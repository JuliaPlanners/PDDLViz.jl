## Makie plotting recipes for graphics ##

@recipe(GraphicPlot, graphic) do scene
    Makie.Attributes(
        cycle=[:color],
        colormap=colorschemes[:vibrant]
    )
end

function Makie.plot!(plt::GraphicPlot{<:Tuple{BasicGraphic}})
    graphic = plt[:graphic]
    shape = @lift $graphic.shape
    attributes = Dict(plt.attributes)
    local_attributes = Dict{Symbol, Any}(
        k => graphic[].attributes[k] isa Observable ?
            graphic[].attributes[k] : @lift($graphic.attributes[k])
        for k in keys(graphic[].attributes)
    )
    attributes = merge!(attributes, local_attributes)
    if !haskey(attributes, :shading)
        attributes[:shading] = isdefined(Makie.MakieCore, :NoShading) ?
            Makie.MakieCore.NoShading : false
    end
    # Plot fill
    mesh!(plt, shape; attributes...)
    # Plot stroke if width is greater than 0
    visible = get!(attributes, :visible, Observable(true))
    strokewidth = get!(attributes, :strokewidth, Observable(0))
    attributes[:visible] = @lift $visible && $strokewidth > 0
    attributes[:color] = get(attributes, :strokecolor, :black)
    attributes[:linewidth] = strokewidth
    if haskey(attributes, :shading)
        delete!(attributes, :shading)
    end
    lines!(plt, shape; attributes...)
end

function Makie.plot!(plt::GraphicPlot{<:Tuple{MarkerGraphic}})
    graphic = plt[:graphic]
    attributes = Dict(plt.attributes)
    local_attributes = Dict{Symbol, Any}(
        k => graphic[].attributes[k] isa Observable ?
            graphic[].attributes[k] : @lift($graphic.attributes[k])
        for k in keys(graphic[].attributes)
    )
    attributes = merge!(attributes, local_attributes)
    # Plot marker
    marker = @lift $graphic.marker
    position = @lift Point2f($graphic.x, $graphic.y)
    size = @lift Vec2f($graphic.w, $graphic.h)
    scatter!(plt, position; marker=marker, markersize=size,
             markerspace=:data, attributes...)
end

function Makie.plot!(plt::GraphicPlot{<:Tuple{TextGraphic}})
    graphic = plt[:graphic]
    attributes = Dict(plt.attributes)
    local_attributes = Dict{Symbol, Any}(
        k => graphic[].attributes[k] isa Observable ?
            graphic[].attributes[k] : @lift($graphic.attributes[k])
        for k in keys(graphic[].attributes)
    )
    attributes = merge!(attributes, local_attributes)
    # Plot text
    str = @lift $graphic.str
    text!(plt, @lift($graphic.x), @lift($graphic.y); text=str,
          fontsize=@lift($graphic.fontsize), markerspace=:data,
          align=(:center, :center), attributes...)
end

function Makie.plot!(plt::GraphicPlot{<:Tuple{MultiGraphic}})
    graphic = plt[:graphic]
    attributes = Dict(plt.attributes)
    local_attributes = Dict{Symbol, Any}(
        k => graphic[].attributes[k] isa Observable ?
            graphic[].attributes[k] : @lift($graphic.attributes[k])
        for k in keys(graphic[].attributes)
    )
    attributes = merge!(attributes, local_attributes)
    n_components = length(graphic[].components)
    components = [@lift($graphic.components[i]) for i in 1:n_components]
    for subgraphic in components
        graphicplot!(plt, subgraphic; attributes...)
    end
end
