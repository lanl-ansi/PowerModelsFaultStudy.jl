
function build_mc_admittance_matrix(data::Dict{String,<:Any}; loading=loading, )
    add_mc_admittance_map!(data)
    admit_matrix = Dict{Tuple,Complex{Float64}}()
    add_mc_generator_p_matrix!(data, admit_matrix)
    add_mc_branch_p_matrix!(data, admit_matrix)
    add_mc_transformer_p_matrix!(data, admit_matrix)
    loading ? add_mc_load_p_matrix!(data, admit_matrix) : nothing
    add_mc_shunt_p_matrix!(data, admit_matrix)
    # --> need to finish other devices
    return _convert_sparse_matrix(admit_matrix)
end

function add_mc_admittance_map!(data_math::Dict{String,<:Any})
    admittance_map = Dict{Tuple,Int}()
    admittance_type = Dict{Int,Any}()
    indx = 1
# TODO determine if bus is inactive
    for (_, bus) in data_math["bus"]
        id = bus["index"]
        for (i, t) in enumerate(bus["terminals"])
            if bus["bus_type"] != 4
                if !(bus["grounded"][i])
                    admittance_map[(id, t)] = indx
                    admittance_type[indx] = bus["bus_type"]
                    indx += 1
                end
            end
        end
    end
    data_math["admittance_map"] = admittance_map
    data_math["admittance_type"] = admittance_type
    end


function  add_mc_generator_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
    for (_, gen) in data["gen"]
        bus = gen["gen_bus"]
        for (_i, i) in enumerate(gen["connections"])
            if haskey(data["admittance_map"], (bus, i))
                for (_j, j) in enumerate(gen["connections"])
                    if haskey(data["admittance_map"], (bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])) ? admit_matrix[(data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])] += gen["p_matrix"][_i,_j] : admit_matrix[(data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])] = gen["p_matrix"][_i,_j]
                    end
                end
            end
        end
    end
end


function add_mc_voltage_source_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}}, gen::Dict{String,<:Any})
    bus = gen["gen_bus"]
    for (_i, i) in enumerate(gen["connections"])
        if haskey(data["admittance_map"], (bus, i))
            for (_j, j) in enumerate(gen["connections"])
                if haskey(data["admittance_map"], (bus, j))
                    haskey(admit_matrix, (data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])) ? admit_matrix[(data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])] += gen["p_matrix"][_i,_j] : admit_matrix[(data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])] = gen["p_matrix"][_i,_j]
                end
            end
        end
    end
end



function add_mc_branch_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
    for (indx, branch) in data["branch"]
        f_bus = branch["f_bus"]
        for (_i, i) in enumerate(branch["f_connections"])
            if haskey(data["admittance_map"], (f_bus, i))
                for (_j, j) in enumerate(branch["f_connections"])
                    if haskey(data["admittance_map"], (f_bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])] += branch["p_matrix"][_i,_j] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])] = branch["p_matrix"][_i,_j]
                    end
                end
                t_bus = branch["t_bus"]
                for (_j, j) in enumerate(branch["t_connections"])
                    if haskey(data["admittance_map"], (t_bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] += branch["p_matrix"][_i,_j+length(branch["t_connections"])] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] = branch["p_matrix"][_i,_j+length(branch["t_connections"])]
                    end
                end
            end
        end
        t_bus = branch["t_bus"]
        for (_i, i) in enumerate(branch["t_connections"])
            if haskey(data["admittance_map"], (t_bus, i))
                for (_j, j) in enumerate(branch["t_connections"])
                    if haskey(data["admittance_map"], (t_bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] += branch["p_matrix"][_i+length(branch["t_connections"]),_j+length(branch["t_connections"])] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] = branch["p_matrix"][_i+length(branch["t_connections"]),_j+length(branch["t_connections"])]
                    end
                end
                f_bus = branch["f_bus"]
                for (_j, j) in enumerate(branch["f_connections"])
                    if haskey(data["admittance_map"], (f_bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] += branch["p_matrix"][_i+length(branch["f_connections"]),_j] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] = branch["p_matrix"][_i+length(branch["f_connections"]),_j]
                    end
                end
            end
        end
    end
end


function add_mc_transformer_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
    for (indx, transformer) in data["transformer"]
if typeof(transformer["t_bus"]) == Vector{Int}
            add_mc_3w_transformer_p_matrix!(transformer, data, admit_matrix)
        else
            add_mc_2w_transformer_p_matrix!(transformer, data, admit_matrix)
        end
    end
end


function add_mc_2w_transformer_p_matrix!(transformer::Dict{String,<:Any}, data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
        f_bus = transformer["f_bus"]
        for (_i, i) in enumerate(transformer["f_connections"])
            if haskey(data["admittance_map"], (f_bus, i))
                for (_j, j) in enumerate(transformer["f_connections"])
                    if haskey(data["admittance_map"], (f_bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])] += transformer["p_matrix"][_i,_j] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])] = transformer["p_matrix"][_i,_j]
                    end
                end
                t_bus = transformer["t_bus"]
                for (_j, j) in enumerate(transformer["t_connections"])
                    if haskey(data["admittance_map"], (t_bus, j))
                        if transformer["phases"] == 3
                            haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][_i,_j+4] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][_i,_j+4]
                        elseif transformer["phases"] == 1
                            haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][_i,_j+2] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][_i,_j+2]
                        end
                    end
                end
            end
        end
        t_bus = transformer["t_bus"]
        for (_i, i) in enumerate(transformer["t_connections"])
            if haskey(data["admittance_map"], (t_bus, i))
                for (_j, j) in enumerate(transformer["t_connections"])
                    if haskey(data["admittance_map"], (t_bus, j))
                        if transformer["phases"] == 3
                            haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][_i+4,_j+4] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][_i+4,_j+4]
                        elseif transformer["phases"] == 1
                            haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][_i+2,_j+2] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][_i+2,_j+2]
                        end
                    end
                end
                f_bus = transformer["f_bus"]
                for (_j, j) in enumerate(transformer["f_connections"])
                    if haskey(data["admittance_map"], (f_bus, j))
                        if transformer["phases"] == 3
                            haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] += transformer["p_matrix"][_i+4,_j] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] = transformer["p_matrix"][_i+4,_j]
                        elseif transformer["phases"] == 1
                            haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] += transformer["p_matrix"][_i+2,_j] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] = transformer["p_matrix"][_i+2,_j]
                        end
                    end
                end
            end
        end
    end


function add_mc_3w_transformer_p_matrix!(transformer::Dict{String,<:Any}, data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
    f_bus = transformer["f_bus"]
    phases = isa(transformer["dss"]["phases"], String) ? parse(Int, transformer["dss"]["phases"]) : transformer["dss"]["phases"]
    for (_i, i) in enumerate(transformer["f_connections"])
        if haskey(data["admittance_map"], (f_bus, i))
            for (_j, j) in enumerate(transformer["f_connections"])
                if haskey(data["admittance_map"], (f_bus, j))
                    haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])] += transformer["p_matrix"][_i,_j] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)])] = transformer["p_matrix"][_i,_j]
                end
            end
            for (indx, t_bus) in enumerate(transformer["t_bus"])
                for (_, t_connections) in enumerate(transformer["t_connections"][indx])
                    for (_j, j) in enumerate(t_connections)
                        if haskey(data["admittance_map"], (t_bus, j))
                            if phases == 3
                                haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][_i,_j+4] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][_i,_j+4]
                            elseif phases == 1
                                haskey(admit_matrix, (data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][_i,j*3] : admit_matrix[(data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][_i,j*3]
                            end
                        end
                    end
                end
            end
        end
    end
    for (indx, t_bus) in enumerate(transformer["t_bus"])
        for (_, t_connections) in enumerate(transformer["t_connections"][indx])
            for (_i, i) in enumerate(t_connections)
                if haskey(data["admittance_map"], (t_bus, i))
                    for (indx_i, _) in enumerate(transformer["t_connections"])
                        for (_j, j) in enumerate(transformer["t_connections"][indx_i])
                        if haskey(data["admittance_map"], (t_bus, j))
                            if phases == 3
                                haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][_i+4,_j+4] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][_i+4,_j+4]
                            elseif phases == 1
                                if _i == indx
                                        haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][i*3,j*3] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][i*3,j*3]
                                    else
                                        haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] += transformer["p_matrix"][i*3,j*3] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)])] = transformer["p_matrix"][i*3,j*3]
                                    end
                                end
                            end
                        end
                    end
                    f_bus = transformer["f_bus"]
                    for (_j, j) in enumerate(transformer["f_connections"])
                        if haskey(data["admittance_map"], (f_bus, j))
                            if phases == 3
                                haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] += transformer["p_matrix"][_i+4,_j] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] = transformer["p_matrix"][_i+4,_j]
                            elseif phases == 1
                                haskey(admit_matrix, (data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])) ? admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] += transformer["p_matrix"][i*3,_j] : admit_matrix[(data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)])] = transformer["p_matrix"][i*3,_j]
                            end
                        end
                    end
                end
            end
        end
    end
end


function add_mc_load_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
    for (_, load) in data["load"]
        bus = load["load_bus"]
        for (_i, i) in enumerate(load["connections"])
            if haskey(data["admittance_map"], (bus, i))
                for (_j, j) in enumerate(load["connections"])
                    if haskey(data["admittance_map"], (bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])) ? admit_matrix[(data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])] += load["p_matrix"][_i,_j] : admit_matrix[(data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])] = load["p_matrix"][_i,_j]
                    end
                end
            end
        end
    end
end


function add_mc_shunt_p_matrix!(data::Dict{String,<:Any}, admit_matrix::Dict{Tuple,Complex{Float64}})
    for (_, shunt) in data["shunt"]
        bus = shunt["shunt_bus"]
        for (_i, i) in enumerate(shunt["connections"])
            if haskey(data["admittance_map"], (bus, i))
                for (_j, j) in enumerate(shunt["connections"])
                    if haskey(data["admittance_map"], (bus, j))
                        haskey(admit_matrix, (data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])) ? admit_matrix[(data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])] += shunt["p_matrix"][_i,_j] : admit_matrix[(data["admittance_map"][(bus, i)], data["admittance_map"][(bus, j)])] = shunt["p_matrix"][_i,_j]
                    end
                end
            end
        end
    end
end


function build_mc_voltage_vector(data::Dict{String,<:Any})
    v = zeros(Complex{Float64}, length(keys(data["admittance_type"])), 1)
    for (indx, bus) in data["bus"]
        if haskey(bus, "vm")
            for (_j, j) in enumerate(bus["terminals"])
                if haskey(data["admittance_map"], (bus["bus_i"], j))
                    v[data["admittance_map"][(bus["bus_i"], j)],1] = bus["vm"][_j] * data["settings"]["voltage_scale_factor"] * exp(1im*bus["va"][_j]*pi/180)
                end
            end
        else
            for (_j, j) in enumerate(bus["terminals"])
                if haskey(data["admittance_map"], (bus["bus_i"], j))
                    v[data["admittance_map"][(bus["bus_i"], j)],1] = bus["vbase"] * data["settings"]["voltage_scale_factor"] * exp(1im*-2/3*pi*(j-1))
                end
            end
        end
    end
    return v
end


"""
    builds current vector for constant current injection sources
"""
function build_mc_current_vector(data::Dict{String,<:Any}, v::Matrix{ComplexF64})
    i = zeros(Complex{Float64}, length(keys(data["admittance_type"])), 1)
    # TODO look at models for gen and how they are defined
    for (_, gen) in data["gen"]
        if gen["element"] == SolarElement
            if gen["gen_status"] == 1 && gen["grid_forming"]
                bus = data["bus"][string(gen["gen_bus"])]
                n = 3 #TODO fix when 4 is included
                p_matrix = zeros(Complex{Float64}, n, n)
                va = [0 -2*pi/3 2*pi/3]
                for i in gen["connections"]
                    if i != 4
                        v[i,1] = bus["vbase"] * data["settings"]["voltage_scale_factor"] * exp(1im * va[i])
                        for j in gen["connections"]
                            if j != 4
                                p_matrix[i,j] = gen["p_matrix"][i,j]
                            end
                        end
                    end
                end
                i_update = p_matrix * v
                for (_j, j) in enumerate(gen["connections"])
                    if (gen["gen_bus"], j) in keys(data["admittance_map"])
                        i[data["admittance_map"][(gen["gen_bus"], j)],1] = i_update[_j,1]
                    end
                end
            end
        elseif gen["element"] == VoltageSourceElement
            if gen["gen_status"] == 1
                bus = data["bus"][string(gen["gen_bus"])]
                n = 3 #TODO fix when 4 is included
                p_matrix = zeros(Complex{Float64}, n, n)
                _v = zeros(Complex{Float64}, n, 1)
                for i in gen["connections"]
                    if i != 4
                        _v[i,1] = bus["vm"][i] * data["settings"]["voltage_scale_factor"] * exp(1im * bus["va"][i] * pi/180)
                        for j in gen["connections"]
                            if j != 4
                                p_matrix[i,j] = gen["p_matrix"][i,j]
                            end
                        end
                    end
                end
                i_update = p_matrix * _v
                for (_j, j) in enumerate(gen["connections"])
                    if (gen["gen_bus"], j) in keys(data["admittance_map"])
                        i[data["admittance_map"][(gen["gen_bus"], j)],1] = i_update[_j,1]
                    end
                end
            end
        end
    end
    return i
end


" defines i based on setting reg points vs setting current based on voltage"
function build_mc_delta_current_control_vector(data, v)
    (n, m) = size(v)
    delta_i = zeros(Complex{Float64}, n, 1)
    build_mc_delta_current_control_inverter!(delta_i, v, data)
    return _SP.sparse(delta_i)
end


function build_mc_delta_current_control_inverter!(delta_i, v, data)
    for (_, gen) in data["gen"]
        if gen["element"] == SolarElement
            if gen["grid_forming"]
                calc_mc_delta_current_gfmi!(gen, delta_i, v, data)
            else
                calc_mc_delta_current_gfli!(gen, delta_i, v, data)
            end
        end
    end
end



function calc_mc_delta_current_control_gfmi!(gen, delta_i, v, data)
    bus = gen["gen_bus"]
    v_solar = [gen["vg"][1]; gen["vg"][1]*exp(-2im/3*pi); gen["vg"][1]*exp(2im/3*pi)]
    i_vsource = gen["vs_matrix"][1:3, 1:3] * v_solar
    pg = gen["pg"]
    haskey(gen, "qg") ? qg = gen["qg"] : qg = gen["pg"].*0.0
    s = pg .+ 1im .* qg
    s_seq = s[1]
    v_seq = inv(_A)*v_solar
    i_seq = conj(s_seq/v_seq[2])
    i_inj = _A*[0;i_seq;0]
    s = [v_solar[1,1]*conj(i_inj[1,1]);v_solar[2,1]*conj(i_inj[2,1]);v_solar[3,1]*conj(i_inj[3,1])]
    for (_j, j) in enumerate(gen["connections"])
        if j != 4
            delta_i[data["admittance_map"][(bus, j)], 1] += i_inj[j]
        end
    end
end


function update_mc_delta_current_control_vector(model, v, y)
    (n, m) = size(v)
    delta_i = zeros(Complex{Float64}, n, 1)
    # update_mc_delta_current_gfmi_control!(delta_i, v, model.data)
    update_mc_delta_current_inverter!(delta_i, v, model.data)
    y = update_mc_delta_current_transformer!(v, y, model.data)
    return delta_i, y
end


function update_mc_delta_current_gfmi_control!(delta_i, v, data)
    for (_, gen) in data["gen"]
        if occursin("solar.", gen["source_id"])
            if gen["grid_forming"]
                if gen["pv_model"] == 4
                    update_mc_delta_current_gfmi_control_vbalance!(gen, delta_i, v, data)
                end
            end
        end
    end
end


function update_mc_delta_current_transformer!(v, y, data)
    if haskey(data["controls"], "transformer")
        for (id, control) in data["controls"]["transformer"]
            if control == "reg"
                y = update_mc_delta_current_regulator_control!(id, v, y, data)
            end
        end
    end
    return y
end

function update_mc_delta_current_regulator_control!(id, v, y, data)
    transformer = data["transformer"][id]
    if !(haskey(transformer, "p_last"))
        transformer["p_last"] = transformer["p_matrix"]
    end
    f_bus = transformer["f_bus"]
    t_bus = transformer["t_bus"]
    _y = transformer["p_last"]
    v_size = size(_y)[1]
    v_t = zeros(Complex{Float64}, v_size, 1)
    indx = 1
    for (_i, i) in enumerate(transformer["f_connections"])
        if haskey(data["admittance_map"], (f_bus, i))
            v_t[indx,1] = v[data["admittance_map"][(f_bus, i)], 1]
        end
        indx += 1
    end
    for (_i, i) in enumerate(transformer["t_connections"])
        if haskey(data["admittance_map"], (t_bus, i))
            v_t[indx,1] = v[data["admittance_map"][(t_bus, i)], 1]
        end
        indx += 1
    end
    i_t = _y*v_t
    transformer["current"] = i_t
    taps = zeros(length(transformer["t_connections"]), 1)
    for (_i, i) in enumerate(transformer["t_connections"]) # only supports tap on 2nd winding and pmd issue of 1 filled no others
        if haskey(data["admittance_map"], (t_bus, i))
            ptratio = transformer["controls"]["ptratio"][2][1]
            ctratio = transformer["controls"]["ctprim"][2][1] / 5
            z = (transformer["controls"]["r"][2][1] + transformer["controls"]["x"][2][1]*1im) / 5 
            i_comp = i_t[length(transformer["f_connections"]) + _i]*exp(1im*pi) / ctratio
            v_reg = v_t[length(transformer["f_connections"]) + _i,1] / ptratio
            v_drop = z * i_comp
            v_r = v_reg - v_drop
            if abs(v_r) > transformer["controls"]["vreg"][2][1] + transformer["controls"]["band"][2][1]/2
                tap = (transformer["controls"]["vreg"][2][1] + transformer["controls"]["band"][2][1]/2 - abs(v_r))/.75
            elseif abs(v_r) < transformer["controls"]["vreg"][2][1] - transformer["controls"]["band"][2][1]/2
                tap = (transformer["controls"]["vreg"][2][1] - transformer["controls"]["band"][2][1]/2 - abs(v_r))/.75
            else
                tap = 0.0
            end
            taps[_i,1] = tap
        end
    end
    lookup = Dict(
        (1,1) => [1,1],
        (1,2) => [5,3],
        (1,3) => [9,5],
        (2,1) => [3,2],
        (2,2) => [7,4],
        (2,3) => [11,6]
    ) 
    if transformer["phases"] == 1
        if  ceil(taps[1]) * .2*transformer["tm_step"][2][1] < transformer["tm_ub"][2][1]
            transformer["tm_set"][2][1] += ceil(taps[1]) * .2*transformer["tm_step"][2][1]
        else
            transformer["tm_set"][2][1] = transformer["tm_ub"][2][1]
        end
        z = sum(transformer["rw"]) + 1im .* transformer["xsc"][1]
        z_1volt= z * 1/transformer["sm_nom"][1]/1000
        b = [1 ;-1]
        y1 = b*1/z_1volt*transpose(b)
        n = zeros(Float64, 4, 2)
        a = zeros(Int64,4,4)
        for w = 1:2
            if transformer["configuration"][w] == _PMD.WYE
                i = lookup[(w,1)][1]
                j = lookup[(w,1)][2]
                n[i,j] = 1/(transformer["tm_nom"][w]*1000*transformer["tm_set"][w][1])
                n[i+1,j] = - n[i,j]
                if w == 1
                    a[1,1] = a[2,2] = 1
                else
                    a[3,3] = a[4,4] = 1
                end
            end
        end
        y_w = n*y1*transpose(n)
        p_matrix = a*y_w*transpose(a)
    elseif transformer["phases"] == 3
        for i = 1:3
            tap = transformer["tm_set"][2][i] + ceil(taps[i]) * .2*transformer["tm_step"][2][i]
            if tap < transformer["tm_lb"][2][i]
                tap = transformer["tm_lb"][2][i]
            elseif tap > transformer["tm_ub"][2][i]
                tap = transformer["tm_ub"][2][i]
            end
            transformer["tm_set"][2][i] = tap
        end
        z = sum(transformer["rw"]) + 1im .* transformer["xsc"][1]
        z_1volt= z * 3/transformer["sm_nom"][1]/1000
        z_b = [z_1volt 0 0;0 z_1volt 0;0 0 z_1volt]
        b = [1 0 0;-1 0 0;0 1 0;0 -1 0;0 0 1;0 0 -1]
        y1 = b*inv(z_b)*transpose(b)
        n = zeros(Float64, 12, 6)
        a = zeros(Int64,8,12)
        for w = 1:2
            if transformer["configuration"][w] == _PMD.WYE 
                w == 1 ? connections = transformer["f_connections"] : connections = transformer["t_connections"]
                for (_,k) in enumerate(connections)
                    if haskey(lookup, (w,k))
                        i = lookup[(w,k)][1]
                        j = lookup[(w,k)][2]
                        n[i,j] = 1/(transformer["tm_nom"][w]/sqrt(3)*1000*transformer["tm_set"][w][k])
                        n[i+1,j] = - n[i,j]
                    end
                end
                if w == 1
                    a[1,1] = a[2,5] = a[3,9] = a[4,2] = a[4,6] = a[4,10] = 1
                else
                    a[5,3] = a[6,7] = a[7,11] = a[8,4] = a[8,8] = a[8,12] = 1
                end
            elseif transformer["configuration"][w] == _PMD.DELTA
                w == 1 ? connections = transformer["f_connections"] : connections = transformer["t_connections"]
                for (_,k) in enumerate(connections)
                    if haskey(lookup, (w,k))
                        i = lookup[(w,k)][1]
                        j = lookup[(w,k)][2]
                        n[i,j] = 1/(transformer["tm_nom"][w]*1000*transformer["tm_set"][w][k])
                        n[i+1,j] = - n[i,j]
                    end
                end
                if transformer["configuration"][1] == _PMD.DELTA && transformer["configuration"][2] == _PMD.DELTA
                    if w == 1
                        a[1,1] = a[1,10] = a[2,2] = a[2,5] = a[3,6] = a[3,9] = 1
                        # a[1,2] = a[1,6] = a[2,5] = a[2,10] = a[3,9] = a[3,2] = 1
                    else
                        a[5,3] = a[5,12] = a[6,4] = a[6,7] = a[7,8] = a[7,11] = 1
                    end
                else
                    if w == 1
                        if transformer["leadlag"] == "lead"
                            if transformer["tm_nom"][1] > transformer["tm_nom"][2]
                                a[1,1] = a[1,10] = a[2,2] = a[2,5] = a[3,6] = a[3,9] = 1
                            else
                                a[1,1] = a[1,6] = a[2,5] = a[2,10] = a[3,9] = a[3,2] = 1
                            end
                        else
                            if transformer["tm_nom"][1] > transformer["tm_nom"][2]
                                a[1,1] = a[1,6] = a[2,5] = a[2,10] = a[3,9] = a[3,2] = 1
                            else
                                # a[1,1] = a[1,10] = a[2,2] = a[2,5] = a[3,6] = a[3,9] = 1
                                a[1,1] = a[1,6] = a[2,5] = a[2,10] = a[3,9] = a[3,2] = 1
                                # a[1,1] = a[1,6] = a[2,] = a[2,9] = a[3,10] = a[3,1] = 1
                            end
                        end
                    else
                        if transformer["configuration"][1] == _PMD.DELTA 
                            a[5,4] = a[5,7] = a[6,8] = a[6,11] = a[7,12] = a[7,3] = 1
                            # a[5,3] = a[5,12] = a[6,4] = a[6,7] = a[7,8] = a[7,11] = 1  
                        end
                    end
                end
            end
        end
        y_w = n*y1*transpose(n)
        p_matrix = a*y_w*transpose(a)
        ybase = (transformer["sm_nom"][1]/3) / (transformer["tm_nom"][2]*transformer["tm_set"][2][1]/sqrt(3))^2 /1000
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
        # p_matrix[8,8] += z_float
    end
    for (_i, i) in enumerate(transformer["f_connections"])
        if haskey(data["admittance_map"], (f_bus, i))
            for (_j, j) in enumerate(transformer["f_connections"])
                if haskey(data["admittance_map"], (f_bus, j))
                    y[data["admittance_map"][(f_bus, i)], data["admittance_map"][(f_bus, j)]] +=  p_matrix[_i,_j] - transformer["p_last"][_i,_j]
                end
            end
            for (_j, j) in enumerate(transformer["t_connections"])
                if haskey(data["admittance_map"], (t_bus, j))
                    if transformer["phases"] == 3
                        y[data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)]] += p_matrix[_i,_j+4] - transformer["p_last"][_i,_j+4]
                    elseif transformer["phases"] == 1
                        y[data["admittance_map"][(f_bus, i)], data["admittance_map"][(t_bus, j)]] += p_matrix[_i,_j+2] - transformer["p_last"][_i,_j+2] 
                    end
                end
            end
        end
    end
    for (_i, i) in enumerate(transformer["t_connections"])
        if haskey(data["admittance_map"], (t_bus, i))
            for (_j, j) in enumerate(transformer["t_connections"])
                if haskey(data["admittance_map"], (t_bus, j))
                    if transformer["phases"] == 3
                        y[data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)]] += p_matrix[_i+4,_j+4] - transformer["p_last"][_i+4,_j+4]
                    elseif transformer["phases"] == 1
                        y[data["admittance_map"][(t_bus, i)], data["admittance_map"][(t_bus, j)]] += p_matrix[_i+2,_j+2] - transformer["p_last"][_i+2,_j+2]
                    end
                end
            end
            for (_j, j) in enumerate(transformer["f_connections"])
                if haskey(data["admittance_map"], (f_bus, j))
                    if transformer["phases"] == 3
                        y[data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)]] += p_matrix[_i+4,_j] - transformer["p_last"][_i+4,_j]
                    elseif transformer["phases"] == 1
                        y[data["admittance_map"][(t_bus, i)], data["admittance_map"][(f_bus, j)]] += p_matrix[_i+2,_j] - transformer["p_last"][_i+2,_j]
                    end
                end
            end
        end
    end
    transformer["p_last"] = p_matrix
    return y
end


function update_mc_delta_current_gfmi_control_vbalance!(gen, delta_i, v, data)
    transformer = data["transformer"][gen["transformer_id"]]
    f_bus = data["bus"]["$(transformer["f_bus"])"]
    t_bus = data["bus"]["$(transformer["t_bus"])"]
    y = transformer["p_matrix"][5:8,1:8]
    _v = zeros(Complex{Float64}, 8, 1)
    indx = 1
    for (_j, j) in enumerate(f_bus["terminals"])
        if haskey(data["admittance_map"], (f_bus["bus_i"], j))
            _v[indx, 1] = v[data["admittance_map"][(f_bus["bus_i"], j)], 1]
        else
            _v[indx, 1] = 0.0
        end
        indx += 1
    end
    for (_j, j) in enumerate(t_bus["terminals"])
        if haskey(data["admittance_map"], (t_bus["bus_i"], j))
            _v[indx, 1] = v[data["admittance_map"][(t_bus["bus_i"], j)], 1]
        else
            _v[indx, 1] = 0.0
        end
        indx += 1
    end
    i_abc = (transformer["p_matrix"][1:4,1:8]*_v)
    i_012 = inv(_A) * [i_abc[1,1];i_abc[2,1];i_abc[3,1]]
    v_012 = inv(_A) * [_v[1,1];_v[2,1];_v[3,1]]
    z_1 = v_012[2,1]/i_012[2,1]
    z_2 = v_012[3,1]/i_012[3,1]
    v_inv = [f_bus["vbase"]; f_bus["vbase"]*exp(-2im/3*pi); f_bus["vbase"]*exp(2im/3*pi)] .* data["settings"]["voltage_scale_factor"]
    v_012 = inv(_A) * v_inv
    i_012 = [0;v_012[2,1]/z_1;v_012[3,1]/z_2]
    i_inj = _A*[0;v_012[2,1]/z_1;v_012[3,1]/z_2]
    for (_j, j) in enumerate(gen["connections"])
        if j != 4
            if abs(i_inj[j]) > gen["i_max"][1]
                delta_i[data["admittance_map"][(gen["gen_bus"], j)], 1] += gen["i_max"][1]* exp(1im*angle(i_inj[j]))
            else
                delta_i[data["admittance_map"][(gen["gen_bus"], j)], 1] += i_inj[j]
            end
        end
    end
end


" defines i based on voltage vs setting current based on reg"
function build_mc_delta_current_vector(data, v)
    (n, m) = size(v)
    delta_i = zeros(Complex{Float64}, n, 1)
    build_mc_delta_current_load!(delta_i, v, data)
    build_mc_delta_current_generator!(delta_i, v, data)
    # build_mc_delta_current_inverter!(delta_i, v, data, z_matrix) # add if just genernal pv 
    return _SP.sparse(delta_i)
end


function build_mc_delta_current_generator!(delta_i, v, data)
    for (_, gen) in data["gen"]
        if occursin("generator", gen["source_id"])
            if gen["gen_model"] == 1
                calc_delta_current_generator!(gen, delta_i, v, data)
            end
        end
    end
end


function calc_delta_current_generator!(gen, delta_i, v, data)
    bus = gen["gen_bus"]
    if occursin("generator", gen["source_id"])
        if gen["gen_model"] == 1
            for (_j, j) in enumerate(gen["connections"])
                if haskey(data["admittance_map"], (bus, j))
                    s = -(gen["pg"][_j] + 1im * gen["qg"][_j])
                    y = conj(s) / gen["vnom_kv"]^2 / 1000
                    delta_i[data["admittance_map"][(bus, j)], 1] += conj(s * data["settings"]["power_scale_factor"] / v[data["admittance_map"][(bus, j)], 1])  - y * v[data["admittance_map"][(bus, j)], 1]
                end
            end
        end
    end
end


function build_mc_delta_current_load!(delta_i, v, data)
    for (_, load) in data["load"]
        if load["model"] == _PMD.POWER
            calc_delta_current_load_constantpq!(load, delta_i, v, data)
        end
    end
end


function calc_delta_current_load_constantpq!(load, delta_i, v, data)
    bus = load["load_bus"]
    if load["configuration"] == _PMD.WYE
        n = length(load["connections"])
        for (_j, j) in enumerate(load["connections"])
            if haskey(data["admittance_map"], (bus, j))
                s = load["pd"][_j] + 1im .* load["qd"][_j]
                y = load["p_matrix"][_j,_j]
                if abs(v[data["admittance_map"][(bus, j)], 1]) < load["vminpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                    y_vmin = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*load["vminpu"]*data["settings"]["voltage_scale_factor"])^2
                    delta_i[data["admittance_map"][(bus, j)], 1] -= v[data["admittance_map"][(bus, j)], 1] * (y_vmin - y) - load["i_last"][_j]
                    load["i_last"][_j] = v[data["admittance_map"][(bus, j)], 1] * (y_vmin - y)
                elseif abs(v[data["admittance_map"][(bus, j)], 1]) > load["vmaxpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                    y_vmax = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*load["vmaxpu"]*data["settings"]["voltage_scale_factor"])^2 
                    delta_i[data["admittance_map"][(bus, j)], 1] -= v[data["admittance_map"][(bus, j)], 1] * (y_vmax - y) - load["i_last"][_j]
                    load["i_last"][_j] = v[data["admittance_map"][(bus, j)], 1] * (y_vmax - y)
                else
                    delta_i[data["admittance_map"][(bus, j)], 1] -= conj(s * data["settings"]["power_scale_factor"] / v[data["admittance_map"][(bus, j)], 1])  - y * v[data["admittance_map"][(bus, j)], 1] - load["i_last"][_j]
                    load["i_last"][_j] = conj(s * data["settings"]["power_scale_factor"] / v[data["admittance_map"][(bus, j)], 1])  - y * v[data["admittance_map"][(bus, j)], 1] 
                end
            end
        end
    elseif load["configuration"] == _PMD.DELTA
        n = length(load["connections"])
        phases = isa(load["dss"]["phases"], String) ? parse(Int, load["dss"]["phases"]) : load["dss"]["phases"]
        if phases == 1
            i = load["connections"][1]
            j = load["connections"][2]
            if haskey(data["admittance_map"], (bus, i)) && haskey(data["admittance_map"], (bus, j))
                s = load["pd"][1] + 1im .* load["qd"][1]
                y = load["p_matrix"][1,1]
                if abs(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) < load["vminpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                    y_vmin = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*load["vminpu"]*data["settings"]["voltage_scale_factor"])^2
                    i_ij = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmin - y) - load["i_last"][1]
                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                    load["i_last"][1] = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmin - y)
                elseif abs(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) > load["vmaxpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                    y_vmax = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*load["vmaxpu"]*data["settings"]["voltage_scale_factor"])^2
                    i_ij = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmax - y) - load["i_last"][1]
                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                    load["i_last"][1] = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmax - y)
                else
                    i_ij = conj(s * data["settings"]["power_scale_factor"] / (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]))  - y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) - load["i_last"][1]
                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                    load["i_last"][1] = conj(s * data["settings"]["power_scale_factor"] / (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]))  - y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1])
                end
            end
        else
            idx = 1
            for (_i, i) in enumerate(load["connections"])
                if haskey(data["admittance_map"], (bus, i))
                    for (_j, j) in enumerate(load["connections"])
                        if _i < _j
                            if haskey(data["admittance_map"], (bus, j))
                                length(load["pd"]) == n ? s = load["pd"][_i] + 1im .* load["qd"][_i] : s = load["pd"][1] + 1im .* load["qd"][1]
                                y = -load["p_matrix"][_i,_j]
                                if abs(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) < load["vminpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                                    y_vmin = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*load["vminpu"]*data["settings"]["voltage_scale_factor"])^2
                                    i_ij = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmin - y) - load["i_last"][idx]
                                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                                    load["i_last"][idx] = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmin - y)
                                elseif abs(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) > load["vmaxpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                                    y_vmax = conj(s*data["settings"]["power_scale_factor"]) / (load["vnom_kv"]*load["vmaxpu"]*data["settings"]["voltage_scale_factor"])^2
                                    i_ij = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmax - y) - load["i_last"][idx]
                                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                                    load["i_last"][idx] = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmax - y)
                                else
                                    i_ij = conj(s * data["settings"]["power_scale_factor"] / (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]))  - y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) - load["i_last"][idx]
                                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                                    load["i_last"][idx] = conj(s * data["settings"]["power_scale_factor"] / (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]))  - y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1])
                                end
                                idx += 1
                            end
                        end
                    end
                end
            end
        end
    end
end


function calc_delta_current_load_constanti!(load, delta_i, v, data)
    bus = load["load_bus"]
    if load["configuration"] == _PMD.WYE
        n = length(load["connections"])
        for (_j, j) in enumerate(load["connections"])
            if haskey(data["admittance_map"], (bus, j))
                constant_i = (conj(load["pd"][_j] + 1im .* load["qd"][_j]) * data["settings"]["power_scale_factor"]) / (load["vnom_kv"] * data["settings"]["voltage_scale_factor"])
                y = load["p_matrix"][_j,_j] 
                if abs(v[data["admittance_map"][(bus, j)], 1]) < load["vminpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                    y_vmin = constant_i / (load["vnom_kv"]*load["vminpu"]*data["settings"]["voltage_scale_factor"])
                    delta_i[data["admittance_map"][(bus, j)], 1] -= v[data["admittance_map"][(bus, j)], 1] * (y_vmin - y) - load["i_last"][_j]
                    load["i_last"][_j] = v[data["admittance_map"][(bus, j)], 1] * (y_vmin - y)
                elseif abs(v[data["admittance_map"][(bus, j)], 1]) > load["vmaxpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                    y_vmax = constant_i / (load["vnom_kv"]*load["vmaxpu"]*data["settings"]["voltage_scale_factor"])
                    delta_i[data["admittance_map"][(bus, j)], 1] -= v[data["admittance_map"][(bus, j)], 1] * (y_vmax - y) - load["i_last"][_j]
                    load["i_last"][_j] = v[data["admittance_map"][(bus, j)], 1] * (y_vmax - y)
                else
                    delta_i[data["admittance_map"][(bus, j)], 1] -= constant_i * exp(1im*angle(v[data["admittance_map"][(bus, j)], 1])) - y * v[data["admittance_map"][(bus, j)], 1] - load["i_last"][_j]
                    load["i_last"][_j] = constant_i * exp(1im*angle(v[data["admittance_map"][(bus, j)], 1])) - y * v[data["admittance_map"][(bus, j)], 1]
                end
            end
        end
    elseif load["configuration"] == _PMD.DELTA
        n = length(load["connections"])
        phases = isa(load["dss"]["phases"], String) ? parse(Int, load["dss"]["phases"]) : load["dss"]["phases"]
        if phases == 1
            i = load["connections"][1]
            j = load["connections"][2]
            if haskey(data["admittance_map"], (bus, i)) && haskey(data["admittance_map"], (bus, j))
                constant_i = conj(((load["pd"][1] + 1im .* load["qd"][1]) * data["settings"]["power_scale_factor"]) / (load["vnom_kv"] * data["settings"]["voltage_scale_factor"]))
                y = load["p_matrix"][1,1]
                if abs(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) < load["vminpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                    y_vmin = constant_i / (load["vnom_kv"]*load["vminpu"]*data["settings"]["voltage_scale_factor"])
                    i_ij = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmin - y) - load["i_last"][1]
                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                    load["i_last"][1] = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmin - y)
                elseif abs(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) > load["vmaxpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                    y_vmax = constant_i / (load["vnom_kv"]*load["vmaxpu"]*data["settings"]["voltage_scale_factor"])
                    i_ij = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmax - y) - load["i_last"][1]
                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                    load["i_last"][1] = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmax - y)
                else
                    i_ij = constant_i * exp(1im*angle(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1])) - y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) - load["i_last"][1]
                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                    load["i_last"][1] = constant_i * exp(1im*angle(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1])) - y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1])
                end
            end
        else
            idx = 1
            for (_i, i) in enumerate(load["connections"])
                if haskey(data["admittance_map"], (bus, i))
                    for (_j, j) in enumerate(load["connections"])
                        if _i < _j
                            if haskey(data["admittance_map"], (bus, j))
                                length(load["pd"]) == n ? s = load["pd"][_i] + 1im .* load["qd"][_i] : s = load["pd"][1] + 1im .* load["qd"][1]
                                constant_i = conj((s * data["settings"]["power_scale_factor"]) / (load["vnom_kv"] * data["settings"]["voltage_scale_factor"]))
                                y = -load["p_matrix"][_i,_j]
                                if abs(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) < load["vminpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                                    y_vmin = constant_i / (load["vnom_kv"]*load["vminpu"]*data["settings"]["voltage_scale_factor"])
                                    i_ij = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmin - y) - load["i_last"][idx]
                                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                                    load["i_last"][idx] = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmin - y)
                                elseif abs(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) > load["vmaxpu"] * load["vnom_kv"]*data["settings"]["voltage_scale_factor"]
                                    y_vmax = constant_i / (load["vnom_kv"]*load["vmaxpu"]*data["settings"]["voltage_scale_factor"])
                                    i_ij = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmax - y) - load["i_last"][idx]
                                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                                    load["i_last"][idx] = (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) * (y_vmax - y)
                                else
                                    i_ij = constant_i * exp(1im*angle(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1])) - y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1]) - load["i_last"][idx]
                                    delta_i[data["admittance_map"][(bus, i)], 1] -= i_ij
                                    delta_i[data["admittance_map"][(bus, j)], 1] -= -i_ij
                                    load["i_last"][idx] = constant_i * exp(1im*angle(v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1])) - y * (v[data["admittance_map"][(bus, i)], 1] - v[data["admittance_map"][(bus, j)], 1])
                                end
                                idx += 1
                            end
                        end
                    end
                end
            end
        end

    end
end


function build_mc_delta_current_inverter!(delta_i, v, data)
    for (_, gen) in data["gen"]
        if gen["element"] == SolarElement
            if gen["grid_forming"]
                calc_mc_delta_current_gfmi!(gen, delta_i, v, data)
            else
                calc_mc_delta_current_gfli!(gen, delta_i, v, data)
            end
        end
    end
end


function calc_mc_delta_current_gfli!(gen, delta_i, v, data)
    if gen["response"] == ConstantPAtPF
        bus = data["bus"]["$(gen["gen_bus"])"]
        pg = gen["pg"]
        haskey(gen, "qg") ? qg = gen["qg"] : qg = gen["pg"].*0.0
        s = (pg .+ 1im .* qg) .* data["settings"]["power_scale_factor"]
        v_solar = zeros(Complex{Float64}, length(s), 1)
        v0 = zeros(Complex{Float64}, length(s), 1)
        for (_j, j) in enumerate(gen["connections"])
            if haskey(data["admittance_map"], (bus["bus_i"], j))
                v_solar[_j, 1] = v[data["admittance_map"][(bus["bus_i"], j)], 1]
            end
        end
        if haskey(gen, "fault_model")
            if gen["fault_model"]["standard"] == IEEE2800
                v_012 = inv(_A) * v_solar
                if gen["fault_model"]["priority"] == "active"
                    i_pq = conj(s[1]/v_012[2]) * exp(-1im*angle(v_012[2]))
                    if abs(i_pq) < gen["i_max"][1]
                        if abs(v_012[2]) < (1-gen["fault_model"]["ir1_dead_band"]) * bus["vbase"] * data["settings"]["voltage_scale_factor"] 
                            delta_v1 = abs(v_012[2])/(bus["vbase"] * data["settings"]["voltage_scale_factor"]) - 1 + gen["fault_model"]["ir1_dead_band"]
                            ir1 = gen["fault_model"]["delta_ir1"] * delta_v1 * gen["i_nom"]
                        else
                            ir1 = 0.0
                        end
                        if abs(v_012[3]) > gen["fault_model"]["ir2_dead_band"] * bus["vbase"] * data["settings"]["voltage_scale_factor"]
                            delta_v2 = abs(v_012[3])/(bus["vbase"] * data["settings"]["voltage_scale_factor"]) - gen["fault_model"]["ir2_dead_band"] 
                            ir2 = gen["fault_model"]["delta_ir2"] * delta_v2 * gen["i_nom"]
                        else
                            ir2 = 0.0
                        end
                        iq = sqrt(gen["i_max"][1]^2 - abs(i_pq)^2)
                        if ir1 < ir2
                            ir2 = ir1
                        end
                        if ir1 + ir2 > iq
                            delta_iq = iq - (ir1 + ir2)
                            ir1 = ir1 - delta_iq/2
                            ir2 = ir2 - delta_iq/2
                        end
                        i_inj = _A * [0; (i_pq+1im*ir1); (1im*ir2)*exp(1im*angle(v_012[3]))]
                    else
                        i_inj = _A * [0;gen["i_max"][1]*exp(1im*angle(v_012[2])); 0.0]
                    end
                elseif gen["fault_model"]["priority"] == "reactive"
                    if !(haskey(gen, "i_inj"))
                        gen["i_inj"] = [0; 0; 0]
                        gen["current"] = [0; 0; 0]
                        gen["current_seq"] = [0.0+0.0im; 0.0+0.0im; 0.0+0.0im]
                        gen["angle_seq"] = [0.0; 0.0; 0.0]
                        gen["i+_sum"] = 0.0
                        gen["i-_sum"] = 0.0
                        gen["last_ir1"] = 0.0
                        gen["set_a"] = 0.0
                        gen["set_2"] = 0.0
                        gen["old_v"] = 0.0
                        gen["old_a"] = 0.0
                        gen["inj"] = false
                    end
                    ipq = conj(s[1]/abs(v_012[2]))
                    # i_pos = ipq
                    i_neg = 0.0
                    delta_v1 = 0.0
                    if abs(v_012[2]) < (1-gen["fault_model"]["ir1_dead_band"]) * bus["vbase"] * data["settings"]["voltage_scale_factor"] || abs(v_012[2]) > (1+gen["fault_model"]["ir1_dead_band"]) * bus["vbase"] * data["settings"]["voltage_scale_factor"] 
                        delta_v1 = abs(v_012[2])/(bus["vbase"] * data["settings"]["voltage_scale_factor"]) - 1
                        ir1 = gen["fault_model"]["delta_ir1"] * delta_v1 * gen["i_nom"][1]
                        abs(ir1) > gen["i_nom"][1] ? ir1 = sign(ir1)*gen["i_max"][1] : nothing
                        ipq = conj(s[1]/((1-gen["fault_model"]["ir1_dead_band"]*0.0) * bus["vbase"] * data["settings"]["voltage_scale_factor"]))
                        ir1 = 0.0 + ir1*1im
                    else
                        ir1 = 0.0
                    end   
                    delta_v2 = 0.0         
                    if abs(v_012[3]) > gen["fault_model"]["ir2_dead_band"] * bus["vbase"] * data["settings"]["voltage_scale_factor"]
                        delta_v2 = abs(v_012[3])/(bus["vbase"] * data["settings"]["voltage_scale_factor"])
                        ir2 = gen["fault_model"]["delta_ir2"] * delta_v2 * gen["i_nom"][1]*1im
                    else
                        ir2 = 0.0
                    end
                    m = max(1, (abs(ir1) + abs(ir2))/(gen["i_max"][1]))
                    ir1 = ir1/m
                    ir2 = ir2/m
                    i_012 = [0; ir1; ir2]
                    ir1_a = 0.0
                    ir2_a = 0.0
                    if maximum(abs.(gen["current_seq"])) > .1
                        ir1_a = -(angle(gen["current_seq"][2]) - angle(v_012[2]) + pi/2)*.5
                        ir2_a = -(angle(gen["current_seq"][3]) - angle(v_012[3]) - pi/2)*.5
                    else
                        if abs(ir1) > .1 || abs(ir2) > .1
                            ir1_a = angle(v_012[2])
                            ir2_a = angle(v_012[3])
                        end
                    end
                    if gen["angle_seq"][2] + ir1_a < -pi/6
                        gen["angle_seq"][2] = -pi/6
                    else
                        gen["angle_seq"][2] += ir1_a
                    end

                    if gen["angle_seq"][3] + ir2_a < pi/6
                        gen["angle_seq"][3] = pi/6
                    else
                        gen["angle_seq"][3] += ir2_a
                    end      
                    i_inj = _A * [0; i_012[2]*exp(1im*(gen["angle_seq"][2])) ; i_012[3]*exp(1im*gen["angle_seq"][3])] .- gen["i_inj"]
                    gen["i_inj"] += i_inj
                    gen["current_seq"] = [0; i_012[2]*exp(1im*(gen["angle_seq"][2])) ; i_012[3]*exp(1im*gen["angle_seq"][3])]
                    gen["i+"] = abs(i_012[2])
                    gen["i-"] = abs(i_012[3])
                    gen["v+"] = abs(v_012[2])
                    gen["v-"] = abs(v_012[3])
                    gen["v+_a"] = angle(v_012[2])*180/pi
                    gen["v-_a"] = angle(v_012[3])*180/pi
                    for (_j, j) in enumerate(gen["connections"]) 
                        if j != 4
                            delta_i[data["admittance_map"][(bus["bus_i"], j)], 1] += i_inj[j] 
                        end
                    end
                end
            end
        else
            v_012 = inv(_A) * v_solar
            if abs(conj(s[1]/v_012[2])) > gen["i_max"][1]
                i_1 = gen["i_max"][1] * exp(1im*angle(conj(s[1]/v_012[2])))
                gen["i+"] = gen["i_max"][1] * exp(1im*angle(conj(s[1]/v_012[2]))) - gen["i+"]
            else
                i_1 = conj(s[1]/v_012[2]) - gen["i+"]
                gen["i+"] = conj(s[1]/v_012[2])
            end
            i_inj = _A * [0.0; i_1; 0.0]
            for (_j, j) in enumerate(gen["connections"]) 
                if j != 4
                    delta_i[data["admittance_map"][(bus["bus_i"], j)], 1] += i_inj[j]
                end
            end
        end
    end
end


function calc_mc_delta_current_gfmi!(gen, delta_i, v, data)
    bus = gen["gen_bus"]
    pg = gen["pg"]
    haskey(gen, "qg") ? qg = gen["qg"] : qg = gen["pg"].*0.0
    s = (pg .+ 1im .* qg) .* data["settings"]["power_scale_factor"]
    if gen["configuration"] == _PMD.WYE
        if gen["balanced"]
            v_solar = zeros(Complex{Float64}, length(s), 1)
            for (_j, j) in enumerate(gen["connections"])
                if haskey(data["admittance_map"], (bus, j))
                    v_solar[_j, 1] = v[data["admittance_map"][(bus, j)], 1]
                end
            end
            s_seq = s[1]
            v_seq = inv(_A)*v_solar
            i_seq = conj(s_seq/v_seq[2])
            if abs(i_seq) <= gen["i_max"][1]
                i_inj = _A*[0;i_seq;0]
            else
                i_inj = _A*[0;gen["i_max"][1]*exp(1im*angle(i_seq));0]
            end
            for (_j, j) in enumerate(gen["connections"])
                if j != 4
                    delta_i[data["admittance_map"][(bus, j)], 1] += i_inj[j]
                end
            end
        else
            k = findall(x->x==4, gen["connections"])[1]
            for (_j, j) in enumerate(gen["connections"])
                if j != 4
                    i_inj = conj(s[_j]/v[data["admittance_map"][(bus, j)], 1])
                    if abs(i_inj) < gen["i_max"][_j]
                        delta_i[data["admittance_map"][(bus, j)], 1] += i_inj * exp(-1im*angle(i_inj))
                    else
                        delta_i[data["admittance_map"][(bus, j)], 1] += gen["i_max"][_j] * exp(-1im*angle(i_inj))
                    end
                end
            end
        end
    end
end


function update_mc_delta_current_vector(model, v)
    (n, m) = size(v)
    delta_i = zeros(Complex{Float64}, n, 1)
    # update_mc_delta_current_generator!(delta_i, v, model.data)
    update_mc_delta_current_load!(delta_i, v, model.data)
    # update_mc_delta_current_inverter!(delta_i, v, model.data)
    # update_mc_delta_current_regulator_control!(delta_i, v, model.data)
    return delta_i
end


function update_mc_delta_current_generator!(delta_i, v, data)
    for (_, gen) in data["gen"]
        if occursin("generator", gen["source_id"])
            if gen["gen_model"] == 1
                calc_delta_current_generator!(gen, delta_i, v, data)
            end
        end
    end
end


function update_mc_delta_current_load!(delta_i, v, data)
    for (_, load) in data["load"]
        if data["settings"]["loading"]
            if load["response"] == ConstantPQ
                calc_delta_current_load_constantpq!(load, delta_i, v, data)
            elseif load["response"] == ConstantZ
               nothing
            elseif load["response"] == ConstantI
                calc_delta_current_load_constanti!(load, delta_i, v, data)
            end
        end
    end
end


function update_mc_delta_current_inverter!(delta_i, v, data)
    for (_, gen) in data["gen"]
        if gen["element"] == SolarElement
            if gen["grid_forming"]
                calc_mc_delta_current_gfmi!(gen, delta_i, v, data)
            else
                calc_mc_delta_current_gfli!(gen, delta_i, v, data)
            end
        end
    end
end
