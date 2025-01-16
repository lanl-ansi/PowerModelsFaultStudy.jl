@testset "Admittance test for components" begin
    @info "source checks"
    @testset "check mvasc1 mvasc3 defined source" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(bus_example3)
        p_matrix = model.data["gen"]["1"]["p_matrix"]
        @test calculate_error_percentage(real(p_matrix[1, 1]), 1668079.689) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 1]), -6014804.171) < 0.001
        @test calculate_error_percentage(real(p_matrix[1, 4]), -1668079.689) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 4]), 6014804.171) < 0.001
        @test calculate_error_percentage(real(p_matrix[5, 5]), 1668079.6899) < 0.001
        @test calculate_error_percentage(imag(p_matrix[5, 5]), -6014804.171) < 0.001
        @test calculate_error_percentage(real(p_matrix[6, 6]), 1668079.689) < 0.001
        @test calculate_error_percentage(imag(p_matrix[6, 6]), -6014804.171) < 0.001
    end
    @testset "check isc3 isc1 defined source" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_wye_lag)
        p_matrix = model.data["gen"]["1"]["p_matrix"]
        @test calculate_error_percentage(real(p_matrix[1, 1]), 420247.0941) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 1]), -1515337.661) < 0.001
        @test calculate_error_percentage(real(p_matrix[1, 4]), -420247.0941) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 4]), 1515337.661) < 0.001
        @test calculate_error_percentage(real(p_matrix[5, 5]), 420247.0941) < 0.001
        @test calculate_error_percentage(imag(p_matrix[5, 5]), -1515337.661) < 0.001
        @test calculate_error_percentage(real(p_matrix[6, 6]), 420247.0941) < 0.001
        @test calculate_error_percentage(imag(p_matrix[6, 6]), -1515337.661) < 0.001
    end
    @testset "check r1 x1 r0 x0 defined source" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_wye_lead)
        p_matrix = model.data["gen"]["1"]["p_matrix"]
        @test calculate_error_percentage(real(p_matrix[1, 1]), 492.6378751) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 1]), -2035.939789) < 0.001
        @test calculate_error_percentage(real(p_matrix[1, 4]), -492.6378751) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 4]), 2035.939789) < 0.001
        @test calculate_error_percentage(real(p_matrix[5, 5]), 492.6378751) < 0.001
        @test calculate_error_percentage(imag(p_matrix[5, 5]), -2035.939789) < 0.001
        @test calculate_error_percentage(real(p_matrix[6, 6]), 492.6378751) < 0.001
        @test calculate_error_percentage(imag(p_matrix[6, 6]), -2035.939789) < 0.001
    end
    @info "transformer checks"
    @testset "2w y-y transformer test" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(wye_wye)
        p_matrix = model.data["transformer"]["1"]["p_matrix"]
        @test calculate_error_percentage(real(p_matrix[1, 1]), 0.0350450455) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 1]), -0.05840841123) < 0.001
        @test calculate_error_percentage(real(p_matrix[1, 4]), -0.0350450455) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 4]), 0.05840840917) < 0.001
        @test calculate_error_percentage(real(p_matrix[5, 5]), 0.2947154789) < 0.001
        @test calculate_error_percentage(imag(p_matrix[5, 5]), -0.4920781573) < 0.001
        @test calculate_error_percentage(real(p_matrix[8, 8]), 0.8841464368) < 0.001
        @test calculate_error_percentage(imag(p_matrix[8, 8]), -1.476234488) < 0.001
    end
    @testset "2w d-y lag high delta transformer test" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_wye_lag)
        p_matrix = model.data["transformer"]["1"]["p_matrix"]
        @test calculate_error_percentage(real(p_matrix[1, 1]), 0.02430724356) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 1]), -0.04051207398) < 0.001
        @test calculate_error_percentage(real(p_matrix[1, 6]), 0.05788939865) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 6]), -0.09648233108) < 0.001
        @test real(p_matrix[1, 7]) < 0.0000001
        @test imag(p_matrix[1, 7]) < 0.0000001
        @test calculate_error_percentage(real(p_matrix[5, 5]), 0.2772977941) < 0.001
        @test calculate_error_percentage(imag(p_matrix[5, 5]), -0.4629963392) < 0.001
        @test calculate_error_percentage(real(p_matrix[8, 8]), 0.8318933824) < 0.001
        @test calculate_error_percentage(imag(p_matrix[8, 8]), -1.388989033) < 0.001
    end
    @testset "2w d-y lead high delta transformer test" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_wye_lead)
        p_matrix = model.data["transformer"]["1"]["p_matrix"]
        @test calculate_error_percentage(real(p_matrix[1, 1]), 0.02430724356) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 1]), -0.04051207398) < 0.001
        @test real(p_matrix[1, 6]) < 0.0000001
        @test imag(p_matrix[1, 6]) < 0.0000001
        @test calculate_error_percentage(real(p_matrix[1, 7]), 0.05788939865) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 7]), -0.09648233108) < 0.001
        @test calculate_error_percentage(real(p_matrix[5, 5]), 0.2772977941) < 0.001
        @test calculate_error_percentage(imag(p_matrix[5, 5]), -0.4629963392) < 0.001
        @test calculate_error_percentage(real(p_matrix[8, 8]), 0.8318933824) < 0.001
        @test calculate_error_percentage(imag(p_matrix[8, 8]), -1.388989033) < 0.001
    end
    # @testset "2w d-y lag low delta transformer test" begin
    #     model = PowerModelsProtection.instantiate_mc_admittance_model(bus_example3_lag)
    #     p_matrix = model.data["transformer"]["1"]["p_matrix"]
    #     @test calculate_error_percentage(real(p_matrix[1,1]), 0.9191176471) < .001
    #     @test calculate_error_percentage(imag(p_matrix[1,1]), -1.531862797) < .001
    #     @test real(p_matrix[1,6]) < .0000001
    #     @test imag(p_matrix[1,6]) < .0000001
    #     @test calculate_error_percentage(real(p_matrix[1,7]), 0.07653646456) < .001
    #     @test calculate_error_percentage(imag(p_matrix[1,7]), -0.1275607743) < .001
    #     @test calculate_error_percentage(real(p_matrix[5,5]), 0.01274663897) < .001
    #     @test calculate_error_percentage(imag(p_matrix[5,5]), -0.021244399) < .001
    #     @test calculate_error_percentage(real(p_matrix[8,8]), 0.0382399169) < .001
    #     @test calculate_error_percentage(imag(p_matrix[8,8]), -0.06373319772) < .001
    # end
    @testset "center tap transformer test" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(simple_center_tap)
        p_matrix = model.data["transformer"]["1"]["p_matrix"]
        @test calculate_error_percentage(real(p_matrix[1, 1]), 0.1069198529) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 1]), -0.1514697935) < 0.001
        @test calculate_error_percentage(real(p_matrix[1, 4]), 3.207595586) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 4]), -4.544093747) < 0.001
        @test calculate_error_percentage(real(p_matrix[3, 3]), 534.2988189) < 0.001
        @test calculate_error_percentage(imag(p_matrix[3, 3]), -384.5472844) < 0.001
        @test calculate_error_percentage(real(p_matrix[4, 4]), 534.2988189) < 0.001
        @test calculate_error_percentage(real(p_matrix[6, 6]), 534.2710411) < 0.001
        @test calculate_error_percentage(imag(p_matrix[4, 4]), -384.5472913) < 0.001
        @test calculate_error_percentage(imag(p_matrix[6, 6]), -384.5472913) < 0.001
    end
    @testset "regulator transformer test" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(reg_case)
        p_matrix = model.data["transformer"]["2"]["p_matrix"]
        @test real(p_matrix[1, 1]) < 0.0000001
        @test calculate_error_percentage(imag(p_matrix[1, 1]), -2892.361111) < 0.001
        @test real(p_matrix[1, 4]) < 0.0000001
        @test calculate_error_percentage(imag(p_matrix[1, 4]), -2892.361111) < 0.001
        @test real(p_matrix[3, 3]) < 0.0000001
        @test calculate_error_percentage(imag(p_matrix[3, 3]), -2892.361111) < 0.001
        @test real(p_matrix[4, 4]) < 0.0000001
        @test calculate_error_percentage(imag(p_matrix[4, 4]), -2892.361111) < 0.001
    end
    @info "load checks"
    @testset "single phase load" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(bus_example3)
        p_matrix = model.data["load"]["1"]["p_matrix"]
        @test calculate_error_percentage(real(p_matrix[1, 1]), 0.1125) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 1]), -0.05625) < 0.001
        @test calculate_error_percentage(real(p_matrix[1, 2]), -0.1125) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 2]), 0.05625) < 0.001
    end
    @testset "3 phase load" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(bus_example5)
        p_matrix = model.data["load"]["1"]["p_matrix"]
        @test calculate_error_percentage(real(p_matrix[1, 1]), 0.0006430830947) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 1]), -6.430830947E-005) < 0.001
        @test real(p_matrix[1, 2]) < 0.0000001
        @test imag(p_matrix[1, 2]) < 0.0000001
        @test calculate_error_percentage(real(p_matrix[2, 2]), 0.0006430830947) < 0.001
        @test calculate_error_percentage(imag(p_matrix[2, 2]), -6.430830947E-005) < 0.001
    end
    @testset "delta PQ, Z, and I load based on PQ" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(loads_example)
        p_matrix = model.data["load"]["1"]["p_matrix"]
        @test calculate_error_percentage(real(p_matrix[1, 1]), 0.0375) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 1]), -0.01875) < 0.001
        @test calculate_error_percentage(real(p_matrix[1, 2]), -0.0375) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 2]), 0.01875) < 0.001
        @test calculate_error_percentage(real(p_matrix[2, 2]), 0.0375) < 0.001
        @test calculate_error_percentage(imag(p_matrix[2, 2]), -0.01875) < 0.001
        p_matrix = model.data["load"]["2"]["p_matrix"]
        @test calculate_error_percentage(real(p_matrix[1, 1]), 0.0375) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 1]), -0.01875) < 0.001
        @test calculate_error_percentage(real(p_matrix[1, 2]), -0.0375) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 2]), 0.01875) < 0.001
        @test calculate_error_percentage(real(p_matrix[2, 2]), 0.0375) < 0.001
        @test calculate_error_percentage(imag(p_matrix[2, 2]), -0.01875) < 0.001
        p_matrix = model.data["load"]["3"]["p_matrix"]
        @test calculate_error_percentage(real(p_matrix[1, 1]), 0.05625) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 1]), -0.01875) < 0.001
        @test calculate_error_percentage(real(p_matrix[1, 2]), -0.05625) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 2]), 0.01875) < 0.001
        @test calculate_error_percentage(real(p_matrix[2, 2]), 0.05625) < 0.001
        @test calculate_error_percentage(imag(p_matrix[2, 2]), -0.01875) < 0.001
    end
    @testset "3 phase delta PQ, Z, and I load based on PQ" begin
        model = PowerModelsProtection.instantiate_mc_admittance_model(delta_3p_load)
        p_matrix = model.data["load"]["1"]["p_matrix"]
        @test calculate_error_percentage(real(p_matrix[1, 1]), 1.666666667) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 1]), -1.25) < 0.001
        @test calculate_error_percentage(real(p_matrix[1, 2]), -0.8333333333) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 2]), 0.625) < 0.001
        @test calculate_error_percentage(real(p_matrix[2, 2]), 1.666666667) < 0.001
        @test calculate_error_percentage(imag(p_matrix[2, 2]), -1.25) < 0.001
        p_matrix = model.data["load"]["3"]["p_matrix"]
        @test calculate_error_percentage(real(p_matrix[1, 1]), 1.666666667) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 1]), -1.25) < 0.001
        @test calculate_error_percentage(real(p_matrix[1, 2]), -0.8333333333) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 2]), 0.625) < 0.001
        @test calculate_error_percentage(real(p_matrix[2, 2]), 1.666666667) < 0.001
        @test calculate_error_percentage(imag(p_matrix[2, 2]), -1.25) < 0.001
        p_matrix = model.data["load"]["4"]["p_matrix"]
        @test calculate_error_percentage(real(p_matrix[1, 1]), 0.8333333333) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 1]), -1.25) < 0.001
        @test calculate_error_percentage(real(p_matrix[1, 2]), -0.4166666667) < 0.001
        @test calculate_error_percentage(imag(p_matrix[1, 2]), 0.625) < 0.001
        @test calculate_error_percentage(real(p_matrix[2, 2]), 0.8333333333) < 0.001
        @test calculate_error_percentage(imag(p_matrix[2, 2]), -1.25) < 0.001
    end
end
