Item = Int64
ItemSet = Set{Item}
IUtility = Int64
EUtility = Float64
Utility = Float64
Transaction = Dict{Item, IUtility}
UtilTable = Dict{Item, EUtility}

function utility(item::Item, trans::Transaction, util_table::UtilTable)
	return trans[item] * util_table[item]
end

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

function utility(itemset::Union{ItemSet, Vector{Item}}, transactions::Vector{Transaction}, util_table::UtilTable)
    return sum(utility(itemset, trans, util_table) for trans in transactions)
end

function utility(trans::Transaction, util_table::UtilTable)
	return sum(int_util * util_table[item] for (item, int_util) in pairs(trans))
end

function utility(transactions::Vector{Transaction}, util_table::UtilTable)
	return sum(utility(trans, util_table) for trans in transactions)
end

using Sound
function beep(freq=440, duration=3, amplitude=0.5, samplerate=44100)
    t = range(0, duration, step=1/samplerate)
    signal = amplitude * tan.(2π * freq * t)
    sound(signal, samplerate)
end