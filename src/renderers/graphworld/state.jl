function render_state!(
    canvas::Canvas, renderer::GraphworldRenderer,
    domain::Domain, state::Observable;
    options...
)
    # Update options
    options = merge(renderer.state_options, options)
    # Set canvas state observable (replacing any previous state)
    canvas.state = state
    # Extract or construct main axis
    ax = get(canvas.blocks, 1) do 
        _ax = Axis(canvas.layout[1,1], aspect=1)
        push!(canvas.blocks, _ax)
        return _ax
    end
    # Extract objects from state
    locations = reduce(vcat, [PDDL.get_objects(domain, state[], t)
                              for t in renderer.location_types])
    movables = reduce(vcat, [PDDL.get_objects(domain, state[], t)
                             for t in renderer.movable_types])
    # Build static location graph
    n_locs = length(locations)
    loc_graph = renderer.is_directed ?
        SimpleDiGraph(n_locs) : SimpleGraph(n_locs)
    for (i, a) in enumerate(locations), (j, b) in enumerate(locations)
        if renderer.edge_fn(domain, state[], a, b)
            add_edge!(loc_graph, i, j)
        end
    end
    # Add movable objects to graph
    graph = @lift begin
        g = copy(loc_graph)
        for obj in movables
            add_vertex!(g)
            for (i, loc) in enumerate(locations)
                if renderer.at_loc_fn(domain, $state, obj, loc)
                    add_edge!(g, i, nv(g))
                    continue
                end
            end
        end
        g
    end
    # Construct layout for graph including movable objects
    loc_pos = renderer.graph_layout(loc_graph)
    layout = @lift begin
        init_pos = copy(loc_pos)
        for i in n_locs+1:nv($graph)
            nbs = inneighbors($graph, i)
            if isempty(nbs)
                push!(init_pos, Point2f(0, 0))
            else
                push!(init_pos, loc_pos[nbs[1]])
            end
        end
        Spring(; pin=loc_pos, initialpos=init_pos, C=0.3)
    end
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
                if e.src > n_locs || e.dst > n_locs
                    labels[i] = ""
                else
                    a, b = locations[e.src], locations[e.dst]
                    labels[i] = renderer.edge_label_fn(domain, $state, a, b)
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
    # Update node label offsets
    offset_mult = get(options, :label_offset_mult, 0.2)
    map!(gp.nlabels_offset, gp.node_pos) do node_pos
        mean_pos = sum(node_pos[1:n_locs]) / n_locs
        offsets = offset_mult .* (node_pos .- mean_pos)
        return offsets
    end
    # Render location graphics
    if get(options, :show_location_graphics, true)
        for (i, loc) in enumerate(locations)
            type = PDDL.get_objtype(state[], loc)
            r = get(renderer.loc_renderers, type, nothing)
            r === nothing && continue
            graphic = @lift begin
                pos = $(gp.node_pos)[i]
                translate(r(domain, $state, loc), pos[1], pos[2])
            end
            graphicplot!(ax, graphic)
        end
    end
    # Render movable object graphics
    if get(options, :show_movable_graphics, true)
        for (i, obj) in enumerate(movables)
            type = PDDL.get_objtype(state[], obj)
            r = get(renderer.obj_renderers, type, nothing)
            r === nothing && continue
            graphic = @lift begin
                pos = $(gp.node_pos)[n_locs + i]
                translate(r(domain, $state, obj), pos[1], pos[2])
            end
            graphicplot!(ax, graphic)
        end
    end
    # Final axis modifications
    hidedecorations!(ax)
    autolimits!(ax)
    ax.aspect = 1
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
- `label_offset_mult = 0.2`: Multiplier for the offset of labels from their
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
    :label_offset_mult => 0.2,
)
