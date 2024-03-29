function render_state!(
    canvas::Canvas, renderer::GraphworldRenderer,
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
        axis_options = copy(renderer.axis_options)
        delete!(axis_options, :hidedecorations)
        _ax = Axis(canvas.layout[1, 1]; axis_options...)
        push!(canvas.blocks, _ax)
        return _ax
    end
    # Extract objects from state
    locations = [sort!(PDDL.get_objects(domain, state[], t), by=string)
                 for t in renderer.location_types]
    locations = prepend!(reduce(vcat, locations, init=Const[]), renderer.locations)
    movables = [sort!(PDDL.get_objects(domain, state[], t), by=string)
                for t in renderer.movable_types]
    movables = prepend!(reduce(vcat, movables, init=Const[]), renderer.movables)
    # Build static location graph
    is_directed = renderer.is_loc_directed || renderer.is_mov_directed
    n_locs = length(locations)
    loc_graph = is_directed ? SimpleDiGraph(n_locs) : SimpleGraph(n_locs)
    for (i, a) in enumerate(locations), (j, b) in enumerate(locations)
        renderer.loc_edge_fn(domain, state[], a, b) || continue
        add_edge!(loc_graph, i, j)
        is_directed && !renderer.is_loc_directed || continue
        add_edge!(loc_graph, j, i)
    end
    # Add movable objects to graph
    graph = @lift begin
        g = copy(loc_graph)
        # Add edges between locations and movable objects
        for (i, mov) in enumerate(movables)
            add_vertex!(g)
            for (j, loc) in enumerate(locations)
                if renderer.mov_loc_edge_fn(domain, $state, mov, loc)
                    add_edge!(g, n_locs + i, j)
                    break
                end
            end
        end
        # Add edges between movable objects
        if renderer.has_mov_edges
            for (i, a) in enumerate(movables), (j, b) in enumerate(movables)
                renderer.mov_edge_fn(domain, $state, a, b) || continue
                add_edge!(g, n_locs + i, n_locs + j)
                is_directed && !renderer.is_mov_directed || continue
                add_edge!(g, n_locs + j, n_locs + i)
            end
        end
        g
    end
    # Construct layout for graph including movable objects
    layout = renderer.graph_layout(n_locs)
    # Define node and edge labels
    loc_labels = get(options, :show_location_labels, true) ?
        string.(locations) : fill("", length(locations))
    mov_labels = get(options, :show_movable_labels, true) ?
        string.(movables) : fill("", length(movables))
    node_labels = [loc_labels; mov_labels]
    if get(options, :show_edge_labels, false)
        init_n_edges = ne(graph[])
        edge_labels = @lift begin
            n_edges = ne($graph)
            if n_edges != init_n_edges
                error("Cannot update edge labels for dynamic graphs.")
            end
            labels = Vector{String}(undef, n_edges)
            for (i, e) in enumerate(edges($graph))
                if e.src <= n_locs && e.dst <= n_locs
                    a, b = locations[e.src], locations[e.dst]
                    labels[i] = renderer.loc_edge_label_fn(domain, $state, a, b)
                elseif e.src > n_locs && e.dst > n_locs
                    a = movables[e.src - n_locs]
                    b = movables[e.dst - n_locs]
                    labels[i] = renderer.mov_edge_label_fn(domain, $state, a, b)
                elseif e.src <= n_locs && e.dst > n_locs
                    a = movables[e.dst - n_locs]
                    b = locations[e.src]
                    labels[i] =
                        renderer.mov_loc_edge_label_fn(domain, $state, a, b)
                end
            end
            labels
        end
    else
        edge_labels = nothing
    end
    # Define node and edge colors
    node_colors = @lift map(vertices($graph)) do v
        v > n_locs ? to_color(get(options, :movable_node_color, :gray)) :
                     to_color(get(options, :location_node_color, :black))
    end
    edge_colors = @lift map(edges($graph)) do e
        e.src > n_locs || e.dst > n_locs ?
            to_color(get(options, :movable_edge_color, (:mediumpurple, 0.75))) :
            to_color(get(options, :location_edge_color, :black))
    end
    # Render graph
    gp = graphplot!(ax, graph; layout=layout, node_color=node_colors,
                    nlabels=node_labels, elabels=edge_labels,
                    edge_color=edge_colors, renderer.graph_options...)
    canvas.plots[:graphplot] = gp
    canvas.observables[:graph] = graph
    canvas.observables[:layout] = gp[:layout]
    canvas.observables[:node_pos] = gp[:node_pos]
    # Update node label offsets
    label_offset = get(options, :label_offset, 0.15)
    map!(gp.nlabels_offset, gp.node_pos) do node_pos
        mean_pos = sum(node_pos[1:n_locs]) / n_locs
        dir = node_pos .- mean_pos
        mag = [GeometryBasics.norm(d) for d in dir]
        dir = dir ./ mag
        offsets = label_offset .* dir
        return offsets
    end
    # Render location graphics
    if get(options, :show_location_graphics, true)
        for (i, loc) in enumerate(locations)
            r = get(renderer.loc_renderers, loc, nothing)
            if r === nothing
                loc in PDDL.get_objects(state[]) || continue
                type = PDDL.get_objtype(state[], loc)
                r = get(renderer.loc_type_renderers, type, nothing)
                r === nothing && continue
            end
            graphic_pos = Observable(gp.node_pos[][i], ignore_equal_values=true)
            on(gp.node_pos, update=true) do positions
                graphic_pos[] = positions[i]
            end
            graphic = @lift begin
                pos = $graphic_pos
                translate(r(domain, $state, loc), pos[1], pos[2])
            end
            plt = graphicplot!(ax, graphic)
            canvas.plots[Symbol("$(loc)_graphic")] = plt
        end
    end
    # Render movable object graphics
    if get(options, :show_movable_graphics, true)
        for (i, obj) in enumerate(movables)
            r = get(renderer.mov_renderers, obj, nothing)
            if r === nothing
                obj in PDDL.get_objects(state[]) || continue
                type = PDDL.get_objtype(state[], obj)
                r = get(renderer.mov_type_renderers, type, nothing)
                r === nothing && continue
            end
            graphic_pos = Observable(gp.node_pos[][n_locs + i],
                                     ignore_equal_values=true)
            on(gp.node_pos, update=true) do positions
                graphic_pos[] = positions[n_locs + i]
            end
            graphic = @lift begin
                pos = $graphic_pos
                translate(r(domain, $state, obj), pos[1], pos[2])
            end
            plt = graphicplot!(ax, graphic)
            canvas.plots[Symbol("$(obj)_graphic")] = plt
        end
    end
    # Hide decorations if flag is specified
    if get(renderer.axis_options, :hidedecorations, true)
        hidedecorations!(ax)
    end
    return canvas
end

"""
- `show_location_graphics = true`: Whether to show location graphics.
- `show_location_labels = true`: Whether to show location labels.
- `show_movable_graphics = true`: Whether to show movable object graphics.
- `show_movable_labels = true`: Whether to show movable object labels.
- `show_edge_labels = false`: Whether to show edge labels.
- `location_node_color = :black`: Color of location nodes.
- `location_edge_color = :black`: Color of edges between locations.
- `movable_node_color = :gray`: Color of movable object nodes.
- `movable_edge_color = (:mediumpurple, 0.75)`: Color of edges between
  locations and movable objects.
- `label_offset = 0.15`: How much labels are offset from the center of their
  corresponding objects. Larger values move the labels further away.
"""
default_state_options(R::Type{GraphworldRenderer}) = Dict{Symbol,Any}(
    :show_location_graphics => true,
    :show_location_labels => true,
    :show_movable_graphics => true,
    :show_movable_labels => true,
    :show_edge_labels => false,
    :location_node_color => :black,
    :location_edge_color => :black,
    :movable_node_color => :gray,
    :movable_edge_color => (:mediumpurple, 0.75),
    :label_offset => 0.15
)
