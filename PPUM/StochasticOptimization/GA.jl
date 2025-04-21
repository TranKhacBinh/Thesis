using StatsBase

Individual = BitSet

mutable struct GA
    populations::Vector{Individual} # Quần thể
    N::Int                          # Số tự nhiên từ 1 đến N
    population_size::Int            # Số cá thể trong quần thể
    max_genes_size::Int             # Kích thước tối đa của genes
    mutation_rate::Float64          # Tỷ lệ đột biến        
end

# Hàm khởi tạo cá thể ngẫu nhiên
function init_individual(N::Int, max_genes_size::Int)
    k = rand(1:max_genes_size)
    genes = sample(1:N, k, replace=false)
    
    return Individual(genes)
end

# Hàm khởi tạo GA
function GA(N::Int, population_size::Int, mutation_rate::Float64=0.2)
    GA(N, population_size, N, mutation_rate)
end
function GA(N::Int, population_size::Int, max_genes_size::Int, mutation_rate::Float64=0.2)
    @assert 1 <= max_genes_size <= N "Invalid size constraints"
    populations = [init_individual(N, max_genes_size) for _ in 1:population_size]

    return GA(populations, N, population_size, max_genes_size, mutation_rate)
end

# Hàm lai ghép hai cá thể
function crossover1(parent1::Individual, parent2::Individual, max_genes_size::Int)
    offspring_genes = union(parent1, parent2)

    if length(offspring_genes) > max_genes_size
        offspring_genes = sample(collect(offspring_genes), max_genes_size, replace=false)
    end

    return Individual(offspring_genes)
end

# Hàm lai ghép hai cá thể
function crossover2(parent1::Individual, parent2::Individual, max_genes_size::Int)
    # Tạo giao của hai tập gen từ cha và mẹ
    offspring_genes = intersect(parent1, parent2)
    
    # Các gen có trong cha hoặc mẹ nhưng không chung
    unique_parent_genes = symdiff(parent1, parent2)

    # Chỉ chọn ngẫu nhiên gen từ unique_parent_genes nếu nó không rỗng
    if !isempty(unique_parent_genes)
        selected_genes = sample(collect(unique_parent_genes), rand(1:length(unique_parent_genes)), replace=false)
        union!(offspring_genes, selected_genes)
    end

    # Đảm bảo kích thước genes con không vượt quá giới hạn
    if length(offspring_genes) > max_genes_size
        offspring_genes = sample(collect(offspring_genes), max_genes_size, replace=false)
    end

    # Trả về cá thể mới với fitness mặc định Inf (sẽ được tính sau)
    return Individual(offspring_genes)
end

# Hàm đột biến ngẫu nhiên
function mutate!(individual::Individual, max_genes_size::Int, mutation_rate::Float64, N::Int)
    if rand() < mutation_rate
        if length(individual) > 1 && rand(Bool)
            # Loại bỏ phần tử ngẫu nhiên nếu có nhiều hơn một phần tử
            delete!(individual, rand(individual))
        elseif length(individual) < max_genes_size
            # Thêm phần tử ngẫu nhiên nếu còn chỗ trống
            push!(individual, rand(setdiff(1:N, individual)))
        end
    end
end

# Hàm tối ưu hóa
function optimize!(ga::GA, objective_func::Function, num_generations::Int)
    best_individual = nothing
    best_fitness = Inf
    num_elites = div(ga.population_size, 2)

    for _ in 1:num_generations
        fitnesses = objective_func.(ga.populations)
        elites_indices = partialsortperm(fitnesses, 1:num_elites)

        # Cập nhật best_individual
        if fitnesses[elites_indices[1]] < best_fitness
            best_individual = ga.populations[elites_indices[1]]
            best_fitness = fitnesses[elites_indices[1]]
        end

        new_populations = Vector{Individual}(undef, ga.population_size)

        # Lai ghép các cá thể tinh hoa
        for idx in 1:num_elites
            parent1 = ga.populations[elites_indices[rand(1:num_elites)]]
            parent2 = ga.populations[elites_indices[rand(1:num_elites)]]
            new_populations[idx] = crossover2(parent1, parent2, ga.max_genes_size)
            mutate!(new_populations[idx], ga.max_genes_size, ga.mutation_rate, ga.N)
        end

        # Thay thế phần còn lại bằng cá thể ngẫu nhiên
        for idx in (num_elites + 1):ga.population_size
            new_populations[idx] = init_individual(ga.N, ga.max_genes_size)
        end

        ga.populations = new_populations
    end
    
    return best_individual, best_fitness
end