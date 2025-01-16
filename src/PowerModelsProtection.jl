module PowerModelsProtection
    import Pkg
    import UUIDs

    import JuMP

    import InfrastructureModels
    import PowerModels
    import PowerModelsDistribution

    const _IM = InfrastructureModels
    const _PM = PowerModels
    const _PMD = PowerModelsDistribution

    import InfrastructureModels: ismultinetwork, nw_id_default
    import PowerModelsDistribution: ENABLED, DISABLED

    import Graphs
    import SparseArrays
    const _SP = SparseArrays
    import JSON

    include("core/types.jl")
    include("core/admittance_matrix.jl")
    include("core/variable.jl")
    include("core/constraint_template.jl")
    include("core/constraint.jl")
    include("core/constraint_inverter.jl")
    include("core/data.jl")
    include("core/expression.jl")
    include("core/ref.jl")
    include("core/objective.jl")
    include("core/solution.jl")

    include("data_model/units.jl")
    include("data_model/components.jl")
    include("data_model/eng2math_pmd.jl")
    include("data_model/eng2math.jl")
    include("data_model/math2eng.jl")
    include("data_model/helper_functions.jl")
    include("data_model/operation.jl")
    include("data_model/cts.jl")
    include("data_model/fuses.jl")
    include("data_model/relays.jl")
    include("data_model/utils.jl")

    include("io/common.jl")
    include("io/dss/dss2eng.jl")
    include("io/matpower.jl")
    include("io/opendss.jl")

    include("prob/common.jl")
    include("prob/fs.jl")
    include("prob/fs_mc.jl")
    include("prob/pf_mc.jl")

    include("core/export.jl")  # must be last include to properly export functions
end
