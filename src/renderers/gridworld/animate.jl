function anim_initialize!(
    canvas::Canvas, renderer::GridworldRenderer, domain::Domain, state::State;
    callback=nothing, options...
)
    options = merge(renderer.anim_options, options)
    if canvas.state === nothing
        captions = get(options, :captions, nothing)
        caption = isnothing(captions) ? nothing : get(captions, 1, nothing)
        render_state!(canvas, renderer, domain, state; 
                      caption=caption, options...)
    else
        anim_transition!(canvas, renderer, domain, state; options...)
    end
    callback !== nothing && callback(canvas)
    return canvas
end

function anim_transition!(
    canvas::Canvas, renderer::GridworldRenderer, domain::Domain,
    state::State, action::Term = PDDL.no_op, t::Int = 1;
    callback=nothing, options...
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
    # Run callback
    callback !== nothing && callback(canvas)
    return canvas
end

"""
- `captions = nothing`: Captions to display for each timestep, e.g., 
  `["t=1", "t=2", ...]`. Can be provided as a vector of strings, or a dictionary
    mapping timesteps to strings. If `nothing`, no captions are displayed.
"""
default_anim_options(R::Type{GridworldRenderer}) = Dict{Symbol,Any}(
    :captions => nothing
)
