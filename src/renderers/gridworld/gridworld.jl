export GridworldRenderer

"""
    GridworldRenderer(; options...)

Customizable renderer for 2D gridworld domains.

# Options

$(TYPEDFIELDS)
"""
@kwdef mutable struct GridworldRenderer <: Renderer
    "PDDL fluents that represent the grid layers (walls, etc)."
    grid_fluents::Vector{Term} = [pddl"(walls)"]
    "Colors for each grid layer."
    grid_colors::Vector = [:black]
    "Whether the domain has an agent not associated with a PDDL object."
    has_agent::Bool = true
    "Function that returns the PDDL fluent for the agent's x position."
    get_agent_x::Function = () -> pddl"(xpos)"
    "Function that returns the PDDL fluent for the agent's y position."
    get_agent_y::Function = () -> pddl"(ypos)"
    "Takes an object constant and returns the PDDL fluent for its x position."
    get_obj_x::Function = obj -> Compound(:xloc, [obj])
    "Takes an object constant and returns the PDDL fluent for its y position."
    get_obj_y::Function = obj -> Compound(:yloc, [obj])
    "Agent renderer, of the form `(domain, state) -> Graphic`."
    agent_renderer::Function = (d, s) -> CircleShape(0, 0, 0.3, color=:black)
    "Per-type object renderers, of the form `(domain, state, obj) -> Graphic`."
    obj_renderers::Dict{Symbol, Function} = Dict{Symbol, Function}(
        :object => (d, s, o) -> SquareShape(0, 0, 0.2, color=:gray)
    )
    "Z-order for object types, from bottom to top."
    obj_type_z_order::Vector{Symbol} = collect(keys(obj_renderers))
    "List of `(x, y, label, color)` tuples to label locations on the grid."
    locations::Vector{Tuple} = Tuple[]
    "Whether to show an object inventory for each function in `inventory_fns`."
    show_inventory::Bool = false
    "Inventory indicator functions of the form `(domain, state, obj) -> Bool`."
    inventory_fns::Vector{Function} = Function[]
    "Types of objects that can be each inventory."
    inventory_types::Vector{Symbol} = Symbol[]
    "Axis titles / labels for each inventory."
    inventory_labels::Vector{String} = String[]
    "Default options for state rendering."
    state_options::Dict{Symbol, Any} = Dict{Symbol, Any}(
        :show_agent => true,
        :show_objects => true,
        :show_locations => true
    )
    "Default options for trajectory rendering."
    trajectory_options::Dict{Symbol, Any} = Dict{Symbol, Any}(
        :agent_color => :black,
        :step_markersize => 0.3,
        :tracked_objects => Const[],
        :object_colors => [],
        :tracked_types => Symbol[],
        :type_colors => [],
    )
end

function new_canvas(renderer::GridworldRenderer)
    figure = Figure(resolution=(600,600))
    layout = GridLayout(figure[1,1])
    return Canvas(figure, layout)
end

include("state.jl")
include("trajectory.jl")
include("path_search.jl")
include("policy.jl")
