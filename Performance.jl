include("./Dataset.jl")
include("./PPUM/SideEffects.jl")
include("./HUIM/Algorithm/EFIM.jl")

using JSON
using .EFIM

performances_path = joinpath(pwd(), "Performances.json")

struct Performance
    runtime::Float64
    side_effects::SideEffects
end

function Performance(ds_name::String, mut::Float64, sip::Float64, halg::Function, ac::Bool=false, dig::Int=8, malg::Function=EFIM.efim)
    output_path = joinpath(pwd(), "Outputs", ds_name, "mut=$(mut)", "sip=$(sip)", "halg=$(halg)")
    @assert isdir(output_path) "Output does not exist"

    runtime = parse(Float64, readlines(joinpath(output_path, "runtime.txt"))[1])
    sanitized_transactions = load_transactions(joinpath(output_path, "sanitized_transactions.txt"))
    ds = load_dataset(ds_name)
    huis = load_huis(ds_name, mut)
    sis = load_sis(ds_name, mut, sip)

    min_util = ifelse(ac, (utility(sanitized_transactions, ds.util_table) * mut) / 100, (ds.info.total_util * mut) / 100)
    sanitized_huis = malg(sanitized_transactions, ds.util_table, min_util)
    se = SideEffects(sis, huis, sanitized_huis, (0.8, 0.1, 0.1), dig)

    return Performance(runtime, se)
end

function Performance!(ds_name::String, mut::Float64, sip::Float64, halg::Function, ac::Bool=false, dig::Int=8, malg::Function=EFIM.efim)
    perf = Performance(ds_name, mut, sip, halg, ac, dig, malg)

    perfs = load_performances()
    add!(perfs, ds_name, mut, sip, "$(halg)", perf)
    save(perfs)

    return perf
end

Performances = Dict{String, Dict{Float64, Dict{Float64, Dict{String, Performance}}}}

function add!(perfs::Performances, ds_name::String, mut::Float64, sip::Float64, halg::String, perf::Performance)
    if !haskey(perfs, ds_name)
        perfs[ds_name] = Dict{Float64, Dict{Float64, Dict{String, Performance}}}()
    end

    if !haskey(perfs[ds_name], mut)
        perfs[ds_name][mut] = Dict{Float64, Dict{String, Performance}}()
    end

    if !haskey(perfs[ds_name][mut], sip)
        perfs[ds_name][mut][sip] = Dict{String, Performance}()
    end

    perfs[ds_name][mut][sip][halg] = perf
end

function load_performances()
    data = open(performances_path, "r") do io
        JSON.parse(io)
    end
    perfs = Performances()

    for (ds_name, mut_data) in data
        for (mut, sip_data) in mut_data
            for (sip, halg_data) in sip_data
                for (halg, perf) in halg_data
                    converted_perf = Performance(perf["runtime"], SideEffects(perf["side_effects"]["HF"], perf["side_effects"]["MC"], perf["side_effects"]["AC"], perf["side_effects"]["HC"]))
                    add!(perfs, ds_name, parse(Float64, mut), parse(Float64, sip), halg, converted_perf)
                end
            end
        end
    end

    return perfs
end

function load_runtimes(ds_name::String, muts::Vector{Float64}, sip::Float64)
    data = open(performances_path, "r") do io
        JSON.parse(io)
    end
    runtimes = Dict{String, Vector{Float64}}()

    for (i, mut) in enumerate(muts)
        for (halg, perf) in data[ds_name]["$(mut)"]["$(sip)"]
            if !haskey(runtimes, halg)
                runtimes[halg] = Vector{Float64}(undef, length(muts))
            end
            runtimes[halg][i] = perf["runtime"]
        end
    end
    
    return runtimes
end

function load_runtimes(ds_name::String, mut::Float64, sips::Vector{Float64})
    data = open(performances_path, "r") do io
        JSON.parse(io)
    end
    runtimes = Dict{String, Vector{Float64}}()

    for (i, sip) in enumerate(sips)
        for (halg, perf) in data[ds_name]["$(mut)"]["$(sip)"]
            if !haskey(runtimes, halg)
                runtimes[halg] = Vector{Float64}(undef, length(sips))
            end
            runtimes[halg][i] = perf["runtime"]
        end
    end
    
    return runtimes
end

function load_side_effects(ds_name::String, muts::Vector{Float64}, sip::Float64, field::String)
    data = open(performances_path, "r") do io
        JSON.parse(io)
    end
    fields = Dict{String, Vector{Float64}}()

    for (i, mut) in enumerate(muts)
        for (halg, perf) in data[ds_name]["$(mut)"]["$(sip)"]
            if !haskey(fields, halg)
                fields[halg] = Vector{Float64}(undef, length(muts))
            end
            fields[halg][i] = perf["side_effects"][field]
        end
    end
    
    return fields
end

function load_side_effects(ds_name::String, mut::Float64, sips::Vector{Float64}, field::String)
    data = open(performances_path, "r") do io
        JSON.parse(io)
    end
    fields = Dict{String, Vector{Float64}}()

    for (i, sip) in enumerate(sips)
        for (halg, perf) in data[ds_name]["$(mut)"]["$(sip)"]
            if !haskey(fields, halg)
                fields[halg] = Vector{Float64}(undef, length(sips))
            end
            fields[halg][i] = perf["side_effects"][field]
        end
    end
    
    return fields
end

function save(perfs::Performances)
    open(performances_path, "w") do io
        JSON.print(io, perfs, 4)
    end
end