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
    "Whether to show an object inventory for each function in `inventory_fns`."
    show_inventory::Bool = false
    "Inventory indicator functions of the form `(domain, state, obj) -> Bool`."
    inventory_fns::Vector{Function} = Function[]
    "Axis titles / labels for each inventory."
    inventory_labels::Vector{String} = String[]
    "Default options for state rendering."
    state_options::Dict{Symbol, Any} = Dict{Symbol, Any}(
        :show_agent => true,
        :show_objects => true,
    )
    "Default options for trajectory rendering."
    trajectory_options::Dict{Symbol, Any} = Dict{Symbol, Any}(
        :agent_color => :black,
        :agent_markersize => 20,
        :tracked_objects => Const[],
        :object_colors => [],
        :tracked_types => Symbol[],
        :type_colors => [],
    )
end

current_canvas(renderer::GridworldRenderer) = error("Not implemented.")

function new_canvas(renderer::GridworldRenderer)
    figure = Figure(resolution=(600,600))
    layout = GridLayout(figure[1,1])
    return Canvas(figure, layout)
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
    # Extract or construct main axis
    ax = get(canvas.blocks, 1) do 
        _ax = Axis(canvas.layout[1,1], aspect=DataAspect())
        hidedecorations!(_ax, grid=false)
        push!(canvas.blocks, _ax)
        return _ax
    end
    # Get grid dimensions from PDDL state
    base_grid = @lift $state[renderer.grid_fluents[1]]
    height = @lift size($base_grid, 1)
    width = @lift size($base_grid, 2)
    # Render grid variables as heatmaps
    for (i, grid_fluent) in enumerate(renderer.grid_fluents)
        grid = @lift reverse(transpose(float($state[grid_fluent])), dims=2)
        cmap = cgrad([:transparent, renderer.grid_colors[i]])
        crange = @lift (min(minimum($grid), 0), max(maximum($grid), 1))
        heatmap!(ax, grid, colormap=cmap, colorrange=crange)
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
            for obj in PDDL.get_objects(domain, state[], type)
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
    # Render inventories
    if renderer.show_inventory
        inventory_size = @lift max(length(PDDL.get_objects($state)), $width)
        colsize!(canvas.layout, 1, Auto(1))
        rowsize!(canvas.layout, 1, Auto(1))
        for (i, inventory_fn) in enumerate(renderer.inventory_fns)
            # Extract or construct axis for each inventory
            ax_i = get(canvas.blocks, i+1) do
                title = get(renderer.inventory_labels, i, "Inventory")
                _ax = Axis(canvas.layout[i+1, 1], aspect=DataAspect(),
                           title=title, titlealign=:left,
                           titlefont=:regular, titlesize=20)
                hidedecorations!(_ax, grid=false)
                push!(canvas.blocks, _ax)
                return _ax
            end
            # Render inventory as heatmap
            cmap = cgrad([:transparent, :black])
            heatmap!(ax_i, @lift(zeros($inventory_size, 1)),
                     colormap=cmap, colorrange=(0, 1))
            map!(w -> (1:w-1) .+ 0.5, ax_i.xticks, inventory_size)
            map!(ax_i.limits, inventory_size) do w
                return ((0.5, w + 0.5), nothing)
            end
            ax_i.yticks = [0.5, 1.5]
            ax_i.xgridcolor, ax_i.ygridcolor = :black, :black
            ax_i.xgridstyle, ax_i.ygridstyle = :solid, :solid
            # Compute object locations
            sorted_objs = sort(PDDL.get_objects(state[]), by=string)
            obj_locs = @lift begin
                locs = Int[]
                n = 0
                for obj in sorted_objs
                    if inventory_fn(domain, $state, obj)
                        push!(locs, n += 1)
                    else
                        push!(locs, -1)
                    end
                end
                return locs
            end
            # Render objects in inventory
            for (j, obj) in enumerate(sorted_objs)
                type = PDDL.get_objtype(state[], obj)
                r = get(renderer.obj_renderers, type, default_obj_renderer)
                graphic = @lift begin
                    x = $obj_locs[j]
                    g = translate(r(domain, $state, obj), x, 1)
                    g.attributes[:visible] = x > 0
                    g
                end
                graphicplot!(ax_i, graphic)
            end
            # Resize row
            rowsize!(canvas.layout, i+1, Auto(1/inventory_size[]))
        end
        rowgap!(canvas.layout, 10)
        resize_to_layout!(canvas.figure)
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
    # Determine set of objects to track
    state = trajectory[][1]
    objects = get(options, :tracked_objects, Const[])
    obj_colors = get(options, :object_colors, Any[])
    types = get(options, :tracked_types, Symbol[])
    type_colors = get(options, :type_colors, Any[])
    for (ty, col) in zip(types, type_colors)
        objs = PDDL.get_objects(domain, state, ty)
        append!(objects, objs)
        cols = col isa ColorScheme ?
            range(0, 1; length=length(objs)) : fill(col, length(objs))
        append!(obj_colors, cols)
    end
    # Construct observables for object locations and markers
    obj_locations = [Observable(Point2f[]) for _ in 1:length(objects)]
    obj_markers = [Observable(Symbol[]) for _ in 1:length(objects)]
    obj_rotations = [Observable(Float64[]) for _ in 1:length(objects)]
    # Construct observables for agent locations and markers
    locations = Observable(Point2f[])
    markers = Observable(Symbol[])
    rotations = Observable(Float64[])
    # Fill observables
    on(trajectory; update = true) do trajectory
        # Clear previous locations and markers
        for (ls, ms, rs) in zip(obj_locations, obj_markers, obj_rotations)
            empty!(ls[]); empty!(ms[]); empty!(rs[])
        end
        empty!(locations[])
        empty!(markers[])
        empty!(rotations[])
        # Add locations and markers for each timestep
        for (t, state) in enumerate(trajectory)
            next_state = trajectory[min(t+1, length(trajectory))]
            height = size(state[renderer.grid_fluents[1]], 1)
            # Add markers for tracked objects
            for (i, obj) in enumerate(objects)
                x = state[renderer.get_obj_x(obj)]
                y = height - state[renderer.get_obj_y(obj)] + 1
                push!(obj_locations[i], Point2f(x, y))
                next_x = next_state[renderer.get_obj_x(obj)]
                next_y = height - next_state[renderer.get_obj_y(obj)] + 1
                if next_x == x && next_y == y
                    push!(obj_markers[i], :circle)
                    push!(obj_rotations[i], 0.0)
                else
                    push!(obj_markers[i], :rtriangle)
                    push!(obj_rotations[i], atan(next_y - y, next_x - x))
                end
            end
            # Add markers for agent
            x = state[renderer.get_agent_x()]
            y = height - state[renderer.get_agent_y()] + 1
            push!(locations[], Point2f(x, y))
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
        for (ls, ms, rs) in zip(obj_locations, obj_markers, obj_rotations)
            notify(ls); notify(ms); notify(rs)
        end
        notify(locations)
        notify(markers)
        notify(rotations)
    end
    # Plot agent locations over time
    markersize = get(options, :agent_markersize, 20)
    color = get(options, :agent_color, :black)
    scatter!(ax, locations, marker=markers, rotations=rotations,
             markersize=markersize, color=color)
    # Return the canvas
    return canvas
end
