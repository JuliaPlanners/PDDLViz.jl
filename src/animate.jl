export anim_initialize!, anim_transition!
export anim_plan!, anim_plan
export anim_trajectory!, anim_trajectory
export anim_solve!, anim_solve, anim_refine!

import Makie: FigureLike

"""
    Animation

Displayable animation which wraps a `VideoStream` object. Can be displayed
with `show(io, MIME"text/html"(), anim)`, or saved with `save(path, anim)`.
"""
mutable struct Animation
    videostream::VideoStream
    path::String
end

Animation(videostream::VideoStream) =
    Animation(videostream, videostream.path)

Animation(figlike::FigureLike; kwargs...) =
    Animation(VideoStream(figlike; kwargs...))

Animation(canvas::Canvas; kwargs...) =
    Animation(canvas.figure; kwargs...)

Makie.recordframe!(anim::Animation) =
    recordframe!(anim.videostream)

function FileIO.save(path::AbstractString, anim::Animation; kwargs...)
    if anim.path == anim.videostream.path
        save(path, anim.videostream; kwargs...)
        anim.path = abspath(path)
    elseif anim.path != abspath(path)
        format = lstrip(splitext(path)[2], '.')
        options = anim.videostream.options
        if format != options.format || !isempty(kwargs)
            framerate = get(kwargs, :framerate, options.framerate)
            Makie.convert_video(anim.path, path; framerate=framerate, kwargs...)
        else
            cp(anim.path, path; force=true)
        end
    else
        warn("Animation already saved to $path.")
    end
    return path
end

Base.show(io::IO, ::MIME"juliavscode/html", anim::Animation) =
    show(io, MIME"text/html"(), anim)

function Base.show(io::IO, ::MIME"text/html", anim::Animation)
    # Save to file if not already saved
    format = anim.videostream.options.format
    if anim.path == anim.videostream.path
        dir = mktempdir()
        path = joinpath(dir, "$(gensym(:video)).$(format)")
        save(path, anim)
    end
    # Display animation as HTML tag, depending on format
    if format == "gif"
        # Display GIFs as image tags
        blob = base64encode(read(anim.path))
        print(io, "<img src=\"data:image/gif;base64,$blob\">")
    elseif format == "mp4"
        # Display MP4 videos as video tags
        blob = base64encode(read(anim.path))
        print(io, "<video controls autoplay muted>",
             "<source src=\"data:video/mp4;base64,$blob\"",
             "type=\"video/mp4\"></video>")
    else
        # Convert other video types to MP4
        mktempdir() do dir
            path = joinpath(dir, "video.mp4")
            save(path, anim)
            blob = base64encode(read(path))
            print(io, "<video controls autoplay muted>",
                  "<source src=\"data:video/mp4;base64,$blob\"",
                  "type=\"video/mp4\"></video>")
        end
    end
end

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

"""
    ManhattanTransition(;
        order = [:up, :horizontal, :down],
        stop_early = [true, false, false]
    )

Transition that interpolates between node positions by moving horizontally
and vertically.

# Arguments

- `order::Vector{Symbol} = [:up, :horizontal, :down]`: Order in which to
  interpolate between node positions. Valid values are `:up`, `:down`,
  `:left`, `:right`, `:horizontal`, and `:vertical`.
- `stop_early::Vector{Bool} = [true, false, false]`: Whether to stop
  interpolating early for each direction. If `true`, then the transition
  will stop once that direction is done. If no nodes have moved in that 
  direction, then the transition will continue to the next direction.
"""
@kwdef struct ManhattanTransition <: Transition
    order::Vector{Symbol} = [:up, :horizontal, :down]
    stop_early::Vector{Bool} = [true, false, false]
end

"""
    anim_initialize!(canvas, renderer, domain, state;
                     callback=nothing, overlay=nothing, kwargs...)

Initializes an animation that will be rendered on the `canvas`. Called by
[`anim_plan`](@ref) and [`anim_trajectory`](@ref) as an initialization step.

By default, this just renders the initial `state` on the `canvas`. This function
can be overloaded for different [`Renderer`](@ref) types to implement custom
initializations, e.g., to add captions or other overlays.
"""
function anim_initialize!(
    canvas::Canvas, renderer::Renderer, domain::Domain, state::State;
    callback=nothing, overlay=nothing, kwargs...
)
    if canvas.state === nothing
        render_state!(canvas, renderer, domain, state; kwargs...)
    else
        anim_transition!(canvas, renderer, domain, state; kwargs...)
    end
    # Run callbacks
    overlay !== nothing && overlay(canvas)
    callback !== nothing && callback(canvas)
    return canvas
end

"""
    anim_transition!(canvas, renderer, domain, state, [action, t];
                     callback=nothing, overlay=nothing, kwargs...)

Animates a transition from the current state stored in the `canvas` to the
newly provided `state` (via `action` at timestep `t` if provided). Called by
[`anim_plan`](@ref) and [`anim_trajectory`](@ref) to animate a series of
state transitions.

By default, this updates the `canvas` with the new `state`, then runs the
`overlay` and `callback` functions (if provided) on `canvas` (e.g. to ovelay
annotations, or to record a frame).
    
This function can be overloaded for different [`Renderer`](@ref) types to
implement custom transitions, e.g., transitions that involve multiple frames. 
"""
function anim_transition!(
    canvas::Canvas, renderer::Renderer, domain::Domain,
    state::State, action::Term, t::Int;
    callback=nothing, overlay=nothing, kwargs...
)
    # Ignore timestep by default
    return anim_transition!(canvas, renderer, domain, state, action;
                            callback, overlay, kwargs...)
end

function anim_transition!(
    canvas::Canvas, renderer::Renderer, domain::Domain,
    state::State, action::Term;
    callback=nothing, overlay=nothing, kwargs...
)
    # Ignore action by default
    return anim_transition!(canvas, renderer, domain, state;
                            callback, overlay, kwargs...)
end

function anim_transition!(
    canvas::Canvas, renderer::Renderer, domain::Domain, state::State;
    callback=nothing, overlay=nothing, kwargs...
)
    # Default to updating canvas with new state
    canvas.state[] = state   
    # Run callback
    overlay !== nothing && overlay(canvas)
    callback !== nothing && callback(canvas)
    return canvas
end

"""
    anim_plan([path], renderer, domain, state, actions;
              format="mp4", framerate=5, show=false,
              record_init=true, options...)
              
    anim_plan!([anim|path], canvas, renderer, domain, state, actions;
               format="mp4", framerate=5, show=is_displayed(canvas),
               record_init=true, options...)

Uses `renderer` to animate a series of `actions` in a PDDL `domain` starting
from `state` (updating the `canvas` if one is provided). An [`Animation`](@ref)
object is returned, which can be saved or displayed. 

An existing `anim` can provided as the first argument, so that frames are 
appended to that animation (format and frame rates are ignored in this case).
Alternatively, if a `path` is specified, the animation is saved to that file,
and the `path` is returned.

Note that once an animation is displayed or saved, no frames can be added to it.
"""
function anim_plan(
    renderer::Renderer, domain::Domain, state::State, actions;
    show::Bool=false, kwargs...
)
    canvas = new_canvas(renderer)
    return anim_plan!(canvas, renderer, domain, state, actions;
                      show, kwargs...)
end

function anim_plan(path::AbstractString, args...; kwargs...)
    format = lstrip(splitext(path)[2], '.')
    save(path, anim_plan(args...; format, kwargs...))
end

function anim_plan!(
    canvas::Canvas, renderer::Renderer, domain::Domain, state::State, actions;
    kwargs...
)
    trajectory = PDDL.simulate(domain, state, actions)
    return anim_trajectory!(canvas, renderer, domain,
                            trajectory, actions; kwargs...)
end

function anim_plan!(
    anim::Animation, canvas::Canvas, 
    renderer::Renderer, domain::Domain, state::State, actions;
    kwargs...
)
    trajectory = PDDL.simulate(domain, state, actions)
    return anim_trajectory!(anim, canvas, renderer, domain,
                            trajectory, actions; kwargs...)
end

function anim_plan!(path::AbstractString, args...; kwargs...)
    format = lstrip(splitext(path)[2], '.')
    save(path, anim_plan!(args...; format, kwargs...))
end

@doc (@doc anim_plan) anim_plan!

"""
    anim_trajectory([path], renderer, domain, trajectory, [actions];
                    format="mp4", framerate=5, show=false,
                    record_init=true, options...)
                    
    anim_trajectory!([anim|path], canvas, renderer,
                     domain, trajectory, [actions];
                     format="mp4", framerate=5, show=is_displayed(canvas),
                     record_init=true, options...)

Uses `renderer` to animate a `trajectory` in a PDDL `domain` (updating the
`canvas` if one is provided).  An [`Animation`](@ref) object is returned,
which can be saved or displayed. 
    
An existing `anim` can provided as the first argument, so that frames are 
appended to that animation (format and frame rates are ignored in this case).
Alternatively, if a `path` is specified, the animation is saved to that file,
and the `path` is returned.

Note that once an animation is displayed or saved, no frames can be added to it.
"""
function anim_trajectory(
    renderer::Renderer, domain::Domain,
    trajectory, actions=fill(PDDL.no_op, length(trajectory)-1);
    show::Bool=false, kwargs...
)
    canvas = new_canvas(renderer)
    return anim_trajectory!(canvas, renderer, domain, trajectory;
                            show, kwargs...)
end

function anim_trajectory(path::AbstractString, args...; kwargs...)
    format = lstrip(splitext(path)[2], '.')
    save(path, anim_trajectory(args...; format=format, kwargs...))
end

function anim_trajectory!(
    canvas::Canvas, renderer::Renderer, domain::Domain,
    trajectory, actions=fill(PDDL.no_op, length(trajectory)-1);
    format="mp4", framerate=5, show::Bool=is_displayed(canvas),
    showrate=framerate, record_init=true, options...
)
    # Display canvas if `show` is true
    show && !is_displayed(canvas) && display(canvas)
    # Initialize animation
    record_args = filter(Dict(options)) do (k, v)
        k in (:compression, :profile, :pixel_format, :loop)
    end
    anim = Animation(canvas.figure; visible=is_displayed(canvas),
                     format, framerate, record_args...)
    # Record animation
    anim_trajectory!(anim, canvas, renderer, domain, trajectory, actions;
                     show, showrate, record_init, options...)
    return anim
end

function anim_trajectory!(
    anim::Animation, canvas::Canvas, renderer::Renderer, domain::Domain,
    trajectory, actions=fill(PDDL.no_op, length(trajectory)-1);
    show::Bool=is_displayed(canvas), showrate=5, record_init=true, options...
)
    # Display canvas if `show` is true
    show && !is_displayed(canvas) && display(canvas)
    # Initialize animation and record initial frame
    anim_initialize!(canvas, renderer, domain, trajectory[1]; options...)
    record_init && recordframe!(anim)
    # Construct recording callback
    function record_callback(canvas::Canvas)
        recordframe!(anim)
        !show && return
        notify(canvas.state)
        sleep(1/showrate)
    end
    # Iterate over subsequent states and actions
    for (t, act) in enumerate(actions)
        state = trajectory[t+1]
        anim_transition!(canvas, renderer, domain, state, act, t+1;
                         callback=record_callback, options...)
    end
    return anim
end

function anim_trajectory!(path::AbstractString, args...; kwargs...)
    format = lstrip(splitext(path)[2], '.')
    save(path, anim_trajectory!(args...; format=format, kwargs...))
end

@doc (@doc anim_trajectory) anim_trajectory!

"""
    AnimSolveCallback{R <: Renderer}

A callback for [`anim_solve`](@ref) that animates the solving process of a 
SymbolicPlanners.jl [`Planner`]. The behavior of this callback can be customized
on a per-renderer and per-`planner`` basis by defining a new method for 
`(cb::AnimSolveCallback{R <: Renderer)(planner::Planner, args...)`.
"""
struct AnimSolveCallback{R <: Renderer} <: Function
    renderer::R
    domain::Domain
    canvas::Canvas
    sleep_dur::Float64
    record_callback::Union{Nothing, Function}
    options::Dict{Symbol, Any}
end

function AnimSolveCallback(
    renderer::R, domain::Domain, canvas::Canvas,
    sleep_dur::Real = 0.0, record_callback = nothing;
    options...
) where {R <: Renderer}
    return AnimSolveCallback{R}(renderer, domain, canvas, sleep_dur,
                                record_callback, Dict(options))
end

"""
    anim_solve([path], renderer, planner, domain, state, spec;
               format="mp4", framerate=30, show=false,
               record_init=true, options...)

    anim_solve!([anim|path], canvas, renderer,
                planner, domain, state, spec;
                format="mp4", framerate=30, show=is_displayed(canvas),
                record_init=true, options...)

Uses `renderer` to animate the solving process of a SymbolicPlanners.jl
`planner` in a PDDL `domain` (updating the `canvas` if one is provided).

Returns a tuple `(anim, sol)` where `anim` is an [`Animation`](@ref) object
containing the animation, and `sol` is the solution returned by `planner`. If 
`anim` is provided as the first argument, then additional frames are added to 
the animation. Alternatively, if a `path` is provided, the animation is saved
to that file, and `(path, sol)` is returned.

Note that once an animation is displayed or saved, no frames can be added to it.
"""
function anim_solve(
    renderer::Renderer, planner::Planner, domain::Domain, state::State, spec;
    show::Bool=false, kwargs...
)
    canvas = new_canvas(renderer)
    return anim_solve!(canvas, renderer, planner, domain, state, spec;
                       show=show, kwargs...)
end

function anim_solve(path::AbstractString, args...; kwargs...)
    format = lstrip(splitext(path)[2], '.')
    anim, sol = anim_solve(args...; format=format, kwargs...)
    save(path, anim)
    return (path, sol)
end

function anim_solve!(
    canvas::Canvas, renderer::Renderer,
    planner::Planner, domain::Domain, state::State, spec;
    format="mp4", framerate=30, show::Bool=is_displayed(canvas),
    showrate=framerate, record_init=true, options...
)
    # Display canvas if `show` is true
    show && !is_displayed(canvas) && display(canvas)
    # Initialize animation
    record_args = filter(Dict(options)) do (k, v)
        k in (:compression, :profile, :pixel_format, :loop)
    end
    anim = Animation(canvas.figure; visible=is_displayed(canvas), format=format,
                     framerate=framerate, record_args...)
    # Record animation
    return anim_solve!(anim, canvas, renderer, planner, domain, state, spec;
                       show, showrate, record_init, options...)
end

function anim_solve!(
    anim::Animation, canvas::Canvas, renderer::Renderer,
    planner::Planner, domain::Domain, state::State, spec;
    show::Bool=is_displayed(canvas), showrate=30, record_init=true, options...
)
    # Display canvas if `show` is true
    show && !is_displayed(canvas) && display(canvas)
    # Initialize animation and record initial frame
    anim_initialize!(canvas, renderer, domain, state; options...)
    record_init && recordframe!(anim)
    # Construct recording callback
    function record_callback(canvas::Canvas)
        recordframe!(anim)
        !show && return
        notify(canvas.state)
        sleep(1/showrate)
    end
    # Construct animation callback
    anim_callback = AnimSolveCallback(renderer, domain, canvas, 0.0,
                                      record_callback; options...)
    # Run planner and return solution with animation
    planner = add_anim_callback(planner, anim_callback)
    sol = SymbolicPlanners.solve(planner, domain, state, spec)
    return (anim, sol)
end

function anim_solve!(path::AbstractString, args...; kwargs...)
    format = lstrip(splitext(path)[2], '.')
    anim, sol = anim_solve!(args...; format=format, kwargs...)
    save(path, anim)
    return (path, sol)
end

@doc (@doc anim_solve) anim_solve!

"""
    anim_refine!([path], renderer,
                 sol, planner, domain, state, spec;
                 format="mp4", framerate=30, show=false,
                 record_init=true, copy_sol=false, options...)

    anim_refine!([anim|path], canvas, renderer,
                 sol, planner, domain, state, spec;
                 format="mp4", framerate=30, show=is_displayed(canvas),
                 record_init=true, copy_sol=false, options...)

Uses `renderer` to animate the refinement of an existing solution by a
SymbolicPlanners.jl `planner` in a PDDL `domain` (updating the `canvas`
if one is provided).

Returns a tuple `(anim, sol)` where `anim` is an [`Animation`](@ref) object
containing the animation, and `sol` is the solution returned by `planner`. If 
`anim` is provided as the first argument, then additional frames are added to 
the animation. Alternatively, if a `path` is provided, the animation is saved
to that file, and `(path, sol)` is returned. If `copy_sol` is `true`, then
a copy of the initial solution is made before refinement.

Note that once an animation is displayed or saved, no frames can be added to it.
"""
function anim_refine!(
    renderer::Renderer,
    sol::Solution, planner::Planner, domain::Domain, state::State, spec;
    show::Bool=false, kwargs...
)
    canvas = new_canvas(renderer)
    return anim_refine!(canvas, renderer, sol, planner, domain, state, spec;
                        show=show, kwargs...)
end

function anim_refine!(path::AbstractString, args...; kwargs...)
    format = lstrip(splitext(path)[2], '.')
    anim, sol = anim_refine!(args...; format=format, kwargs...)
    save(path, anim)
    return (path, sol)
end

function anim_refine!(
    canvas::Canvas, renderer::Renderer,
    sol::Solution, planner::Planner, domain::Domain, state::State, spec;
    format="mp4", framerate=30, show::Bool=is_displayed(canvas),
    showrate=framerate, record_init=true, options...
)
    # Display canvas if `show` is true
    show && !is_displayed(canvas) && display(canvas)
    # Initialize animation
    record_args = filter(Dict(options)) do (k, v)
        k in (:compression, :profile, :pixel_format, :loop)
    end
    anim = Animation(canvas.figure; visible=is_displayed(canvas), format=format,
                     framerate=framerate, record_args...)
    # Record animation
    return anim_refine!(anim, canvas, renderer,
                        sol, planner, domain, state, spec;
                        show, showrate, record_init, options...)
end

function anim_refine!(
    anim::Animation, canvas::Canvas, renderer::Renderer,
    sol::Solution, planner::Planner, domain::Domain, state::State, spec;
    show::Bool=is_displayed(canvas), showrate=30, record_init=true,
    copy_sol::Bool=false, options...
)
    # Display canvas if `show` is true
    show && !is_displayed(canvas) && display(canvas)
    # Initialize animation and record initial frame
    anim_initialize!(canvas, renderer, domain, state; options...)
    record_init && recordframe!(anim)
    # Construct recording callback
    function record_callback(canvas::Canvas)
        recordframe!(anim)
        !show && return
        notify(canvas.state)
        sleep(1/showrate)
    end
    # Construct animation callback
    anim_callback = AnimSolveCallback(renderer, domain, canvas, 0.0,
                                      record_callback; options...)
    # Refine existing solution and return solution with animation
    planner = add_anim_callback(planner, anim_callback)
    copy_sol && (sol = copy(sol))
    sol = SymbolicPlanners.refine!(sol, planner, domain, state, spec)
    return (anim, sol)
end

function add_anim_callback(planner::Planner, cb::AnimSolveCallback)
    planner = copy(planner)
    planner.callback = cb
    return planner
end

function add_anim_callback(planner::RTHS, cb::AnimSolveCallback)
    # Set top-level callback
    planner = copy(planner)
    planner.callback = cb
    # Set callback for internal forward-search planner
    planner.planner = copy(planner.planner)
    planner.planner.callback = cb
    return planner
end
