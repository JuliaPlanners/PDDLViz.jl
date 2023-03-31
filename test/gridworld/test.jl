# Test gridworld rendering
using RenderPDDL, PDDL, Test, GLMakie

# Load example gridworld domain and problem
domain = load_domain(joinpath(@__DIR__, "domain.pddl"))
problem = load_problem(joinpath(@__DIR__, "problem.pddl"))

# Load array extension to PDDL
PDDL.Arrays.register!()

# Construct initial state from domain and problem
state = initstate(domain, problem)

# Construct gridworld renderer
gem_colors = RenderPDDL.colorschemes[:vibrant]
renderer = RenderPDDL.GridworldRenderer(
    agent_renderer = (d, s) -> HumanGraphic(color=:black),
    obj_renderers = Dict(
        :key => (d, s, o) -> KeyGraphic(
            visible=!s[Compound(:has, [o])]
        ),
        :door => (d, s, o) -> LockedDoorGraphic(
            visible=s[Compound(:locked, [o])]
        ),
        :gem => (d, s, o) -> GemGraphic(
            visible=!s[Compound(:has, [o])],
            color=gem_colors[parse(Int, string(o.name)[end])]
        )
    )
)

# Render initial state
canvas = renderer(domain, state)

# Render plan
plan = @pddl("(right)", "(right)", "(right)", "(up)", "(up)")
renderer(canvas, domain, state, plan)

# Render trajectory
trajectory = PDDL.simulate(domain, state, plan)
canvas = renderer(domain, trajectory)
