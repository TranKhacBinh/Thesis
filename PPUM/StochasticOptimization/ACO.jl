using StatsBase

mutable struct Solution
    elements::Vector{Int}
    obj_value::Float64
end

struct ACO
    N::Int                          # Kích thước tập S = {1,2,...,N}
    n_ants::Int                     # Số lượng kiến
    k::Int                          # Kích thước tối đa của tập con
    alpha::Float64                  # Hệ số quan trọng của pheromone
    beta::Float64                   # Hệ số quan trọng của thông tin heuristic
    rho::Float64                    # Tốc độ bay hơi pheromone
    Q::Float64                      # Hằng số cập nhật pheromone
    pheromones::Vector{Float64}     # Ma trận pheromone
    k_probs::Vector{Float64}        # Xác suất để tính k
end

function ACO(N, n_ants, alpha=1.0, beta=2.0, rho=0.1, Q=1.0)
    return ACO(N, n_ants, N, alpha, beta, rho, Q)
end
function ACO(N, n_ants, k, alpha=1.0, beta=2.0, rho=0.1, Q=1.0)
    @assert 1 <= k <= N "Invalid size constraints"
    pheromones = fill(1.0, N)
    k_probs = fill(1.0, k)

    return ACO(N, n_ants, k, alpha, beta, rho, Q, pheromones, k_probs)
end

function construct_solution(aco::ACO, probs::Vector{Float64})
    n_element = sample(1:aco.k, ProbabilityWeights(aco.k_probs))
    elements = sample(
        1:aco.N,
        ProbabilityWeights(probs),
        n_element,
        replace=false
    )

    return elements
end

function update_pheromone!(aco::ACO, solutions::Vector{Solution})
    # Bay hơi pheromone
    aco.pheromones .*= (1 - aco.rho)
    aco.k_probs .*= (1 - aco.rho)

    # Tăng cường pheromone dựa trên lời giải của các con kiến
    for solution in solutions
        # Tránh chia cho 0 nếu hàm mục tiêu trả về 0
        deposit = (solution.obj_value == 0) ? aco.Q : aco.Q / solution.obj_value
        for i in solution.elements
            aco.pheromones[i] += deposit
        end
        aco.k_probs[length(solution.elements)] += deposit
    end
end

function optimize(aco::ACO, objective_func::Function, max_iter::Int, early_stop_iter=nothing, verbose=false)
    # Khởi tạo heuristic cho mỗi phần tử: heuristic(i) = 1 / f({i})
    # (thêm epsilon nhỏ để tránh chia cho 0)
    epsilon = 1e-6
    heuristics = [1.0/(objective_func([i]) + epsilon) for i in 1:aco.N]
    
    solutions = Vector{Solution}(undef, aco.n_ants)
    best_solution = Solution([], Inf)

    # Biến dừng sớm
    iter_no_impr = 0
    
    for iter in 1:max_iter
        # Xác suất chọn phần tử
        probs = (aco.pheromones.^aco.alpha) .* (heuristics.^aco.beta)

        for ant in 1:aco.n_ants
            elements = construct_solution(aco, probs)
            obj_value = objective_func(elements)
            solutions[ant] = Solution(elements, obj_value)
            
            if obj_value < best_solution.obj_value
                best_solution = solutions[ant]
                iter_no_impr = 0
            end
        end
        update_pheromone!(aco, solutions)

        iter_no_impr += 1
        if !isnothing(early_stop_iter) && iter_no_impr >= early_stop_iter
            if verbose
                println("Early stopping at iteration $iter")
            end
            break
        end
    end
    
    return best_solution.elements, best_solution.obj_value
end