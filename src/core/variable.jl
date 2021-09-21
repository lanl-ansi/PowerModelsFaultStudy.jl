"Copies from PowerModels and PowerModelsDistribution without power vars"
function variable_branch_current(pm::_PM.AbstractIVRModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true, kwargs...)
    _PM.variable_branch_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PM.variable_branch_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)

    _PM.variable_branch_series_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PM.variable_branch_series_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
end


"builds generator variables for transmission networks"
function variable_gen(pm::_PM.AbstractIVRModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true, kwargs...)
    _PM.variable_gen_current_real(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    _PM.variable_gen_current_imaginary(pm, nw=nw, bounded=bounded, report=report; kwargs...)
    variable_gen_loading(pm, nw=nw, bounded=bounded, report=report; kwargs...)


    # store active and reactive power expressions for use in objective + post processing
    pg = Dict()
    qg = Dict()

    for (i, gen) in _PM.ref(pm, nw, :gen)
        busid = gen["gen_bus"]
        smax = abs(max(abs(gen["pmax"]), abs(gen["pmin"])) + max(abs(gen["qmax"]), abs(gen["qmin"])) * 1im)
        cmax = 1.1 * smax

        vr = _PM.var(pm, nw, :vr, busid)
        vi = _PM.var(pm, nw, :vi, busid)
        crg = _PM.var(pm, nw, :crg, i)
        cig = _PM.var(pm, nw, :cig, i)

        if gen["inverter"] == 1 && gen["inverter_mode"] == "pq"
            JuMP.set_lower_bound(crg, -cmax)
            JuMP.set_upper_bound(crg, cmax)
            JuMP.set_lower_bound(cig, -cmax)
            JuMP.set_upper_bound(cig, cmax)
        end

        pg[i] = JuMP.@NLexpression(pm.model, vr * crg  + vi * cig)
        qg[i] = JuMP.@NLexpression(pm.model, vi * crg  - vr * cig)
    end

    _PM.var(pm, nw)[:pg] = pg
    _PM.var(pm, nw)[:qg] = qg
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :gen, :pg, _PM.ids(pm, nw, :gen), pg)
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :gen, :qg, _PM.ids(pm, nw, :gen), qg)

    if bounded
        for (i, gen) in _PM.ref(pm, nw, :gen)
            _PM.constraint_gen_active_bounds(pm, i, nw=nw)
            _PM.constraint_gen_reactive_bounds(pm, i, nw=nw)
        end
    end
end


"variable: `pg[j]` for `j` in `gen`"
function variable_gen_loading(pm::_PM.AbstractIVRModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    kg = _PM.var(pm, nw)[:kg] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :gen)], base_name = "$(nw)_kg",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :gen, i), "kg_start")
    )

    for (i, gen) in _PM.ref(pm, nw, :gen)
        kmax = max(1.1 / gen["pg"], 2)
        JuMP.set_lower_bound(kg[i], 0)
        JuMP.set_upper_bound(kg[i], kmax)
    end

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :gen, :kg, _PM.ids(pm, nw, :gen), kg)
end


"helper function to get gen ids of 'pq' gens"
function pq_gen_ids(pm, nw)
    return [i for (i, gen) in _PM.ref(pm, nw, :gen) if gen["inverter_mode"] == "pq"]
end


"helper function to get gen dict of 'pq' gens"
function pq_gen_vals(pm, nw)
    return [gen for (i, gen) in _PM.ref(pm, nw, :gen) if gen["inverter_mode"] == "pq"]
end


"helper function to get gen ref of 'pq' gens"
function pq_gen_refs(pm, nw)
    return [(i, gen) for (i, gen) in _PM.ref(pm, nw, :gen) if gen["inverter_mode"] == "pq"]
end


"fault current variables for active faults"
function variable_bus_fault_current(pm::_PM.AbstractIVRModel; nw::Int=nw_id_default, report::Bool=true)
    cr = _PM.var(pm, nw)[:cfr] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :fault)], base_name="$(nw)_cfr",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :fault, i), "cfr_start", 0.0)
    )
    ci = _PM.var(pm, nw)[:cfi] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :fault)], base_name="$(nw)_cfi",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :fault, i), "cfi_start", 0.0)
    )

    cr_bus = _PM.var(pm, nw)[:cfr_bus] = Dict(_PM.ref(pm, nw, :fault, i, "fault_bus") => _PM.var(pm, nw, :cfr, i) for i in _PM.ids(pm, nw, :fault))
    ci_bus = _PM.var(pm, nw)[:cfi_bus] = Dict(_PM.ref(pm, nw, :fault, i, "fault_bus") => _PM.var(pm, nw, :cfi, i) for i in _PM.ids(pm, nw, :fault))

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :fault, :cfr, _PM.ids(pm, nw, :fault), cr)
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :fault, :cfi, _PM.ids(pm, nw, :fault), ci)

    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :bus, :cfr_bus, _PM.ids(pm, nw, :fault_buses), cr_bus)
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :bus, :cfi_bus, _PM.ids(pm, nw, :fault_buses), ci_bus)
end


"variables for pq inverters"
function variable_pq_inverter(pm::_PM.AbstractIVRModel; nw::Int=nw_id_default, bounded::Bool=true, kwargs...)
    p_int = _PM.var(pm, nw)[:p_int] = JuMP.@variable(pm.model,
        [i in pq_gen_ids(pm, nw)], base_name = "$(nw)_p_int_$(i)",
        start = 0
    )

    for (i, gen) in pq_gen_refs(pm, nw)
        JuMP.set_lower_bound(p_int[i], 0.0)
        JuMP.set_upper_bound(p_int[i], gen["pmax"])
    end

    q_int = _PM.var(pm, nw)[:q_int] = JuMP.@variable(pm.model,
        [i in pq_gen_ids(pm, nw)], base_name = "$(nw)_q_int_$(i)",
        start = 0
    )

    for (i, gen) in pq_gen_refs(pm, nw)
        JuMP.set_lower_bound(q_int[i], gen["qmin"])
        JuMP.set_upper_bound(q_int[i], gen["qmax"])
    end


    crg_pos_max = _PM.var(pm, nw)[:crg_max] = JuMP.@variable(pm.model,
        [i in pq_gen_ids(pm, nw)], base_name = "$(nw)_crg_pos_max_$(i)",
        start = 0.0
    )
    cig_pos_max = _PM.var(pm, nw)[:cig_max] = JuMP.@variable(pm.model,
        [i in pq_gen_ids(pm, nw)], base_name = "$(nw)_cig_pos_max_$(i)",
        start = 0.0
    )

    z = _PM.var(pm, nw)[:z] = JuMP.@variable(pm.model,
        [i in pq_gen_ids(pm, nw)], base_name = "$(nw)_z_$(i)",
        start = 0.0
    )
    for i in pq_gen_ids(pm, nw)
        JuMP.set_lower_bound(z[i], 0.0)
        JuMP.set_upper_bound(z[i], 1.0)
    end
end


"variables for multiconductor pq inverters"
function variable_mc_pq_inverter(pm::_PMD.AbstractUnbalancedIVRModel; nw::Int=nw_id_default, bounded::Bool=true, kwargs...)
    p_int = _PMD.var(pm, nw)[:p_int] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfli)], base_name = "$(nw)_p_int_$(i)",
        start = 0
    )
    for i in _PMD.ids(pm, nw, :solar_gfli)
        gen = _PMD.ref(pm, nw, :gen, i)
        pmax = 0.0
        if gen["solar_max"] < gen["kva"] * gen["pf"]
            pmax = gen["solar_max"]
        else
            pmax = gen["kva"] * gen["pf"]
        end
        JuMP.set_lower_bound(p_int[i], 0.0)
        JuMP.set_upper_bound(p_int[i], pmax / 3)
    end

    q_int = _PMD.var(pm, nw)[:q_int] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfli)], base_name = "$(nw)_q_int_$(i)",
        start = 0
    )
    for i in _PMD.ids(pm, nw, :solar_gfli)
        gen = _PMD.ref(pm, nw, :gen, i)
        pmax = 0.0
        if gen["solar_max"] < gen["kva"] * gen["pf"]
            pmax = gen["solar_max"]
        else
            pmax = gen["kva"] * gen["pf"]
        end
        JuMP.set_lower_bound(q_int[i], 0.0)
        JuMP.set_upper_bound(q_int[i], pmax / 3)
    end

    crg_pos = _PMD.var(pm, nw)[:crg_pos] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfli)], base_name = "$(nw)_crg_pos_$(i)",
        start = 0.0
    )
    cig_pos = _PMD.var(pm, nw)[:cig_pos] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm,nw, :solar_gfli)], base_name = "$(nw)_cig_pos_$(i)",
        start = 0.0
    )

    vrg_pos = _PMD.var(pm, nw)[:vrg_pos] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfli)], base_name = "$(nw)_vrg_pos_$(i)",
        start = 0.0
    )
    vig_pos = _PMD.var(pm, nw)[:vig_pos] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfli)], base_name = "$(nw)_vig_pos_$(i)",
        start = 0.0
    )

    crg_pos_max = _PMD.var(pm, nw)[:crg_pos_max] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfli)], base_name = "$(nw)_crg_pos_max_$(i)",
        start = 0.0
    )
    cig_pos_max = _PMD.var(pm, nw)[:cig_pos_max] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfli)], base_name = "$(nw)_cig_pos_max_$(i)",
        start = 0.0
    )

    z = _PMD.var(pm, nw)[:z_gfli] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfli)], base_name = "$(nw)_z_gfli_$(i)",
        start = 0.0
    )

    for i in _PMD.ids(pm, nw, :solar_gfli)
        JuMP.set_lower_bound(z[i], 0.0)
        JuMP.set_upper_bound(z[i], 1.0)
    end
end


"variables for multiconductor grid forming inverters"
function variable_mc_grid_formimg_inverter(pm::_PMD.AbstractUnbalancedIVRModel; nw::Int=nw_id_default, bounded::Bool=true, kwargs...)
    terminals = Dict(gfmi => _PMD.ref(pm, nw, :bus, bus)["terminals"] for (gfmi,bus) in _PMD.ref(pm, nw, :solar_gfmi))

    # inverter setpoints for virtual impedance formulation
    # taking into account virtual impedance voltage drop
    _PMD.var(pm, nw)[:vrsp] = Dict(i => JuMP.@variable(pm.model,
               [c in terminals[i]], base_name = "$(nw)_vrsp_$(i)",
               start = 0.0,
        ) for i in _PMD.ids(pm, nw, :solar_gfmi)
    )

    _PMD.var(pm, nw)[:visp] = Dict(i => JuMP.@variable(pm.model,
    [c in terminals[i]], base_name = "$(nw)_visp_$(i)",
               start = 0.0,
        ) for i in _PMD.ids(pm, nw, :solar_gfmi)
    )

    _PMD.var(pm, nw)[:z] = Dict(i => JuMP.@variable(pm.model,
               [c in terminals[i]], base_name = "$(nw)_z_$(i)",
               start = 0.0,
               lower_bound = 0.0,
               upper_bound = 1.0
        ) for i in _PMD.ids(pm, nw, :solar_gfmi)
    )

    _PMD.var(pm, nw)[:z2] = Dict(i => JuMP.@variable(pm.model,
               [c in terminals[i]], base_name = "$(nw)_z2_$(i)",
               start = 0.0,
               lower_bound = 0.0,
               upper_bound = 1.0
        ) for i in _PMD.ids(pm, nw, :solar_gfmi)
    )

    _PMD.var(pm, nw)[:z3] = Dict(i => JuMP.@variable(pm.model,
               [c in terminals[i]], base_name = "$(nw)_z3_$(i)",
               start = 0.0,
               lower_bound = 0.0,
               upper_bound = 1.0
        ) for i in _PMD.ids(pm, nw, :solar_gfmi)
    )

    p = _PMD.var(pm, nw)[:p_solar] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfmi)], base_name = "$(nw)_p_solar_$(i)",
        start = 0
    )

    q = _PMD.var(pm, nw)[:q_solar] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :solar_gfmi)], base_name = "$(nw)_q_solar_$(i)",
        start = 0
    )

    _PMD.var(pm, nw)[:rv] = Dict(i => JuMP.@variable(pm.model,
               [c in terminals[i]], base_name = "$(nw)_rv_$(i)",
               start = 0.0,
        ) for i in _PMD.ids(pm, nw, :solar_gfmi)
    )

    _PMD.var(pm, nw)[:xv] = Dict(i => JuMP.@variable(pm.model,
               [c in terminals[i]], base_name = "$(nw)_xv_$(i)",
               start = 0.0,
        ) for i in _PMD.ids(pm, nw, :solar_gfmi)
    )

end


"variables for multiconductor fault currents for active faults"
function variable_mc_bus_fault_current(pm::_PMD.AbstractUnbalancedIVRModel; nw::Int=nw_id_default, report::Bool=true)
    cr = _PMD.var(pm, nw)[:cfr] = Dict(
        i => JuMP.@variable(
            pm.model,
            [t in _PMD.ref(pm, nw, :fault, i, "connections")],
            base_name = "$(nw)_cfr",
            start = 0
        ) for i in _PMD.ids(pm, nw, :fault)
    )

    ci = _PMD.var(pm, nw)[:cfi] = Dict(
        i => JuMP.@variable(
            pm.model,
            [t in _PMD.ref(pm, nw, :fault, i, "connections")],
            base_name = "$(nw)_cfr",
            start = 0
        ) for i in _PMD.ids(pm, nw, :fault)
    )

    cr_bus = _PMD.var(pm, nw)[:cfr_bus] = Dict(_PMD.ref(pm, nw, :fault, i, "fault_bus") => cfr for (i, cfr) in cr)
    ci_bus = _PMD.var(pm, nw)[:cfi_bus] = Dict(_PMD.ref(pm, nw, :fault, i, "fault_bus") => cfi for (i, cfi) in ci)

    report && _IM.sol_component_value(pm, _PMD.pmd_it_sym, nw, :fault, :cfr, _PMD.ids(pm, nw, :fault), cr)
    report && _IM.sol_component_value(pm, _PMD.pmd_it_sym, nw, :fault, :cfi, _PMD.ids(pm, nw, :fault), ci)

    report && _IM.sol_component_value(pm, _PMD.pmd_it_sym, nw, :bus, :cfr_bus, _PMD.ids(pm, nw, :fault_buses), cr_bus)
    report && _IM.sol_component_value(pm, _PMD.pmd_it_sym, nw, :bus, :cfi_bus, _PMD.ids(pm, nw, :fault_buses), ci_bus)
end


"variables for output terminal currents for grid-connected energy storage"
function variable_mc_storage_current(pm::_PMD.AbstractUnbalancedIVRModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    variable_mc_storage_current_real(pm; nw=nw, bounded=bounded, report=report)
    variable_mc_storage_current_imaginary(pm; nw=nw, bounded=bounded, report=report)
end


"variables for real portion of output terminal currents for grid-connected energy storage"
function variable_mc_storage_current_real(pm::_PMD.AbstractUnbalancedIVRModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    connections = Dict(i => storage["connections"] for (i,storage) in _PMD.ref(pm, nw, :storage))
    crs = _PMD.var(pm, nw)[:crs] = Dict(i => JuMP.@variable(pm.model,
            # [c in _PMD.ref(pm, nw, :bus_conns_storage, storage["storage_bus"])], base_name="$(nw)_cis_$(i)",
            [c in connections[i]], base_name="$(nw)_crs_$(i)",
            start = _PMD.comp_start_value(_PMD.ref(pm, nw, :storage, i), "crs_start", c, 0.0)
        ) for i in _PMD.ids(pm, nw, :storage)
    )
    if bounded
        for (i,storage) in ref(pm, nw, :storage)
            if haskey(storage, "thermal_rating")
                for (idx,c) in enumerate(connections[i])
                    set_lower_bound(crs[i][c], -storage["thermal_rating"][idx])
                end
            end
            if haskey(gen, "thermal_rating")
                for (idx,c) in enumerate(connections[i])
                    set_upper_bound(crs[i][c], gen["thermal_rating"][idx])
                end
            end
        end        
    end
end


"variables for real portion of output terminal currents for grid-connected energy storage"
function variable_mc_storage_current_imaginary(pm::_PMD.AbstractUnbalancedIVRModel; nw::Int=nw_id_default, bounded::Bool=true, report::Bool=true)
    connections = Dict(i => storage["connections"] for (i,storage) in _PMD.ref(pm, nw, :storage))
    cis = _PMD.var(pm, nw)[:cis] = Dict(i => JuMP.@variable(pm.model,
            # [c in _PMD.ref(pm, nw, :bus_conns_storage, storage["storage_bus"])], base_name="$(nw)_cis_$(i)",
            [c in connections[i]], base_name="$(nw)_crs_$(i)",
            start = _PMD.comp_start_value(_PMD.ref(pm, nw, :storage, i), "cis_start", c, 0.0)
        ) for i in _PMD.ids(pm, nw, :storage)
    )
    if bounded
        for (i,storage) in ref(pm, nw, :storage)
            if haskey(storage, "qmin")
                for (idx,c) in enumerate(connections[i])
                    set_lower_bound(crs[i][c], storage["qmin"][idx])
                end
            end
            if haskey(gen, "qmax")
                for (idx,c) in enumerate(connections[i])
                    set_upper_bound(crs[i][c], gen["qmax"][idx])
                end
            end
        end        
    end        
end


"variables associated with grid-connected energy storage: internal voltage, virutal impedance, dc-link power, faulted state"
function variable_mc_storage_grid_forming_inverter(pm::_PMD.AbstractUnbalancedIVRModel; nw::Int=nw_id_default, bounded::Bool=true, kwargs...)
    connections = Dict(i => storage["connections"] for (i,storage) in _PMD.ref(pm, nw, :storage))

    # inverter setpoints for virtual impedance formulation
    # taking into account virtual impedance voltage drop
    _PMD.var(pm, nw)[:vrstp] = Dict(i => JuMP.@variable(pm.model,
               [c in connections[i]], base_name = "$(nw)_vrstp_$(i)",
               start = 0.0,
        ) for i in _PMD.ids(pm, nw, :storage)
    )

    _PMD.var(pm, nw)[:vistp] = Dict(i => JuMP.@variable(pm.model,
    [c in connections[i]], base_name = "$(nw)_vistp_$(i)",
               start = 0.0,
        ) for i in _PMD.ids(pm, nw, :storage)
    )

    _PMD.var(pm, nw)[:z_storage] = Dict(i => JuMP.@variable(pm.model,
               [c in connections[i]], base_name = "$(nw)_:z_storage_$(i)",
               start = 0.0,
               lower_bound = 0.0,
               upper_bound = 1.0
        ) for i in _PMD.ids(pm, nw, :storage)
    )

    p = _PMD.var(pm, nw)[:p_storage] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :storage)], base_name = "$(nw)_p_storage_$(i)",
        start = 0
    )

    q = _PMD.var(pm, nw)[:q_storage] = JuMP.@variable(pm.model,
        [i in _PMD.ids(pm, nw, :storage)], base_name = "$(nw)_q_storage_$(i)",
        start = 0
    )

    _PMD.var(pm, nw)[:rv_storage] = Dict(i => JuMP.@variable(pm.model,
               [c in connections[i]], base_name = "$(nw)_rv_storage_$(i)",
               start = 0.0,
        ) for i in _PMD.ids(pm, nw, :storage)
    )

    _PMD.var(pm, nw)[:xv_storage] = Dict(i => JuMP.@variable(pm.model,
               [c in connections[i]], base_name = "$(nw)_xv_storage_$(i)",
               start = 0.0,
        ) for i in _PMD.ids(pm, nw, :storage)
    )

end
