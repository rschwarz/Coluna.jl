"""
    AbstractTreeExploreStrategy

    Strategy for the tree exploration

"""
abstract type AbstractTreeExploreStrategy end

getnodevalue(strategy::AbstractTreeExploreStrategy, node::Node) = 0

# Depth-first strategy
struct DepthFirstStrategy <: AbstractTreeExploreStrategy end
getnodevalue(algo::DepthFirstStrategy, n::Node) = (-n.depth)

# Best dual bound strategy
struct BestDualBoundStrategy <: AbstractTreeExploreStrategy end
getnodevalue(algo::BestDualBoundStrategy, n::Node) = get_ip_dual_bound(getincumbents(n))


"""
    SearchTree
"""
mutable struct SearchTree
    nodes::DS.PriorityQueue{Node, Float64}
    strategy::AbstractTreeExploreStrategy
end

SearchTree(strategy::AbstractTreeExploreStrategy) = SearchTree(
    DS.PriorityQueue{Node, Float64}(Base.Order.Forward), strategy
)

getnodes(tree::SearchTree) = tree.nodes
treeisempty(tree::SearchTree) = DS.isempty(tree.nodes)

push!(tree::SearchTree, node::Node) = DS.enqueue!(tree.nodes, node, getnodevalue(tree.strategy, node))
popnode!(tree::SearchTree) = DS.dequeue!(tree.nodes)
nb_open_nodes(tree::SearchTree) = length(tree.nodes)


"""
    TreeSearchRuntimeData

    Data used by the tree search algorithm while running.
    Destroyed after each run.     
"""
mutable struct TreeSearchRuntimeData
    primary_tree::SearchTree
    max_primary_tree_size::Int64
    secondary_tree::SearchTree
    tree_order::Int64
    optstate::OptimizationState
    exploitsprimalsolutions::Bool
    Sense::Type{<:Coluna.AbstractSense}
    node_storages_to_restore::StoragesToRestoreDict
end

treeisempty(data::TreeSearchRuntimeData) = treeisempty(data.primary_tree) && treeisempty(data.secondary_tree)
primary_tree_is_full(data::TreeSearchRuntimeData) = nb_open_nodes(data.primary_tree) >= data.max_primary_tree_size

function push!(data::TreeSearchRuntimeData, node::Node) 
    if primary_tree_is_full(data) 
        push!(data.secondary_tree, node)
    else           
        push!(data.primary_tree, node)
    end
end

function popnode!(data::TreeSearchRuntimeData)::Node
    if treeisempty(data.secondary_tree)
        return popnode!(data.primary_tree)
    end
    return popnode!(data.secondary_tree)
end

function nb_open_nodes(data::TreeSearchRuntimeData)
    return nb_open_nodes(data.primary_tree) + nb_open_nodes(data.secondary_tree)
end
get_tree_order(data::TreeSearchRuntimeData) = data.tree_order
getoptstate(data::TreeSearchRuntimeData) = data.optstate

"""
    Coluna.Algorithm.TreeSearchAlgorithm(
        conqueralg::AbstractConquerAlgorithm = ColGenConquer(),
        dividealg::AbstractDivideAlgorithm = SimpleBranching(),
        explorestrategy::AbstractTreeExploreStrategy = DepthFirstStrategy(),
        maxnumnodes::Int = 100000,
        opennodeslimit::Int = 100,
        branchingtreefile = nothing
    )

This algorithm uses search tree to do optimization. At each node in the tree, it applies
`conqueralg` to improve the bounds, `dividealg` to generate child nodes, and `explorestrategy`
to select the next node to treat.
"""
Base.@kwdef struct TreeSearchAlgorithm <: AbstractOptimizationAlgorithm
    conqueralg::AbstractConquerAlgorithm = ColGenConquer()
    dividealg::AbstractDivideAlgorithm = SimpleBranching()
    explorestrategy::AbstractTreeExploreStrategy = DepthFirstStrategy()
    maxnumnodes::Int64 = 100000 
    opennodeslimit::Int64 = 100 
    branchingtreefile::Union{Nothing, String} = nothing
    skiprootnodeconquer = false # true for diving heuristics
    rootpriority = 0
    nontrootpriority = 0
    storelpsolution = false 
end

function get_storages_usage!(
    algo::TreeSearchAlgorithm, reform::Reformulation, storages_usage::StoragesUsageDict
)
    get_storages_usage!(algo.conqueralg, reform, storages_usage)
    get_storages_usage!(algo.dividealg, reform, storages_usage)
    return
end

function get_storages_to_restore!(
    algo::TreeSearchAlgorithm, reform::Reformulation, storages_to_restore::StoragesToRestoreDict
)
    # tree search algorithm restores itself storages for the conquer and divide algorithm 
    # on every node, so we do not require anything here
end

function print_node_info_before_conquer(data::TreeSearchRuntimeData, node::Node)
    println("***************************************************************************************")
    if isrootnode(node)
        println("**** BaB tree root node")
    else
        println("**** BaB tree node N° ", get_tree_order(node), 
                ", parent N° ", get_tree_order(getparent(node)),
                ", depth ", getdepth(node),
                ", ", nb_open_nodes(data) + 1, " open nodes")
    end

    db = getvalue(get_ip_dual_bound(getoptstate(data)))
    pb = getvalue(get_ip_primal_bound(getoptstate(data)))
    node_db = getvalue(get_ip_dual_bound(getoptstate(node)))
    @printf "**** Local DB = %.4f," node_db
    @printf " global bounds : [ %.4f , %.4f ]," db pb
    @printf " time = %.2f sec.\n" Coluna._elapsed_solve_time()

    if node.branchdescription != ""
        println("**** Branching constraint: ", node.branchdescription)
    end
    println("***************************************************************************************")
    return
end

function init_branching_tree_file(algo::TreeSearchAlgorithm)
    if algo.branchingtreefile !== nothing
        open(algo.branchingtreefile, "w") do file
            println(file, "## dot -Tpdf thisfile > thisfile.pdf \n")
            println(file, "digraph Branching_Tree {")
            println(file, "\tedge[fontname = \"Courier\", fontsize = 10];")
        end
    end
    return
end

function print_node_in_branching_tree_file(algo::TreeSearchAlgorithm, data::TreeSearchRuntimeData, node)
    if algo.branchingtreefile !== nothing
        pb = getvalue(get_ip_primal_bound(getoptstate(data)))
        db = getvalue(get_ip_dual_bound(getoptstate(node)))
        open(algo.branchingtreefile, "a") do file
            ncur = get_tree_order(node)
            time = Coluna._elapsed_solve_time()
            @printf file "\tn%i [label= \"N_%i (%.0f s) \\n[%.4f , %.4f]\"];\n" ncur ncur time db pb
            if !isrootnode(node)
                npar = get_tree_order(getparent(node))
                @printf file "\tn%i -> n%i [label= \"%s\"];\n" npar ncur node.branchdescription
            end
        end
    end
    return
end

function finish_branching_tree_file(algo::TreeSearchAlgorithm)
    if algo.branchingtreefile !== nothing
        open(algo.branchingtreefile, "a") do file
            println(file, "}")
        end
    end
    return
end

function run_conquer_algorithm!(
    algo::TreeSearchAlgorithm, tsdata::TreeSearchRuntimeData,
    rfdata::ReformData, node::Node
)
    if (!node.conquerwasrun)
        set_tree_order!(node, tsdata.tree_order)
        tsdata.tree_order += 1
    end

    print_node_info_before_conquer(tsdata, node)

    node.conquerwasrun && return

    treestate = getoptstate(tsdata)
    nodestate = getoptstate(node)
    update_ip_primal!(nodestate, treestate, tsdata.exploitsprimalsolutions)

    apply_conquer_alg_to_node!(node, algo.conqueralg, rfdata)        

    update_all_ip_primal_solutions!(treestate, nodestate)
    
    if algo.storelpsolution && isrootnode(node) && nb_lp_primal_sols(nodestate) > 0
        set_lp_primal_sol!(treestate, get_best_lp_primal_sol(nodestate)) 
    end 
    return
end

function update_tree!(data::TreeSearchRuntimeData, output::DivideOutput)
end

function run_divide_algorithm!(
    algo::TreeSearchAlgorithm, tsdata::TreeSearchRuntimeData, 
    rfdata::ReformData, node::Node
)
    if to_be_pruned(node)
        println("Node is already conquered. No children will be generated")
        return
    end        

    treestate = getoptstate(tsdata)
    output = run!(algo.dividealg, rfdata, DivideInput(node, treestate))

    update_all_ip_primal_solutions!(treestate, getoptstate(output))

    @logmsg LogLevel(-1) string("Updating tree.")

    children = getchildren(output)
    isempty(children) && return

    first_child_with_runconquer = true
    for child in children
        if (child.conquerwasrun)
            set_tree_order!(child, tsdata.tree_order)
            tsdata.tree_order += 1
            if first_child_with_runconquer
                print("Child nodes generated :")
                first_child_with_runconquer = false
            end    
            print(" N° ", get_tree_order(child) ," ")
        end
        push!(tsdata, child)
    end
    !first_child_with_runconquer && println()
    return
end

function updatedualbound!(data::TreeSearchRuntimeData)
    treestate = getoptstate(data)
    bound_value = getvalue(get_ip_primal_bound(treestate))
    worst_bound = DualBound{data.Sense}(bound_value)  
    for (node, priority) in getnodes(data.primary_tree)
        db = get_ip_dual_bound(getoptstate(node))
        if isbetter(worst_bound, db)
            worst_bound = db
        end
    end
    for (node, priority) in getnodes(data.secondary_tree)
        db = get_ip_dual_bound(getoptstate(node))
        if isbetter(worst_bound, db)
            worst_bound = db
        end
    end
    set_ip_dual_bound!(treestate, worst_bound)
    return
end

# TODO : make it better
function determine_statuses(data::TreeSearchRuntimeData)
    fully_explored = treeisempty(data)
    treestate = getoptstate(data)
    found_sols = (nb_ip_primal_sols(treestate) > 0)
    gap_is_zero = (get_ip_primal_bound(treestate) / get_ip_dual_bound(treestate) ≈ 1.0)
    #gap_is_zero && @assert found_sols
    found_sols && setfeasibilitystatus!(treestate, FEASIBLE)
    gap_is_zero && setterminationstatus!(treestate, OPTIMAL)
    if !found_sols # Implies that gap is not zero
        setterminationstatus!(treestate, EMPTY_RESULT)
        # Determine if we can prove that is was infeasible
        if fully_explored
            setfeasibilitystatus!(treestate, INFEASIBLE)
        else
            setfeasibilitystatus!(treestate, UNKNOWN_FEASIBILITY)
        end
    elseif !gap_is_zero
        setterminationstatus!(treestate, OTHER_LIMIT)
    end
    return
end

function TreeSearchRuntimeData(algo::TreeSearchAlgorithm, rfdata::ReformData, input::OptimizationInput)
    exploitsprimalsols = exploits_primal_solutions(algo.conqueralg) || exploits_primal_solutions(algo.dividealg)        
    reform = getreform(rfdata)
    treestate = CopyBoundsAndStatusesFromOptState(getmaster(reform), getoptstate(input), exploitsprimalsols)

    node_storages_to_restore = StoragesToRestoreDict()
    get_storages_to_restore!(algo.conqueralg, reform, node_storages_to_restore) 
    get_storages_to_restore!(algo.dividealg, reform, node_storages_to_restore) 

    tsdata = TreeSearchRuntimeData(
        SearchTree(algo.explorestrategy), algo.opennodeslimit, SearchTree(DepthFirstStrategy()), 1,
        treestate, exploitsprimalsols, getobjsense(reform), node_storages_to_restore
    )
    master = getmaster(getreform(rfdata))
    push!(tsdata, RootNode(master, treestate, store_states!(rfdata), algo.skiprootnodeconquer))
    return tsdata
end

function run!(algo::TreeSearchAlgorithm, rfdata::ReformData, input::OptimizationInput)::OptimizationOutput
    tsdata = TreeSearchRuntimeData(algo, rfdata, input)

    init_branching_tree_file(algo)
    while !treeisempty(tsdata) 
        node = popnode!(tsdata)

        if get_tree_order(tsdata) <= algo.maxnumnodes
            restore_states!(node.stateids, tsdata.node_storages_to_restore)
            run_conquer_algorithm!(algo, tsdata, rfdata, node)
            print_node_in_branching_tree_file(algo, tsdata, node)
            run_divide_algorithm!(algo, tsdata, rfdata, node)           
            updatedualbound!(tsdata)
        else
            remove_states!(node.stateids)
        end
        
        # we delete solutions from the node optimization state, as they are not needed anymore
        clear_solutions!(getoptstate(node))
    end
    finish_branching_tree_file(algo)

    determine_statuses(tsdata)
    return OptimizationOutput(getoptstate(tsdata))
end
