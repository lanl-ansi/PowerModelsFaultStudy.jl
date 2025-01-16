"""
    create_fault(type::String, bus::String, connections::Vector{Int}, resistance::Real, phase_resistance::Real)::Dict{String,Any}

Creates a fault dictionary given the `type` of fault, i.e., one of "3pq", "llg", the `bus` on which the fault is active,
the `connections` on which the fault applies, the `resistance` between the phase and ground, and the `phase_resistance`
between phases
"""
function create_fault(type::String, bus::String, connections::Vector{Int}, resistance::Real, phase_resistance::Real)::Dict{String,Any}
    return getfield(PowerModelsProtection, Symbol("_create_$(type)_fault"))(bus, connections, resistance, phase_resistance)
end


"""
    create_fault(type::String, bus::String, connections::Vector{Int}, resistance::Real, phase_resistance::Real)::Dict{String,Any}

Creates a fault dictionary given the `type` of fault, i.e., one of "3p", "ll", "lg", the `bus` on which the fault is active,
the `connections` on which the fault applies, the `resistance` between the phase and ground, in the case of "lg", or phase and phase.
"""
function create_fault(buses::Dict{String,Any})::Dict{String,Any}
    phase_resistance = 1e-4
    ground_resistance = 1e-4

    Gf_3p = zeros(Real, 3, 3)
    gp = 1 / phase_resistance
    gf = 1 / ground_resistance
    gtot = 3 * gp + gf
    gpp = gp^2 / gtot
    gpg = gp * gf / gtot

    for i in 1:3
        for j in 1:3
            if i == j
                Gf_3p[i, j] = 2 * gpp + gpg
            else
                Gf_3p[i, j] = -gpg
            end
        end
    end

    Gf_ll = zeros(Real, 2, 2)
    Gf_lg = zeros(Real, 2, 2)
    for i in 1:2
        for j in 1:2
            if i == j
                Gf_ll[i, j] = 1 / phase_resistance
                Gf_lg[i, j] = 1 / ground_resistance
            else
                Gf_ll[i, j] = -1 / phase_resistance
                Gf_lg[i, j] = -1 / ground_resistance
            end
        end
    end

    fault = Dict{String,Any}()
    for (indx, bus) in buses
        if !(occursin("virtual", bus["name"]))
            fault[indx] = Dict{String,Any}()
            if length(bus["terminals"]) > 3
                fault[indx]["3pg"] = Gf_3p
            elseif length(bus["terminals"]) == 3 && !(4 in bus["terminals"])
                fault[indx]["3pg"] = Gf_3p
            end
            fault[indx]["lg"] = Dict{Int,Any}()
            fault[indx]["ll"] = Dict{Tuple,Any}()
            for i = 1:length(bus["terminals"])
                if bus["grounded"][i] == 0
                    for j = i:length(bus["terminals"])
                        if bus["grounded"][j] == 0 && i != j
                            fault[indx]["ll"][(i, j)] = Gf_ll
                        end
                    end
                    fault[indx]["lg"][i] = Gf_lg
                end
            end
        end
    end
    return fault
end


"""
    create_fault(type::String, bus::String, connections::Vector{Int}, resistance::Real, phase_resistance::Real)::Dict{String,Any}

Creates a fault dictionary given the `type` of fault, i.e., one of "3p", "ll", "lg", the `bus` on which the fault is active,
the `connections` on which the fault applies, the `resistance` between the phase and ground, in the case of "lg", or phase and phase.
"""
function create_fault(type::String, bus::String, connections::Vector{Int}, resistance::Real)::Dict{String,Any}
    return getfield(PowerModelsProtection, Symbol("_create_$(type)_fault"))(bus, connections, resistance)
end


"creates a three-phase fault"
function _create_3p_fault(bus::String, connections::Vector{Int}, phase_resistance::Real)::Dict{String,Any}
    @assert length(connections) == 3
    ncnds = length(connections)

    Gf = zeros(Real, ncnds, ncnds)
    for i in 1:ncnds
        for j in 1:ncnds
            if i != j
                Gf[i, j] = -1 / phase_resistance
            else
                Gf[i, j] = 2 * (1 / phase_resistance)
            end
        end
    end

    return Dict{String,Any}(
        "bus" => bus,
        "connections" => connections,
        "fault_type" => "3p",
        "g" => Gf,
        "b" => zeros(Real, ncnds, ncnds),
        "status" => _PMD.ENABLED,
    )
end


"creates a three-phase-ground fault"
function _create_3pg_fault(bus::String, connections::Vector{Int}, resistance::Real, phase_resistance::Real)::Dict{String,Any}
    @assert length(connections) == 4
    ncnds = length(connections)

    Gf = zeros(Real, ncnds, ncnds)

    gp = 1 / phase_resistance
    gf = 1 / resistance
    gtot = 3 * gp + gf
    gpp = gp^2 / gtot
    gpg = gp * gf / gtot

    for i in 1:ncnds
        for j in 1:ncnds
            if i == j
                if i == 4
                    Gf[i, j] = 3 * gpg
                else
                    Gf[i, j] = 2 * gpp + gpg
                end
            else
                if i == 4 || j == 4
                    Gf[i, j] = -gpg
                else
                    Gf[i, j] = -gpp
                end
            end
        end
    end

    return Dict{String,Any}(
        "bus" => bus,
        "connections" => connections,
        "fault_type" => "3pg",
        "g" => Gf,
        "b" => zeros(Real, ncnds, ncnds),
        "status" => _PMD.ENABLED,
    )
end


"creates a line-line fault"
function _create_ll_fault(bus::String, connections::Vector{Int}, phase_resistance::Real)::Dict{String,Any}
    @assert length(connections) == 2
    ncnds = length(connections)

    Gf = zeros(Real, ncnds, ncnds)
    for i in 1:ncnds
        for j in 1:ncnds
            if i == j
                Gf[i, j] = 1 / phase_resistance
            else
                Gf[i, j] = -1 / phase_resistance
            end
        end
    end

    return Dict{String,Any}(
        "bus" => bus,
        "connections" => connections,
        "fault_type" => "ll",
        "g" => Gf,
        "b" => zeros(Real, ncnds, ncnds),
        "status" => _PMD.ENABLED,
    )
end


"creates a line-line-ground fault"
function _create_llg_fault(bus::String, connections::Vector{Int}, resistance::Real, phase_resistance::Real)::Dict{String,Any}
    @assert length(connections) == 3
    ncnds = length(connections)

    Gf = zeros(Real, ncnds, ncnds)

    gp = 1 / phase_resistance
    gf = 1 / resistance
    gtot = 2 * gp + gf
    gpp = gp^2 / gtot
    gpg = gp * gf / gtot

    for i in 1:ncnds
        for j in 1:ncnds
            if i == j
                if i == 3
                    Gf[i, j] = 2 * gpg
                else
                    Gf[i, j] = gpp + gpg
                end
            else
                if i == 3 || j == 3
                    Gf[i, j] = -gpg
                else
                    Gf[i, j] = -gpp
                end
            end
        end
    end

    return Dict{String,Any}(
        "bus" => bus,
        "connections" => connections,
        "fault_type" => "llg",
        "g" => Gf,
        "b" => zeros(Real, ncnds, ncnds),
        "status" => _PMD.ENABLED,
    )
end


"creates a line-ground fault"
function _create_lg_fault(bus::String, connections::Vector{Int}, resistance::Real)::Dict{String,Any}
    @assert length(connections) == 2
    ncnds = length(connections)

    Gf = zeros(Real, ncnds, ncnds)
    for i in 1:ncnds
        for j in 1:ncnds
            if i == j
                Gf[i, j] = 1 / resistance
            else
                Gf[i, j] = -1 / resistance
            end
        end
    end

    return Dict{String,Any}(
        "bus" => bus,
        "connections" => connections,
        "fault_type" => "lg",
        "g" => Gf,
        "b" => zeros(Real, ncnds, ncnds),
        "status" => _PMD.ENABLED,
    )
end


"""
    add_fault!(data::Dict{String,Any}, name::String, type::String, bus::String, connections::Vector{Int}, resistance::Real, phase_resistance::Real)

Creates a fault dictionary given the `type` of fault, i.e., one of "3p", "ll", "lg", the `bus` on which the fault is active,
the `connections` on which the fault applies, the `resistance` between the phase and ground, in the case of "lg", or phase and phase,
and adds it to `data["fault"]` under `"name"`
"""
function add_fault!(data::Dict{String,Any}, name::String, type::String, bus::String, connections::Vector{Int}, resistance::Real, phase_resistance::Real)
    if !haskey(data, "fault")
        data["fault"] = Dict{String,Any}()
    end

    fault = create_fault(type, bus, connections, resistance, phase_resistance)

    fault["name"] = name
    data["fault"][name] = fault
end


"""
    add_fault!(data::Dict{String,Any}, name::String, type::String, bus::String, connections::Vector{Int}, resistance::Real)

Creates a fault dictionary given the `type` of fault, i.e., one of "3pq", "llg", the `bus` on which the fault is active,
the `connections` on which the fault applies, the `resistance` between the phase and ground, and the `phase_resistance`
between phases, and adds it to `data["fault"]` under `"name"`
"""
function add_fault!(data::Dict{String,Any}, name::String, type::String, bus::String, connections::Vector{Int}, resistance::Real)
    if !haskey(data, "fault")
        data["fault"] = Dict{String,Any}()
    end

    fault = create_fault(type, bus, connections, resistance)

    fault["name"] = name
    data["fault"][name] = fault
end


"""
    _non_ideal_ct(relay_data,CT_data,Iabc)

Converts primary side current to the actual current going through relay coil based on non-ideal parameters.
Unused.
"""
function _non_ideal_ct(relay_data, CT_data, Iabc)
    Ze = CT_data["Ze"]
    R2 = CT_data["R2"]
    Zb = relay_data["Zb"]
    turns = CT_data["turns"]
    i_s = Iabc .* turns[2] ./ turns[1]
    i_r = i_s .* Ze ./ (Ze + Zb + R2)
    return i_r
end


"admittance model"

function _map_eng2math_mc_admittance_line!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "branch")
        for (name, branch) in data_math["branch"]
            z = branch["br_r"] + 1im .* branch["br_x"]
            y_from = branch["g_fr"] + 1im .* branch["b_fr"]
            y_to = branch["g_to"] + 1im .* branch["b_to"]
            z1 = inv(z) + y_from
            z2 = -inv(z)
            z3 = z2
            z4 = inv(z) + y_to
            branch["p_matrix"] = [z1 z2; z3 z4]
        end
    end
end


function _map_eng2math_mc_admittance_shunt!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "shunt")
        for (name, shunt) in data_math["shunt"]
            y = shunt["gs"] + 1im .* shunt["bs"]
            y1 = y
            y2 = -y
            y3 = y2
            y4 = y
            shunt["p_matrix"] = [y1 y2; y3 y4]
        end
    end
end


function _map_eng2math_mc_admittance_voltage_source!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "gen")
        for (name, gen) in data_math["gen"]
            if occursin("voltage_source", gen["source_id"])
                vsource = data_eng["voltage_source"][gen["dss"]["name"]]
                z = vsource["rs"] + 1im .* vsource["xs"]
                z1 = inv(z[1:3, 1:3])
                z2 = -inv(z[1:3, 1:3])
                gen["p_matrix"] = [z1 z2; z2 z1]
            end
        end
    end
end


function _map_eng2math_mc_admittance_generator!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "gen")
        for (name, gen) in data_math["gen"]
            if occursin("generator", gen["source_id"])
                if gen["gen_model"] == 1
                    y = zeros(Complex{Float64}, 4, 4)
                    for (i, pg) in enumerate(gen["pg"])
                        kv = gen["vnom_kv"]
                        s = -(pg + 1im * gen["qg"][i])
                        y_ = conj(s) / kv^2 / 1000
                        y[i, i] += y_
                        y[i, 4] -= y[i, i]
                        y[4, i] -= y[i, 4]
                        y[4, 4] += y[i, i]
                    end
                end
                gen["p_matrix"] = y
            end
        end
    end
end


function _map_eng2math_mc_admittance_solar!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "gen")
        for (name, gen) in data_math["gen"]
            if gen["element"] == SolarElement
                n = length(gen["connections"])
                y = zeros(Complex{Float64}, n, n)
                if gen["configuration"] == _PMD.WYE
                    for (i, connection) in enumerate(gen["connections"])
                        j = findall(x -> x == 4, gen["connections"])[1]
                        if connection != 4
                            if gen["grid_forming"]
                                zs = 0.0001 + 0.0005im
                                y[i, i] = 1 / zs
                                y[j, j] = y[i, i]
                            else
                                y[i, i] = 1 / 1e6im
                                y[j, j] = y[i, i]
                            end
                        end
                    end
                end
                gen["p_matrix"] = y
            end
        end
    end
end


function _map_eng2math_mc_admittance_load!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "load")
        for (name, load) in data_math["load"]
            n = length(load["connections"])
            y = zeros(Complex{Float64}, n, n)
            if load["configuration"] == _PMD.WYE
                if haskey(load, "pd") && haskey(load, "qd")
                    for (i, _i) in enumerate(load["connections"])
                        for (j, _j) in enumerate(load["connections"])
                            if _i != 4 && _j == 4
                                s = conj.(load["pd"][i] + 1im .* load["qd"][i])
                                _y = (s * data_math["settings"]["power_scale_factor"]) / (load["vnom_kv"] * data_math["settings"]["voltage_scale_factor"])^2
                                y[i, i] += _y
                                y[i, j] -= _y
                                y[j, i] -= _y
                                y[j, j] += _y
                            end
                        end
                    end
                end
                load["p_matrix"] = y
            elseif load["configuration"] == _PMD.DELTA
                if haskey(load, "pd") && haskey(load, "qd")
                    for (i, _i) in enumerate(load["connections"])
                        length(load["pd"]) == n ? s = conj.(load["pd"][i] + 1im .* load["qd"][i]) : s = conj.(load["pd"][1] + 1im .* load["qd"][1])
                        for (j, _j) in enumerate(load["connections"])
                            if i != j
                                _y = (s * data_math["settings"]["power_scale_factor"]) / (load["vnom_kv"] * data_math["settings"]["voltage_scale_factor"])^2
                                y[i, i] += _y
                                y[i, j] -= _y
                            end
                        end
                    end
                end
                load["p_matrix"] = y
            end
        end
    end
end


function _map_eng2math_mc_admittance_transformer!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    if haskey(data_math, "transformer")
        for (name, transformer) in data_math["transformer"]
            if typeof(transformer["t_bus"]) == Vector{Int}
                _map_eng2math_mc_admittance_3w_transformer!(transformer, data_math, data_eng; pass_props=pass_props)
            else
                _map_eng2math_mc_admittance_2w_transformer!(transformer, data_math, data_eng; pass_props=pass_props)
            end
        end
    end
end


function _map_eng2math_mc_admittance_2w_transformer!(transformer::Dict{String,<:Any}, data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    lookup = Dict(
        (1, 1) => [1, 1],
        (1, 2) => [5, 3],
        (1, 3) => [9, 5],
        (2, 1) => [3, 2],
        (2, 2) => [7, 4],
        (2, 3) => [11, 6]
    )
    if transformer["phases"] == 3
        z = sum(transformer["rw"]) + 1im .* transformer["xsc"][1]
        z_1volt = z * 3 / transformer["sm_nom"][1] / 1000
        z_b = [z_1volt 0 0; 0 z_1volt 0; 0 0 z_1volt]
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


function _map_eng2math_mc_admittance_3w_transformer!(transformer::Dict{String,<:Any}, data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    lookup = Dict(
        (1, 1) => [1, 1],
        (1, 2) => [7, 4],
        (1, 3) => [13, 7],
        (2, 1) => [3, 2],
        (2, 2) => [9, 5],
        (2, 3) => [15, 8],
        (3, 1) => [5, 3],
        (3, 2) => [11, 6],
        (3, 3) => [17, 9]
    )
    z_12 = transformer["rw"][1] + transformer["rw"][2] + 1im * transformer["xsc"][1]
    z_13 = transformer["rw"][1] + transformer["rw"][3] + 1im * transformer["xsc"][2]
    z_23 = transformer["rw"][1] + 1im * transformer["xsc"][3]
    phases = isa(transformer["dss"]["phases"], String) ? parse(Int, transformer["dss"]["phases"]) : transformer["dss"]["phases"]
    if phases == 3
        z_1volt_base = 3 / transformer["sm_nom"][1] / 1000
        z_b = [
            z_12*z_1volt_base z_23*z_1volt_base 0 0 0 0; z_23*z_1volt_base z_13*z_1volt_base 0 0 0 0;
            0 0 z_12*z_1volt_base z_23*z_1volt_base 0 0; 0 0 z_23*z_1volt_base z_13*z_1volt_base 0 0;
            0 0 0 0 z_12*z_1volt_base z_23*z_1volt_base; 0 0 0 0 z_23*z_1volt_base z_13*z_1volt_base
        ]
        b = [1 1 0 0 0 0; -1 0 0 0 0 0; 0 -1 0 0 0 0; 0 0 1 1 0 0; 0 0 -1 0 0 0; 0 0 0 -1 0 0; 0 0 0 0 1 1; 0 0 0 0 -1 0; 0 0 0 0 0 -1]
        y1 = b * inv(z_b) * transpose(b)
        n = zeros(Float64, 18, 9)
        a = zeros(Int64, 12, 18)
        for w = 1:3
            if transformer["configuration"][w] == _PMD.WYE
                w == 1 ? connections = transformer["f_connections"] : connections = transformer["t_connections"][w-1]
                for (_, k) in enumerate(connections)
                    if haskey(lookup, (w, k))
                        i = lookup[(w, k)][1]
                        j = lookup[(w, k)][2]
                        n[i, j] = 1 / (transformer["tm_nom"][w] / sqrt(3) * 1000 * transformer["tm_set"][w][k])
                        n[i+1, j] = -n[i, j]
                    end
                end
                if w == 1
                    # a[1,1] = a[2,5] = a[3,9] = a[4,2] = a[4,6] = a[4,10] = 1
                elseif w == 2
                    a[5, 3] = a[6, 9] = a[7, 15] = a[8, 4] = a[8, 10] = a[8, 16] = 1
                else
                    a[9, 5] = a[10, 11] = a[11, 17] = a[12, 6] = a[12, 12] = a[12, 18] = 1
                end
            elseif transformer["configuration"][w] == _PMD.DELTA
                w == 1 ? connections = transformer["f_connections"] : connections = transformer["t_connections"][w-1]
                for (_, k) in enumerate(connections)
                    if haskey(lookup, (w, k))
                        i = lookup[(w, k)][1]
                        j = lookup[(w, k)][2]
                        n[i, j] = 1 / (transformer["tm_nom"][w] * 1000 * transformer["tm_set"][w][k])
                        n[i+1, j] = -n[i, j]
                    end
                end
                if w == 1
                    a[1, 1] = a[1, 8] = a[2, 7] = a[2, 14] = a[3, 13] = a[3, 2] = 1
                else
                    # a[5,3] = a[6,7] = a[7,11] = a[8,4] = a[8,8] = a[8,12] = 1
                end
            end
        end
        y_w = n * y1 * transpose(n)
        p_matrix = a * y_w * transpose(a)
        ybase = (transformer["sm_nom"][1] / 3) / (transformer["tm_nom"][2] * transformer["tm_set"][2][1] / sqrt(3))^2 / 1000
        if haskey(transformer["dss"], "%noloadloss")
            shunt = (transformer["g_sh"] + 1im * transformer["b_sh"])*ybase
            p_matrix[5,5] += shunt
            p_matrix[5,8] -= shunt
            p_matrix[6,6] += shunt
            p_matrix[6,8] -= shunt
            p_matrix[7,7] += shunt
            p_matrix[7,8] -= shunt
            p_matrix[8,5] -= shunt
            p_matrix[8,6] -= shunt
            p_matrix[8,7] -= shunt
            p_matrix[8,8] += 3*shunt
        end
        z_float = 1e-6
        p_matrix[1,1] += z_float
        p_matrix[2,2] += z_float
        p_matrix[3,3] += z_float
        # p_matrix[4,4] += z_float
        p_matrix[5,5] += z_float
        p_matrix[6,6] += z_float
        p_matrix[7,7] -= z_float
        transformer["p_matrix"] = p_matrix
    elseif transformer["dss"]["phases"] == 1
        z_1volt_base = 1/transformer["sm_nom"][1]/1000
        z_b = [z_12*z_1volt_base z_23*z_1volt_base;z_23*z_1volt_base z_13*z_1volt_base]
        b = [1 1 ;-1 0;0 -1]
        y1 = b*inv(z_b)*transpose(b)
        n = zeros(Float64, 6, 3)
        for w = 1:3
            if transformer["configuration"][w] == _PMD.WYE
                i = lookup[(w, 1)][1]
                j = lookup[(w, 1)][2]
                n[i, j] = 1 / (transformer["tm_nom"][w] * 1000 * transformer["tm_set"][w][1])
                n[i+1, j] = -n[i, j]
            end
        end
        y_w = n * y1 * transpose(n)
        p_matrix = y_w
        ybase = (transformer["sm_nom"][1]) / (transformer["tm_nom"][2] * transformer["tm_set"][2][1])^2 / 1000
        if haskey(transformer["dss"], "%noloadloss")
            shunt = (transformer["g_sh"] + 1im * transformer["b_sh"]) * ybase
            p_matrix[3, 3] += shunt
            p_matrix[3, 4] -= shunt
            p_matrix[4, 4] += shunt
            p_matrix[4, 3] -= shunt
        end
        transformer["p_matrix"] = p_matrix
    end
end
