module FULD_Plus
    include("../../../Data.jl")
    using DataStructures

    export fuld

    mutable struct ULElem
        tns::Float64
        item_util::Utility
    end

    mutable struct UTList
        SINS::Int
        ULElems::OrderedDict{Int, ULElem}
    end

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
        utldic = UTLDic(item => UTList(SINS(item, nsis), OrderedDict{Int, ULElem}()) for item in s_item)

        for (tid, trans) in enumerate(transactions)
            SI = reduce(union, filter(itemset -> issubset(itemset, keys(trans)), sis), init=Set{Item}())
            for item in SI
                ULE = ULElem(tns(nsis, trans), utility(item, trans, util_table))
                utldic[item].ULElems[tid] = ULE
            end
        end

        return utldic
    end

    function L(utldic::UTLDic, itemset::ItemSet)
        return reduce(intersect, [Set(keys(utldic[item].ULElems)) for item in itemset])
    end

    function hide_shuis!(utldic::UTLDic, transactions::Vector{Transaction}, util_table::UtilTable, sis::Vector{ItemSet}, huis::Dict{ItemSet, Utility}, min_util::Utility)
        sanitized_transactions = deepcopy(transactions)
    
        sort!(sis, by = itemset -> huis[itemset], rev=true)
        for si in sis
            l = L(utldic, si)
            target_util = utility(si, sanitized_transactions, util_table) - min_util + 1
    
            si = collect(si)
            sort!(si, by = item -> utldic[item].SINS)
            while target_util > 0.0
                for item in si
                    utldic[item].ULElems = OrderedDict(sort(collect(utldic[item].ULElems), by = pair -> (-pair[2].tns, pair[2].item_util)))
                    for (tid, elem) in pairs(utldic[item].ULElems)
                        if (tid in l) && (target_util > 0.0)
                            if elem.item_util <= target_util
                                target_util -= sum(utldic[item].ULElems[tid].item_util for item in si)
                                elem.item_util = 0.0
    
                                delete!(sanitized_transactions[tid], item)
                            else
                                count = transactions[tid][item] - ceil(target_util / util_table[item])
                                elem.item_util = count * util_table[item]
                                target_util = 0.0
    
                                sanitized_transactions[tid][item] = count
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