export render_storyboard

using Makie: extract_frames

"""
    render_storyboard(anim::Animation, [idxs]; options...)

Renders an [`Animation`](@ref) as a series of (bitmap) images in a storyboard.
Returns a `Figure` where each frame is a subplot.

The frames to render can be specified by `idxs`, a vector of indices. If
`idxs` is not specified, all frames are rendered.

# Options

- `n_rows = 1`: Number of storyboard rows.
- `n_cols = nothing`: Number of storyboard columns (default: number of frames).
- `figscale = 1`: Scales figure size relative to number of pixels required
    to fit all frames at their full resolution.
- `titles`: List or dictionary of frame titles.
- `subtitles`: List or dictionary of frame subtitles.
- `xlabels`: List or dictionary of x-axis labels per frame.
- `ylabels`: List or dictionary of y-axis labels per frame.

Options that control title and label styling (e.g. `titlesize`) can also be
specified as keyword arguments. See `Axis` for details.
"""
function render_storyboard(
    anim::Animation, idxs=nothing;
    n_rows::Union{Int, Nothing}=1, n_cols::Union{Int, Nothing}=nothing,
    figscale::Real=1, options...
)
    # Save animation to file if not already saved
    if anim.path == anim.videostream.path
        dir = mktempdir()
        format = anim.videostream.options.format
        path = joinpath(dir, "$(gensym(:video)).$(format)")
        save(path, anim)
    end
    # Extract frames from video
    frames = Any[]
    mktempdir() do dir
        extract_frames(anim.path, dir)
        for (i, path) in enumerate(readdir(dir))
            frame = load(joinpath(dir, path))
            idxs !== nothing && !(i in idxs) && continue
            push!(frames, rotr90(frame))
        end
    end
    # Determine number of rows and columns
    n_frames = length(frames)
    if n_rows === nothing && n_cols === nothing
        n_rows = 1
        n_cols = n_frames
    elseif n_rows === nothing
        n_rows = ceil(Int, n_frames / n_cols)
    elseif n_cols === nothing
        n_cols = ceil(Int, n_frames / n_rows)
    end
    # Extract titles, labels, and other options
    titles = get(options, :titles) do 
        fill(get(options, :title, ""), n_frames)
    end
    subtitles = get(options, :subtitles) do
        fill(get(options, :subtitle, ""), n_frames)
    end
    xlabels = get(options, :xlabels) do
        fill(get(options, :xlabel, ""), n_frames)
    end
    ylabels = get(options, :ylabels) do
        fill(get(options, :ylabel, ""), n_frames)
    end
    title_options = filter(Dict(options)) do (k, v)
        k in (
            :titlealign, :titlecolor, :titlefont,
            :titlesize, :titlegap, :titlelineheight,
            :subtitlealign, :subtitlecolor, :subtitlefont, 
            :subtitlesize, :subtitlegap, :subtitlelineheight,
            :xlabelcolor, :xlabelfont, :xlabelsize,
            :xlabelpadding, :xlabelrotation,
            :ylabelcolor, :ylabelfont, :ylabelsize,
            :ylabelpadding, :ylabelrotation
        )
    end
    # Create figure with subplots for each frame
    width = round(Int, size(frames[1])[1] * n_cols * figscale)
    height = round(Int, size(frames[1])[2] * n_rows * figscale)
    figure = Figure()
    resize!(figure.scene, (width, height))
    for (i, frame) in enumerate(frames)
        i_row = ceil(Int, i / n_cols)
        i_col = i - (i_row - 1) * n_cols
        ax = Axis(figure[i_row, i_col]; aspect=DataAspect(),
                  title=get(titles, i, ""), subtitle=get(subtitles, i, ""),
                  xlabel=get(xlabels, i, ""), ylabel=get(ylabels, i, ""),
                  title_options...)
        image!(ax, frame)
        hidedecorations!(ax)
        hidespines!(ax)
        ax.xlabelvisible = true
        ax.ylabelvisible = true
    end
    resize_to_layout!(figure)
    return figure
end
