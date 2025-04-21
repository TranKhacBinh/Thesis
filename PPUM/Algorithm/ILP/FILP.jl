module FILP
    using JuMP
    using HiGHS # Gurobi, GLPK, SCIP
    import JuMP.optimize!
    import JuMP.backend

    import Base.length
    import Base.deleteat!

    include("./ConstraintMatrix.jl")
    include("./Tables.jl")

    export filp

    function construct_tables(huis, sis, transactions)
        # 1st phase: Constructs tables stored relationship of HUIs and transactions support them
        S_IT = IT()
        N_IT = IT()
        for (itemset, util) in pairs(huis)
            size = length(itemset)
            tids=Set{Int64}()
            # Find transactions that support itemset 
            for (tid, trans) in enumerate(transactions)
                if issubset(itemset, keys(trans))
                    push!(tids, tid)
                end
            end
            if itemset in sis
                push!(S_IT.itemsets, itemset)
                push!(S_IT.tidsets, tids)
                push!(S_IT.sizes, size)
                push!(S_IT.utils, util)
                S_IT.n_rows += 1
            else
                push!(N_IT.itemsets, itemset)
                push!(N_IT.tidsets, tids)
                push!(N_IT.utils, util)
                push!(N_IT.sizes, size)
                N_IT.n_rows += 1
            end
        end
        return N_IT, S_IT
    end

    function find_special_sets(N_IT::IT, S_IT::IT)
        # 2nd phase: find bound-to-lose itemsets and itemsets that will be not affected by hiding process
        remove = Vector{Int64}()
        for i in 1:N_IT.n_rows
            L = 0 
            n_itemset  = N_IT.itemsets[i]
            n_tidset = N_IT.tidsets[i]
            for j in 1:S_IT.n_rows
                s_itemset  = S_IT.itemsets[j]
                s_tidset = S_IT.tidsets[j]
                a = n_itemset ∩ s_itemset
                b = n_tidset ∩ s_tidset
                if !isempty(a) && !isempty(b)
                    if n_itemset ⊆ s_itemset && n_tidset ⊆ s_tidset
                        push!(remove, i)                #Bound to lose itemset
                        break
                    end
                else
                    L+=1
                end
            end

            if L == S_IT.n_rows
                push!(remove, i)                # itemset that will not be affected by hiding process
            end

            # 3rd phase: find redundant itemsets
            for k in 1:N_IT.n_rows
                n1_itemset = N_IT.itemsets[k]
                n1_tidset = N_IT.tidsets[k]
                if n_itemset != n1_itemset && n1_itemset ⊆ n_itemset && n1_tidset ⊆ n_tidset
                    push!(remove, i)
                    break
                end
            end
        end
        deleteat!(N_IT, unique(remove))
        return remove
    end

    function establish_constraints(N_IT, S_IT, transactions, util_table, min_util)
        # Establish variables and constraint matrix for sensitive itemsets
        #========================================================================================#
        n_vrs = 0                                               # Number of variables
        utils = Dict{Tuple{Int64, Item}, Utility}()           # Variable utils
        coeff = Vector{EUtility}()                                  # Coefficent of variables
        vr_orders = Dict{Tuple{Int64, Item}, Int64}()      # Order of variables in variable list
        poss = Vector{Tuple{Int64, Item}}()                   # Positions of variables in data 

        n_s_constraints = S_IT.n_rows                          # Number of sensitive itemsets

        # constraints constructed from S_IT table 
        replace_indices = Vector{Vector{Int64}}()                                      # Matrix indices to replace (abstract array)
        for c_idx in 1:n_s_constraints
            itemset = S_IT.itemsets[c_idx]
            tidset  = S_IT.tidsets[c_idx]
            prod = collect(Iterators.product(tidset, itemset))

            r = Vector{Int64}()
            for v in prod
                if get(vr_orders, v, -1) == -1 
                    n_vrs +=1
                    exUtil = util_table[v[2]]
                    inUtil = transactions[v[1]][v[2]]

                    push!(coeff, exUtil)
                    push!(utils, v => exUtil * inUtil)
                    push!(vr_orders, v => n_vrs)
                    push!(poss, v)
                end
                push!(r, vr_orders[v])
            end
            push!(replace_indices, r)
        end
        vrs = Variables(n_vrs, coeff, [], [], poss)                # All variables of CSP model
        s_matrix = zeros(Int64, n_s_constraints, n_vrs)
        for r in 1:n_s_constraints
            s_matrix[r, replace_indices[r]] .= 1                      
        end
        s_matrix = s_matrix .* transpose(coeff)
        # println("matrix size:", size(s_matrix))
        s_constraints = ConstraintMatrix(n_s_constraints , s_matrix, fill(min_util, n_s_constraints))


        # Establish constraint matrix for non-sensitive itemsets
        #========================================================================================#
        lower_bounds = Vector{Utility}()    # Lowerbounds to retain NSHUIs 
        remove = Vector{Int64}()         # Some itemsets affected by hiding process but their utilities can not be lower than δ, we will not establish contraints to retain them.
        n_n_constraints = N_IT.n_rows      # Number of constraints constructed from N_IT table
        n_matrix = zeros(Int64, n_n_constraints, n_vrs)
        for i in 1:n_n_constraints
            n_itemset = N_IT.itemsets[i]
            n_tidset = N_IT.tidsets[i]
            tid_items = Vector{Tuple{Int64, Item}}()
            vs = collect(Iterators.product(n_tidset, n_itemset))
            l = 0
            for v in vs 
                missing_util = get(utils, v, 0)
                l += missing_util 
                if missing_util != 0
                    push!(tid_items, v)
                end
            end
            remaining_util = N_IT.utils[i] - l
            if remaining_util >= min_util
                push!(remove, i)                              # Remove itemset from constraints
            end

            push!(lower_bounds, min_util - remaining_util)           # Inequality 5 or 6 (correct it later)
            order_list = getindex.(Ref(vr_orders), tid_items)
            n_matrix[i, order_list] .= 1
            # n_constraints[product(i,order_list)] .= 1
        end

        n_matrix = n_matrix[setdiff(1:end, remove), :]
        if !isempty(remove) 
            deleteat!(lower_bounds, remove)
            deleteat!(N_IT, remove)
        end
        n_matrix = n_matrix.* transpose(coeff)
        n_constraints = ConstraintMatrix(n_n_constraints, n_matrix, lower_bounds)
        return s_constraints, n_constraints, vrs
    end

    function preprocess(transactions, util_table, sis, huis, min_util)
        N_IT, S_IT = construct_tables(huis, sis, transactions)
        find_special_sets(N_IT, S_IT)
        s_constraints, n_constraints, variables = establish_constraints(N_IT, S_IT, transactions, util_table, min_util)
        return s_constraints, n_constraints, variables, N_IT 
    end

    function relaxation(utils, sizes, indxs, jump_model, n_cons)
        #Find the constraint corresponding to maximum size and minimum utility itemset
        longest = argmax(sizes)
        idx = argmin(utils[longest])
        c_idx = indxs[idx] 

        #Remove contraint from model
        delete(jump_model, n_cons[c_idx])
        deleteat!(utils, idx)
        deleteat!(indxs, idx)
        deleteat!(sizes, idx)
    end

    function solve_FILP(s_constraints, n_constraints, variables, table)
        #jump_model = direct_model(Gurobi.Optimizer())
        #jump_model = direct_model(GLPK.Optimizer())
        jump_model = direct_model(HiGHS.Optimizer())
        model = backend(jump_model)
        @variable(jump_model, 1 <= x[1:length(variables)], Int)

        n_s_cons = length(s_constraints)
        n_n_cons = length(n_constraints)

        @constraint(jump_model, s_cons, s_constraints.matrix * x .<= s_constraints.bounds)
        @constraint(jump_model, n_cons, n_constraints.matrix * x  .>= n_constraints.bounds)

        @objective(jump_model, Min, sum(x))

        indxs = collect(1:length(table.sizes))
        #set_optimizer_attribute(jump_model, "OutputFlag", 0)
        #set_optimizer_attribute(jump_model, "msg_lev", 0)
        set_optimizer_attribute(jump_model, "log_to_console", false)
        #set_silent(jump_model)
        optimize!(jump_model)
        while termination_status(jump_model) == MOI.INFEASIBLE || termination_status(jump_model)== MOI.INFEASIBLE_OR_UNBOUNDED
            # Relaxation
            relaxation(table.utils, table.sizes, indxs, jump_model, n_cons)
            optimize!(jump_model)
        end
        return value.(x)#, jump_model, model
    end

    function filp(transactions, util_table, sis, huis, min_util)
        s_constraints, n_constraints, variables, table = preprocess(transactions, util_table, sis, huis, min_util)
        x  = solve_FILP(s_constraints, n_constraints, variables, table)

        sanitized_transactions = deepcopy(transactions)
        for i in 1:length(variables)
            pos = variables.poss[i]
            tid = pos[1]
            item = pos[2]
            if get(sanitized_transactions, tid, -1) != -1
                sanitized_transactions[tid][item] = ceil(x[i])
            end
        end
        return sanitized_transactions
    end
end