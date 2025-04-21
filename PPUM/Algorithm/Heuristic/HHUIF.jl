module HHUIF
    include("../../../Data.jl")

    export hhuif

    function select(si::ItemSet, transactions::Vector{Transaction}, util_table::UtilTable)
        selected_item = nothing
        selected_tid = nothing
        selected_item_util = 0.0

        for (tid, trans) in enumerate(transactions)
            if issubset(si, keys(trans))
                for (item, iu) in pairs(trans)
                    if item in si
                        item_util = iu * util_table[item]
                        if item_util > selected_item_util
                            selected_item = item
                            selected_tid = tid
                            selected_item_util = item_util
                        end
                    end
                end
            end
        end

        return selected_item, selected_tid, selected_item_util
    end

    function hhuif(transactions::Vector{Transaction}, util_table::UtilTable, sis::Vector{ItemSet}, huis::Dict{ItemSet, Utility}, min_util::Utility)
        sanitized_transactions = deepcopy(transactions)
        sis_sorted = sort(sis, by=si->huis[si], rev=true)

        for si in sis_sorted
            diff = utility(si, sanitized_transactions, util_table) - min_util

            while diff >= 0
                selected_item, selected_tid, selected_item_util = select(si, sanitized_transactions, util_table)

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