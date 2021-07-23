"helper function to build extra dynamics information for pvsystem objects"
function _dss2eng_solar_dynamics!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    if haskey(data_eng, "solar")
        for (id,solar) in data_eng["solar"]
            dss_obj = data_dss["pvsystem"][id]

            _PMD._apply_like!(dss_obj, data_dss, "pvsystem")
            defaults = _PMD._apply_ordered_properties(_PMD._create_pvsystem(id; _PMD._to_kwargs(dss_obj)...), dss_obj)

            solar["i_max"] = (1/defaults["vminpu"]) * defaults["kva"] / 3
            solar["solar_max"] = defaults["irradiance"] * defaults["pmpp"]
            solar["kva"] = defaults["kva"]
            solar["pf"] = defaults["pf"]
        end
    end
end


"helper function to build extra dynamics information for generator or vsource objects"
function _dss2eng_gen_dynamics!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
   if haskey(data_eng, "generator")
        for (id, generator) in data_eng["generator"]
            dss_obj = data_dss["generator"][id]

            _PMD._apply_like!(dss_obj, data_dss, "generator")
            defaults = _PMD._apply_ordered_properties(_PMD._create_generator(id; _PMD._to_kwargs(dss_obj)...), dss_obj)

            generator["zr"] = zeros(length(generator["connections"]))
            generator["zx"] = fill(defaults["xdp"] / defaults["kw"], length(generator["connections"]))
        end
    end

    if haskey(data_eng, "voltage_source")
        for (id, vsource) in data_eng["voltage_source"]
            vsource["zr"] = zeros(length(vsource["connections"]))
            vsource["zx"] = zeros(length(vsource["connections"]))
        end
    end
end


"Helper function to convert dss data for monitors to engineering current transformer model."
function _dss2eng_ct!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    for (id, dss_obj) in get(data_dss, "monitor", Dict())
        if haskey(dss_obj, "turns")
            turns = split(dss_obj["turns"], ',')
            n_p = parse(Int, strip(split(turns[1], '[')[end]))
            n_s = parse(Int, strip(split(turns[2], ']')[begin]))
            add_ct(data_eng, dss_obj["element"], "$id", n_p, n_s)
        elseif haskey(dss_obj, "n_p") && haskey(dss_obj, "n_s")
            add_ct(data_eng, dss_obj["element"], "$id", parse(Int,dss_obj["n_p"]), parse(Int,dss_obj["n_s"]))
        else
            @warn "Could not find turns ratio. CT $id not added."
        end
    end
end


"Helper function for converting dss relay to engineering relay model."
function _dss2eng_relay!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    for (id, dss_obj) in get(data_dss, "relay", Dict())
        if haskey(dss_obj, "basefreq") && dss_obj["basefreq"] != data_eng["settings"]["base_frequency"]
            @warn "basefreq=$(dss_obj["basefreq"]) on line.$id does not match circuit basefreq=$(data_eng["settings"]["base_frequency"])"
        end
        add_relay! = true
        relay_type = strip(dss_obj["type"])
        phase = [1,2,3]
        t_breaker = 0
        shots = 1
        if haskey(dss_obj, "breaker_time")
            t_breaker = parse(Float64, dss_obj["breaker_time"])
        elseif haskey(dss_obj, "t_breaker")
            t_breaker = parse(Float64, dss_obj["t_breaker"])
        elseif haskey(dss_obj, "breakertime")
            t_breaker = parse(Float64, dss_obj["breakertime"])
        end
        if haskey(dss_obj, "shots")
            shots = parse(Float64, dss_obj["shots"])
        end
        if haskey(dss_obj, "phase")
            phase = strip(dss_obj["phase"])
            if startswith(phase,'[') && endswith(phase,']')
                phases = split(split(split(phase, '[')[end],']')[begin],',')
            elseif startswith(phase,''') && endswith(phase,''')
                phases = split(split(split(phase, ''')[end],''')[begin],',')
            elseif startswith(phase,'"') && endswith(phase,'"')
                phases = split(split(split(phase, '"')[end],'"')[begin],',')
            end
            phase = []
            for i = 1:length(phases)
                push!(phase,parse(Int,phases[i]))
            end
        end
        element = "<none>"
        if haskey(dss_obj, "element")
            element = strip(dss_obj["element"])
        elseif haskey(dss_obj, "element1")
            element = strip(dss_obj["element1"])
        elseif haskey(dss_obj, "monitoredobj")
            element = strip(dss_obj["monitoredobj"])
        else
            @warn "Relay $id does not have a monitored object. Could not add relay."
            add_relay! = false
        end
        if haskey(dss_obj, "phasetrip")
            TS = parse(Float64, dss_obj["phasetrip"])
        elseif haskey(dss_obj,"ts")
            TS = parse(Float64, dss_obj["ts"])
        elseif haskey(dss_obj, "trip_angle")
            trip_angle = parse(Float64, dss_obj["trip_angle"])
        else
            @warn "Relay $id has no tap setting. Could not add relay."
            add_relay! = false
        end
        if haskey(dss_obj, "tdphase")
            TDS = parse(Float64, dss_obj["tdphase"])
        elseif haskey(dss_obj, "tds")
            TDS = parse(Float64, dss_obj["tds"])
        elseif haskey(dss_obj,"trip_angle")
        else
            @warn "Relay $id has no time dial setting. Could not add relay."
            add_relay! = false
        end
        if relay_type == "differential_dir"
            element2 = "<none>"
            if haskey(dss_obj, "element2")
                element2 = strip(dss_obj["element2"])
            elseif haskey(dss_obj, "monitoredobj2")
                element2 = strip(dss_obj["monitoredobj2"])
            else
                @warn "Relay $id needs a second monitored object. Could not add relay."
                add_relay! = false
            end
        end
        if add_relay!
            if relay_type == "overcurrent"
                if haskey(dss_obj, "ct") || haskey(dss_obj, "cts")
                    if haskey(dss_obj, "cts")
                        ct = strip(dss_obj["cts"])
                    else
                        ct = strip(dss_obj["ct"])
                    end
                    add_relay(data_eng, element, "$id", TS, TDS, ct;phase=phase,t_breaker=t_breaker,shots=shots)
                else
                    add_relay(data_eng, element, "$id", TS, TDS;phase=phase,t_breaker=t_breaker,shots=shots)
                end
            elseif relay_type == "differential"
                if haskey(dss_obj, "cts")
                    ct_vec = strip(dss_obj["cts"])
                else
                    ct_vec = strip(dss_obj["ct"])
                end
                if occursin(',',ct_vec)
                    if startswith(ct_vec,'[') && endswith(ct_vec,']')
                        cts = split(split(split(ct_vec, '[')[end],']')[begin],',')
                    elseif startswith(ct_vec,''') && endswith(ct_vec,''')
                        cts = split(split(split(ct_vec, ''')[end],''')[begin],',')
                    elseif startswith(ct_vec,'"') && endswith(ct_vec,'"')
                        cts = split(split(split(ct_vec, '"')[end],'"')[begin],',')
                    end
                    ct_vec = String[]
                    for i = 1:length(cts)
                        push!(ct_vec, String(cts[i]))
                    end
                end
                if haskey(dss_obj, "element2") || haskey(dss_obj, "monitoredobj2")
                    element2 = "<none>"
                    if haskey(dss_obj, "element2")
                        element2 = strip(dss_obj["element2"])
                    elseif haskey(dss_obj, "monitoredobj2")
                        element2 = strip(dss_obj["monitoredobj2"])
                    end
                    add_relay(data_eng, element, element2, "$id", TS, TDS, ct_vec;phase=phase,t_breaker=t_breaker)
                else
                    add_relay(data_eng, element, "$id", TS, TDS, ct_vec;phase=phase,t_breaker=t_breaker)
                end
            elseif relay_type == "differential_dir"
                add_relay(data_eng, element, element2, "$id", trip_angle)
            end
        end
    end
end   


"Helper function for converting dss fuse to engineering fuse"
function _dss2eng_fuse!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    for (id, dss_obj) in get(data_dss, "fuse", Dict())
        if haskey(dss_obj, "basefreq") && dss_obj["basefreq"] != data_eng["settings"]["base_frequency"]
            @warn "basefreq=$(dss_obj["basefreq"]) on line.$id does not match circuit basefreq=$(data_eng["settings"]["base_frequency"])"
        end
        phase = [1,2,3]
        element = "<none>"
        add_fuse! = true
        if haskey(dss_obj, "element")
            element = dss_obj["element"]
        elseif haskey(dss_obj, "monitoredobj")
            element = dss_obj["monitoredobj"]
        elseif haskey(dss_obj, "element1")
            element = dss_obj["element1"]
        else
            @warn "Fuse $id has no monitored object."
            add_fuse! = false
        end
        if haskey(dss_obj,"min_melt_curve")
            min_melt_curve = strip(dss_obj["min_melt_curve"])
        elseif haskey(dss_obj,"fuse_curve")
            min_melt_curve = strip(dss_obj["fuse_curve"])
        elseif haskey(dss_obj,"max_clear_curve")
            min_melt_curve = strip(dss_obj["max_clear_curve"])
        else
            @warn "Fuse $id hase no fuse curve."
            add_fuse! = false
        end
        if haskey(dss_obj,"max_clear_curve")
            max_clear_curve = strip(dss_obj["max_clear_curve"])
        else
            max_clear_curve = min_melt_curve
        end
        if haskey(dss_obj, "phase")
            phase = strip(dss_obj["phase"])
            if startswith(phase,'[') && endswith(phase,']')
                phases = split(split(split(phase, '[')[end],']')[begin],',')
            elseif startswith(phase,''') && endswith(phase,''')
                phases = split(split(split(phase, ''')[end],''')[begin],',')
            elseif startswith(phase,'"') && endswith(phase,'"')
                phases = split(split(split(phase, '"')[end],'"')[begin],',')
            end
            phase = []
            for i = 1:length(phases)
                push!(phase,parse(Int,phases[i]))
            end
        end
        if add_fuse!
            if ((startswith(min_melt_curve,'[') && endswith(min_melt_curve,']'))||(startswith(min_melt_curve,''') && endswith(min_melt_curve,'''))
                ||(startswith(min_melt_curve,'"') && endswith(min_melt_curve,'"')))
                if startswith(min_melt_curve, '[')
                    (c_array, t_array) = split(split(split(min_melt_curve,']')[begin],'[')[end],';')
                elseif startswith(min_melt_curve, ''')
                    (c_array, t_array) = split(split(split(min_melt_curve,''')[begin],''')[end],';')
                elseif startswith(min_melt_curve,'"')
                    (c_array, t_array) = split(split(split(min_melt_curve,'"')[begin],'"')[end],';')
                end
                c_array = split(c_array,',')
                t_array = split(t_array,',')
                min_melt_curve = zeros(2,length(c_array))
                if length(c_array) != length(t_array)
                    c_len, t_len = length(c_array), length(t_array)
                    c_array, t_array = parse.(Float64,c_array),parse.(Float64,t_array)
                    if c_len > t_len
                        @warn "t_array is shorter than c_array. Adding time values."
                        for i=0:c_len - t_len - 1
                            push!(t_array, t_array[t_len+i]/2)
                        end
                    else
                        @warn "c_array is shorter than t_array. Adding current values."
                        c_len = length(c_array)
                        (a,b) = _bisection(c_array[c_len],t_array[c_len],c_array[c_len-1],t_array[c_len-1])
                        for i=1:npts - c_len
                            push!(c_array, round((a/t_array[c_len+i]+1)^(1/b)))
                        end
                    end
                    min_melt_curve[1,:],min_melt_curve[2,:] = parse.(Float64,c_array),parse.(Float64,t_array)
                else
                    min_melt_curve[1,:],min_melt_curve[2,:] = parse.(Float64,c_array),parse.(Float64,t_array)
                end
            end
            if ((startswith(max_clear_curve,'[') && endswith(max_clear_curve,']'))||(startswith(max_clear_curve,''') && endswith(max_clear_curve,'''))
                ||(startswith(max_clear_curve,'"') && endswith(max_clear_curve,'"')))
                if startswith(max_clear_curve, '[')
                    (c_array, t_array) = split(split(split(max_clear_curve,']')[begin],'[')[end],';')
                elseif startswith(max_clear_curve, ''')
                    (c_array, t_array) = split(split(split(max_clear_curve,''')[begin],''')[end],';')
                elseif startswith(max_clear_curve,'"')
                    (c_array, t_array) = split(split(split(max_clear_curve,'"')[begin],'"')[end],';')
                end
                c_array = split(c_array,',')
                t_array = split(t_array,',')
                max_clear_curve = zeros(2,length(c_array))
                if length(c_array) != length(t_array)
                    c_len, t_len = length(c_array), length(t_array)
                    c_array, t_array = parse.(Float64,c_array),parse.(Float64,t_array)
                    if c_len > t_len
                        @warn "t_array is shorter than c_array. Adding time values."
                        for i=0:c_len - t_len - 1
                            push!(t_array, t_array[t_len+i]/2)
                        end
                    else
                        @warn "c_array is shorter than t_array. Adding current values."
                        c_len = length(c_array)
                        (a,b) = _bisection(c_array[c_len],t_array[c_len],c_array[c_len-1],t_array[c_len-1])
                        for i=1:npts - c_len
                            push!(c_array, round((a/t_array[c_len+i]+1)^(1/b)))
                        end
                    end
                    max_clear_curve[1,:],max_clear_curve[2,:] = parse.(Float64,c_array),parse.(Float64,t_array)
                else
                    max_clear_curve[1,:],max_clear_curve[2,:] = parse.(Float64,c_array),parse.(Float64,t_array)
                end
            end
            add_fuse(data_eng,"$element","$id",min_melt_curve;max_clear_curve=max_clear_curve,phase=phase)
        end
    end
end


"Helper function for converting dss tcc_curves to engineering model"
function _dss2eng_curve!(data_eng::Dict{String,<:Any}, data_dss::Dict{String,<:Any})
    for (id, dss_obj) in get(data_dss, "tcc_curve", Dict())
        if startswith(strip(dss_obj["c_array"]),'[')
        c_string = split(split(split(strip(dss_obj["c_array"]),'[')[end],']')[begin],',')
        elseif startswith(strip(dss_obj["c_array"]),'"')
        c_string = split(split(split(strip(dss_obj["c_array"]),'"')[end],'"')[begin],',')
        elseif startswith(strip(dss_obj["c_array"]),''')
        c_string = split(split(split(strip(dss_obj["c_array"]),''')[end],''')[begin],',')
        end
        if startswith(strip(dss_obj["t_array"]),'[')
        t_string = split(split(split(strip(dss_obj["t_array"]),'[')[end],']')[begin],',')    
        elseif startswith(strip(dss_obj["t_array"]),'"')
        t_string = split(split(split(strip(dss_obj["t_array"]),'"')[end],'"')[begin],',')
        elseif startswith(strip(dss_obj["t_array"]),''')
        t_string = split(split(split(strip(dss_obj["t_array"]),''')[end],''')[begin],',')
        end
        c_array, t_array = [],[]
        for i = 1:length(c_string)
            push!(c_array,parse(Float64,c_string[i]))
        end
        for i = 1:length(t_string)
            push!(t_array,parse(Float64,t_string[i]))
        end
        if haskey(dss_obj, "npts")
            npts = parse(Int64,dss_obj["npts"])
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
                    for i=0:npts - t_len - 1
                        push!(t_array, t_array[t_len+i]/2)
                    end
                end
                if length(c_array) < npts
                    @warn "c_array is shorter than npts. Adding current values."
                    c_len = length(c_array)
                    (a,b) = _bisection(c_array[c_len],t_array[c_len],c_array[c_len-1],t_array[c_len-1])
                    for i=1:npts - c_len
                        push!(c_array, round((a/t_array[c_len+i]+1)^(1/b)))
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
                    (a,b) = _bisection(c_array[c_len],t_array[c_len],c_array[c_len-1],t_array[c_len-1])
                    for i=1:npts - c_len
                        push!(c_array, round((a/t_array[c_len+i]+1)^(1/b)))
                    end
                else
                    @warn "t_array is shorter than c_array. Adding time values."
                    for i=0:c_len - t_len - 1
                        push!(t_array, t_array[t_len+i]/2)
                    end
                end
            end
        end
        add_curve(data_eng, id, t_array, c_array)
    end  
end