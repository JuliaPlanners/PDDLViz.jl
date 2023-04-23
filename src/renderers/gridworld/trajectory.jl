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
    obj_markers = [Observable(Char[]) for _ in 1:length(objects)]
    obj_rotations = [Observable(Float64[]) for _ in 1:length(objects)]
    # Construct observables for agent locations and markers
    locations = Observable(Point2f[])
    markers = Observable(Char[])
    rotations = Observable(Float64[])
    # Fill observables
    on(trajectory; update = true) do trajectory
        # Clear previous locations and markers
        for (ls, ms, rs) in zip(obj_locations, obj_markers, obj_rotations)
            empty!(ls[]); empty!(ms[]); empty!(rs[])
        end
        if renderer.has_agent
            empty!(locations[]); empty!(markers[]); empty!(rotations[])
        end
        # Add locations and markers for each timestep
        for (t, state) in enumerate(trajectory)
            next_state = trajectory[min(t+1, length(trajectory))]
            height = size(state[renderer.grid_fluents[1]], 1)
            # Add markers for tracked objects
            for (i, obj) in enumerate(objects)
                x = state[renderer.get_obj_x(obj)]
                y = height - state[renderer.get_obj_y(obj)] + 1
                push!(obj_locations[i][], Point2f(x, y))
                next_x = next_state[renderer.get_obj_x(obj)]
                next_y = height - next_state[renderer.get_obj_y(obj)] + 1
                if next_x == x && next_y == y
                    push!(obj_markers[i][], '⦿')
                    push!(obj_rotations[i][], 0.0)
                else
                    push!(obj_markers[i][], '▶') 
                    push!(obj_rotations[i][], atan(next_y - y, next_x - x))
                end
            end
            # Add markers for agent
            renderer.has_agent || continue
            x = state[renderer.get_agent_x()]
            y = height - state[renderer.get_agent_y()] + 1
            push!(locations[], Point2f(x, y))
            next_x = next_state[renderer.get_agent_x()]
            next_y = height - next_state[renderer.get_agent_y()] + 1
            if next_x == x && next_y == y
                push!(markers[], '⦿') 
                push!(rotations[], 0.0)
            else
                push!(markers[], '▶')
                push!(rotations[], atan(next_y - y, next_x - x))
            end
        end
        # Trigger updates
        for (ls, ms, rs) in zip(obj_locations, obj_markers, obj_rotations)
            notify(ls); notify(ms); notify(rs)
        end
        if renderer.has_agent
            notify(locations); notify(markers); notify(rotations)
        end
    end
    markersize = get(options, :step_markersize, 0.3)
    # Plot agent locations over time
    if renderer.has_agent
        color = get(options, :agent_color, :black)
        scatter!(ax, locations, marker=markers, rotations=rotations,
                 markersize=markersize, color=color, markerspace=:data)
    end
    # Plot tracked object locations over time
    for (i, color) in enumerate(obj_colors)
        scatter!(ax, obj_locations[i], marker=obj_markers[i],
                 rotations=obj_rotations[i], markersize=markersize,
                 color=color, markerspace=:data)
    end
    # Return the canvas
    return canvas
end

"""
- `:agent_color = black`: Marker color of agent tracks.
- `:tracked_objects = Const[]`: Moving objects to plot marker tracks for.
- `:object_colors = Any[]`: Marker colors to use for tracked objects.
- `:tracked_types = Symbol[]`: Types of objects to track.
- `:type_colors = Any[]`: Marker colors to use for tracked object types.
- `:step_markersize = 0.3`: Size of track markers.
"""
default_trajectory_options(R::Type{GridworldRenderer}) = Dict{Symbol,Any}(
    :agent_color => :black,
    :tracked_objects => Const[],
    :object_colors => [],
    :tracked_types => Symbol[],
    :type_colors => [],
    :step_markersize => 0.3,
)
