@testset "Unbalanced fault study" begin
    ut_trans_2w_yy_fault_study = parse_file("../test/data/dist/ut_trans_2w_yy_fault_study.dss")
    case3_balanced_pv = parse_file("../test/data/dist/case3_balanced_pv.dss")
    case3_balanced_pv_grid_forming = parse_file("../test/data/dist/case3_balanced_pv_grid_forming.dss")
    case3_balanced_multi_pv_grid_following = parse_file("../test/data/dist/case3_balanced_multi_pv_grid_following.dss")
    case3_balanced_parallel_pv_grid_following = parse_file("../test/data/dist/case3_balanced_parallel_pv_grid_following.dss")
    case3_balanced_single_phase = parse_file("../test/data/dist/case3_balanced_single_phase.dss")
    case3_unblanced_switch = parse_file("../test/data/dist/case3_unbalanced_switch.dss")
    simulink_model = parse_file("../test/data/dist/simulink_model.dss")
    case3_balanced_pv_storage_grid_forming = parse_file("../test/data/dist/case3_balanced_pv_storage_grid_forming.dss")

    @testset "ut_trans_2w_yy_fault_study test fault study" begin
        data = deepcopy(ut_trans_2w_yy_fault_study)

        fault_studies = build_mc_fault_study(data)
        sol = solve_mc_fault_study(data, fault_studies, ipopt_solver)

        @test sol["1"]["lg"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["1"]["lg"]["1"]["solution"]["line"]["line1"]["cf_fr"][1], 1381.0) < .05
        @test sol["1"]["ll"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["1"]["ll"]["1"]["solution"]["line"]["line1"]["cf_fr"][1], 818.0) < .05
        @test sol["1"]["3p"]["1"]["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["1"]["3p"]["1"]["solution"]["line"]["line1"]["cf_fr"][1], 945.0) < .05
    end

    @testset "ut_trans_2w_yy_fault_study line to ground fault" begin
        data = deepcopy(ut_trans_2w_yy_fault_study)

        add_fault!(data, "1", "lg", "3", [1,4], .00001)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["line2"]["cf_fr"][1], 785.0) < .05
    end

    @testset "ut_trans_2w_yy_fault_study 3-phase fault" begin
        data = deepcopy(ut_trans_2w_yy_fault_study)

        add_fault!(data, "1", "3p", "3", [1,2,3], 0.005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["line2"]["cf_fr"][1], 708.0) < .05
    end

    @testset "3-bus pv fault test single faults" begin
        data = deepcopy(case3_balanced_pv)

        add_fault!(data, "1", "3p", "loadbus", [1,2,3], 0.005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 39.686) < .05
        add_fault!(data, "1", "lg", "loadbus", [1, 4], 0.005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 38.978) < .05

        add_fault!(data, "1", "ll", "loadbus", [1, 2], 0.005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 39.693) < .05

        # test the current limit bu placing large load to force off limits
        add_fault!(data, "1", "3p", "loadbus", [1,2,3], 500.0)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 35.523) < .05
    end

    @testset "c3-bus multiple pv grid_following fault test" begin
        data = deepcopy(case3_balanced_multi_pv_grid_following)

        add_fault!(data, "1", "lg", "loadbus", [1, 4], 0.0005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 38.648) < .05

        add_fault!(data, "1", "ll", "loadbus", [1, 2], 0.0005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 39.691) < .05

        add_fault!(data, "1", "3p", "loadbus", [1,2,3], 0.0005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 39.692) < .05

        add_fault!(data, "1", "lg", "pv_bus", [1, 4], 0.0005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 913.270) < .05
    end
    

    @testset "c3-bus parallel pv grid_following fault test" begin
        data = deepcopy(case3_balanced_parallel_pv_grid_following)

        add_fault!(data, "1", "lg", "loadbus", [1, 4], 0.0005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 76.389) < .05

        add_fault!(data, "1", "ll", "loadbus", [1, 2], 0.0005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 76.389) < .05

        add_fault!(data, "1", "3p", "loadbus", [1,2,3], 0.0005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 76.389) < .05

        add_fault!(data, "1", "lg", "pv_bus", [1, 4], 0.0005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 890.711) < .05
    end

    @testset "c3-bus pv grid_forming fault test island" begin
        case3_balanced_pv_grid_forming["solar"]["pv1"]["grid_forming"] = true
        case3_balanced_pv_grid_forming["line"]["ohline"]["status"] = DISABLED

        data = deepcopy(case3_balanced_pv_grid_forming)
        add_fault!(data, "1", "lg", "loadbus", [1, 4], 0.005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 39.692) < .05

        add_fault!(data, "1", "ll", "loadbus", [1, 2], 0.005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 39.692) < .05

        add_fault!(data, "1", "3p", "loadbus", [1,2,3], 0.005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 39.692) < .05

        # TODO: Why isn't this passing? this should be the exact value
        # add_fault!(data, "1", "lg", "pv_bus", [1, 4], 0.005)
        # sol = solve_mc_fault_study(data, ipopt_solver)
        # @test sol["termination_status"] == LOCALLY_SOLVED
        # println(sol["solution"]["line"]["pv_line"]["cf_fr"][1])
        # @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 904.091) < .05
    end

    @testset "c3-bus pv and storage grid_forming fault test" begin
        case3_balanced_pv_storage_grid_forming["solar"]["pv1"]["grid_forming"] = true
        data = deepcopy(case3_balanced_pv_storage_grid_forming)

        add_fault!(data, "1", "ll", "loadbus", [1, 2], 0.0005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 519.975) < .05

        add_fault!(data, "1", "3p", "loadbus", [1,2,3], 0.0005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 400.557) < .05

        
        add_fault!(data, "1", "lg", "pv_bus", [1, 4], 0.0005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["line"]["pv_line"]["cf_fr"][1], 1132.408) < .05
    end

    @testset "c3-bus single phase test" begin
        case3_balanced_single_phase["voltage_source"]["source"]["grid_forming"] = true
        data = deepcopy(case3_balanced_single_phase)

        add_fault!(data, "1", "lg", "loadbus", [1, 4], 0.005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 862.0) < .05

        add_fault!(data, "1", "ll", "loadbus", [1, 2], 0.005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 1259.0) < .05

        add_fault!(data, "1", "3p", "loadbus", [1,2,3], 0.005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 1455.0) < .05

        add_fault!(data, "1", "lg", "loadbus2", [2, 4], 0.005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 640.0) < .05
    end

    @testset "case3_unblanced_switch test fault study" begin
        data = deepcopy(case3_unblanced_switch)

        add_fault!(data, "1", "3p", "loadbus", [1,2,3], .0005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 1454.0) < .06

        add_fault!(data, "1", "ll", "loadbus", [1, 2], .0005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 1257.0) < .06

        add_fault!(data, "1", "lg", "loadbus", [1, 4], .0005)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 883.0) < .06
    end


    @testset "compare to simulink model" begin
        # TODO needs helper function
        simulink_model["solar"]["pv1"]["grid_forming"] = true
        simulink_model["line"]["cable1"]["status"] = DISABLED
        data = deepcopy(simulink_model)

        add_fault!(data, "1", "3p", "midbus", [1,2,3], 60.0)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 13.79) < .05

        add_fault!(data, "1", "ll", "midbus", [1, 2], 40.0)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 11.94) < .05

        add_fault!(data, "1", "lg", "midbus", [1, 4], 20.0)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 13.79) < .05

        add_fault!(data, "1", "3p", "midbus", [1,2,3], .1)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 69.93) < .15

        add_fault!(data, "1", "ll", "midbus", [1, 2], .1)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 60.55) < .15

        add_fault!(data, "1", "lg", "midbus", [1, 4], .1)
        sol = solve_mc_fault_study(data, ipopt_solver)
        @test sol["termination_status"] == LOCALLY_SOLVED
        @test calculate_error_percentage(sol["solution"]["fault"]["1"]["cf"][1], 103.4) < .15
    end

end
