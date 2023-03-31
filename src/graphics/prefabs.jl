export GemGraphic, LockedDoorGraphic, KeyGraphic, RobotGraphic, HumanGraphic

"Gem prefab graphic, consisting of a N-gon and a smaller N-gon inside it."
function GemGraphic(
    x::Real=0.0, y::Real=0.0, size::Real=1.0, sides::Int=6;
    color=:royalblue, strokewidth=1.0, kwargs...
)
    color = to_color(color)
    outer = NgonShape(x, y, size, sides; color=color,
                         strokewidth=strokewidth, kwargs...)
    outer = scale(outer, 0.225, 0.3)
    color = lighten(color, 0.5) 
    inner = NgonShape(x, y, size, sides; color=color, kwargs...)
    inner = scale(inner, 0.135, 0.18)
    return MultiGraphic(outer, inner)
end

"Locked door prefab graphic, consisting of square with a keyhole in it."
function LockedDoorGraphic(
    x::Real=0.0, y::Real=0.0, size::Real=1.0;
    color=:gray, strokewidth=1.0, kwargs...
)
    color = to_color(color)
    bg = SquareShape(x, y, size; color=color,
                     strokewidth=strokewidth, kwargs...)
    color = lighten(color, 0.1)
    fg = SquareShape(x, y, 0.85*size; color=color, 
                     strokewidth=strokewidth, kwargs...)
    hole1 = NgonShape(x, y+0.1*size, 0.10*size, 16; color=:black, kwargs...)
    hole2 = TriangleShape(x, y-0.1*size, size; color=:black, kwargs...)
    hole2 = scale(hole2, 0.125, -0.25)
    return MultiGraphic(bg, fg, hole1, hole2)
end

"Key prefab graphic, consisting of a key with a handle and two teeth."
function KeyGraphic(
    x::Real=0.0, y::Real=0.0, size::Real=1.0;
    color=:goldenrod1, kwargs...
)
    color = to_color(color)
    handle = NgonShape(-0.35, 0.0, 0.4, 8)
    blade = RectShape(0.375, 0.0, 0.75, 0.2)
    tooth1 = RectShape(0.4, -0.2, 0.1, 0.2)
    tooth2 = RectShape(0.6, -0.2, 0.1, 0.2)
    key = MultiGraphic(handle, blade, tooth1, tooth2; color=color, kwargs...)
    shadow = translate(key, 0.025, -0.025)
    shadow.attributes[:color] = :black
    graphic = MultiGraphic(shadow, key)
    return scale(translate(graphic, x, y), 0.5*size)
end

"Robot prefab graphic"
function RobotGraphic(
    x::Real=0.0, y::Real=0.0, size::Real=1.0;
    color=:slategray, kwargs...
)
    color = to_color(color)
    light_color = lighten(color, 0.4)
    dark_color = darken(color, 0.3)
    tip = NgonShape(x, y+0.325*size, 0.025*size, 16)
    antenna = RectShape(x, y+0.31*size, 0.05*size, 0.03*size)
    head = NgonShape(x, y+0.05*size, 0.25*size, 32)
    face = NgonShape(x, y+0.05*size, 0.2*size, 32; color=light_color)
    eye1 = SquareShape(x-0.1*size, y+0.1*size, 0.05*size)
    eye2 = SquareShape(x+0.1*size, y+0.1*size, 0.05*size)
    wheel = NgonShape(x, y-0.325*size, 0.10*size, 32; color=dark_color)
    body = RectShape(x, y-0.15*size, 0.5*size, 0.4*size;)
    shoulder1 = RectShape(x+0.28125*size, y, 0.0625*size, 0.05*size)
    shoulder2 = RectShape(x-0.28125*size, y, 0.0625*size, 0.05*size)
    arm1 = RectShape(x+0.2875*size, y-0.125*size, 0.05*size, 0.2*size)
    arm2 = RectShape(x-0.2875*size, y-0.125*size, 0.05*size, 0.2*size)
    return MultiGraphic(tip, antenna, head, face, eye1, eye2, 
                        wheel, body, shoulder1, shoulder2,
                        arm1, arm2; color=color, kwargs...)
end

"Human prefab graphic, made of a oval head and triangle body."
function HumanGraphic(
    x::Real=0.0, y::Real=0.0, size::Real=1.0;
    color=:black, kwargs...
)
    color = to_color(color)
    head = NgonShape(x, y+0.205*size, 0.15*size, 32)
    eye1 = NgonShape(x-0.1*size, y+0.22*size, 0.025*size, 16; color=:white)
    eye2 = NgonShape(x+0.1*size, y+0.22*size, 0.025*size, 16; color=:white)
    body = TrapezoidShape(x, y-0.075*size, 0.15*size, 0.3*size, 0.25*size)
    u_arm = TriangleShape(x, y-0.03*size, 0.1*size)
    u_arm1 = rotate(scale(translate(u_arm, -0.14*size, 0.0), 0.5, 1), π-1.1*π/6)
    u_arm2 = rotate(scale(translate(u_arm, 0.14*size, 0.0), 0.5, 1), π+1.1*π/6)
    l_arm = TrapezoidShape(x, y, size/12, 0.02*size, 0.12*size)
    l_arm1 = rotate(translate(l_arm, -0.202*size, -0.132*size), -1.1*π/6)
    l_arm2 = rotate(translate(l_arm, +0.202*size, -0.132*size), 1.1*π/6)
    leg = TrapezoidShape(x, y, size/12, 0.02*size, 0.12*size)
    leg1 = translate(leg, -0.102*size, -0.268*size)
    leg2 = translate(leg, 0.102*size, -0.268*size)
    human = MultiGraphic(
        body, head, eye1, eye2, u_arm1, u_arm2,
        l_arm1, l_arm2, leg1, leg2; color=color, kwargs...
    )
    return scale(human, 1.2, 1.2)
end
