include("../../../Data.jl")

struct Variables
    n_vrs::UInt32
    coeff::Array{EUtility, 1}    # Coefficent of variables
    original_value::Array{UInt32, 1}
    original_util::Array{Float64, 1}
    poss::Array{Tuple{Int64, Item}}            # Positions of varibales in data

end
mutable struct ConstraintMatrix
    n_constraints::Int64                  # Number of constraintss
    matrix::Array{Float64}               # Array of constraints (not matrix) 
    bounds::Array{Float64}                   # Lower (or upper) bounds of constraints
end

function length(vrs::Variables)
	return vrs.n_vrs
end
function length(matrix::ConstraintMatrix)
    return matrix.n_constraints
end
function size(matrix::ConstraintMatrix)
    return size(matrix.matrix)
end 
