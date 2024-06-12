export GemGraphic, LockedDoorGraphic, KeyGraphic
export BoxGraphic, QuestionBoxGraphic
export RobotGraphic, HumanGraphic
export CityGraphic
export CarrotGraphic, OnionGraphic

"""
    GemGraphic(x=0.0, y=0.0, size=1.0, sides=6, aspect=0.75;
               color=:royalblue, strokewidth=1.0, kwargs...)

Gem graphic, consisting of a N-gon and a smaller N-gon inside it.
"""
function GemGraphic(
    x::Real=0.0, y::Real=0.0, size::Real=1.0, sides::Int=6, aspect::Real=0.75;
    color=:royalblue, strokewidth=1.0, kwargs...
)
    color = color isa Observable ? to_color_obs(color) : to_color(color)
    outer = NgonShape(x, y, size, sides; color=color, strokewidth=strokewidth)
    outer = scale(outer, aspect*0.3, 0.3)
    color = lighten(color, 0.5)
    inner = NgonShape(x, y, size, sides; color=color)
    inner = scale(inner, aspect*0.18, 0.18)
    return MultiGraphic(outer, inner; kwargs...)
end

"""
    LockedDoorGraphic(x=0.0, y=0.0, size=1.0;
                      color=:gray, strokewidth=1.0, kwargs...)

Locked door graphic, consisting of square with a keyhole in it.
"""
function LockedDoorGraphic(
    x::Real=0.0, y::Real=0.0, size::Real=1.0;
    color=:gray, strokewidth=1.0, kwargs...
)
    color = color isa Observable ? to_color_obs(color) : to_color(color)
    bg = SquareShape(x, y, size; color=color, strokewidth=strokewidth)
    color = lighten(color, 0.1)
    fg = SquareShape(x, y, 0.85*size; color=color, strokewidth=strokewidth)
    hole1 = NgonShape(x, y+0.1*size, 0.10*size, 16; color=:black)
    hole2 = TriangleShape(x, y-0.1*size, size; color=:black)
    hole2 = scale(hole2, 0.125, -0.25)
    return MultiGraphic(bg, fg, hole1, hole2; kwargs...)
end

"""
    KeyGraphic(x=0.0, y=0.0, size=1.0;
               color=:goldenrod1, shadow_color=:black, kwargs...)

Key graphic, consisting of a key with a handle and two teeth.
"""
function KeyGraphic(
    x::Real=0.0, y::Real=0.0, size::Real=1.0;
    color=:goldenrod1, shadow_color=:black, kwargs...
)
    color = color isa Observable ? to_color_obs(color) : to_color(color)
    shadow_color = shadow_color isa Observable ?
        to_color_obs(shadow_color) : to_color(shadow_color)
    handle = NgonShape(-0.35, 0.0, 0.4, 8)
    blade = RectShape(0.375, 0.0, 0.75, 0.2)
    tooth1 = RectShape(0.4, -0.2, 0.1, 0.2)
    tooth2 = RectShape(0.6, -0.2, 0.1, 0.2)
    key = MultiGraphic(handle, blade, tooth1, tooth2; color=color)
    shadow = translate(key, 0.025, -0.025)
    shadow.attributes[:color] = shadow_color
    graphic = MultiGraphic(shadow, key; kwargs...)
    return scale(translate(graphic, x, y), 0.5*size)
end

"""
    BoxGraphic(x=0.0, y=0.0, size=1.0;
               color=:burlywood3, is_open=false, kwargs...)

Cardboard box graphic, consisting of a box with a lid.
"""
function BoxGraphic(
    x::Real=0.0, y::Real=0.0, size::Real=1.0;
    color=:burlywood3, is_open::Bool=false, kwargs...
)
    size = size * 0.9
    lid_color = lighten(color, 0.3)
    if is_open
        lid = RectShape(x-0.37*size, y+0.02*size, 0.825*size, 0.2*size;
                        color=lid_color)
        lid = rotate(lid, 11*π/24)
    else
        lid = RectShape(x, y+0.3*size, 0.825*size, 0.2*size; color=lid_color)
        lid = rotate(lid, 0.0)
    end
    box = RectShape(x, y-0.05*size, 0.75*size, 0.65*size; color=color)
    return MultiGraphic(box, lid; kwargs...)
end

"""
    QuestionBoxGraphic(x=0.0, y=0.0, size=1.0;
                       color=:burlywood3, text_color=:white,
                       is_open=false, kwargs...)

Question box graphic, consisting of a box with a lid and question mark.
"""
function QuestionBoxGraphic(
    x::Real=0.0, y::Real=0.0, size::Real=1.0;
    color=:burlywood3, text_color=:white, is_open::Bool=false, kwargs...
)
    size = size * 0.9
    lid_color = lighten(color, 0.3)
    if is_open
        lid = RectShape(x-0.37*size, y+0.02*size, 0.825*size, 0.2*size;
                        color=lid_color)
        lid = rotate(lid, 11*π/24)
    else
        lid = RectShape(x, y+0.3*size, 0.825*size, 0.2*size; color=lid_color)
        lid = rotate(lid, 0.0)
    end
    box = RectShape(x, y-0.05*size, 0.75*size, 0.65*size; color=color)
    question = TextGraphic("?", x, y-0.075*size; color=text_color,
                           fontsize=0.5*size, font=:bold)
    return MultiGraphic(box, lid, question; kwargs...)
end

"""
    RobotGraphic(x=0.0, y=0.0, size=1.0;
                 color=:slategray, kwargs...)

Robot prefab character graphic, consisting of a semi-circular head with an 
antenna, two arms, a body and a wheel.
"""
function RobotGraphic(
    x::Real=0.0, y::Real=0.0, size::Real=1.0;
    color=:slategray, kwargs...
)
    color = color isa Observable ? to_color_obs(color) : to_color(color)
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

"""
    HumanGraphic(x=0.0, y=0.0, size=1.0;
                 color=:black, kwargs...)

Human character graphic, consisting of a circular head, and a trapezoidal torso,
two-segment arms, and legs.
"""
function HumanGraphic(
    x::Real=0.0, y::Real=0.0, size::Real=1.0;
    color=:black, kwargs...
)
    color = color isa Observable ? to_color_obs(color) : to_color(color)
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

"""
    CityGraphic(x=0.0, y=0.0, size=1.0;
                color=:grey, kwargs...)

City graphic, made of three rectangles with slightly different shading.
"""
function CityGraphic(
    x::Real=0.0, y::Real=0.0, size::Real=1.0;
    color=:grey, kwargs...
)
    color = color isa Observable ? to_color_obs(color) : to_color(color)
    block1 = RectShape(x+0.00, y, 0.30, 0.75, color=color)
    block2 = RectShape(x-0.15, y-0.075, 0.30, 0.60, color=darken(color, 0.2))
    block3 = RectShape(x+0.15, y-0.1875, 0.30, 0.375, color=darken(color, 0.4))
    city = MultiGraphic(block1, block2, block3; kwargs...)
    return scale(city, size)
end

function CarrotGraphic(
    x::Real=0.0, y::Real=0.0, size::Real=1.0;
    body_color=:orange, leaves_color=:green, shadow_color=:black, kwargs...
)
    body_color = body_color isa Observable ? to_color_obs(body_color) : to_color(body_color)
    leaves_color = leaves_color isa Observable ? to_color_obs(leaves_color) : to_color(leaves_color)
    shadow_color = shadow_color isa Observable ? to_color_obs(shadow_color) : to_color(shadow_color)
    
    body = NgonShape(0.0, 0.0, 0.3, 3)
    leaves1 = NgonShape(-0.1, 0.35, 0.1, 3)
    leaves2 = NgonShape(0.0, 0.35, 0.1, 3)
    leaves3 = NgonShape(0.1, 0.35, 0.1, 3)
    
    carrot_body = MultiGraphic(body; color=body_color)
    carrot_leaves = MultiGraphic(leaves1, leaves2, leaves3; color=leaves_color)
    
    carrot = MultiGraphic(carrot_body, carrot_leaves)
    shadow = translate(carrot, 0.025, -0.025)
    shadow.attributes[:color] = shadow_color
    
    graphic = MultiGraphic(shadow, carrot; kwargs...)
    return scale(translate(graphic, x, y), 0.5 * size)
end

function OnionGraphic(
    x::Real=0.0, y::Real=0.0, size::Real=1.0;
    body_color=:goldenrod, leaves_color=:green, shadow_color=:black, kwargs...
)
    body_color = body_color isa Observable ? to_color_obs(body_color) : to_color(body_color)
    leaves_color = leaves_color isa Observable ? to_color_obs(leaves_color) : to_color(leaves_color)
    shadow_color = shadow_color isa Observable ? to_color_obs(shadow_color) : to_color(shadow_color)
    
    # Onion body as a circle
    body = CircleShape(0.0, 0.0, 0.3)
    
    # Onion leaves as small triangles at the bottom
    leaves1 = NgonShape(-0.1, -0.35, 0.1, 3)
    leaves2 = NgonShape(0.0, -0.35, 0.1, 3)
    leaves3 = NgonShape(0.1, -0.35, 0.1, 3)
    
    onion_body = MultiGraphic(body; color=body_color)
    onion_leaves = MultiGraphic(leaves1, leaves2, leaves3; color=leaves_color)
    
    onion = MultiGraphic(onion_body, onion_leaves)
    shadow = translate(onion, 0.025, -0.025)
    shadow.attributes[:color] = shadow_color
    
    graphic = MultiGraphic(shadow, onion; kwargs...)
    return scale(translate(graphic, x, y), 0.5 * size)
end

