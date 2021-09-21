@testset "test pf" begin
    ut_trans_2w_yy = parse_file("../test/data/dist/ut_trans_2w_yy.dss")
    case3_unbalanced = parse_file("../test/data/dist/case3_unbalanced.dss")
    case3_balanced_pv = parse_file("../test/data/dist/case3_balanced_pv.dss")
    case3_balanced_multi_pv_grid_following = parse_file("../test/data/dist/case3_balanced_multi_pv_grid_following.dss")
    case3_balanced_multi_pv_on_bus_grid_following = parse_file("../test/data/dist/case3_balanced_multi_pv_on_bus_grid_following.dss")

    @testset "ivr pf ut_trans_2w_yy" begin
        sol = solve_mc_pf(ut_trans_2w_yy, ipopt_solver; make_si=false)
        @test isapprox.(sol["solution"]["bus"]["sourcebus"]["vr"][1], 1.0; atol=1e-4)
        @test isapprox.(sol["solution"]["bus"]["3"]["vr"][1], 0.8745; atol=1e-4)
    end

    @testset "ivr pf case3_unbalanced" begin
        sol = solve_mc_pf(case3_unbalanced, ipopt_solver; make_si=false)
        @test isapprox.(sol["solution"]["bus"]["sourcebus"]["vr"][1], .9959; atol=1e-4)
        @test isapprox.(sol["solution"]["bus"]["loadbus"]["vr"][3], -0.4924; atol=1e-4)
    end

    @testset "ivr pf case3_balanced_pv" begin
        sol = solve_mc_pf(case3_balanced_pv, ipopt_solver)
        @test calculate_error_percentage(sol["solution"]["line"]["quad"]["cr_fr"][1], 89.674) < .05
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cr_fr"][1], 36.637) < .05
    end

    @testset "ivr pf case3_balanced_multi_pv_grid_following" begin
        sol = solve_mc_pf(case3_balanced_multi_pv_grid_following, ipopt_solver)
        @test calculate_error_percentage(sol["solution"]["line"]["quad"]["cr_fr"][1], 89.674) < .05
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cr_fr"][1], 36.637) < .05
        @test calculate_error_percentage(sol["solution"]["line"]["pv2_line"]["cr_fr"][1], 36.637) < .05
    end

    @testset "ivr pf case3_balanced_multi_pv_on_bus_grid_following" begin
        sol = solve_mc_pf(case3_balanced_multi_pv_on_bus_grid_following, ipopt_solver)
        @test calculate_error_percentage(sol["solution"]["line"]["quad"]["cr_fr"][1], 90.855) < .05
    end
end
