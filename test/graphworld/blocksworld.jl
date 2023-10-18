using PDDLViz, GLMakie, GraphMakie
using PDDL, SymbolicPlanners, PlanningDomains

# Load blocksworld domain and problem
domain = load_domain(:blocksworld)
problem = load_problem(:blocksworld, 5)

# Construct initial state from domain and problem
state = initstate(domain, problem)

# Construct graphworld renderer
cmap = Makie.colorschemes[:plasma][1:8:256]
renderer = PDDLViz.GraphworldRenderer(
    graph_layout = n_locs -> PDDLViz.BlocksworldLayout(n_locs=n_locs),
    is_loc_directed = true,
    is_mov_directed = true,
    has_mov_edges = true,
    locations = [pddl"(table)", pddl"(gripper)"],
    location_types = [:block],
    movable_types = [:block],
    loc_edge_fn = (d, s, a, b) -> false,
    mov_loc_edge_fn = (d, s, x, loc) -> begin
        if x == loc
            s[Compound(:ontable, [x])]
        elseif loc.name == :gripper
            s[Compound(:holding, [x])]
        else
            false
        end
    end,
    mov_edge_fn = (d, s, x, y) -> s[Compound(:on, [x, y])],
    loc_renderers = Dict{Const, Function}(
        pddl"(table)" => (d, s, loc) -> begin
            n_blocks = length(PDDL.get_objects(s, :block))
            width = 1.5 * n_blocks
            PDDLViz.RectShape(
                0.0, 0.0, width, 1.0,
                color = :grey60, strokewidth=2.0
            ) 
        end,
    ),
    mov_type_renderers = Dict{Symbol, Function}(
        :block => (d, s, o) -> MultiGraphic(
            PDDLViz.SquareShape(
                0.0, 0.0, 1.0,
                color=cmap[mod(hash(o.name), length(cmap))+1],
                strokewidth=2.0
            ),
            TextGraphic(
                string(o.name), 0, 0, 3/4*length(string(o.name)),
                font=:bold, color=:white, strokecolor=:black, strokewidth=1.0
            )
        )
    ),
    axis_options = Dict{Symbol, Any}(
        :aspect => DataAspect(),
        # :autolimitaspect => 1,
        :xautolimitmargin => (0.0, 0.0),
        # :yautolimitmargin => (0.0, 0.0),
        :limits => (0.0, nothing, 0.0, nothing),
        :hidedecorations => true
    ),
    state_options = Dict{Symbol, Any}(
        :show_location_labels => false,
        :show_movable_labels => false,
        :show_edge_labels => false,
        :show_location_graphics => true,
        :show_movable_graphics => true
    ),
    graph_options = Dict{Symbol, Any}(
        :node_size => 0.0,
        :node_attr => (markerspace=:data,),
        :nlabels_fontsize => 20,
        :nlabels_align => (:center, :center),
        :elabels_fontsize => 16,
    )
)

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
anim = anim_plan!(canvas, renderer, domain, state, plan, framerate=2)
save("blocksworld.mp4", anim)
