using SymbolicPlanners:
    get_value, has_cached_value, get_action, best_action

function render_sol!(
    canvas::Canvas, renderer::GridworldRenderer, domain::Domain,
    state::Observable, sol::Observable{<:PolicySolution};
    options...
)
    render_policy_heatmap!(canvas, renderer, domain, state, sol; options...)
    return canvas
end

function render_sol!(
    canvas::Canvas, renderer::GridworldRenderer, domain::Domain,
    state::Observable, sol::Observable{<:ReusableTreePolicy};
    options...
)
    # Render heatmap
    render_policy_heatmap!(canvas, renderer, domain, state, sol; options...)
    # Render search tree  
    if get(options, :show_search, true)
        search_sol = @lift($sol.search_sol)
        render_sol!(canvas, renderer, domain, state, search_sol;
                    show_search=true, options...)
    end
    return canvas
end

function render_policy_heatmap!(
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
    max_states = get(options, :max_policy_states, 200)
    arrowmarker = get(options, :track_arrowmarker, '▶')
    stopmarker = get(options, :track_stopmarker, '⦿')
    # Set up observables for agent
    if renderer.has_agent
        agent_locs = Observable(Point2f[])
        agent_values = Observable(Float64[])
        agent_markers = Observable(Char[])
        agent_rotations = Observable(Float64[])
    end
    # Set up observables for tracked objects
    objects = get(options, :tracked_objects, Const[])
    types = get(options, :tracked_types, Symbol[])
    for ty in types
        objs = PDDL.get_objects(domain, state, ty)
        append!(objects, objs)
    end
    obj_locs = [Observable(Point2f[]) for _ in 1:length(objects)]
    obj_values = [Observable(Float64[]) for _ in 1:length(objects)]
    # Update observables for reachable states
    show_cached_only = get(options, :show_cached_only, false)
    onany(sol, state) do sol, init_state
        # Update agent observables
        if renderer.has_agent
            # Clear previous values
            empty!(agent_locs[])
            empty!(agent_markers[])
            empty!(agent_rotations[])
            empty!(agent_values[])
            # Iterate over reachable agent locations up to limit
            queue = [init_state]
            visited = Set{UInt}()
            while !isempty(queue) && length(visited) < max_states
                state = popfirst!(queue)
                state_id = hash(state)
                state_id in visited && continue
                push!(visited, state_id)
                # Get agent location
                height = size(state[renderer.grid_fluents[1]], 1)
                loc = Point2f(gw_agent_loc(renderer, state, height))
                loc_exists = loc in agent_locs[]
                if show_cached_only && state != init_state
                    # Terminate if state has no cached value
                    !has_cached_value(sol, state) && continue
                else
                    # Terminate if location has already been encountered
                    loc_exists && continue
                end
                # Get state value and best action
                val = get_value(sol, state)
                best_act = best_action(sol, state)
                # Append agent location and value, etc.
                next_state = transition(domain, state, best_act)
                if !loc_exists # Skip if location already exists
                    push!(agent_locs[], loc)
                    next_loc = Point2f(gw_agent_loc(renderer, next_state, height))
                    marker = loc == next_loc ? stopmarker : arrowmarker
                    push!(agent_markers[], marker)
                    rotation = atan(next_loc[2] - loc[2], next_loc[1] - loc[1])
                    push!(agent_rotations[], rotation)
                    push!(agent_values[], val)
                end
                # Add next states to queue
                push!(queue, next_state)
                for act in available(domain, state)
                    next_state = transition(domain, state, act)
                    push!(queue, next_state)
                end
            end
            # Trigger updates
            notify(agent_locs)
            notify(agent_markers)
            notify(agent_rotations)
            notify(agent_values)
        end
        # Update observables for tracked objects
        for (obj, locs, vals) in zip(objects, obj_locs, obj_values)
            # Clear previous values
            empty!(locs[])
            empty!(vals[])
            # Add initial location and value
            if show_cached_only && has_cached_value(sol, init_state)
                push!(locs[], Point2f(gw_obj_loc(renderer, init_state, obj)))
                push!(vals[], get_value(sol, init_state))
            end
            # Add locations and values of neighboring states
            for act in available(domain, init_state)
                next_state = transition(domain, init_state, act)
                show_cached_only && !has_cached_value(sol, next_state) && continue
                next_loc = Point2f(gw_obj_loc(renderer, next_state, obj))
                next_loc in locs[] && continue
                push!(locs[], next_loc)
                push!(vals[], get_value(sol, next_state))
            end
            # Trigger updates
            notify(locs)
            notify(vals)
        end
    end
    notify(sol)
    # Render state value heatmap
    if get(options, :show_value_heatmap, true)
        cmap = get(options, :value_colormap) do 
            cgrad(Makie.ColorSchemes.viridis, alpha=0.5)
        end
        if renderer.has_agent
            marker = _policy_heatmap_marker()
            plt = scatter!(ax, agent_locs, color=agent_values, colormap=cmap,
                            marker=marker, markerspace=:data, markersize=1.0)
            Makie.translate!(plt, 0.0, 0.0, -0.5)
            canvas.plots[:agent_policy_values] = plt
        end
        for (i, obj) in enumerate(objects)
            marker = _policy_heatmap_marker(length(objects), i)
            locs, vals = obj_locs[i], obj_values[i]
            plt = scatter!(ax, locs, color=vals, colormap=cmap,
                            marker=marker, markerspace=:data, markersize=1.0)
            Makie.translate!(plt, 0.0, 0.0, -0.5)
            canvas.plots[Symbol("$(obj)_policy_values")] = plt
        end
    end
    # Render best agent actions at each location
    if get(options, :show_actions, true) && renderer.has_agent
        markersize = get(options, :track_markersize, 0.3)
        color = get(options, :agent_color, :black)
        plt = scatter!(ax, agent_locs, marker=agent_markers,
                        rotations=agent_rotations, markersize=markersize,
                        color=color, markerspace=:data)
        canvas.plots[:agent_policy_actions] = plt
    end
    # Render state value labels at each location
    if get(options, :show_value_labels, true)
        if renderer.has_agent
            offset = _policy_label_offset()
            label_locs = @lift $agent_locs .+ offset
            labels = @lift map($agent_values) do val
                @sprintf("%.1f", val)
            end
            plt = text!(ax, label_locs; text=labels, color=:black,
                        fontsize=0.2, markerspace=:data,
                        align=(:center, :center))
            canvas.plots[:agent_policy_labels] = plt
        end
        for (i, obj) in enumerate(objects)
            locs, vals = obj_locs[i], obj_values[i]
            label_locs = @lift $locs .+ _policy_label_offset(length(objects), i)
            labels = @lift map($vals) do val
                @sprintf("%.1f", val)
            end
            fontsize = length(objects) > 2 ? 0.15 : 0.2
            plt = text!(ax, label_locs; text=labels, color=:black,
                        fontsize=fontsize, markerspace=:data,
                        align=(:center, :center))
            canvas.plots[Symbol("$(obj)_policy_labels")] = plt
        end
    end
    return canvas
end

function _policy_heatmap_marker(n::Int = 1, i::Int = 1)
    if n <= 1 # Square marker for single agent
        return Polygon(Point2f.([(-.5, -.5), (-.5, .5), (.5, .5), (.5, -.5)]))
    elseif n <= 2 # Bottom left and top right triangles for 2 agents
        if i == 1
            return Polygon(Point2f.([(-.5, -.5), (-.5, .5), (.5, -.5)]))
        elseif i == 2
            return Polygon(Point2f.([(.5, .5), (.5, -.5), (-.5, .5)]))
        end
    elseif n <= 4 # Four triangles for 4 or less agents
        if i == 1
            return Polygon(Point2f.([(-.5, -.5), (-.5, .5), (0.0, 0.0)]))
        elseif i == 2
            return Polygon(Point2f.([(-.5, .5), (.5, .5), (0.0, 0.0)]))
        elseif i == 3
            return Polygon(Point2f.([(.5, .5), (.5, -.5), (0.0, 0.0)]))
        elseif i == 4
            return Polygon(Point2f.([(.5, -.5), (-.5, -.5), (0.0, 0.0)]))
        end
    else # Circle marker for more than 4 agents
        angle = 2*pi*i/n
        x, y = 2/n*cos(angle), 2/n*sin(angle)
        points = decompose(Point2f, Circle(Point2f(x, y), 1/n))
        return Polygon(points)
    end 
end

function _policy_label_offset(n::Int=1, i::Int=1)
    if n <= 1
        return Point2f(0.0, 0.25)
    elseif n <= 2
        if i == 1
            return Point2f(-0.2, -0.2)
        elseif i == 2
            return Point2f(0.2, 0.2)
        end
    elseif n <= 4
        if i == 1
            return Point2f(-0.3, 0.0)
        elseif i == 2
            return Point2f(0.0, 0.3)
        elseif i == 3
            return Point2f(0.3, 0.0)
        elseif i == 4
            return Point2f(0.0, -0.3)
        end
    else
        angle = 2*pi*i/n
        x, y = 2/n*cos(angle), 2/n*sin(angle)
        return Point2f(x, y)
    end
end
