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
    # Set up observables for agent
    agent_locs = Observable(Point2f[])
    agent_markers = Observable(Union{Symbol,Char}[])
    agent_rotations = Observable(Float64[])
    agent_values = Observable(Float64[])
    # Update observables for reachable states
    on(sol; update=true) do sol
        # Clear previous values
        if renderer.has_agent
            empty!(agent_locs[])
            empty!(agent_markers[])
            empty!(agent_rotations[])
            empty!(agent_values[])
        end
        # Iterate over reachable states up to limit
        queue = [state[]]
        visited = Set{UInt}()
        while !isempty(queue) && length(visited) < max_states
            state = popfirst!(queue)
            state_id = hash(state)
            state_id in visited && continue
            push!(visited, state_id)
            # Get state value and best action
            val = SymbolicPlanners.get_value(sol, state)
            act = SymbolicPlanners.best_action(sol, state)
            # Get agent location
            renderer.has_agent || continue
            height = size(state[renderer.grid_fluents[1]], 1)
            x = state[renderer.get_agent_x()]
            y = height - state[renderer.get_agent_y()] + 1
            loc = Point2f(x, y)
            # Terminate if location has already been encountered
            loc in agent_locs[] && continue
            # Update agent observables
            push!(agent_locs[], loc)
            next_state = transition(domain, state, act)
            next_x = next_state[renderer.get_agent_x()]
            next_y = height - next_state[renderer.get_agent_y()] + 1
            if next_x == x && next_y == y
                push!(agent_markers[], '⦿') 
                push!(agent_rotations[], 0.0)
            else
                push!(agent_markers[], :rtriangle)
                push!(agent_rotations[], atan(next_y - y, next_x - x))
            end
            push!(agent_values[], val)
            # Add next states to queue
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
    # Render policy information
    if renderer.has_agent
        # Render state value heatmap
        if get(options, :show_value_heatmap, true)
            xs = @lift first.($agent_locs)
            ys = @lift last.($agent_locs)
            cmap = get(options, :value_colormap) do 
                cgrad(Makie.ColorSchemes.viridis, alpha=0.5)
            end
            heatmap!(ax, xs, ys, agent_values; colormap=cmap)
        end
        # Render best actions at each location
        if get(options, :show_actions, true)
            markersize = get(options, :step_markersize, 0.3)
            color = get(options, :agent_color, :black)
            scatter!(ax, agent_locs, marker=agent_markers,
                     rotations=agent_rotations, markersize=markersize,
                     color=color, markerspace=:data)
        end
        # Render state value labels at each location
        if get(options, :show_value_labels, true)
            label_locs = @lift $agent_locs .+ Point2f(0.0, 0.25)
            labels = @lift string.($agent_values)
            text!(ax, label_locs; text=labels, color=:black,
                  fontsize=0.2, markerspace=:data, align=(:center, :center))
        end
    end
    return canvas
end
