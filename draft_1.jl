include("./Dataset.jl")
include("./HUIM/Algorithm/EFIM.jl")

include("./PPUM/Algorithm/Heuristic/MSU_MAU.jl")
include("./PPUM/Algorithm/Heuristic/MSU_MIU.jl")
include("./PPUM/Algorithm/Evolutionary/PPUMGAT.jl")
include("./PPUM/Algorithm/Evolutionary/SO2DI.jl")
include("./PPUM/Algorithm/ILP/FILP.jl")

include("./HideSIs.jl")
include("./Performance.jl")
include("./Charts/Chart.jl")

using .EFIM

using .MSU_MAU
using .MSU_MIU
using .PPUMGAT
using .SO2DI
using .FILP

M = 20
max_iterations = 100
w1 = 0.9
w2 = 0.1

ppumgat(transactions, util_table, sis, huis, min_util) = PPUMGAT.ppumgat(transactions, util_table, sis, huis, min_util, M, max_iterations, w1, w2)
so2di(transactions, util_table, sis, huis, min_util) = SO2DI.so2di(transactions, util_table, sis, huis, min_util, M, max_iterations)

#=
ds_name = "chess"
muts = [26.0, 26.25, 26.5, 26.75, 27.0]
sip = 0.5                                     #     filp: chạy bước giải không ra
mut = 26.5
sips = [0.7, 0.9, 1.1, 1.3, 1.5]
=#

#=
ds_name = "connect"
muts = [28.6, 28.8, 29.0, 29.2, 29.4]
sip = 1.0									#   filp: thuật toán chạy thành công (lâu), nhưng không khai thác được
mut = 29.5
sips = [1.0, 1.5, 2.0, 2.5, 3.0]
=#

#=
ds_name = "foodmart"
muts = [0.052, 0.054, 0.056, 0.058, 0.06]
sip = 2.0
mut = 0.05
sips = [1.0, 2.0, 3.0, 4.0, 5.0]
=#

#=
ds_name = "mushrooms"
muts = [8.6, 8.7, 8.8, 8.9, 9.0]
sip = 0.6
mut = 9.0
sips = [0.8, 1.2, 1.6, 2.0, 2.4]
=#

#=
ds_name = "pumsb"
muts = [19.4, 19.5, 19.6, 19.7, 19.8]
sip = 2.0               					#   filp: thuật toán chạy thành công, nhưng không khai thác được
mut = 20.0
sips = [3.0, 5.0, 7.0, 9.0, 11.0]
=#

#=
ds_name = "retail"
muts = [0.03, 0.035, 0.04, 0.045, 0.05]
sip = 0.2
mut = 0.05
sips = [0.6, 0.7, 0.8, 0.9, 1.0]
=#

#=
ds_name = "t20i6d100k"
muts = [0.28, 0.29, 0.30, 0.31, 0.32]
sip = 2.0
mut = 0.32
sips = [4.0, 5.5, 7.0, 8.5, 10.0]
=#

#=
ds_name = "t25i10d10k"
muts = [0.35, 0.36, 0.37, 0.38, 0.39]
sip = 0.2
mut = 0.4
sips = [0.4, 0.6, 0.8, 1.0, 1.2]
=#




styles = OrderedDict(
    so2di   => (label="SO2DI",   color=:red,    marker=:star),
    msu_mau => (label="MSU_MAU", color=:blue,   marker=:square),
    msu_miu => (label="MSU_MIU", color=:green,  marker=:diamond),
    filp    => (label="FILP",    color=:orange, marker=:circle),
    ppumgat => (label="PPUMGAT", color=:purple, marker=:cross)
)

ds_name = "chess"
muts = [26.0, 26.25, 26.5, 26.75, 27.0]
sip = 0.5                                     #     filp: chạy bước giải không ra
mut = 26.5
sips = [0.7, 0.9, 1.1, 1.3, 1.5]

#chart(ds_name, muts, sip, styles, "pdf")
#chart(ds_name, mut, sips, styles, "pdf")

halgs = [msu_mau, msu_miu, so2di, filp, ppumgat]
runtimes = load_runtimes(ds_name, muts, sip)
Dict(halg => mean(times) for (halg, times) in runtimes)


 #= 
  "filp"    => 1.03041
  "ppumgat" => 5.99454
  "so2di"   => 0.492965
  "msu_mau" => 0.0109784
  "msu_miu" => 0.0126993

  "filp"    => 34.5369
  "ppumgat" => 0.90233
  "so2di"   => 0.203336
  "msu_mau" => 0.0105175
  "msu_miu" => 0.0166419

  "filp"    => 124.93
  "ppumgat" => 4.51715
  "so2di"   => 0.20839
  "msu_mau" => 0.140177
  "msu_miu" => 0.149162

  "ppumgat" => 6.62197
  "so2di"   => 0.923292
  "msu_mau" => 0.0488477
  "msu_miu" => 0.0816141
=#



#=
ds_name = "mushrooms"
muts = [8.6, 8.7, 8.8, 8.9, 9.0]
sip = 0.6
mut = 9.0
sips = [0.8, 1.2, 1.6, 2.0, 2.4]

for mut in muts
	#=
	if load_huis(ds_name, mut) === nothing
		mine_huis!(ds_name, mut, EFIM.efim)
	end
	if load_sis(ds_name, mut, sip) === nothing
		gen_sis!(ds_name, mut, sip)
	end
	=#
	for halg in halgs
		hide_sis!(ds_name, mut, sip, halg)
	end
	println([Performance!(ds_name, mut, sip, halg) for halg in halgs])
end

chart(ds_name, muts, sip, styles, "svg")

for sip in sips
	#=
	if load_huis(ds_name, mut) === nothing
		mine_huis!(ds_name, mut, EFIM.efim)
	end
	if load_sis(ds_name, mut, sip) === nothing
		gen_sis!(ds_name, mut, sip)
	end
	=#
	for halg in halgs
		hide_sis!(ds_name, mut, sip, halg)
	end
	println([Performance!(ds_name, mut, sip, halg) for halg in halgs])
end

chart(ds_name, mut, sips, styles, "svg")
=#