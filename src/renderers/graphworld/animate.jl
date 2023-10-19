function anim_initialize!(
    canvas::Canvas, renderer::GraphworldRenderer, domain::Domain, state::State;
    callback=nothing, overlay=nothing, kwargs...
)
    if canvas.state === nothing
        render_state!(canvas, renderer, domain, state; kwargs...)
    end
    # Run callbacks
    overlay !== nothing && overlay(canvas)
    callback !== nothing && callback(canvas)
    return canvas
end

function anim_transition!(
    canvas::Canvas, renderer::GraphworldRenderer, domain::Domain,
    state::State, action::Term = PDDL.no_op, t::Int = 1;
    options...
)
    options = merge(renderer.anim_options, options)
    transition = get(options, :transition, StepTransition())
    return anim_transition!(
        transition, canvas, renderer, domain, state, action, t;
        options...
    )
end

function anim_transition!(
    trans::StepTransition,
    canvas::Canvas, renderer::GraphworldRenderer, domain::Domain,
    state::State, action::Term = PDDL.no_op, t::Int = 1;
    callback=nothing, overlay=nothing, options...
)
    # Update canvas with new state
    canvas.state[] = state   
    # Run callback
    overlay !== nothing && overlay(canvas)
    callback !== nothing && callback(canvas)
    return canvas
end

function anim_transition!(
    trans::LinearTransition, 
    canvas::Canvas, renderer::GraphworldRenderer, domain::Domain,
    state::State, action::Term = PDDL.no_op, t::Int = 1;
    callback=nothing, overlay=nothing, options...
)
    options = merge(renderer.anim_options, options)
    # Copy starting node positions
    node_start_pos = copy(canvas.observables[:node_pos][])
    # Update canvas with new state
    canvas.state[] = state
    # Copy ending node positions
    node_stop_pos = copy(canvas.observables[:node_pos][])
    # Compute differences
    node_diffs = node_stop_pos .- node_start_pos
    # Temporarily disconnect graph layout from node positions
    layout = canvas.observables[:layout][]
    canvas.observables[:layout][] = node_start_pos
    # Compute number of frames
    move_speed = get(options, :move_speed, nothing)
    if move_speed === nothing
        frames_per_step = get(options, :frames_per_step, 24)
    else
        max_dist = maximum(GeometryBasics.norm.(node_diffs))
        frames_per_step = round(Int, max_dist / move_speed)
    end
    # Linearly interpolate between start and stop positions
    for t in 1:frames_per_step
        node_pos = node_start_pos .+ node_diffs .* t / frames_per_step
        canvas.observables[:layout][] = node_pos
        # Run callbacks
        overlay !== nothing && overlay(canvas)
        callback !== nothing && callback(canvas)
    end
    # Reconnect graph layout to node positions
    canvas.observables[:layout].val = layout
    return canvas
end

function anim_transition!(
    trans::ManhattanTransition, 
    canvas::Canvas, renderer::GraphworldRenderer, domain::Domain,
    state::State, action::Term = PDDL.no_op, t::Int = 1;
    callback=nothing, overlay=nothing, options...
)
    options = merge(renderer.anim_options, options)
    # Copy starting node positions
    node_start_pos = copy(canvas.observables[:node_pos][])
    # Update canvas with new state
    canvas.state[] = state
    # Copy ending node positions
    node_stop_pos = copy(canvas.observables[:node_pos][])
    # Temporarily disconnect graph layout from node positions
    layout = canvas.observables[:layout][]
    canvas.observables[:layout][] = node_start_pos
    # Compute node displacements for each direction
    diffs_per_dir = Vector{typeof(node_start_pos)}()
    node_pos = node_start_pos
    for (dir, stop_early) in zip(trans.order, trans.stop_early)
        # Project node displacements onto direction
        node_diffs = node_stop_pos .- node_start_pos
        node_diffs = map(node_diffs) do diff
            x, y = diff
            if dir == :up
                return Point2(zero(x), y > 0 ? y : zero(y))
            elseif dir == :down
                return Point2(zero(x), y < 0 ? y : zero(y))
            elseif dir == :left
                return Point2(x < 0 ? x : zero(x), zero(y))
            elseif dir == :right
                return Point2(x > 0 ? x : zero(x), zero(y))
            elseif dir == :horizontal
                return Point2(x, zero(y))
            elseif dir == :vertical
                return Point2(zero(x), y)
            else
                error("Invalid direction: $dir")
            end
        end
        # Check if any nodes have moved in this direction
        moved = any((d[1] != 0 || d[2] != 0) for d in node_diffs)
        !moved && continue
        # Add node displacements to list
        push!(diffs_per_dir, node_diffs)
        node_pos = node_pos + node_diffs
        stop_early && break 
    end
    # Compute total number of frames
    move_speed = get(options, :move_speed, nothing)
    if move_speed === nothing
        frames_per_step = get(options, :frames_per_step, 24)
    else
        max_dists = map(d -> maximum(GeometryBasics.norm.(d)), diffs_per_dir)
        total_dist = sum(max_dists)
        frames_per_step = round(Int, total_dist / move_speed)
    end
    # Compute frames per direction
    n_dirs = length(diffs_per_dir)
    frames_per_dir = fill(frames_per_step ÷ n_dirs, n_dirs)
    frames_per_dir[end] += frames_per_step % n_dirs
    # Iterate over node displacements per direction
    for (node_diffs, frames) in zip(diffs_per_dir, frames_per_dir)
        # Interpolate nodes along direction
        for t in 1:frames
            node_pos = node_start_pos .+ node_diffs .* t / frames
            canvas.observables[:layout][] = node_pos
            # Run callbacks
            overlay !== nothing && overlay(canvas)
            callback !== nothing && callback(canvas)
        end
        node_start_pos += node_diffs
    end
    # Reconnect graph layout to node positions
    canvas.observables[:layout].val = layout
    return canvas
end
