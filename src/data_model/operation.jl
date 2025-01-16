"Determines whether a relay operates given the current through its protected object"
function _relay_operation(relay_data::Dict{String,Any}, Iabc::Vector)
    trip = false
    if relay_data["type"] == "differential_dir"
        I_neg = Iabc[3]
        trip_angle = relay_data["trip"]
        if I_neg > trip_angle
            relay_data["state"] = "open"
            trip = true
        end
    elseif relay_data["type"] == "differential"
        Ir = relay_data["restraint"]
        for phase = 1:length(relay_data["phase"])
            if Iabc[phase] > Ir
                I = Iabc[phase]
                op_times = _differential_time(relay_data, I)
                relay_data["phase"]["$phase"]["state"] = "open"
                relay_data["phase"]["$phase"]["op_times"] = op_times
                trip = true
            else
                relay_data["phase"]["$phase"]["state"] = "closed"
            end
        end
    else
        if (relay_data["shots"] == 1)
            for phase = 1:length(relay_data["phase"])
                if Iabc[phase] > relay_data["TS"]
                    I = Iabc[phase]
                    op_times = _short_time(relay_data, I)
                    relay_data["phase"]["$phase"]["state"] = "open"
                    relay_data["phase"]["$phase"]["op_times"] = op_times
                    trip = true
                else
                    relay_data["phase"]["$phase"]["state"] = "closed"
                end
            end
        elseif relay_data["shots"] == 2
            op_times = zeros(length(relay_data["phase"]), 2)
            for phase = 1:length(relay_data["phase"])
                if Iabc[phase] > relay_data["TS"]
                    I = Iabc[phase]
                    op_times[phase, 1] = _short_time(relay_data, I)
                    op_times[phase, 2] = _long_time(relay_data, I) + op_times[phase, 1] + 0.5
                    relay_data["phase"]["$phase"]["op_times"] = op_times[phase, :]
                    relay_data["phase"]["$phase"]["state"] = "open"
                    trip = true
                else
                    relay_data["phase"]["$phase"]["state"] = "closed"
                end
            end
        elseif relay_data["shots"] == 3
            op_times = zeros(length(relay_data["phase"]), 3)
            for phase = 1:length(relay_data["phase"])
                if Iabc[phase] > relay_data["TS"]
                    I = Iabc[phase]
                    op_times[phase, 1] = _short_time(relay_data, I)
                    op_times[phase, 2] = _short_time(relay_data, I) + op_times[phase, 1] + 0.5
                    op_times[phase, 3] = _long_time(relay_data, I) + op_times[phase, 2] + 2.5
                    relay_data["phase"]["$phase"]["op_times"] = op_times[phase, :]
                    relay_data["phase"]["$phase"]["state"] = "open"
                    trip = true
                else
                    relay_data["phase"]["$phase"]["state"] = "closed"
                end
            end
        elseif relay_data["shots"] >= 4
            op_times = zeros(length(relay_data["phase"]), 4)
            for phase = 1:length(relay_data["phase"])
                if Iabc[phase] > relay_data["TS"]
                    I = Iabc[phase]
                    op_times[phase, 1] = _short_time(relay_data, I)
                    op_times[phase, 2] = _short_time(relay_data, I) + op_times[phase, 1] + 0.5
                    op_times[phase, 3] = _long_time(relay_data, I) + op_times[phase, 2] + 2.5
                    op_times[phase, 4] = _long_time(relay_data, I) + op_times[phase, 3] + 12.5
                    relay_data["phase"]["$phase"]["op_times"] = op_times[phase, :]
                    relay_data["phase"]["$phase"]["state"] = "open"
                    trip = true
                else
                    relay_data["phase"]["$phase"]["state"] = "closed"
                end
            end
        end
    end
    return trip
end


"Determines whether a fuse operates given the current through the line it is protecting"
function _fuse_operation(data::Dict{String,Any}, fuse_data::Dict{String,Any}, Iabc::Vector)
    blown = false
    min_melt_curve = fuse_data["min_melt_curve"]
    max_clear_curve = fuse_data["max_clear_curve"]
    if typeof(min_melt_curve) == String
        min_current_vec = data["protection"]["curves"]["$min_melt_curve"]["curve_mat"][1, :]
        min_time_vec = data["protection"]["curves"]["$min_melt_curve"]["curve_mat"][2, :]
    else
        min_current_vec = min_melt_curve[1, :]
        min_time_vec = min_melt_curve[2, :]
    end
    if typeof(max_clear_curve) == String
        max_current_vec = data["protection"]["curves"]["$max_clear_curve"]["curve_mat"][1, :]
        max_time_vec = data["protection"]["curves"]["$max_clear_curve"]["curve_mat"][2, :]
    else
        max_current_vec = max_clear_curve[1, :]
        max_time_vec = max_clear_curve[2, :]
    end
    for phase = 1:length(fuse_data["phase"])
        (time_min, op_min) = _interpolate_time(min_current_vec, min_time_vec, Iabc[phase])
        if op_min
            blown = true
            (time_max, op_max) = _interpolate_time(max_current_vec, max_time_vec, Iabc[phase])
            if op_max
                fuse_data["phase"]["$phase"]["state"] = "open"
                fuse_data["phase"]["$phase"]["op_times"] = "Min. melt: $time_min. Max. clear: $time_max."
            else
                fuse_data["phase"]["$phase"]["state"] = "open"
                fuse_data["phase"]["$phase"]["op_times"] = "Min. melt: $time_min."
            end
        else
            fuse_data["phase"]["$phase"]["state"] = "closed"
            fuse_data["phase"]["$phase"]["op_times"] = "Does not operate."
        end
    end
    return blown
end


"Function to solve protection problem when not using solution processors or extensions"
function protection_operation(data::Dict{String,Any}, results::Dict{String,Any})
    if haskey(data, "protection")
        tripped_relays = Dict{String,Any}("relay" => Dict{String,Any}())
        blown_fuses = Dict{String,Any}("fuse" => Dict{String,Any}())
        if haskey(data["protection"], "relays")
            elements = collect(keys(data["protection"]["relays"]))
            for element in elements
                for (id, relay) in get(data["protection"]["relays"], "$element", Dict())
                    Iabc = _get_current(data, results, element, id)
                    trip = _relay_operation(relay, Iabc)
                    if trip
                        tripped_relays["relay"]["$id"] = relay
                    end
                end
            end
        end
        if haskey(data["protection"], "fuses")
            elements = collect(keys(data["protection"]["fuses"]))
            for element in elements
                for (id, fuse) in get(data["protection"]["fuses"], "$element", Dict())
                    Iabc = _get_current(data, results, element, id)
                    blown = _fuse_operation(data, fuse, Iabc)
                    if blown
                        blown_fuses["fuse"]["$id"] = fuse
                    end
                end
            end
        end
        if !isempty(tripped_relays["relay"])
            merge!(results["solution"], tripped_relays)
        end
        if !isempty(blown_fuses["fuse"])
            merge!(results["solution"], blown_fuses)
        end
    else
        @info "No protection equipment in circuit."
    end
end


"Shows all protection equipment that have operated and their respective operating times"
function protection_report(results::Dict{String,Any})
    string = ""
    for (id, relay) in get(results["solution"], "relay", Dict())
        op_times = []
        phase_string = "phase "
        time_string = ""
        phase_vec = []
        if relay["type"] != "differential_dir"
            for phase = 1:length(relay["phase"])
                if relay["phase"]["$phase"]["state"] == "open"
                    push!(phase_vec, phase)
                    push!(op_times, relay["phase"]["$phase"]["op_times"])
                end
            end
            if length(phase_vec) > 1
                phase_string = phase_string * "$(phase_vec[1]), "
                time_string = time_string * "$(op_times[1]), "
                for i = 2:length(phase_vec)
                    if i == length(phase_vec)
                        phase_string = phase_string * "and $(phase_vec[end]) tripped "
                        time_string = time_string * "and $(op_times[end]) seconds after fault occured.\n"
                    else
                        phase_string = phase_string * "$(phase_vec[i]), "
                        time_string = time_string * "$(op_times[i]), "
                    end
                end
            else
                phase_string = phase_string * "$(phase_vec[1]) tripped "
                time_string = time_string * "$(op_times[1]) seconds after fault occured.\n"
            end
            string = string * "Relay $id " * phase_string * time_string
        else
            string = string * "Relay $id tripped.\n"
        end
    end
    for (id, fuse) in get(results["solution"], "fuse", Dict())
        op_times = []
        phase_vec = []
        for phase = 1:length(fuse["phase"])
            if fuse["phase"]["$phase"]["state"] == "open"
                push!(phase_vec, phase)
                push!(op_times, fuse["phase"]["$phase"]["op_times"])
            end
        end
        for i = 1:length(phase_vec)
            string = string * "Fuse $id phase $(phase_vec[i]): " * op_times[i] * "\n"
        end
    end
    @info string
end
