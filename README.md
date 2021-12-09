# RenderPDDL.jl

A framework for rendering and animating PDDL domains.

## Installation

First, clone this repository for local development:

```
git clone https://github.com/JuliaPlanners/RenderPDDL.jl.git # HTTPS
git clone git@github.com:JuliaPlanners/RenderPDDL.jl.git # SSH
```

Then start Julia in the `RenderPDDL.jl` directory and press `]` to enter the
REPL for Julia's package manager. Activate the local package environment,
install `PDDL.jl` as as dependency, and `instantiate` all other dependencies:

```
activate .
add https://github.com/JuliaPlanners/PDDL.jl
instantiate
```
