function (cb::AnimSolveCallback{GridworldRenderer})(
    planner::RealTimeHeuristicSearch,
    sol::PolicySolution, init_state::State, cur_state::State,
    n::Int, act, cur_v, best_act
)
    renderer, canvas, domain = cb.renderer, cb.canvas, cb.domain
    options = isempty(cb.options) ?  renderer.trajectory_options :
        merge(renderer.trajectory_options, cb.options)
    # Determine grid height
    height = size(cur_state[renderer.grid_fluents[1]], 1)
    # Advance to next state if current action is nothing
    if isnothing(act)
        cur_state = isnothing(best_act) ? 
            init_state : PDDL.transition(domain, cur_state, best_act)
    end
    # Extract agent observables
    Point2fVecObservable() = Observable(Point2f[])
    if renderer.has_agent
        agent_loc = get!(canvas.observables, :rths_agent_loc) do
            Observable(Point2f(gw_agent_loc(renderer, cur_state, height)))
        end
        agent_color = set_alpha(get(options, :agent_color, :black), 0.75)
        search_agent_locs =
            get!(Point2fVecObservable, canvas.observables, :search_agent_locs)
        search_agent_dirs =
            get!(Point2fVecObservable, canvas.observables, :search_agent_dirs)
    end
    # Extract object observables
    objects = get(options, :tracked_objects, Const[])
    obj_colors = get(options, :object_colors, Symbol[]) .|> to_color_obs
    types = get(options, :tracked_types, Symbol[])
    types = get(options, :tracked_types, Symbol[])
    type_colors = get(options, :type_colors, Symbol[]) .|> to_color_obs
    for (ty, col) in zip(types, type_colors)
        objs = PDDL.get_objects(domain, state, ty)
        append!(objects, objs)
        append!(obj_colors, fill(col, length(objs)))
    end
    obj_locs = map(objects) do obj
        get!(canvas.observables, Symbol("rths_$(obj)_loc")) do
            Observable(Point2f(gw_obj_loc(renderer, cur_state, obj, height)))
        end
    end
    obj_colors = map(col -> set_alpha(col, 0.75), obj_colors)
    search_obj_locs = [get!(Point2fVecObservable, canvas.observables,
                       Symbol("search_$(obj)_locs")) for obj in objects]
    search_obj_dirs = [get!(Point2fVecObservable, canvas.observables,
                       Symbol("search_$(obj)_dirs")) for obj in objects]
    # Extract solution observables
    sol_obs = get!(() -> Observable(sol), canvas.observables, :rths_solution)
    state_obs = get!(() -> Observable(cur_state), canvas.observables, :rths_state)
    # Render current locations if necessary
    loc_marker = get(options, :rths_loc_marker, '○')
    loc_markersize = get(options, :rths_loc_markersize, 0.6)
    ax = canvas.blocks[1]
    if renderer.has_agent && !haskey(canvas.plots, :rths_agent_loc)
        canvas.plots[:rths_agent_loc] =
            scatter!(ax, agent_loc, color=agent_color, markerspace=:data,
                     marker=loc_marker, markersize=loc_markersize)
    end
    if !isempty(objects) && !haskey(canvas.plots, :rths_obj_locs)
        canvas.plots[:rths_obj_locs] = scatter!(
            ax, obj_locs, color=obj_colors, markerspace=:data,
            marker=loc_marker, markersize=loc_markersize
        )
    end
    # Update location observables
    if renderer.has_agent
        agent_loc[] = Point2f(gw_agent_loc(renderer, cur_state, height))
    end
    for (obj, loc) in zip(objects, obj_locs)
        loc[] = Point2f(gw_obj_loc(renderer, cur_state, obj, height))
    end
    # Reset search locations if iteration has completed
    if isnothing(act)
        empty!(search_agent_locs[])
        empty!(search_agent_dirs[])
        notify(search_agent_locs)
        for (ls, ds) in zip(search_obj_locs, search_obj_dirs)
            empty!(ls[])
            empty!(ds[])
            notify(ls)
        end
    end
    # Render / update value heatmap
    if renderer.has_agent && !haskey(canvas.plots, :policy_values)
        render_sol!(canvas, renderer, domain, state_obs, sol_obs; options...)
    else
        state_obs.val = cur_state
        sol_obs[] = sol
    end
    # Run record callback if provided
    !isnothing(cb.record_callback) && cb.record_callback(canvas)
    cb.sleep_dur > 0 && sleep(cb.sleep_dur)
    return nothing
end
