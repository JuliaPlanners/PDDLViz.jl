using Makie: to_color, ColorScheme
using ColorTypes: RGBA, RGB, Colorant

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

"Lighten a RGB(A) color by a given amount."
function lighten(color::RGBA, amount::Real)
    return RGBA(
        color.r + (1 - color.r) * amount,
        color.g + (1 - color.g) * amount,
        color.b + (1 - color.b) * amount,
        color.alpha
    )
end

"Darken a RGB(A) color by a given amount."
function darken(color::RGBA, amount::Real)
    return RGBA(
        color.r * (1 - amount),
        color.g * (1 - amount),
        color.b * (1 - amount),
        color.alpha
    )
end
