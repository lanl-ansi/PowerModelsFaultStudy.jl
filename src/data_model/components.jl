"""
    create_fault(type::String, bus::String, connections::Vector{Int}, resistance::Real, phase_resistance::Real)::Dict{String,Any}

Creates a fault dictionary given the `type` of fault, i.e., one of "3pq", "llg", the `bus` on which the fault is active,
the `connections` on which the fault applies, the `resistance` between the phase and ground, and the `phase_resistance`
between phases
"""
function create_fault(type::String, bus::String, connections::Vector{Int}, resistance::Real, phase_resistance::Real)::Dict{String,Any}
    return getfield(PowerModelsProtection, Symbol("_create_$(type)_fault"))(bus, connections, resistance, phase_resistance)
end


"""
    create_fault(type::String, bus::String, connections::Vector{Int}, resistance::Real, phase_resistance::Real)::Dict{String,Any}

Creates a fault dictionary given the `type` of fault, i.e., one of "3p", "ll", "lg", the `bus` on which the fault is active,
the `connections` on which the fault applies, the `resistance` between the phase and ground, in the case of "lg", or phase and phase.
"""
function create_fault(type::String, bus::String, connections::Vector{Int}, resistance::Real)::Dict{String,Any}
    return getfield(PowerModelsProtection, Symbol("_create_$(type)_fault"))(bus, connections, resistance)
end


"creates a three-phase fault"
function _create_3p_fault(bus::String, connections::Vector{Int}, phase_resistance::Real)::Dict{String,Any}
    @assert length(connections) == 3
    ncnds = length(connections)

    Gf = zeros(Real, ncnds, ncnds)
    for i in 1:ncnds
        for j in 1:ncnds
            if i != j
                Gf[i,j] = -1/phase_resistance
            else
                Gf[i,j] = 2 * (1/phase_resistance)
            end
        end
    end

    return Dict{String,Any}(
        "bus" => bus,
        "connections" => connections,
        "fault_type" => "3p",
        "g" => Gf,
        "b" => zeros(Real, ncnds, ncnds),
        "status" => _PMD.ENABLED,
    )
end


"creates a three-phase-ground fault"
function _create_3pg_fault(bus::String, connections::Vector{Int}, resistance::Real, phase_resistance::Real)::Dict{String,Any}
    @assert length(connections) == 4
    ncnds = length(connections)

    Gf = zeros(Real, ncnds, ncnds)

    gp = 1 / phase_resistance
    gf = 1 / resistance
    gtot = 3 * gp + gf
    gpp = gp^2 / gtot
    gpg = gp * gf / gtot

    for i in 1:ncnds
        for j in 1:ncnds
            if i == j
                if i == 4
                    Gf[i,j] = 3 * gpg
                else
                    Gf[i,j] = 2 * gpp + gpg
                end
            else
                if i == 4 || j == 4
                    Gf[i,j] = -gpg
                else
                    Gf[i,j] = -gpp
                end
            end
        end
    end

    return Dict{String,Any}(
        "bus" => bus,
        "connections" => connections,
        "fault_type" => "3pg",
        "g" => Gf,
        "b" => zeros(Real, ncnds, ncnds),
        "status" => _PMD.ENABLED,
    )
end


"creates a line-line fault"
function _create_ll_fault(bus::String, connections::Vector{Int}, phase_resistance::Real)::Dict{String,Any}
    @assert length(connections) == 2
    ncnds = length(connections)

    Gf = zeros(Real, ncnds, ncnds)
    for i in 1:ncnds
        for j in 1:ncnds
            if i == j
                Gf[i,j] = 1 / phase_resistance
            else
                Gf[i,j] = -1 / phase_resistance
            end
        end
    end

    return Dict{String,Any}(
        "bus" => bus,
        "connections" => connections,
        "fault_type" => "ll",
        "g" => Gf,
        "b" => zeros(Real, ncnds, ncnds),
        "status" => _PMD.ENABLED,
    )
end


"creates a line-line-ground fault"
function _create_llg_fault(bus::String, connections::Vector{Int}, resistance::Real, phase_resistance::Real)::Dict{String,Any}
    @assert length(connections) == 3
    ncnds = length(connections)

    Gf = zeros(Real, ncnds, ncnds)

    gp = 1 / phase_resistance
    gf = 1 / resistance
    gtot = 2 * gp + gf
    gpp = gp^2  / gtot
    gpg = gp * gf / gtot

    for i in 1:ncnds
        for j in 1:ncnds
            if i == j
                if i == 3
                    Gf[i,j] = 2 * gpg
                else
                    Gf[i,j] = gpp + gpg
                end
            else
                if i == 3 || j == 3
                    Gf[i,j] = -gpg
                else
                    Gf[i,j] = -gpp
                end
            end
        end
    end

    return Dict{String,Any}(
        "bus" => bus,
        "connections" => connections,
        "fault_type" => "llg",
        "g" => Gf,
        "b" => zeros(Real, ncnds, ncnds),
        "status" => _PMD.ENABLED,
    )
end


"creates a line-ground fault"
function _create_lg_fault(bus::String, connections::Vector{Int}, resistance::Real)::Dict{String,Any}
    @assert length(connections) == 2
    ncnds = length(connections)

    Gf = zeros(Real, ncnds, ncnds)
    for i in 1:ncnds
        for j in 1:ncnds
            if i == j
                Gf[i,j] =  1 / resistance
            else
                Gf[i,j] = -1 / resistance
            end
        end
    end

    return Dict{String,Any}(
        "bus" => bus,
        "connections" => connections,
        "fault_type" => "lg",
        "g" => Gf,
        "b" => zeros(Real, ncnds, ncnds),
        "status" => _PMD.ENABLED,
    )
end


"""
    add_fault!(data::Dict{String,Any}, name::String, type::String, bus::String, connections::Vector{Int}, resistance::Real, phase_resistance::Real)

Creates a fault dictionary given the `type` of fault, i.e., one of "3p", "ll", "lg", the `bus` on which the fault is active,
the `connections` on which the fault applies, the `resistance` between the phase and ground, in the case of "lg", or phase and phase,
and adds it to `data["fault"]` under `"name"`
"""
function add_fault!(data::Dict{String,Any}, name::String, type::String, bus::String, connections::Vector{Int}, resistance::Real, phase_resistance::Real)
    if !haskey(data, "fault")
        data["fault"] = Dict{String,Any}()
    end

    fault = create_fault(type, bus, connections, resistance, phase_resistance)

    fault["name"] = name
    data["fault"][name] = fault
end


"""
    add_fault!(data::Dict{String,Any}, name::String, type::String, bus::String, connections::Vector{Int}, resistance::Real)

Creates a fault dictionary given the `type` of fault, i.e., one of "3pq", "llg", the `bus` on which the fault is active,
the `connections` on which the fault applies, the `resistance` between the phase and ground, and the `phase_resistance`
between phases, and adds it to `data["fault"]` under `"name"`
"""
function add_fault!(data::Dict{String,Any}, name::String, type::String, bus::String, connections::Vector{Int}, resistance::Real)
    if !haskey(data, "fault")
        data["fault"] = Dict{String,Any}()
    end

    fault = create_fault(type, bus, connections, resistance)

    fault["name"] = name
    data["fault"][name] = fault
end


"""
    add_ct(data::Dict{String,Any}, element::String, id::String, n_p::Number, n_s::Number;kwargs...)

Function to add current transformer to circuit.
Inputs 4 if adding first CT, 5 otherwise:
    (1) data(Dictionary): Result from parse_file(). Circuit information
    (2) element(String): Element or line that CT is being added to
    (3) id(String): Optional. For multiple CT on the same line. If not used overwrites previously defined CT1
    (4) n_p(Number): Primary . Would be the number of  of the relay side of transformer
    (5) n_s(Number): Secondary . Number of  on line side
    (6) kwargs: Any other information user wants to add. Not used by anything.
"""
function add_ct(data::Dict{String,Any}, element::Union{String,SubString{String}}, id::Union{String,SubString{String}}, n_p::Number, n_s::Number;kwargs...)
    if !haskey(data, "protection")
        data["protection"] = Dict{String,Any}()
    end
    if haskey(data["line"], "$element")
        if !haskey(data["protection"], "C_Transformers")
            data["protection"]["C_Transformers"] = Dict{String,Any}()
        end
        if haskey(data["protection"]["C_Transformers"], "$id")
            @info "$id has been redefined"
        end
        data["protection"]["C_Transformers"]["$id"] = Dict{String,Any}(
            "turns" => [n_p,n_s],
            "element" => element
        )
        kwargs_dict = Dict(kwargs)
        new_dict = _add_dict(kwargs_dict)
        merge!(data["protection"]["C_Transformers"]["$id"], new_dict)
    else
        @info "Circuit element $element does not exist. No CT added."
    end
end


"""
    _non_ideal_ct(relay_data,CT_data,Iabc)

Converts primary side current to the actual current going through relay coil based on non-ideal parameters.
Unused.
"""
function _non_ideal_ct(relay_data, CT_data, Iabc)
    Ze = CT_data["Ze"]
    R2 = CT_data["R2"]
    Zb = relay_data["Zb"]
    turns = CT_data["turns"]
    i_s = Iabc .* turns[2] ./ turns[1]
    i_r = i_s .* Ze ./ (Ze + Zb + R2)
    return i_r
end
