using NetworkLayout: AbstractLayout

"""
    StressLocSpringMov(; kwargs...)(adj_matrix)

Returns a layout that first places the first `n_locs` nodes using stress 
minimization, then places the remaining nodes using spring/repulsion.

## Keyword Arguments
- `dim = 2`, `Ptype = Float64`: Dimension and output type.
- `n_locs = 0`: Number of nodes to place using stress minimization.
- `stress_kwargs = Dict{Symbol, Any}()`: Keyword arguments for `Stress`.
- `spring_kwargs = Dict{Symbol, Any}(:C => 0.3)`: Keyword arguments for `Spring`.
"""
struct StressLocSpringMov{Dim, Ptype} <: AbstractLayout{Dim, Ptype}
    n_locs::Int
    stress_kwargs::Dict{Symbol, Any}
    spring_kwargs::Dict{Symbol, Any}
end

function StressLocSpringMov(;
    dim = 2,
    Ptype = Float64,
    n_locs = 0,
    stress_kwargs = Dict{Symbol, Any}(:seed => 1),
    spring_kwargs = Dict{Symbol, Any}(:C => 0.3, :seed => 1)
)
    return StressLocSpringMov{dim, Ptype}(n_locs, stress_kwargs, spring_kwargs)
end

function NetworkLayout.layout(
    algo::StressLocSpringMov{Dim, Ptype}, adj_matrix::AbstractMatrix
) where {Dim, Ptype}
    n_nodes = NetworkLayout.assertsquare(adj_matrix)
    stress = Stress(;dim=Dim, Ptype=Ptype, algo.stress_kwargs...)
    loc_positions = stress(adj_matrix[1:algo.n_locs, 1:algo.n_locs])
    init_positions = resize!(copy(loc_positions), n_nodes)
    for i in algo.n_locs+1:n_nodes
        for j in 1:algo.n_locs
            adj_matrix[i, j] == 0 && continue
            init_positions[i] = loc_positions[j]
            break
        end
    end
    spring = Spring(;dim=Dim, Ptype=Ptype, pin=loc_positions,
                    initialpos=init_positions, algo.spring_kwargs...)
    return spring(adj_matrix)
end

struct BlocksworldLayout{Ptype} <: AbstractLayout{2, Ptype}
    n_locs::Int
    block_width::Ptype
    block_height::Ptype
    block_gap::Ptype
    table_height::Ptype
    gripper_height::Ptype
end

function BlocksworldLayout(;
    Ptype = Float64,
    n_locs = 2,
    block_width = Ptype(1.0),
    block_height = Ptype(1.0),
    block_gap = Ptype(0.5),
    table_height = block_height,
    gripper_height = table_height + (n_locs - 2 + 1) * block_height
)
    return BlocksworldLayout{Ptype}(
        n_locs,
        block_width,
        block_height,
        block_gap,
        table_height,
        gripper_height
    )
end

function NetworkLayout.layout(
    algo::BlocksworldLayout{Ptype}, adj_matrix::AbstractMatrix
) where {Ptype}
    n_nodes = NetworkLayout.assertsquare(adj_matrix)
    n_blocks = n_nodes - algo.n_locs
    graph = SimpleDiGraph(adj_matrix)
    positions = Vector{Point2{Ptype}}(undef, n_nodes)
    # Set table and gripper location
    x_mid = n_blocks * (algo.block_width + algo.block_gap) / Ptype(2)
    positions[1] = Point2{Ptype}(x_mid, algo.table_height/2)
    positions[2] = Point2{Ptype}(x_mid, algo.gripper_height+algo.block_height/2)
    # Compute base locations
    x_start = (algo.block_width + algo.block_gap) / Ptype(2)
    for i in 1:(algo.n_locs-2)
        x = (i - 1) * (algo.block_width + algo.block_gap) + x_start
        y = algo.table_height - algo.block_height / Ptype(2)
        positions[2 + i] = Point2{Ptype}(x, y)
    end
    # Compute block locations for towers rooted at each base
    for base in 3:algo.n_locs
        stack = [(i, base) for i in inneighbors(graph, base)]
        while !isempty(stack)
            (node, parent) = pop!(stack)
            x, y = positions[parent]
            y += algo.block_height
            positions[node] = Point2{Ptype}(x, y)
            for child in inneighbors(graph, node)
                push!(stack, (child, node))
            end
        end
    end
    # Compute block locations for blocks held in gripper
    for node in inneighbors(graph, 2)
        positions[node] = copy(positions[2])
    end
    return positions
end
