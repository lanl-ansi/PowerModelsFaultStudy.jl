"""
	solution_fs!(pm::_PMD.AbstractUnbalancedIVRModel, sol::Dict{String,<:Any})

adds additional variable transformations for fault study solutions of distribution networks
"""
function solution_fs!(pm::_PMD.AbstractUnbalancedIVRModel, sol::Dict{String,<:Any})
    _PMD.apply_pmd!(_solution_fs!, sol; apply_to_subnetworks=true)
end


"adds additional variable transformations for fault study solutions of distribution networks"
function _solution_fs!(sol::Dict{String,<:Any})

    if haskey(sol, "branch")
        for (_,branch) in sol["branch"]
            if haskey(branch, "cr_fr") && haskey(branch, "ci_fr")
                branch["cf_fr"] = sqrt.(branch["cr_fr"].^2 + branch["ci_fr"].^2)
            end
            if haskey(branch, "cr_to") && haskey(branch, "ci_to")
                branch["cf_to"] = sqrt.(branch["cr_to"].^2 + branch["ci_to"].^2)
            end
        end
    end

    if haskey(sol, "switch")
        for (_,switch) in sol["switch"]
            if haskey(switch, "cr_fr") && haskey(switch, "ci_fr")
                switch["cf_fr"] = sqrt.(switch["cr_fr"].^2 + switch["ci_fr"].^2)
            end
            if haskey(switch, "cr_to") && haskey(switch, "ci_to")
                switch["cf_to"] = sqrt.(switch["cr_to"].^2 + switch["ci_to"].^2)
            end
        end
    end

    if haskey(sol, "fault")
        for (_,fault) in sol["fault"]
            if haskey(fault, "cfr") && haskey(fault, "cfi")
                fault["cf"] = sqrt.(fault["cfr"].^2 + fault["cfi"].^2)
            end
        end
    end

    if haskey(sol, "bus")
        for (_,bus) in sol["bus"]
            if haskey(bus, "vr")  && haskey(bus, "vi")
                bus["vm"] = sqrt.(bus["vr"].^2 + bus["vi"].^2)
                bus["va"] = atan.(bus["vi"], bus["vr"])
            end

            if haskey(bus, "cfr_bus") && haskey(bus, "cfi_bus")
                bus["cf_bus"] = sqrt.(bus["cfr_bus"].^2 + bus["cfi_bus"].^2)
            end
        end
    end
end


"adds additional variable transformations for fault study solutions of transmission networks"
function solution_fs!(pm::_PM.AbstractIVRModel, sol::Dict{String,<:Any})
    _PM.apply_pm!(_solution_pm_fs!, sol; apply_to_subnetworks=true)
end


"adds additional variable transformations for fault study solutions of transmission networks"
function _solution_pm_fs!(sol::Dict{String,<:Any})
    if haskey(sol, "branch")
        for (_,branch) in sol["branch"]
            if haskey(branch, "cr_fr") && haskey(branch, "ci_fr")
                branch["cf_fr"] = sqrt.(branch["csr_fr"].^2 + branch["csi_fr"].^2)
            end
            if haskey(branch, "cr_to") && haskey(branch, "ci_to")
                branch["cf_to"] = sqrt.(branch["cr_to"].^2 + branch["ci_to"].^2)
            end
        end
    end

    if haskey(sol, "switch")
        for (_,switch) in sol["switch"]
            if haskey(switch, "cr_fr") && haskey(switch, "ci_fr")
                switch["cf_fr"] = sqrt.(switch["cr_fr"].^2 + switch["ci_fr"].^2)
            end
            if haskey(switch, "cr_to") && haskey(switch, "ci_to")
                switch["cf_to"] = sqrt.(switch["cr_to"].^2 + switch["ci_to"].^2)
            end
        end
    end

    if haskey(sol, "fault")
        for (_,fault) in sol["fault"]
            if haskey(fault, "cfr") && haskey(fault, "cfi")
                fault["cf_bus"] = sqrt.(fault["cfr"].^2 + fault["cfi"].^2)
            end
        end
    end

    if haskey(sol, "bus")
        for (_,bus) in sol["bus"]
            if haskey(bus, "vr")  && haskey(bus, "vi")
                bus["vm"] = sqrt(bus["vr"]^2 + bus["vi"]^2)
                bus["va"] = atan(bus["vi"], bus["vr"])
            end

            if haskey(bus, "cfr_bus") && haskey(bus, "cfi_bus")
                bus["cf"] = sqrt(bus["cfr_bus"]^2 + bus["cfi_bus"]^2)
            end
        end
    end
end

"calculates relay and fuse operation times and adds them to solution dictionary"
function solution_protection!(pm::_PMD.AbstractUnbalancedIVRModel, sol::Dict{String,<:Any})
    _PMD.apply_pmd!(_solution_protection!, pm.ref, sol; apply_to_subnetworks=true)
end


"calculates relay and fuse operation times and adds them to solution dictionary"
function _solution_protection!(ref::Dict{Symbol,Any},sol::Dict{String,<:Any})
    if haskey(ref,:relay)
        pu = [ref[:settings]["sbase_default"]]
        push!(pu,ref[:settings]["power_scale_factor"])
        push!(pu,ref[:settings]["voltage_scale_factor"])
        tripped_relays = Dict{String,Any}()
        for (id,obj) in get(ref,:relay,Dict())
            trip = false
            element_enum = obj["element_enum"]
            Iabc = _get_current_math(ref,sol,element_enum,id,pu)
            _relay_operation(obj,Iabc)
            if haskey(obj,"phase")
                for phase=1:length(obj["phase"])
                    if obj["phase"]["$phase"]["state"] == "open"
                        trip = true
                    end
                end
            else
                if obj["state"] == "open"
                    trip = true
                end
            end
            if trip
                tripped_relays["$id"] = obj
            end
        end
        if !isempty(tripped_relays)
            sol["relay"] = tripped_relays
        end
    end

    if haskey(ref, :fuse)
        pu = [ref[:settings]["sbase_default"]]
        push!(pu,ref[:settings]["power_scale_factor"])
        push!(pu,ref[:settings]["voltage_scale_factor"])
        blown_fuses = Dict{String,Any}()
        for (id, obj) in get(ref, :fuse, Dict())
            blown = false
            element_enum = obj["element_enum"]
            Iabc = _get_current_math(ref,sol,element_enum,id,pu)
            for phase=1:length(obj["phase"])
                if haskey(obj, "min_melt_curve_enum")
                    current_vec = ref[:curve][obj["min_melt_curve_enum"]]["curve_mat"][1,:]
                    time_vec = ref[:curve][obj["min_melt_curve_enum"]]["curve_mat"][2,:]
                else
                    current_vec = obj["min_melt_curve"][1,:]
                    time_vec = obj["min_melt_curve"][2,:]
                end
                (time_min, op_min) = _interpolate_time(current_vec, time_vec, Iabc[phase])
                if op_min
                    blown = true
                    if haskey(obj, "max_clear_curve_enum")
                        current_vec = ref[:curve][obj["max_clear_curve_enum"]]["curve_mat"][1,:]
                        time_vec = ref[:curve][obj["max_clear_curve_enum"]]["curve_mat"][2,:]
                    else
                        current_vec = obj["max_clear_curve"][1,:]
                        time_vec = obj["max_clear_curve"][2,:]
                    end
                    (time_max, op_max) = _interpolate_time(current_vec,time_vec,Iabc[phase])
                    if op_max
                        obj["phase"]["$phase"]["state"] = "open"
                        obj["phase"]["$phase"]["op_times"] = "Min. melt: $time_min. Max. clear: $time_max."
                    else
                        obj["phase"]["$phase"]["state"] = "open"
                        obj["phase"]["$phase"]["op_times"] = "Min. melt: $time_min."
                    end
                end
            end
            if blown
                blown_fuses["$id"] = obj
            end
        end
        if !isempty(blown_fuses)
            sol["fuse"] = blown_fuses
        end
    end
end


function solution_mc_pf(v::Matrix{ComplexF64}, it::Int64, it_current, last_delta::Float64, i::Matrix{ComplexF64}, model::AdmittanceModel)
    solution = Dict{String, Any}()
    solution["bus"] = Dict{String, Any}()
    for (indx,bus) in model.data["bus"]
        solution["bus"][indx] = Dict{String, Any}(
            "vm" => [0.0 for t in bus["terminals"]],
            "va" => [0.0 for t in bus["terminals"]],
            "name" => bus["source_id"],
            "vbase" => bus["vbase"],
        )
        for (j, grounded) in enumerate(bus["grounded"])
            if grounded == 0
                t = bus["terminals"][j]
                solution["bus"][indx]["vm"][j] = abs(v[model.data["admittance_map"][(bus["index"], t)]])
                solution["bus"][indx]["va"][j] = angle(v[model.data["admittance_map"][(bus["index"], t)]]) * 180/pi
            end
        end
    end
    solution_mc_pf_loads!(solution, v, model.data)
    solution_mc_pf_branches!(solution, v, model.data)
    solution["model"] = model
    solution["solver"] = Dict{String,Any}(
        "it" => it,
        "inner it" => it_current,
        "delta" => last_delta,
    )

    return solution
end


function solution_mc_pf_loads!(solution, v, data)
    for (indx,load) in data["load"]
        bus = load["load_bus"]
        current = Dict{Int,Any}()
        if load["configuration"] == _PMD.WYE
            n = length(load["connections"])
            for (_j, j) in enumerate(load["connections"])
                if haskey(data["admittance_map"], (bus, j))
                    current[j] = load["p_matrix"][_j,_j] * v[data["admittance_map"][(bus, j)], 1] + load["i_last"][_j]
                end
            end
        end
        load["i"] = current
    end
end


function solution_mc_pf_branches!(solution, v, data)
    for (indx,branch) in data["branch"]
        f_bus = branch["f_bus"]
        t_bus = branch["t_bus"]
        _y = branch["p_matrix"]
        v_size = size(_y)[1]
        v_t = zeros(Complex{Float64}, v_size, 1)
        indx = 1
        for (_i, i) in enumerate(branch["f_connections"])
            if haskey(data["admittance_map"], (f_bus, i))
                v_t[indx,1] = v[data["admittance_map"][(f_bus, i)], 1]
            end
            indx += 1
        end
        for (_i, i) in enumerate(branch["t_connections"])
            if haskey(data["admittance_map"], (t_bus, i))
                v_t[indx,1] = v[data["admittance_map"][(t_bus, i)], 1]
            end
            indx += 1
        end
        branch["i"] = _y*v_t
    end
end


function solution_mc_pf(v::Matrix{ComplexF64}, model::AdmittanceModel)
    solution = Dict{String, Any}()
    solution["bus"] = Dict{String, Any}()
    for (indx,bus) in model.data["bus"]
        solution["bus"][bus["name"]] = Dict{String, Any}(
            "vm" => [0.0 for t in bus["terminals"]],
            "va" => [0.0 for t in bus["terminals"]],
            "name" => bus["source_id"],
            "vbase" => bus["vbase"],
        )
        for (j, grounded) in enumerate(bus["grounded"])
            if grounded == 0
                t = bus["terminals"][j]
                solution["bus"][bus["name"]]["vm"][j] = abs(v[model.data["admittance_map"][(bus["index"], t)]])
                solution["bus"][bus["name"]]["va"][j] = angle(v[model.data["admittance_map"][(bus["index"], t)]]) * 180/pi
            end
        end
        solution["model"] = model
    end

    return solution
end



function solution_mc_fs(data::Dict{String,Any})
    buses = Dict{String,Any}()
    for (name,indx) in data["bus_lookup"]
        bus = data["bus"][string(indx)]
        buses[name] = Dict{String, Any}(
            "grounded" => bus["terminals"],
            "3pg" => haskey(bus,"3pg") ? bus["3pg"] : nothing,
            "ll" => haskey(bus,"ll") ? bus["ll"] : nothing,
            "lg" => bus["lg"],
        )
    end
    return buses
end


const A = inv([1 1 1; 1 exp(-1im*2/3*pi) exp(1im*2/3*pi); 1 exp(1im*2/3*pi) exp(-1im*2/3*pi)])

function get_current_sequence(i::Vector{ComplexF64}, connections::Vector{Int})
    i_abc = zeros(Complex{Float64}, 3)
    for (_j,j) in enumerate(connections)
        if j <= 3
            i_abc[j,1] = i[_j,1]
        end
    end
    return A*i_abc
end


function build_output_schema!(output::Dict{String,Any}, v::SparseArrays.SparseMatrixCSC{ComplexF64, Int64}, data::Dict{String,Any}, y::Matrix{ComplexF64}, bus::Dict{String,Any}, fault_type::String, fault::Matrix{Real})
    conductance = fault
    susceptance = conductance .* 0.0

    name = "$(bus["name"])_$fault_type"
    connections = bus["terminals"]
    n = length(connections)
    v_bus = zeros(Complex{Float64},3)
    for j = 1:3
        v_bus[j,1] = v[data["admittance_map"][(bus["bus_i"],j)],1]
    end
    i = fault*v_bus
    i012 = get_current_sequence(i,connections)
    obj = Dict{String,Any}(
            "fault" => Dict{String,Any}(
            "susceptance (S)" => susceptance,
            "conductance (S)" => conductance,
            "connections" => connections,
            "bus" => bus["name"],
            "type" => fault_type,
            "|I| (A)" => abs.(i),
            "theta (deg)" => angle.(i).* pi/180,
            "|I0| (A)" => abs(i012[1]),
            "|I1| (A)" => abs(i012[2]),
            "|I2| (A)" => abs(i012[3]),
            "|V| (V)" => abs.(v_bus),
            "phi (deg)" => angle.(v_bus).*pi/180,
        )
    )
    line = Dict{String,Any}()
    switch = Dict{String,Any}()
    for (i,branch) in data["branch"]
        branch_name = branch["name"]
        n = length(branch["f_connections"])
        v_f_bus = zeros(Complex{Float64}, n)
        v_t_bus = zeros(Complex{Float64}, n)
        f_bus = data["bus"][string(branch["f_bus"])]
        t_bus = data["bus"][string(branch["t_bus"])]
        y_line = branch["p_matrix"][1:n,n+1:2*n]
        for (_j,j) in enumerate(branch["f_connections"])
            if haskey(data["admittance_map"], (f_bus["bus_i"], j))
                v_f_bus[_j,1] = v[data["admittance_map"][(f_bus["bus_i"], j)],1] 
            end
        end
        for (_j,j) in enumerate(branch["t_connections"])
            if haskey(data["admittance_map"], (t_bus["bus_i"], j))
                v_t_bus[_j,1] = v[data["admittance_map"][(t_bus["bus_i"], j)],1] 
            end
        end
        i_line = y_line * (v_f_bus - v_t_bus)
        i012 = get_current_sequence(i_line,branch["f_connections"])
        branch_obj = Dict{String,Any}(
            "|I| (A)" => abs.(i_line),
            "theta (deg)" => angle.(i_line).* pi/180,
            "|I0| (A)" => abs(i012[1]),
            "|I1| (A)" => abs(i012[2]),
            "|I2| (A)" => abs(i012[3]),
        )

        if occursin("line.", branch["source_id"])
            line[branch_name] = branch_obj
        elseif occursin("switch", branch["source_id"])
            switch[branch_name] = branch_obj
        end
    end
    obj["switch"] = switch
    obj["line"] = line
    output[name] = obj
end


function build_output_schema!(output::Dict{String,Any}, v::SparseArrays.SparseMatrixCSC{ComplexF64, Int64}, data::Dict{String,Any}, y::Matrix{ComplexF64}, bus::Dict{String,Any}, fault_type::String, fault::Matrix{Real}, indx::Tuple)
    conductance = fault
    susceptance = conductance .* 0.0
    name = "$(bus["name"])_$(fault_type)_$(indx[1])_$(indx[2])"
    connections = [bus["terminals"][indx[1]], bus["terminals"][indx[2]]]
    n = length(connections)
    v_bus = zeros(Complex{Float64},n)
    for j =1:2
        v_bus[j,1] = v[data["admittance_map"][(bus["bus_i"],connections[j])],1]
    end
    i = fault*v_bus
    i012 = get_current_sequence(i,connections)
    obj = Dict{String,Any}(
            "fault" => Dict{String,Any}(
            "susceptance (S)" => susceptance,
            "conductance (S)" => conductance,
            "connections" => connections,
            "bus" => bus["name"],
            "type" => fault_type,
            "|I| (A)" => abs.(i),
            "theta (deg)" => angle.(i).* pi/180,
            "|I0| (A)" => abs(i012[1]),
            "|I1| (A)" => abs(i012[2]),
            "|I2| (A)" => abs(i012[3]),
            "|V| (V)" => abs.(v_bus),
            "phi (deg)" => angle.(v_bus).*pi/180,
        )
    )
   
    line = Dict{String,Any}()
    switch = Dict{String,Any}()
    for (i,branch) in data["branch"]
        branch_name = branch["name"]
        n = length(branch["f_connections"])
        v_f_bus = zeros(Complex{Float64}, n)
        v_t_bus = zeros(Complex{Float64}, n)
        f_bus = data["bus"][string(branch["f_bus"])]
        t_bus = data["bus"][string(branch["t_bus"])]
        y_line = branch["p_matrix"][1:n,n+1:2*n]
        for (_j,j) in enumerate(branch["f_connections"])
            if haskey(data["admittance_map"], (f_bus["bus_i"], j))
                v_f_bus[_j,1] = v[data["admittance_map"][(f_bus["bus_i"], j)],1] 
            end
        end
        for (_j,j) in enumerate(branch["t_connections"])
            if haskey(data["admittance_map"], (t_bus["bus_i"], j))
                v_t_bus[_j,1] = v[data["admittance_map"][(t_bus["bus_i"], j)],1] 
            end
        end
        i_line = y_line * (v_f_bus - v_t_bus)
        i012 = get_current_sequence(i_line,branch["f_connections"])
        branch_obj = Dict{String,Any}(
            "|I| (A)" => abs.(i_line),
            "theta (deg)" => angle.(i_line).* pi/180,
            "|I0| (A)" => abs(i012[1]),
            "|I1| (A)" => abs(i012[2]),
            "|I2| (A)" => abs(i012[3]),
        )

        if occursin("line.", branch["source_id"])
            line[branch_name] = branch_obj
        elseif occursin("switch", branch["source_id"])
            switch[branch_name] = branch_obj
        end
    end
    obj["switch"] = switch
    obj["line"] = line
    output[name] = obj
end



function build_output_schema!(output::Dict{String,Any}, v::SparseArrays.SparseMatrixCSC{ComplexF64, Int64}, data::Dict{String,Any}, y::Matrix{ComplexF64}, bus::Dict{String,Any}, fault_type::String, fault::Matrix{Real}, indx::Int)
    conductance = fault
    susceptance = conductance .* 0.0
    name = "$(bus["name"])_$(fault_type)_$(indx)"
    connections = [bus["terminals"][indx]]
    v_bus = zeros(Complex{Float64},2)
    v_bus[1,1] = v[data["admittance_map"][(bus["bus_i"],connections[1])],1]
    i = fault*v_bus
    i012 = get_current_sequence(i,connections)
    obj = Dict{String,Any}(
            "fault" => Dict{String,Any}(
                "susceptance (S)" => susceptance,
                "conductance (S)" => conductance,
                "connections" => connections,
                "bus" => bus["name"],
                "type" => fault_type,
                "|I| (A)" => abs.(i),
                "theta (deg)" => angle.(i).* pi/180,
                "|I0| (A)" => abs(i012[1]),
                "|I1| (A)" => abs(i012[2]),
                "|I2| (A)" => abs(i012[3]),
                "|V| (V)" => abs.(v_bus),
                "phi (deg)" => angle.(v_bus).*pi/180,
            )
        )
    line = Dict{String,Any}()
    switch = Dict{String,Any}()
    for (i,branch) in data["branch"]
        branch_name = branch["name"]
        n = length(branch["f_connections"])
        v_f_bus = zeros(Complex{Float64}, n)
        v_t_bus = zeros(Complex{Float64}, n)
        f_bus = data["bus"][string(branch["f_bus"])]
        t_bus = data["bus"][string(branch["t_bus"])]
        y_line = branch["p_matrix"][1:n,n+1:2*n]
        for (_j,j) in enumerate(branch["f_connections"])
            if haskey(data["admittance_map"], (f_bus["bus_i"], j))
                v_f_bus[_j,1] = v[data["admittance_map"][(f_bus["bus_i"], j)],1] 
            end
        end
        for (_j,j) in enumerate(branch["t_connections"])
            if haskey(data["admittance_map"], (t_bus["bus_i"], j))
                v_t_bus[_j,1] = v[data["admittance_map"][(t_bus["bus_i"], j)],1] 
            end
        end
        i_line = y_line * (v_f_bus - v_t_bus)
        i012 = get_current_sequence(i_line,branch["f_connections"])
        branch_obj = Dict{String,Any}(
            "|I| (A)" => abs.(i_line),
            "theta (deg)" => angle.(i_line).* pi/180,
            "|I0| (A)" => abs(i012[1]),
            "|I1| (A)" => abs(i012[2]),
            "|I2| (A)" => abs(i012[3]),
        )

        if occursin("line.", branch["source_id"])
            line[branch_name] = branch_obj
        elseif occursin("switch", branch["source_id"])
            switch[branch_name] = branch_obj
        end
    end
    obj["switch"] = switch
    obj["line"] = line
    output[name] = obj
end