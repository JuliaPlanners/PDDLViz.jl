
"Return the coordinates of a graphic."
GeometryBasics.coordinates(g::BasicGraphic) =
    Point2{Float64}.(coordinates(g.shape))
GeometryBasics.coordinates(g::MultiGraphic) =
    reduce(vcat, (coordinates(c) for c in g.components))

"Return the centroid of a graphic."
centroid(g::BasicGraphic) = centroid(g.shape)
centroid(g::MultiGraphic) = centroid(boundingbox(g))
centroid(c::Circle) = c.center
centroid(r::Rect2{T}) where {T} =
    Point2{T}(r.origin + r.widths./2)
centroid(p::Polygon{2, T}) where {T} =
    Point2{T}(sum(coordinates(p)) ./ length(coordinates(p)))

"Return the bounding box of a graphic."
boundingbox(g::Graphic) = Rect(coordinates(g))

"Translate a graphic by `x` and `y` units."
function translate(g::BasicGraphic, x::Real, y::Real)
    return BasicGraphic(translate(g.shape, x, y), copy(g.attributes))
end

function translate(g::MultiGraphic, x::Real, y::Real)
    return MultiGraphic(map(a -> translate(a, x, y), g.components), copy(g.attributes))
end

function translate(rect::Rect2{T}, x::Real, y::Real) where {T}
    return Rect2{T}(rect.origin + Vec2{T}(x, y), rect.widths)
end

function translate(circle::Circle{T}, x::Real, y::Real) where {T}
    return Circle(circle.center + Vec2{T}(x, y), circle.r)
end

function translate(polygon::Polygon{2,T}, x::Real, y::Real) where {T}
    return Polygon([v + Vec2{T}(x, y) for v in coordinates(polygon)])
end

"Scale by a horizontal factor `x` and vertical factor `y` around a point `c`."
function scale(g::BasicGraphic, x::Real, y::Real=x, c=centroid(g))
    return BasicGraphic(scale(g.shape, x, y, c), copy(g.attributes))
end

function scale(g::MultiGraphic, x::Real, y::Real=x, c=centroid(g))
    return MultiGraphic(map(a -> scale(a, x, y, c), g.components), copy(g.attributes))
end

function scale(rect::Rect2{T}, x::Real, y::Real=x, c=centroid(r)) where {T}
    origin = Vec2{T}(c[1] - x * (c[1] - rect.origin[1]),
                     c[2] - y * (c[2] - rect.origin[2]))
    widths = Vec2{T}(x * rect.widths[1], y * rect.widths[2])
    return Rect2{T}(origin, widths)
end

function scale(circle::Circle{T}, x::Real, y::Real=x, c=centroid(circle)) where {T}
    if x != y
        polygon = Polygon(Point2{T}.(coordinates(circle)))
        return scale(polygon, x, y, c)
    end
    center = Point2{T}(c[1] - x * (c[1] - circle.center[1]),
                       c[2] - y * (c[2] - circle.center[2]))
    return Circle{T}(center, x * circle.r)
end

function scale(polygon::Polygon{2,T}, x::Real, y::Real=x, c=centroid(polygon)) where {T}
    vertices = [Point2{T}(c[1] - x * (c[1] - v[1]),
                          c[2] - y * (c[2] - v[2])) for v in coordinates(polygon)]
    return Polygon(vertices)
end

"Rotate a graphic by θ radians around a point `c`."
function rotate(g::BasicGraphic, θ::Real, c=centroid(g))
    return BasicGraphic(rotate(g.shape, θ, c), copy(g.attributes))
end

function rotate(g::MultiGraphic, θ::Real, c=centroid(g))
    return MultiGraphic(map(a -> rotate(a, θ, c), g.components), copy(g.attributes))
end

function rotate(rect::Rect2{T}, θ::Real, c=centroid(rect)) where {T}
    vertices = Point2{T}.(coordinates(rect))[[1, 2, 4, 3]]
    polygon = Polygon(vertices)
    return rotate(polygon, θ, c)
end

function rotate(circle::Circle{T}, θ::Real, c=centroid(circle)) where {T}
    if θ == 0 || c == circle.center
        return circle
    end
    center = Point2{T}(c[1] + (circle.center[1] - c[1]) * cos(θ)
                            - (circle.center[2] - c[2]) * sin(θ),
                       c[2] + (circle.center[1] - c[1]) * sin(θ)
                            + (circle.center[2] - c[2]) * cos(θ))
    return Circle{T}(center, circle.r)
end

function rotate(polygon::Polygon{2,T}, θ::Real, c=centroid(polygon)) where {T}
    vertices = [Point2{T}(c[1] + (v[1]-c[1]) * cos(θ) - (v[2]-c[2]) * sin(θ),
                          c[2] + (v[1]-c[1]) * sin(θ) + (v[2]-c[2]) * cos(θ))
                for v in coordinates(polygon)]
    return Polygon(vertices)
end
