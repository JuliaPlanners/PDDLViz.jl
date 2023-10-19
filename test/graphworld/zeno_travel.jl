using PDDLViz, GLMakie, GraphMakie
using PDDL, SymbolicPlanners, PlanningDomains

# Load example graph-based domain and problem
domain = load_domain(:zeno_travel)
problem = load_problem(:zeno_travel, 3)

# Construct initial state from domain and problem
state = initstate(domain, problem)

# Construct graphworld renderer
cmap = PDDLViz.colorschemes[:vibrant]
renderer = GraphworldRenderer(
    has_mov_edges = true,
    location_types = [:city],
    movable_types = [:movable],
    loc_edge_fn = (d, s, a, b) -> a != b,
    loc_edge_label_fn = (d, s, a, b) -> string(s[Compound(:distance, [a, b])]),
    mov_loc_edge_fn = (d, s, x, loc) -> s[Compound(:at, [x, loc])],
    mov_edge_fn = (d, s, x, y) -> begin
        terms = [Compound(:person, Term[x]), Compound(:aircraft, Term[y]),
                 Compound(:in, Term[x, y])]
        return satisfy(d, s, terms)
    end,
    loc_type_renderers = Dict{Symbol, Function}(
        :city => (d, s, loc) -> CityGraphic(
            0, 0, 0.25, color=cmap[parse(Int, string(loc.name)[end])+1]
        )
    ),
    mov_type_renderers = Dict{Symbol, Function}(
        :person => (d, s, o) -> HumanGraphic(
            0, 0, 0.15, color=cmap[parse(Int, string(o.name)[end])]
        ),
        :aircraft => (d, s, o) -> MarkerGraphic(
            '✈', 0, 0, 0.2, color=cmap[parse(Int, string(o.name)[end])]
        )
    ),
    state_options = Dict{Symbol, Any}(
        :show_location_labels => true,
        :show_movable_labels => true,
        :show_edge_labels => true,
        :show_location_graphics => true,
        :show_movable_graphics => true,
        :label_offset => 0.15,
        :movable_node_color => (:black, 0.0),
    ),
    axis_options = Dict{Symbol, Any}(
        :aspect => 1,
        :autolimitaspect => 1,
        :xautolimitmargin => (0.2, 0.2),
        :yautolimitmargin => (0.2, 0.2),
        :hidedecorations => true
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
anim = anim_plan!(canvas, renderer, domain, state, plan, framerate=1)
save("zeno_travel.mp4", anim)

# Convert animation frames to storyboard
storyboard = render_storyboard(
    anim, [1, 3, 4, 5, 6, 7], figscale=0.65, n_rows=2,
    xlabels=["t=1", "t=3", "t=4", "t=5", "t=6", "t=7"],
    subtitles=["(i) Initial state", "(ii) Plane flies to city 2",
               "(iii) Person 1 boards plane", "(iv) Plane flies to city 1",
               "(v) Person 1 debarks plane", "(vi) Plane flies back to city 2"],
    xlabelsize=18, subtitlesize=22
)

# Render animation with linearly interpolated transitions
canvas = renderer(domain, state)
anim = anim_plan!(canvas, renderer, domain, state, plan,
                  transition=PDDLViz.LinearTransition(), 
                  framerate=30, frames_per_step=30)
save("zeno_travel_smooth.mp4", anim)
