using GeometryBasics: GeometryBasics, Circle, Rect, Polygon, coordinates

export BasicGraphic, MarkerGraphic, TextGraphic, MultiGraphic

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
    MarkerGraphic(marker, x, y, [w=1.0, h=w]; attributes...)

A marker graphic with a given position and size, rendered using `scatter`
with the corresponding marker type.
"""
struct MarkerGraphic{T} <: Graphic
    marker::T
    x::Float64
    y::Float64
    w::Float64
    h::Float64
    attributes::Dict{Symbol, Any}
end

function MarkerGraphic(
    marker::T, x::Real=0.0, y::Real=0.0, w::Real=1.0, h::Real=w;
    attributes...
) where {T}
    return MarkerGraphic{T}(marker, x, y, w, h, Dict{Symbol,Any}(attributes...))
end

"""
    TextGraphic(str, x, y, [fontsize]; attributes...)

A text graphic with a given position and [fontsize], rendered using the `text`
plotting command.
"""
struct TextGraphic <: Graphic
    str::String
    x::Float64
    y::Float64
    fontsize::Vec2f
    attributes::Dict{Symbol, Any}
end

function TextGraphic(
    str::AbstractString, x::Real=0.0, y::Real=0.0, fontsize=1/length(str);
    attributes...
)
    if fontsize isa Real
        fontsize = Vec2f(fontsize, fontsize)
    elseif fontsize isa Tuple
        fontsize = Vec2f(fontsize...)
    end
    return TextGraphic(str, x, y, fontsize, Dict{Symbol,Any}(attributes...))
end

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
