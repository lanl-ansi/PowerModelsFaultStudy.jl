"""
    parse_matpower(
        file::String;
        method::Union{String,Missing},
        add_gensub::Bool=false,
        flat_start::Bool=false,
        neglect_line_charging::Bool=false,
        neglect_transformer::Bool=false,
        zero_gen_setpoints::Bool=false,
        import_all::Bool=true
    )::Dict{String,Any}

Parser for matpower (transmission) files.

`method` is for matpower files, and should be one of "PMs", "solar-pf", "dg-pf", "pf", or "opf", and "PMD" or missing for dss files.

If `add_gensub`, [`parse_matpower`](@ref parse_matpower) will attempt to find rs and xs from a gensub dict.

Explanations of `flat_start`, `neglect_line_charging`, `neglect_transformer`, and `zero_gen_setpoints` can be found in [`prepare_transmission_data!`](@ref prepare_transmission_data!)

If `add_gensub`, [`parse_matpower`](@ref parse_matpower) will attempt to find rs and xs from a gensub dict.

Explanations of `flat_start`, `neglect_line_charging`, `neglect_transformer`, and `zero_gen_setpoints` can be found in [`prepare_transmission_data!`](@ref prepare_transmission_data!)
"""
function parse_matpower(
    file::String;
    method::Union{String,Missing},
    add_gensub::Bool=false,
    flat_start::Bool=false,
    neglect_line_charging::Bool=false,
    neglect_transformer::Bool=false,
    zero_gen_setpoints::Bool=false,
    import_all::Bool=true)::Dict{String,Any}

    pm_data = _PM.parse_file(file; import_all=import_all)
    if !ismissing(method)
        pm_data["method"] = method
    end

    if haskey(pm_data, "gensub")
        for (i, gen) in pm_data["gensub"]
            pm_data["gen"][i]["rs"] = gen["rs"]
            pm_data["gen"][i]["xs"] = gen["xs"]
        end
        delete!(pm_data, "gensub")
    else
        # TODO verify pu values as inputs
        if haskey(pm_data, "gen") && add_gensub
            for (_, gen) in pm_data["gen"]
                gen["rs"] = 0
                gen["xs"] = 0.1
            end
        end
    end

    prepare_transmission_data!(
        pm_data;
        flat_start=flat_start,
        neglect_line_charging=neglect_line_charging,
        neglect_transformer=neglect_transformer,
        zero_gen_setpoints=zero_gen_setpoints
    )

    return pm_data
end
