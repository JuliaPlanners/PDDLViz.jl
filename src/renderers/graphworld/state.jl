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
        _ax = Axis(canvas.layout[1,1], aspect=DataAspect())
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
        if renderer.edge_fn(domain, state, a, b)
            add_edge!(loc_graph, i, j)
        end
    end
    # Add movable objects to graph
    graph = @lift begin
        g = copy(loc_graph)
        for obj in movables
            for (i, loc) in enumerate(locations)
                if renderer.get_loc_fn(domain, $state, obj, loc)
                    add_vertex!(g)
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
            j = inneighbors($graph, i)[1]
            push!(init_pos, loc_pos[j])
        end
        Spring(; pin=loc_pos, initialpos=init_pos, C=0.5)
    end
    # Compute labels
    node_labels = [string.(locations); string.(movables)]
    edge_labels = @lift begin
        labels = Vector{String}(undef, ne($graph))
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
    # Define edge styles
    edge_styles = map(edges(graph[])) do e
        e.src > n_locs || e.dst > n_locs ? :dash : :solid
    end
    # Render graph
    gp = graphplot!(ax, graph; layout=layout,
                    nlabels=node_labels, elabels=edge_labels,
                    edge_attr=(linestyle=edge_styles,),
                    edge_plottype=:beziersegments, renderer.graph_options...)
    # Update node offsets
    map!(gp.nlabels_offset, gp.node_pos) do node_pos
        mean_pos = sum(node_pos) / length(node_pos)
        offsets = 0.15 * (node_pos .- mean_pos)
        return offsets
    end
    # Final axis modifications
    hidedecorations!(ax)
    autolimits!(ax)
    ax.aspect = 1
    return canvas
end
