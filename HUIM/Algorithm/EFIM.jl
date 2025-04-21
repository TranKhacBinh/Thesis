module EFIM
    include("../../Data.jl")
    using DataStructures

    export efim

    mutable struct ProjectedTransaction
        items::Vector{Item}
        utils::Vector{Utility}
        offset::UInt32
        u::Utility
    end

    ProjectedTransaction() = ProjectedTransaction(Vector{Item}(), Vector{Utility}(), 1, 0.0)
    ProjectedTransaction(items::Vector{Item}, utils::Vector{Utility}) = ProjectedTransaction(items, utils, 1, 0.0)

    mutable struct Database
        transactions::Vector{ProjectedTransaction}
        itemset::Vector{Item}

        function Database(transactions::Vector{Transaction}, util_table::UtilTable)
            projected_transactions = Vector{ProjectedTransaction}(undef, length(transactions))
            itemset = Set{Item}()

            for (tid, transaction) in enumerate(transactions)
                items = Vector{Item}()
                utils = Vector{Utility}()
                for (item, iu) in pairs(transaction)
                    push!(items, item)
                    push!(utils, iu * util_table[item])
                end
                projected_transactions[tid] = ProjectedTransaction(items, utils)
                union!(itemset, items)
            end

            return new(projected_transactions, collect(itemset))
        end
    end

    function less(a::ProjectedTransaction, b::ProjectedTransaction, T::DefaultDict{Item, Utility})
        i, j = length(a.items), length(b.items)
        while i >= a.offset && j >= b.offset
            if a.items[i] != b.items[j]
                if T[a.items[i]] == T[b.items[j]]
                    return a.items[i] < b.items[j]
                end
                return T[a.items[i]] < T[b.items[j]]
            end
            i -= 1
            j -= 1
        end
        return (i - a.offset) < (j - b.offset)
    end

    function calculate_twu(db::Database)
        U = DefaultDict{Item, Utility}(0.0)
        for pt in db.transactions
            tu = sum(pt.utils)
            for item in pt.items
                U[item] += tu
            end
        end
        return U
    end

    function calculate_su(db::Database)
        U = DefaultDict{Item, Utility}(0.0)
        for pt in db.transactions
            re_util = 0.0
            for i in lastindex(pt.items):-1:1
                item = pt.items[i]
                item_util = pt.utils[i]
                U[item] += item_util + re_util
                re_util += item_util
            end
        end
        return U
    end

    function efim(db::Database, min_util::Utility)
        α = Vector{Item}()
        lu = calculate_twu(db)
        secondary = filter(item -> lu[item] >= min_util, db.itemset)
        sort!(secondary, by = item -> lu[item])
        
        # Remove non-secondary items from transactions
        for pt in db.transactions
            indices = filter(i -> !isnothing(i), indexin(secondary, pt.items))
            pt.items = pt.items[indices]
            pt.utils = pt.utils[indices]
        end
        filter!(pt -> !isempty(pt.items), db.transactions)
        
        T(a::ProjectedTransaction, b::ProjectedTransaction) = less(a, b, lu)
        sort!(db.transactions, lt=T)
        
        su = calculate_su(db)
        primary = filter(item -> su[item] >= min_util, secondary)
        
        return efim_search(α, db.transactions, primary, secondary, min_util, T)
    end

    function calculate_uβ_and_βD(αD::Vector{ProjectedTransaction}, β::Vector{Item}, T::Function)
        uβ = 0.0
        βD = Vector{ProjectedTransaction}()
        last_pt = nothing
        merged_pt = nothing

        for pt in αD
            # α-T luôn chứa α nên chỉ cần β[end] (item) in α-T thì α-T sẽ chứa β
            item_index = findfirst(item -> item == β[end], pt.items[pt.offset:end])
            if !isnothing(item_index)
                item_index += pt.offset - 1
                uβ_pt = pt.u + pt.utils[item_index]
                uβ += uβ_pt
                if item_index < length(pt.items)
                    new_pt = ProjectedTransaction(pt.items, pt.utils, item_index + 1, uβ_pt)

                    if isnothing(last_pt)
                        last_pt = new_pt
                    else
                        # Thêm giao dịch vào β_D
                        if T(last_pt, new_pt)
                            if isnothing(merged_pt)
                                push!(βD, last_pt)
                            else
                                push!(βD, merged_pt)
                                merged_pt = nothing
                            end
                        # Gộp các giao dịch giống nhau
                        else
                            if isnothing(merged_pt)
                                merged_pt = ProjectedTransaction(last_pt.items[last_pt.offset:end], last_pt.utils[last_pt.offset:end], 1, last_pt.u)
                            end
                            merged_pt.utils .+= new_pt.utils[new_pt.offset:end]
                            merged_pt.u += new_pt.u
                        end
                        last_pt = new_pt
                    end
                end
            end
        end

        # Thêm giao dịch cuối cùng vào β_D
        if isnothing(merged_pt)
            if !isnothing(last_pt)
                push!(βD, last_pt)
            end
        else
            push!(βD, merged_pt)
        end

        return uβ, βD
    end

    function calculate_su_and_lu(βD::Vector{ProjectedTransaction})
        su = DefaultDict{Item, Utility}(0)
        lu = DefaultDict{Item, Utility}(0)
        for pt in βD
            re_util = 0.0
            total_re_util = sum(pt.utils[pt.offset:end])
            for i in lastindex(pt.items):-1:pt.offset
                item = pt.items[i]
                item_util = pt.utils[i]
                su[item] += pt.u + item_util + re_util
                lu[item] += pt.u + total_re_util
                re_util += item_util
            end
        end
        return su, lu
    end

    function efim_search(α::Vector{Item}, αD::Vector{ProjectedTransaction}, α_primary::Vector{Item}, α_secondary::Vector{Item}, min_util::Utility, T::Function)
        huis = Dict{ItemSet, Utility}()

        for item in α_primary
            @assert !(item in α) throw("abc")
            β = vcat(α, item)
            uβ, βD = calculate_uβ_and_βD(αD, β, T)

            if uβ >= min_util
                huis[Set(β)] = uβ
            end

            su, lu = calculate_su_and_lu(βD)
            β_primary = [item for item in α_secondary if get(su, item, 0) >= min_util]
            β_secondary = [item for item in α_secondary if get(lu, item, 0) >= min_util]

            merge!(huis, efim_search(β, βD, β_primary, β_secondary, min_util, T)) do v1, v2
                if v1 != v2
                    throw(ErrorException("Same key but different value: $v1, $v2"))
                end
                return v1
            end
        end

        return huis
    end

    function efim(transactions::Vector{Transaction}, util_table::UtilTable, min_util::Utility)
        db = Database(transactions, util_table)
        return efim(db, min_util)
    end
end

#=
transactions = [
    Dict(1 => 1, 3 => 1, 4 => 1),
    Dict(1 => 2, 3 => 6, 5 => 2, 7 => 5),
    Dict(1 => 1, 2 => 2, 3 => 1, 4 => 6, 5 => 1, 6 => 5),
    Dict(2 => 4, 3 => 3, 4 => 3, 5 => 1),
    Dict(2 => 2, 3 => 2, 5 => 1, 7 => 2)
]
util_table = Dict(1 => 5.0, 2 => 2.0, 3 => 1.0, 4 => 2.0, 5 => 3.0, 6 => 1.0, 7 => 1.0)
min_util = 30.0
=#

#=
transactions = [
	Dict(3 => 7, 4 => 1, 5 => 1),
    Dict(1 => 1, 3 => 2, 5 => 2),
	Dict(2 => 6, 3 => 4, 4 => 3, 5 => 7),
	Dict(2 => 5, 3 => 3, 4 => 9),
	Dict(1 => 3, 3 => 10, 4 => 3),
	Dict(3 => 5, 5 => 9),
	Dict(1 => 6, 3 => 9, 4 => 2, 5 => 5),
	Dict(1 => 1, 2 => 6, 3 => 2, 4 => 5, 5 => 3)
]
util_table = Dict(1 => 9.0, 2 => 11.0, 3 => 4.0, 4 => 6.0, 5 => 7.0)
min_util = 200.0
HUIs = Dict(
	Set([1, 3, 4, 5]) => 205,
	Set([2, 3, 4, 5]) => 274,
	Set([2, 3]) => 223,
    Set([1, 3, 4]) => 234,
	Set([2, 3, 5]) => 226,
	Set([3, 4, 5]) => 266,
    Set([2, 5]) => 202,
	Set([2, 4]) => 289,
	Set([3, 5]) => 305,
    Set([2, 4, 5]) => 250,
	Set([2, 3, 4]) => 325,
	Set([3, 4]) => 278
)
=#