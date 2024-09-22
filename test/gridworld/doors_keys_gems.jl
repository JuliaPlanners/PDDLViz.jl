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
renderer = GridworldRenderer(
    resolution = (600, 700),
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
astar = AStarPlanner(GoalCountHeuristic(), save_search=true,
                     save_search_order=true, max_nodes=100)
sol = astar(domain, state, pddl"(has gem2)")
canvas = renderer(domain, state, sol, show_search=true)

# Render policy solution
heuristic = PlannerHeuristic(AStarPlanner(GoalCountHeuristic(), max_nodes=20))
rtdp = RTDP(heuristic=heuristic, n_rollouts=5, max_depth=20)
policy = rtdp(domain, state, pddl"(has gem1)")
canvas = renderer(domain, state, policy)

# Render reusable tree policy
heuristic = GoalCountHeuristic()
rths = RTHS(heuristic=heuristic, n_iters=1, max_nodes=20)
policy = rths(domain, state, pddl"(has gem1)")
canvas = renderer(domain, state, policy, show_goal_tree=false)
new_state = copy(state)
new_state[pddl"(xpos)"] = 4
new_state[pddl"(ypos)"] = 4
policy = refine!(policy, rths, domain, new_state, pddl"(has gem1)")
canvas = renderer(domain, new_state, policy, show_goal_tree=true)

# Render multi-solution
rths_bfs = RTHS(GoalCountHeuristic(), h_mult=0.0, max_nodes=10)
rths_astar = RTHS(GoalCountHeuristic(), h_mult=1.0, max_nodes=20)
arths = AlternatingRTHS(rths_bfs, rths_astar)
new_state = copy(state)
new_state[pddl"(xpos)"] = 4
new_state[pddl"(ypos)"] = 4
policy = arths(domain, new_state, pddl"(has gem1)")
canvas = renderer(domain, new_state, policy, show_goal_tree=false)

# Animate plan
plan = collect(sol)
anim = anim_plan(renderer, domain, state, plan; trail_length=10)
save("doors_keys_gems.mp4", anim)

# Animate path search planning
canvas = renderer(domain, state)
sol_anim, sol = anim_solve!(canvas, renderer, astar,
                            domain, state, pddl"(has gem1)")
save("doors_keys_gems_astar.mp4", sol_anim)

# Animate RTDP planning
canvas = renderer(domain, state)
sol_anim, sol = anim_solve!(canvas, renderer, rtdp,
                            domain, state, pddl"(has gem2)")
save("doors_keys_gems_rtdp.mp4", sol_anim)

# Animate RTHS planning
rths = RTHS(GoalCountHeuristic(), n_iters=5, max_nodes=15, reuse_paths=false)
canvas = renderer(domain, state)
sol_anim, sol = anim_solve!(canvas, renderer, rths,
                            domain, state, pddl"(has gem1)")
save("doors_keys_gems_rths.mp4", sol_anim)

# Convert animation frames to storyboard
storyboard = render_storyboard(
    anim, [1, 14, 17, 24], figscale=0.75,
    xlabels=["t=1", "t=14", "t=17", "t=24"],
    subtitles=["(i) Initial state", "(ii) Agent picks up key",
               "(iii) Agent unlocks door", "(iv) Agent picks up gem"],
    xlabelsize=18, subtitlesize=22
)

# Construct multiple canvases on the same figure
figure = Figure()
resize!(figure, 1200, 700)
canvas1 = new_canvas(renderer, figure[1, 1])
canvas2 = new_canvas(renderer, figure[1, 2])
renderer(canvas1, domain, state)
renderer(canvas2, domain, state, plan)

# Add controller
canvas = renderer(domain, state)
recorder = ControlRecorder()
controller = KeyboardController(
    Keyboard.up => pddl"(up)",
    Keyboard.down => pddl"(down)",
    Keyboard.left => pddl"(left)",
    Keyboard.right => pddl"(right)",
    Keyboard.z, Keyboard.x, Keyboard.c, Keyboard.v;
    callback = recorder
)
add_controller!(canvas, controller, domain, state; show_controls=true)
remove_controller!(canvas, controller)
