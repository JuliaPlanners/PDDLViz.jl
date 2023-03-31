using GeometryBasics: GeometryBasics, Circle, Rect, Polygon, coordinates

abstract type Graphic end

"""
    BasicGraphic(shape; attributes...)

Basic graphic type, containing a primitive shape and a dictionary of attributes.
"""
struct BasicGraphic{T} <: Graphic
    shape::T
    attributes::Dict{Symbol, Any}
end

BasicGraphic(shape; attributes...) =
    BasicGraphic(shape, Dict{Symbol,Any}(attributes...))

"""
    MultiGraphic(graphics; attributes...)

Composite graphic type, containing a tuple of graphics in depth-order and a
dictionary of attributes.
"""
struct MultiGraphic{Gs <: Tuple} <: Graphic
    components::Gs
    attributes::Dict{Symbol, Any}
end

MultiGraphic(graphics::Tuple; attributes...) =
    MultiGraphic(graphics, Dict{Symbol,Any}(attributes...))
MultiGraphic(graphics::AbstractVector; attributes...) =
    MultiGraphic(Tuple(graphics), Dict{Symbol,Any}(attributes...))
MultiGraphic(graphics::Graphic...; attributes...) =
    MultiGraphic(graphics, Dict{Symbol,Any}(attributes...))

include("recipes.jl")
include("colors.jl")
include("geometry.jl")
include("shapes.jl")
include("prefabs.jl")
