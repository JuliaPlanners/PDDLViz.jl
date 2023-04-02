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
    ),
    show_inventory = true,
    inventory_fns = [(d, s, o) -> s[Compound(:has, [o])]],
    inventory_types = [:item]
)

# Render initial state
canvas = renderer(domain, state); display(canvas)

# Render plan
plan = @pddl("(right)", "(right)", "(right)", "(up)", "(up)")
renderer(canvas, domain, state, plan)

# Render trajectory
trajectory = PDDL.simulate(domain, state, plan)
canvas = renderer(domain, trajectory)

# Animate trajectory
plan = @pddl(
    "(right)", "(right)", "(right)", "(up)", "(up)",
    "(left)", "(left)", "(left)",
    "(up)", "(up)", "(up)", "(up)",
    "(pickup key1)", "(up)", "(pickup gem1)",
    "(right)", "(right)", "(down)", "(unlock key1 door1)"
)

anim = anim_plan(renderer, domain, state, plan; show=true)
