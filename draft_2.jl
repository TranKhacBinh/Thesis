include("./Dataset.jl")
include("./UtilityGenerator.jl")
include("./HUIM/Algorithm/EFIM.jl")
include("./PPUM/Algorithm/Evolutionary/SO2DI.jl")
include("./Performance.jl")
include("./PPUM/StochasticOptimization/GA.jl")

using .EFIM
using .SO2DI

#=
n_item = 5
n_trans = 8

items = collect(1:n_item)
transactions_no_util = Set{Set{Int64}}([])
while true
    push!(transactions_no_util, Set(sample(items, rand(1:n_item), replace=false)))
    if length(transactions_no_util) == n_trans
        break
    end
end

util_table = gen_ext_util(Set(items), 1.0:10.0)
transactions = gen_int_util(collect(transactions_no_util), 1:9)
for trans in transactions
    println([item => get(trans, item, 0) for item in items])
end
println()
println(sort(collect(util_table), by=x->first(x)))
println()

min_util = 200.0
huis = efim(transactions, util_table, min_util)
println.(sort(collect(huis), by=x->last(x)))
=#


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
so2di(transactions, util_table, sis, huis, min_util) = SO2DI.so2di(transactions, util_table, sis, huis, min_util, 5, 10)

transactions = [
	Dict(1 => 5, 2 => 1, 3 => 6,         5 => 8),
    Dict(1 => 6, 2 => 6, 3 => 7, 4 => 8, 5 => 3),
	Dict(1 => 8, 2 => 1, 3 => 4                ),
    Dict(1 => 4,                 4 => 8, 5 => 4),
    Dict(        2 => 1,                       ),
    Dict(1 => 9, 2 => 7,         4 => 9        ),
    Dict(1 => 5,         3 => 3, 4 => 6, 5 => 5),
    Dict(        2 => 6, 3 => 8, 4 => 8, 5 => 9)
]

util_table = Dict(1 => 4.0, 2 => 8.0, 3 => 8.0, 4 => 1.0, 5 => 2.0)
min_util = 200.0
huis = Dict(
    Set([5, 4, 3]) => 200.0,
    Set([5, 3, 1]) => 224.0,
    Set([3]) => 224.0,
    Set([5, 2, 3, 1]) => 226.0,

    Set([2, 1]) => 232.0,
    Set([4, 2, 3]) => 232.0,
    Set([5, 3]) => 242.0,
    Set([5, 4, 2, 3]) => 256.0,

    Set([3, 1]) => 256.0,
    Set([2, 3, 1]) => 276.0,
    Set([5, 2, 3]) => 312.0,
    Set([2, 3]) => 312.0
)

(trans -> utility(Set([3, 1]), trans, util_table)).(transactions)


#=
sis = Set{Int64}[Set([3, 1]), Set([5, 2, 3])] #sample(collect(keys(huis)), 2, replace=false)


runtime = @elapsed sanitized_transactions = so2di(transactions, util_table, sis, huis, min_util)
sanitized_huis = efim(sanitized_transactions, util_table, min_util)
se = SideEffects(sis, huis, sanitized_huis, (0.8, 0.1, 0.1), 8)
println("Performance: $(Performance(runtime, se))")


sanitized_transactions = deepcopy(transactions)
nsis_util = filter(x -> !(first(x) in sis), collect(huis))
println("nsis_util = $nsis_util")

for si in sis
    println("\n=====================================")
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

    println("s_tids = $s_tids")
    println("si_util_in_trans = $si_util_in_trans")
    println("si_util = $si_util")

    count_nsis = Dict(item => findall(x -> item in first(x), nsis_util) for item in si)
    item_deleted = argmin(item -> length(count_nsis[item]), keys(count_nsis))
    nsis_related = count_nsis[item_deleted]
    println("count_nsis = $count_nsis")
    println("item_deleted = $item_deleted")
    println("nsis_related = $nsis_related")

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
    println("k = $max_genes_size")

    nsis_util_in_trans = [
        [utility(first(nsis_util[nsi_idx]), sanitized_transactions[tid], util_table) 
            for tid in s_tids]
        for nsi_idx in nsis_related
    ]
    println("nsis_util_in_trans = $nsis_util_in_trans")

    ga = GA(length(s_tids), 5, max_genes_size)
    best_individual, best_fitness = optimize!(
        ga, 
        individual -> fitness(individual, si_util, si_util_in_trans, nsis_util, nsis_util_in_trans, nsis_related, min_util),
        10
    )
    println("best_individual = $best_individual")
    println("best_fitness = $best_fitness")

    for (nsi_idx, nsi_util_in_trans) in zip(nsis_related, nsis_util_in_trans)
        new_utility = nsis_util[nsi_idx][2] - sum(nsi_util_in_trans[idx] for idx in best_individual)
        nsis_util[nsi_idx] = Pair(nsis_util[nsi_idx][1], new_utility)
    end
    filter!(x -> last(x) >= min_util, nsis_util)
    println("|nsis_util| = $(length(nsis_util))")
    println("nsis_util = $nsis_util")

    for idx in best_individual
        delete!(sanitized_transactions[s_tids[idx]], item_deleted)
    end
    println("V* = $([s_tids[idx] for idx in best_individual])")
end
=#