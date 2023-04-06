# Test gridworld rendering
using PDDLViz, GLMakie
using PDDL, SymbolicPlanners, PlanningDomains

# Load example graph-based domain and problem
domain = load_domain(:zeno_travel)
problem = load_problem(:zeno_travel, 3)

# Construct initial state from domain and problem
state = initstate(domain, problem)

# Construct graphworld renderer
renderer = PDDLViz.GraphworldRenderer(
    graph_layout=GraphMakie.NetworkLayout.Stress(),
    location_types = [:city],
    movable_types = [:movable],
    edge_fn = (d, s, a, b) -> a != b,
    edge_label_fn = (d, s, a, b) -> string(s[Compound(:distance, [a, b])]),
    at_loc_fn = (d, s, x, loc) -> s[Compound(:at, [x, loc])]
)

# Render initial state
canvas = renderer(domain, state)
