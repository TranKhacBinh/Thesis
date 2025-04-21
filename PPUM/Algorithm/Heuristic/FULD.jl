module FULD
    include("../../../Data.jl")

    export fuld

    mutable struct ULElem
        tid::Int
        tns::Float64
        item_util::Utility
    end

    mutable struct UTList
        item::Item
        SINS::Int
        #total_util::Utility
        ULElems::Vector{ULElem}
    end
    UTList(item::Item) = UTList(item, 0, [])

    UTLDic = Dict{Item, UTList}

    function SINS(s_item::Item, nsis::Set{ItemSet})
        return count(itemset -> s_item in itemset, nsis)
    end

    function tns(nsis::Set{ItemSet}, trans::Transaction)
        NSI_num = count(itemset -> issubset(itemset, keys(trans)), nsis)
        return round(1 / (1 + NSI_num), digits=2)
    end

    function construct_UTLDic(transactions::Vector{Transaction}, util_table::UtilTable, sis::Vector{ItemSet}, nsis::Set{ItemSet})
        s_item = reduce(union, sis)
        utldic = UTLDic()

        for item in s_item
            UTL = UTList(item)
            UTL.SINS = SINS(item, nsis)
            utldic[item] = UTL
        end

        for (tid, trans) in enumerate(transactions)
            SI = reduce(union, filter(itemset -> issubset(itemset, keys(trans)), sis), init=Set{Item}())
            for item in SI
                ULE = ULElem(tid, tns(nsis, trans), trans[item] * util_table[item])
                push!(utldic[item].ULElems, ULE)
                #utldic[item].total_util += ULE.item_util
            end
        end

        return utldic
    end

    function L(utldic::UTLDic, itemset::ItemSet)
        return reduce(intersect, [Set([elem.tid for elem in utldic[item].ULElems]) for item in itemset])
    end

    function hide_shuis!(utldic::UTLDic, transactions::Vector{Transaction}, util_table::UtilTable, sis::Vector{ItemSet}, huis::Dict{ItemSet, Utility}, min_util::Utility)
        sanitized_transactions = deepcopy(transactions)
    
        sort!(sis, by = itemset -> huis[itemset], rev=true)
        for si in sis
            l = L(utldic, si)
            target_util = utility(si, sanitized_transactions, util_table) - min_util
    
            si = collect(si)
            sort!(si, by = item -> utldic[item].SINS)
            while target_util >= 0.0
                for item in si
                    sort!(utldic[item].ULElems, by = ULE -> (-ULE.tns, ULE.item_util))
                    for elem in utldic[item].ULElems
                        if (elem.tid in l) && (target_util > 0.0) && (elem.item_util > 0.0)
                            if elem.item_util <= target_util
                                si_util_in_trans = utility(si, sanitized_transactions[elem.tid], util_table)
                                target_util -= si_util_in_trans
                                elem.item_util = 0.0
    
                                delete!(sanitized_transactions[elem.tid], item)
                            else
                                reduced = floor(IUtility, target_util / util_table[item]) + 1
                                sanitized_transactions[elem.tid][item] -= reduced
                                target_util -= reduced * util_table[item]
                                elem.item_util -= reduced * util_table[item]
                                
                                if sanitized_transactions[elem.tid][item] == 0
                                    delete!(sanitized_transactions[elem.tid], item)
                                end
                            end
                        end
                    end
                end
            end
        end
        filter!(trans -> !isempty(trans), sanitized_transactions)
        return sanitized_transactions
    end
    
    function fuld(transactions::Vector{Transaction}, util_table::UtilTable, sis::Vector{ItemSet}, huis::Dict{ItemSet, Utility}, min_util::Utility)
        nsis = setdiff(keys(huis), sis)
        utldic = construct_UTLDic(transactions, util_table, sis, nsis)
        sanitized_transactions = hide_shuis!(utldic, transactions, util_table, sis, huis, min_util)
    
        return sanitized_transactions
    end
end


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
huis = Dict(
	Set([1, 3, 4, 5]) => 205.0,
	Set([2, 3, 4, 5]) => 274.0,
	Set([2, 3]) => 223.0,
    Set([1, 3, 4]) => 234.0,
	Set([2, 3, 5]) => 226.0,
	Set([3, 4, 5]) => 266.0,
    Set([2, 5]) => 202.0,
	Set([2, 4]) => 289.0,
	Set([3, 5]) => 305.0,
    Set([2, 4, 5]) => 250.0,
	Set([2, 3, 4]) => 325.0,
	Set([3, 4]) => 278.0
)
sis = [Set([1, 3, 4]), Set([2, 3])]
=#