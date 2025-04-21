module MSU_MIU
    include("../../../Data.jl")

    export msu_miu

    function maximum_sensitive_utility_minimum_item_utility(si::ItemSet, transactions::Vector{Transaction}, util_table::UtilTable)
        selected_item = nothing
        selected_tid = nothing
        msu = 0
        min_item_util = Inf

        for (tid, trans) in enumerate(transactions)
            if issubset(si, keys(trans))
                si_util_in_trans = utility(si, trans, util_table)
                if si_util_in_trans > msu
                    msu = si_util_in_trans
                    selected_tid = tid
                end
            end
        end

        for item in si
            item_util = utility(item, transactions[selected_tid], util_table)
            if item_util < min_item_util
                min_item_util = item_util
                selected_item = item
            end
        end

        return selected_item, selected_tid
    end

    function msu_miu(transactions::Vector{Transaction}, util_table::UtilTable, sis::Vector{ItemSet}, huis::Dict{ItemSet, Utility}, min_util::Utility)
        sanitized_transactions = deepcopy(transactions)

        for si in sis
            diff = utility(si, sanitized_transactions, util_table) - min_util

            while diff >= 0
                selected_item, selected_tid = maximum_sensitive_utility_minimum_item_utility(si, sanitized_transactions, util_table)
                selected_item_util = utility(selected_item, sanitized_transactions[selected_tid], util_table)

                if selected_item_util <= diff
                    si_util_in_trans = utility(si, sanitized_transactions[selected_tid], util_table)
                    delete!(sanitized_transactions[selected_tid], selected_item)
                    diff -= si_util_in_trans
                else
                    reduced = floor(IUtility, diff / util_table[selected_item]) + 1
                    sanitized_transactions[selected_tid][selected_item] -= reduced
                    diff -= reduced * util_table[selected_item]

                    if sanitized_transactions[selected_tid][selected_item] == 0
                        delete!(sanitized_transactions[selected_tid], selected_item)
                    end
                end
            end
        end

        filter!(trans -> !isempty(trans), sanitized_transactions)
        return sanitized_transactions
    end
end