module HUI_Miner
    include("../../Data.jl")
    using DataStructures

    export hui_miner

    struct Element
        iutils::Utility
        rutils::Utility
    end

    mutable struct Data  
        t_iutils::Utility
        t_rutils::Utility

        tidset:: Set{Int64}
        elements::Dict{Int64, Element}
        prune::Bool
    end
    mutable struct UtilityList
        prefix_util::Any
        prefix::Vector{Item}
        data::OrderedDict{Item, Data}
        
    end
    Data() = Data(0, 0, Set{Int64}(), Dict{Int64,Element}(), false)
    UtilityList()=UtilityList(nothing,[],OrderedDict{Item,Data}())
    function addItem2Ul(uL, item)
        push!(uL.data, item =>  Data())
    end
    function addElement(uL, item, tid, iutils, rutils)
        d=uL.data[item]
        d.t_iutils+=iutils
        d.t_rutils+=rutils
        push!(d.elements, tid => Element(iutils, rutils))
        push!(d.tidset, tid)
    end

    #=
    function printSet(s)
        print("[")
        for i in s
            print(i)
            print(" ")
        end
        print("]")
    end
    function printULValues(utilityList)
        println("")
        print("\titemset: ")
        printSet(utilityList.itemset)
        println("")
        println("\tTotal Utils: ", utilityList.t_iutils)
        println("\tTotal Remaining Utils: ", utilityList.t_rutils)
        print("\tTidset: ")
        printSet(utilityList.tidset)
        println("")
        println("\tPrune: ", utilityList.prune)
        println("\tNext: ",utilityList.next)
    end
    function printUL(uL)
        for (key, value) in uL
            print("Prefix :", key) 
            print(printULValues(value))
        end
    end
    function printDict(dict)
        for (key, value) in dict
            println(@sprintf("%d => %d",key, value))
        end
    end
    =#


    @inline function gen_K_itemset(prefix, b)
        #Generate new itemset by 2 k-1 itemsets: a and b
        ret=vcat(prefix, b)
        return ret
    end

    function initUtilityList(items)
        #=Init utility list
        ------------------------
        itemset: represented by tuple
        iutils: itemset iutils in transactions
        rutils: itemset rutils in transaction
        tidset: a python set of tids of transactions support itemset=#
        uL=UtilityList()
        for item in items
            addItem2Ul(uL,item)
        end
        return uL   
    end

    function construct_1_utilityList(data, uTable, minUtil, h_sets)
        twu = DefaultOrderedDict{Item, Utility}(0)
        TU= Dict{Int64, Utility}()#transaction utility
        total_util=0
        tw= Dict{Int64, Dict{Item, Utility}}() #utility of item in transaction

        for (tid, row) in enumerate(data)
            t_utils=0
            for (item, internal_util) in row
        
                util = internal_util * uTable[item]
                if isnothing(get(tw, tid, nothing))
                    push!(tw,tid => Dict(item=>util))
                else
                    push!(tw[tid], item=>util)
                end
                t_utils   += util
                twu[item] += util
            end
            push!(TU, tid => t_utils)
            total_util+=t_utils
        end

        items=[item for (item, value) in sort(collect(twu), by=x->x[2])]

        uL=initUtilityList(items)
        for (tid, transaction) in enumerate(data)
            t_utils=0
            # for (item, value) in sort(collect(transaction), by= x ->twu[x])
            for item in items
                if item in keys(transaction)
                    iutils=tw[tid][item]
                    t_utils+=iutils

                    rutils=TU[tid]- t_utils
                    
                    addElement(uL,item, tid, iutils, rutils)
                end
            end
        end
        
        for (item, values) in uL.data
            t_iutils=values.t_iutils
            t_rutils=values.t_rutils
            if t_iutils >= minUtil
                push!(h_sets, [item] => t_iutils)
            end
            if t_iutils + t_rutils < minUtil
                values.prune = true
            end
        end

        return uL
    end

    @inline function construct_K_utilityList(uLs, minUtil, h_sets, k)
        # Contruct k-utilityList from k-1 - utilityList
        new_uLs=Vector{UtilityList}()

        for uL in uLs
            data=uL.data
            items=collect(keys(data))
            n=length(items)
            
        
            if n==0 continue end
            for i in 1:n-1
                a=items[i]
                if data[a].prune
                    continue
                end
                
                new_prefix = vcat(uL.prefix, a)
                new_uL=UtilityList(data[a].elements, new_prefix, OrderedDict{Item,Data}())
            
                for j in i+1:n
                    b=items[j]
                    
                    t_a=data[a].tidset
                    t_b=data[b].tidset

                    trans=intersect(t_a, t_b) # transactions that support both a and b
                    if length(trans) == 0 continue end
        
                    addItem2Ul(new_uL, b)
                    
                    for t in trans
                        iutils=data[a].elements[t].iutils + data[b].elements[t].iutils
                        if k>2 
                            iutils -= uL.prefix_util[t].iutils 
                        end

                        rutils = data[b].elements[t].rutils    #rutils definitely is the rutils of itemset b

                        addElement(new_uL, b, t, iutils, rutils)
                    end
                    
                    new_itemset= gen_K_itemset(new_prefix, b)
                    utils=new_uL.data[b].t_iutils
                    r_utils=new_uL.data[b].t_rutils
            
                    if utils >= minUtil
                        push!(h_sets, new_itemset => utils) 
                    end
                    if utils + r_utils < minUtil
                        new_uL.data[b].prune = true
                    end
                end 

                push!(new_uLs, new_uL)
            end
        end

        uLs=nothing
        return new_uLs
    end

    function hui_miner(transactions::Vector{Transaction}, util_table::UtilTable, min_util::Utility)
        h_sets=Dict{Vector{Item}, Utility}()
        uL = construct_1_utilityList(transactions, util_table, min_util, h_sets)
    
        uLs=[uL]
        k=2
        while length(uLs) != 0
            new_uLs=construct_K_utilityList(uLs, min_util, h_sets, k)
            uLs=0
            uLs=deepcopy(new_uLs)
            new_uLs=0
            k=k+1
        end
    
        return Dict(Set(itemset) => util for (itemset, util) in h_sets)
    end
end