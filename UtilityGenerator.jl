include("./Data.jl")
using StatsBase

function gen_ext_util(items::Set{Item}, ext_util_range::StepRangeLen{EUtility})::UtilTable
    mu = mean(log.(ext_util_range))
    sigma = std(log.(ext_util_range))
    pdf = (exp.(- (log.(ext_util_range) .- mu ).^2 ./(2 * sigma^2)) ./ (ext_util_range .* sigma .* sqrt(2*pi)))
    #pdf = pdf / sum(pdf)

    gen = () -> sample(ext_util_range, ProbabilityWeights(pdf))
    return Dict(item => gen() for item in items)
end

function gen_int_util(transactions_no_util::Vector{Set{Item}}, int_util_range::UnitRange{IUtility})::Vector{Transaction}
    gen = () -> rand(int_util_range)
    return (trans -> Dict(item => gen() for item in trans)).(transactions_no_util)
end