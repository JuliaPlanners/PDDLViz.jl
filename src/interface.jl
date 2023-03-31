export Canvas, Renderer
export render_state, render_plan, render_trajectory
export render_state!, render_plan!, render_trajectory!

"""
    Canvas

A `Canvas` is a mutable container for renderable outputs produced by a
[`Renderer`](@ref), consisting of a reference to the figure and axis blocks
on which the output is rendered, the PDDL [`State`](@ref) that the output is
based on, and a dictionary of additional `Observable`s.
"""
mutable struct Canvas
    figure::Figure
    blocks::Vector{Block}
    state::Union{Nothing,Observable}
    observables::Dict{Symbol,Observable}
end

Canvas(figure::Figure) =
    Canvas(figure, Block[], nothing, Dict{Symbol,Observable}())
Canvas(figure::Figure, axis::Block) =
    Canvas(figure, Block[axis], nothing, Dict{Symbol,Observable}())
Canvas(figure::Figure, blocks::Vector) =
    Canvas(figure, blocks, nothing, Dict{Symbol,Observable}())
Canvas(figure::Figure, blocks::Vector, state::State) =
    Canvas(figure, blocks, Observable(state), Dict{Symbol,Observable}())
Canvas(figure::Figure, blocks::Vector, state::Observable{<:State}) =
    Canvas(figure, blocks, state, Dict{Symbol,Observable}())

Base.display(canvas::Canvas; kwargs...) = display(canvas.figure; kwargs...)

"""
    Renderer

A `Renderer` defines how a PDDL [`State`](@ref) for a specific [`Domain`](@ref)
should be rendered. A concrete sub-type of `Renderer` should be implemented
for a PDDL domain (or family of PDDL domains, e.g. 2D gridworlds) for users who
wish to visualize that domain.
"""
abstract type Renderer end

function (r::Renderer)(
    domain::Domain, state::MaybeObservable{<:State}
)
    return render_state(r, domain, state)
end

function (r::Renderer)(
    domain::Domain, state::MaybeObservable{<:State},
    actions::MaybeObservable{<:AbstractVector{<:Term}}
)
    return render_plan(r, domain, state, actions)
end

function (r::Renderer)(
    domain::Domain, trajectory::MaybeObservable{AbstractVector{<:State}}
)
    return render_trajectory(r, domain, trajectory)
end

function (r::Renderer)(
    canvas::Canvas, 
    domain::Domain, state::MaybeObservable{<:State}
)
    return render_state!(canvas, r, domain, state)
end

function (r::Renderer)(
    canvas::Canvas, 
    domain::Domain, state::MaybeObservable{<:State},
    actions::MaybeObservable{<:AbstractVector{<:Term}}
)
    return render_plan!(canvas, r, domain, state, actions)
end

function (r::Renderer)(
    canvas::Canvas, 
    domain::Domain, trajectory::MaybeObservable{<:AbstractVector{<:State}}
)
    return render_trajectory!(canvas, r, domain, trajectory)
end

"""
    render_state!(canvas, renderer, domain, state)

"""
    render_state!(canvas, renderer, domain, state; options...)


"""
    new_canvas(renderer::Renderer)
    new_canvas(renderer::Renderer, figure::Figure)
    new_canvas(renderer::Renderer, axis::Axis)
    new_canvas(renderer::Renderer, gridpos::GridPosition)

Creates a new [`Canvas`](@ref) to be used by `renderer`. An existing `figure`,
`axis`, or `gridpos` can be specified to use as the base for the new canvas.
"""
function new_canvas(renderer::Renderer)
    figure = Figure()
    axis = Axis(figure[1, 1])
    return Canvas(figure, axis)
end
new_canvas(renderer::Renderer, figure::Figure) =
    Canvas(figure, contents(figure.layout))
new_canvas(renderer::Renderer, axis::Axis) =
    Canvas(axis.parent, axis)
new_canvas(renderer::Renderer, gridpos::GridPosition) =
    Canvas(gridpos.layout.parent, contents(gridpos))

"""
    render_state(renderer, domain, state)

Uses `renderer` to render a `state` of a PDDL `domain`, constructing and
returning a new [`Canvas`](@ref).
"""
function render_state(
    renderer::Renderer, domain::Domain, state; options...
)
    render_state!(new_canvas(renderer), renderer, domain, state; options...)
end

"""
    render_state!(canvas, renderer, domain, state; options...)

Uses `renderer` to render a `state` of a PDDL `domain` to an existing `canvas`,
rendering over any existing content.
"""
function render_state!(
    canvas::Canvas, renderer::Renderer, domain::Domain, state;
    options...
)
    render_state!(canvas, renderer, domain, maybe_observe(state), options...)
end

function render_state!(
    canvas::Canvas, renderer::Renderer, domain::Domain, state::Observable;
    options...
)
    error("Not implemented.")
end


"""
    render_plan(renderer, domain, state, actions; options...)

Uses `renderer` to render a series of `actions` in a PDDL `domain` starting
from `state`, constructing and returning a new [`Canvas`](@ref).
"""
function render_plan(
    renderer::Renderer, domain::Domain, state, actions;
    options...
)
    render_plan!(new_canvas(renderer), renderer, domain, state, actions;
                 options...)
end

"""
    render_plan!(canvas, renderer, domain, state, actions)

Uses `renderer` to render a series of `actions` in a PDDL `domain` starting
from `state`. Renders to a `canvas` on top of any existing content.
"""
function render_plan!(
    canvas::Canvas, renderer::Renderer, domain::Domain,
    state, actions;
    options...
)
    render_plan!(canvas, renderer, domain, maybe_observe(state),
                 maybe_observe(actions); options...)
end

function render_plan!(
    canvas::Canvas, renderer::Renderer, domain::Domain,
    state::Observable, actions::Observable;
    options...
)
    trajectory = @lift PDDL.simulate(domain, $state, $actions)
    return render_trajectory!(canvas, renderer, domain, trajectory; options...)
end

"""
    render_trajectory(renderer::Renderer,
                      domain::Domain, trajectory::AbstractVector{<:State})

Uses `renderer` to render a `trajectory` of PDDL `domain` states, constructing
and returning a new [`Canvas`](@ref).
"""
function render_trajectory(
    renderer::Renderer, domain::Domain, trajectory;
    options...
)
    render_trajectory!(new_canvas(renderer), renderer, domain, trajectory;
                       options...)
end

"""
    render_trajectory!(canvas::Canvas, renderer::Renderer,
                       domain::Domain, trajectory::AbstractVector{<:State})

Uses `renderer` to render a `trajectory` of PDDL `domain` states. Renders to a
`canvas` on top of any existing content.
"""
function render_trajectory!(
    canvas::Canvas, renderer::Renderer, domain::Domain, trajectory;
    options...
)
    render_trajectory!(canvas, renderer, domain, maybe_observe(trajectory);
                       options...)
end

function render_trajectory!(
    canvas::Canvas, renderer::Renderer, domain::Domain, trajectory::Observable;
    options...
)
    error("Not implemented.")
end
