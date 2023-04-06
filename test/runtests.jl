using Test

@testset "GridworldRenderer" begin
    include("gridworld/test.jl")
end

@testset "GraphworldRenderer" begin
    include("graphworld/test.jl")
end