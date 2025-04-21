include("../../../Data.jl")
"""
mutable struct HI
    # The HI table data structure, each row represents an itemset
    n_rows::UInt32                      # Number of rows (or itemsets) in IT table
    itemsets
    tidsets
end

function deleteat!(table::HI, indxs)
    deleteat!(table.itemsets, indxs)
    deleteat!(table.tidsets, indxs)
    table.n_rows -= length(indxs)
end

function length(table::HI)
    return table.n_rows
end

HI() = HI(0, [], [])
"""
mutable struct IT
    # The IT table data structure, each row represents an itemset
    n_rows::Int64                      # Number of rows (or itemsets) in IT table
    utils::Array{Utility}                 # Util itemsets  
    sizes::Array{Int64}
    itemsets::Array{ItemSet}
    tidsets::Array{Set{Int64}}
end

function deleteat!(table::IT, indxs)
    deleteat!(table.itemsets, indxs)
    deleteat!(table.tidsets, indxs)
    deleteat!(table.utils, indxs)
    deleteat!(table.sizes, indxs)
    table.n_rows -= length(indxs)
end

function length(table::IT)
    return table.n_rows
end

IT() = IT(0, Vector{Utility}(), Vector{Int64}(), Vector{ItemSet}(), Vector{Set{UInt32}}())