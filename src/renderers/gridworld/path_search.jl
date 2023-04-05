function render_sol!(
    canvas::Canvas, renderer::GridworldRenderer, domain::Domain,
    state::Observable, sol::Observable{<:PathSearchSolution};
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
    # Render search tree
    if get(options, :show_search, true) && !isnothing(sol[].search_tree)
        # Set up observables for agents
        agent_locs = Observable(Point2f[])
        agent_dirs = Observable(Point2f[])
        # Set up observables for tracked objects
        objects = get(options, :tracked_objects, Const[])
        types = get(options, :tracked_types, Symbol[])
        for ty in types
            objs = PDDL.get_objects(domain, state, ty)
            append!(objects, objs)
        end
        obj_locs = [Observable(Point2f[]) for _ in 1:length(objects)]
        obj_dirs = [Observable(Point2f[]) for _ in 1:length(objects)]
        # Fill observables
        on(sol; update = true) do sol
            # Clear previous values
            if renderer.has_agent
                empty!(agent_locs[]); empty!(agent_dirs[])
            end
            for (ls, ds) in zip(obj_locs, obj_dirs)
                empty!(ls[]); empty!(ds[])
            end
            # Determine node iteration order
            has_order = !isempty(sol.search_order)
            node_ids = has_order ? sol.search_order : keys(sol.search_tree)
            if has_order
                push!(node_ids, hash(sol.trajectory[end]))
            end
            # Iterate over nodes in search tree (in order if available)
            for id in node_ids
                node = sol.search_tree[id]
                isnothing(node.parent_id) && continue
                state = node.state
                prev_state = sol.search_tree[node.parent_id].state
                height = size(node.state[renderer.grid_fluents[1]], 1)
                # Update agent observables
                if renderer.has_agent
                    x = state[renderer.get_agent_x()]
                    y = height - state[renderer.get_agent_y()] + 1
                    prev_x = prev_state[renderer.get_agent_x()]
                    prev_y = height - prev_state[renderer.get_agent_y()] + 1
                    push!(agent_locs[], Point2f(prev_x, prev_y))
                    push!(agent_dirs[], Point2f(x-prev_x, y-prev_y))
                end
                # Update object observables
                for (i, obj) in enumerate(objects)
                    x = state[renderer.get_obj_x(obj)]
                    y = height - state[renderer.get_obj_y(obj)] + 1
                    prev_x = prev_state[renderer.get_obj_x(obj)]
                    prev_y = height - prev_state[renderer.get_obj_y(obj)] + 1
                    push!(obj_locs[i][], Point2f(prev_x, prev_y))
                    push!(obj_dirs[i][], Point2f(x-prev_x, y-prev_y))
                end
            end
            # Trigger updates
            if renderer.has_agent
                notify(agent_locs); notify(agent_dirs)
            end
            for (ls, ds) in zip(obj_locs, obj_dirs)
                notify(ls); notify(ds)
            end
        end
        # Create arrow plots for agent and tracked objects
        arrowsize = get(options, :search_size, 0.2)
        colors = @lift isempty($sol.search_order) ?
            get(options, :search_color, :red) : 1:length($agent_locs)
        cmap = get(options, :search_colormap, cgrad([:blue, :red]))
        arrows!(ax, agent_locs, agent_dirs; colormap=cmap, color=colors,
                arrowsize=arrowsize, markerspace=:data)
        for (ls, ds) in zip(obj_locs, obj_dirs)
            colors = @lift isempty($sol.search_order) ?
                get(options, :search_color, :red) : 1:length($ls)
            arrows!(ax, ls, ds; colormap=cmap, color=colors,
                    arrowsize=arrowsize, markerspace=:data)
        end
    end
    # Render trajectory
    if get(options, :show_trajectory, true) && !isnothing(sol[].trajectory)
        trajectory = @lift($sol.trajectory)
        render_trajectory!(canvas, renderer, domain, trajectory; options...)
    end
    return canvas
end
