
function (cb::AnimSolveCallback{GridworldRenderer})(
    planner::Union{ForwardPlanner, BreadthFirstPlanner},
    sol::PathSearchSolution, node_id::UInt, priority
)
    renderer, canvas, domain = cb.renderer, cb.canvas, cb.domain
    options = isempty(cb.options) ?  renderer.trajectory_options :
        merge(renderer.trajectory_options, cb.options)
    # Extract current and previous states
    node = sol.search_tree[node_id]
    state = node.state
    prev_state = isnothing(node.parent_id) ?
        state : sol.search_tree[node.parent_id].state
    height = size(state[renderer.grid_fluents[1]], 1)
    # Extract agent observables
    Point2fVecObservable() = Observable(Point2f[])
    if renderer.has_agent
        agent_locs = get!(Point2fVecObservable,
                          canvas.observables, :search_agent_locs)
        agent_dirs = get!(Point2fVecObservable,
                          canvas.observables, :search_agent_dirs)
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
    # Update agent observables
    if renderer.has_agent
        if sol.expanded == 1
            empty!(agent_locs[])
            empty!(agent_dirs[])
        end
        loc = gw_agent_loc(renderer, state, height)
        prev_loc = gw_agent_loc(renderer, prev_state, height)
        push!(agent_locs[], prev_loc)
        push!(agent_dirs[], loc .- prev_loc)
    end
    # Update object observables
    for (i, obj) in enumerate(objects)
        if sol.expanded == 1
            empty!(obj_locs[i][])
            empty!(obj_dirs[i][])
        end
        loc = gw_object_loc(renderer, state, obj, height)
        prev_loc = gw_object_loc(renderer, prev_state, obj, height)
        push!(obj_locs[i][], prev_loc)
        push!(obj_dirs[i][], loc .- prev_loc)
    end
    # Render search tree if necessary
    if sol.expanded == 1
        ax = canvas.blocks[1]
        node_marker = get(options, :search_marker, '⦿') 
        node_size = get(options, :search_size, 0.3)
        edge_arrow = get(options, :search_arrow, '▷')  
        cmap = get(options, :search_colormap, cgrad([:blue, :red]))
        if renderer.has_agent
            colors = @lift 1:length($agent_locs)
            arrows!(ax, agent_locs, agent_dirs; color=colors, colormap=cmap,
                    arrowsize=node_size, arrowhead=node_marker,
                    markerspace=:data)
            edge_locs = @lift $agent_locs .+ ($agent_dirs .* 0.5)
            edge_rotations = @lift [atan(d[2], d[1]) for d in $agent_dirs]
            edge_markers = @lift map($agent_dirs) do d
                d == Point2f(0, 0) ? node_marker : edge_arrow
            end
            scatter!(ax, edge_locs, 
                    marker=edge_markers, rotation=edge_rotations,
                    markersize=node_size, markerspace=:data,
                    color=colors, colormap=cmap)
        end
        for (ls, ds) in zip(obj_locs, obj_dirs)
            colors = @lift 1:length($agent_locs)
            arrows!(ax, ls, ds; colormap=cmap, color=colors, 
                    arrowsize=node_size, arrowhead=node_marker,
                    markerspace=:data)
            e_ls = @lift $ls .+ ($ds .* 0.5)
            e_rs = @lift [atan(d[2], d[1]) for d in $ds]
            e_ms = @lift map($ds) do d
                d == Point2f(0, 0) ? node_marker : edge_arrow
            end
            scatter!(ax, e_ls, marker=e_ms, rotation=e_rs,
                    markersize=node_size, markerspace=:data,
                    colormap=cmap, color=colors)
        end    
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
