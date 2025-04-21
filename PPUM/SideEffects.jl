include("../Data.jl")

struct SideEffects
    HF::Float64
    MC::Float64
    AC::Float64
    HC::Float64
end

function Base.show(io::IO, se::SideEffects)
    print(io, "SideEffects(HF=$(se.HF), MC=$(se.MC), AC=$(se.AC), HC=$(se.HC))")
end

function SideEffects(sis::Vector{ItemSet}, huis::Dict{ItemSet, Utility}, sanitized_huis::Dict{ItemSet, Utility}, w::Tuple{Float64, Float64, Float64}, dig::Int = 8)
    h = Set(keys(huis))
    sanitized_h = Set(keys(sanitized_huis))
    sis = Set(sis)
    nsis = setdiff(h, sis)

    HF = hiding_failure(sis, sanitized_h, dig)
    MC = missing_cost(nsis, sanitized_h, dig)
    AC = artificial_cost(h, sanitized_h, nsis, dig)
    HC = round(w[1] * HF + w[2] * MC + w[3] * AC, digits=dig)

    return SideEffects(HF, MC, AC, HC)
end

function hiding_failure(sis::Set{ItemSet}, sanitized_h::Set{ItemSet}, dig::Int)
    round(length(intersect(sis, sanitized_h)) / length(sis), digits=dig)
end

function missing_cost(nsis::Set{ItemSet}, sanitized_h::Set{ItemSet}, dig::Int)
    round(length(setdiff(nsis, sanitized_h)) / length(nsis), digits=dig)
end

function artificial_cost(h::Set{ItemSet}, sanitized_h::Set{ItemSet}, nsis::Set{ItemSet}, dig::Int)
    round(length(setdiff(sanitized_h, h)) / length(nsis), digits=dig)
end