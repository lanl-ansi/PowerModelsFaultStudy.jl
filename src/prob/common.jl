
const _a = exp(2im/3*pi) 
const _A = [1 1 1;1 _a^2 _a;1 _a _a^2]

# need for future methods T&D need to define types
function instantiate_mc_model(
    data::Dict{String,<:Any},
    model_type::Type,
    build_method::Function;
    ref_extensions::Vector{<:Function}=Function[],
    multinetwork::Bool=ismultinetwork(data),
    global_keys::Set{String}=Set{String}(),
    eng2math_extensions::Vector{<:Function}=Function[],
    eng2math_passthrough::Dict{String,<:Vector{<:String}}=Dict{String,Vector{String}}(),
    make_pu_extensions::Vector{<:Function}=Function[],
    kwargs...
    )

    if _PMD.iseng(data)
        data = transform_admittance_data_model
    end
end


function instantiate_mc_admittance_model(
    data::Dict{String,<:Any}; 
    loading::Bool=true,
    ref_extensions::Vector{<:Function}=Function[],
    multinetwork::Bool=ismultinetwork(data),
    global_keys::Set{String}=Set{String}(),
    eng2math_extensions::Vector{<:Function}=Function[],
    eng2math_passthrough::Dict{String,<:Vector{<:String}}=Dict{String,Vector{String}}(),
    make_pu_extensions::Vector{<:Function}=Function[],
    kwargs...
    )

    if data["data_model"] == _PMD.ENGINEERING
        data_math = transform_admittance_data_model(
            data; 
            eng2math_extensions = Function[],
            eng2math_passthrough=_pmp_eng2math_passthrough,
            make_pu_extensions=make_pu_extensions,
        )
    else
        data_math = data
    end

    data_math["settings"]["loading"] = loading

    y_matrix = build_mc_admittance_matrix(data_math;loading=loading)
    v = build_mc_voltage_vector(data_math)
    i = build_mc_current_vector(data_math, v)
    delta_i_control = build_mc_delta_current_control_vector(data_math, v)
    delta_i = build_mc_delta_current_vector(data_math, v)
    return AdmittanceModel(data_math, y_matrix, v, i, delta_i_control, delta_i)
end


