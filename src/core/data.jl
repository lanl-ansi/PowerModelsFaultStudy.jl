"""
	check_pf!(data::Dict{String,Any}, solver)

Check to see if pf should be solved
"""
function check_pf!(data::Dict{String,Any}, solver)
    if haskey(data, "pf")
        if data["pf"] == "true"
            add_pf_data!(data, solver)
        end
    else
        add_pf_data!(data, solver)
    end
end


"""
	add_pf_data!(data::Dict{String,Any}, solver)

Adds the result from pf based on model type
"""
function add_pf_data!(data::Dict{String,Any}, solver)
    if haskey(data, "method") && data["method"] in ["PMD", "solar-pf"]
        @debug "Adding PF results to network"
        result = solve_mc_pf(data, solver)
        add_mc_pf_data!(data, result)
    elseif haskey(data, "method") && data["method"] == "dg-pf"
        @debug "Adding PF results to network"
        result = solve_mc_dg_pf(data, solver)
        add_pf_data!(data, result)
    elseif haskey(data, "method") && data["method"] in ["PMs", "pf"]
        @debug "Adding PF results to network"
        result = _PM.run_pf(data, _PM.ACPPowerModel, solver)
        add_pf_data!(data, result)
    elseif haskey(data, "method") && data["method"] == "opf"
        @debug "Adding OPF results to network"
        result = _PM.run_opf(data, _PM.ACPPowerModel, solver)
        add_pf_data!(data, result)
    else
        @debug "Not performing pre-fault power flow"
    end
    @debug "Done adding results to network"

end


"""
	add_pf_data!(data::Dict{String,Any}, result::Dict{String,Any})

Adds the result from pf
"""
function add_pf_data!(data::Dict{String,Any}, result::Dict{String,Any})
    if result["primal_status"] == FEASIBLE_POINT
        for (i, bus) in result["solution"]["bus"]
            data["bus"][i]["vm"] = bus["vm"]
            data["bus"][i]["va"] = bus["va"]
            @debug "Adding powerflow solution to bus $i"
            # @debug "Adding powerflow solution to bus $i"
        end
        for (i, gen) in result["solution"]["gen"]
            data["gen"][i]["pg"] = gen["pg"]
            data["gen"][i]["qg"] = gen["qg"]
            @debug "Adding powerflow solution to gen $i"
            # @debug "Adding powerflow solution to bus $i"
        end
    else
        @debug "The model power flow returned infeasible"
    end
end


"""
	add_mc_pf_data!(data::Dict{String,Any}, result::Dict{String,Any})

Add the result from pf returning in the engineer model format
"""
function add_mc_pf_data!(data::Dict{String,Any}, result::Dict{String,Any})
    if result["primal_status"] == FEASIBLE_POINT
        for (i, bus) in result["solution"]["bus"]
            bus_index = string(data["bus_lookup"][i])
            data["bus"][bus_index]["vr"] = bus["vr"]
            data["bus"][bus_index]["vi"] = bus["vi"]
        end
    else
        @warn "The model power flow returned infeasible"
    end
end


"""
    build_fault_study(data::Dict; default_fault_resistance::Real=0.0001)

Builds a dictionary of fault studies on a transmission (single-phase positive sequence) network
that are intended to be used in conjunction with [`solve_fault_study`](@ref solve_fault_study).

The function will iterate over all buses and create faults using the default fault resistance.
The fault study dictionary will have the following structure:

```julia
    Dict{String,Any}(
        "bus_i" => Dict{String,Any}(
            "fault_bus" => bus_i
            "gf" => 1 / resistance,
            "status" => 1
        ),
        ...
    )
```
"""
function build_fault_study(data::Dict{String,<:Any}; default_fault_resistance::Real=0.0001)::Dict{String,Any}
    fault_studies = Dict{String,Any}()

    if haskey(data, "bus")
        for (i, bus) in data["bus"]
            fault_studies[i] = add_fault!(Dict{String,Any}(), parse(Int, i), bus["bus_i"], default_fault_resistance)
        end
    end

    return fault_studies
end


"""
    add_fault!(data::Dict, fault_id::Int, bus_id::Int, resistance::Real)

Helper function to add a fault using a fault resistance to a transmission data set.
"""
function  add_fault!(data::Dict{String,<:Any}, id::Int, bus_i::Int, resistance::Real)
    if !haskey(data, "fault")
        data["fault"] = Dict{String,Any}()
    end

    data["fault"]["$id"] = Dict{String,Any}(
        "fault_bus" => bus_i,
        "gf" => max(1 / resistance, 1e-6),
        "status" => 1,
        "index" => id,
    )
end


"""
    build_mc_fault_study(data::Dict{String,<:Any}; resistance::Real=0.01, phase_resistance::Real=0.01)::Dict{String,Any}

Add all fault type data to model for study for multiconductor networks
"""
function build_mc_fault_study(data::Dict{String,<:Any}; resistance::Real=0.01, phase_resistance::Real=0.01)::Dict{String,Any}
    # TODO better detection of neutral vs ground phases, ground is currently hardcoded as 4

    fault_studies = Dict{String,Any}()
    vsource_buses = Set([vsource["bus"] for (_,vsource) in get(data, "voltage_source", Dict())])

    for (id, bus) in get(data, "bus", Dict())
        if !(id in vsource_buses)
            fault_studies[id] = Dict{String,Any}(
                "lg" => Dict{String,Any}(),
                "ll" => Dict{String,Any}(),
                "llg" => Dict{String,Any}(),
                "3p" => Dict{String,Any}(),
                "3pg" => Dict{String,Any}(),
            )

            i = 1
            for t in bus["terminals"]
                ground_terminal = !isempty(bus["grounded"]) ? bus["grounded"][end] : 4
                if !(t in bus["grounded"])
                    fault_studies[id]["lg"]["$i"] = add_fault!(Dict{String,Any}(), "1", "lg", id, [t, ground_terminal], resistance)
                    i += 1
                end
            end

            i = 1
            for t in bus["terminals"]
                ground_terminal = !isempty(bus["grounded"]) ? bus["grounded"][end] : 4
                if !(t in bus["grounded"])
                    for u in bus["terminals"]
                        if !(u in bus["grounded"]) && t != u && t < u
                            fault_studies[id]["ll"]["$i"] = add_fault!(Dict{String,Any}(), "1", "ll", id, [t, u], phase_resistance)
                            fault_studies[id]["llg"]["$i"] = add_fault!(Dict{String,Any}(), "1", "llg", id, [t, u, ground_terminal], resistance, phase_resistance)
                            i += 1
                        end
                    end
                end
            end

            if length(bus["terminals"]) >= 3
                fault_studies[id]["3p"]["1"] = add_fault!(Dict{String,Any}(), "1", "3p", id, bus["terminals"][1:3], phase_resistance)
                if length(bus["terminals"]) >= 4
                    fault_studies[id]["3pg"]["1"] = add_fault!(Dict{String,Any}(), "1", "3pg", id, bus["terminals"][1:4], resistance, phase_resistance)
                else
                    fault_studies[id]["3pg"]["1"] = add_fault!(Dict{String,Any}(), "1", "3pg", id, [bus["terminals"][1:3]; 4], resistance, phase_resistance)
                end
            end

        end
    end

    return fault_studies
end


"""
    build_mc_sparse_fault_study(data::Dict{String,<:Any}; resistance::Real=0.01, phase_resistance::Real=0.01)::Dict{String,Any}

Builds sparse collection of fault studies using a network graph
"""
function build_mc_sparse_fault_study(data::Dict{String,<:Any}; resistance::Real=0.01, phase_resistance::Real=0.01)::Dict{String,Any}
    fault_studies = Dict{String,Any}()
    fault_bus_ids = Set()
    vsource_bus_ids = Set([vsource["bus"] for (_,vsource) in get(data, "voltage_source", Dict())])

    bus_ids = Dict(enumerate(keys(data["bus"])))
    bus_nums = Dict([k => i for (i,k) in enumerate(keys(data["bus"]))])
    g = Graphs.SimpleGraph(length(bus_nums))

    if haskey(data, "line")
        for (_, device_obj) in data["line"]
            Graphs.add_edge!(g, bus_nums[device_obj["f_bus"]], bus_nums[device_obj["t_bus"]])
        end
    end

    if haskey(data, "switch")
        for (_, device_obj) in data["switch"]
            push!(fault_bus_ids, device_obj["f_bus"])
            push!(fault_bus_ids, device_obj["t_bus"])
            Graphs.add_edge!(g, bus_nums[device_obj["f_bus"]], bus_nums[device_obj["t_bus"]])
        end
    end

    if haskey(data, "transformer")
        for (_, device_obj) in data["transformer"]
            if haskey(device_obj, "f_bus") && haskey(device_obj, "t_bus")
                push!(fault_bus_ids, device_obj["f_bus"])
                push!(fault_bus_ids, device_obj["t_bus"])
                Graphs.add_edge!(g, bus_nums[device_obj["f_bus"]], bus_nums[device_obj["t_bus"]])
            else
                for f_bus in device_obj["bus"]
                    push!(fault_bus_ids, f_bus)
                    for t_bus in device_obj["bus"]
                        if f_bus != t_bus
                            Graphs.add_edge!(g, bus_nums[f_bus], bus_nums[t_bus])
                        end
                    end
                end
            end
        end
    end

    generation_devices = ["generator", "solar", "storage"]
    for device in generation_devices
        for (_, device_obj) in get(data, device, Dict())
            push!(fault_bus_ids, device_obj["bus"])
        end
    end

    protection_devices = ["fuse", "relay"]
    for device in protection_devices
        for (_, device_obj) in get(data, device, Dict())
            if haskey(data[device_obj["monitor_type"]], device_obj["monitoredobj"])
                monitor_obj = data[device_obj["monitor_type"]][device_obj["monitoredobj"]]
                if device_obj["monitor_type"] == "line"
                    push!(fault_bus_ids, monitor_obj["f_bus"])
                    push!(fault_bus_ids, monitor_obj["t_bus"])
                else
                    push!(fault_bus_ids, monitor_obj["bus"])
                end
            end
        end
    end

    for (node_index, node_degree) in enumerate(Graphs.degree(g))
        if node_degree == 1 && !(bus_ids[node_index] in vsource_bus_ids)
            push!(fault_bus_ids, bus_ids[node_index])
        end
    end


    for id in fault_bus_ids
        bus = data["bus"][id]
        if !(id in vsource_bus_ids)
            fault_studies[id] = Dict{String,Any}(
                "lg" => Dict{String,Any}(),
                "ll" => Dict{String,Any}(),
                "llg" => Dict{String,Any}(),
                "3p" => Dict{String,Any}(),
                "3pg" => Dict{String,Any}(),
            )

            i = 1
            for t in bus["terminals"]
                ground_terminal = !isempty(bus["grounded"]) ? bus["grounded"][end] : 4
                if !(t in bus["grounded"])
                    fault_studies[id]["lg"]["$i"] = add_fault!(Dict{String,Any}(), "1", "lg", id, [t, ground_terminal], resistance)
                    i += 1
                end
            end

            i = 1
            for t in bus["terminals"]
                ground_terminal = !isempty(bus["grounded"]) ? bus["grounded"][end] : 4
                if !(t in bus["grounded"])
                    for u in bus["terminals"]
                        if !(u in bus["grounded"]) && t != u && t < u
                            fault_studies[id]["ll"]["$i"] = add_fault!(Dict{String,Any}(), "1", "ll", id, [t, u], phase_resistance)
                            fault_studies[id]["llg"]["$i"] = add_fault!(Dict{String,Any}(), "1", "llg", id, [t, u, ground_terminal], resistance, phase_resistance)
                            i += 1
                        end
                    end
                end
            end

            if length(bus["terminals"]) >= 3
                fault_studies[id]["3p"]["1"] = add_fault!(Dict{String,Any}(), "1", "3p", id, bus["terminals"][1:3], phase_resistance)
                if length(bus["terminals"]) >= 4
                    fault_studies[id]["3pg"]["1"] = add_fault!(Dict{String,Any}(), "1", "3pg", id, bus["terminals"][1:4], resistance, phase_resistance)
                else
                    fault_studies[id]["3pg"]["1"] = add_fault!(Dict{String,Any}(), "1", "3pg", id, [bus["terminals"][1:3]; 4], resistance, phase_resistance)
                end
            end

        end
    end

    return fault_studies
end


"""
	get_mc_fault_buses(data::Dict{String,Any})

Creates a list of buses in the model to fault for study
"""
function get_mc_fault_buses(data::Dict{String,Any})
    hold = []
    vsource_buses = Set([vsource["bus"] for (_,vsource) in get(data, "voltage_source", Dict())])

    for (id,_) in get(data, "bus", Dict())
        if !(id in vsource_buses)
            push!(hold, id)
        end
    end
    hold
end


"""
	check_microgrid!(data::Dict{String,Any})

Checks for a microgrid and deactivates infinite bus
"""
function check_microgrid!(data::Dict{String,Any})
    if haskey(data, "microgrid")
        if data["microgrid"]
            index_bus = 0
            index_gen = 0
            bus_i = 0
            for (index, bus) in data["bus"]
                if bus["bus_type"] == 3
                    bus_i = bus["bus_i"]
                    index_bus = index
                end
            end
            for (index, gen) in data["gen"]
                gen["gen_bus"] == bus_i ? index_gen = index : nothing
            end
            delete!(data["bus"], index_bus)
            delete!(data["gen"], index_gen)
        end
    end
end


"""
    prepare_transmission_data!(
        data::Dict{String,<:Any};
        flat_start::Bool=false,
        neglect_line_charging::Bool=false,
        neglect_transformer::Bool=false,
        zero_gen_setpoints::Bool=false
    )

Helper function to help perform some common data preparation tasks on transmission data sets.

Includes the following action options

- [`flat_start!`](@ref flat_start!)
- [`neglect_line_charging!`](@ref neglect_line_charging!)
- [`neglect_transformer!`](@ref neglect_transformer!)
- [`zero_gen_setpoints!`](@ref zero_gen_setpoints!)

"""
function prepare_transmission_data!(
    data::Dict{String,<:Any};
    flat_start::Bool=false,
    neglect_line_charging::Bool=false,
    neglect_transformer::Bool=false,
    zero_gen_setpoints::Bool=false)

    flat_start && flat_start!(data)
    neglect_line_charging && neglect_line_charging!(data)
    neglect_transformer && neglect_transformer!(data)
    zero_gen_setpoints && zero_gen_setpoints!(data)
end


"""
    flat_start!(data::Dict{String,<:Any})

Sets bus voltage magnitudes to one, and voltage angles to zero, and widens bounds on voltage magnitude to [0,2]
"""
function flat_start!(data::Dict{String,<:Any})
    if haskey(data, "bus")
        for (_,b) in data["bus"]
            b["vm"] = 1
            b["va"] = 0
            b["vmax"] = 2
            b["vmin"] = 0
        end
    end
end


"""
    neglect_line_charging!(data::Dict{String,<:Any})

Sets b_fr and b_to on branches to zero
"""
function neglect_line_charging!(data::Dict{String,<:Any})
    if haskey(data, "branch")
        for (_,br) in data["branch"]
            br["b_fr"] = 0
            br["b_to"] = 0
        end
    end
end


"""
    neglect_transformer!(data::Dict{String,<:Any})

Sets tap to one and shift to zero on all branches
"""
function neglect_transformer!(data::Dict{String,<:Any})
    if haskey(data, "branch")
        for (_,br) in data["branch"]
            br["tap"] = 1
            br["shift"] = 0
        end
    end
end


"""
    zero_gen_setpoints!(data::Dict{String,<:Any})

Sets pg and qg to zero on all generators
"""
function zero_gen_setpoints!(data::Dict{String,<:Any})
    if haskey(data, "gen")
        for (_,g) in data["gen"]
            g["pg"] = 0
            g["qg"] = 0
        end
    end
end


"""
    function to calculate line parameters based of carson's equation 1st term only 
"""
function calc_line_paramters!(line::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    if length(line["rs"]) != length(line["f_connections"])^2
        nothing
    end
end


function add_pre_fault!(pre_v, model::AdmittanceModel)
    add_pre_fault_bus_voltage!(pre_v, model)
    add_pre_fault_gfli_current!(pre_v, model)
end


function add_pre_fault_bus_voltage!(pre_v, model::AdmittanceModel)
    for (_, bus) in model.data["bus"]
        _v = zeros(Complex{Float64}, 1, length(bus["terminals"]))
        for (i, j) in enumerate(bus["terminals"])
            if haskey(model.data["admittance_map"], (bus["bus_i"], j))
                _v[1, i] = pre_v[model.data["admittance_map"][(bus["bus_i"], j)], 1]
            end
        end
        bus["pre_fault"] = _v
    end
end

function add_pre_fault_gfli_current!(pre_v, model::AdmittanceModel)
    for (_, gen) in model.data["gen"]
        if gen["element"] == SolarElement
            transformer = model.data["transformer"][gen["transformer_id"]]
            if gen["phases"] == 3
                f_bus = transformer["f_bus"]
                t_bus = transformer["t_bus"]
                y = transformer["p_matrix"]
                n = size(y)[1]
                _v = zeros(Complex{Float64}, n, 1)
                for (i, j) in enumerate(transformer["f_connections"])
                    if haskey(model.data["admittance_map"], (f_bus, j)) 
                        _v[i, 1] = pre_v[model.data["admittance_map"][(f_bus, j)], 1]
                    else
                        _v[i, 1] = 0.0 + 0.0im
                    end
                end
                for (i, j) in enumerate(transformer["t_connections"])
                    if haskey(model.data["admittance_map"], (t_bus, j))
                        _v[i+length(transformer["t_connections"]), 1] = pre_v[model.data["admittance_map"][(t_bus, j)], 1]
                    else
                        _v[i+length(transformer["t_connections"]), 1] = 0.0 + 0.0im
                    end
                end
                _i = y * _v
                gen["pre_fault"] = _i
            end
        end
    end
end


function add_mc_last_current_keys!(data::Dict{String,<:Any})
    if haskey(data, "load")
        for (name, load) in data["load"]
            load["i_last"] = [0.0 + 0.0im for (i, _) in enumerate(load["pd"])]
        end
    end
end


function build_mc_fault_study(model::AdmittanceModel)
    faults = Dict{String, Any}()
    for (i, bus) in model.data["bus"]
        fault = faults[i] = Dict{String, Any}()
        terminals = [j for j in bus["terminals"] if haskey(model.data["admittance_map"], (bus["bus_i"], j))]
        if length(terminals) == 3
            fault["3p"] = Dict{String, Any}()
            fault["3pg"] = Dict{String, Any}()
            Gf = build_mc_3p_gf(model, terminals)
            fault["3p"]["1"] = Dict(
                "terminals" => terminals,
                "Gf" => Gf,
            )
            Gf = build_mc_3pg_gf(model, terminals)
            fault["3pg"]["1"] = Dict(
                "terminals" => terminals,
                "Gf" => Gf,
            )
        end
        if length(terminals) >= 2
            fault["ll"] = Dict{String, Any}()
            fault["llg"] = Dict{String, Any}()
            indx = 1
            for n in terminals
                for m in terminals
                    if n < m
                        Gf = build_mc_ll_gf(model, [n, m])
                        fault["ll"]["$(indx)"] = Dict(
                            "terminals" => [n, m],
                            "Gf" => Gf,
                        )
                        Gf = build_mc_llg_gf(model, [n, m])
                        fault["llg"]["$(indx)"] = Dict(
                            "terminals" => [n, m],
                            "Gf" => Gf,
                        )
                        indx += 1
                    end
                end
            end
        end
        fault["lg"] = Dict{String, Any}()
        indx = 1
        for n in terminals
            Gf = build_mc_lg_gf(model, [n])
            fault["lg"]["$(indx)"] = Dict(
                "terminals" => [n],
                "Gf" => Gf,
            )
            indx += 1
        end
    end
    return faults
end