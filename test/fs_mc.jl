@testset "Unbalanced fault study" begin
    @testset "check mvasc1 mvasc3 defined source" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(bus_example3; loading=false)
        sol = PowerModelsProtection.solve_mc_fault_study(model)
        @test calculate_error_percentage(sol["loadbus"]["ll"][(1, 2)][1], 907.0) < 0.001
        @test calculate_error_percentage(sol["loadbus"]["ll"][(2, 3)][1], 907.0) < 0.001
        @test calculate_error_percentage(sol["loadbus"]["ll"][(1, 3)][1], 907.0) < 0.001
        @test calculate_error_percentage(sol["loadbus"]["lg"][1][1], 629.0) < 0.001
        @test calculate_error_percentage(sol["loadbus"]["lg"][2][1], 629.0) < 0.001
        @test calculate_error_percentage(sol["loadbus"]["lg"][3][1], 629.0) < 0.001
        @test calculate_error_percentage(sol["loadbus"]["3pg"][1], 1048.0) < 0.001
        @test calculate_error_percentage(sol["loadbus"]["3pg"][2], 1048.0) < 0.001
        @test calculate_error_percentage(sol["loadbus"]["3pg"][3], 1048.0) < 0.001
        model = PowerModelsProtection.instantiate_mc_admittance_model(bus_example3)
        sol = PowerModelsProtection.solve_mc_fault_study(model)
        @test calculate_error_percentage(sol["loadbus"]["ll"][(1, 2)][1], 905.0) < 0.02
        @test calculate_error_percentage(sol["loadbus"]["ll"][(2, 3)][1], 905.0) < 0.02
        @test calculate_error_percentage(sol["loadbus"]["ll"][(1, 3)][1], 905.0) < 0.02
        @test calculate_error_percentage(sol["loadbus"]["lg"][1][1], 647.0) < 0.02
        @test calculate_error_percentage(sol["loadbus"]["lg"][2][1], 647.0) < 0.02
        @test calculate_error_percentage(sol["loadbus"]["lg"][3][1], 647.0) < 0.02
        @test calculate_error_percentage(sol["loadbus"]["3pg"][1], 1046.0) < 0.02
        @test calculate_error_percentage(sol["loadbus"]["3pg"][2], 1046.0) < 0.02
        @test calculate_error_percentage(sol["loadbus"]["3pg"][3], 1046.0) < 0.02
    end
    @testset "check isc3 isc1 defined source, and lag transformer delta high side" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_wye_lag; loading=false)
        sol = PowerModelsProtection.solve_mc_fault_study(model)
        @test calculate_error_percentage(sol["3"]["ll"][(1, 2)][1], 607.0) < 0.001
        @test calculate_error_percentage(sol["3"]["ll"][(2, 3)][1], 607.0) < 0.001
        @test calculate_error_percentage(sol["3"]["ll"][(1, 3)][1], 607.0) < 0.001
        @test calculate_error_percentage(sol["3"]["lg"][1][1], 784.0) < 0.001
        @test calculate_error_percentage(sol["3"]["lg"][2][1], 784.0) < 0.001
        @test calculate_error_percentage(sol["3"]["lg"][3][1], 784.0) < 0.001
        @test calculate_error_percentage(sol["3"]["3pg"][1], 701.0) < 0.001
        @test calculate_error_percentage(sol["3"]["3pg"][2], 701.0) < 0.001
        @test calculate_error_percentage(sol["3"]["3pg"][3], 701.0) < 0.001
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_wye_lag)
        sol = PowerModelsProtection.solve_mc_fault_study(model)
        @test calculate_error_percentage(sol["3"]["ll"][(1, 2)][1], 595.0) < 0.02
        @test calculate_error_percentage(sol["3"]["ll"][(2, 3)][1], 593.0) < 0.02
        @test calculate_error_percentage(sol["3"]["ll"][(1, 3)][1], 592.0) < 0.02
        @test calculate_error_percentage(sol["3"]["lg"][1][1], 763.0) < 0.02
        @test calculate_error_percentage(sol["3"]["lg"][2][1], 761.0) < 0.02
        @test calculate_error_percentage(sol["3"]["lg"][3][1], 759.0) < 0.02
        @test calculate_error_percentage(sol["3"]["3pg"][1], 687.0) < 0.02
        @test calculate_error_percentage(sol["3"]["3pg"][2], 685.0) < 0.02
        @test calculate_error_percentage(sol["3"]["3pg"][3], 682.0) < 0.02
    end
    @testset "check r1 x1 r0 x0 defined source and lead transformer delat high side" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_wye_lead; loading=false)
        sol = PowerModelsProtection.solve_mc_fault_study(model)
        @test calculate_error_percentage(sol["3"]["ll"][(1, 2)][1], 607.0) < 0.001
        @test calculate_error_percentage(sol["3"]["ll"][(2, 3)][1], 607.0) < 0.001
        @test calculate_error_percentage(sol["3"]["ll"][(1, 3)][1], 607.0) < 0.001
        @test calculate_error_percentage(sol["3"]["lg"][1][1], 784.0) < 0.001
        @test calculate_error_percentage(sol["3"]["lg"][2][1], 784.0) < 0.001
        @test calculate_error_percentage(sol["3"]["lg"][3][1], 784.0) < 0.001
        @test calculate_error_percentage(sol["3"]["3pg"][1], 701.0) < 0.001
        @test calculate_error_percentage(sol["3"]["3pg"][2], 701.0) < 0.001
        @test calculate_error_percentage(sol["3"]["3pg"][3], 701.0) < 0.001
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_wye_lead)
        sol = PowerModelsProtection.solve_mc_fault_study(model)
        @test calculate_error_percentage(sol["3"]["ll"][(1, 2)][1], 594.0) < 0.02
        @test calculate_error_percentage(sol["3"]["ll"][(2, 3)][1], 594.0) < 0.02
        @test calculate_error_percentage(sol["3"]["ll"][(1, 3)][1], 592.0) < 0.02
        @test calculate_error_percentage(sol["3"]["lg"][1][1], 764.0) < 0.02
        @test calculate_error_percentage(sol["3"]["lg"][2][1], 759.0) < 0.02
        @test calculate_error_percentage(sol["3"]["lg"][3][1], 760.0) < 0.02
        @test calculate_error_percentage(sol["3"]["3pg"][1], 688.0) < 0.02
        @test calculate_error_percentage(sol["3"]["3pg"][2], 684.0) < 0.02
        @test calculate_error_percentage(sol["3"]["3pg"][3], 683.0) < 0.02
    end
    @testset "check wye wye transformer and single phase wye loads" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(wye_wye; loading=false)
        sol = PowerModelsProtection.solve_mc_fault_study(model)
        @test calculate_error_percentage(sol["3"]["ll"][(1, 2)][1], 612.0) < 0.001
        @test calculate_error_percentage(sol["3"]["ll"][(2, 3)][1], 612.0) < 0.001
        @test calculate_error_percentage(sol["3"]["ll"][(1, 3)][1], 612.0) < 0.001
        @test calculate_error_percentage(sol["3"]["lg"][1][1], 784.0) < 0.001
        @test calculate_error_percentage(sol["3"]["lg"][2][1], 784.0) < 0.001
        @test calculate_error_percentage(sol["3"]["lg"][3][1], 784.0) < 0.001
        @test calculate_error_percentage(sol["3"]["3pg"][1], 707.0) < 0.001
        @test calculate_error_percentage(sol["3"]["3pg"][2], 707.0) < 0.001
        @test calculate_error_percentage(sol["3"]["3pg"][3], 707.0) < 0.001
        model = PowerModelsProtection.instantiate_mc_admittance_model(wye_wye)
        sol = PowerModelsProtection.solve_mc_fault_study(model)
        @test calculate_error_percentage(sol["3"]["ll"][(1, 2)][1], 596.0) < 0.02
        @test calculate_error_percentage(sol["3"]["ll"][(2, 3)][1], 594.0) < 0.02
        @test calculate_error_percentage(sol["3"]["ll"][(1, 3)][1], 592.0) < 0.02
        @test calculate_error_percentage(sol["3"]["lg"][1][1], 760.0) < 0.02
        @test calculate_error_percentage(sol["3"]["lg"][2][1], 755.0) < 0.02
        @test calculate_error_percentage(sol["3"]["lg"][3][1], 754.0) < 0.02
        @test calculate_error_percentage(sol["3"]["3pg"][1], 690.0) < 0.02
        @test calculate_error_percentage(sol["3"]["3pg"][2], 686.0) < 0.02
        @test calculate_error_percentage(sol["3"]["3pg"][3], 682.0) < 0.02
    end
    @testset "check single phase delta PQ, Z, and I load based on PQ" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(loads_example; loading=false)
        sol = PowerModelsProtection.solve_mc_fault_study(model)
        @test calculate_error_percentage(sol["loadbus"]["ll"][(1, 2)][1], 1327.0) < 0.001
        @test calculate_error_percentage(sol["loadbus"]["ll"][(2, 3)][1], 1327.0) < 0.001
        @test calculate_error_percentage(sol["loadbus"]["ll"][(1, 3)][1], 1327.0) < 0.001
        @test calculate_error_percentage(sol["loadbus"]["lg"][1][1], 919.0) < 0.001
        @test calculate_error_percentage(sol["loadbus"]["lg"][2][1], 919.0) < 0.001
        @test calculate_error_percentage(sol["loadbus"]["lg"][3][1], 919.0) < 0.001
        @test calculate_error_percentage(sol["loadbus"]["3pg"][1], 1532.0) < 0.001
        @test calculate_error_percentage(sol["loadbus"]["3pg"][2], 1532.0) < 0.001
        @test calculate_error_percentage(sol["loadbus"]["3pg"][3], 1532.0) < 0.001
        model = PowerModelsProtection.instantiate_mc_admittance_model(loads_example)
        sol = PowerModelsProtection.solve_mc_fault_study(model)
        @test calculate_error_percentage(sol["loadbus"]["ll"][(1, 2)][1], 1325.0) < 0.02
        @test calculate_error_percentage(sol["loadbus"]["ll"][(2, 3)][1], 1328.0) < 0.02
        @test calculate_error_percentage(sol["loadbus"]["ll"][(1, 3)][1], 1325.0) < 0.02
        @test calculate_error_percentage(sol["loadbus"]["lg"][1][1], 907.0) < 0.02
        @test calculate_error_percentage(sol["loadbus"]["lg"][2][1], 905.0) < 0.02
        @test calculate_error_percentage(sol["loadbus"]["lg"][3][1], 909.0) < 0.02
        @test calculate_error_percentage(sol["loadbus"]["3pg"][1], 1531.0) < 0.02
        @test calculate_error_percentage(sol["loadbus"]["3pg"][2], 1531.0) < 0.02
        @test calculate_error_percentage(sol["loadbus"]["3pg"][3], 1532.0) < 0.02
    end
end
