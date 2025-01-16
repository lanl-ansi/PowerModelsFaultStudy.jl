"helper function to transformer fault objects from ENGINEERING to MATHEMATICAL data models"
function _eng2math_fault!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any})
    if !haskey(data_math, "fault")
        data_math["fault"] = Dict{String,Any}()
    end

    pass_props = ["status", "connections", "g", "b"]

    for (name, eng_obj) in get(data_eng, "fault", Dict())
        # TODO bug in PMD, kron_reduced not in data_eng, apply by default for now
        if true # get(data_eng, "kron_reduced", false)
            # kron reduce g, b, connections
            # TODO better kr_neutral detection
            f = _PMD._kron_reduce_branch!(eng_obj, String[], ["g", "b"], eng_obj["connections"], 4)
            _PMD._apply_filter!(eng_obj, ["connections"], f)
        end

        math_obj = _PMD._init_math_obj("fault", name, eng_obj, length(data_math["fault"]) + 1; pass_props=pass_props)

        math_obj["fault_bus"] = data_math["bus_lookup"][eng_obj["bus"]]

        data_math["fault"]["$(math_obj["index"])"] = math_obj

        push!(data_math["map"], Dict{String,Any}(
            "from" => name,
            "to" => "fault.$(math_obj["index"])",
            "unmap_function" => "_map_math2eng_fault!",
            "apply_to_subnetworks" => true,
        ))
    end
end


"helper function to transform protection equipment objects from ENGINEERING to MATHEMATICAL data models"
function _eng2math_protection!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any})
    map_dict = Dict{String,Any}("bus" => Dict{String,Any}(), "branch" => Dict{String,Any}())
    for (_, obj) in get(data_math, "branch", Dict())
        map_dict["branch"]["$(obj["name"])"] = obj["index"]
    end
    for (_, obj) in get(data_math, "bus", Dict())
        map_dict["bus"]["$(obj["name"])"] = obj["index"]
    end
    ct_map = Dict{String,Any}()
    curve_map = Dict{String,Any}()

    if "C_Transformers" in keys(data_eng["protection"])
        pass_props = ["turns", "element"]
        if !haskey(data_math, "c_transformer")
            data_math["c_transformer"] = Dict{String,Any}()
        end
        for (name, eng_obj) in get(data_eng["protection"], "C_Transformers", Dict())
            math_obj = _PMD._init_math_obj("c_transformer", name, eng_obj, length(data_math["c_transformer"]) + 1; pass_props=pass_props)
            math_obj["prot_obj"] = :branch
            math_obj["element_enum"] = map_dict["branch"]["$(math_obj["element"])"]
            data_math["c_transformer"]["$(math_obj["index"])"] = math_obj
            push!(data_math["map"], Dict{String,Any}(
                "from" => name,
                "to" => "c_transformer.$(math_obj["index"])",
                "unmap_function" => "_map_math2eng_protection!",
                "apply_to_subnetworks" => true,
            )
            )
            ct_map["$name"] = length(data_math["c_transformer"])
        end
    end

    if "relays" in keys(data_eng["protection"])
        pass_props = ["TDS", "TS", "phase", "breaker_time", "shots", "type", "CT", "CTs", "trip", "restraint", "element2", "state"]
        if !haskey(data_math, "relay")
            data_math["relay"] = Dict{String,Any}()
        end
        for (element_name, relay_dict) in get(data_eng["protection"], "relays", Dict())
            for (name, eng_obj) in relay_dict
                math_obj = _PMD._init_math_obj("relay", name, eng_obj, length(data_math["relay"]) + 1; pass_props=pass_props)
                if haskey(math_obj, "CT")
                    math_obj["ct_enum"] = ct_map["$(math_obj["CT"])"]
                elseif haskey(math_obj, "CTs")
                    math_obj["cts_enum"] = []
                    for i = 1:length(math_obj["CTs"])
                        push!(math_obj["cts_enum"], ct_map["$(math_obj["CTs"][i])"])
                    end
                end
                if haskey(map_dict["branch"], element_name)
                    math_obj["prot_obj"] = :branch
                    math_obj["element_enum"] = map_dict["branch"]["$element_name"]
                else
                    math_obj["prot_obj"] = :bus
                    math_obj["element_enum"] = map_dict["bus"]["$element_name"]
                end

                if haskey(math_obj, "element2")
                    math_obj["element2_enum"] = map_dict["branch"]["$(math_obj["element2"])"]
                end
                math_obj["element"] = element_name
                data_math["relay"]["$(math_obj["index"])"] = math_obj
                push!(data_math["map"], Dict{String,Any}(
                    "from" => name,
                    "to" => "relay.$(math_obj["index"])",
                    "unmap_function" => "_map_math2eng_protection!",
                    "apply_to_subnetworks" => true,
                )
                )
            end
        end
    end

    if "curves" in keys(data_eng["protection"])
        pass_props = ["curve_mat"]
        if !haskey(data_math, "curve")
            data_math["curve"] = Dict{String,Any}()
        end
        for (name, eng_obj) in get(data_eng["protection"], "curves", Dict())
            math_obj = _PMD._init_math_obj("curve", name, eng_obj, length(data_math["curve"]) + 1; pass_props=pass_props)
            data_math["curve"]["$(math_obj["index"])"] = math_obj
            push!(data_math["map"], Dict{String,Any}(
                "from" => name,
                "to" => "curve.$(math_obj["index"])",
                "unmap_function" => "_map_math2eng_protection!",
                "apply_to_subnetworks" => true,
            )
            )
            curve_map["$name"] = length(data_math["curve"])
        end
    end

    if "fuses" in keys(data_eng["protection"])
        pass_props = ["min_melt_curve", "max_clear_curve", "phase"]
        if !haskey(data_math, "fuse")
            data_math["fuse"] = Dict{String,Any}()
        end
        for (line_name, fuse_dict) in get(data_eng["protection"], "fuses", Dict())
            for (name, eng_obj) in fuse_dict
                math_obj = _PMD._init_math_obj("fuse", name, eng_obj, length(data_math["fuse"]) + 1; pass_props=pass_props)
                math_obj["element"] = line_name
                math_obj["element_enum"] = map_dict["branch"]["$line_name"]
                if (typeof(math_obj["max_clear_curve"]) == String) || (typeof(math_obj["max_clear_curve"]) == SubString{String})
                    math_obj["max_clear_curve_enum"] = curve_map["$(math_obj["max_clear_curve"])"]
                end
                if (typeof(math_obj["min_melt_curve"]) == String) || (typeof(math_obj["min_melt_curve"]) == SubString{String})
                    math_obj["min_melt_curve_enum"] = curve_map["$(math_obj["min_melt_curve"])"]
                end
                data_math["fuse"]["$(math_obj["index"])"] = math_obj
                push!(data_math["map"], Dict{String,Any}(
                    "from" => name,
                    "to" => "fuse.$(math_obj["index"])",
                    "unmap_function" => "_map_math2eng_protection!",
                    "apply_to_subnetworks" => true,
                )
                )
            end
        end
    end


end


"field/values to passthrough from the ENGINEERING to MATHEMATICAL data models"
const _pmp_eng2math_passthrough = Dict{String,Vector{String}}(
        "generator" => String["zr", "zx", "gen_model", "xdp", "rp", "xdpp", "vnom_kv", "phases", "response", "element"],
        "solar" => String["i_max", "solar_max", "kva", "pf", "grid_forming", "balanced", "vminpu", "transformer", "type", "pv_model", "phases", "response", "element", "fault_model", "i_nom", "i+", "i-", "p_control"],
        "voltage_source" => String["zr", "zx", "phases", "response", "element"],
        "load" => String["vminpu", "vmaxpu", "response", "phases", "element"],
        "transformer" => String["leadlag", "phases", "element"]
    )


"custom version of `transform_data_model` from PowerModelsDistribution for easy model transformation"
transform_data_model(
    data::Dict{String,<:Any};
    eng2math_extensions::Vector{<:Function}=Function[],
    make_pu_extensions::Vector{<:Function}=Function[],
    kwargs...) = _PMD.transform_data_model(
    data;
    eng2math_extensions=[_eng2math_fault!, _eng2math_protection!, eng2math_extensions...],
    eng2math_passthrough=_pmp_eng2math_passthrough,
    make_pu_extensions=[_rebase_pu_fault!, _rebase_pu_gen_dynamics!, make_pu_extensions...],
    kwargs...)


"admittance model"
const _mc_admittance_asset_types = [
    "line", "voltage_source", "load", "transformer", "shunt", "solar", "generator"
]

"custom version of 'transform_data_model' to build admittance model and deal with transformers"
function transform_admittance_data_model(
    data::Dict{String,<:Any};
    global_keys::Set{String}=Set{String}(),
    eng2math_passthrough::Dict{String,<:Vector{<:String}}=_pmp_eng2math_passthrough,
    eng2math_extensions::Vector{<:Function}=Function[],
    make_pu::Bool=true,
    make_pu_extensions::Vector{<:Function}=Function[],
    build_model::Bool=false,
    correct_network_data::Bool=true,
    kwargs...,
)::Dict{String,Any}

    if data["method"] == "PM"
        # TODO work on transmission admittance model
    elseif data["method"] == "PMD"
        data_math = _map_eng2math_mc_admittance(
            data;
            eng2math_extensions=[_eng2math_link_transformer, eng2math_extensions...],
            # eng2math_extensions = [_eng2math_gen_model!], # TODO concat eng2math_extensions
            eng2math_passthrough=eng2math_passthrough,
            make_pu_extensions=make_pu_extensions,
            global_keys=global_keys,
            build_model=build_model,
            kwargs...
        )

        correct_network_data && correct_network_data!(data_math)

        correct_grounds!(data_math)

        populate_bus_voltages!(data_math)

        add_mc_last_current_keys!(data_math)

        return data_math
    end
end


"base function for converting mc engineering model to mathematical with admittances"
function _map_eng2math_mc_admittance(
    data_eng::Dict{String,<:Any};
    eng2math_passthrough::Dict{String,<:Vector{<:String}}=Dict{String,Vector{String}}(),
    eng2math_extensions::Vector{<:Function}=Function[],
    make_pu::Bool=true,
    make_pu_extentions::Vector{<:Function}=Function[],
    global_keys::Set{String}=Set{String}(),
    build_model::Bool=false,
    kwargs...,
)::Dict{String,Any}

    _data_eng = deepcopy(data_eng)

    # any pre-processing of data here

    # TODO kron

    # TODO phase projection

    if ismultinetwork(data_eng)
        #  TODO multi network
    else
        data_math = Dict{String,Any}(
            "name" => get(_data_eng, "name", ""),
            "per_unit" => get(_data_eng, "per_unit", false),
            "data_model" => _PMD.MATHEMATICAL,
            "is_projected" => get(_data_eng, "is_projected", false),
            "is_kron_reduced" => get(_data_eng, "is_kron_reduced", false),
            "settings" => deepcopy(_data_eng["settings"]),
            "time_elapsed" => get(_data_eng, "time_elapsed", 1.0),
        )
    end
    data_math["controls"] = Dict{String, Any}()
    
    _map_eng2math_nw!(data_math, data_eng, eng2math_passthrough=eng2math_passthrough, eng2math_extensions=eng2math_extensions)

    _apply_mc_admittance!(_map_eng2math_mc_admittance_nw!, data_math, _data_eng; eng2math_passthrough=eng2math_passthrough, eng2math_extensions=eng2math_extensions)

    # admittance_bus_order!(data_math)
    return data_math
end


function _apply_mc_admittance!(func!::Function, data1::Dict{String,<:Any}, data2::Dict{String,<:Any}; kwargs...)
    func!(data1, data2; kwargs...)
end


function _map_eng2math_mc_admittance_nw!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any}; eng2math_passthrough::Dict{String,<:Vector{<:String}}=Dict{String,Vector{String}}(), eng2math_extensions::Vector{<:Function}=Function[])
    for type in _mc_admittance_asset_types # --> anything from missing from the model needed for the solve or admittance matrix maybe per unit to actual
        getfield(PowerModelsProtection, Symbol("_map_eng2math_mc_admittance_$(type)!"))(data_math, data_eng; pass_props=get(eng2math_passthrough, type, String[]))
    end
end


# "mod with out per unit corrections see: common.jl in io PowerModelsDistribution"
function correct_network_data!(data::Dict{String,Any})
    if _PMD.iseng(data)
        _PMD.check_eng_data_model(data)
    elseif _PMD.ismath(data)
        nothing
        # check_connectivity(data) not done here becuase checks are performed during admittance creation

        # correct_branch_directions!(data) used to tell if parallel lines are in same direction
        # check_branch_loops(data) ill add check in admit creation

        # correct_bus_types!(data) check for islands, slack and no slack and fixes. will need to add TODO

        #  TODO propagate_network_topology!(data) need to add chck for it

        #  no pu
        # if make_pu
        #     make_per_unit!(data; make_pu_extensions=make_pu_extensions)

        #     correct_mc_voltage_angle_differences!(data)
        #     correct_mc_thermal_limits!(data)

        #     correct_cost_functions!(data)
        #     standardize_cost_terms!(data)
        # end
    end
end

function populate_bus_voltages!(data::Dict{String,Any})
    for (i, transformer) in data["transformer"]
        f_bus = transformer["f_bus"]
        t_bus = transformer["t_bus"]
        if haskey(transformer, "tm_nom")
            transformer["phases"] == 3 ? multi = 1 / sqrt(3) : multi = 1
            if !haskey(data["bus"][string(f_bus)], "vbase")
                data["bus"][string(f_bus)]["vbase"] = transformer["tm_nom"][1] * multi
            end
            # Vector{Vector{Int}}
            if typeof(t_bus) == Vector{Int64}
                for (indx, bus) in enumerate(t_bus)
                    if !haskey(data["bus"][string(bus)], "vbase")
                        data["bus"][string(bus)]["vbase"] = transformer["tm_nom"][indx+1] * multi
                    end
                end
            else
                if !haskey(data["bus"][string(t_bus)], "vbase")
                    data["bus"][string(t_bus)]["vbase"] = transformer["tm_nom"][2] * multi
                end
            end
        end
    end

    propagate_voltages!(data)

    for (i, gen) in data["gen"]
        if !haskey(data["bus"][string(gen["gen_bus"])], "vbase")
            if gen["element"] == VoltageSourceElement
                data["bus"][string(gen["gen_bus"])]["vbase"] = gen["vg"][1]
            end
        end
    end
    propagate_voltages!(data)

end


function propagate_voltages!(data::Dict{String,Any})
    buses = collect(keys(data["bus"]))
    for (i, bus) in data["bus"]
        !haskey(bus, "vbase") ? filter!(n -> n != string(i), buses) : nothing
    end

    found = true
    while found
        found = false
        for (i, branch) in data["branch"]
            f_bus = string(branch["f_bus"])
            t_bus = string(branch["t_bus"])
            if f_bus in buses
                if t_bus in buses
                    nothing
                else
                    data["bus"][t_bus]["vbase"] = data["bus"][f_bus]["vbase"]
                    found = true
                    push!(buses, t_bus)
                end
            elseif t_bus in buses
                if f_bus in buses
                    nothing
                else
                    data["bus"][f_bus]["vbase"] = data["bus"][t_bus]["vbase"]
                    found = true
                    push!(buses, f_bus)
                end
            end
        end
    end
end


function correct_grounds!(data::Dict{String,Any})
    for (i, transformer) in data["transformer"]
        for (i, config) in enumerate(transformer["configuration"])
            if config == _PMD.WYE
                buses = isa(transformer["dss"]["buses"], String) ? split(transformer["dss"]["buses"]) : transformer["dss"]["buses"]
                if occursin(".1.2.3.0", buses[i])
                    if i == 2
                        transformer["t_connections"] = [1, 2, 3, 4]
                        data["bus"][string(transformer["t_bus"])]["terminals"] = [1, 2, 3, 4]
                        data["bus"][string(transformer["t_bus"])]["grounded"] = Bool[0, 0, 0, 1]
                    end
                end
            end
        end
    end
end

