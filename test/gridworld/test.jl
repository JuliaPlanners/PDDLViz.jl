# Test gridworld rendering
using RenderPDDL, PDDL, Test

# Load example gridworld domain and problem
path = joinpath(dirname(pathof(RenderPDDL)), "..", "test", "gridworld")
domain = load_domain(joinpath(path, "domain.pddl"))
problem = load_problem(joinpath(path, "problem.pddl"))

# Load array extension to PDDL
PDDL.Arrays.register!()

# Construct initial state from domain and problem
state = initstate(domain, problem)

# Construct gridworld renderer
renderer = RenderPDDL.GridworldRenderer()

# Render initial state
canvas = render(renderer, domain, state)
