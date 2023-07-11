function (cb::AnimSolveCallback{GridworldRenderer})(
    planner::RealTimeDynamicPlanner,
    sol::PolicySolution, n::Int, visited, stop_reason::Symbol
)
    renderer, canvas, domain = cb.renderer, cb.canvas, cb.domain
    options = isempty(cb.options) ?  renderer.trajectory_options :
        merge(renderer.trajectory_options, cb.options)
    # Extract initial state
    state = visited[1]
    prev_state = state
    height = size(state[renderer.grid_fluents[1]], 1)
    # Extract agent observables
    Point2fVecObservable() = Observable(Point2f[])
    if renderer.has_agent
        agent_locs = get!(Point2fVecObservable,
                          canvas.observables, :rtdp_agent_locs)
        agent_dirs = get!(Point2fVecObservable,
                          canvas.observables, :rtdp_agent_dirs)
    end
    # Extract object observables
    objects = get(options, :tracked_objects, Const[])
    types = get(options, :tracked_types, Symbol[])
    for ty in types
        objs = PDDL.get_objects(domain, state, ty)
        append!(objects, objs)
    end
    obj_locs = [get!(Point2fVecObservable, canvas.observables,
                     Symbol("rtdp_$(obj)_locs")) for obj in objects]
    obj_dirs = [get!(Point2fVecObservable, canvas.observables,
                     Symbol("rtdp_$(obj)_dirs")) for obj in objects]
    # Extract solution observables
    sol_obs = get!(() -> Observable(sol), canvas.observables, :rtdp_solution)
    state_obs = get!(() -> Observable(state), canvas.observables, :rtdp_state)
    # Reset agent observables
    if renderer.has_agent
        empty!(agent_locs[])
        empty!(agent_dirs[])
        loc = gw_agent_loc(renderer, state, height)
        prev_loc = gw_agent_loc(renderer, prev_state, height)
        push!(agent_locs[], loc)
        push!(agent_dirs[], loc .- prev_loc)
    end
    # Reset object observables
    for (i, obj) in enumerate(objects)
        empty!(obj_locs[i][])
        empty!(obj_dirs[i][])
        loc = gw_obj_loc(renderer, state, obj, height)
        prev_loc = gw_obj_loc(renderer, prev_state, obj, height)
        push!(obj_locs[i][], loc)
        push!(obj_dirs[i][], loc .- prev_loc)
    end
    # Render rollout if necessary
    ax = canvas.blocks[1]
    node_marker = get(options, :search_marker, '⦿') 
    node_size = get(options, :search_size, 0.3)
    edge_arrow = get(options, :search_arrow, '▷')  
    cmap = get(options, :search_colormap, cgrad([:blue, :red]))
    if renderer.has_agent && !haskey(canvas.plots, :agent_rtdp_nodes)
        colors = @lift 1:length($agent_locs)
        canvas.plots[:agent_rtdp_nodes] = arrows!(
            ax, agent_locs, agent_dirs, color=colors, colormap=cmap,
            arrowsize=node_size, arrowhead=node_marker,
            markerspace=:data, align=:head
        )
        edge_locs = @lift $agent_locs .- ($agent_dirs .* 0.5)
        edge_rotations = @lift [atan(d[2], d[1]) for d in $agent_dirs]
        edge_markers = @lift map($agent_dirs) do d
            d == Point2f(0, 0) ? node_marker : edge_arrow
        end
        canvas.plots[:agent_rtdp_arrows] = scatter!(
            ax, edge_locs, rotation=edge_rotations, color=colors, colormap=cmap,
            marker=edge_markers, markersize=node_size, markerspace=:data,            
        )
    end
    for (obj, ls, ds) in zip(objects, obj_locs, obj_dirs)
        haskey(canvas.plots, Symbol("$(obj)_rtdp_nodes")) && continue
        colors = @lift 1:length($ls)
        canvas.plots[Symbol("$(obj)_rtdp_nodes")] = arrows!(
            ax, ls, ds, colormap=cmap, color=colors, markerspace=:data,
            arrowsize=node_size, arrowhead=node_marker, align=:head
        )
        e_ls = @lift $ls .- ($ds .* 0.5)
        e_rs = @lift [atan(d[2], d[1]) for d in $ds]
        e_ms = @lift map($ds) do d
            d == Point2f(0, 0) ? node_marker : edge_arrow
        end
        canvas.plots[Symbol("$(obj)_rtdp_arrows")] = scatter!(
            ax, e_ls, rotation=e_rs, marker=e_ms, markersize=node_size,
            markerspace=:data, colormap=cmap, color=colors
        )
    end   
    !isnothing(cb.record_callback) && cb.record_callback(canvas)
    cb.sleep_dur > 0 && sleep(cb.sleep_dur)
    # Iterate over visited states
    for state in visited[2:end]
        # Update observables
        if renderer.has_agent
            loc = gw_agent_loc(renderer, state, height)
            prev_loc = gw_agent_loc(renderer, prev_state, height)
            push!(agent_locs[], loc)
            push!(agent_dirs[], loc .- prev_loc)
            notify(agent_locs); notify(agent_dirs)
        end
        for (i, obj) in enumerate(objects)
            loc = gw_obj_loc(renderer, state, obj, height)
            prev_loc = gw_obj_loc(renderer, prev_state, obj, height)
            push!(obj_locs[i][], loc)
            push!(obj_dirs[i][], loc .- prev_loc)
            notify(obj_locs[i]); notify(obj_dirs[i])
        end
        !isnothing(cb.record_callback) && cb.record_callback(canvas)
        cb.sleep_dur > 0 && sleep(cb.sleep_dur)
        prev_state = state
    end
    # Render / update value heatmap
    if (renderer.has_agent && !haskey(canvas.plots, :agent_policy_values)) ||
       (!isempty(objects) && !haskey(canvas.plots, Symbol("$(objects[1])_policy_values")))
         render_sol!(canvas, renderer, domain, state_obs, sol_obs; options...)
    else
        state_obs.val = visited[1]
        sol_obs[] = sol
    end
    !isnothing(cb.record_callback) && cb.record_callback(canvas)
    cb.sleep_dur > 0 && sleep(cb.sleep_dur)
    return nothing
end
