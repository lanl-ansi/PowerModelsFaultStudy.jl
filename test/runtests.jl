using PowerModelsProtection

import PowerModels
import PowerModelsDistribution

import Ipopt

const PMD = PowerModelsDistribution
const PM = PowerModels

PowerModels.silence()
PowerModelsDistribution.silence!()

ipopt_solver = optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-6, "print_level"=>0)

using Test

include("common.jl")
include("test_cases.jl")

@testset "PowerModelsProtection" begin
    include("admittance.jl")
    include("pf_mc.jl")
    # include("fs.jl")
    # include("fs_mc.jl")
    # include("pf_mc.jl")
    # include("protection_tests.jl")
    # include("sparse_fault.jl")
end
