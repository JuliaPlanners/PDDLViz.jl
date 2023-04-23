export GraphworldRenderer

using GraphMakie.NetworkLayout: AbstractLayout

"""
    GraphworldRenderer(; options...)

Customizable renderer for domains with fixed locations connected in a graph.

# Options

$(TYPEDFIELDS)
"""
@kwdef mutable struct GraphworldRenderer <: Renderer
    "Default figure resolution, in pixels."
    resolution::Tuple{Int, Int} = (800, 800)
    "Function or `AbstractLayout` that maps a graph to node locations."
    graph_layout::Union{Function, AbstractLayout} = Stress()
    "Whether the graph edges are directed."
    is_directed::Bool = false
    "PDDL object types that correspond to fixed locations."
    location_types::Vector{Symbol} = [:location]
    "PDDL object types that correspond to movable objects."
    movable_types::Vector{Symbol} = [:movable]
    "Function `(dom, state, a, b) -> Bool` that checks if `(a, b)` is present."
    edge_fn::Function = (d, s, a, b) -> a != b
    "Function `(dom, state, a, b) -> String` that returns a label for `(a, b)`."
    edge_label_fn::Function = (d, s, a, b) -> ""
    "Function `(dom, state, x, loc) -> Bool` that returns if `x` is at `loc`."
    at_loc_fn::Function = (d, s, x, loc) -> false
    "Per-type location renderers, of the form `(domain, state, loc) -> Graphic`."
    loc_renderers::Dict{Symbol, Function} = Dict{Symbol, Function}()
    "Per-type object renderers, of the form `(domain, state, obj) -> Graphic`."
    obj_renderers::Dict{Symbol, Function} = Dict{Symbol, Function}()
    "Default options for state rendering."
    state_options::Dict{Symbol, Any} = Dict{Symbol, Any}(
        :show_location_graphics => true
        :show_location_labels => true,
        :show_movable_graphics => true
        :show_movable_labels => true,
        :label_offset_mult => 0.2,
    )
    "Default options for graph rendering, passed to the `graphplot` recipe."
    graph_options::Dict{Symbol, Any} = Dict{Symbol, Any}(
        :node_size => 0.05,
        :node_attr => (markerspace=:data,),
        :nlabels_fontsize => 20,
        :nlabels_align => (:center, :center),
        :elabels_fontsize => 16,
    )
end

function new_canvas(renderer::GraphworldRenderer)
    figure = Figure(resolution=renderer.resolution)
    axis = Axis(figure[1, 1])
    return Canvas(figure, axis)
end

include("state.jl")
