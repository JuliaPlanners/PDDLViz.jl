function render_sol!(
    canvas::Canvas, renderer::GridworldRenderer, domain::Domain,
    state::Observable, sol::Observable{<:PolicySolution};
    options...
)
    # Render initial state if not already on canvas
    if canvas.state === nothing
        render_state!(canvas, renderer, domain, state; options...)
    end
    # Extract main axis
    ax = canvas.blocks[1]
    # Update options
    options = merge(renderer.trajectory_options, options)
    max_states = get(options, :max_states, 200)
    arrowmarker = get(options, :track_arrowmarker, '▶')
    stopmarker = get(options, :track_stopmarker, '⦿')
    # Set up observables for agent
    agent_locs = Observable(Point2f[])
    agent_markers = Observable(Char[])
    agent_rotations = Observable(Float64[])
    agent_values = Observable(Float64[])
    # Update observables for reachable states
    onany(sol, state) do sol, init_state
        # Clear previous values
        if renderer.has_agent
            empty!(agent_locs[])
            empty!(agent_markers[])
            empty!(agent_rotations[])
            empty!(agent_values[])
        end
        # Iterate over reachable states up to limit
        queue = [init_state]
        visited = Set{UInt}()
        while !isempty(queue) && length(visited) < max_states
            state = popfirst!(queue)
            state_id = hash(state)
            state_id in visited && continue
            push!(visited, state_id)
            # Get state value and best action
            val = SymbolicPlanners.get_value(sol, state)
            best_act = SymbolicPlanners.best_action(sol, state)
            # Get agent location
            renderer.has_agent || continue
            height = size(state[renderer.grid_fluents[1]], 1)
            loc = Point2f(gw_agent_loc(renderer, state, height))
            # Terminate if location has already been encountered
            loc in agent_locs[] && continue
            # Update agent observables
            push!(agent_locs[], loc)
            next_state = transition(domain, state, best_act)
            next_loc = Point2f(gw_agent_loc(renderer, next_state, height))
            marker = loc == next_loc ? stopmarker : arrowmarker
            push!(agent_markers[], marker)
            rotation = atan(next_loc[2] - loc[2], next_loc[1] - loc[1])
            push!(agent_rotations[], rotation)
            push!(agent_values[], val)
            # Add next states to queue
            push!(queue, next_state)
            for act in available(domain, state)
                next_state = transition(domain, state, act)
                push!(queue, next_state)
            end
        end
        # Trigger updates
        if renderer.has_agent
            notify(agent_locs)
            notify(agent_markers)
            notify(agent_rotations)
            notify(agent_values)
        end
    end
    notify(sol)
    # Render policy information
    if renderer.has_agent
        # Render state value heatmap
        if get(options, :show_value_heatmap, true)
            cmap = get(options, :value_colormap) do 
                cgrad(Makie.ColorSchemes.viridis, alpha=0.5)
            end
            marker = Polygon(Point2f.([(-.5, -.5), (-.5, .5),
                                       (.5, .5), (.5, -.5)]))
            plt = scatter!(ax, agent_locs, color=agent_values, colormap=cmap,
                           marker=marker, markerspace=:data, markersize=1.0)
            Makie.translate!(plt, 0.0, 0.0, -0.5)
            canvas.plots[:policy_values] = plt
        end
        # Render best actions at each location
        if get(options, :show_actions, true)
            markersize = get(options, :track_markersize, 0.3)
            color = get(options, :agent_color, :black)
            plt = scatter!(ax, agent_locs, marker=agent_markers,
                           rotations=agent_rotations, markersize=markersize,
                           color=color, markerspace=:data)
            canvas.plots[:policy_actions] = plt
        end
        # Render state value labels at each location
        if get(options, :show_value_labels, true)
            label_locs = @lift $agent_locs .+ Point2f(0.0, 0.25)
            labels = @lift map($agent_values) do val
                @sprintf("%.1f", val)
            end
            plt = text!(ax, label_locs; text=labels, color=:black,
                        fontsize=0.2, markerspace=:data,
                        align=(:center, :center))
            canvas.plots[:policy_value_labels] = plt
        end
    end
    return canvas
end
