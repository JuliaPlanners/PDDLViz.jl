export render_state, render_plan, render_trajectory, render_sol
export render_state!, render_plan!, render_trajectory!, render_sol!

"""
    render_state(renderer, domain, state)

Uses `renderer` to render a `state` of a PDDL `domain`. Constructs and
returns a new [`Canvas`](@ref).
"""
function render_state(
    renderer::Renderer, domain::Domain, state; options...
)
    render_state!(new_canvas(renderer), renderer, domain, state; options...)
end

"""
    render_state!(canvas, renderer, domain, state; options...)

Uses `renderer` to render a `state` of a PDDL `domain` to an existing `canvas`,
rendering over any existing content.
"""
function render_state!(
    canvas::Canvas, renderer::Renderer, domain::Domain, state;
    options...
)
    render_state!(canvas, renderer, domain, maybe_observe(state), options...)
end

function render_state!(
    canvas::Canvas, renderer::Renderer, domain::Domain, state::Observable;
    options...
)
    error("Not implemented.")
end


"""
    render_plan(renderer, domain, state, actions; options...)

Uses `renderer` to render a series of `actions` in a PDDL `domain` starting
from `state`. Constructs and returns a new [`Canvas`](@ref).
"""
function render_plan(
    renderer::Renderer, domain::Domain, state, actions;
    options...
)
    render_plan!(new_canvas(renderer), renderer, domain, state, actions;
                 options...)
end

"""
    render_plan!(canvas, renderer, domain, state, actions)

Uses `renderer` to render a series of `actions` in a PDDL `domain` starting
from `state`. Renders to a `canvas` on top of any existing content.
"""
function render_plan!(
    canvas::Canvas, renderer::Renderer, domain::Domain,
    state, actions;
    options...
)
    render_plan!(canvas, renderer, domain, maybe_observe(state),
                 maybe_observe(actions); options...)
end

function render_plan!(
    canvas::Canvas, renderer::Renderer, domain::Domain,
    state::Observable, actions::Observable;
    options...
)
    trajectory = @lift PDDL.simulate(domain, $state, $actions)
    return render_trajectory!(canvas, renderer, domain, trajectory; options...)
end

"""
    render_trajectory(renderer::Renderer,
                      domain::Domain, trajectory::AbstractVector{<:State})

Uses `renderer` to render a `trajectory` of PDDL `domain` states. Constructs
and returns a new [`Canvas`](@ref).
"""
function render_trajectory(
    renderer::Renderer, domain::Domain, trajectory;
    options...
)
    render_trajectory!(new_canvas(renderer), renderer, domain, trajectory;
                       options...)
end

"""
    render_trajectory!(canvas::Canvas, renderer::Renderer,
                       domain::Domain, trajectory::AbstractVector{<:State})

Uses `renderer` to render a `trajectory` of PDDL `domain` states. Renders to a
`canvas` on top of any existing content.
"""
function render_trajectory!(
    canvas::Canvas, renderer::Renderer, domain::Domain, trajectory;
    options...
)
    render_trajectory!(canvas, renderer, domain, maybe_observe(trajectory);
                       options...)
end

function render_trajectory!(
    canvas::Canvas, renderer::Renderer, domain::Domain, trajectory::Observable;
    options...
)
    error("Not implemented.")
end

"""
    render_sol(renderer::Renderer,
               domain::Domain, state::State, sol::Solution)

Uses `renderer` to render a planning solution `sol` starting from a `state` in
a PDDL `domain`. Constructs and returns a new [`Canvas`](@ref).
"""
function render_sol(
    renderer::Renderer, domain::Domain, state, sol;
    options...
)
    render_sol!(new_canvas(renderer), renderer, domain, state, sol; options...)
end

"""
    render_sol!(canvas::Canvas, renderer::Renderer,
                domain::Domain, state::State, sol::Solution)

Uses `renderer` to render a planning solution `sol` starting from a `state` in
a PDDL `domain`. Renders to a `canvas` on top of any existing content.
"""
function render_sol!(
    canvas::Canvas, renderer::Renderer, domain::Domain, state, sol;
    options...
)
    render_sol!(canvas, renderer, domain, maybe_observe(state),
                maybe_observe(sol); options...)
end

function render_sol!(
    canvas::Canvas, renderer::Renderer,
    domain::Domain, state::Observable, sol::Observable{<:Solution};
    options...
)
    error("Not implemented.")
end

function render_sol!(
    canvas::Canvas, renderer::GridworldRenderer,
    domain::Domain, state::Observable, sol::Observable{<: OrderedSolution};
    options...
)
    trajectory = @lift PDDL.simulate(domain, $state, collect($sol))
    return render_trajectory!(canvas, renderer, domain, trajectory; options...)
end
