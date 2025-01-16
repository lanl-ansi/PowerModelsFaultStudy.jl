"""
Function to add fuses to circuit dictionary.

Enter circuit dictionary, protected element, name, and a curve. Max clear curve is defaulted to min melt if not provided
"""
function add_fuse(data::Dict{String,Any}, element::Union{SubString{String},String}, id::String, min_melt_curve::Union{Matrix,String,SubString{String}};
    max_clear_curve::Union{Matrix,String,SubString{String}}=min_melt_curve, phase::Vector=[1, 2, 3], kwargs...)
    # Create Dict for this fuse.
    # check if protection\fuses exists.
    # check if there is already a dict for this fuse
    if haskey(data["line"], "$element")
        if !haskey(data, "protection")
            data["protection"] = Dict{String,Any}(
                "fuses" => Dict{String,Any}(
                    "$element" => Dict{String,Any}(
                        "$id" => Dict{String,Any}(
                            "min_melt_curve" => min_melt_curve,
                            "max_clear_curve" => max_clear_curve,
                            "phase" => Dict{String,Any}()
                        )
                    )
                )
            )
        elseif !haskey(data["protection"], "fuses")
            data["protection"]["fuses"] = Dict{String,Any}(
                "$element" => Dict{String,Any}(
                    "$id" => Dict{String,Any}(
                        "min_melt_curve" => min_melt_curve,
                        "max_clear_curve" => max_clear_curve,
                        "phase" => Dict{String,Any}()
                    )
                )
            )
        elseif !haskey(data["protection"]["fuses"], "$element")
            data["protection"]["fuses"]["$element"] = Dict{String,Any}(
                "$id" => Dict{String,Any}(
                    "min_melt_curve" => min_melt_curve,
                    "max_clear_curve" => max_clear_curve,
                    "phase" => Dict{String,Any}()
                )
            )
        elseif !haskey(data["protection"]["fuses"]["$element"], "$id")
            data["protection"]["fuses"]["$element"]["$id"] = Dict{String,Any}(
                "min_melt_curve" => min_melt_curve,
                "max_clear_curve" => max_clear_curve,
                "phase" => Dict{String,Any}()
            )
        else
            @info "Fuse %s-%s redefined.", element, id
            data["protection"]["fuses"]["$element"]["$id"] = Dict{String,Any}(
                "min_melt_curve" => min_melt_curve,
                "max_clear_curve" => max_clear_curve,
                "phase" => Dict{String,Any}()
            )
        end
        conn = values(data["line"]["$element"]["f_connections"])
        for i = 1:length(phase)
            if phase[i] in conn
                data["protection"]["fuses"]["$element"]["$id"]["phase"]["$(phase[i])"] = Dict{String,Any}(
                    "state" => "closed",
                    "op_times" => "Does not operate"
                )
            else
                @info "Phase %d on %s does not exist. No fuse added", phase[i], element
            end
        end
        kwargs_dict = Dict(kwargs)
        new_dict = _add_dict(kwargs_dict)
        merge!(data["protection"]["fuses"]["$element"]["$id"], new_dict)
    else
        @info "Circuit element %s does not exist. No fuse added.", element
    end
end


"Function to add curves to circuit dictionary. Enter current values from smallest to largest, with time is the corresponding order."
function add_curve(data::Dict{String,Any}, name::String, time_vals::Vector, current_vals::Vector)
    if length(current_vals) == length(time_vals)
        curve_mat = zeros(2, length(time_vals))
        curve_mat[1, :] = current_vals
        curve_mat[2, :] = time_vals
        if !haskey(data, "protection")
            data["protection"] = Dict{String,Any}(
                "curves" => Dict{String,Any}(
                    "$name" => Dict{String,Any}(
                        "curve_mat" => curve_mat
                    )
                )
            )
        elseif !haskey(data["protection"], "curves")
            data["protection"]["curves"] = Dict{String,Any}(
                "$name" => Dict{String,Any}(
                    "curve_mat" => curve_mat
                )
            )
        elseif !haskey(data["protection"]["curves"], "$name")
            data["protection"]["curves"]["$name"] = Dict{String,Any}(
                "curve_mat" => curve_mat
            )
        else
            @info "Curve %s redefined.", name
            data["protection"]["curves"]["$name"]["curve_mat"] = curve_mat
        end
    else
        @warn "Make sure vector lengths for curve $name match"
    end
end


"Function to interpolate time values from tcc_curve"
function _interpolate_time(current_vec, time_vec, I)
    if I <= current_vec[1]
        I1, I2, T1, T2 = 0, 0, 0, 0
        time = 1000
        op = false
    elseif I > current_vec[length(current_vec)]
        I1 = current_vec[length(current_vec)-1]
        I2 = current_vec[length(current_vec)]
        T1 = time_vec[length(current_vec)-1]
        T2 = time_vec[length(current_vec)]
        (a, b) = _bisection(I1, T1, I2, T2)
        time = a / (I^b - 1)
        op = true
    else
        for i = 2:length(current_vec)
            if I <= current_vec[i]
                I2 = current_vec[i]
                I1 = current_vec[i-1]
                T2 = time_vec[i]
                T1 = time_vec[i-1]
                m = (T2 - T1) / (I2 - I1)
                time = m * (I - I1) + T1
                op = true
                break
            end
        end
    end
    return time, op
end
