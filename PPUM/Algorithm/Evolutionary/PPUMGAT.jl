module PPUMGAT
    include("../../../Data.jl")
    include("../../StochasticOptimization/GA.jl")

    export ppumgat

    # Hàm tính TWU (Transaction-Weighted Utility)
    function calculate_twu(itemset::ItemSet, transactions::Vector{Transaction}, tu::Vector{Utility})
        sum(tu[tid] for (tid, trans) in enumerate(transactions) if issubset(itemset, keys(trans)); init=0.0)
    end

    function calculate_mdu(sis::Vector{ItemSet}, transactions::Vector{Transaction}, tu::Vector{Utility}, min_util::Utility)
        return sum(calculate_twu(si, transactions, tu) - min_util for si in sis; init=0.0)
    end

    function find_candi_delete(transactions::Vector{Transaction}, sis::Vector{ItemSet}, tu::Vector{Utility}, mdu::Utility)
        candidates = Vector{Int}()
        for (tid, trans) in enumerate(transactions)
            if any(issubset(si, keys(trans)) for si in sis)
                if tu[tid] < mdu
                    push!(candidates, tid)
                end
            end
        end
        return sort(candidates, by=x->tu[x])
    end

    function fitness(chromosome::BitSet, utility_table::Vector{Vector{Utility}}, sis::Vector{ItemSet},
                    itemsets::Vector{ItemSet}, min_util::Utility, w1::Float64, w2::Float64)

        new_util = utility_table[end] - sum(utility_table[idx] for idx in chromosome)
        hf = 0
        mc = 0
        for (idx, itemset) in enumerate(itemsets)
            if itemset in sis
                if new_util[idx] >= min_util
                    hf += 1
                end
            else
                if new_util[idx] < min_util
                    mc += 1
                end
            end
        end
        HF = hf / length(sis)
        MC = mc / (length(itemsets) - length(sis))
        
        return w1 * HF + w2 * MC
    end

    function ppumgat(transactions::Vector{Transaction}, util_table::UtilTable, sis::Vector{ItemSet},
                    huis::Dict{ItemSet, Utility}, min_util::Utility, population_size::Int, max_generations::Int, w1::Float64, w2::Float64)

        tu = (trans -> utility(trans, util_table)).(transactions)
        mdu = calculate_mdu(sis, transactions, tu, min_util)
        candidates = find_candi_delete(transactions, sis, tu, mdu)

        itemsets = collect(keys(huis))
        utility_table = [Vector{Utility}(undef, length(itemsets)) for _ in 1:(length(candidates) + 1)]
        for (i, candidate) in enumerate(candidates)
            for (j, itemset) in enumerate(itemsets)
                utility_table[i][j] = utility(itemset, transactions[candidate], util_table)
            end
        end
        utility_table[end] = [huis[itemset] for itemset in itemsets]

        chromosome_length = 0
        total_util = 0.0
        for tid in candidates
            total_util += tu[tid]
            if total_util > mdu
                break
            end
            chromosome_length += 1
        end

        ga = GA(length(candidates), population_size, chromosome_length)
        best_chromosome, best_fitness = optimize!(ga, chromosome -> fitness(chromosome, utility_table, sis, itemsets, min_util, w1, w2), max_generations)
        
        return [trans for (tid, trans) in enumerate(transactions) if !(tid in candidates[collect(best_chromosome)])]
    end
end

#=
transactions = [
	Dict("D" => 6, "F" => 1),
    Dict("E" => 6),
	Dict("A" => 5, "E" => 1),
	Dict("B" => 5, "F" => 2),
	Dict("C" => 8, "F" => 2),
	Dict("A" => 4, "E" => 1),
	Dict("B" => 2, "C" => 3, "D" => 2),
	Dict("A" => 7, "B" => 3, "E" => 2),
	Dict("E" => 4),
	Dict("A" => 5, "B" => 2, "E" => 5),
	Dict("C" => 1, "F" => 1),
	Dict("A" => 3, "E" => 3)
]

utilTable = Dict("A" => 7, "B" => 15, "C" => 10, "D" => 6, "E" => 2, "F" => 1)

S = Set([Set(["B"]), Set(["A", "B", "E"])])

HUIs = Dict(
	Set(["A"]) => 168,
	Set(["B"]) => 180,
	Set(["C"]) => 120,
    Set(["A", "B"]) => 159,
	Set(["A", "E"]) => 192,
	Set(["A", "B", "E"]) => 173
)

min_util = 114
=#