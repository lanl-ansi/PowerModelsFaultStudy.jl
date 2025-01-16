
"mod (becuase of three phase transformer) of PMD's helper function to map non integer conductor ids into integers"
function _map_conductor_ids!(data_math::Dict{String,<:Any})
    if all(typeof(c) <: Int for c in data_math["conductor_ids"])
        cnd_map = Dict{Any,Int}(c => c for c in data_math["conductor_ids"])
    else
        cnd_map = Dict{Any,Int}(c => idx for (idx, c) in enumerate(data_math["conductor_ids"]))
    end

    data_math["conductor_ids"] = Vector{Int}([cnd_map[c] for c in data_math["conductor_ids"]])

    # TODO make more robus with f_connections and t_connections as vectors 
    for type in ["branch", "switch", "transformer"]
        if haskey(data_math, type)
            for (_,obj) in data_math[type]
                obj["f_connections"] = Vector{Int}([cnd_map[c] for c in obj["f_connections"]])
                if haskey(obj, "sm_nom") && length(obj["sm_nom"]) > 2
                    t_connections_org = deepcopy(obj["t_connections"])
                    obj["t_connections"] = Vector{Vector{Int}}()
                    for t_connections in t_connections_org
                        push!(obj["t_connections"], Vector{Int}([cnd_map[c] for c in t_connections]))
                    end
                else
                    obj["t_connections"] = Vector{Int}([cnd_map[c] for c in obj["t_connections"]])
                end
            end
        end
    end

    for type in ["load", "shunt", "gen", "storage"]
        if haskey(data_math, type)
            for (_,obj) in data_math[type]
                obj["connections"] = Vector{Int}([cnd_map[c] for c in obj["connections"]])
            end
        end
    end

    for (_,bus) in data_math["bus"]
        bus["terminals"] = Vector{Int}([cnd_map[t] for t in bus["terminals"]])
    end
end


function _convert_sparse_matrix(m::Dict{Tuple,Complex{Float64}})
    rows = zeros(Int64, length(m))
    columns = zeros(Int64, length(m))
    values = zeros(Complex{Float64}, length(m))
    indx = 1
    for ((i,j), val) in m
        rows[indx] = i
        columns[indx] = j
        values[indx] = val
        indx += 1
    end
    return SparseArrays.sparse(rows, columns, values)
end


function _add_phases!(data)
    phases = 0
    if haskey(data, "connections")
        phases = length(f_connections)
    end
    data["phases"] = phases
end


" checks if delta-gwye transformer is connected to gen "
function check_gen_transformer(data)
    nothing
end


function calculate_currents(gen, v, data)
    transformer = data["transformer"][gen["transformer_id"]]
    f_bus = transformer["f_bus"]
    t_bus = transformer["t_bus"]
    y = transformer["p_matrix"]
    n = size(y)[1]
    _v = zeros(Complex{Float64}, n, 1)
    for (i, j) in enumerate(transformer["f_connections"])
        if haskey(data["admittance_map"], (f_bus, j)) 
            _v[i, 1] = v[data["admittance_map"][(f_bus, j)], 1]
        else
             _v[i, 1] = 0.0 + 0.0im
        end
    end
    for (i, j) in enumerate(transformer["t_connections"])
        if haskey(data["admittance_map"], (t_bus, j))
            _v[i+length(transformer["t_connections"]), 1] = v[data["admittance_map"][(t_bus, j)], 1]
        else
            _v[i+length(transformer["t_connections"]), 1] = 0.0 + 0.0im
        end
    end
    _i = y * _v 
    i_012 = inv(PowerModelsProtection._A)*_i[1:3,1] 
    v_012 = inv(PowerModelsProtection._A)*_v[1:3,1]
    return _i[1:3,1], i_012, _v[1:3,1], v_012
end


