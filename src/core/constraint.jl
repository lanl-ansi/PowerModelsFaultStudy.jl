"generator reactive power setpoint constraint"
function constraint_mc_gen_power_setpoint_imag(pm::_PMD.AbstractUnbalancedPowerModel, n::Int, i, qg)
    qg_var = _PMD.var(pm, n, :qg, i)
    JuMP.@constraint(pm.model, qg_var .== qg)
end


"States that the bus voltage is equal to the internal voltage minus voltage drop across subtransient impedance"
function constraint_gen_voltage_drop(pm::_PM.AbstractIVRModel, n::Int, i::Int, bus_id, r, x, vgr, vgi)
    vr_to = _PM.var(pm, n, :vr, bus_id)
    vi_to = _PM.var(pm, n, :vi, bus_id)

    crg =  _PM.var(pm, n, :crg, i)
    cig =  _PM.var(pm, n, :cig, i)

    JuMP.@constraint(pm.model, vr_to == vgr - r * crg + x * cig)
    JuMP.@constraint(pm.model, vi_to == vgi - r * cig - x * crg)
end


"Calculates the fault current at a bus"
function constraint_bus_fault_current(pm::_PM.AbstractIVRModel, nw::Int, i::Int, fault_bus::Int, g::Real)
    vr = _PM.var(pm, nw, :vr, fault_bus)
    vi = _PM.var(pm, nw, :vi, fault_bus)

    cr = _PM.var(pm, nw, :cfr, i)
    ci = _PM.var(pm, nw, :cfi, i)

    JuMP.@constraint(pm.model, g * vr == cr)
    JuMP.@constraint(pm.model, g * vi == ci)
end


"Calculates the current balance at the non-faulted buses"
function constraint_current_balance(pm::_PM.AbstractIVRModel, n::Int, i::Int, bus_arcs, bus_gens, bus_gs, bus_bs)
    vr = _PM.var(pm, n, :vr, i)
    vi = _PM.var(pm, n, :vi, i)

    cr =  _PM.var(pm, n, :cr)
    ci =  _PM.var(pm, n, :ci)

    crg =  _PM.var(pm, n, :crg)
    cig =  _PM.var(pm, n, :cig)

    JuMP.@NLconstraint(pm.model, sum(cr[a] for a in bus_arcs)
                                ==
                                sum(crg[g] for g in bus_gens)
                                - sum(gs for gs in values(bus_gs)) * vr + sum(bs for bs in values(bus_bs)) * vi
                                )
    JuMP.@NLconstraint(pm.model, sum(ci[a] for a in bus_arcs)
                                ==
                                sum(cig[g] for g in bus_gens)
                                - sum(gs for gs in values(bus_gs)) * vi - sum(bs for bs in values(bus_bs)) * vr
                                )
end


"Calculates the current balance at the faulted bus"
function constraint_fault_current_balance(pm::_PM.AbstractIVRModel, n::Int, i::Int, bus_arcs, bus_gens, bus_gs, bus_bs)
    vr = _PM.var(pm, n, :vr, i)
    vi = _PM.var(pm, n, :vi, i)

    cr =  _PM.var(pm, n, :cr)
    ci =  _PM.var(pm, n, :ci)

    crg =  _PM.var(pm, n, :crg)
    cig =  _PM.var(pm, n, :cig)

    cfr = _PM.var(pm, n, :cfr_bus, i)
    cfi = _PM.var(pm, n, :cfi_bus, i)

    JuMP.@NLconstraint(pm.model, sum(cr[a] for a in bus_arcs)
                                ==
                                sum(crg[g] for g in bus_gens)
                                - sum(gs for gs in values(bus_gs)) * vr + sum(bs for bs in values(bus_bs)) * vi
                                - cfr
                                )
    JuMP.@NLconstraint(pm.model, sum(ci[a] for a in bus_arcs)
                                ==
                                sum(cig[g] for g in bus_gens)
                                - sum(gs for gs in values(bus_gs)) * vi - sum(bs for bs in values(bus_bs)) * vr
                                - cfi
                                )
end


"Constraint that sets the terminal voltage basd on the internal voltage and the stator impedence"
function constraint_mc_gen_voltage_drop(pm::_PMD.AbstractUnbalancedIVRModel, n::Int, i::Int, bus_id::Int, r, x, vgr, vgi, terminals)
    vr_to = _PMD.var(pm, n, :vr, bus_id)
    vi_to = _PMD.var(pm, n, :vi, bus_id)

    crg =  _PMD.var(pm, n, :crg_bus, i)
    cig =  _PMD.var(pm, n, :cig_bus, i)

    @debug "Adding drop for generator $i on bus $bus_id with xdp = $x"

    for c in terminals
        JuMP.@constraint(pm.model, vr_to[c] == vgr[c] - r[c] * crg[c] + x[c] * cig[c])
        JuMP.@constraint(pm.model, vi_to[c] == vgi[c] - r[c] * cig[c] - x[c] * crg[c])
        # JuMP.@constraint(pm.model, vr_to[c] == vgr[c])
        # JuMP.@constraint(pm.model, vi_to[c] == vgi[c])
    end
end


"Calculates the current at the faulted bus for multiconductor"
function constraint_mc_bus_fault_current(pm::_PMD.AbstractUnbalancedPowerModel, nw::Int, i::Int, bus::Int, connections::Vector{Int}, Gf::Matrix{<:Real}, Bf::Matrix{<:Real})
    vr = _PMD.var(pm, nw, :vr, bus)
    vi = _PMD.var(pm, nw, :vi, bus)

    cr = _PMD.var(pm, nw, :cfr, i)
    ci = _PMD.var(pm, nw, :cfi, i)

    for (idx, fc) in enumerate(connections)
        JuMP.@constraint(pm.model, cr[fc] == sum(Gf[idx,jdx] * vr[tc] for (jdx,tc) in enumerate(connections)))
        JuMP.@constraint(pm.model, ci[fc] == sum(Gf[idx,jdx] * vi[tc] for (jdx,tc) in enumerate(connections)))
    end
end


"Calculates the current balance at the faulted bus for multiconductor"
function constraint_mc_fault_current_balance(pm::_PMD.AbstractUnbalancedIVRModel, nw::Int, i::Int, fault::Int, terminals::Vector{Int}, grounded::Vector{Bool}, bus_arcs::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_sw::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_arcs_trans::Vector{Tuple{Tuple{Int,Int,Int},Vector{Int}}}, bus_gens::Vector{Tuple{Int,Vector{Int}}}, bus_storage::Vector{Tuple{Int,Vector{Int}}}, bus_shunts::Vector{Tuple{Int,Vector{Int}}})
    vr = _PMD.var(pm, nw, :vr, i)
    vi = _PMD.var(pm, nw, :vi, i)

    cr    = get(_PMD.var(pm, nw),    :cr, Dict()); _PMD._check_var_keys(cr, bus_arcs, "real current", "branch")
    ci    = get(_PMD.var(pm, nw),    :ci, Dict()); _PMD._check_var_keys(ci, bus_arcs, "imaginary current", "branch")
    crg   = get(_PMD.var(pm, nw),   :crg_bus, Dict()); _PMD._check_var_keys(crg, bus_gens, "real current", "generator")
    cig   = get(_PMD.var(pm, nw),   :cig_bus, Dict()); _PMD._check_var_keys(cig, bus_gens, "imaginary current", "generator")
    crs   = get(_PMD.var(pm, nw),   :crs, Dict()); _PMD._check_var_keys(crs, bus_storage, "real currentr", "storage")
    cis   = get(_PMD.var(pm, nw),   :cis, Dict()); _PMD._check_var_keys(cis, bus_storage, "imaginary current", "storage")
    crsw  = get(_PMD.var(pm, nw),  :crsw, Dict()); _PMD._check_var_keys(crsw, bus_arcs_sw, "real current", "switch")
    cisw  = get(_PMD.var(pm, nw),  :cisw, Dict()); _PMD._check_var_keys(cisw, bus_arcs_sw, "imaginary current", "switch")
    crt   = get(_PMD.var(pm, nw),   :crt, Dict()); _PMD._check_var_keys(crt, bus_arcs_trans, "real current", "transformer")
    cit   = get(_PMD.var(pm, nw),   :cit, Dict()); _PMD._check_var_keys(cit, bus_arcs_trans, "imaginary current", "transformer")

    cfr = _PMD.var(pm, nw, :cfr, fault)
    cfi = _PMD.var(pm, nw, :cfi, fault)

    fault_conns = _PMD.ref(pm, nw, :fault, fault, "connections")

    Gt, Bt = _PMD._build_bus_shunt_matrices(pm, nw, terminals, bus_shunts)

    ungrounded_terminals = [(idx,t) for (idx,t) in enumerate(terminals) if !grounded[idx]]

    for (idx, t) in ungrounded_terminals
        if t in fault_conns
            JuMP.@NLconstraint(pm.model,  sum(cr[a][t] for (a, conns) in bus_arcs if t in conns)
                                        + sum(crsw[a_sw][t] for (a_sw, conns) in bus_arcs_sw if t in conns)
                                        + sum(crt[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                        ==
                                        sum(crg[g][t]         for (g, conns) in bus_gens if t in conns)
                                        - sum(crs[s][t]         for (s, conns) in bus_storage if t in conns)
                                        - sum( Gt[idx,jdx]*vr[u] -Bt[idx,jdx]*vi[u] for (jdx,u) in ungrounded_terminals) # shunts
                                        - cfr[t] # faults
                                        )
            JuMP.@NLconstraint(pm.model,  sum(ci[a][t] for (a, conns) in bus_arcs if t in conns)
                                        + sum(cisw[a_sw][t] for (a_sw, conns) in bus_arcs_sw if t in conns)
                                        + sum(cit[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                        ==
                                        sum(cig[g][t]         for (g, conns) in bus_gens if t in conns)
                                        - sum(cis[s][t]         for (s, conns) in bus_storage if t in conns)
                                        - sum( Gt[idx,jdx]*vi[u] +Bt[idx,jdx]*vr[u] for (jdx,u) in ungrounded_terminals) # shunts
                                        - cfi[t] # faults
                                        )
        else
            JuMP.@NLconstraint(pm.model,  sum(cr[a][t] for (a, conns) in bus_arcs if t in conns)
                                        + sum(crsw[a_sw][t] for (a_sw, conns) in bus_arcs_sw if t in conns)
                                        + sum(crt[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                        ==
                                        sum(crg[g][t]         for (g, conns) in bus_gens if t in conns)
                                        - sum(crs[s][t]         for (s, conns) in bus_storage if t in conns)
                                        - sum( Gt[idx,jdx]*vr[u] -Bt[idx,jdx]*vi[u] for (jdx,u) in ungrounded_terminals) # shunts
                                        )
            JuMP.@NLconstraint(pm.model,  sum(ci[a][t] for (a, conns) in bus_arcs if t in conns)
                                        + sum(cisw[a_sw][t] for (a_sw, conns) in bus_arcs_sw if t in conns)
                                        + sum(cit[a_trans][t] for (a_trans, conns) in bus_arcs_trans if t in conns)
                                        ==
                                        sum(cig[g][t]         for (g, conns) in bus_gens if t in conns)
                                        - sum(cis[s][t]         for (s, conns) in bus_storage if t in conns)
                                        - sum( Gt[idx,jdx]*vi[u] +Bt[idx,jdx]*vr[u] for (jdx,u) in ungrounded_terminals) # shunts
                                        )
        end
    end
end
