"""
    Transition

Abstract animation transition type.
"""
abstract type Transition end

"""
    StepTransition

Transition that immediately steps to the next state.
"""
struct StepTransition <: Transition end

"""
    LinearTransition

Transition that linearly interpolates between node positions.
"""
struct LinearTransition <: Transition end

function anim_transition!(
    canvas::Canvas, renderer::GraphworldRenderer, domain::Domain,
    state::State, action::Term = PDDL.no_op, t::Int = 1;
    transition=StepTransition(), options...
)
    options = merge(renderer.anim_options, options)
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
    # Linearly interpolate between start and stop positions
    frames_per_step = get(options, :frames_per_step, 10)
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
