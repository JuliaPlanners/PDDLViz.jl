export Canvas, Renderer
export new_canvas, save

import Makie: Block, AbstractPlot
import Makie.GridLayoutBase: GridLayoutBase, gridcontent

"""
    Canvas

A `Canvas` is a mutable container for renderable outputs produced by a
[`Renderer`](@ref), consisting of a reference to the figure and grid layout
on which the output is rendered, the PDDL [`State`](@ref) that the output is
based on, and a dictionary of additional `Observable`s.
"""
mutable struct Canvas
    figure::Figure
    blocks::Vector{Block}
    layout::GridLayout
    state::Union{Nothing,Observable}
    observables::Dict{Symbol,Observable}
    plots::Dict{Symbol,AbstractPlot}
end

function Canvas(figure::Figure, blocks::Vector{Block}, layout::GridLayout)
    return Canvas(figure, blocks, layout, nothing,
                  Dict{Symbol,Observable}(), Dict{Symbol,AbstractPlot}())
end

Canvas(figure::Figure) =
    Canvas(figure, Block[], figure.layout)
Canvas(figure::Figure, axis::Block) =
    Canvas(figure, Block[axis], gridcontent(axis).parent)
Canvas(figure::Figure, layout::GridLayout) =
    Canvas(figure, Vector{Block}(contents(layout)), layout)
Canvas(figure::Figure, gp::GridPosition) =
    Canvas(figure, Vector{Block}(contents(gp)), gp.layout)

Canvas(axis::Block) =
    Canvas(axis.parent, axis)
Canvas(layout::GridLayout) =
    Canvas(GridLayoutBase.top_parent(layout), layout)
Canvas(gridpos::GridPosition) =
    Canvas(Makie.get_top_parent(gridpos), gridpos)

Base.showable(m::MIME"text/plain", canvas::Canvas) = true
Base.showable(m::MIME, canvas::Canvas) = showable(m, canvas.figure)
Base.show(io::IO, m::MIME"text/plain", canvas::Canvas) = show(io, canvas)
Base.show(io::IO, m::MIME, canvas::Canvas) = show(io, m, canvas.figure)

Base.display(canvas::Canvas; kwargs...) = display(canvas.figure; kwargs...)

function is_displayed(canvas::Canvas)
    scene = canvas.figure.scene
    screen = Makie.getscreen(scene)
    return screen in scene.current_screens
end

FileIO.save(path::AbstractString, canvas::Canvas; kwargs...) =
    save(path, canvas.figure; kwargs...)

"""
    Renderer

A `Renderer` defines how a PDDL [`State`](@ref) for a specific [`Domain`](@ref)
should be rendered. A concrete sub-type of `Renderer` should be implemented
for a PDDL domain (or family of PDDL domains, e.g. 2D gridworlds) for users who
wish to visualize that domain.

    (r::Renderer)(domain::Domain, args...; options...)
    (r::Renderer)(canvas::Canvas, domain::Domain, args...; options...)

Once a `Renderer` has been constructed, it can be used to render PDDL states and
other entities by calling it with the appropriate arguments.
"""
abstract type Renderer end

function (r::Renderer)(
    domain::Domain, state::MaybeObservable{<:State};
    options...
)
    return render_state(r, domain, state; options...)
end

function (r::Renderer)(
    domain::Domain, state::MaybeObservable{<:State},
    actions::MaybeObservable{<:AbstractVector{<:Term}};
    options...
)
    return render_plan(r, domain, state, actions; options)
end

function (r::Renderer)(
    domain::Domain, trajectory::MaybeObservable{AbstractVector{<:State}};
    options...
)
    return render_trajectory(r, domain, trajectory; options...)
end

function (r::Renderer)(
    domain::Domain, state::MaybeObservable{<:State},
    sol::MaybeObservable{<:Solution};
    options...
)
    return render_sol(r, domain, state, sol; options...)
end

function (r::Renderer)(
    canvas::Canvas, 
    domain::Domain, state::MaybeObservable{<:State};
    options...
)
    return render_state!(canvas, r, domain, state; options...)
end

function (r::Renderer)(
    canvas::Canvas, 
    domain::Domain, state::MaybeObservable{<:State},
    actions::MaybeObservable{<:AbstractVector{<:Term}};
    options...
)
    return render_plan!(canvas, r, domain, state, actions; options...)
end

function (r::Renderer)(
    canvas::Canvas, 
    domain::Domain, trajectory::MaybeObservable{<:AbstractVector{<:State}};
    options...
)
    return render_trajectory!(canvas, r, domain, trajectory; options...)
end

function (r::Renderer)(
    canvas::Canvas, 
    domain::Domain, state::MaybeObservable{<:State},
    sol::MaybeObservable{<:Solution};
    options...
)
    return render_sol!(canvas, r, domain, state, sol; options...)
end

"""
    new_canvas(renderer::Renderer)
    new_canvas(renderer::Renderer, figure::Figure)
    new_canvas(renderer::Renderer, axis::Axis)
    new_canvas(renderer::Renderer, gridpos::GridPosition)

Creates a new [`Canvas`](@ref) to be used by `renderer`. An existing `figure`,
`axis`, or `gridpos` can be specified to use as the base for the new canvas.
"""
function new_canvas(renderer::Renderer)
    figure = Figure(resolution=(800, 800))
    axis = Axis(figure[1, 1])
    return Canvas(figure, axis)
end
new_canvas(renderer::Renderer, figure::Figure) =
    Canvas(figure)
new_canvas(renderer::Renderer, axis::Axis) =
    Canvas(axis)
new_canvas(renderer::Renderer, gridpos::GridPosition) =
    Canvas(gridpos)

default_state_options(R::Type{<:Renderer}) = Dict{Symbol,Any}()

default_plan_options(R::Type{<:Renderer}) = Dict{Symbol,Any}()

default_trajectory_options(R::Type{<:Renderer}) = Dict{Symbol,Any}()

default_anim_options(R::Type{<:Renderer}) = Dict{Symbol,Any}()
