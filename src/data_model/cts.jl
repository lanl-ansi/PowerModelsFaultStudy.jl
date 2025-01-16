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
function add_ct(data::Dict{String,Any}, element::Union{String,SubString{String}}, id::Union{String,SubString{String}}, n_p::Number, n_s::Number; kwargs...)
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
            "turns" => [n_p, n_s],
            "element" => element
        )
        kwargs_dict = Dict(kwargs)
        new_dict = _add_dict(kwargs_dict)
        merge!(data["protection"]["C_Transformers"]["$id"], new_dict)
    else
        @info "Circuit element $element does not exist. No CT added."
    end
end
