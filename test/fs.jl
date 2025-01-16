@testset "Balanced fault study" begin
    @testset "5-bus fault example" begin
        data = parse_file("../test/data/trans/case5_fault.m"; flat_start=true, neglect_line_charging=true, neglect_transformer=true, zero_gen_setpoints=true)

        add_fault!(data, 1, 2, 0.0001)

        result = solve_fault_study(data, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED

        bus = result["solution"]["bus"]["1"]
        @test isapprox(abs(bus["vr"] + 1im * bus["vi"]), 0.0610503; atol=1e-3)

        bus = result["solution"]["bus"]["3"]
        @test isapprox(abs(bus["vr"] + 1im * bus["vi"]), 0.0279175; atol=1e-3)

        bus = result["solution"]["bus"]["4"]
        @test isapprox(abs(bus["vr"] + 1im * bus["vi"]), 0.0529499; atol=1e-3)

        bus = result["solution"]["bus"]["10"]
        @test isapprox(abs(bus["vr"] + 1im * bus["vi"]), 0.0645659; atol=1e-3)
    end

    @testset "3-bus fault example with inverter" begin
        data = parse_file("../test/data/trans/case3_fault_inverter.m"; flat_start=true, neglect_line_charging=true)

        add_fault!(data, 1, 2, 0.0001)

        result = solve_fault_study(data, ipopt_solver)

        @test result["termination_status"] == LOCALLY_SOLVED

        @test isapprox(result["objective"], -2.657226; atol=2)

        bus = result["solution"]["bus"]["2"]
        @test isapprox(abs(bus["vr"] + 1im * bus["vi"]), 0.000444; atol=1e-3)

        bus = result["solution"]["bus"]["3"]
        @test isapprox(abs(bus["vr"] + 1im * bus["vi"]), 0.045139; atol=1e-2)

        bus = result["solution"]["bus"]["4"]
        @test isapprox(abs(bus["vr"] + 1im * bus["vi"]), 0.196538; atol=1e-3)

        gen = result["solution"]["gen"]["1"]
        @test isapprox(abs(gen["crg"] + 1im * gen["cig"]), 2.406009; atol=5e-1)
        @test isapprox(angle(gen["pg"] + 1im * gen["qg"]), 3.141592; atol=4)
    end
end
