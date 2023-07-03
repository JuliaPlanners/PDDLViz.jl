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
    obj_colors = get(options, :object_colors, Symbol[]) .|> to_color_obs
    obj_s_colors = get(options, :object_start_colors, obj_colors) .|> to_color_obs
    types = get(options, :tracked_types, Symbol[])
    type_colors = get(options, :type_colors, Symbol[]) .|> to_color_obs
    type_s_colors = get(options, :type_start_colors, type_colors) .|> to_color_obs
    for (ty, col, s_col) in zip(types, type_colors, type_s_colors)
        objs = PDDL.get_objects(domain, state, ty)
        append!(objects, objs)
        append!(obj_colors, fill(col, length(objs)))
        append!(obj_start_colors, fill(s_col, length(objs)))
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
    arrowmarker = get(options, :track_arrowmarker, '▶')
    stopmarker = get(options, :track_stopmarker, '⦿')
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
                loc = gw_obj_loc(renderer, state, obj, height)
                next_loc = gw_obj_loc(renderer, next_state, obj, height)
                push!(obj_locations[i][], loc)
                marker = loc == next_loc ? stopmarker : arrowmarker
                push!(obj_markers[i][], marker)
                rotation = atan(next_loc[2] - loc[2], next_loc[1] - loc[1])
                push!(obj_rotations[i][], rotation)
            end
            # Add markers for agent
            if renderer.has_agent
                loc = gw_agent_loc(renderer, state, height)
                next_loc = gw_agent_loc(renderer, next_state, height)
                push!(locations[], loc)
                marker = loc == next_loc ? stopmarker : arrowmarker
                push!(markers[], marker)
                rotation = atan(next_loc[2] - loc[2], next_loc[1] - loc[1])
                push!(rotations[], rotation)
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
    markersize = get(options, :track_markersize, 0.3)
    # Plot agent locations over time
    if renderer.has_agent
        stop_color = get(options, :agent_color, :black) |> to_color_obs
        start_color = get(options, :agent_start_color, stop_color) |> to_color_obs
        if start_color != stop_color
            color = @lift if length($trajectory) > 1
                cmap = cgrad([$start_color, $stop_color])
                cmap[range(0, 1; length=length($trajectory))]
            else
                [$stop_color]
            end
        else
            color = stop_color
        end
        scatter!(ax, locations, marker=markers, rotations=rotations,
                 markersize=markersize, color=color, markerspace=:data)
    end
    # Plot tracked object locations over time
    for (i, (col1, col2)) in enumerate(zip(obj_s_colors, obj_colors))
        if col1 != col2
            color = @lift if length($trajectory) > 1
                cmap = cgrad([$col1, $col2])
                cmap[range(0, 1; length=length($trajectory))]
            else
                [$col2]
            end
        else
            color = col2
        end
        scatter!(ax, obj_locations[i], marker=obj_markers[i],
                 rotations=obj_rotations[i], markersize=markersize,
                 color=color, markerspace=:data)
    end
    # Return the canvas
    return canvas
end

"""
- `:agent_color = black`: Marker color of agent tracks.
- `:agent_start_color = agent_color`: Marker color of agent tracks at the start
    of the trajectory, which fade into the main color.
- `:tracked_objects = Const[]`: Moving objects to plot marker tracks for.
- `:object_colors = Symbol[]`: Marker colors to use for tracked objects.
- `:object_start_colors = object_colors`: Marker colors to use for tracked
    objects at the start of the trajectory, which fade into the main color.
- `:tracked_types = Symbol[]`: Types of objects to track.
- `:type_colors = Symbol[]`: Marker colors to use for tracked object types.
- `:type_start_colors = type_colors`: Marker colors to use for tracked object
    types at the start of the trajectory, which fade into the main color.
- `:track_arrowmarker = '▶'`: Marker to use for directed tracks.
- `:track_stopmarker = '⦿'`: Marker to use for stationary tracks.
- `:track_markersize = 0.3`: Size of track markers.
"""
default_trajectory_options(R::Type{GridworldRenderer}) = Dict{Symbol,Any}(
    :agent_color => :black,
    :tracked_objects => Const[],
    :object_colors => Symbol[],
    :tracked_types => Symbol[],
    :type_colors => Symbol[],
    :track_arrowmarker => '▶',
    :track_stopmarker => '⦿',
    :track_markersize => 0.3,
)
