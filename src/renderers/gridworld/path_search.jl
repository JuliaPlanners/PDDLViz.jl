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
        arrow_locs = Observable(Point2f[])
        arrow_dirs = Observable(Point2f[])
        on(sol; update = true) do sol
            empty!(arrow_locs[])
            empty!(arrow_dirs[])
            has_order = !isempty(sol.search_order)
            node_ids = has_order ? sol.search_order : keys(sol.search_tree)
            if has_order
                push!(node_ids, hash(sol.trajectory[end]))
            end
            for id in node_ids
                node = sol.search_tree[id]
                height = size(node.state[renderer.grid_fluents[1]], 1)
                x = node.state[renderer.get_agent_x()]
                y = height - node.state[renderer.get_agent_y()] + 1
                if node.parent_id !== nothing
                    prev_state = sol.search_tree[node.parent_id].state
                    prev_x = prev_state[renderer.get_agent_x()]
                    prev_y = height - prev_state[renderer.get_agent_y()] + 1
                    push!(arrow_locs[], Point2f(prev_x, prev_y))
                    push!(arrow_dirs[], Point2f(x-prev_x, y-prev_y))
                end
            end
            notify(arrow_locs)
            notify(arrow_dirs)
        end
        arrowsize = get(options, :search_size, 0.2)
        colors = @lift isempty($sol.search_order) ?
            get(options, :search_color, :red) : 1:length($arrow_locs)
        cmap = get(options, :search_colormap, cgrad([:blue, :red]))
        arrows!(ax, arrow_locs, arrow_dirs; colormap=cmap, color=colors,
                arrowsize=arrowsize, markerspace=:data)
    end
    # Render trajectory
    if get(options, :show_trajectory, true) && !isnothing(sol[].trajectory)
        trajectory = @lift($sol.trajectory)
        render_trajectory!(canvas, renderer, domain, trajectory; options...)
    end
    return canvas
end
