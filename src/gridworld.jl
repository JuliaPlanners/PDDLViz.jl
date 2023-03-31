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
    obj_renderers::Dict{Symbol, Function} = Dict{Symbol, Function}()
    "Z-order for object types, from bottom to top."
    obj_type_z_order::Vector{Symbol} = collect(keys(obj_renderers))
    "Default options for state rendering."
    state_options::Dict{Symbol, Any} = Dict{Symbol, Any}(
        :show_agent => true,
        :show_objects => true
    )
    "Default options for trajectory rendering."
    trajectory_options::Dict{Symbol, Any} = Dict{Symbol, Any}(
        :agent_color => :black,
        :agent_markersize => 20
    )
end

current_canvas(renderer::GridworldRenderer) = error("Not implemented.")

function new_canvas(renderer::GridworldRenderer)
    figure = Figure(resolution=(600,600))
    axis = Axis(figure[1,1], aspect=1)
    hidedecorations!(axis, grid=false)
    return Canvas(figure, axis)
end

function render_state!(
    canvas::Canvas, renderer::GridworldRenderer,
    domain::Domain, state::Observable;
    options...
)
    # Update options
    options = merge(renderer.state_options, options)
    # Set canvas state observable (replacing any previous state)
    canvas.state = state
    # Extract main axis
    ax = canvas.blocks[1]
    # Get grid dimensions from PDDL state
    base_grid = @lift $state[renderer.grid_fluents[1]]
    height = @lift size($base_grid, 1)
    width = @lift size($base_grid, 2)
    # Render grid variables as heatmaps
    for (i, grid_fluent) in enumerate(renderer.grid_fluents)
        grid = @lift reverse(transpose(float($state[grid_fluent])), dims=2)
        cmap = cgrad([:transparent, renderer.grid_colors[i]])
        heatmap!(ax, grid, colormap=cmap)
    end
    # Set ticks to show grid
    map!(w -> (1:w-1) .+ 0.5, ax.xticks, width)
    map!(h -> (1:h-1) .+ 0.5, ax.yticks, height) 
    ax.xgridcolor, ax.ygridcolor = :black, :black
    ax.xgridstyle, ax.ygridstyle = :dash, :dash
    # Render objects
    default_obj_renderer(d, s, o) = SquareShape(0, 0, 0.2, color=:gray)
    if options[:show_objects]
        # Render objects with type-specific graphics
        for type in renderer.obj_type_z_order
            for obj in PDDL.get_objects(state[], type)
                r = get(renderer.obj_renderers, type, default_obj_renderer)
                graphic = @lift begin
                    x = $state[renderer.get_obj_x(obj)]
                    y = $height - $state[renderer.get_obj_y(obj)] + 1
                    translate(r(domain, $state, obj), x, y)
                end
                graphicplot!(ax, graphic)
           end
        end
        # Render remaining objects
        for (obj, type) in PDDL.get_objtypes(state[])
            type in renderer.obj_type_z_order && continue
            graphic = @lift begin
                x = $state[renderer.get_obj_x(obj)]
                y = $height - $state[renderer.get_obj_y(obj)] + 1
                translate(default_obj_renderer(domain, $state, obj), x, y)
            end
            graphicplot!(ax, graphic)
        end
    end
    # Render agent
    if options[:show_agent]
        graphic = @lift begin
            x = $state[renderer.get_agent_x()]
            y = $height - $state[renderer.get_agent_y()] + 1
            translate(renderer.agent_renderer(domain, $state), x, y)
        end
        graphicplot!(ax, graphic)
    end
    # Return the canvas
    return canvas
end

function render_trajectory!(
    canvas::Canvas, renderer::GridworldRenderer,
    domain::Domain, trajectory::Observable;
    options...
)
    # Render initial state if not already on canvas
    if canvas.state === nothing
        render_state!(canvas, renderer, domain, trajectory[][1]; options...)
    end
    # Update options
    options = merge(renderer.trajectory_options, options)
    # Extract main axis and grid height
    ax = canvas.blocks[1]
    # Construct observables for locations and markers
    locations = Observable(Point2f[])
    markers = Observable(Symbol[])
    rotations = Observable(Float64[])
    # Fill observables
    on(trajectory; update = true) do trajectory
        # Clear previous locations and markers
        empty!(locations[])
        empty!(markers[])
        empty!(rotations[])
        # Add locations and markers for each timestep
        for (t, state) in enumerate(trajectory)
            height = size(state[renderer.grid_fluents[1]], 1)
            x = state[renderer.get_agent_x()]
            y = height - state[renderer.get_agent_y()] + 1
            push!(locations[], Point2f(x, y))
            next_state = trajectory[min(t+1, length(trajectory))]
            next_x = next_state[renderer.get_agent_x()]
            next_y = height - next_state[renderer.get_agent_y()] + 1
            if next_x == x && next_y == y
                push!(markers[], :circle)
                push!(rotations[], 0.0)
            else
                push!(markers[], :rtriangle)
                push!(rotations[], atan(next_y - y, next_x - x))
            end
        end
        # Trigger updates
        notify(locations)
        notify(markers)
        notify(rotations)
    end
    # Plot agent locations over time
    scatter!(ax, locations, marker=markers, rotations=rotations,
             markersize=options[:agent_markersize], color=options[:agent_color])
    # Return the canvas
    return canvas
end
