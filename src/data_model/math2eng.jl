"helper function to transform fault solutions back into ENGINEERING from MATHEMATICAL data models"
function _map_math2eng_fault!(data_eng::Dict{String,<:Any}, data_math::Dict{String,<:Any}, map::Dict{String,<:Any})
    eng_obj = _PMD._init_unmap_eng_obj!(data_eng, "fault", map)
    math_obj = _PMD._get_math_obj(data_math, map["to"])

    merge!(eng_obj, math_obj)

    if !isempty(eng_obj)
        data_eng["fault"][map["from"]] = eng_obj
    end
end


"Helper function to convert tripped relays and blown fuses from MATHEMATICAL to ENGINEERING models"
function _map_math2eng_protection!(data_eng::Dict{String,<:Any}, data_math::Dict{String,<:Any}, map::Dict{String,<:Any})
    if split(map["to"], '.')[1] == "relay"
        eng_obj = _PMD._init_unmap_eng_obj!(data_eng, "relay", map)
        math_obj = _PMD._get_math_obj(data_math, map["to"])
        merge!(eng_obj, math_obj)
        keep_prop = ["TDS", "TS", "type", "phase", "breaker_time", "shots", "trip", "element", "element2", "state"]
        for key in keys(eng_obj)
            if !(key in keep_prop)
                delete!(eng_obj, key)
            end
        end
        if !isempty(eng_obj)
            data_eng["relay"][map["from"]] = eng_obj
        end
    end

    if split(map["to"], '.')[1] == "fuse"
        eng_obj = _PMD._init_unmap_eng_obj!(data_eng, "fuse", map)
        math_obj = _PMD._get_math_obj(data_math, map["to"])
        merge!(eng_obj, math_obj)
        keep_prop = ["phase", "min_melt_curve", "max_clear_curve"]
        for key in keys(eng_obj)
            if !(key in keep_prop)
                delete!(eng_obj, key)
            end
        end
        if !isempty(eng_obj)
            data_eng["fuse"][map["from"]] = eng_obj
        end
    end
end


"necessary function reference dict for solution transformations"
const _pmp_map_math2eng_extensions = Dict{String,Function}(
    "_map_math2eng_fault!" => _map_math2eng_fault!,
    "_map_math2eng_protection!" => _map_math2eng_protection!
)


"custom version of `transform_solution` from PowerModelsDistribution to aid in easy solution transformation"
transform_solution(
    solution_math::Dict{String,<:Any},
    data_math::Dict{String,<:Any};
    make_si_extensions::Vector{<:Function}=Function[],
    kwargs...) = _PMD.transform_solution(
    solution_math,
    data_math;
    make_si_extensions=[make_fault_si!, make_si_extensions...],
    dimensionalize_math_extensions=_pmp_dimensionalize_math_extensions,
    map_math2eng_extensions=_pmp_map_math2eng_extensions,
    kwargs...)
