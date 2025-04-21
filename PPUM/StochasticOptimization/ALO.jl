using StatsBase

struct MetaHeuristicAlgo
    name::String
    maxima::Bool
    n_iterations::UInt32
    max_iterations::UInt32 #Early stopping
    dim::UInt32
    lb::Vector
    ub::Vector
end
MetaHeuristicAlgo(name, maxima, n_iterations, dim, lb, ub) = MetaHeuristicAlgo(name, maxima, n_iterations, 20, dim, lb, ub)

mutable struct AntLion
    n_ants::UInt32
    ants::Matrix{Int64}
    elite::Vector
end
AntLion() = AntLion(undef, undef, undef)
function AntLion(n_ants::Integer, dim::Integer, lb, ub)
    ants = reshape([rand(lb[i]:ub[i]) for i in 1:dim for j in 1:n_ants], (dim, n_ants))
    elite = ants[:,1]
    swarm = AntLion(n_ants, ants, elite)
    return swarm
end
function AntLion(n_ants::Integer, elite::Vector, dim::Integer, lb, ub)
    ants = reshape([rand(lb[i]:ub[i]) for i in 1:dim for j in 1:(n_ants-1)], (dim, (n_ants-1)))
    ants = hcat(ants, elite)
    swarm = AntLion(n_ants, ants, elite)
    return swarm
end

struct ALO
    algo::MetaHeuristicAlgo
    swarm::AntLion
end
function ALO(max_iteration, n_ants, dim, lb, ub, maxima=true, elite=nothing)
    if elite === nothing 
        swarm = AntLion(n_ants, dim, lb, ub)  
    else
        swarm = AntLion(n_ants, elite, dim, lb, ub)
    end
    algo = MetaHeuristicAlgo("Antlion Optimizer", maxima, max_iteration, dim, lb, ub)
    return ALO(algo, swarm)
end

function antlion_random_walk(ant, iter, n_iterations, dim, lb, ub)
    I = 1
    if iter > (n_iterations/10)
        I = 1 + 100 * (iter/n_iterations)
    end
    if iter > (n_iterations/2)
        I = 1 + 1000 * (iter/n_iterations)
    end
    if iter > n_iterations * (3/4)
        I = 1 + 10000 * (iter/n_iterations)
    end
    if iter > n_iterations * 0.9
        I = 1 + 100000 * (iter/n_iterations)
    end
    if iter > n_iterations * 0.95
        I = 1 + 1000000 * (iter/n_iterations)
    end

    # Sliding ants towards antlion
    lb = lb / I
    ub = ub / I

    # Trapping in antlion’s pits
    rand()<0.5 ? lb = lb .+ ant : lb = -lb .+ ant
    rand()<0.5 ? ub = ub .+ ant : ub = -ub .+ ant

    X = reduce(hcat,([cumsum(2 .* (rand(n_iterations) .> 0.5) .- 1) for _ in 1:dim]))
    a = minimum(X, dims=1)
    b = maximum(X, dims=1)
    c = reshape(lb, (1,dim)) # [a b] - -->[c d]
    d = reshape(ub, (1,dim)) # [a b] - -->[c d]
    t1 = (d - c) ./ (b - a)
    t2 = X .- a
    X_norm = t2 .* t1 .+ c
    #X_norm = ((X - a) * (d - c)) / (b - a) + c

    return X_norm
end
function roulette(list_fitness)
    s = sum(list_fitness)
    if s == 0 return 1 end
    pmf = (list_fitness / s)
    return sample(1:length(list_fitness), ProbabilityWeights(pmf))
end
function Evolve!(swarm::AntLion, f::Function, args, iter, n_iterations, dim, lb, ub, maxima=true)
    new_ants = []
    list_fitness = [f(swarm.ants[:,idx], args) for idx in 1:swarm.n_ants]
    for idx in 1:swarm.n_ants
        # Select ant lions based on their fitness
        antlion_idx = roulette(list_fitness)

        # random walk around the selected antlion
        Rₐ = antlion_random_walk(swarm.ants[antlion_idx], iter, n_iterations, dim, lb, ub)

        # random walk around the elite
        Rₑ = antlion_random_walk(swarm.elite, iter, n_iterations, dim, lb, ub)

        ant = (Rₐ[iter,:] + Rₑ[iter,:]) ./ 2
        new = [ floor(Int,x) for x in ant]
        new  = clamp.(new, lb, ub)
        swarm.ants = hcat(swarm.ants, new)
        push!(list_fitness,f(new,args))
    end
    if maxima == true
        perm = sortperm(list_fitness, rev=true)
    else
        perm = sortperm(list_fitness, rev=false)
        old = swarm.elite
    end
    swarm.ants = swarm.ants[:,perm[1:swarm.n_ants]]
    swarm.elite = swarm.ants[:,1]
end
function optimize!(optimizer::ALO, f::Function, args)
    swarm = optimizer.swarm
    algo  = optimizer.algo
    dim = algo.dim
    lb = algo.lb
    ub = algo.ub
    n_iterations = algo.n_iterations
    maxima = algo.maxima
    count = 0
    ϵ = 10^-8
    for iter in 1:n_iterations
        elite = swarm.elite
        Evolve!(swarm,f, args, iter, n_iterations, dim, lb, ub, maxima)
        new_elite =  swarm.elite
        if sum(abs.(elite .- new_elite)) < ϵ 
            count+=1
        end
        if count == algo.max_iterations
            break;
        end
    end

    return optimizer.swarm.elite
end