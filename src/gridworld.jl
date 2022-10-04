# Import shape constructors for convenience
import Makie.GeometryBasics: Circle, Point2f
using GLMakie, FileIO

"Customizable renderer for 2D gridworld domains."
@kwdef mutable struct GridworldRenderer <: Renderer
    show_agent::Bool = true
    show_objects::Bool = true
    agent_x = pddl"xpos"
    agent_y = pddl"ypos"
    obj_x = obj -> Compound(:xloc, [obj])
    obj_y = obj -> Compound(:yloc, [obj])
    sprites = Dict{Symbol, Any}(:default => load(""))
end

@kwdef mutable struct GridworldSprite <: Sprite
    img = rotr90(load(""))
end

function add_sprite!(renderer::GridworldRenderer, domain::Domain, state::State, obj::Symbol)
    renderer.sprites[obj] = load("")
    return nothing
end

current_canvas(renderer::GridworldRenderer) = error("Not implemented.")

function new_canvas(renderer::GridworldRenderer)
    fig = Makie.Figure(resolution=(600,600))
    ax = Makie.Axis(fig[1,1])
    Makie.hidedecorations!(ax, grid=false) # Remove ticks
    return GenericCanvas(fig)
end

function render!(canvas::Canvas, renderer::GridworldRenderer,
                 domain::Domain, state::State, extras...)
    # Set domain and state of canvas if neccessary
    if canvas.domain !== domain
        canvas.domain = domain
    end
    if canvas.state !== state
        canvas.state = state
    end
    # Extract current figure and axis
    fig = canvas.output
    ax = Makie.content(fig[1, 1])
    # Get wall grid and its dimensions from PDDL state
    grid = state[pddl"walls"] # TODO make grid variable customizable
    height, width = size(grid)
    grid = reverse(transpose(grid), dims=2) # Transpose and rotate
    # Render wall grid as a heatmap
    cmap = Makie.cgrad([:transparent, :black])
    Makie.heatmap!(ax, float(grid), colormap=cmap)
    # Set ticks to show grid
    ax.xticks = (1:width-1) .+ 0.5
    ax.yticks = (1:height-1) .+ 0.5
    ax.xgridcolor, ax.ygridcolor = :black, :black
    ax.xgridstyle, ax.ygridstyle = :dash, :dash
    # Iterate over objects and render them
    if renderer.show_objects

        for obj in PDDL.get_objects(state)
            render_object!(canvas, renderer, domain, state, obj)
        end
    end

    # Render agent
    if renderer.show_agent
        # Look-up agent position from PDDL state
        x = state[renderer.agent_x]
        y = height - state[renderer.agent_y] + 1 # Flip y-coordinate
        if :agent in PDDL.get_objects(state)
            img = renderer.sprites[PDDL.get_objtypes(state)[:agent]]
            image!([x-0.5, x+0.5], [y-0.5, y+0.5], img)
        else
            agent_shape = Circle(Point2f(x, y), 0.2)
            Makie.poly!(ax, agent_shape, color=:red)
        end
    end
    # Return the canvas
    return canvas
end

function render_object!(canvas::Canvas, renderer::GridworldRenderer,
                        domain::Domain, state::State, object::Const)
    # Extract current figure and axis
    fig = canvas.output
    ax = Makie.content(fig[1, 1])
    height = size(state[pddl"walls"])[1] # TODO make grid variable customizable
    # TODO : Plot different shapes / sprites based on object name and type
    # Check if object should be plotted based on whether it is picked up / unlocked
    x = state[renderer.obj_x(object)]
    y = height - state[renderer.obj_y(object)] + 1 # Flip y-coordinate


    if in(object, values(PDDL.get_objtypes(state)))
        img = renderer.sprites[PDDL.get_objtypes(state)[object]]
        image!([x-0.5, x+0.5], [y-0.5, y+0.5], img)
    else
        obj_shape = Circle(Point2f(x, y), 0.1)
        Makie.poly!(ax, obj_shape)
    end
    return canvas
end

function animate!(
    canvas::Canvas, renderer::GridworldRenderer,
    domain::Domain, state1::State, state2::State, action=nothing;
    n_steps=nothing, step_dur=nothing, record=false
)
    error("Not implemented.")
end
