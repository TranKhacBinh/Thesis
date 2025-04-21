module PPUMALO
    import Base.length
    import Base.deleteat!

    include("./ConstraintMatrix.jl")
    include("./Tables.jl") 
    include("../../StochasticOptimization/ALO.jl")

    export ppumalo

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
        remove = Array{Int64, 1}()
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
        original_value = Array{IUtility, 1}()
        original_util = Array{Utility, 1}()
        coeff = Array{EUtility, 1}()                                  # Coefficent of variables
        vr_orders = Dict{Tuple{Int64, Item}, Int64}()      # Order of variables in variable list
        poss = Array{Tuple{Int64, Item}, 1}()                   # Positions of variables in data 

        n_s_constraints = S_IT.n_rows                          # Number of sensitive itemsets

        # constraints constructed from S_IT table 
        replace_indices = Array{Array{Int64, 1}, 1}()                                      # Matrix indices to replace (abstract array)
        for c_idx in 1:n_s_constraints
            itemset = S_IT.itemsets[c_idx]
            tidset  = S_IT.tidsets[c_idx]
            prod = collect(Iterators.product(tidset, itemset))

            r = Array{Int64, 1}()
            for v in prod
                if get(vr_orders, v, -1) == -1 
                    n_vrs +=1
                    exUtil = util_table[v[2]]
                    inUtil = transactions[v[1]][v[2]]
                    util = exUtil * inUtil

                    push!(coeff, exUtil)
                    push!(original_value, inUtil)
                    push!(original_util, util)
                    push!(utils, v => exUtil * inUtil)
                    push!(vr_orders, v => n_vrs)
                    push!(poss, v)
                end
                push!(r, vr_orders[v])
            end
            push!(replace_indices, r)
        end
        vrs = Variables(n_vrs, coeff, original_value, original_util, poss)                # All variables of CSP model
        s_matrix = zeros(Int64, n_s_constraints, n_vrs)
        for r in 1:n_s_constraints
            s_matrix[r, replace_indices[r]] .= 1                      
        end
        s_matrix = s_matrix .* transpose(coeff)
        # println("matrix size:", size(s_matrix))
        s_constraints = ConstraintMatrix(n_s_constraints , s_matrix, fill(min_util, n_s_constraints))


        # Establish constraint matrix for non-sensitive itemsets
        #========================================================================================#
        lower_bounds = Array{Utility, 1}()    # Lowerbounds to retain NSHUIs 
        remove = Array{Int64, 1}()         # Some itemsets affected by hiding process but their utilities can not be lower than δ, we will not establish contraints to retain them.
        n_n_constraints = N_IT.n_rows      # Number of constraints constructed from N_IT table
        n_matrix = zeros(Int64, n_n_constraints, n_vrs)
        for i in 1:n_n_constraints
            n_itemset = N_IT.itemsets[i]
            n_tidset = N_IT.tidsets[i]
            tid_items = Array{Tuple{Int64, Item}, 1}()
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

    function PPUM_ALO_F(x, args, log=false)
        coeff = args[1] 
        w₁ = args[2] 
        w₂ = args[3]
        w₃ = args[4]
        n_matrix= args[5] 
        n_pen = args[6]
        s_matrix = args[7] 
        s_pen = args[8]
        r_pen = args[9]
        #' @param 
        #         x::Array{Float64,1}       variables
        #'        coeff::Array{Float64,1}   coefficients of variables
        #'        α, β, γ::Float64          hyperparams
        #'        n_matrix::Matrix          non-sensitive constraint matrix
        #'        s_matrix::Matrix          sensitive constraint matrix
        #'        s_pen::Array{Float64, 1}  penalties for vialating sensitive constraints
        #'        n_pen::Array{Float64, 1}  penalties for vialating non-sensitive constraints

        s_violate = s_matrix * x .- s_pen
        n_violate = n_pen - n_matrix * x
        r_util    = r_pen .+ coeff    .* x 
        #r_util    = coeff    .* x 
        s_violate[s_violate.<0] .= 0
        n_violate[n_violate.<0] .= 0
        r_util[r_util.<0] .= 0
        s = sum(w₁ .* s_violate) # sensitive utilities

        n = sum(w₂ .* n_violate)
        r = sum(w₃ .* r_util)
        if log ==true
            println(s,"\t",n,"\t",r)
        end

        f = s + n + r
        return f
    end

    function solve_PPUMALO(s_constraints, n_constraints, variables, N_IT, n_ants, n_iterations)
        dim = length(variables)
        lb = fill(1, dim) 
        ub = fill(20, dim) 

        maxima=false
        n_matrix = n_constraints.matrix
        n_pen = n_constraints.bounds

        s_pen = s_constraints.bounds
        s_matrix = s_constraints.matrix

        coeff = variables.coeff
        r_pen = -variables.original_util
        w₁ = big(100000000)
        w₂ = 1
        w₃ = 20

        args = (coeff, w₁, w₂, w₃, n_matrix, n_pen, s_matrix, s_pen, r_pen, lb, ub)
        alo = ALO(n_iterations, n_ants, dim, lb, ub, false)
        solution = optimize!(alo, PPUM_ALO_F, args)
        return solution
    end

    function ppumalo(transactions, util_table, sis, huis, min_util, M, n_iterations)
        s_constraints, n_constraints, variables, table = preprocess(transactions, util_table, sis, huis, min_util)
        x = solve_PPUMALO(s_constraints, n_constraints, variables, table, M, n_iterations)

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