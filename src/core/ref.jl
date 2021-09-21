"Adds the fault to the model"
function ref_add_fault!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    _PM.apply_pm!(_ref_add_fault!, ref, data; apply_to_subnetworks=true)
end


"Adds the fault to the model"
function _ref_add_fault!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    ref[:fault] = Dict(x for x in get(ref, :fault, Dict{Int,Any}()) if x.second["status"] != 0)
    ref[:fault_buses] = Dict{Int,Int}(x.second["fault_bus"] => x.first for x in ref[:fault])
end


"Adds the fault to the model for multiconductor"
function ref_add_mc_fault!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    _PMD.apply_pmd!(_ref_add_mc_fault!, ref, data; apply_to_subnetworks=true)
end


"Adds the fault to the model for multiconductor"
function _ref_add_mc_fault!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    ref[:fault] = Dict(x for x in get(ref, :fault, Dict{Int,Any}()) if x.second["status"] != 0)
    ref[:fault_buses] = Dict{Int,Int}(x.second["fault_bus"] => x.first for x in ref[:fault])
end


"Calculates the power from solar based on inputs"
function ref_add_mc_solar!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    _PMD.apply_pmd!(_ref_add_mc_solar!, ref, data; apply_to_subnetworks=true)
end


"Calculates the power from solar based on inputs"
function _ref_add_mc_solar!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    ref[:solar_gfli] = Dict{Int,Any}()
    ref[:solar_gfmi] = Dict{Int,Any}()

    for (i, gen) in data["gen"]
        @debug "Adding solar refs for gen $i"

        if occursin("solar", gen["source_id"])
            if haskey(gen, "grid_forming")
                @debug "Gen $i is grid-forming inverter:"
                if gen["grid_forming"]
                    ref[:solar_gfmi][parse(Int, i)] = gen["gen_bus"]
                else
                    ref[:solar_gfli][parse(Int, i)] = gen["gen_bus"]
                end
            else
                ref[:solar_gfli][parse(Int, i)] = gen["gen_bus"]
            end
        end
    end
end


"identifies grid forming buses"
function ref_add_grid_forming_bus!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    _PMD.apply_pmd!(_ref_add_grid_forming_bus!, ref, data; apply_to_subnetworks=true)
end


"identifies grid forming buses"
function _ref_add_grid_forming_bus!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    grid_forming_buses = Set([gen["gen_bus"] for (_,gen) in ref[:gen] if get(gen, "grid_forming", false)])
    ref[:grid_forming] = Dict{Int,Bool}(i => i in grid_forming_buses for (i,_) in ref[:bus])
end


"Add solar inverters to the model"
function ref_add_mc_storage!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    _PMD.apply_pmd!(_ref_add_mc_storage!, ref, data; apply_to_subnetworks=true)
end

"Add battery energy storage to the model"
function _ref_add_mc_storage!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    ref[:storage_gfmi] = Dict{Int,Any}()

    for (i, storage) in data["storage"]
        @debug "Adding storage refs for storage $i"

        ref[:storage_gfmi][parse(Int, i)] = storage["storage_bus"]
        if !(haskey(storage, "kva"))
            storage["kva"] = storage["dss"]["kva"] / ref[:settings]["sbase"] / 100
        end
    end
end
