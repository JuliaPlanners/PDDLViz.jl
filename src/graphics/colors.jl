using Makie: to_color, ColorScheme
using ColorTypes: RGBA, RGB, Colorant

"Lighten a RGB(A) color by a given amount."
function lighten(color::RGBA, amount::Real)
    return RGBA(
        color.r + (1 - color.r) * amount,
        color.g + (1 - color.g) * amount,
        color.b + (1 - color.b) * amount,
        color.alpha
    )
end

function lighten(color::RGB, amount::Real)
    return RGB(
        color.r + (1 - color.r) * amount,
        color.g + (1 - color.g) * amount,
        color.b + (1 - color.b) * amount
    )
end

lighten(color, amount::Real) = lighten(to_color(color), amount)
lighten(color::Observable, amount::Real) = lift(x -> lighten(x, amount), color)

"Darken a RGB(A) color by a given amount."
function darken(color::RGBA, amount::Real)
    return RGBA(
        color.r * (1 - amount),
        color.g * (1 - amount),
        color.b * (1 - amount),
        color.alpha
    )
end

function darken(color::RGB, amount::Real)
    return RGB(
        color.r * (1 - amount),
        color.g * (1 - amount),
        color.b * (1 - amount)
    )
end

darken(color, amount::Real) = darken(to_color(color), amount)
darken(color::Observable, amount::Real) = lift(x -> darken(x, amount), color)

"Set the alpha value of a RGB(A) color."
set_alpha(color::RGBA, alpha::Real) =
    RGBA(color.r, color.g, color.b, alpha)
set_alpha(color::RGB, alpha::Real) =
    RGBA(color.r, color.g, color.b, alpha)
set_alpha(color, alpha::Real) =
    set_alpha(to_color(color), alpha)
set_alpha(color::Observable, alpha::Real) =
    lift(x -> set_alpha(x, alpha), color)

"Convert a color or observable to a `Observable{RGBA}`."
to_color_obs(obs::Observable) =
    obs[] isa RGBA ? obs : lift(x -> to_color(x), obs)
to_color_obs(color) =
    Observable(to_color(color))

"A dictionary of `ColorScheme`s provided by PDDLViz."
const colorschemes = Dict{Symbol, ColorScheme}()

colorschemes[:vibrant] = ColorScheme([
    colorant"#D41159",
    colorant"#FFC20A", 
    colorant"#1A85FF",
    colorant"#007D68",
    colorant"#785EF0",
    colorant"#D55E00",
    colorant"#56B4E9",
    colorant"#CC79A7"
])

colorschemes[:vibrantlight] =
    ColorScheme([lighten(c, 0.5) for c in colorschemes[:vibrant]])

colorschemes[:vibrantdark] =
    ColorScheme([darken(c, 0.5) for c in colorschemes[:vibrant]])
