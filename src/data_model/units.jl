"function to rebase units into pu on fault objects"
function _rebase_pu_fault!(nw::Dict{String,<:Any}, data_math::Dict{String,<:Any}, bus_vbase, line_vbase, sbase::Real, sbase_old::Real, voltage_scale_factor)
    if haskey(nw, "fault")
        for (_, fault) in nw["fault"]
            vbase = bus_vbase["$(fault["fault_bus"])"]
            z_scale = 1 / (vbase^2 / sbase * voltage_scale_factor)
            y_scale = 1 / z_scale

            _PMD._scale_props!(fault, ["g", "b"], y_scale)
        end
    end
end


"function to rebase extra fields for generator dynamics into per unit"
function _rebase_pu_gen_dynamics!(nw::Dict{String,<:Any}, data_math::Dict{String,<:Any}, bus_vbase, line_vbase, sbase::Real, sbase_old::Real, voltage_scale_factor)
    if haskey(nw, "gen")
        for (_, gen) in nw["gen"]
            vbase = bus_vbase["$(gen["gen_bus"])"]
            zbase = vbase^2 / sbase * voltage_scale_factor # sbase in kva?

            _PMD._scale_props!(gen, ["rp", "xdp", "xdpp"], zbase)
        end
    end
end


"pointers for fields to get unit transformations back to si units in solutions"
const _pmp_dimensionalize_math_extensions = Dict{String,Dict{String,Vector{String}}}(
    "branch" => Dict{String,Vector{String}}(
        "ibase" => String[
            "cf_fr", "cf_to", "cf0r_fr", "cf0i_fr", "cf1r_fr", "cf1i_fr", "cf2r_fr", "cf2i_fr", "cf0r_to", "cf0i_to", "cf1r_to", "cf1i_to", "cf2r_to", "cf2i_to",
        ]
    ),
    "switch" => Dict{String,Vector{String}}(
        "ibase" => String[
            "cf_fr", "cf_to", "cf0r_fr", "cf0i_fr", "cf1r_fr", "cf1i_fr", "cf2r_fr", "cf2i_fr", "cf0r_to", "cf0i_to", "cf1r_to", "cf1i_to", "cf2r_to", "cf2i_to",
        ]
    ),
    "bus" => Dict{String,Vector{String}}(
        "ibase" => String[
            "cfr_bus", "cfi_bus", "cf_bus", "cf0r", "cf0i", "cf0", "cf1r", "cf1i", "cf1", "cf2r", "cf2i", "cf2"
        ]
    ),
)


"helper function to convert fault object units back into si units"
function make_fault_si!(nw_sol::Dict{String,<:Any}, nw_data::Dict{String,<:Any}, solution::Dict{String,<:Any}, math_model::Dict{String,<:Any})
    if haskey(nw_sol, "fault")
        for (id, fault) in nw_sol["fault"]

            vbase = nw_data["bus"]["$(nw_data["fault"][id]["fault_bus"])"]["vbase"]
            sbase = nw_sol["settings"]["sbase"]
            ibase = sbase / vbase

            for prop in ["cfr", "cfi", "cf", "cf0r", "cf0i", "cf0", "cf1r", "cf1i", "cf1", "cf2r", "cf2i", "cf2"]
                if haskey(fault, prop)
                    fault[prop] = _PMD._apply_func_vals(fault[prop], x -> x * ibase)
                end
            end
        end
    end
end


"function to rebase extra fields for solar into per unit"
function _rebase_pu_solar!(nw::Dict{String,<:Any}, data_math::Dict{String,<:Any}, bus_vbase, line_vbase, sbase::Real, sbase_old::Real, voltage_scale_factor)
    if haskey(nw, "gen")
        for (_, gen) in nw["gen"]
            if haskey(gen, "i_max")
                vbase = bus_vbase["$(gen["gen_bus"])"]
                ibase = sbase / vbase
                _PMD._scale_props!(gen, ["i_max"], 1 / ibase)
                _PMD._scale_props!(gen, ["kva"], 1 / sbase)
                _PMD._scale_props!(gen, ["solar_max"], 1 / sbase)
            end
        end
    end
end
