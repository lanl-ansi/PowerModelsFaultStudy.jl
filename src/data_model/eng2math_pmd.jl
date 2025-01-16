
const _eng_node_elements = String[
    "load", "shunt", "generator", "solar", "storage", 
]

"list of edge type elements in the engineering model"
const _eng_edge_elements = String[
    "line", 
]

"list of all eng asset types"
const pmd_eng_asset_types = String[
    "bus", _eng_edge_elements..., _eng_node_elements...
]

const pmp_eng_asset_types = String[
    "transformer", "voltage_source", "switch",
]

const pmd_math_asset_types = String[
    "branch", "load", "gen"
]


function _map_eng2math_nw!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any}; eng2math_passthrough::Dict{String,Vector{String}}=Dict{String,Vector{String}}(), eng2math_extensions::Vector{<:Function}=Function[])
    data_math["map"] = Vector{Dict{String,Any}}([
        Dict{String,Any}("unmap_function" => "_map_math2eng_root!")
    ])

    _PMD._init_base_components!(data_math)

    for property in get(eng2math_passthrough, "root", String[])
        if haskey(data_eng, property)
            data_math[property] = deepcopy(data_eng[property])
        end
    end
    
    for type in pmd_eng_asset_types
        getfield(_PMD.PowerModelsDistribution, _PMD.Symbol("_map_eng2math_$(type)!"))(data_math, data_eng; pass_props=get(eng2math_passthrough, type, String[]))
    end

    for type in pmp_eng_asset_types
        getfield(PowerModelsProtection, Symbol("_map_eng2math_$(type)!"))(data_math, data_eng; pass_props=get(eng2math_passthrough, type, String[]))
    end

    # Custom base eng2math transformation functions for pmd assets
    _add_bus_phases_key!(data_math, data_eng)

    # Custom eng2math transformation functions
    for eng2math_func! in eng2math_extensions
        eng2math_func!(data_math, data_eng)
    end

    # post fix
    if !get(data_math, "is_kron_reduced", false)
        #TODO fix this in place / throw error instead? IEEE8500 leads to switches
        # with 3x3 R matrices but only 1 phase
        #NOTE: Don't do this when kron-reducing, it will undo the padding
        # _slice_branches!(data_math)
    end

    _PMD.find_conductor_ids!(data_math)
    
    _map_conductor_ids!(data_math)

    _PMD._map_settings_vbases_default!(data_math)

end


"alternate to pmd transformer TODO work on 3 winding"
function _map_eng2math_transformer!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    for (name, eng_obj) in get(data_eng, "transformer", Dict{Any,Dict{String,Any}}())
        push!(data_math["map"], Dict{String,Any}(
            "from" => name,
            "to" => String[],
            "unmap_function" => "_map_math2eng_transformer!",
        ))

        to_map = data_math["map"][end]["to"]

        _PMD._apply_xfmrcode!(eng_obj, data_eng)

        if haskey(eng_obj, "f_bus") && haskey(eng_obj, "t_bus")
            @assert all(haskey(eng_obj, k) for k in ["f_bus", "t_bus", "f_connections", "t_connections"]) "Incomplete definition of AL2W tranformer $name, aborting eng2math conversion"

            nphases = length(eng_obj["f_connections"])

            math_obj = Dict{String,Any}(
                "name" => name,
                "source_id" => eng_obj["source_id"],
                "f_bus" => data_math["bus_lookup"][eng_obj["f_bus"]],
                "t_bus" => data_math["bus_lookup"][eng_obj["t_bus"]],
                "f_connections" => eng_obj["f_connections"],
                "t_connections" => eng_obj["t_connections"],
                "configuration" => get(eng_obj, "configuration", WYE),
                "tm_nom" => get(eng_obj, "tm_nom", 1.0),
                "tm_set" => get(eng_obj, "tm_set", fill(1.0, nphases)),
                "tm_fix" => get(eng_obj, "tm_fix", fill(true, nphases)),
                "polarity" => get(eng_obj, "polarity", -1),
                "sm_ub" => get(eng_obj, "sm_ub", Inf),
                "cm_ub" => get(eng_obj, "cm_ub", Inf),
                "status" => Int(get(eng_obj, "status", ENABLED)),
                "index" => length(data_math["transformer"])+1,
                "dss" => eng_obj["dss"]
            )

            for k in [["tm_lb", "tm_ub"]; pass_props]
                if haskey(eng_obj, k)
                    math_obj[k] = eng_obj[k]
                end
            end

            data_math["transformer"]["$(math_obj["index"])"] = math_obj

            push!(to_map, "transformer.$(math_obj["index"])")
        else
            vnom = eng_obj["vm_nom"] * data_eng["settings"]["voltage_scale_factor"]
            snom = eng_obj["sm_nom"] * data_eng["settings"]["power_scale_factor"]

            nrw = length(eng_obj["bus"])
            
            !haskey(eng_obj["dss"], "buses") ? eng_obj["dss"]["buses"] = eng_obj["bus"] : nothing # fix to buses issue missing form dss (single buses are defined on some transformers)

            # calculate zbase in which the data is specified, and convert to SI
            zbase = (vnom.^2) ./ snom

            # x_sc is specified with respect to first winding
            x_sc = eng_obj["xsc"] .* zbase[1]

            # rs is specified with respect to each winding
            r_s = eng_obj["rw"] .* zbase

            # want percentage for matrix
            g_sh =  eng_obj["noloadloss"]
            b_sh = -eng_obj["cmag"]

            # data is measured externally, but we now refer it to the internal side
            ratios = vnom/data_eng["settings"]["voltage_scale_factor"]
            x_sc = x_sc./ratios[1]^2
            r_s = r_s./ratios.^2
            # g_sh = g_sh*ratios[1]^2
            # b_sh = b_sh*ratios[1]^2

            # convert x_sc from list of upper triangle elements to an explicit dict
            y_sh = g_sh + im*b_sh
            z_sc = Dict([(key, im*x_sc[i]) for (i,key) in enumerate([(i,j) for i in 1:nrw for j in i+1:nrw])])

            dims = length(eng_obj["tm_set"][1])
            tm_nom = eng_obj["vm_nom"]
            # for i = 1:nrw
                #     tm_nom[i] = eng_obj["configuration"][i]==_PMD.DELTA ? eng_obj["vm_nom"][i] : eng_obj["vm_nom"][i]  
                #     # tm_nom[i] = eng_obj["configuration"][i]==_PMD.DELTA ? eng_obj["vm_nom"][i]*sqrt(3) : eng_obj["vm_nom"][i] 
            # end
            t_connections = sort!(eng_obj["connections"][2])
            t_bus = data_math["bus_lookup"][eng_obj["bus"][2]]
            # 3-w transformers will have vectors: t_bus and t_connections, center_tap will have vectors: t_connections 
            # TODO make sure that the connections always coordinate with bus
            if length(eng_obj["connections"]) > 2
                t_connections = [sort!(eng_obj["connections"][2])]
                t_bus = [data_math["bus_lookup"][eng_obj["bus"][2]]]
                for row in eng_obj["connections"][2+1:end]
                    push!(t_connections, sort!(row))
                end
                for bus in eng_obj["bus"][2+1:end]
                    push!(t_bus, data_math["bus_lookup"][bus])
                end
            end
            
            transformer_obj = Dict{String,Any}(
                    "name"          => name,
                    "source_id"     => eng_obj["source_id"],
                    "f_bus"         => data_math["bus_lookup"][eng_obj["bus"][1]],
                    "t_bus"         => t_bus,
                    "tm_nom"        => tm_nom,
                    "f_connections" => sort!(eng_obj["connections"][1]),
                    "t_connections" => t_connections,
                    "configuration" => eng_obj["configuration"],
                    "polarity"      => eng_obj["polarity"],
                    "tm_set"        => eng_obj["tm_set"],
                    "tm_fix"        => eng_obj["tm_fix"],
                    "sm_ub"         => get(eng_obj, "sm_ub", Inf),
                    "cm_ub"         => get(eng_obj, "cm_ub", Inf),
                    "status"        => eng_obj["status"] == DISABLED ? 0 : 1,
                    "index"         => length(data_math["transformer"])+1,
                    "x_sc"          => x_sc,
                    "xsc"           => eng_obj["xsc"],
                    "r_s"           => r_s,
                    "rw"            => eng_obj["rw"],
                    "g_sh"          => g_sh,
                    "b_sh"          => b_sh,
                    "dss"           => haskey(eng_obj, "dss") ? eng_obj["dss"] : Dict{String,Any}(),
                    "sm_nom"        => eng_obj["sm_nom"]
            )

            for prop in [["tm_lb", "tm_ub", "tm_step"]; pass_props]
                if haskey(eng_obj, prop)
                    transformer_obj[prop] = eng_obj[prop]
                end
            end


            if haskey(transformer_obj, "vm_nom")
                if transformer_2wa_obj["dss"]["phases"] == 3
                    data_math["bus"][string(transformer_obj["f_bus"])]["vbase"] = transformer_obj["vm_nom"][1]/sqrt(3)
                    data_math["bus"][string(transformer_obj["t_bus"])]["vbase"] = transformer_obj["vm_nom"][2:end]./sqrt(3)
                else
                    data_math["bus"][string(transformer_obj["f_bus"])]["vbase"] = transformer_obj["vm_nom"][1]
                    data_math["bus"][string(transformer_obj["t_bus"])]["vbase"] = transformer_obj["vm_nom"][2:end]
                end
            end

            data_math["transformer"]["$(transformer_obj["index"])"] = transformer_obj
   
            if haskey(eng_obj,"controls") #&& !all(data_math["transformer"]["$(transformer_2wa_obj["index"])"]["tm_fix"])
                reg_obj = Dict{String,Any}(
                    "vreg" => eng_obj["controls"]["vreg"],
                    "band" => eng_obj["controls"]["band"],
                    "ptratio" => eng_obj["controls"]["ptratio"],
                    "ctprim" => eng_obj["controls"]["ctprim"],
                    "r" => eng_obj["controls"]["r"],
                    "x" => eng_obj["controls"]["x"],
                )
                data_math["transformer"]["$(transformer_obj["index"])"]["controls"] = reg_obj
                if !(haskey(data_math["controls"], "transformer"))
                    data_math["controls"]["transformer"] = Dict{String, Any}()
                end
                data_math["controls"]["transformer"]["$(transformer_obj["index"])"] = "reg"
            end
        end
    end
end


"converts engineering voltage sources into mathematical generators and (if needed) impedance branches to represent the loss model"
function _map_eng2math_voltage_source!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any}; pass_props::Vector{String}=String[])
 
    for (name, eng_obj) in get(data_eng, "voltage_source", Dict{String,Any}())

        nconductors = length(eng_obj["connections"])
        nphases = get(eng_obj, "configuration", _PMD.WYE) == _PMD.WYE && !get(data_eng, "is_kron_reduced", false) ? nconductors - 1 : nconductors

        math_obj = _PMD._init_math_obj("voltage_source", name, eng_obj, length(data_math["gen"])+1; pass_props=pass_props)

        math_obj["name"] = name
        math_obj["gen_bus"] = gen_bus = data_math["bus_lookup"][eng_obj["bus"]]
        math_obj["connections"] = eng_obj["connections"]
        math_obj["gen_status"] = status = Int(eng_obj["status"])
        math_obj["pg"] = get(eng_obj, "pg", fill(0.0, nphases))
        math_obj["qg"] = get(eng_obj, "qg", fill(0.0, nphases))
        math_obj["vg"] = eng_obj["vm"]
        math_obj["pmin"] = get(eng_obj, "pg_lb", fill(-Inf, nphases))
        math_obj["pmax"] = get(eng_obj, "pg_ub", fill( Inf, nphases))
        math_obj["qmin"] = get(eng_obj, "qg_lb", fill(-Inf, nphases))
        math_obj["qmax"] = get(eng_obj, "qg_ub", fill( Inf, nphases))
        math_obj["connections"] = eng_obj["connections"]
        math_obj["configuration"] = get(eng_obj, "configuration", _PMD.WYE)
        math_obj["control_mode"] = control_mode = Int(get(eng_obj, "control_mode", _PMD.ISOCHRONOUS))
        math_obj["source_id"] = "voltage_source.$name"
        math_obj["rs"] = eng_obj["rs"]
        math_obj["xs"] = eng_obj["xs"]
        
        _PMD._add_gen_cost_model!(math_obj, eng_obj)
 
        bus_obj = data_math["bus"]["$gen_bus"]
        bus_obj["vm"] = deepcopy(eng_obj["vm"])
        bus_obj["va"] = deepcopy(eng_obj["va"])
        bus_obj["bus_type"] = status == 0 ? 4 : 3

        if !all(isapprox.(get(eng_obj, "rs", zeros(1, 1)), 0)) && !all(isapprox.(get(eng_obj, "xs", zeros(1, 1)), 0))
            
            for (i,t) in enumerate(eng_obj["connections"])
                if data_math["bus"]["$(data_math["bus_lookup"][eng_obj["bus"]])"]["grounded"][i]
                    bus_obj["vm"][i] = 0
                    bus_obj["vmin"][i] = 0
                    bus_obj["vmax"][i] = Inf
                end
            end
                
        else
            vm_lb = control_mode == Int(_PMD.ISOCHRONOUS) ? eng_obj["vm"] : get(eng_obj, "vm_lb", fill(0.0, nphases))
            vm_ub = control_mode == Int(_PMD.ISOCHRONOUS) ? eng_obj["vm"] : get(eng_obj, "vm_ub", fill(Inf, nphases))

            data_math["bus"]["$gen_bus"]["vmin"] = [vm_lb..., [0.0 for n in 1:(nconductors-nphases)]...]
            data_math["bus"]["$gen_bus"]["vmax"] = [vm_ub..., [Inf for n in 1:(nconductors-nphases)]...]
            data_math["bus"]["$gen_bus"]["vm"] = [eng_obj["vm"]..., [0.0 for n in 1:(nconductors-nphases)]...]
            data_math["bus"]["$gen_bus"]["va"] = [eng_obj["va"]..., [0.0 for n in 1:(nconductors-nphases)]...]

            bus_type = data_math["bus"]["$gen_bus"]["bus_type"]
            data_math["bus"]["$gen_bus"]["bus_type"] = _PMD._compute_bus_type(bus_type, status, control_mode)
        end

        data_math["gen"]["$(math_obj["index"])"] = math_obj

    end
end


"converts engineering switches into mathematical switches and (if neeed) impedance branches to represent loss model"
function _map_eng2math_switch!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any}; pass_props::Vector{String}=String[])
    for (name, eng_obj) in get(data_eng, "switch", Dict{Any,Dict{String,Any}}())
   
        nphases = length(eng_obj["f_connections"])

        math_obj = _PMD._init_math_obj("switch", name, eng_obj, length(data_math["switch"])+1; pass_props=pass_props)

        math_obj["f_bus"] = data_math["bus_lookup"][eng_obj["f_bus"]]
        math_obj["t_bus"] = data_math["bus_lookup"][eng_obj["t_bus"]]
        math_obj["status"] = eng_obj["status"] == _PMD.DISABLED ? 0 : 1

        math_obj["state"] = Int(get(eng_obj, "state", _PMD.CLOSED))
        math_obj["dispatchable"] = Int(get(eng_obj, "dispatchable", _PMD.YES))

        # OPF bounds
        for (f_key, t_key) in [("cm_ub", "current_rating"), ("cm_ub_b", "c_rating_b"), ("cm_ub_c", "c_rating_c"),
            ("sm_ub", "thermal_rating"), ("sm_ub_b", "rate_b"), ("sm_ub_c", "rate_c")]
            math_obj[t_key] = haskey(eng_obj, f_key) ? eng_obj[f_key] : fill(Inf, nphases)
        end

        map_to = "switch.$(math_obj["index"])"

        if haskey(eng_obj, "linecode")
            _PMD._apply_linecode!(eng_obj, data_eng)
        end
        # TODO more test and define perfect
        if !(all(isapprox.(get(eng_obj, "rs", zeros(1, 1)), 0)) && all(isapprox.(get(eng_obj, "xs", zeros(1, 1)), 0)))
            # build virtual bus

            f_bus = data_math["bus_lookup"][eng_obj["f_bus"]]
            t_bus = data_math["bus_lookup"][eng_obj["t_bus"]]

            N = length(eng_obj["t_connections"])


            branch_obj = _PMD._init_math_obj("line", name, eng_obj, length(data_math["branch"])+1)

            _branch_obj = Dict{String,Any}(
                "name" => "_virtual_branch.switch.$name",
                "source_id" => "switch.$name",
                "f_bus" => f_bus,
                "t_bus" => t_bus,
                "f_connections" => eng_obj["t_connections"],  # the virtual branch connects to the switch on the to-side
                "t_connections" => eng_obj["t_connections"],  # should be identical to the switch's to-side connections
                "br_r" => _PMD._impedance_conversion(data_eng, eng_obj, "rs"),
                "br_x" => _PMD._impedance_conversion(data_eng, eng_obj, "xs"),
                "g_fr" => zeros(nphases, nphases),
                "g_to" => zeros(nphases, nphases),
                "b_fr" => zeros(nphases, nphases),
                "b_to" => zeros(nphases, nphases),
                "angmin" => fill(-10.0, nphases),
                "angmax" => fill( 10.0, nphases),
                "c_rating_a" => fill(Inf, nphases),
                "br_status" => eng_obj["status"] == _PMD.DISABLED ? 0 : 1,
            )

            merge!(branch_obj, _branch_obj)

            data_math["branch"]["$(branch_obj["index"])"] = branch_obj

        end

        data_math["switch"]["$(math_obj["index"])"] = math_obj

        push!(data_math["map"], Dict{String,Any}(
            "from" => name,
            "to" => map_to,
            "unmap_function" => "_map_math2eng_switch!",
        ))
    end
end


function _add_bus_phases_key!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any})
    for (_, bus) in data_math["bus"]
        phases = 0
        if !(haskey(bus, "phases"))
            for (i, terminal) in enumerate(bus["terminals"])
                if bus["grounded"][i]
                    phases += 1
                end
            end
        end
        bus["phases"] = phases
    end
end


"fix the control components by adding extra data from dss model"
function _fix_control_components!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any})
    _fix_control_load!(data_math, data_eng)
    # _fix_control_transformer!(data_math, data_eng)
end


"fix load control adds vminpu from dss"
function _fix_control_load!(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any})
    if haskey(data_math, "load")
        for (name, load) in data_math["load"]
            vminpu = .95
            vmaxpu = 1.05
            vlowpu = .5
            if haskey(load, "dss")
                if haskey(load["dss"], "vminpu")
                    load["dss"]["vminpu"] >= .75 ? vminpu = load["dss"]["vminpu"] : vminpu = .75
                end
                haskey(load["dss"], "vmaxpu") ? vmaxpu = load["dss"]["vmaxpu"] : nothing
                if haskey(load["dss"], "vlowpu")
                    load["dss"]["vlowpu"] < vminpu && load["dss"]["vlowpu"] >= .5 ? vlowpu = load["dss"]["vlowpu"] : nothing    
                end 
            end
        end
    end  
end



function _eng2math_link_transformer(data_math::Dict{String,<:Any}, data_eng::Dict{String,<:Any})
    for (_, gen) in data_math["gen"]
        if haskey(gen, "type")
            if gen["element"] == SolarElement
                # TODO adds transformer need to add for when transformer key set to false
                for (id, transformer) in data_math["transformer"]
                    if transformer["f_bus"] == gen["gen_bus"] || transformer["t_bus"] == gen["gen_bus"]
                        gen["transformer_id"] = id
                    end
                end
            end
        end
    end
end