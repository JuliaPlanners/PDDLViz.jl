function (cb::AnimSolveCallback{GridworldRenderer})(
    planner::Union{ForwardPlanner, BreadthFirstPlanner},
    sol::PathSearchSolution, node_id::Union{UInt, Nothing}, priority
)
    renderer, canvas, domain = cb.renderer, cb.canvas, cb.domain
    options = isempty(cb.options) ?  renderer.trajectory_options :
        merge(renderer.trajectory_options, cb.options)
    # Extract agent observables
    if renderer.has_agent
        agent_locs = get!(Point2fVecObservable,
                          canvas.observables, :search_agent_locs)
        agent_dirs = get!(Point2fVecObservable,
                          canvas.observables, :search_agent_dirs)
    else
        agent_locs = nothing
        agent_dirs = nothing
    end
    # Extract object observables
    objects = get(options, :tracked_objects, Const[])
    types = get(options, :tracked_types, Symbol[])
    for ty in types
        objs = PDDL.get_objects(domain, state, ty)
        append!(objects, objs)
    end
    obj_locs = [get!(Point2fVecObservable, canvas.observables,
                     Symbol("search_$(obj)_locs")) for obj in objects]
    obj_dirs = [get!(Point2fVecObservable, canvas.observables,
                     Symbol("search_$(obj)_dirs")) for obj in objects]
    # Determine if search tree was reinitialized or rerooted
    n_expanded = length(sol.search_tree) - length(sol.search_frontier)
    n_expanded = max(n_expanded, sol.expanded)
    if renderer.has_agent
        tree_updated = length(agent_locs[]) != n_expanded-1
    else
        tree_updated = any(length(os[]) != n_expanded-1 for os in obj_locs)
    end
    # Rebuild search tree if tree was updated, otherwise add node to tree
    if tree_updated
        _build_tree!(agent_locs, agent_dirs, objects, obj_locs, obj_dirs,
                     renderer, sol, node_id)
    elseif !isnothing(node_id)
        _add_node_to_tree!(agent_locs, agent_dirs, objects, obj_locs, obj_dirs,
                           renderer, sol, node_id)
    end
    # Render search tree if necessary
    ax = canvas.blocks[1]
    node_marker = get(options, :search_marker, '⦿') 
    node_size = get(options, :search_size, 0.3)
    edge_arrow = get(options, :search_arrow, '▷')  
    cmap = get(options, :search_colormap, cgrad([:blue, :red]))
    if renderer.has_agent && !haskey(canvas.plots, :agent_search_nodes)
        colors = @lift 1:length($agent_locs)
        canvas.plots[:agent_search_nodes] = arrows!(
            ax, agent_locs, agent_dirs, color=colors, colormap=cmap,
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
            color=colors, colormap=cmap
        )
    end
    for (obj, ls, ds) in zip(objects, obj_locs, obj_dirs)
        haskey(canvas.plots, Symbol("$(obj)_search_nodes")) && continue
        colors = @lift 1:length($ls)
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
    # Trigger updates
    if renderer.has_agent
        notify(agent_locs); notify(agent_dirs)
    end
    for (ls, ds) in zip(obj_locs, obj_dirs)
        notify(ls); notify(ds)
    end
    # Run record callback if provided
    !isnothing(cb.record_callback) && cb.record_callback(canvas)
    cb.sleep_dur > 0 && sleep(cb.sleep_dur)
    return nothing
end
