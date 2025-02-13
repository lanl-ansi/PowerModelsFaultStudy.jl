
function modify_transformer_model!(transformer::Dict{String,<:Any}, parameters::Dict{String, <:Any})
    if haskey(parameters, "x1") || haskey(parameters, "x0")
        _calculate_x1x0_winding_matrix(transformer, parameters)
    end
end


function _calculate_z1z0_winding_matrix!(transformer::Dict{String,<:Any}, parameters::Dict{String, <:Any})
    z1 = parameters["z1"]
    z0 = parameters["z0"]
    ratio_1 = parameters["x1/r1"]
    ratio_0 = parameters["x0/r0"]
    x1 = sqrt((z1^2*ratio_1^2)/(1+ratio_1^2))
    r1 = x1/ratio_1
    x0 = sqrt((z0^2*ratio_0^2)/(1+ratio_0^2))
    r0 = x0/ratio_0
    z_pu = inv(_A)*[r0+x0*1im 0 0;0 r1+x1*1im 0;0 0 r1+x1*1im]
    lookup = Dict(
        (1, 1) => [1, 1],
        (1, 2) => [5, 3],
        (1, 3) => [9, 5],
        (2, 1) => [3, 2],
        (2, 2) => [7, 4],
        (2, 3) => [11, 6]
    )
    if transformer["phases"] == 3
        # z_1volt = z * 3 / transformer["sm_nom"][1] / 1000
        z_b = z_pu .* 3 / transformer["sm_nom"][1] / 1000
        b = [1 0 0; -1 0 0; 0 1 0; 0 -1 0; 0 0 1; 0 0 -1]
        y1 = b * inv(z_b) * transpose(b)
        n = zeros(Float64, 12, 6)
        a = zeros(Int64, 8, 12)
        for w = 1:2
            if transformer["configuration"][w] == _PMD.WYE
                w == 1 ? connections = transformer["f_connections"] : connections = transformer["t_connections"]
                for (_, k) in enumerate(connections)
                    if haskey(lookup, (w, k))
                        i = lookup[(w, k)][1]
                        j = lookup[(w, k)][2]
                        n[i, j] = 1 / (transformer["tm_nom"][w] / sqrt(3) * 1000 * transformer["tm_set"][w][k])
                        n[i+1, j] = -n[i, j]
                    end
                end
                if w == 1
                    a[1, 1] = a[2, 5] = a[3, 9] = a[4, 2] = a[4, 6] = a[4, 10] = 1
                else
                    a[5, 3] = a[6, 7] = a[7, 11] = a[8, 4] = a[8, 8] = a[8, 12] = 1
                end
            elseif transformer["configuration"][w] == _PMD.DELTA
                w == 1 ? connections = transformer["f_connections"] : connections = transformer["t_connections"]
                for (_, k) in enumerate(connections)
                    if haskey(lookup, (w, k))
                        i = lookup[(w, k)][1]
                        j = lookup[(w, k)][2]
                        n[i, j] = 1 / (transformer["tm_nom"][w] * 1000 * transformer["tm_set"][w][k])
                        n[i+1, j] = -n[i, j]
                    end
                end
                if transformer["configuration"][1] == _PMD.DELTA && transformer["configuration"][2] == _PMD.DELTA
                    if w == 1
                        a[1, 1] = a[1, 10] = a[2, 2] = a[2, 5] = a[3, 6] = a[3, 9] = 1
                        # a[1,2] = a[1,6] = a[2,5] = a[2,10] = a[3,9] = a[3,2] = 1
                    else
                        a[5, 3] = a[5, 12] = a[6, 4] = a[6, 7] = a[7, 8] = a[7, 11] = 1
                    end
                else
                    if w == 1
                        if transformer["leadlag"] == "lead"
                            if transformer["tm_nom"][1] > transformer["tm_nom"][2]
                                a[1, 1] = a[1, 10] = a[2, 2] = a[2, 5] = a[3, 6] = a[3, 9] = 1
                            else
                                a[1, 1] = a[1, 6] = a[2, 5] = a[2, 10] = a[3, 9] = a[3, 2] = 1
                            end
                        else
                            if transformer["tm_nom"][1] > transformer["tm_nom"][2]
                                a[1, 1] = a[1, 6] = a[2, 5] = a[2, 10] = a[3, 9] = a[3, 2] = 1
                            else
                                a[1,1] = a[1,10] = a[2,2] = a[2,5] = a[3,6] = a[3,9] = 1
                                # a[1,1] = a[1,6] = a[2,5] = a[2,10] = a[3,9] = a[3,2] = 1
                                # a[1,1] = a[1,6] = a[2,] = a[2,9] = a[3,10] = a[3,1] = 1
                            end
                        end
                    else
                        if transformer["configuration"][1] == _PMD.DELTA
                            a[5, 4] = a[5, 7] = a[6, 8] = a[6, 11] = a[7, 12] = a[7, 3] = 1
                            # a[5,3] = a[5,12] = a[6,4] = a[6,7] = a[7,8] = a[7,11] = 1
                        end
                    end
                end
            end
        end
        y_w = n * y1 * transpose(n)
        p_matrix = a * y_w * transpose(a)
        ybase = (transformer["sm_nom"][1] / 3) / (transformer["tm_nom"][2] * transformer["tm_set"][2][1] / sqrt(3))^2 / 1000
        if haskey(transformer["dss"], "%noloadloss")
            shunt = (transformer["g_sh"] + 1im * transformer["b_sh"]) * ybase
            p_matrix[5, 5] += shunt
            p_matrix[5, 8] -= shunt
            p_matrix[6, 6] += shunt
            p_matrix[6, 8] -= shunt
            p_matrix[7, 7] += shunt
            p_matrix[7, 8] -= shunt
            p_matrix[8, 5] -= shunt
            p_matrix[8, 6] -= shunt
            p_matrix[8, 7] -= shunt
            p_matrix[8, 8] += 3 * shunt
        end
        z_float = 1e-6
        p_matrix[1, 1] += z_float
        p_matrix[2, 2] += z_float
        p_matrix[3, 3] += z_float
        # p_matrix[4,4] += z_float
        p_matrix[5, 5] += z_float
        p_matrix[6, 6] += z_float
        p_matrix[7, 7] -= z_float
        # p_matrix[8,8] += z_float
        transformer["p_matrix"] = p_matrix
    elseif transformer["phases"] == 1
        z = sum(transformer["rw"]) + 1im .* transformer["xsc"][1]
        z_1volt = z * 1 / transformer["sm_nom"][1] / 1000
        b = [1; -1]
        y1 = b * 1 / z_1volt * transpose(b)
        n = zeros(Float64, 4, 2)
        a = zeros(Int64, 4, 4)
        for w = 1:2
            if transformer["configuration"][w] == _PMD.WYE
                i = lookup[(w, 1)][1]
                j = lookup[(w, 1)][2]
                n[i, j] = 1 / (transformer["tm_nom"][w] * 1000 * transformer["tm_set"][w][1])
                n[i+1, j] = -n[i, j]
                if w == 1
                    a[1, 1] = a[2, 2] = 1
                else
                    a[3, 3] = a[4, 4] = 1
                end
            end
        end
        y_w = n * y1 * transpose(n)
        p_matrix = a * y_w * transpose(a)
        transformer["p_matrix"] = p_matrix
    end
end