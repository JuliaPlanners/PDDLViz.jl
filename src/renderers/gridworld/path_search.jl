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
        # Set up observables for agent
        if renderer.has_agent
            agent_locs = Observable(Point2f[])
            agent_dirs = Observable(Point2f[])
        end
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
                    loc = gw_agent_loc(renderer, state, height)
                    prev_loc = gw_agent_loc(renderer, prev_state, height)
                    push!(agent_locs[], loc)
                    push!(agent_dirs[], loc .- prev_loc)
                end
                # Update object observables
                for (i, obj) in enumerate(objects)
                    loc = gw_object_loc(renderer, state, obj, height)
                    prev_loc = gw_object_loc(renderer, prev_state, obj, height)
                    push!(obj_locs[i][], loc)
                    push!(obj_dirs[i][], loc .- prev_loc)
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
        node_marker = get(options, :search_marker, '⦿') 
        node_size = get(options, :search_size, 0.3)
        edge_arrow = get(options, :search_arrow, '▷')  
        cmap = get(options, :search_colormap, cgrad([:blue, :red]))
        if renderer.has_agent
            colors = @lift isempty($sol.search_order) ?
                get(options, :search_color, :red) : 1:length($agent_locs)
            canvas.plots[:agent_search_nodes] = arrows!(
                ax, agent_locs, agent_dirs, colormap=cmap, color=colors,
                arrowsize=node_size, arrowhead=node_marker,
                markerspace=:data, align=:head
            )
            edge_locs = @lift $agent_locs .- ($agent_dirs .* 0.5)
            edge_rotations = @lift [atan(d[2], d[1]) for d in $agent_dirs]
            edge_markers = @lift map($agent_dirs) do d
                d == Point2f(0, 0) ? node_marker : edge_arrow
            end
            canvas.plots[:agent_search_arrows] = scatter!(
                ax, edge_locs, rotation=edge_rotations,
                marker=edge_markers, markersize=node_size, markerspace=:data,
                colormap=cmap, color=colors
            )
        end
        for (obj, ls, ds) in zip(objects, obj_locs, obj_dirs)
            colors = @lift isempty($sol.search_order) ?
                get(options, :search_color, :red) : 1:length($ls)
            canvas.plots[Symbol("$(obj)_search_nodes")] = arrows!(
                ax, ls, ds, colormap=cmap, color=colors, markerspace=:data,
                arrowsize=node_size, arrowhead=node_marker, align=:head
            )
            e_ls = @lift $ls .- ($ds .* 0.5)
            e_rs = @lift [atan(d[2], d[1]) for d in $ds]
            e_ms = @lift map($ds) do d
                d == Point2f(0, 0) ? node_marker : edge_arrow
            end
            canvas.plots[Symbol("$(obj)_search_arrows")] = scatter!(
                ax, e_ls, rotation=e_rs, marker=e_ms, markersize=node_size,
                markerspace=:data, colormap=cmap, color=colors
            )
        end
    end
    # Render trajectory
    if get(options, :show_trajectory, true) && !isnothing(sol[].trajectory)
        trajectory = @lift($sol.trajectory)
        render_trajectory!(canvas, renderer, domain, trajectory; options...)
    end
    return canvas
end
