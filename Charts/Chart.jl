include("../Performance.jl")

using Plots
using StatsPlots
using DataStructures

function line_chart(x_value::Vector{Float64}, y_values::Dict{String, Vector{Float64}},
                    styles::OrderedDict{Function, NamedTuple{(:label, :color, :marker), Tuple{String, Symbol, Symbol}}},
                    title::String, xlabel::String, ylabel::String)

    p = plot(title=title, xlabel=xlabel, ylabel=ylabel, #yscale=:log10, 
            legend=true, xticks=x_value, label_ordering=collect(keys(styles))) #, titlefont=font(10), guidefont=font(8), tickfont=font(6))
    
    for (halg, style) in pairs(styles)
        plot!(p, x_value, y_values["$halg"], label=style.label, color=style.color, marker=style.marker,
            markersize=4, linewidth=2)
    end
    
    return p
end

function chart(ds_name::String, muts::Vector{Float64}, sip::Float64,
               styles::OrderedDict{Function, NamedTuple{(:label, :color, :marker), Tuple{String, Symbol, Symbol}}},
               format::String="svg")

    runtimes = load_runtimes(ds_name, muts, sip)
    HFs = load_side_effects(ds_name, muts, sip, "HF")
    MCs = load_side_effects(ds_name, muts, sip, "MC")
    ACs = load_side_effects(ds_name, muts, sip, "AC")
    HCs = load_side_effects(ds_name, muts, sip, "HC")

    for vec in values(HFs)
        vec .*= 100
    end
    for vec in values(MCs)
        vec .*= 100
    end
    for vec in values(ACs)
        vec .*= 100
    end
    for vec in values(HCs)
        vec .*= 100
    end

    p1 = line_chart(muts, runtimes, styles, "$(ds_name) (SIP: $(sip)%)", "Minimum Utility Threshold (%)", "Running Time (sec.)")
    p2 = line_chart(muts, HFs, styles, "$(ds_name) (SIP: $(sip)%)", "Minimum Utility Threshold (%)", "Hiding Failure (%)")
    p3 = line_chart(muts, MCs, styles, "$(ds_name) (SIP: $(sip)%)", "Minimum Utility Threshold (%)", "Missing Cost (%)")
    p4 = line_chart(muts, ACs, styles, "$(ds_name) (SIP: $(sip)%)", "Minimum Utility Threshold (%)", "Artificial Cost (%)")
    p5 = line_chart(muts, HCs, styles, "$(ds_name) (SIP: $(sip)%)", "Minimum Utility Threshold (%)", "Hiding Cost (%)")

    path = joinpath(pwd(), "Charts", "$ds_name")
    if !ispath(path)
        mkpath(path)
    end
    savefig(p1, joinpath(path, "runtime1.$(format)"))
    savefig(p2, joinpath(path, "HF1.$(format)"))
    savefig(p3, joinpath(path, "MC1.$(format)"))
    savefig(p4, joinpath(path, "AC1.$(format)"))
    savefig(p5, joinpath(path, "HC1.$(format)"))
end

function chart(ds_name::String, mut::Float64, sips::Vector{Float64},
               styles::OrderedDict{Function, NamedTuple{(:label, :color, :marker), Tuple{String, Symbol, Symbol}}},
               format::String="svg")

    runtimes = load_runtimes(ds_name, mut, sips)
    HFs = load_side_effects(ds_name, mut, sips, "HF")
    MCs = load_side_effects(ds_name, mut, sips, "MC")
    ACs = load_side_effects(ds_name, mut, sips, "AC")
    HCs = load_side_effects(ds_name, mut, sips, "HC")

    for vec in values(HFs)
        vec .*= 100
    end
    for vec in values(MCs)
        vec .*= 100
    end
    for vec in values(ACs)
        vec .*= 100
    end
    for vec in values(HCs)
        vec .*= 100
    end

    p1 = line_chart(sips, runtimes, styles, "$(ds_name) (MUT: $(mut)%)", "Sensitive Information Percentage (%)", "Running Time (sec.)")
    p2 = line_chart(sips, HFs, styles, "$(ds_name) (MUT: $(mut)%)", "Sensitive Information Percentage (%)", "Hiding Failure (%)")
    p3 = line_chart(sips, MCs, styles, "$(ds_name) (MUT: $(mut)%)", "Sensitive Information Percentage (%)", "Missing Cost (%)")
    p4 = line_chart(sips, ACs, styles, "$(ds_name) (MUT: $(mut)%)", "Sensitive Information Percentage (%)", "Artificial Cost (%)")
    p5 = line_chart(sips, HCs, styles, "$(ds_name) (MUT: $(mut)%)", "Sensitive Information Percentage (%)", "Hiding Cost (%)")

    path = joinpath(pwd(), "Charts", "$ds_name")
    if !ispath(path)
        mkpath(path)
    end
    savefig(p1, joinpath(path, "runtime2.$(format)"))
    savefig(p2, joinpath(path, "HF2.$(format)"))
    savefig(p3, joinpath(path, "MC2.$(format)"))
    savefig(p4, joinpath(path, "AC2.$(format)"))
    savefig(p5, joinpath(path, "HC2.$(format)"))
end