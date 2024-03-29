module PDDLViz

using Base: @kwdef

using PDDL, SymbolicPlanners
using Makie, GraphMakie
using Graphs, NetworkLayout
using FileIO, Base64
using OrderedCollections
using DocStringExtensions
using Printf

const MaybeObservable{T} = Union{Observable{T}, T}
maybe_observe(x::Observable) = x
maybe_observe(x) = Observable(x)

include("graphics/graphics.jl")
include("interface.jl")
include("render.jl")
include("animate.jl")
include("storyboard.jl")
include("control.jl")
include("renderers/renderers.jl")

end
