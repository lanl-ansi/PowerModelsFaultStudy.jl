
""
function run_mc_pf(data::Dict{String,<:Any}, solver; kwargs...)  
    return solution = run_mc_model(data, _PM.IVRPowerModel, solver, build_mc_pf; ref_extensions=[ref_add_solar!], kwargs...)
end


""
function run_mc_pf(file::String, solver; kwargs...)
    return run_mc_pf(parse_file(file; import_all = true), solver; kwargs...)
end


""
function build_mc_pf(pm::_PM.AbstractPowerModel)
    _PMD.variable_mc_bus_voltage(pm, bounded=false)
    _PMD.variable_mc_branch_current(pm, bounded=false)
    _PMD.variable_mc_transformer_current(pm, bounded=false)
    _PMD.variable_mc_gen_power_setpoint(pm, bounded=false) 
    _PMD.variable_mc_load_setpoint(pm, bounded = false)
  
    variable_mc_pq_inverter(pm)
    variable_mc_grid_formimg_inverter(pm)

    for (i,bus) in ref(pm, :ref_buses)
        @assert bus["bus_type"] == 3
        _PMD.constraint_mc_theta_ref(pm, i)
        _PMD.constraint_mc_voltage_magnitude_only(pm, i)
    end

    for id in ids(pm, :gen)
        _PMD.constraint_mc_gen_setpoint(pm, id)
    end

    for id in ids(pm, :load)
        _PMD.constraint_mc_load_setpoint(pm, id)
    end

    for (i,bus) in ref(pm, :bus)
        
        _PMD.constraint_mc_load_current_balance(pm, i)
        
        # PV Bus Constraints
        if length(ref(pm, :bus_gens, i)) > 0 && !(i in ids(pm,:ref_buses))
            # this assumes inactive generators are filtered out of bus_gens
            @assert bus["bus_type"] == 2
            if !(i in ids(pm, :solar_gfli)) 
                _PMD.constraint_mc_voltage_magnitude_only(pm, i)
                if !(i in ids(pm, :solar_gfmi)) 
                    for j in ref(pm, :bus_gens, i)
                        _PMD.constraint_mc_gen_power_setpoint_real(pm, j)
                    end
                end
            end
        end

    end

    for i in ids(pm, :branch)
        _PMD.constraint_mc_current_from(pm, i)
        _PMD.constraint_mc_current_to(pm, i)
        _PMD.constraint_mc_bus_voltage_drop(pm, i)
    end

    for i in ids(pm, :transformer)
        _PMD.constraint_mc_transformer_power(pm, i)
    end

    for i in ids(pm, :solar_gfli)
        constraint_mc_pq_inverter(pm, i)
    end

    for i in ids(pm, :solar_gfmi)
        constraint_mc_grid_forming_inverter_impedance(pm, i)
        # constraint_mc_grid_forming_inverter(pm, i)
    end

end
