if Pkg.dependencies()[UUIDs.UUID("d7431456-977f-11e9-2de3-97ff7677985e")].version < v"0.15.0"

    "helper function to build extra dynamics information for pvsystem objects
        model = 1:P Q gen  2: constant z  3: P V gen  4: balance Voltage
        balanced = current balance true or false
        transformer = true (contained in model) or false (not in model)
    "
    function _dss2eng_solar_dynamics!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
        if haskey(data_eng, "solar")
            for (id, solar) in data_eng["solar"]
                dss_obj = data_dss["pvsystem"][id]
                _PMD._apply_like!(dss_obj, data_dss, "pvsystem")
                defaults = _PMD._apply_ordered_properties(_PMD._create_pvsystem(id; _PMD._to_kwargs(dss_obj)...), dss_obj)
                if haskey(dss_obj, "irradiance")
                    irradiance = dss_obj["irradiance"]
                else
                    irradiance = defaults["irradiance"]
                end
                if haskey(dss_obj, "vminpu")
                    vminpu = dss_obj["vminpu"]
                else
                    vminpu = defaults["vminpu"]
                end
                if haskey(dss_obj, "kva")
                    kva = dss_obj["kva"]
                else
                    kva = defaults["kva"]
                end
                if haskey(dss_obj, "pmpp")
                    pmpp = dss_obj["pmpp"]
                else
                    pmpp = defaults["pmpp"]
                end
                if haskey(dss_obj, "pf")
                    pf = dss_obj["pf"]
                    if abs(sum(solar["pg"]) + 1im * sum(solar["qg"])) > kva
                        solar["pg"] = [kva / length(solar["pg"]) * pf for i in solar["pg"]]
                        solar["qg"] = [kva / length(solar["qg"]) * sqrt(1 - pf^2) for i in solar["qg"]]
                    end
                else
                    pf = defaults["pf"]
                end
                if haskey(dss_obj, "balanced")
                    balanced = dss_obj["balanced"]
                else
                    balanced = defaults["balanced"]
                end
                if haskey(dss_obj, "pv_model")
                    model = dss_obj["model"]
                else
                    model = 1
                end
                if haskey(dss_obj, "phases")
                    phases = dss_obj["phases"]
                else
                    phases = 3
                end
                ncnd = length(solar["connections"]) >= 3 ? 3 : 1
                solar["i_max"] = fill(1 / vminpu * kva / (ncnd / sqrt(3) * dss_obj["kv"]), ncnd)
                solar["i_nom"] = kva / (ncnd / sqrt(3) * dss_obj["kv"])
                solar["solar_max"] = irradiance * pmpp
                solar["pf"] = pf
                solar["kva"] = kva
                solar["balanced"] = balanced
                solar["vminpu"] = vminpu
                solar["type"] = "solar"
                solar["pv_model"] = model
                solar["grid_forming"] = false
                if model == 1
                    solar["response"] = ConstantPAtPF
                elseif model == 2
                    solar["response"] = ConstantI
                elseif model == 3
                    solar["response"] = ConstantPQ
                end
                solar["phases"] = phases
                solar["element"] = SolarElement
            end
        end
    end


    "helper function to build extra dynamics information for load objects"
    function _dss2eng_load_dynamics!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
        if haskey(data_eng, "load")
            for (id, load) in data_eng["load"]
                dss_obj = data_dss["load"][id]
                defaults = _PMD._apply_ordered_properties(_PMD._create_pvsystem(id; _PMD._to_kwargs(dss_obj)...), dss_obj)
                if haskey(dss_obj, "vminpu")
                    vminpu = dss_obj["vminpu"]
                else
                    vminpu = defaults["vminpu"]
                end
                if haskey(dss_obj, "vmaxpu")
                    vmaxpu = dss_obj["vmaxpu"]
                else
                    vmaxpu = defaults["vmaxpu"]
                end
                if haskey(dss_obj, "phases")
                    phases = dss_obj["phases"]
                else
                    phases = defaults["phases"]
                end
                load["vminpu"] = vminpu
                load["vmaxpu"] = vmaxpu
                load["phases"] = phases
                if load["model"] == _PMD.IMPEDANCE
                    load["response"] = ConstantZ
                elseif load["model"] == _PMD.POWER
                    load["response"] = ConstantPQ
                elseif load["model"] == _PMD.CURRENT
                    load["response"] = ConstantI
                elseif load["model"] == _PMD.ZIP
                    load["response"] = ConstantZIP
                end
                load["element"] = LoadElement
            end
        end
    end


    "helper function to build extra dynamics information for transfomer objects"
    function _dss2eng_transformer_dynamics!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
        if haskey(data_eng, "transformer")
            for (id, transformer) in data_eng["transformer"]
                dss_obj = data_dss["transformer"][id]
                defaults = _PMD._apply_ordered_properties(_PMD._create_pvsystem(id; _PMD._to_kwargs(dss_obj)...), dss_obj)
                if haskey(dss_obj, "leadlag")
                    leadlag = dss_obj["leadlag"]
                else
                    if haskey(defaults, "leadlag")
                        leadlag = defaults["leadlag"]
                    else
                        leadlag = "lag"
                    end
                end
                if haskey(dss_obj, "phases")
                    phases = dss_obj["phases"]
                else
                    phases = defaults["phases"]
                end
                transformer["leadlag"] = leadlag
                transformer["phases"] = phases
                if length(transformer["connections"]) == 2
                    transformer["element"] = Transformer2WElement
                else
                    Nothing
                end
            end
        end
    end


    "helper function to fix voltage source objects"
    function _dss2eng_voltage_source_dynamics!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
        if haskey(data_eng, "voltage_source")
            for (id, voltage_source) in data_eng["voltage_source"]
                dss_obj = data_dss["vsource"][id]
                defaults = _PMD._apply_ordered_properties(_PMD._create_vsource(id; _PMD._to_kwargs(dss_obj)...), dss_obj)
                if haskey(dss_obj, "phases")
                    phases = dss_obj["phases"]
                else
                    phases = defaults["phases"]
                end
                voltage_source["phases"] = phases
                voltage_source["element"] = VoltageSourceElement
                if haskey(dss_obj, "r1") && haskey(dss_obj, "x1")
                    r1 = dss_obj["r1"]
                    x1 = dss_obj["x1"]
                    haskey(dss_obj, "r0") ? r0 = dss_obj["r0"] : r0 = 1.796
                    haskey(dss_obj, "x0") ? x0 = dss_obj["x0"] : x0 = 5.3881
                    zabc = _A * [r0+x0*1im 0 0; 0 r1+x1*1im 0; 0 0 r1+x1*1im] * inv(_A)
                    voltage_source["rs"] = real(zabc)
                    voltage_source["xs"] = imag(zabc)
                end
            end
        end
    end


    "helper function to build extra dynamics information for pvsystem objects
        model = 1:P Q gen  2: constant z  3: P V gen  4-6 not modeled 7: inverter connected
        balanced = current balance true or false
        transformer = true (contained in model) or false (not in model)
    "

    "helper function to build extra dynamics information for generator or vsource objects"
    function _dss2eng_gen_dynamics!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
        if haskey(data_eng, "generator")
            for (id, generator) in data_eng["generator"]
                dss_obj = data_dss["generator"][id]
                _PMD._apply_like!(dss_obj, data_dss, "generator")
                defaults = _PMD._apply_ordered_properties(_PMD._create_generator(id; _PMD._to_kwargs(dss_obj)...), dss_obj)
                zbase = defaults["kv"]^2 / defaults["kva"] * 1000
                xdp = defaults["xdp"] * zbase
                rp = xdp / defaults["xrdp"]
                xdpp = defaults["xdpp"] * zbase
                generator["xdp"] = fill(xdp, length(generator["connections"]))
                generator["rp"] = fill(rp, length(generator["connections"]))
                generator["xdpp"] = fill(xdpp, length(generator["connections"]))
                if haskey(generator["dss"], "model")
                    model = generator["dss"]["model"]
                else
                    model = 1
                end
                generator["gen_model"] = model
                if model == 1
                    if haskey(generator["dss"], "kvar")
                        generator["qg"] = fill(generator["dss"]["kvar"] / length(generator["pg"]), length(generator["pg"]))
                    else
                        generator["qg"] = fill(0.0, length(generator["pg"]))
                    end
                    if haskey(generator["dss"], "kv")

                        generator["vnom_kv"] = generator["dss"]["kv"] / sqrt(3)
                    end
                    generator["element"] = GeneratorElement
                    # if generator["dss"]["model"] == 3
                    #         dss_obj = data_dss["generator"][id]
                    #         _PMD._apply_like!(dss_obj, data_dss, "generator")
                    #         defaults = _PMD._apply_ordered_properties(_PMD._create_generator(id; _PMD._to_kwargs(dss_obj)...), dss_obj)
                    #         zbase = defaults["kv"]^2/defaults["kva"]*1000
                    #         xdp = defaults["xdp"] * zbase
                    #         rp = xdp/defaults["xrdp"]
                    #         xdpp = defaults["xdpp"] * zbase
                    #         generator["xdp"] = fill(xdp, length(generator["connections"]))
                    #         generator["rp"] = fill(rp, length(generator["connections"]))
                    #         generator["xdpp"] = fill(xdpp, length(generator["connections"]))
                    #     end
                end
            end
        end
    end


    "Helper function to convert dss data for monitors to engineering current transformer model."
    function _dss2eng_ct!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
        for (id, dss_obj) in get(data_dss, "monitor", Dict())
            if haskey(dss_obj, "turns")
                turns = split(dss_obj["turns"], ',')
                n_p = parse(Int, strip(split(turns[1], '[')[end]))
                n_s = parse(Int, strip(split(turns[2], ']')[1]))
                add_ct(data_eng, dss_obj["element"], "$id", n_p, n_s)
            elseif haskey(dss_obj, "n_p") && haskey(dss_obj, "n_s")
                add_ct(data_eng, dss_obj["element"], "$id", parse(Int, dss_obj["n_p"]), parse(Int, dss_obj["n_s"]))
            else
                @warn "Could not find turns ratio. CT $id not added."
            end
        end
    end


    "Helper function for converting dss relay to engineering relay model."
    function _dss2eng_relay!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
        monitor_type_list = ["line", "load", "gen"]
        defaults_dict = Dict{String,Any}(
            "float_dict" => Dict{String,Any}(
                "phasetrip" => 1.0,
                "groundtrip" => 1.0,
                "tdphase" => 1.0,
                "tdground" => 1.0,
                "phaseinst" => 0.0,
                "groundinst" => 0.0,
                "delay" => 0.0,
                "kvbase" => 0.0,
                "47%pickup" => 2.0,
                "46%pickup" => 20.0,
                "breakertime" => 0.0,
            ),
            "int_dict" => Dict{String,Any}(
                "monitoredterm" => 1,
                "switchedterm" => 1,
                "reset" => 15,
                "shots" => 4,
                "46isqt" => 1
            ),
            "str_dict" => Dict{String,Any}(
                "type" => "current",
                "phasecurve" => "none",
                "groundcurve" => "none",
                "overvoltcurve" => "none",
                "undervoltcurve" => "none",
            ),
        )
        for (id, dss_obj) in get(data_dss, "relay", Dict())
            eng_obj = Dict{String,Any}()
            if !haskey(dss_obj, "monitoredobj")
                @warn "relay $(dss_obj["name"]) does not have a monitoredobj and will be disabled"
                eng_obj["status"] = 0
                eng_obj["monitoredobj"] = "none"
            else
                if !haskey(dss_obj, "enabled")
                    @warn "relay $(dss_obj["name"]) does not have enable key and will be set to enable"
                    eng_obj["status"] = 1
                else
                    if dss_obj["enabled"] == "yes" || dss_obj["enabled"] == "true"
                        eng_obj["status"] = 1
                    else
                        eng_obj["status"] = 0
                    end
                end
                eng_obj["monitoredobj"] = dss_obj["monitoredobj"]
                if !haskey(dss_obj, "switchedobj")
                    eng_obj["switchedobj"] = dss_obj["monitoredobj"]
                else
                    eng_obj["switchedobj"] = dss_obj["switchedobj"]
                end
                for monitor_type in monitor_type_list
                    for (id, dss_monit_obj) in get(data_dss, monitor_type, Dict())
                        if dss_obj["monitoredobj"] == id
                            eng_obj["monitor_type"] = monitor_type
                        end
                    end
                end
            end
            if haskey(dss_obj, "basefreq") && dss_obj["basefreq"] != data_eng["settings"]["base_frequency"]
                @warn "basefreq=$(dss_obj["basefreq"]) on line.$id does not match circuit basefreq=$(data_eng["settings"]["base_frequency"])"
            end
            for (default_id, default_value) in get(defaults_dict, "float_dict", Dict())
                if !haskey(dss_obj, default_id)
                    eng_obj[default_id] = default_value
                end
            end
            for (default_id, default_value) in get(defaults_dict, "int_dict", Dict())
                if !haskey(dss_obj, default_id)
                    eng_obj[default_id] = default_value
                end
            end
            for (default_id, default_value) in get(defaults_dict, "str_dict", Dict())
                if !haskey(dss_obj, default_id)
                    eng_obj[default_id] = default_value
                end
            end
            if !haskey(dss_obj, "type")
                @warn "relay $id does not have a type defined setting it to current"
                eng_obj["type"] = "current"
                eng_obj["recloseintervals"] = [0.5, 2.0, 2.0]
            else
                if dss_obj["type"] == "current"
                    if !haskey(dss_obj, "recloseintervals")
                        eng_obj["recloseintervals"] = [0.5, 2.0, 2.0]
                    end
                elseif dss_obj["type"] == "voltage"
                    if !haskey(dss_obj, "recloseintervals")
                        eng_obj["recloseintervals"] = 5.0
                    end
                end
            end
            _PMD._add_eng_obj!(data_eng, "relay", id, eng_obj)
        end
    end


    "Helper function for converting dss fuse to engineering fuse"
    function _dss2eng_fuse!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
        defaults_dict = Dict{String,Any}(
            "float_dict" => Dict{String,Any}(
                "delay" => 0.0,
            ),
            "int_dict" => Dict{String,Any}(
                "monitoredterm" => 1,
                "switchedterm" => 1,
            ),
            "str_dict" => Dict{String,Any}(
                "fusecurve" => "tlink",
            ),
        )
        for (id, dss_obj) in get(data_dss, "fuse", Dict())
            eng_obj = Dict{String,Any}()
            if !haskey(dss_obj, "monitoredobj")
                @warn "fuse $(dss_obj["name"]) does not have a monitoredobj and will be disabled"
                eng_obj["status"] = 0
                eng_obj["monitoredobj"] = "none"
            else
                if !haskey(dss_obj, "enabled")
                    @warn "fuse $(dss_obj["name"]) does not have enable key and will be set to enable"
                    eng_obj["status"] = 1
                else
                    if dss_obj["enabled"] == "yes" || dss_obj["enabled"] == "true"
                        eng_obj["status"] = 1
                    else
                        eng_obj["status"] = 0
                    end
                end
                eng_obj["monitoredobj"] = dss_obj["monitoredobj"]
                if !haskey(dss_obj, "switchedobj")
                    eng_obj["switchedobj"] = dss_obj["monitoredobj"]
                else
                    eng_obj["switchedobj"] = dss_obj["switchedobj"]
                end
            end
            _PMD._add_eng_obj!(data_eng, "relay", id, eng_obj)
        end
    end


    "Helper function for converting dss tcc_curves to engineering model"
    function _dss2eng_curve!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
        for (id, dss_obj) in get(data_dss, "tcc_curve", Dict())
            eng_obj = Dict{String,Any}()
            if startswith(strip(dss_obj["c_array"]), '[')
                c_string = split(split(split(strip(dss_obj["c_array"]), '[')[end], ']')[1], ',')
            elseif startswith(strip(dss_obj["c_array"]), '"')
                c_string = split(split(split(strip(dss_obj["c_array"]), '"')[end], '"')[1], ',')
            elseif startswith(strip(dss_obj["c_array"]), ''')
                c_string = split(split(split(strip(dss_obj["c_array"]), ''')[end], ''')[1], ',')
            end
            if startswith(strip(dss_obj["t_array"]), '[')
                t_string = split(split(split(strip(dss_obj["t_array"]), '[')[end], ']')[1], ',')
            elseif startswith(strip(dss_obj["t_array"]), '"')
                t_string = split(split(split(strip(dss_obj["t_array"]), '"')[end], '"')[1], ',')
            elseif startswith(strip(dss_obj["t_array"]), ''')
                t_string = split(split(split(strip(dss_obj["t_array"]), ''')[end], ''')[1], ',')
            end
            c_array, t_array = [], []
            for i = 1:length(c_string)
                push!(c_array, parse(Float64, c_string[i]))
            end
            eng_obj["c_array"] = c_array
            for i = 1:length(t_string)
                push!(t_array, parse(Float64, t_string[i]))
            end
            eng_obj["t_array"] = t_array
            if haskey(dss_obj, "npts")
                npts = parse(Int, dss_obj["npts"])
                if (length(c_array) != npts) || (length(t_array) != npts)
                    if length(c_array) > npts
                        @warn "c_array is longer than the npts. Truncating array."
                        cut_points = length(c_array) - npts
                        c_array = c_array[cut_points+1:length(c_array)]
                    end
                    if length(t_array) > npts
                        @warn "t_array is longer than the npts. Truncating array."
                        cut_points = length(t_array) - npts
                        t_array = t_array[cut_points+1:length(t_array)]
                    end
                    if length(t_array) < npts
                        @warn "t_array is shorter than npts. Adding time values."
                        t_len = length(t_array)
                        for i = 0:npts-t_len-1
                            push!(t_array, t_array[t_len+i] / 2)
                        end
                    end
                    if length(c_array) < npts
                        @warn "c_array is shorter than npts. Adding current values."
                        c_len = length(c_array)
                        (a, b) = _bisection(c_array[c_len], t_array[c_len], c_array[c_len-1], t_array[c_len-1])
                        for i = 1:npts-c_len
                            push!(c_array, round((a / t_array[c_len+i] + 1)^(1 / b)))
                        end
                    end
                end
            else
                if length(c_array) != length(t_array)
                    c_len = length(c_array)
                    t_len = length(t_array)
                    if c_len < t_len
                        @warn "c_array is shorter than t_array. Adding current values."
                        c_len = length(c_array)
                        (a, b) = _bisection(c_array[c_len], t_array[c_len], c_array[c_len-1], t_array[c_len-1])
                        for i = 1:npts-c_len
                            push!(c_array, round((a / t_array[c_len+i] + 1)^(1 / b)))
                        end
                    else
                        @warn "t_array is shorter than c_array. Adding time values."
                        for i = 0:c_len-t_len-1
                            push!(t_array, t_array[t_len+i] / 2)
                        end
                    end
                end
                npts = length(c_array)
            end
            eng_obj["npts"] = npts
            _PMD._add_eng_obj!(data_eng, "tcc_curve", id, eng_obj)
        end
    end


    "helper function to define generator typr from opendss models"
    function _dss2eng_gen_model!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
        if haskey(data_eng, "generator")
            for (id, generator) in data_eng["generator"]
                if haskey(generator["dss"], "model")
                    generator["gen_model"] = generator["dss"]["model"]
                else
                    generator["gen_model"] = 1
                end
            end
        end
    end


    function _dss2eng_phases!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
        if haskey(data_eng, "transformer")
            for (_, transformer) in data_eng["transformer"]
                if haskey(transformer, "xfmrcode")
                    xfmrcode = data_dss["xfmrcode"][transformer["xfmrcode"]]
                    haskey(xfmrcode, "phases") ? transformer["dss"]["phases"] = xfmrcode["phases"] : transformer["dss"]["phases"] = 3
                end
            end
        end
    end


    function _dss2eng_solar_transformer(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
        #TODO add function that checks for transformer
        if haskey(data_eng, "solar")
            for (id, solar) in data_eng["solar"]
                bus = "virtual_bus_$(id)"
                transformer = Dict{String,Any}(
                    "polarity" => [1, -1],
                    "sm_nom" => [solar["kva"] / sqrt(3), solar["kva"]],
                    "tm_lb" => [[0.9, 0.9, 0.9], [0.9, 0.9, 0.9]],
                    "connections" => [[1, 2, 3], [2, 3, 1, 4]],
                    "tm_set" => [[1.0, 1.0, 1.0], [1.0, 1.0, 1.0]],
                    "tm_step" => [[0.03125, 0.03125, 0.03125], [0.03125, 0.03125, 0.03125]],
                    "bus" => [bus, deepcopy(solar["bus"])],
                    "configuration" => _PMD.ConnConfig[_PMD.DELTA, _PMD.WYE],
                    "status" => _PMD.ENABLED,
                    "noloadloss" => 0.005,
                    "dss" => Dict{String,Any}("phases" => 3, "buses" => [bus, solar["bus"]]),
                    "cmag" => 0.11,
                    "xsc" => [0.05],
                    "source_id" => "virtual_transformer.$(id)",
                    "sm_ub" => 1.5 * solar["kva"],
                    "rw" => [0.001, 0.002],
                    "tm_fix" => Vector{Bool}[[1, 1, 1], [1, 1, 1]],
                    "vm_nom" => [solar["dss"]["kv"], solar["dss"]["kv"]],
                    "leadlag" => "lag",
                    "tm_ub" => [[1.1, 1.1, 1.1], [1.1, 1.1, 1.1]],
                )
                if !haskey(data_eng, "transformer")
                    data_eng["transformer"] = Dict{String,Any}()
                end
                data_eng["transformer"]["virtual_$(id)"] = transformer
                data_eng["bus"][bus] = deepcopy(data_eng["bus"][solar["bus"]])
                solar["bus"] = bus
                solar["transformer_id"] = "virtual_$(id)"
            end
        end
    end


    function _dss2eng_issues!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
        nothing
    end
else

    "helper function to build extra dynamics information for pvsystem objects"
    function _dss2eng_solar_dynamics!(data_eng::Dict{String,<:Any}, data_dss::_PMD.OpenDssDataModel)
        if haskey(data_eng, "solar")
            for (id, solar) in data_eng["solar"]
                dss_obj = data_dss["pvsystem"][id]

                irradiance = dss_obj["irradiance"]
                vminpu = dss_obj["vminpu"]
                vminpu = dss_obj["vminpu"]
                kva = dss_obj["kva"]
                pmpp = dss_obj["pmpp"]
                pf = dss_obj["pf"]

                ncnd = length(solar["connections"]) >= 3 ? 3 : 1
                solar["i_max"] = fill(1 / vminpu * kva / (ncnd / sqrt(3) * dss_obj["kv"]), ncnd)
                solar["solar_max"] = irradiance * pmpp
                solar["pf"] = pf
                solar["kva"] = kva
            end
        end
    end


    "helper function to build extra dynamics information for load objects"
    function _dss2eng_load_dynamics!(data_eng::Dict{String,<:Any}, data_dss::_PMD.OpenDssDataModel)
        if haskey(data_eng, "load")
            for (id, load) in data_eng["load"]
                dss_obj = data_dss["load"][id]
                vminpu = dss_obj["vminpu"]
                vmaxpu = dss_obj["vmaxpu"]
                phases = dss_obj["phases"]
                load["vminpu"] = vminpu
                load["vmaxpu"] = vmaxpu
                load["phases"] = phases
                if load["model"] == _PMD.IMPEDANCE
                    load["response"] = ConstantZ
                elseif load["model"] == _PMD.POWER
                    load["response"] = ConstantPQ
                elseif load["model"] == _PMD.CURRENT
                    load["response"] = ConstantI
                elseif load["model"] == _PMD.ZIP
                    load["response"] = ConstantZIP
                end
                load["element"] = LoadElement
            end
        end
    end


    "helper function to build extra dynamics information for generator or vsource objects"
    function _dss2eng_gen_dynamics!(data_eng::Dict{String,<:Any}, data_dss::_PMD.OpenDssDataModel)
        if haskey(data_eng, "generator")
            for (id, generator) in data_eng["generator"]
                if haskey(generator["dss"], "model")
                    if generator["dss"]["model"] == 3
                        defaults = data_dss["generator"][id]

                        zbase = defaults["kv"]^2 / defaults["kva"] * 1000
                        xdp = defaults["xdp"] * zbase
                        rp = xdp / defaults["xrdp"]
                        xdpp = defaults["xdpp"] * zbase
                        generator["xdp"] = fill(xdp, length(generator["connections"]))
                        generator["rp"] = fill(rp, length(generator["connections"]))
                        generator["xdpp"] = fill(xdpp, length(generator["connections"]))
                    end
                end
            end
        end
    end


    "helper function to fix voltage source objects"
    function _dss2eng_voltage_source_dynamics!(data_eng::Dict{String,<:Any}, data_dss::_PMD.OpenDssDataModel)
        if haskey(data_eng, "voltage_source")
            for (id, voltage_source) in data_eng["voltage_source"]
                dss_obj = data_dss["vsource"][id]
                phases = dss_obj["phases"]
                voltage_source["phases"] = phases
                voltage_source["element"] = VoltageSourceElement
                r1 = dss_obj["r1"]
                x1 = dss_obj["x1"]
                r0 = dss_obj["r0"]
                x0 = dss_obj["x0"]
                zabc = _A * [r0+x0*1im 0 0; 0 r1+x1*1im 0; 0 0 r1+x1*1im] * inv(_A)
                voltage_source["rs"] = real(zabc)
                voltage_source["xs"] = imag(zabc)
            end
        end
    end


    "helper function to build extra dynamics information for transfomer objects"
    function _dss2eng_transformer_dynamics!(data_eng::Dict{String,<:Any}, data_dss::_PMD.OpenDssDataModel)
        if haskey(data_eng, "transformer")
            for (id, transformer) in data_eng["transformer"]
                dss_obj = data_dss["transformer"][id]
                leadlag = dss_obj["leadlag"]
                phases = dss_obj["phases"]
                transformer["leadlag"] = leadlag
                transformer["phases"] = phases
                if length(transformer["connections"]) == 2
                    transformer["element"] = Transformer2WElement
                else
                    nothing
                end
            end
        end
    end


    "Helper function to convert dss data for monitors to engineering current transformer model."
    function _dss2eng_ct!(data_eng::Dict{String,<:Any}, data_dss::_PMD.OpenDssDataModel)
        for (id, dss_obj) in get(data_dss, "monitor", Dict())
            if haskey(dss_obj, "turns")
                turns = split(dss_obj["turns"], ',')
                n_p = parse(Int, strip(split(turns[1], '[')[end]))
                n_s = parse(Int, strip(split(turns[2], ']')[1]))
                add_ct(data_eng, dss_obj["element"], "$id", n_p, n_s)
            elseif haskey(dss_obj, "n_p") && haskey(dss_obj, "n_s")
                add_ct(data_eng, dss_obj["element"], "$id", parse(Int, dss_obj["n_p"]), parse(Int, dss_obj["n_s"]))
            else
                @warn "Could not find turns ratio. CT $id not added."
            end
        end
    end


    "Helper function for converting dss relay to engineering relay model."
    function _dss2eng_relay!(data_eng::Dict{String,<:Any}, data_dss::_PMD.OpenDssDataModel)
        monitor_type_list = ["line", "load", "gen"]
        defaults_dict = Dict{String,Any}(
            "float_dict" => Dict{String,Any}(
                "phasetrip" => 1.0,
                "groundtrip" => 1.0,
                "tdphase" => 1.0,
                "tdground" => 1.0,
                "phaseinst" => 0.0,
                "groundinst" => 0.0,
                "delay" => 0.0,
                "kvbase" => 0.0,
                "47%pickup" => 2.0,
                "46%pickup" => 20.0,
                "breakertime" => 0.0,
            ),
            "int_dict" => Dict{String,Any}(
                "monitoredterm" => 1,
                "switchedterm" => 1,
                "reset" => 15,
                "shots" => 4,
                "46isqt" => 1
            ),
            "str_dict" => Dict{String,Any}(
                "type" => "current",
                "phasecurve" => "none",
                "groundcurve" => "none",
                "overvoltcurve" => "none",
                "undervoltcurve" => "none",
            ),
        )
        for (id, dss_obj) in get(data_dss, "relay", Dict())
            eng_obj = Dict{String,Any}(
                "status" => dss_obj["enabled"],
                "monitoredobj" => dss_obj["monitoredobj"],
                "switchedobj" => dss_obj["switchedobj"],
                Dict{String,Any}(k => dss_obj[k] for t in keys(defaults_dict) for k in keys(defaults_dict[t]))...
            )
            if dss_obj["basefreq"] != data_eng["settings"]["base_frequency"]
                @warn "basefreq=$(dss_obj["basefreq"]) on line.$id does not match circuit basefreq=$(data_eng["settings"]["base_frequency"])"
            end

            _PMD._add_eng_obj!(data_eng, "relay", id, eng_obj)
        end
    end


    "Helper function for converting dss fuse to engineering fuse"
    function _dss2eng_fuse!(data_eng::Dict{String,<:Any}, data_dss::_PMD.OpenDssDataModel)
        defaults_dict = Dict{String,Any}(
            "float_dict" => Dict{String,Any}(
                "delay" => 0.0,
            ),
            "int_dict" => Dict{String,Any}(
                "monitoredterm" => 1,
                "switchedterm" => 1,
            ),
            "str_dict" => Dict{String,Any}(
                "fusecurve" => "tlink",
            ),
        )
        for (id, dss_obj) in get(data_dss, "fuse", Dict())
            eng_obj = Dict{String,Any}()
            if !haskey(dss_obj, "monitoredobj")
                @warn "fuse $(dss_obj["name"]) does not have a monitoredobj and will be disabled"
                eng_obj["status"] = 0
                eng_obj["monitoredobj"] = "none"
            else
                if !haskey(dss_obj, "enabled")
                    @warn "fuse $(dss_obj["name"]) does not have enable key and will be set to enable"
                    eng_obj["status"] = 1
                else
                    if dss_obj["enabled"] == "yes" || dss_obj["enabled"] == "true"
                        eng_obj["status"] = 1
                    else
                        eng_obj["status"] = 0
                    end
                end
                eng_obj["monitoredobj"] = dss_obj["monitoredobj"]
                if !haskey(dss_obj, "switchedobj")
                    eng_obj["switchedobj"] = dss_obj["monitoredobj"]
                else
                    eng_obj["switchedobj"] = dss_obj["switchedobj"]
                end
            end
            _PMD._add_eng_obj!(data_eng, "relay", id, eng_obj)
        end
    end


    "Helper function for converting dss tcc_curves to engineering model"
    function _dss2eng_curve!(data_eng::Dict{String,<:Any}, data_dss::_PMD.OpenDssDataModel)
        for (id, dss_obj) in get(data_dss, "tcc_curve", Dict())
            eng_obj = Dict{String,Any}()
            if startswith(strip(dss_obj["c_array"]), '[')
                c_string = split(split(split(strip(dss_obj["c_array"]), '[')[end], ']')[1], ',')
            elseif startswith(strip(dss_obj["c_array"]), '"')
                c_string = split(split(split(strip(dss_obj["c_array"]), '"')[end], '"')[1], ',')
            elseif startswith(strip(dss_obj["c_array"]), ''')
                c_string = split(split(split(strip(dss_obj["c_array"]), ''')[end], ''')[1], ',')
            end
            if startswith(strip(dss_obj["t_array"]), '[')
                t_string = split(split(split(strip(dss_obj["t_array"]), '[')[end], ']')[1], ',')
            elseif startswith(strip(dss_obj["t_array"]), '"')
                t_string = split(split(split(strip(dss_obj["t_array"]), '"')[end], '"')[1], ',')
            elseif startswith(strip(dss_obj["t_array"]), ''')
                t_string = split(split(split(strip(dss_obj["t_array"]), ''')[end], ''')[1], ',')
            end
            c_array, t_array = [], []
            for i in eachindex(1:length(c_string))
                push!(c_array, parse(Float64, c_string[i]))
            end
            eng_obj["c_array"] = c_array
            for i in eachindex(1:length(t_string))
                push!(t_array, parse(Float64, t_string[i]))
            end
            eng_obj["t_array"] = t_array
            if haskey(dss_obj, "npts")
                npts = parse(Int, dss_obj["npts"])
                if (length(c_array) != npts) || (length(t_array) != npts)
                    if length(c_array) > npts
                        @warn "c_array is longer than the npts. Truncating array."
                        cut_points = length(c_array) - npts
                        c_array = c_array[cut_points+1:length(c_array)]
                    end
                    if length(t_array) > npts
                        @warn "t_array is longer than the npts. Truncating array."
                        cut_points = length(t_array) - npts
                        t_array = t_array[cut_points+1:length(t_array)]
                    end
                    if length(t_array) < npts
                        @warn "t_array is shorter than npts. Adding time values."
                        t_len = length(t_array)
                        for i = 0:npts-t_len-1
                            push!(t_array, t_array[t_len+i] / 2)
                        end
                    end
                    if length(c_array) < npts
                        @warn "c_array is shorter than npts. Adding current values."
                        c_len = length(c_array)
                        (a, b) = _bisection(c_array[c_len], t_array[c_len], c_array[c_len-1], t_array[c_len-1])
                        for i = 1:npts-c_len
                            push!(c_array, round((a / t_array[c_len+i] + 1)^(1 / b)))
                        end
                    end
                end
            else
                if length(c_array) != length(t_array)
                    c_len = length(c_array)
                    t_len = length(t_array)
                    if c_len < t_len
                        @warn "c_array is shorter than t_array. Adding current values."
                        c_len = length(c_array)
                        (a, b) = _bisection(c_array[c_len], t_array[c_len], c_array[c_len-1], t_array[c_len-1])
                        for i = 1:npts-c_len
                            push!(c_array, round((a / t_array[c_len+i] + 1)^(1 / b)))
                        end
                    else
                        @warn "t_array is shorter than c_array. Adding time values."
                        for i = 0:c_len-t_len-1
                            push!(t_array, t_array[t_len+i] / 2)
                        end
                    end
                end
                npts = length(c_array)
            end
            eng_obj["npts"] = npts
            _PMD._add_eng_obj!(data_eng, "tcc_curve", id, eng_obj)
        end
    end


    "helper function to define generator typr from opendss models"
    function _dss2eng_gen_model!(data_eng::Dict{String,<:Any}, data_dss::_PMD.OpenDssDataModel)
        if haskey(data_eng, "generator")
            for (id, generator) in data_eng["generator"]
                if haskey(generator["dss"], "model")
                    generator["gen_model"] = generator["dss"]["model"]
                else
                    generator["gen_model"] = 1
                end
            end
        end
    end

    function _dss2eng_issues!(data_eng::Dict{String,<:Any}, data_dss::_PMD.OpenDssDataModel)
        nothing
    end
end
