module SO2DI_v1
    include("../../../Data.jl")
    include("../../StochasticOptimization/GA.jl")

    export so2di

    function f_SO2DI(indices,
                     si_util::Utility, 
                     si_util_in_trans::Vector{Utility},
                     nsis_util::Dict{ItemSet, Utility}, 
                     nsis_util_in_trans::Vector{Vector{Utility}}, 
                     nsis_related::Vector{ItemSet}, 
                     min_util::Utility)
    
        hf = si_util - sum(si_util_in_trans[idx] for idx in indices) >= min_util

        mc = 0
        for (nsi, nsi_util_in_trans) in zip(nsis_related, nsis_util_in_trans)
            if nsis_util[nsi] - sum(nsi_util_in_trans[idx] for idx in indices) < min_util
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
        nsis_util = filter(p -> !(p.first in sis), huis)

        for (si_idx, si) in enumerate(sis)
            s_tids = Vector{Int}()
            si_util_in_trans = Vector{Utility}()

            if si_idx == 1
                si_util = huis[si]
                for (tid, trans) in enumerate(sanitized_transactions)
                    util = utility(si, trans, util_table)
                    if util > 0
                        push!(s_tids, tid)
                        push!(si_util_in_trans, util)
                    end
                end
            else
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
            end

            count_nsis = Dict(item => Vector{ItemSet}() for item in si)
            for item in si
                for (nsi, _) in nsis_util
                    if item in nsi
                        push!(count_nsis[item], nsi)
                    end
                end
            end
            item_deleted = argmin(item -> length(count_nsis[item]), keys(count_nsis))
            nsis_related = count_nsis[item_deleted]

            nsis_util_in_trans = [
                [utility(nsi, sanitized_transactions[tid], util_table) for tid in s_tids]
                for nsi in nsis_related
            ]

            si_util_in_trans_sorted = sort(si_util_in_trans)
            max_victim_trans = 1
            total_util = 0
            for util in si_util_in_trans_sorted
                total_util += util
                if si_util - total_util < min_util
                    break
                end
                max_victim_trans += 1
            end
    
            ga = GA(length(s_tids), M, max_victim_trans)
            best_indices, _ = optimize!(
                ga, 
                indices -> f_SO2DI(indices, si_util, si_util_in_trans, nsis_util, nsis_util_in_trans, nsis_related, min_util),
                max_iterations
            )

            if si_idx != num_sis
                for (nsi, nsi_util_in_trans) in zip(nsis_related, nsis_util_in_trans)
                    nsis_util[nsi] -= sum(nsi_util_in_trans[idx] for idx in best_indices)
                end
                filter!(p -> p.second >= min_util, nsis_util)
            end

            for idx in best_indices
                delete!(sanitized_transactions[s_tids[idx]], item_deleted)
            end
        end
    
        filter!(trans -> !isempty(trans), sanitized_transactions)
        return sanitized_transactions
    end
end