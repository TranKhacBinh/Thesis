include("./Dataset.jl")
include("./HUIM/Algorithm/EFIM.jl")

include("./PPUM/Algorithm/Evolutionary/SO2DI.jl")
include("./PPUM/Algorithm/Heuristic/MSU_MAU.jl")
include("./PPUM/Algorithm/Heuristic/MSU_MIU.jl")
include("./PPUM/Algorithm/ILP/FILP.jl")
include("./PPUM/Algorithm/Evolutionary/PPUMGAT.jl")
#include("./PPUM/Algorithm/ILP/PPUMALO.jl")

include("./HideSIs.jl")
include("./Performance.jl")
include("./Charts/Chart.jl")

using .EFIM

using .SO2DI
using .MSU_MAU
using .MSU_MIU
using .FILP
using .PPUMGAT
#using .PPUMALO

M = 20
max_iterations = 100
w1 = 0.9
w2 = 0.1

so2di(transactions, util_table, sis, huis, min_util) = SO2DI.so2di(transactions, util_table, sis, huis, min_util, M, max_iterations)
ppumgat(transactions, util_table, sis, huis, min_util) = PPUMGAT.ppumgat(transactions, util_table, sis, huis, min_util, M, max_iterations, w1, w2)
#ppumalo(transactions, util_table, sis, huis, min_util) = PPUMALO.ppumalo(transactions, util_table, sis, huis, min_util, M, max_iterations)

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

styles = OrderedDict(
    so2di   => (label="SO2DI",   color=:red,    marker=:star),
    msu_mau => (label="MSU_MAU", color=:blue,   marker=:square),
    msu_miu => (label="MSU_MIU", color=:green,  marker=:diamond),
    filp    => (label="FILP",    color=:orange, marker=:circle),
    ppumgat => (label="PPUMGAT", color=:purple, marker=:cross)
)

halgs = [so2di, msu_mau, msu_miu, filp, ppumgat]


ds_name = "foodmart"
mut = 0.07
sip = 1.0

huis = load_huis(ds_name, mut)
if huis === nothing
	huis = mine_huis!(ds_name, mut, EFIM.efim)
end
sis = load_sis(ds_name, mut, sip)
#sis = gen_sis!(ds_name, mut, sip)

println("ds_name = ", ds_name)
println("|huis| = ", length(huis))
println("|sis| = ", length(sis))

for halg in halgs
    println("\nBegin: $(halg)")
    hide_sis!(ds_name, mut, sip, halg)
    println("===================================")
    println(Performance!(ds_name, mut, sip, halg))
    println("End: $(halg)")
end


#=
test = tests[1]

for mut in test.muts
	if load_huis(test.ds_name, mut) === nothing
		mine_huis!(test.ds_name, mut, EFIM.efim)
	end
	if load_sis(test.ds_name, mut, test.sip) === nothing
		gen_sis!(test.ds_name, mut, test.sip)
	end
	
	for halg in halgs
		hide_sis!(test.ds_name, mut, test.sip, halg)
	end
	println.([Performance!(test.ds_name, mut, test.sip, halg) for halg in halgs])
end

for sip in test.sips
	if load_huis(test.ds_name, test.mut) === nothing
		mine_huis!(test.ds_name, test.mut, EFIM.efim)
	end
	if load_sis(test.ds_name, test.mut, sip) === nothing
		gen_sis!(test.ds_name, test.mut, sip)
	end
	
	for halg in halgs
		hide_sis!(test.ds_name, test.mut, sip, halg)
	end
	println.([Performance!(test.ds_name, test.mut, sip, halg) for halg in halgs])
end

chart(test.ds_name, test.muts, test.sip, styles, "pdf")
chart(test.ds_name, test.mut, test.sips, styles, "pdf")
=#