export Controller, KeyboardController
export add_controller!, remove_controller!, render_controls!
export ControlRecorder

import Makie: ObserverFunction

"""
    Controller

Abstract supertype for all controllers. When attached to a canvas, a controller
interprets user input as PDDL actions and updates the canvas accordingly.
    
Can be attached to a canvas using [`add_controller!`](@ref), and removed using
[`remove_controller`](@ref).
"""
abstract type Controller end

"""
    add_controller!(canvas, controller, domain, [init_state];
                    show_controls::Bool=false)

Adds a `controller` to a `canvas` for a given PDDL `domain`. An initial state
`init_state` can be specified to enable restart functionality.
"""
function add_controller!(canvas::Canvas, controller::Controller, 
                         domain::Domain, init_state=nothing;
                         show_controls::Bool=false)
    error("Not implemented.")
end

"""
    remove_controller!(canvas, controller)

Removes a `controller` from a `canvas`.
"""
remove_controller!(canvas::Canvas, controller::Controller) =
    error("Not implemented.")

"""
    render_controls!(canvas, controller, domain)

Renders controls for a `controller` to a `canvas`.
"""
render_controls!(canvas::Canvas, controller::Controller, domain::Domain) =
    nothing

"""
    KeyboardController(options...)
    KeyboardController(
        key1 => act1, key2 => act2, ...,
        extra_key1, extra_key2, ...;
        exclusive=true, callback=nothing
    )

A controller that maps keyboard input to PDDL actions. Set `callback` to a
[`ControlRecorder`](@ref) to record actions.

# Options

$(FIELDS)
"""
@kwdef struct KeyboardController{T,U} <: Controller
    "A dictionary mapping keyboard keys to PDDL actions."
    keymap::OrderedDict{Keyboard.Button, Term} = OrderedDict{Keyboard.Button, Term}()
    "Keys mapped to remaining available actions (default: number keys)."
    extrakeys::Vector{Keyboard.Button} = Keyboard.Button.(collect(49:57))
    "Function `(state, acts) -> acts` that filters/processes remaining actions."
    extraprocess::T = nothing
    "Restart button if an initial state is specified."
    restart_key::Keyboard.Button = Keyboard.backspace
    "Whether an action is executed only if no other keys are pressed."
    exclusive::Bool = true
    "Post-action callback `f(canvas, domain, state, act, next_state)`."
    callback::U = nothing
    obsfunc::Ref{ObserverFunction} = Ref{ObserverFunction}()
end

function KeyboardController(
    args::Union{Pair{Keyboard.Button, <:Term}, Keyboard.Button}...;
    kwargs...
)
    keymap = OrderedDict{Keyboard.Button, Term}()
    extrakeys = Keyboard.Button[]
    for arg in args
        if arg isa Pair{Keyboard.Button, <:Term}
            keymap[arg[1]] = arg[2]
        else
            push!(extrakeys, arg)
        end
    end
    if isempty(extrakeys)
        return KeyboardController(;keymap=keymap, kwargs...)
    else
        return KeyboardController(;keymap=keymap, extrakeys=extrakeys, kwargs...)
    end
end

function add_controller!(
    canvas::Canvas, controller::KeyboardController,
    domain::Domain, init_state=nothing;
    show_controls::Bool=false
)
    controller.obsfunc[] = on(events(canvas.figure).keyboardbutton) do event
        figure, callback = canvas.figure, controller.callback
        # Skip if no keys are pressed
        event.action == Keyboard.press || return
        # Skip if window not in focus
        events(figure).hasfocus[] || return
        # Check if restart button is pressed
        if init_state !== nothing && ispressed(figure, Keyboard.backspace)
            canvas.state[] = init_state
            if callback !== nothing
                callback(canvas, domain, nothing, nothing, init_state)
            end
            return
        end
        # Get currently available actions
        state = canvas.state[]
        actions = collect(available(domain, state))
        # Check if pressed key is in main keymap
        for (key, act) in controller.keymap
            key = controller.exclusive ? Exclusively(key) : key
            # Execute corresponding action if it is available
            if ispressed(figure, key) && act in actions
                next_state = transition(domain, state, act; check=false)
                canvas.state[] = next_state
                if callback !== nothing
                    callback(canvas, domain, state, act, next_state)
                end
                return
            end
        end
        # Filter and sort remaining available actions
        actions = filter!(a -> !(a in values(controller.keymap)), actions)
        if !isnothing(controller.extraprocess)
            actions = controller.extraprocess(state, actions)
        else
            sort!(actions, by=string)
        end
        # Take first action that matches an extra key
        for (i, key) in enumerate(controller.extrakeys)
            key = controller.exclusive ? Exclusively(key) : key
            if ispressed(figure, key) && i <= length(actions)
                act = actions[i]
                next_state = transition(domain, state, act; check=false)
                canvas.state[] = next_state
                if callback !== nothing
                    callback(canvas, domain, state, act, next_state)
                end
                return
            end
        end
    end
    if show_controls
        render_controls!(canvas, controller, domain)
    end
    return nothing
end

function remove_controller!(canvas::Canvas, controller::KeyboardController)
    off(controller.obsfunc[])
end

function render_controls!(
    canvas::Canvas, controller::KeyboardController, domain::Domain
)
    # Construct control legend
    figure = canvas.figure
    buttons = collect(keys(controller.keymap))
    labels = [write_pddl(controller.keymap[b]) for b in buttons]
    n_fixed = length(buttons)
    append!(buttons, controller.extrakeys)
    append!(labels, fill(' '^40, length(controller.extrakeys)))
    markers = _keyboard_button_marker.(buttons)
    entries = [LegendEntry(m, Attributes(label=l, labelcolor=:black))
               for (l, m) in zip(labels, markers)]
    entrygroups = Observable(Makie.EntryGroup[("Controls", entries)])
    controls = nothing
    try
        controls = Legend(figure[1, end+1], entrygroups;
                        framevisible=false, labelsize=14,
                        halign=:left, titlehalign=:left)
    catch
        controls = Legend(figure[1, end+1]; entrygroups=entrygroups,
                        framevisible=false, labelsize=14,
                        halign=:left, titlehalign=:left)
    end
    resize_to_layout!(figure)
    # Extract observables from entries
    label_obs = Observable[]
    lcolor_obs = Observable[]
    mcolor_obs = Observable[]
    scolor_obs = Observable[]
    for entry in controls.entrygroups[][1][2]
        push!(label_obs, entry.attributes.label)
        push!(lcolor_obs, entry.attributes.labelcolor)
        push!(mcolor_obs, entry.elements[2].attributes.markercolor)
        push!(scolor_obs, entry.elements[1].attributes.markerstrokecolor)
    end
    # Set up observer function
    on(canvas.state, update=true) do state
        # Recolor actions that are not available
        actions = collect(available(domain, state))
        for (i, key) in enumerate(buttons[1:n_fixed])
            act = controller.keymap[key]
            if act in actions
                lcolor_obs[i][] = :black
                mcolor_obs[i][] = :black
                scolor_obs[i][] = :black
            else
                lcolor_obs[i][] = :gray
                mcolor_obs[i][] = :gray
                scolor_obs[i][] = :gray
            end
        end
        # Filter and sort remaining available actions
        actions = filter!(a -> !(a in values(controller.keymap)), actions)
        if !isnothing(controller.extraprocess)
            actions = controller.extraprocess(state, actions)
        else
            sort!(actions, by=string)
        end
        for (i, key) in enumerate(controller.extrakeys)
            if i <= length(actions)
                act = actions[i]
                label_obs[n_fixed+i][] = write_pddl(act)
                mcolor_obs[n_fixed+i][] = :black
                scolor_obs[n_fixed+i][] = :black
            else
                label_obs[n_fixed+i][] = ' '^40
                mcolor_obs[n_fixed+i][] = :gray
                scolor_obs[n_fixed+i][] = :gray
            end
        end
    end
    return controls
end

function _keyboard_button_marker(button::Keyboard.Button)
    button_id = Int(button)
    if button_id > 32 && button_id < 127
        char = Char(button_id)
    elseif button == Keyboard.space
        char = '␣'
    elseif button == Keyboard.backspace
        char = '⌫'
    elseif button == Keyboard.enter
        char = '⏎'
    elseif button == Keyboard.tab
        char = '⇥'
    elseif button == Keyboard.up
        char = '↑'
    elseif button == Keyboard.down
        char = '↓'
    elseif button == Keyboard.left
        char = '←'
    elseif button == Keyboard.right
        char = '→'
    else
        char = '⍰' 
    end
    key = MarkerElement(marker=char, markersize=15, markercolor=:black)
    box = MarkerElement(marker=:rect, markersize=30, color=(:white, 0.0),
                        strokewidth=1, strokecolor=:black)
    return [box, key]
end


"""
    ControlRecorder(record_actions = true, record_states = false)

Callback function for a [`Controller`](@ref) that records actions and states.
After constructing a `recorder`, the recorded values can be accessed via
`recorder.actions` and `recorder.states`.
"""
struct ControlRecorder <: Function
    record_actions::Bool
    record_states::Bool
    actions::Vector{Term}
    states::Vector{State}
end 

function ControlRecorder(record_actions::Bool=true, record_states::Bool=false)
    return ControlRecorder(record_actions, record_states, Term[], State[])
end

function (cb::ControlRecorder)(canvas, domain, state, act, next_state)
    act = isnothing(act) ? PDDL.no_op : act
    cb.record_actions && push!(cb.actions, act)
    cb.record_states && push!(cb.states, next_state)
    return nothing
end
