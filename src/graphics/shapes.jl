## Basic shapes and primitives ##

"Construct a circle centered at `x` and `y` with radius `r`."
CircleShape(x::Real, y::Real, r::Real; attributes...) =
    BasicGraphic(Circle(Point2{Float64}(x, y), r); attributes...)

"Construct a square centered at `x` and `y` with side length `l`."
SquareShape(x::Real, y::Real, l::Real; attributes...) =
    BasicGraphic(Rect(x-l/2, y-l/2, l, l); attributes...)

"Construct a rectangle centered at `x` and `y` with width `w` and height `h`."
RectShape(x::Real, y::Real, w::Real, h::Real; attributes...) =
    BasicGraphic(Rect(x-w/2, y-h/2, w, h); attributes...)

"Construct a `n`-sided regular polygon centered at `x` and `y` with radius `1`."
function NgonShape(x::Real, y::Real, r::Real, n::Int; attributes...)
    points = collect(coordinates(Circle(Point2{Float64}(x, y), r), n+1))
    resize!(points, n)
    BasicGraphic(Polygon(points); attributes...)
end

"Construct a triangle centered at `x` and `y` with radius `r`."
TriangleShape(x::Real, y::Real, r::Real; attributes...) =
    NgonShape(x, y, r, 3; attributes...)

"Construct a pentagon centered at `x` and `y` with radius `r`."
PentagonShape(x::Real, y::Real, r::Real; attributes...) =
    NgonShape(x, y, r, 5; attributes...)

"Construct a hexagon centered at `x` and `y` with radius `r`."
HexagonShape(x::Real, y::Real, r::Real; attributes...) =
    NgonShape(x, y, r, 6; attributes...)

"Construct a heptagon centered at `x` and `y` with radius `r`."
HeptagonShape(x::Real, y::Real, r::Real; attributes...) =
    NgonShape(x, y, r, 7; attributes...)

"Construct an octagon centered at `x` and `y` with radius `r`."
OctagonShape(x::Real, y::Real, r::Real; attributes...) =
    NgonShape(x, y, r, 8; attributes...)

"Construct a polygon from a list of vertices."
PolygonShape(vertices; attributes) =
    BasicGraphic(Polygon(Point2{Float64}.(vertices)); attributes...)

"""
Construct a trapezoid at `x` and `y` with top and bottom width `a`, bottom width
`b`, and height `h`. The top can be shifted by an `offset` (zero by default).
"""
function TrapezoidShape(
    x::Real, y::Real, a::Real, b::Real, h::Real, offset::Real=0.0;
    attributes...
)
    vertices = [
        Point2(x-a/2+offset, y+h/2), Point2(x+a/2+offset, y+h/2),
        Point2(x+b/2, y-h/2), Point2(x-b/2, y-h/2)
    ]
    BasicGraphic(Polygon(vertices); attributes...)
end