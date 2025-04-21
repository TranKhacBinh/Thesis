include("./Data.jl")
using Statistics
using StatsBase

path::String = joinpath(pwd(), "Datasets")

struct DatasetInfo
    name::String
    n_trans::Int
    n_items::Int
    avg_trans_len::Float64
    density::Float64
    int_util_range::Tuple{IUtility, IUtility}
    ext_util_range::Tuple{EUtility, EUtility}
    total_util::Utility
end

function DatasetInfo(name::String, transactions::Vector{Transaction}, util_table::UtilTable)
    items = reduce(union, keys.(transactions))
    @assert items == keys(util_table) "Invalid dataset"

    n_trans = length(transactions)
    n_items = length(items)
    avg_trans_len = round(mean(length.(transactions)), digits=2)
    density = round((avg_trans_len / n_items) * 100, digits=2)
    int_util_range = (x -> (minimum(minimum.(x)), maximum(maximum.(x))))(values.(transactions))
    ext_util_range = (x -> (minimum(x), maximum(x)))(values(util_table))
    total_util = utility(transactions, util_table)

    return DatasetInfo(name, n_trans, n_items, avg_trans_len, density, int_util_range, ext_util_range, total_util)
end

function Base.show(io::IO, di::DatasetInfo)
    println(io, "DatasetInfo:
    name = $(di.name)
    n_trans = $(di.n_trans)
    n_items = $(di.n_items)
    avg_trans_len = $(di.avg_trans_len)
    density = $(di.density)
    int_util_range = $(di.int_util_range)
    ext_util_range = $(di.ext_util_range)
    total_util = $(di.total_util)")
end

struct Dataset
    info::DatasetInfo
    transactions::Vector{Transaction}
    util_table::UtilTable
end

function Dataset(name::String, transactions::Vector{Transaction}, util_table::UtilTable)
    di = DatasetInfo(name, transactions, util_table)
    return Dataset(di, transactions, util_table)
end

function load_transactions(path::String)
    lines = readlines(path)
    return (line -> Dict((strs -> parse(Item, strs[1]) => parse(IUtility, strs[2])).((pair -> split(pair, ":")).(split(line))))).(lines)
end

function load_transactions_no_util(path::String)
    lines = readlines(path)
    return (line -> Set((item -> parse(Item, item)).(split(line)))).(lines)
end

function load_util_table(path::String)
    lines = readlines(path)
    return Dict((line -> (strs -> parse(Item, strs[1]) => parse(EUtility, strs[2]))(split(line, ":"))).(lines))
end

function load_dataset_info(path::String)
    lines = readlines(path)
    return DatasetInfo(eval.(Meta.parse.(lines))...)
end

function load_dataset(ds_name::String)
    ds_path = joinpath(path, ds_name)
    @assert isdir(ds_path) "Dataset does not exist"

    di = load_dataset_info(joinpath(ds_path, "info.txt"))
    @assert di.name == ds_name "Invalid dataset"

    transactions = load_transactions(joinpath(ds_path, "transactions.txt"))
    util_table = load_util_table(joinpath(ds_path, "util_table.txt"))

    return Dataset(di, transactions, util_table)
end

function writelines(lines::Vector{String}, path::String)
    open(path, "w") do file
        (line -> println(file, line)).(lines)
    end
end

function save(transactions::Vector{Transaction}, path::String)
    lines = (trans -> join((pair -> "$(pair[1]):$(pair[2])").(collect(trans)), " ")).(transactions)
    writelines(lines, path)
end

function save(util_table::UtilTable, path::String)
    lines = (pair -> "$(pair[1]):$(pair[2])").(collect(util_table))
    writelines(lines, path)
end

function save(di::DatasetInfo, path::String)
    lines = [repr(getfield(di, field)) for field in fieldnames(DatasetInfo)]
    writelines(lines, path)
end

function save(ds::Dataset)
    ds_path = joinpath(path, ds.info.name)
    if !isdir(ds_path)
        mkdir(ds_path)
    end

    save(ds.info, joinpath(ds_path, "info.txt"))
    save(ds.transactions, joinpath(ds_path, "transactions.txt"))
    save(ds.util_table, joinpath(ds_path, "util_table.txt"))

    huis_path = joinpath(ds_path, "huis")
    if isdir(huis_path)
        rm(huis_path, recursive=true, force=true)
    end
    mkdir(huis_path)
end

function Base.:(==)(a::Dataset, b::Dataset)
    fields = fieldnames(Dataset)
    all(getfield(a, field) == getfield(b, field) for field in fields)
end

function utility(itemset::Union{ItemSet, Vector{Item}}, ds::Dataset)
    return utility(itemset, ds.transactions, ds.util_table)
end

function str_to_pair(str)
    strs = split(str, ":")
    return Set((s -> parse(Item, s)).(split(strs[1]))) => parse(Utility, strs[2])
end

function load_huis(ds_name::String, mut::Float64)
    ds_path = joinpath(path, ds_name)
    @assert isdir(ds_path) "Dataset does not exist"

    huis_path = joinpath(ds_path, "huis", "mut=$(mut)")
    if !isdir(huis_path)
        return nothing
    end

    lines = readlines(joinpath(huis_path, "huis.txt"))
    return Dict((line -> str_to_pair(line)).(lines))
end

function save_huis(ds_name::String, mut::Float64, huis::Dict{ItemSet, Utility})
    ds_path = joinpath(path, ds_name)
    @assert isdir(ds_path) "Dataset does not exist"

    huis_path = joinpath(ds_path, "huis", "mut=$(mut)")
    if isdir(huis_path)
        rm(huis_path, recursive=true, force=true)
    end
    mkdir(huis_path)

    lines = (pair -> "$(join(pair[1], " ")):$(pair[2])").(collect(huis))
    writelines(lines, joinpath(huis_path, "huis.txt"))
end

function load_sis(ds_name::String, mut::Float64, sip::Float64)
    ds_path = joinpath(path, ds_name)
    @assert isdir(ds_path) "Dataset does not exist"

    huis_path = joinpath(ds_path, "huis", "mut=$(mut)")
    @assert isdir(huis_path) "mut=$(mut) does not exist"

    sis_path = joinpath(huis_path, "sip=$(sip).txt")
    if !isfile(sis_path)
        return nothing
    end

    lines = readlines(sis_path)
    return (line -> Set((item -> parse(Item, item)).(split(line)))).(lines)
end

function save_sis(ds_name::String, mut::Float64, sip::Float64, sis::Vector{ItemSet})
    ds_path = joinpath(path, ds_name)
    @assert isdir(ds_path) "Dataset does not exist"

    huis_path = joinpath(ds_path, "huis", "mut=$(mut)")
    @assert isdir(huis_path) "mut=$(mut) does not exist"

    lines = (si -> join(si, " ")).(sis)
    writelines(lines, joinpath(huis_path, "sip=$(sip).txt"))
end


function mine_huis(ds_name::String, mut::Float64, malg::Function)
    ds = load_dataset(ds_name)
    min_util = (ds.info.total_util * mut) / 100
    huis = malg(ds.transactions, ds.util_table, min_util)
    return huis
end

function mine_huis!(ds_name::String, mut::Float64, malg::Function)
    huis = mine_huis(ds_name, mut, malg)
    save_huis(ds_name, mut, huis)
    return huis
end
#=
function mine_huis(ds::Dataset, mut::Float64, malg::Function)
    min_util = (ds.info.total_util * mut) / 100
    huis = malg(ds.transactions, ds.util_table, min_util)
    return huis
end

function mine_huis!(ds::Dataset, mut::Float64, malg::Function)
    huis = mine_huis(ds, mut, malg)
    save_huis(ds_name, mut, huis)
    return huis
end
=#

function gen_sis(huis::Dict{ItemSet, Utility}, sip::Float64)
    return sample(collect(keys(huis)), round(Int, (length(huis) * sip) / 100), replace=false)
end

function gen_sis(ds_name::String, mut::Float64, sip::Float64)
    huis = load_huis(ds_name, mut)
    return gen_sis(huis, sip)
end

function gen_sis!(ds_name::String, mut::Float64, sip::Float64)
    sis = gen_sis(ds_name, mut, sip)
    save_sis(ds_name, mut, sip, sis)
    return sis
end