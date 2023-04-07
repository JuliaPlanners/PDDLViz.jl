# Test gridworld rendering
using PDDLViz, GLMakie, GraphMakie
using PDDL, SymbolicPlanners, PlanningDomains

# Load example graph-based domain and problem
domain = load_domain(:zeno_travel)
problem = load_problem(:zeno_travel, 3)

# Construct initial state from domain and problem
state = initstate(domain, problem)

# Construct graphworld renderer
cmap = PDDLViz.colorschemes[:vibrant]
renderer = PDDLViz.GraphworldRenderer(
    graph_layout=GraphMakie.NetworkLayout.Stress(),
    location_types = [:city],
    movable_types = [:movable],
    edge_fn = (d, s, a, b) -> a != b,
    edge_label_fn = (d, s, a, b) -> string(s[Compound(:distance, [a, b])]),
    at_loc_fn = (d, s, x, loc) -> s[Compound(:at, [x, loc])],
    loc_renderers = Dict{Symbol, Function}(
        :city => (d, s, loc) -> CityGraphic(
            0, 0, 0.25, color=cmap[parse(Int, string(loc.name)[end])+1]
        )
    ),
    obj_renderers = Dict{Symbol, Function}(
        :person => (d, s, o) -> HumanGraphic(
            0, 0, 0.15, color=cmap[parse(Int, string(o.name)[end])]
        ),
        :aircraft => (d, s, o) -> MultiGraphic(
            MarkerGraphic(
                '✈', 0, 0, 0.2, color=cmap[parse(Int, string(o.name)[end])]
            ),
            HumanGraphic(
                0, 0, 0.1, color=:black,
                visible=satisfy(d, s, Compound(:in, [Var(:X), o]))
            )
        ),
    ),
    state_options = Dict{Symbol, Any}(
        :show_location_labels => true,
        :show_movable_labels => true,
        :show_edge_labels => true,
        :show_location_graphics => true,
        :show_movable_graphics => true,
        :label_offset_mult => 0.25,
        :movable_node_color => (:black, 0.0),
    ),
    graph_options = Dict{Symbol, Any}(
        :node_size => 0.03,
        :node_attr => (markerspace=:data,),
        :nlabels_fontsize => 20,
        :nlabels_align => (:center, :center),
        :elabels_fontsize => 16,
    )
)

# Render initial state
canvas = renderer(domain, state)

# Render animation
plan = @pddl("(refuel plane1)", "(fly plane1 city0 city2)", 
             "(board person1 plane1 city2)", "(fly plane1 city2 city1)",
             "(debark person1 plane1 city1)", "(fly plane1 city1 city2)")
renderer.state_options[:show_edge_labels] = false
anim = anim_plan("zeno_travel.mp4", renderer, domain, state, plan, framerate=1)
