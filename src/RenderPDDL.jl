module RenderPDDL

using Base: @kwdef

using PDDL, SymbolicPlanners
using Makie, GLMakie
using FileIO

using DocStringExtensions

const MaybeObservable{T} = Union{Observable{T}, T}
maybe_observe(x::Observable) = x
maybe_observe(x) = Observable(x)

include("graphics/graphics.jl")
include("interface.jl")
include("render.jl")
include("animate.jl")
include("control.jl")
include("renderers/renderers.jl")

end
