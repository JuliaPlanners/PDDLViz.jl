function render_state!(
    canvas::Canvas, renderer::GridworldRenderer,
    domain::Domain, state::Observable;
    replace::Bool=true, options...
)
    # Update options
    options = merge(renderer.state_options, options)
    # Set canvas state observable (replacing any previous state)
    if replace || canvas.state === nothing
        canvas.state = state
    end
    # Extract or construct main axis
    ax = get(canvas.blocks, 1) do 
        _ax = Axis(canvas.layout[1,1], aspect=DataAspect(),
                   xzoomlock=true, xpanlock=true, xrectzoom=false,
                   yzoomlock=true, ypanlock=true, yrectzoom=false,
                   xgridstyle=:dash, ygridstyle=:dash,
                   xgridcolor=:black, ygridcolor=:black)
        hidedecorations!(_ax, grid=false)
        push!(canvas.blocks, _ax)
        return _ax
    end
    # Get grid dimensions from PDDL state
    base_grid = @lift $state[renderer.grid_fluents[1]]
    height = @lift size($base_grid, 1)
    width = @lift size($base_grid, 2)
    # Render grid variables as heatmaps
    if get(options, :show_grid, true)
        for (i, grid_fluent) in enumerate(renderer.grid_fluents)
            grid = @lift reverse(transpose(float($state[grid_fluent])), dims=2)
            cmap = cgrad([:transparent, renderer.grid_colors[i]])
            crange = @lift (min(minimum($grid), 0), max(maximum($grid), 1))
            plt = heatmap!(ax, grid, colormap=cmap, colorrange=crange)
            canvas.plots[Symbol("grid_$(grid_fluent)")] = plt
        end
    end
    # Set ticks to show grid
    map!(w -> (1:w-1) .+ 0.5, ax.xticks, width)
    map!(h -> (1:h-1) .+ 0.5, ax.yticks, height) 
    xlims!(ax, 0.5, width[] + 0.5)
    ylims!(ax, 0.5, height[] + 0.5)
    # Render locations
    if get(options, :show_locations, true)
        for (x, y, label, color) in renderer.locations
            _y = @lift $height - y + 1
            fontsize = 1 / (1.5*length(label)^0.5)
            text!(ax, x, _y; text=label, color=color, align=(:center, :center),
                  markerspace=:data, fontsize=fontsize)
        end
    end
    # Render objects
    default_obj_renderer(d, s, o) = SquareShape(0, 0, 0.2, color=:gray)
    if get(options, :show_objects, true)
        # Render objects with type-specific graphics
        for type in renderer.obj_type_z_order
            for obj in PDDL.get_objects(domain, state[], type)
                r = get(renderer.obj_renderers, type, default_obj_renderer)
                graphic = @lift begin
                    x, y = gw_obj_loc(renderer, $state, obj, $height)
                    translate(r(domain, $state, obj), x, y)
                end
                plt = graphicplot!(ax, graphic)
                canvas.plots[Symbol("$(obj)_graphic")] = plt
           end
        end
    end
    # Render agent
    if renderer.has_agent && get(options, :show_agent, true)
        graphic = @lift begin
            x, y = gw_agent_loc(renderer, $state, $height)
            translate(renderer.agent_renderer(domain, $state), x, y)
        end
        plt = graphicplot!(ax, graphic)
        canvas.plots[:agent_graphic] = plt
    end
    # Render inventories
    if renderer.show_inventory && get(options, :show_inventory, true)
        inventory_labelsize = renderer.inventory_labelsize
        colsize!(canvas.layout, 1, Auto(1))
        rowsize!(canvas.layout, 1, Auto(1))
        for (i, inventory_fn) in enumerate(renderer.inventory_fns)
            # Extract objects
            ty = get(renderer.inventory_types, i, :object)
            sorted_objs = sort(PDDL.get_objects(domain, state[], ty), by=string)
            # Extract or construct axis for each inventory
            ax_i = get(canvas.blocks, i+1) do
                title = get(renderer.inventory_labels, i, "Inventory")
                _ax = Axis(canvas.layout[i+1, 1], aspect=DataAspect(),
                           title=title, titlealign=:left,
                           titlefont=:regular, titlesize=inventory_labelsize,
                           xzoomlock=true, xpanlock=true, xrectzoom=false,
                           yzoomlock=true, ypanlock=true, yrectzoom=false,
                           xgridstyle=:solid, ygridstyle=:solid,
                           xgridcolor=:black, ygridcolor=:black)
                hidedecorations!(_ax, grid=false)
                push!(canvas.blocks, _ax)
                return _ax
            end
            # Render inventory as heatmap
            inventory_size = @lift max(length(sorted_objs), $width)
            cmap = cgrad([:transparent, :black])
            heatmap!(ax_i, @lift(zeros($inventory_size, 1)),
                     colormap=cmap, colorrange=(0, 1))
            map!(w -> (1:w-1) .+ 0.5, ax_i.xticks, inventory_size)
            map!(ax_i.limits, inventory_size) do w
                return ((0.5, w + 0.5), nothing)
            end
            ax_i.yticks = [0.5, 1.5]
            # Compute object locations
            obj_locs = @lift begin
                locs = Int[]
                n = 0
                for obj in sorted_objs
                    if inventory_fn(domain, $state, obj)
                        push!(locs, n += 1)
                    else
                        push!(locs, -1)
                    end
                end
                return locs
            end
            # Render objects in inventory
            for (j, obj) in enumerate(sorted_objs)
                type = PDDL.get_objtype(state[], obj)
                r = get(renderer.obj_renderers, type, default_obj_renderer)
                graphic = @lift begin
                    x = $obj_locs[j]
                    g = translate(r(domain, $state, obj), x, 1)
                    g.attributes[:visible] = x > 0
                    g
                end
                graphicplot!(ax_i, graphic)
            end
            # Resize row
            row_height = 1/height[] * width[]/inventory_size[]
            rowsize!(canvas.layout, i+1, Auto(row_height))
        end
        rowgap!(canvas.layout, 10)
        resize_to_layout!(canvas.figure)
    end
    # Render vision bar
    if renderer.show_vision && get(options, :show_vision, true)
        vision_labelsize = renderer.vision_labelsize
        colsize!(canvas.layout, 1, Auto(1))
        rowsize!(canvas.layout, 1, Auto(1))
        for (i, vision_fn) in enumerate(renderer.vision_fns)
            # Extract objects
            ty = get(renderer.vision_types, i, :object)
            sorted_objs = sort(PDDL.get_objects(domain, state[], ty), by=string)
            # Extract or construct axis for each vision bar
            ax_i = get(canvas.blocks, length(renderer.inventory_fns) + i + 1) do
                title = get(renderer.vision_labels, i, "Vision")
                _ax = Axis(canvas.layout[length(renderer.inventory_fns) + i + 1, 1], aspect=DataAspect(),
                           title=title, titlealign=:left,
                           titlefont=:regular, titlesize=vision_labelsize,
                           xzoomlock=true, xpanlock=true, xrectzoom=false,
                           yzoomlock=true, ypanlock=true, yrectzoom=false,
                           xgridstyle=:solid, ygridstyle=:solid,
                           xgridcolor=:black, ygridcolor=:black)
                hidedecorations!(_ax, grid=false)
                push!(canvas.blocks, _ax)
                return _ax
            end
            # Render vision bar as heatmap
            vision_size = @lift max(length(sorted_objs), $width)
            cmap = cgrad([:transparent, :black])
            heatmap!(ax_i, @lift(zeros($vision_size, 1)),
                     colormap=cmap, colorrange=(0, 1))
            map!(w -> (1:w-1) .+ 0.5, ax_i.xticks, vision_size)
            map!(ax_i.limits, vision_size) do w
                return ((0.5, w + 0.5), nothing)
            end
            ax_i.yticks = [0.5, 1.5]
            # Compute object locations
            obj_locs = @lift begin
                locs = Int[]
                n = 0
                for obj in sorted_objs
                    if vision_fn(domain, $state, obj)
                        push!(locs, n += 1)
                    else
                        push!(locs, -1)
                    end
                end
                return locs
            end
            # Render objects in vision bar
            for (j, obj) in enumerate(sorted_objs)
                type = PDDL.get_objtype(state[], obj)
                r = get(renderer.obj_renderers, type, default_obj_renderer)
                graphic = @lift begin
                    x = $obj_locs[j]
                    g = translate(r(domain, $state, obj), x, 1)
                    g.attributes[:visible] = x > 0
                    g
                end
                graphicplot!(ax_i, graphic)
            end
            # Resize row
            row_height = 1/height[] * width[]/vision_size[]
            rowsize!(canvas.layout, length(renderer.inventory_fns) + i + 1, Auto(row_height))
        end
        rowgap!(canvas.layout, 10)
        resize_to_layout!(canvas.figure)
    end
    # Render caption
    if get(options, :caption, nothing) !== nothing
        caption = options[:caption]
        _ax = canvas.blocks[end]
        _ax.xlabel = caption
        _ax.xlabelvisible = true
        _ax.xlabelfont = get(options, :caption_font, :regular)
        _ax.xlabelsize = get(options, :caption_size, 24)
        _ax.xlabelcolor = get(options, :caption_color, :black)
        _ax.xlabelpadding = get(options, :caption_padding, 12)
        _ax.xlabelrotation = get(options, :caption_rotation, 0)
        # Store observable for caption in canvas
        canvas.observables[:caption] = _ax.xlabel
    end
    # Return the canvas
    return canvas
end

"""
- `show_grid::Bool = true`: Whether to show grid variables (walls, etc).
- `show_agent::Bool = true`: Whether to show the agent.
- `show_objects::Bool = true`: Whether to show objects.
- `show_locations::Bool = true`: Whether to show locations.
- `show_inventory::Bool = true`: Whether to show inventories.
- `show_vision::Bool = true`: Whether to show vision bar.
- `caption = nothing`: Caption to display below the figure.
- `caption_font = :regular`: Font for the caption.
- `caption_size = 24`: Font size for the caption.
- `caption_color = :black`: Font color for the caption.
- `caption_padding = 12`: Padding for the caption.
- `caption_rotation = 0`: Rotation for the caption.
"""
default_state_options(R::Type{GridworldRenderer}) = Dict{Symbol,Any}(
    :show_grid => true,
    :show_agent => true,
    :show_objects => true,
    :show_locations => true,
    :show_inventory => true,
    :show_vision => true,
    :caption => nothing,
    :caption_font => :regular,
    :caption_size => 24,
    :caption_color => :black,
    :caption_padding => 12,
    :caption_rotation => 0
)
