## Makie plotting recipes for graphics ##

@recipe(GraphicPlot, graphic) do scene
    Makie.Attributes(
        shading=false,
        cycle=[:color],
        colormap=colorschemes[:vibrant]
    )
end

function Makie.plot!(plt::GraphicPlot{<:Tuple{BasicGraphic}})
    graphic = plt[:graphic]
    shape = Makie.@lift getfield($graphic, :shape)
    attributes = Dict(plt.attributes)
    local_attributes = Dict(
        k => Makie.@lift(getfield($graphic, :attributes)[k])
        for k in keys(graphic[].attributes)
    )
    attributes = merge!(attributes, local_attributes)
    # Plot fill
    Makie.mesh!(plt, shape; attributes...)
    # Plot stroke if width is greater than 0
    attributes[:visible] = (get(attributes, :visible, false)[] &&
                            get(attributes, :strokewidth, 0)[] > 0)
    attributes[:color] = get(attributes, :strokecolor, :black)
    attributes[:linewidth] = get(attributes, :strokewidth, 0)
    Makie.lines!(plt, shape; attributes...)
end

function Makie.plot!(plt::GraphicPlot{<:Tuple{MultiGraphic}})
    graphic = plt[:graphic]
    attributes = Dict(plt.attributes)
    local_attributes = Dict(
        k => Makie.@lift(getfield($graphic, :attributes)[k])
        for k in keys(graphic[].attributes)
    )
    attributes = merge!(attributes, local_attributes)
    n_components = length(graphic[].components)
    components = [Makie.@lift($graphic.components[i]) for i in 1:n_components]
    for subgraphic in components
        graphicplot!(plt, subgraphic; attributes...)
    end
end
