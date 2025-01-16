@testset "power flow solver test" begin
    @testset  "check mvasc1 mvasc3 defined source" begin 
        model = PowerModelsProtection.instantiate_mc_admittance_model(bus_example3) 
        sol = PowerModelsProtection.compute_mc_pf(model)
        @test sol["solver"]["it"] < 10
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][2], 223.41) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][2], -120.1) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][3], 223.41) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][3], 119.9) < .001
    end
    @testset  "check isc3 isc1 defined source, and lag transformer delta high side" begin 
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_wye_lag)  
        sol = PowerModelsProtection.compute_mc_pf(model)
        @test sol["solver"]["it"] < 10
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][1], 2129.8) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][1], -30.0) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][2], 2105.8) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][2], -150.4) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][3], 2084.8) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][3], 89.8) < .001
    end
    @testset  "check r1 x1 r0 x0 defined source and lead transformer delat high side" begin 
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_wye_lead)  
        sol = PowerModelsProtection.compute_mc_pf(model)
        @test sol["solver"]["it"] < 10
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][1], 2130.8) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][1], 29.9) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][2], 2100.8) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][2], -90.3) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][3], 2088.8) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][3], 149.9) < .001
    end
    @testset "check wye wye transformer and single phase wye loads" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(wye_wye) 
        sol = PowerModelsProtection.compute_mc_pf(model)
        @test sol["solver"]["it"] < 10
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][1], 2023.6) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][2], 1993.1) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][2], -120.4) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][3], 1977.0) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][3], 119.8) < .001
    end
    @testset "check center tap transformer and single phase delta load" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(simple_center_tap) 
        sol = PowerModelsProtection.compute_mc_pf(model)
        @test sol["solver"]["it"] < 10
        @test calculate_error_percentage(sol["bus"]["3"]["vm"][1], 119.83) < .001
        @test calculate_error_percentage(sol["bus"]["3"]["vm"][2], 119.84) < .001
        @test calculate_error_percentage(sol["bus"]["3"]["va"][2], 179.9) < .001
    end
    @testset "check single phase delta PQ, Z, and I load based on PQ" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(loads_example) 
        sol = PowerModelsProtection.compute_mc_pf(model)
        @test sol["solver"]["it"] < 10
        @test calculate_error_percentage(sol["bus"]["3"]["vm"][1], 225.0) < .001
        @test calculate_error_percentage(sol["bus"]["3"]["vm"][2], 224.48) < .001 # check
        @test calculate_error_percentage(sol["bus"]["3"]["va"][2], -120.0) < .001
        @test calculate_error_percentage(sol["bus"]["3"]["vm"][3], 225.69) < .001
        @test calculate_error_percentage(sol["bus"]["3"]["va"][3], 119.9) < .001
    end
    @testset "check 3 phase delta PQ, Z, and I load based on PQ" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_3p_load) 
        sol = PowerModelsProtection.compute_mc_pf(model)
        @test sol["solver"]["it"] < 10
        @test calculate_error_percentage(sol["bus"]["3"]["vm"][1], 212.78) < .001
        @test calculate_error_percentage(sol["bus"]["3"]["vm"][2], 229.55) < .001 
        @test calculate_error_percentage(sol["bus"]["3"]["va"][2], -121.0) < .001
        @test calculate_error_percentage(sol["bus"]["3"]["vm"][3], 230.59) < .001
        @test calculate_error_percentage(sol["bus"]["3"]["va"][3], 121.4) < .001
    end
    @testset  "check mvasc1 mvasc3 defined source y pass solve" begin 
        model = PowerModelsProtection.instantiate_mc_admittance_model(bus_example3) 
        sol = PowerModelsProtection.compute_mc_pf(model, model.y)
        @test sol["solver"]["it"] < 10
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][2], 223.41) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][2], -120.1) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][3], 223.41) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][3], 119.9) < .001
    end
    @testset  "check isc3 isc1 defined source, and lag transformer delta high side y pass solve" begin 
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_wye_lag)  
        sol = PowerModelsProtection.compute_mc_pf(model, model.y)
        @test sol["solver"]["it"] < 10
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][1], 2129.8) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][1], -30.0) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][2], 2105.8) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][2], -150.4) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][3], 2084.8) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][3], 89.8) < .001
    end
    @testset  "check r1 x1 r0 x0 defined source and lead transformer delat high side y pass solve" begin 
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_wye_lead)  
        sol = PowerModelsProtection.compute_mc_pf(model, model.y)
        @test sol["solver"]["it"] < 10
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][1], 2130.8) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][1], 29.9) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][2], 2100.8) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][2], -90.3) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][3], 2088.8) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][3], 149.9) < .001
    end
    @testset "check wye wye transformer and single phase wye loads y pass solve" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(wye_wye) 
        sol = PowerModelsProtection.compute_mc_pf(model, model.y)
        @test sol["solver"]["it"] < 10
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][1], 2023.6) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][2], 1993.1) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][2], -120.4) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["vm"][3], 1977.0) < .001
        @test calculate_error_percentage(sol["bus"]["4"]["va"][3], 119.8) < .001
    end
    @testset "check center tap transformer and single phase delta load y pass solve" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(simple_center_tap) 
        sol = PowerModelsProtection.compute_mc_pf(model, model.y)
        @test sol["solver"]["it"] < 10
        @test calculate_error_percentage(sol["bus"]["3"]["vm"][1], 119.83) < .001
        @test calculate_error_percentage(sol["bus"]["3"]["vm"][2], 119.84) < .001
        @test calculate_error_percentage(sol["bus"]["3"]["va"][2], 179.9) < .001
    end
    @testset "check single phase delta PQ, Z, and I load based on PQ y pass solve" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(loads_example) 
        sol = PowerModelsProtection.compute_mc_pf(model, model.y)
        @test sol["solver"]["it"] < 10
        @test calculate_error_percentage(sol["bus"]["3"]["vm"][1], 225.0) < .001
        @test calculate_error_percentage(sol["bus"]["3"]["vm"][2], 224.48) < .001 # check
        @test calculate_error_percentage(sol["bus"]["3"]["va"][2], -120.0) < .001
        @test calculate_error_percentage(sol["bus"]["3"]["vm"][3], 225.69) < .001
        @test calculate_error_percentage(sol["bus"]["3"]["va"][3], 119.9) < .001
    end
    @testset "check 3 phase delta PQ, Z, and I load based on PQ y pass solve" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_3p_load) 
        sol = PowerModelsProtection.compute_mc_pf(model, model.y)
        @test sol["solver"]["it"] < 10
        @test calculate_error_percentage(sol["bus"]["3"]["vm"][1], 212.78) < .001
        @test calculate_error_percentage(sol["bus"]["3"]["vm"][2], 229.55) < .001 
        @test calculate_error_percentage(sol["bus"]["3"]["va"][2], -121.0) < .001
        @test calculate_error_percentage(sol["bus"]["3"]["vm"][3], 230.59) < .001
        @test calculate_error_percentage(sol["bus"]["3"]["va"][3], 121.4) < .001
    end
end


        
    

