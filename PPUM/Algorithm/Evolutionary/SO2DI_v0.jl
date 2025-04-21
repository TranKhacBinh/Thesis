module SO2DI
    include("../../../Data.jl")
    include("../../StochasticOptimization/GA.jl")

    export so2di

    function utility(itemset::Union{ItemSet, Vector{Item}}, trans::Transaction, util_table::UtilTable)
        total_util = 0.0
        for item in itemset
            int_util = get(trans, item, nothing)
            if int_util === nothing
                return 0.0
            end
            total_util += int_util * util_table[item]
        end
        return total_util
    end

    function optimize_genes_size(si_util_in_trans, si_util, min_util)
        si_util_in_trans_sorted = sort(si_util_in_trans)
        max_genes_size = 1
        total_util = 0
        for util in si_util_in_trans_sorted
            total_util += util
            if si_util - total_util < min_util
                break
            end
            max_genes_size += 1
        end
        return max_genes_size
    end

    function fitness(individual::BitSet, 
                     si_util::Utility, 
                     si_util_in_trans::Vector{Utility},
                     nsis_util::Vector{Pair{ItemSet, Utility}}, 
                     nsis_util_in_trans::Vector{Vector{Utility}}, 
                     nsis_related::Vector{Int}, 
                     min_util::Utility)
    
        hf = si_util - sum(si_util_in_trans[idx] for idx in individual) >= min_util

        mc = 0
        for (nsi_idx, nsi_util_in_trans) in zip(nsis_related, nsis_util_in_trans)
            if last(nsis_util[nsi_idx]) - sum(nsi_util_in_trans[idx] for idx in individual) < min_util
                mc += 1
            end
        end
    
        return Int(hf) * (length(nsis_related) + 1) + mc
    end
    
    function so2di(transactions::Vector{Transaction}, 
                   util_table::UtilTable, 
                   sis::Vector{ItemSet},
                   huis::Dict{ItemSet, Utility}, 
                   min_util::Utility, 
                   M::Int, 
                   max_iterations::Int)
    
        num_sis = length(sis)
        sanitized_transactions = deepcopy(transactions)
        nsis_util = filter(x -> !(first(x) in sis), collect(huis))

        for (si_idx, si) in enumerate(sis)
            # 1. Kiểm tra xem SHUI đã bị ẩn hay chưa?
            s_tids = Vector{Int}()
            si_util_in_trans = Vector{Utility}()
            si_util = 0
            for (tid, trans) in enumerate(sanitized_transactions)
                util = utility(si, trans, util_table)
                if util > 0
                    push!(s_tids, tid)
                    push!(si_util_in_trans, util)
                    si_util += util
                end
            end
            
            if si_util < min_util
                continue
            end

            # 2. Xác định item nạn nhân
            count_nsis = Dict(item => findall(x -> item in first(x), nsis_util) for item in si)
            item_deleted = argmin(item -> length(count_nsis[item]), keys(count_nsis))
            nsis_related = count_nsis[item_deleted]

            # 3. Xác định transaction nạn nhân
            max_genes_size = optimize_genes_size(si_util_in_trans, si_util, min_util)
            
            nsis_util_in_trans = [
                [utility(first(nsis_util[nsi_idx]), sanitized_transactions[tid], util_table) 
                 for tid in s_tids]
                for nsi_idx in nsis_related
            ]

            ga = GA(length(s_tids), M, max_genes_size)
            params = (si_util, si_util_in_trans, nsis_util, nsis_util_in_trans, nsis_related, min_util)
            best_individual, _ = optimize!(ga, x -> fitness(x, params...), max_iterations)

            # 4. Xóa item
            for idx in best_individual
                delete!(sanitized_transactions[s_tids[idx]], item_deleted)
            end

            # 5. Cập nhật lợi ích cho các NSHUI
            if si_idx != num_sis
                for (nsi_idx, nsi_util_in_trans) in zip(nsis_related, nsis_util_in_trans)
                    new_utility = nsis_util[nsi_idx][2] - sum(nsi_util_in_trans[idx] for idx in best_individual)
                    nsis_util[nsi_idx] = Pair(nsis_util[nsi_idx][1], new_utility)
                end
                filter!(x -> last(x) >= min_util, nsis_util)
            end
        end
    
        return sanitized_transactions
    end
end