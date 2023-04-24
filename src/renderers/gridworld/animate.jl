function anim_initialize!(
    canvas::Canvas, renderer::GridworldRenderer, domain::Domain, state::State;
    callback=nothing, overlay=nothing, options...
)
    if canvas.state !== nothing
        return anim_transition!(canvas, renderer, domain, state;
                                callback=callback, overlay=overlay, options...)
    end
    options = merge(renderer.anim_options, options)
    # Render state with caption if provided
    captions = get(options, :captions, nothing)
    caption = isnothing(captions) ? nothing : get(captions, 1, nothing)
    render_state!(canvas, renderer, domain, state; caption=caption, options...)
    # Add trail tracks if trail length is non-zero
    trail_length = get(options, :trail_length, 0)
    if trail_length > 0
        trail = Observable([state])
        trail_options = merge(renderer.trajectory_options, options)
        agent_color = get(trail_options, :agent_color, :black) |> to_color
        trail_options[:agent_start_color] = set_alpha(agent_color, 0.0)
        object_colors = get(trail_options, :object_colors, Symbol[]) .|> to_color
        trail_options[:object_start_colors] =
            [set_alpha(c, 0.0) for c in object_colors]
        type_colors = get(trail_options, :type_colors, Symbol[]) .|> to_color
        trail_options[:type_start_colors] =
            [set_alpha(c, 0.0) for c in type_colors]
        render_trajectory!(canvas, renderer, domain, trail; trail_options...)
        canvas.observables[:trail] = trail
    end
    # Run callbacks
    overlay !== nothing && overlay(canvas)
    callback !== nothing && callback(canvas)
    return canvas
end

function anim_transition!(
    canvas::Canvas, renderer::GridworldRenderer, domain::Domain,
    state::State, action::Term = PDDL.no_op, t::Int = 1;
    callback=nothing, overlay=nothing, options...
)
    options = merge(renderer.anim_options, options)
    # Update canvas with new state
    canvas.state[] = state
    # Update captions if provided
    captions = get(options, :captions, nothing)
    if !isnothing(captions)
        caption = get(captions, t, nothing)
        if !isnothing(caption)
            canvas.observables[:caption][] = caption
        end
    end
    # Update trail tracks if trail length is non-zero
    trail_length = get(options, :trail_length, 0)
    if trail_length > 0 && haskey(canvas.observables, :trail)
        trail = canvas.observables[:trail]
        push!(trail[], state)
        if length(trail[]) > trail_length
            popfirst!(trail[])
        end
        notify(trail)
    end
    # Run callbacks
    overlay !== nothing && overlay(canvas)
    callback !== nothing && callback(canvas)
    return canvas
end

"""
- `captions = nothing`: Captions to display for each timestep, e.g., 
  `["t=1", "t=2", ...]`. Can be provided as a vector of strings, or a dictionary
  mapping timesteps to strings. If `nothing`, no captions are displayed.
- `trail_length = 0`: Length of trail tracks to display for each agent or
  tracked object. If `0`, no trail tracks are displayed.
"""
default_anim_options(R::Type{GridworldRenderer}) = Dict{Symbol,Any}(
    :captions => nothing,
    :trail_length => 0,
)
