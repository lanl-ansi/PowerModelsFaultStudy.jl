include("../src/PowerModelsProtection.jl")
const FS = PowerModelsProtection

import Memento

import PowerModels
import PowerModelsDistribution

const PMD = PowerModelsDistribution
const PM = PowerModels

# Suppress warnings during testing.
const TESTLOG = Memento.getlogger(PowerModels)
Memento.setlevel!(TESTLOG, "error")

import JuMP
import Ipopt

import JSON

using Test
using LinearAlgebra

const MOI = JuMP.MOI

ipopt_solver = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-6, print_level=0)
ipopt_solver_fine = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-9, print_level=0)
ipopt_solver_it_cor = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-6, print_level=0, max_iter=50000)
ipopt_solver_it = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-9, print_level=0, max_iter=50000)


include("common.jl")
error = 0.05

@testset "test iee123 fault base case" begin
    ieee123 = FS.parse_file("../test/data/dist/ieee123/IEEE123Master_no_regs_no_sw.dss")
    data = deepcopy(ieee123)
    data["fault"] = Dict{String,Any}()
    data["fault"]["1"] = Dict("type" => "3p", "bus" => "13", "phases" => [1, 2, 3], "gr" => 0.005)
    data["fault"]["2"] = Dict("type" => "ll", "bus" => "13", "phases" => [1, 2], "gr" => 0.005)
    data["fault"]["3"] = Dict("type" => "lg", "bus" => "13", "phases" => [1], "gr" => 0.005)
    sol = FS.run_mc_fault_study(data, ipopt_solver)
    @testset "faults on bus 13 base" begin
        @test sol["13"]["3p"]["1"]["termination_status"] == LOCALLY_SOLVED
        println("Bus: 13 Fault: 3p ---- ", sol["13"]["3p"]["1"]["solution"]["fault"]["bus"]["current"][1])
        @test calculate_error_percentage(sol["13"]["3p"]["1"]["solution"]["fault"]["bus"]["current"][1], 5305.0) < error # opendss
        @test calculate_error_percentage(sol["13"]["3p"]["1"]["solution"]["fault"]["bus"]["current"][2], 5509.0) < error # opendss
        @test calculate_error_percentage(sol["13"]["3p"]["1"]["solution"]["fault"]["bus"]["current"][3], 5254.0) < error # opendss
        @test calculate_error_percentage(sol["13"]["3p"]["1"]["solution"]["fault"]["bus"]["current"][1], 5435.3) < error # kersting
        @test calculate_error_percentage(sol["13"]["3p"]["1"]["solution"]["fault"]["bus"]["current"][2], 5655.7) < error # kersting
        @test calculate_error_percentage(sol["13"]["3p"]["1"]["solution"]["fault"]["bus"]["current"][3], 5306.6) < error # kersting
        @test sol["13"]["ll"]["1"]["termination_status"] == LOCALLY_SOLVED
        println("Bus: 13 Fault: ll ---- ", sol["13"]["ll"]["1"]["solution"]["fault"]["bus"]["current"][1])
        @test calculate_error_percentage(sol["13"]["ll"]["1"]["solution"]["fault"]["bus"]["current"][1], 4736.0) < error # opendss
        @test calculate_error_percentage(sol["13"]["ll"]["1"]["solution"]["fault"]["bus"]["current"][1], 4886.6) < error # kersting
        @test sol["13"]["lg"]["1"]["termination_status"] == LOCALLY_SOLVED
        println("Bus: 13 Fault: lg ---- ", sol["13"]["lg"]["1"]["solution"]["fault"]["bus"]["current"][1])
        @test calculate_error_percentage(sol["13"]["lg"]["1"]["solution"]["fault"]["bus"]["current"][1], 4422.0) < error # opendss
        @test calculate_error_percentage(sol["13"]["lg"]["1"]["solution"]["fault"]["bus"]["current"][1], 4400.1) < error # kersting
    end
    data = deepcopy(ieee123)
    data["fault"] = Dict{String,Any}()
    data["fault"]["1"] = Dict("type" => "3p", "bus" => "67", "phases" => [1, 2, 3], "gr" => 0.005)
    data["fault"]["2"] = Dict("type" => "ll", "bus" => "67", "phases" => [1, 2], "gr" => 0.005)
    data["fault"]["3"] = Dict("type" => "lg", "bus" => "67", "phases" => [1], "gr" => 0.005)
    sol = FS.run_mc_fault_study(data, ipopt_solver)
    @testset "faults on bus 67 base" begin
        @test sol["67"]["3p"]["1"]["termination_status"] == LOCALLY_SOLVED
        println("Bus: 67 Fault: 3p ---- ", sol["67"]["3p"]["1"]["solution"]["fault"]["bus"]["current"][1])
        @test calculate_error_percentage(sol["67"]["3p"]["1"]["solution"]["fault"]["bus"]["current"][1], 3251.0) < error # opendss
        @test calculate_error_percentage(sol["67"]["3p"]["1"]["solution"]["fault"]["bus"]["current"][2], 3401.0) < error # opendss
        @test calculate_error_percentage(sol["67"]["3p"]["1"]["solution"]["fault"]["bus"]["current"][3], 3342.0) < error # opendss
        @test calculate_error_percentage(sol["67"]["3p"]["1"]["solution"]["fault"]["bus"]["current"][1], 3236.6) < error # kersting
        @test calculate_error_percentage(sol["67"]["3p"]["1"]["solution"]["fault"]["bus"]["current"][2], 3383.5) < error # kersting
        @test calculate_error_percentage(sol["67"]["3p"]["1"]["solution"]["fault"]["bus"]["current"][3], 3299.3) < error # kersting
        @test sol["67"]["ll"]["1"]["termination_status"] == LOCALLY_SOLVED
        println("Bus: 67 Fault: ll ---- ", sol["67"]["ll"]["1"]["solution"]["fault"]["bus"]["current"][1])
        @test calculate_error_percentage(sol["67"]["ll"]["1"]["solution"]["fault"]["bus"]["current"][1], 2879.0) < error # opendss
        @test calculate_error_percentage(sol["67"]["ll"]["1"]["solution"]["fault"]["bus"]["current"][1], 2890.0) < error # kersting
        @test sol["67"]["lg"]["1"]["termination_status"] == LOCALLY_SOLVED
        println("Bus: 67 Fault: lg ---- ", sol["67"]["lg"]["1"]["solution"]["fault"]["bus"]["current"][1])
        @test calculate_error_percentage(sol["67"]["lg"]["1"]["solution"]["fault"]["bus"]["current"][1], 2392.0) < error # opendss
        @test calculate_error_percentage(sol["67"]["lg"]["1"]["solution"]["fault"]["bus"]["current"][1], 2339.5) < error # kersting
    end
    data = deepcopy(ieee123)
    data["fault"] = Dict{String,Any}()
    data["fault"]["1"] = Dict("type" => "lg", "bus" => "113", "phases" => [1], "gr" => 0.005)
    sol = FS.run_mc_fault_study(data, ipopt_solver)
    @testset "faults on bus 113 base" begin
        @test sol["113"]["lg"]["1"]["termination_status"] == LOCALLY_SOLVED
        println("Bus: 113 Fault: lg ---- ", sol["113"]["lg"]["1"]["solution"]["fault"]["bus"]["current"][1])
        @test calculate_error_percentage(sol["113"]["lg"]["1"]["solution"]["fault"]["bus"]["current"][1], 1390.0) < error # opendss
        @test calculate_error_percentage(sol["113"]["lg"]["1"]["solution"]["fault"]["bus"]["current"][1], 1382.6) < error # kersting
    end
end
