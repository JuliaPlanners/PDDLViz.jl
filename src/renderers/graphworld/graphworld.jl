export GraphworldRenderer

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
    state_options::Dict{Symbol, Any} = default_state_options(GraphworldRenderer)
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
