using StatsBase

mutable struct Particle
    position::BitSet      # Vị trí hiện tại (tập các số)
    velocity_add::BitSet  # Vận tốc - phần tử cần thêm
    velocity_del::BitSet  # Vận tốc - phần tử cần xóa
    pbest::BitSet         # Vị trí tốt nhất cá nhân
    pbest_value::Float64  # Giá trị tốt nhất cá nhân
end

mutable struct DiscretePSO
    particles::Vector{Particle}
    gbest::BitSet         # Vị trí tốt nhất toàn cục
    gbest_value::Float64  # Giá trị tốt nhất toàn cục
    N::Int                # Giới hạn trên của các số
    num_particles::Int    # Số lượng hạt
    #min_particle_size::Int         # Kích thước tối thiểu của hạt
    max_particle_size::Int         # Kích thước tối đa của hạt
    w::Float64            # Trọng số quán tính
    c1::Float64           # Hệ số học cá nhân
    c2::Float64           # Hệ số học xã hội
end

# Hàm khởi tạo hạt ngẫu nhiên
function init_particle(N::Int, max_particle_size::Int)
    # Sinh ngẫu nhiên kích thước của hạt
    k = rand(1:max_particle_size)
    # Sinh ngẫu nhiên k số từ 1 đến N
    position = BitSet(sample(1:N, k, replace=false))
    
    return Particle(
        position,         # position
        BitSet(),         # velocity_add
        BitSet(),         # velocity_del
        position,         # pbest
        Inf,              # pbest_value
    )
end

# Hàm khởi tạo PSO
function DiscretePSO(N::Int, num_particles::Int, w=0.7, c1=2.0, c2=2.0)
    return DiscretePSO(N, num_particles, N, w, c1, c2)
end
function DiscretePSO(N::Int, num_particles::Int, max_particle_size::Int, w=0.7, c1=2.0, c2=2.0)
    @assert 1 <= max_particle_size <= N "Invalid size constraints"
    particles = [init_particle(N, max_particle_size) for _ in 1:num_particles]
    return DiscretePSO(
        particles,
        BitSet(),  # gbest
        Inf,       # gbest_value
        N,
        num_particles,
        #min_particle_size,
        max_particle_size,
        w, c1, c2
    )
end

# Hàm nhân vận tốc với trọng số
function scale_velocity(v::BitSet, w::Float64)
    k = round(Int, w * length(v))
    return k > 0 ? BitSet(sample(collect(v), k, replace=false)) : BitSet()
end

# Hàm cập nhật vận tốc
function update_velocity!(particle::Particle, gbest::BitSet, w::Float64, c1::Float64, c2::Float64)
    # Phần quán tính
    v_add = scale_velocity(particle.velocity_add, w)
    v_del = scale_velocity(particle.velocity_del, w)
    
    #=
    # Phần học từ pbest
    pbest_add = BitSet()
    pbest_del = BitSet()
    if rand() < c1
        pbest_add = setdiff(particle.pbest, particle.position)
        pbest_del = setdiff(particle.position, particle.pbest)
    end
    
    # Phần học từ gbest
    gbest_add = BitSet()
    gbest_del = BitSet()
    if rand() < c2
        gbest_add = setdiff(gbest, particle.position)
        gbest_del = setdiff(particle.position, gbest)
    end
    =#
    pbest_add = setdiff(particle.pbest, particle.position)
    pbest_del = setdiff(particle.position, particle.pbest)
    gbest_add = setdiff(gbest, particle.position)
    gbest_del = setdiff(particle.position, gbest)
    particle.velocity_add = union(v_add, pbest_add, gbest_add)
    particle.velocity_del = union(v_del, pbest_del, gbest_del)
end

# Hàm cập nhật vị trí
function update_position!(particle::Particle, max_particle_size::Int)
    # Xóa các phần tử trong velocity_del
    particle.position = setdiff(particle.position, particle.velocity_del)
    
    # Thêm các phần tử trong velocity_add
    particle.position = union(particle.position, particle.velocity_add)

    if length(particle.position) > max_particle_size
        particle.position = BitSet(sample(collect(particle.position), max_particle_size, replace=false))
    end
end

# Hàm tối ưu hóa
function optimize!(pso::DiscretePSO, objective_func::Function, max_iter::Int)
    for _ in 1:max_iter
        for particle in pso.particles
            # Tính giá trị hàm mục tiêu
            current_value = objective_func(particle.position)
            
            # Cập nhật pbest
            if current_value < particle.pbest_value
                particle.pbest = particle.position
                particle.pbest_value = current_value
                
                # Cập nhật gbest
                if current_value < pso.gbest_value
                    pso.gbest = particle.position
                    pso.gbest_value = current_value
                end
            end
            
            # Cập nhật vận tốc và vị trí
            update_velocity!(particle, pso.gbest, pso.w, pso.c1, pso.c2)
            update_position!(particle, pso.max_particle_size)
        end
    end
    
    return pso.gbest, pso.gbest_value
end