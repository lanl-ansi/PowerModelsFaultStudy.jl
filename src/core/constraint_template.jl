"Check to see if gen is inverter model"
function is_inverter(pm, i::Int, nw::Int=nw_id_default)
    gen = _PM.ref(pm, nw, :gen, i)

    if !haskey(gen, "inverter")
        return false
    end

    return gen["inverter"] == 1
end


"Checks to see if inverter is operating in pq mode"
function is_pq_inverter(pm, i::Int, nw::Int=nw_id_default)
    gen = _PM.ref(pm, nw, :gen, i)

    if !haskey(gen, "inverter")
        return false
    end

    if gen["inverter"] == 0
        return false
    end

    if !haskey(gen, "inverter_mode")
    	return false
    end

    return gen["inverter_mode"] == "pq"
end


"Checks to see if inverter is operating in V mode"
function is_v_inverter(pm, i::Int, nw::Int=nw_id_default)
    gen = _PM.ref(pm, nw, :gen, i)

    if !haskey(gen, "inverter")
        return false
    end

    if gen["inverter"] == 0
        return false
    end

    if !haskey(gen, "inverter_mode")
    	return false
    end

    return gen["inverter_mode"] == "v"
end


"constraint for the fault current at the fault_bus"
function constraint_bus_fault_current(pm::_PM.AbstractIVRModel, i::Int; nw::Int=nw_id_default)
    constraint_bus_fault_current(pm, nw, i, _PM.ref(pm, nw, :fault, i, "fault_bus"), _PM.ref(pm, nw, :fault, i, "gf"))
end


"generator reactive power setpoint constraint"
function constraint_mc_gen_power_setpoint_imag(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default, kwargs...)
    qg_set = _PMD.ref(pm, nw, :gen, i, "qg")
    constraint_mc_gen_power_setpoint_imag(pm, nw, i, qg_set)
end

"Constraint that sets the terminal voltage basd on the internal voltage and the stator impedence"
function constraint_gen_voltage_drop(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default)
    for (k, gen) in _PM.ref(pm, nw, :gen)
        i = gen["index"]

        if is_inverter(pm, i, nw)
            continue
        end

        bus_id = gen["gen_bus"]

        r = gen["zr"]
        x = gen["zx"]
        z = r + 1im * x

        p = gen["pg"]
        q = gen["qg"]
        s = p + 1im * q

        vm = _PM.ref(pm, :bus, bus_id, "vm")
        va = _PM.ref(pm, :bus, bus_id, "va")
        v = vm * exp(1im * va)

        vr = real(v)
        vi = imag(v)
        @debug "vr = $vr, vi = $vi"

        c = conj(s / v)
        vg = v + z * c # add an option here to disable pre-computed voltage drop
        vgr = real(vg)
        vgi = imag(vg)
        @debug "Compensated vg: vgr = $vgr, vgi = $vgi"


        constraint_gen_voltage_drop(pm, nw, i, bus_id, r, x, vgr, vgi)
    end
end


"Constraints for fault current contribution of inverter in grid-following mode with pq set points"
function constraint_pq_inverter(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default)
    for (k, gen) in _PM.ref(pm, nw, :gen)
        i = gen["index"]

        if !is_pq_inverter(pm, i, nw)
            continue
        end

        bus_id = gen["gen_bus"]

        r = gen["zr"]
        pg = gen["pg"]
        qg = gen["qg"]

        smax = abs(max(abs(gen["pmax"]), abs(gen["pmin"])) + max(abs(gen["qmax"]), abs(gen["qmin"])) * 1im)
        cmax = 1.1 * smax

        # constraint_pq_inverter(pm, nw, i, bus_id, pg, qg, cmax)
        constraint_unity_pf_inverter(pm, nw, i, bus_id, pg, qg, cmax)
    end
end


"Constraints for fault current contribution of inverter in grid-following mode assuming that the inverter current regulating loop operates slowly"
function constraint_i_inverter(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default)
    for (k, gen) in _PM.ref(pm, nw, :gen)
        i = gen["index"]

        if !is_pq_inverter(pm, i, nw)
            continue
        end

        bus_id = gen["gen_bus"]
        bus = _PM.ref(pm, nw, :bus, bus_id)

        r = gen["zr"]
        pg = gen["pg"]
        qg = gen["qg"]

        cm = abs(gen["pg"] + 1im * gen["qg"]) / bus["vm"]

        constraint_i_inverter_vs(pm, nw, i, bus_id, r, pg, qg, cm)
    end
end


"Constraints for fault current contribution of inverter in grid-forming mode"
function constraint_v_inverter(pm::_PM.AbstractPowerModel; nw::Int=nw_id_default)
    for (k, gen) in _PM.ref(pm, nw, :gen)
        i = gen["index"]

        if !is_v_inverter(pm, i, nw)
            continue
        end

        bus_id = gen["gen_bus"]
        bus = _PM.ref(pm, nw, :bus, bus_id)

        vm = _PM.ref(pm, :bus, bus_id, "vm")
        va = _PM.ref(pm, :bus, bus_id, "va")

        vgr = vm * cos(va)
        vgi = vm * sin(va)

        r = gen["zr"]
        x = gen["zx"]

        pg = gen["pg"]
        qg = gen["qg"]

        smax = abs(max(abs(gen["pmax"]), abs(gen["pmin"])) + max(abs(gen["qmax"]), abs(gen["qmin"])) * 1im)
        cmax = 1.1 * smax

        constraint_v_inverter(pm, nw, i, bus_id, r, x, vgr, vgi, cmax)
    end
end


"Constraint to calculate the fault current at a bus and the current at other buses"
function constraint_current_balance(pm::_PM.AbstractPowerModel, i::Int; nw::Int=nw_id_default)
    bus_arcs = _PM.ref(pm, nw, :bus_arcs, i)
    bus_gens = _PM.ref(pm, nw, :bus_gens, i)
    bus_shunts = _PM.ref(pm, nw, :bus_shunts, i)

    bus_gs = Dict(k => _PM.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bus_bs = Dict(k => _PM.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    if i in _PM.ids(pm, nw, :fault_buses)
        constraint_fault_current_balance(pm, nw, i, bus_arcs, bus_gens, bus_gs, bus_bs)
    else
        constraint_current_balance(pm, nw, i, bus_arcs, bus_gens, bus_gs, bus_bs)
    end
end


"Constraint that sets the terminal voltage basd on the internal voltage and the stator impedence for multiconductor"
function constraint_mc_gen_voltage_drop(pm::_PMD.AbstractUnbalancedPowerModel; nw::Int=nw_id_default)
    for (k, gen) in _PMD.ref(pm, nw, :gen)
        if k in _PMD.ids(pm, :solar_gfli)
            @debug "Skipping gen $k in gen constraints"
            continue
        end

        if !("zr" in keys(gen))
            @debug "Skipping gen $k in gen constraints"
            continue
        end

        if occursin("voltage_source", gen["source_id"])
            @debug "Skipping gen $k in gen constraints"
            continue
        end

        @debug "Adding voltage drop constraint for generator $k"

        i = gen["index"]
        bus_id = gen["gen_bus"]

        r = gen["zr"]
        x = gen["zx"]

        # only 3 phase generation is supported
        terminals = length(gen["connections"])
        if terminals == 3
            vm = [1, 1, 1]
            va = [0, -2*pi/3, 2*pi/3]

            if "vm" in keys(_PMD.ref(pm, :bus, bus_id))
                vm = _PMD.ref(pm, :bus, bus_id, "vm")
            else
                @warn "vm not specified for bus $bus_id, assuming 1"
            end

            if "va" in keys(_PMD.ref(pm, :bus, bus_id))
                va = _PMD.ref(pm, :bus, bus_id, "va")
            else
                @warn "va not specified for bus $bus_id, assuming 0"
            end

            mva = 100
            kva = 1e3*mva
            sb = 1e6*mva

            kv = 4.16
            vb = 1000*kv

            pg = gen["pg"]
            qg = gen["qg"]
            sg = pg + 1im*qg

            vr = [vm[i] * cos(va[i]) for i in 1:3]
            vi = [vm[i] * sin(va[i]) for i in 1:3]

            v = vr + 1im*vi
            cg = [conj(sg[i]/v[i]) for i in 1:3]
            z = r + 1im*x
            vg = [v[i] + (z[i]*cg[i]) for i in 1:3]

            vgr = real(vg)
            vgi = imag(vg)

            @debug "Generator terminal voltage from pre-fault powerflow" abs.(v[1])

            @debug "Generator pre-fault power (kVA)" kva*sg[1]

            ssi = sb*sg[1]
            vsi = vb*v[1]/sqrt(3)
            isi = ssi/vsi

            @debug "Generator pre-fault current (A)" abs(isi)
            @debug "Calculated generator internal voltage" abs.(vg[1])

            constraint_mc_gen_voltage_drop(pm, nw, i, bus_id, r, x, vgr, vgi, terminals)
        end
    end
end


"Constraints for fault current contribution of multiconductor inverter in grid-following mode"
function constraint_mc_pq_inverter(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)
    index = _PMD.ref(pm, nw, :solar_gfli, i)
    gen = _PMD.ref(pm, nw, :gen, i)

    cmax = gen["i_max"]
    if gen["solar_max"] < gen["kva"] * gen["pf"]
        pmax = gen["solar_max"]
    else
        pmax = gen["kva"] * gen["pf"]
    end
    constraint_mc_pq_inverter(pm, nw, i, index, pmax, 0.0, cmax)
end


"Constraints for fault current contribution of multiconductor inverter in grid-forming mode"
function constraint_mc_grid_forming_inverter(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)
    @debug "Adding grid-forming inverter constraint without impedance"
    index = _PMD.ref(pm, nw, :solar_gfmi, i)
    gen = _PMD.ref(pm, nw, :gen, index)
    bus_i = gen["gen_bus"]
    bus = _PMD.ref(pm, nw, :bus, bus_i)

    if !haskey(bus, "vm") && !haskey(bus, "va")
        bus["vm"] = [1 for c in bus["terminals"]]
        bus["va"] = [0, -2*pi/3, 2*pi/3]
    end

    cmax = gen["i_max"]
    vrstar = [bus["vm"][c] * cos(bus["va"][c]) for c in bus["terminals"]]
    vistar = [bus["vm"][c] * sin(bus["va"][c]) for c in bus["terminals"]]

    # push into pmax on import and erase this
    if gen["solar_max"] < gen["kva"]
        pmax = gen["solar_max"]
    else
        pmax = gen["kva"]
    end

    constraint_grid_forming_inverter(pm, nw, index, i, vrstar, vistar, pmax, cmax)
end


"Constraints for fault current contribution of multiconductor inverter in grid-forming mode with power matching"
function constraint_mc_grid_forming_inverter_impedance(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)
    index = _PMD.ref(pm, nw, :solar_gfmi, i)
    gen = _PMD.ref(pm, nw, :gen, index)
    bus_i = gen["gen_bus"]
    bus = _PMD.ref(pm, nw, :bus, bus_i)

    if !haskey(bus, "vm") && !haskey(bus, "va")
        bus["vm"] = [1 for c in bus["terminals"]]
        bus["va"] = [0, -2*pi/3, 2*pi/3]
    end

    cmax = gen["i_max"]
    vrstar = [bus["vm"][c] * cos(bus["va"][c]) for c in bus["terminals"]]
    vistar = [bus["vm"][c] * sin(bus["va"][c]) for c in bus["terminals"]]

    # push into pmax on import and erase this
    if gen["solar_max"] < gen["kva"]
        pmax = gen["solar_max"]
    else
        pmax = gen["kva"]
    end

    r = 0.1*ones(3)
    x = [0, 0, 0]

    if "r" in keys(gen)
        r = gen["zr"]
    end

    if "x" in keys(gen)
        x = gen["zx"]
    end

    constraint_grid_formimg_inverter_impedance(pm, nw, index, i, vrstar, vistar, r, x, pmax, cmax)
end


"Constraints for fault current contribution of multiconductor inverter in grid-forming mode with power matching"
function constraint_mc_grid_forming_inverter_virtual_impedance(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)
    index = _PMD.ref(pm, nw, :solar_gfmi, i)
    gen = _PMD.ref(pm, nw, :gen, i)
    bus_i = gen["gen_bus"]
    bus = _PMD.ref(pm, nw, :bus, bus_i)
    terminals = bus["terminals"]
    _PMD.ref(pm, nw, :grid_forming, bus_i) ? ang = true : ang = false

    if !haskey(bus, "vm") && !haskey(bus, "va")
        vm = [.995 for c in bus["terminals"]]
        va = [0 -2*pi/3 2*pi/3]
    else
        vm = bus["vm"]
        va = bus["va"]
    end

    vm = [.995 for c in terminals]
    va = [0 -2*pi/3 2*pi/3]

    cmax = gen["i_max"]
    vr = [vm[c] * cos(va[c]) for c in terminals]
    vi = [vm[c] * sin(va[c]) for c in terminals]

    # push into pmax on import and erase this
    if gen["solar_max"] < gen["kva"]
        pmax = gen["solar_max"]
    else
        pmax = gen["kva"]
    end

    smax = gen["kva"]

    constraint_mc_grid_formimg_inverter_virtual_impedance(pm, nw, i, index, vr, vi, pmax, cmax, smax, ang, terminals)
end


"Constraint to calculate the fault current at a bus and the current at other buses for multiconductor"
function constraint_mc_current_balance(pm::_PMD.AbstractUnbalancedPowerModel, i::Int; nw::Int=nw_id_default)
    bus = _PMD.ref(pm, nw, :bus, i)
    bus_arcs = _PMD.ref(pm, nw, :bus_arcs_conns_branch, i)
    bus_arcs_sw = _PMD.ref(pm, nw, :bus_arcs_conns_switch, i)
    bus_arcs_trans = _PMD.ref(pm, nw, :bus_arcs_conns_transformer, i)
    bus_gens = _PMD.ref(pm, nw, :bus_conns_gen, i)
    bus_storage = _PMD.ref(pm, nw, :bus_conns_storage, i)
    bus_shunts = _PMD.ref(pm, nw, :bus_conns_shunt, i)


    if bus["bus_i"] in _PMD.ids(pm, nw, :fault_buses)
        constraint_mc_fault_current_balance(pm, nw, i, _PMD.ref(pm, nw, :fault_buses, bus["bus_i"]), bus["terminals"], bus["grounded"], bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, bus_shunts)
    else
        _PMD.constraint_mc_current_balance(pm, nw, i, bus["terminals"], bus["grounded"], bus_arcs, bus_arcs_sw, bus_arcs_trans, bus_gens, bus_storage, Tuple{Int,Vector{Int}}[], bus_shunts)
    end
end


"Constraint for Kirchoff's current law on faulted buses"
function constraint_mc_bus_fault_current(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default)
    bus = _PMD.ref(pm, nw, :fault, i, "fault_bus")
    connections = _PMD.ref(pm, nw, :fault, i, "connections")
    Gf = _PMD.ref(pm, nw, :fault, i, "g")
    Bf = _PMD.ref(pm, nw, :fault, i, "b")

    constraint_mc_bus_fault_current(pm, nw, i, bus, connections, Gf, Bf)
end


"Constraint for fault-current contribution battery energy storage inverters"
function constraint_mc_storage_grid_forming_inverter(pm::_PMD.AbstractUnbalancedIVRModel, i::Int; nw::Int=nw_id_default)
    storage = _PMD.ref(pm, nw, :storage, i)
    connections = storage["connections"]
    bus_i = storage["storage_bus"]
    constraint_mc_storage_grid_forming_inverter(pm, nw, i, bus_i, connections)
end
