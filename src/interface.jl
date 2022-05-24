"""
    Renderer

A `Renderer` defines how a PDDL [`State`](@ref) for a specific [`Domain`](@ref)
should be rendered. A concrete sub-type of `Renderer` should be implemented
for a PDDL domain (or family of PDDL domains, e.g. 2D gridworlds) for users who
wish to visualize that domain.
"""
abstract type Renderer end

"Returns the current [`Canvas`](@ref) used by `renderer`."
current_canvas(renderer::Renderer) = error("Not implemented.")

"Returns a new [`Canvas`](@ref) to be used by `renderer`."
new_canvas(renderer::Renderer) = error("Not implemented.")

"""
    Canvas

A `Canvas` is a mutable container for renderable outputs produced by a
[`Renderer`](@ref), typically consisting of a reference to the actual front-end
object (e.g. a Plots.jl `Plot` or Makie.jl `Figure`), the associated PDDL
[`Domain`](@ref) and [`State`](@ref), and any other stateful information.
"""
abstract type Canvas end

"Returns the PDDL [`Domain`](@ref) associated with the `canvas`."
get_domain(canvas::Canvas) = error("Not implemented.")

"Returns the PDDL [`State`](@ref) associated with the `canvas`."
get_state(canvas::Canvas) = error("Not implemented.")

"""
    GenericCanvas{T}

A generic `Canvas` containing an `output` object of type `T`
(e.g. a Plots.jl `Plot` or Makie.jl `Figure`), the `domain` and `state` being
rendered, and dictionary of extra properties (`extras`).
"""
mutable struct GenericCanvas{T} <: Canvas
    output::T
    domain::Union{Domain,Nothing}
    state::Union{State,Nothing}
    extras::Dict
end

GenericCanvas(output) = GenericCanvas(output, nothing, nothing, Dict())

get_domain(canvas::GenericCanvas) = canvas.domain

get_state(canvas::GenericCanvas) = canvas.state

Base.showable(m::MIME"text/plain", canvas::GenericCanvas) = true

Base.showable(m::MIME, canvas::GenericCanvas) = showable(m, canvas.output)

Base.show(io::IO, m::MIME"text/plain", canvas::GenericCanvas; kwargs...) =
    show(io, canvas.output; kwargs...)

Base.show(io::IO, m::MIME, canvas::GenericCanvas; kwargs...) =
    show(io, m, canvas.output; kwargs...)

"""
    render(renderer::Renderer, domain::Domain, state::State, extras...)

Uses `renderer` to render a `state` of a PDDL `domain`, constructing and
returning a new [`Canvas`](@ref).  Optionally specify extra arguments
(`extras`) such as goal specifications or planner solutions.
"""
function render(renderer::Renderer, domain::Domain, state::State, extras...)
    render!(new_canvas(renderer), renderer, domain, state, extras...)
end

"""
    render!([canvas::Canvas], renderer::Renderer,
            domain::Domain, state::State, extras...)

Uses `renderer` to render a `state` of a PDDL `domain` to a `canvas`.
If `canvas` is not specified, render to the last canvas used by `renderer`,
creating a new `canvas` if necessary. Optionally specify extra arguments
(`extras`) such as goal specifications or planner solutions.
"""
function render!(canvas::Canvas, renderer::Renderer,
                 domain::Domain, state::State, extras...)
    error("Not implemented.")
end

function render!(renderer::Renderer, domain::Domain, state::State, extras...)
    render!(current_canvas(renderer), domain, state, extras...)
end

"Renders an `object` in the PDDL state associated with a `canvas`."
function render_object!(canvas::Canvas, renderer::Renderer,
                        domain::Domain, state::State, object::Const)
    error("Not implemented.")
end

render_object!(canvas::Canvas, renderer::Renderer, object::Const) =
    render_object!(canvas, renderer, get_domain(canvas), get_state(canvas), object)

"Animates the transition from `state1` to `state2`."
function animate!(
    canvas::Canvas, renderer::Renderer,
    domain::Domain, state1::State, state2::State, action=nothing;
    n_steps=nothing, step_dur=nothing, record=false
)
    error("Not implemented.")
end

"Animates a sequence of `states` and (optionally) intervening `actions`."
function animate!(
    canvas::Canvas, renderer::Renderer,
    domain::Domain, states::AbstractVector{<:State}, actions=nothing;
    n_steps=nothing, step_dur=nothing, record=false
)
    error("Not implemented.")
end
