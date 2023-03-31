module RenderPDDL

using Base: @kwdef

using PDDL
using GLMakie, Makie
using Makie: Block

using DocStringExtensions

const MaybeObservable{T} = Union{Observable{T}, T}
maybe_observe(x::Observable) = x
maybe_observe(x) = Observable(x)

include("interface.jl")
include("graphics/graphics.jl")
include("gridworld.jl")

end
