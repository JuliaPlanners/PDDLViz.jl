export GraphworldRenderer, BlocksworldRenderer

include("layouts.jl")

"""
    GraphworldRenderer(; options...)

Customizable renderer for domains with fixed locations and movable objects
connected in a graph. The layout of the graph can be controlled with the
`graph_layout` option, which takes a function that returns an `AbstractLayout`
given the number of locations.

By default, the graph is laid out using the `StressLocSpringMov` layout, which 
arranges the first `n_locs` nodes via stress minimization, and uses
spring/repulsion for the remaining nodes.

# General options

$(TYPEDFIELDS)
"""
@kwdef mutable struct GraphworldRenderer <: Renderer
    "Default figure resolution, in pixels."
    resolution::Tuple{Int, Int} = (800, 800)
    "Function `n_locs -> (graph -> positions)` that returns an AbstractLayout."
    graph_layout::Function = n_locs -> StressLocSpringMov(n_locs=n_locs)
    "Whether the edges between locations are directed."
    is_loc_directed::Bool = false
    "Whether the edges between movable objects are directed."
    is_mov_directed::Bool = false
    "Whether there are edges between movable objects."
    has_mov_edges::Bool = false
    "PDDL objects that correspond to fixed locations."
    locations::Vector{Const} = Const[]
    "PDDL object types that correspond to fixed locations."
    location_types::Vector{Symbol} = Symbol[]
    "PDDL objects that correspond to movable objects."
    movables::Vector{Const} = Const[]
    "PDDL object types that correspond to movable objects."
    movable_types::Vector{Symbol} = Symbol[]
    "Function `(dom, s, l1, l2) -> Bool` that checks if `l1` connects to `l2`."
    loc_edge_fn::Function = (d, s, l1, l2) -> l1 != l2
    "Function `(dom, s, l1, l2) -> String` that labels edge `(l1, l2)`."
    loc_edge_label_fn::Function = (d, s, l1, l2) -> ""
    "Function `(dom, s, obj, loc) -> Bool` that checks if `mov` is at `loc`."
    mov_loc_edge_fn::Function = (d, s, mov, loc) -> false
    "Function `(dom, s, obj, loc) -> String` that labels edge `(mov, loc)`."
    mov_loc_edge_label_fn::Function = (d, s, mov, loc) -> ""
    "Function `(dom, s, m1, m2) -> Bool` that checks if `m1` connects to `m2`."
    mov_edge_fn::Function = (d, s, m1, m2) -> false
    "Function `(dom, s, m1, m2) -> String` that labels edge `(m1, m2)`."
    mov_edge_label_fn::Function = (d, s, o1, o2) -> ""
    "Location object renderers, of the form `(domain, state, loc) -> Graphic`."
    loc_renderers::Dict{Const, Function} = Dict{Const, Function}()
    "Movable object renderers, of the form `(domain, state, obj) -> Graphic`."
    mov_renderers::Dict{Const, Function} = Dict{Const, Function}()
    "Per-type location renderers, of the form `(domain, state, loc) -> Graphic`."
    loc_type_renderers::Dict{Symbol, Function} = Dict{Symbol, Function}()
    "Per-type movable renderers, of the form `(domain, state, obj) -> Graphic`."
    mov_type_renderers::Dict{Symbol, Function} = Dict{Symbol, Function}()
    "Default options for graph rendering, passed to the `graphplot` recipe."
    graph_options::Dict{Symbol, Any} = Dict{Symbol, Any}(
        :node_size => 0.05,
        :node_attr => (markerspace=:data,),
        :nlabels_fontsize => 20,
        :nlabels_align => (:center, :center),
        :elabels_fontsize => 16,
    )
    "Default display options for axis."
    axis_options::Dict{Symbol, Any} = Dict{Symbol, Any}(
        :aspect => 1,
        :autolimitaspect => 1,
        :hidedecorations => true
    )
    "Default options for state rendering."
    state_options::Dict{Symbol, Any} =
        default_state_options(GraphworldRenderer)
    "Default options for animation rendering."
    anim_options::Dict{Symbol, Any} = Dict{Symbol, Any}()
end

"""
    BlocksworldRenderer(; options...)

Specialization of [`GraphworldRenderer`](@ref) for the blocksworld domain, which 
uses a custom [`BlocksworldLayout`](@ref) and default renderers for blocks
and tables. The following blocksworld-specific options are supported:

# Options

- `block_type::Symbol`: PDDL type of blocks, defaults to `:block`
- `block_width::Real`: Width of blocks, defaults to `1.0`
- `block_height::Real`: Height of blocks, defaults to `1.0`
- `block_gap::Real`: Gap between blocks, defaults to `0.5`
- `table_height::Real`: Height of table, defaults to `block_height`
- `gripper_height::Real`: Height of blocks when they are picked up. Defaults 
    to `table_height + (n_locs - 2 + 1) * block_height`.
- `block_colors`: Colorscheme for blocks, defaults to a discretization of the
    `plasma` colorscheme.
- `block_renderer`: Renderer for blocks, defaults to a colored square with the
    block name as white text in the center.
"""
function BlocksworldRenderer(;
    block_type::Symbol = :block,
    block_width::Real = 1.0,
    block_height::Real = 1.0,
    block_gap::Real = 0.5,
    table_height::Real = block_height,
    gripper_height::Union{Real, Nothing} = nothing,
    graph_layout = n_locs -> PDDLViz.BlocksworldLayout(;
        n_locs, block_width, block_height, block_gap, table_height,
        gripper_height = isnothing(gripper_height) ? 
            table_height + (n_locs - 2 + 1) * block_height : gripper_height
    ),
    block_colors = Makie.colorschemes[:plasma][1:8:256],
    block_renderer = (d, s, obj) -> begin
        return MultiGraphic(
            SquareShape(
                0.0, 0.0, 1.0,
                color=block_colors[mod(hash(obj.name), length(block_colors))+1],
                strokewidth=2.0
            ),
            TextGraphic(
                string(obj.name), 0, 0, 3/4*length(string(obj.name)),
                font=:bold, color=:white, strokecolor=:black, strokewidth=1.0
            )
        )
    end,
    table_renderer = (d, s, loc) -> begin
        n_blocks = length(PDDL.get_objects(s, :block))
        width = (block_width + block_gap) * n_blocks
        return RectShape(0.0, 0.0, width, 1.0, color=:grey60, strokewidth=2.0) 
    end,
    loc_edge_fn = (d, s, a, b) -> false,
    mov_loc_edge_fn = (d, s, x, loc) -> begin
        if x == loc
            s[Compound(:ontable, [x])]
        elseif loc.name == :gripper
            s[Compound(:holding, [x])]
        else
            false
        end
    end,
    mov_edge_fn = (d, s, x, y) -> s[Compound(:on, [x, y])],
    is_loc_directed = true,
    is_mov_directed = true,
    has_mov_edges = true,
    locations = [pddl"(table)", pddl"(gripper)"],
    location_types = [block_type],
    movable_types = [block_type],
    loc_renderers = Dict{Const, Function}(
        locations[1] => table_renderer
    ),
    mov_type_renderers = Dict{Symbol, Function}(
        block_type => block_renderer
    ),
    axis_options = Dict{Symbol, Any}(
        :aspect => DataAspect(),
        :xautolimitmargin => (0.0, 0.0),
        :limits => (0.0, nothing, 0.0, nothing),
        :hidedecorations => true
    ),
    state_options = Dict{Symbol, Any}(
        :show_location_labels => false,
        :show_movable_labels => false,
        :show_edge_labels => false,
        :show_location_graphics => true,
        :show_movable_graphics => true
    ),
    graph_options = Dict{Symbol, Any}(
        :show_arrow => false,
        :node_size => 0.0,
        :edge_width => 0.0,
        :node_attr => (markerspace=:data,),
    ),
    kwargs...
)
    return GraphworldRenderer(;
        graph_layout,
        is_loc_directed,
        is_mov_directed,
        has_mov_edges,
        locations,
        location_types,
        movable_types,
        loc_edge_fn,
        mov_loc_edge_fn,
        mov_edge_fn,
        loc_renderers,
        mov_type_renderers,
        axis_options,
        state_options,
        graph_options,
        kwargs...
    )
end

function new_canvas(renderer::GraphworldRenderer)
    figure = Figure(resolution=renderer.resolution)
    return Canvas(figure)
end

include("state.jl")

# Add documentation for auxiliary options
Base.with_logger(Base.NullLogger()) do
    @doc """
    $(@doc GraphworldRenderer)

    # State options

    These options can be passed as keyword arguments to [`render_state`](@ref):

    $(Base.doc(default_state_options, Tuple{Type{GraphworldRenderer}}))
    """
    GraphworldRenderer
end
