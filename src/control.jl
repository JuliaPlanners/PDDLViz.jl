export Controller, KeyboardController
export add_controller!, remove_controller!

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
    add_controller!(canvas, controller, domain, [init_state])

Adds a `controller` to a `canvas` for a given PDDL `domain`. An initial state
`init_state` can be specified to enable restart functionality.
"""
function add_controller!(canvas::Canvas, controller::Controller, 
                         domain::Domain, init_state=nothing)
    error("Not implemented.")
end

"""
    remove_controller!(canvas, controller)

Removes a `controller` from a `canvas`.
"""
remove_controller!(canvas::Canvas, controller::Controller) =
    error("Not implemented.")

"""
    KeyboardController(options...)
    KeyboardController(
        key1 => act1, key2 => act2, ...,
        extra_key1, extra_key2, ...;
        exclusive=true, callback=nothing
    )

A controller that maps keyboard input to PDDL actions.

# Options

$(FIELDS)
"""
@kwdef struct KeyboardController{T,U} <: Controller
    "A dictionary mapping keyboard keys to PDDL actions."
    keymap::Dict{Keyboard.Button, Term} = Dict{Mouse.Button, Term}()
    "Keys mapped to remaining available actions (default: number keys)."
    extrakeys::Vector{Keyboard.Button} = Keyboard.Button.(collect(49:57))
    "Function `(state, acts) -> acts` that filters/processes remaining actions."
    extraprocess::T = _default_extraprocess
    "Restart button if an initial state is specified."
    restart_key::Keyboard.Button = Keyboard.backspace
    "Whether an action is executed only if no other keys are pressed."
    exclusive::Bool = true
    "Post-action callback `f(canvas, domain, state, act, next_state)`."
    callback::U = nothing
    obsfunc::Ref{ObserverFunction} = Ref{ObserverFunction}()
end

function KeyboardController(
    args::Union{Pair{Keyboard.Button, <:Term}, Keyboard.Button}...; kwargs...
) where {T}
    keymap = Dict{Keyboard.Button, Term}()
    extrakeys = Keyboard.Button[]
    for arg in args
        if arg isa Pair{Keyboard.Button, <:Term}
            keymap[arg[1]] = arg[2]
        else
            push!(extrakeys, arg)
        end
    end
    if isempty(extrakeys)
        return KeyboardController(keymap=keymap, kwargs...)
    else
        return KeyboardController(keymap=keymap, extrakeys=extrakeys, kwargs...)
    end
end

function add_controller!(
    canvas::Canvas, controller::KeyboardController,
    domain::Domain, init_state=nothing
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
        actions = controller.extraprocess(state, actions)
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
end

function remove_controller!(canvas::Canvas, controller::KeyboardController)
    off(controller.obsfunc[])
end

_default_extraprocess(state, acts) = sort!(acts, by=string)
