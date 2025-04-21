include("./Dataset.jl")
include("./HUIM/Algorithm/EFIM.jl")

include("./PPUM/Algorithm/Heuristic/MSU_MAU.jl")
include("./PPUM/Algorithm/Heuristic/MSU_MIU.jl")
include("./PPUM/Algorithm/Evolutionary/PPUMGAT.jl")
include("./PPUM/Algorithm/Evolutionary/SO2DI.jl")
include("./PPUM/Algorithm/Evolutionary/SO2DI_v1.jl")
include("./PPUM/Algorithm/ILP/FILP.jl")
#include("./PPUM/Algorithm/ILP/PPUMALO.jl")
include("./PPUM/Algorithm/Evolutionary/GA2DI.jl")
include("./PPUM/Algorithm/Evolutionary/PSO2DI.jl")
include("./PPUM/Algorithm/Evolutionary/ACO2DI.jl")

include("./HideSIs.jl")
include("./Performance.jl")
include("./Charts/Chart.jl")

using .EFIM
using .MSU_MAU
using .MSU_MIU
using .PPUMGAT
using .SO2DI
using .SO2DI_v1
using .FILP
#using .PPUMALO
using .GA2DI
using .PSO2DI
using .ACO2DI

M = 20
max_iterations = 100
w1 = 0.9
w2 = 0.1

ppumgat(transactions, util_table, sis, huis, min_util) = PPUMGAT.ppumgat(transactions, util_table, sis, huis, min_util, M, max_iterations, w1, w2)
so2di(transactions, util_table, sis, huis, min_util) = SO2DI.so2di(transactions, util_table, sis, huis, min_util, M, max_iterations)
so2di_v1(transactions, util_table, sis, huis, min_util) = SO2DI_v1.so2di(transactions, util_table, sis, huis, min_util, M, max_iterations)
#ppumalo(transactions, util_table, sis, huis, min_util) = PPUMALO.ppumalo(transactions, util_table, sis, huis, min_util, M, max_iterations)
ga2di(transactions, util_table, sis, huis, min_util) = GA2DI.ga2di(transactions, util_table, sis, huis, min_util, M, max_iterations)
pso2di(transactions, util_table, sis, huis, min_util) = PSO2DI.pso2di(transactions, util_table, sis, huis, min_util, M, max_iterations)
aco2di(transactions, util_table, sis, huis, min_util) = ACO2DI.aco2di(transactions, util_table, sis, huis, min_util, M, max_iterations)

tests = [
	(ds_name="foodmart", muts=[0.052, 0.054, 0.056, 0.058, 0.06], sip=2.0, mut=0.05, sips=[1.0, 2.0, 3.0, 4.0, 5.0]),
	(ds_name="t25i10d10k", muts=[0.35, 0.36, 0.37, 0.38, 0.39], sip=0.2, mut=0.4, sips=[0.4, 0.6, 0.8, 1.0, 1.2]),
	(ds_name="mushrooms", muts=[8.6, 8.7, 8.8, 8.9, 9.0], sip=0.6, mut=9.0, sips=[0.8, 1.2, 1.6, 2.0, 2.4]),
	(ds_name="chess", muts=[26.0, 26.25, 26.5, 26.75, 27.0], sip=0.5, mut=26.5, sips=[0.7, 0.9, 1.1, 1.3, 1.5]),
	(ds_name="retail", muts=[0.03, 0.035, 0.04, 0.045, 0.05], sip=0.2, mut=0.05, sips=[0.6, 0.7, 0.8, 0.9, 1.0]),
	(ds_name="t20i6d100k", muts=[0.28, 0.29, 0.30, 0.31, 0.32], sip=2.0, mut=0.32, sips=[4.0, 5.5, 7.0, 8.5, 10.0]),
	(ds_name="pumsb", muts=[19.4, 19.5, 19.6, 19.7, 19.8], sip=2.0, mut=20.0, sips=[3.0, 5.0, 7.0, 9.0, 11.0]),
	(ds_name="connect", muts=[28.6, 28.8, 29.0, 29.2, 29.4], sip=1.0, mut=29.5, sips=[1.0, 1.5, 2.0, 2.5, 3.0])
]
ds_name = "foodmart"
mut = 0.05
sip = 5.0

println("ds_name = ", ds_name)
println("|huis| = ", length(load_huis(ds_name, mut)))
println("|sis| = ", length(load_sis(ds_name, mut, sip)))

halgs = [so2di, so2di_v1, ga2di, aco2di]
for halg in halgs
    println("\nBegin: $(halg)")

    ds = load_dataset(ds_name)
    huis = load_huis(ds_name, mut)
    sis = load_sis(ds_name, mut, sip)
    min_util = (ds.info.total_util * mut) / 100
	runtime = @elapsed sanitized_transactions = halg(ds.transactions, ds.util_table, sis, huis, min_util)

    println("===================================")

    sanitized_huis = Dict{ItemSet, Utility}()
    for itemset in keys(huis)
        util = utility(itemset, sanitized_transactions, ds.util_table)
        if util >= min_util
            sanitized_huis[itemset] = util
        end
    end
    se = SideEffects(sis, huis, sanitized_huis, (0.8, 0.1, 0.1), 8)
    println(Performance(runtime, se))

    println("End: $(halg)")
end


#=
for halg in halgs
    println("\nBegin: $(halg)")

	hide_sis!(ds_name, mut, sip, halg)
    println("============")
    #println(Performance!(ds_name, mut, sip, halg))

    output_path = joinpath(pwd(), "Outputs", ds_name, "mut=$(mut)", "sip=$(sip)", "halg=$(halg)")
    @assert isdir(output_path) "Output does not exist"

    runtime = parse(Float64, readlines(joinpath(output_path, "runtime.txt"))[1])
    sanitized_transactions = load_transactions(joinpath(output_path, "sanitized_transactions.txt"))

    sanitized_huis = Dict{ItemSet, Utility}()
    for itemset in keys(huis)
        util = utility(itemset, sanitized_transactions, ds.util_table)
        if util >= min_util
            sanitized_huis[itemset] = util
        end
    end

    se = SideEffects(sis, huis, sanitized_huis, 8)
    perf = Performance(runtime, se)

    perfs = load_performances()
    add!(perfs, ds_name, mut, sip, "$(halg)", perf)
    save(perfs)

    println(perf)

    println("End: $(halg)")
end
=#