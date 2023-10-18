using PDDLViz, GLMakie, GraphMakie
using PDDL, SymbolicPlanners, PlanningDomains

# Load blocksworld domain and problem
domain = load_domain(:blocksworld)
problem = load_problem(:blocksworld, 5)

# Construct initial state from domain and problem
state = initstate(domain, problem)

# Construct blocksworld renderer
renderer = BlocksworldRenderer()

# Render initial state
canvas = renderer(domain, state)

# Render animation
plan = @pddl(
    "(unstack f e)", "(put-down f)",
    "(unstack e b)", "(put-down e)",
    "(unstack d a)", "(stack d e)",
    "(unstack a c)", "(stack a f)",
    "(pick-up c)", "(stack c d)",
    "(pick-up b)", "(stack b c)",
    "(unstack a f)", "(stack a b)"
)
anim = anim_plan!(canvas, renderer, domain, state, plan, framerate=2);
save("blocksworld.mp4", anim)
