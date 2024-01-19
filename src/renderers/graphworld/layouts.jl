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

"""
    BlocksworldLayout(; kwargs...)

Layout for blocksworld problems. Blocks are stacked bottom-up from a table, 
except for the block that is currently held by the gripper.

## Keyword Arguments
- `Ptype = Float64`: Type of coordinates.
- `n_locs = 3`: Number of locations, including the table, gripper, ceiling,
    and locations of the base blocks.
- `block_width = 1.0`: Width of each block.
- `block_height = 1.0`: Height of each block.
- `block_gap = 0.5`: Horizontal gap between blocks.
- `table_height = block_height`: Height of the table.
- `gripper_height`: Height of the gripper.
"""
struct BlocksworldLayout{Ptype} <: AbstractLayout{2, Ptype}
    n_locs::Int
    block_width::Ptype
    block_height::Ptype
    block_gap::Ptype
    table_height::Ptype
    gripper_height::Union{Ptype, Nothing}
end

function BlocksworldLayout(;
    Ptype = Float64,
    n_locs = 3,
    block_width = Ptype(1.0),
    block_height = Ptype(1.0),
    block_gap = Ptype(0.5),
    table_height = block_height,
    gripper_height = nothing
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
    # Set table location
    x_mid = n_blocks * (algo.block_width + algo.block_gap) / Ptype(2)
    table_pos = Point2{Ptype}(x_mid, algo.table_height / Ptype(2))
    positions[1] = table_pos
    # Set ceiling location
    ceil_height = algo.table_height + Ptype(n_blocks + 2.5) * algo.block_height
    if !isnothing(algo.gripper_height)
        ceil_height = max(ceil_height, algo.gripper_height)
    end
    ceil_pos = Point2{Ptype}(x_mid, ceil_height)
    positions[3] = ceil_pos
    # Compute base locations
    x_start = (algo.block_width + algo.block_gap) / Ptype(2)
    for i in 1:n_blocks
        x = (i - 1) * (algo.block_width + algo.block_gap) + x_start
        y = algo.table_height - algo.block_height / Ptype(2)
        positions[3 + i] = Point2{Ptype}(x, y)
    end
    # Compute block locations for towers rooted at each base
    max_tower_height = algo.table_height - algo.block_height / Ptype(2)
    for base in 4:algo.n_locs
        stack = [(i, base) for i in inneighbors(graph, base)]
        while !isempty(stack)
            (node, parent) = pop!(stack)
            x, y = positions[parent]
            y += algo.block_height
            max_tower_height = max(y, max_tower_height)
            positions[node] = Point2{Ptype}(x, y)
            for child in inneighbors(graph, node)
                push!(stack, (child, node))
            end
        end
    end
    if isnothing(algo.gripper_height)
        # Automatically determine gripper height
        gripper_height = max_tower_height + Ptype(1.5) * algo.block_height
        if !isempty(inneighbors(graph, 2))
            gripper_height += algo.block_height
        end
        gripper_height = min(gripper_height, ceil_height)
    else
        # Set fixed gripper height
        gripper_height = ceil_height
    end
    # Set gripper location
    gripper_pos = Point2{Ptype}(x_mid, gripper_height)
    positions[2] = gripper_pos
    # Set location of held blocks
    for node in inneighbors(graph, 2)
        positions[node] = copy(gripper_pos)
    end
    return positions
end
