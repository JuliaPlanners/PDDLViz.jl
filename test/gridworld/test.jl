# Test gridworld rendering
using PDDLViz, GLMakie
using PDDL, SymbolicPlanners, PlanningDomains

# Load example gridworld domain and problem
domain = load_domain(:doors_keys_gems)
problem = load_problem(:doors_keys_gems, 3)

# Load array extension to PDDL
PDDL.Arrays.register!()

# Construct initial state from domain and problem
state = initstate(domain, problem)

# Construct gridworld renderer
gem_colors = PDDLViz.colorschemes[:vibrant]
renderer = PDDLViz.GridworldRenderer(
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
canvas = renderer(domain, state)

# Render plan
plan = @pddl("(right)", "(right)", "(right)", "(up)", "(up)")
renderer(canvas, domain, state, plan)

# Render trajectory
trajectory = PDDL.simulate(domain, state, plan)
canvas = renderer(domain, trajectory)

# Render path search solution
planner = AStarPlanner(GoalCountHeuristic(), save_search=true,
                       save_search_order=true, max_nodes=20)
spec = Specification(problem)
sol = planner(domain, state, spec)
canvas = renderer(domain, state, sol)

# Render policy solution
heuristic = PlannerHeuristic(AStarPlanner(GoalCountHeuristic(), max_nodes=20))
planner = RTDP(heuristic=heuristic, n_rollouts=5, max_depth=20)
policy = planner(domain, state, pddl"(has gem1)")
canvas = renderer(domain, state, policy)

# Animate plan
plan = collect(sol)
anim = anim_plan(renderer, domain, state, plan)
save("doors_keys_gems.mp4", anim)

# Add controller
canvas = renderer(domain, state)
controller = KeyboardController(
    Keyboard.up => pddl"(up)",
    Keyboard.down => pddl"(down)",
    Keyboard.left => pddl"(left)",
    Keyboard.right => pddl"(right)",
    Keyboard.z, Keyboard.x, Keyboard.c, Keyboard.v
)
add_controller!(canvas, controller, domain, state; show_controls=true)
remove_controller!(canvas, controller)
