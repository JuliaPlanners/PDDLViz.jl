module RenderPDDL

using Base: @kwdef

using PDDL
using FileIO
using GLMakie, Makie

using DocStringExtensions

const MaybeObservable{T} = Union{Observable{T}, T}
maybe_observe(x::Observable) = x
maybe_observe(x) = Observable(x)

include("graphics/graphics.jl")
include("interface.jl")
include("render.jl")
include("animate.jl")
include("renderers/renderers.jl")

end
