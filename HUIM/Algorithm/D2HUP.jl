# Định nghĩa các cấu trúc dữ liệu
struct UtilityList
    tid::Int
    utility::Int
    remaining_utility::Int
end

struct CAUL
    item::String
    utility_list::Vector{UtilityList}
end

# Hàm tính TWU (Transaction-Weighted Utility)
function calculate_twu(transactions, utility_table)
    twu = Dict{String, Int}()
    for (i, transaction) in enumerate(transactions)
        transaction_utility = sum(get(utility_table, item, 0) * quantity for (item, quantity) in transaction; init=0)
        for item in keys(transaction)
            twu[item] = get(twu, item, 0) + transaction_utility
        end
    end
    return twu
end

# Hàm xây dựng CAUL
function build_caul(transactions, utility_table, twu, min_utility)
    caul_list = CAUL[]
    for (item, item_twu) in sort(collect(twu), by=x->x[2], rev=true)
        if item_twu < min_utility
            break
        end
        utility_list = UtilityList[]
        for (tid, transaction) in enumerate(transactions)
            if haskey(transaction, item)
                utility = transaction[item] * get(utility_table, item, 0)
                remaining_utility = 0
                for (other_item, quantity) in transaction
                    if other_item != item && get(twu, other_item, 0) >= min_utility
                        remaining_utility += get(utility_table, other_item, 0) * quantity
                    end
                end
                push!(utility_list, UtilityList(tid, utility, remaining_utility))
            end
        end
        if !isempty(utility_list)
            push!(caul_list, CAUL(item, utility_list))
        end
    end
    return caul_list
end

# Hàm chính của D2HUP
function d2hup(transactions::Vector{Dict{String, Int}}, utility_table::Dict{String, Int}, min_utility::Int)
    twu = calculate_twu(transactions, utility_table)
    caul_list = build_caul(transactions, utility_table, twu, min_utility)
    hui = Dict{Vector{String}, Int}()
    
    function search(prefix::Vector{String}, caul::CAUL, idx::Int)
        utility = sum(ul.utility for ul in caul.utility_list; init=0)
        if utility >= min_utility
            hui[vcat(prefix, [caul.item])] = utility
        end
        
        if idx < length(caul_list)
            proj_utility = utility + sum(ul.remaining_utility for ul in caul.utility_list; init=0)
            if proj_utility >= min_utility
                for i in (idx+1):length(caul_list)
                    next_caul = caul_list[i]
                    new_utility_list = UtilityList[]
                    for ul in caul.utility_list
                        next_ul = findfirst(x -> x.tid == ul.tid, next_caul.utility_list)
                        if next_ul !== nothing
                            push!(new_utility_list, UtilityList(ul.tid, 
                                                                ul.utility + next_caul.utility_list[next_ul].utility,
                                                                next_caul.utility_list[next_ul].remaining_utility))
                        end
                    end
                    if !isempty(new_utility_list)
                        new_proj_utility = sum(ul.utility + ul.remaining_utility for ul in new_utility_list; init=0)
                        if new_proj_utility >= min_utility
                            search(vcat(prefix, [caul.item]), CAUL(next_caul.item, new_utility_list), i)
                        end
                    end
                end
            end
        end
    end
    
    for i in 1:length(caul_list)
        search(String[], caul_list[i], i)
    end
    
    return Dict(Set(k) => v for (k, v) in hui)
end

# Sử dụng hàm
# transactions = [Dict("A" => 1, "B" => 2, "C" => 3), Dict("B" => 4, "C" => 5, "D" => 6)]
# utility_table = Dict("A" => 5, "B" => 2, "C" => 1, "D" => 2)
# min_utility = 20
# result = d2hup(transactions, utility_table, min_utility)
# println(result)