# PowerModelsProtection.jl Change Log

## staged

- none

## v0.6.0

- Fixed solver and removed the z-matrix to handle larger problems
- The solver was updated to be more stable with larger problems
- Started to add fault controls to inverters for positive and zero sequence currents

## v0.5.3

- Add compatibility for PowerModelsDistribution v0.15

## v0.5.2

- Add JuMP v1 to compat
- Fixed for-loops over conductors in inverter constraints
- Added support for 1-phase solar devices in inverter constraints

## v0.5.1

- Removed duplicate `add_ct` function
- Refactored to move data functions to data_model folder
- Updated support to JuMP v0.23
- Updated to minimum Julia v1.6 (LTS)

## v0.5.0

- Added support for PowerModelsDistribution 0.14
- Removed old compatibility support for JuMP < v0.22
- Removed direct MathOptInterface dependency
- Updated to add JuMP v0.22
- Updated to add InfrastructureModels v0.7
- Updated to add MOI v0.10none

## v0.4.2

- Added support for adding fuses, relays, and curves via `add_fuse`, `add_relay`, and `add_curve`, respectively
- Added sparse faults with `build_mc_sparse_fault_study`
- Added Graphs.jl as dependency

## v0.4.1

- Fixed bug in `solve_mc_fault_study`, where the function call was incorrect (`kwargs` after `,` instead of `;`)
- Fixed bug in `solution_fs!` where the variables `crsw_fr`, `cisw_fr`, etc were still being used for switches
- Fixed bug in ref where faults at disabled fault buses would still be included
- Fixed bug in ref where storage objects that were disabled would still be included
- Removed unnecessary reference to storage `kva` (`sm_ub` already captures this value)
- Updated to PowerModelsDistribution v0.13.0

## v0.4.0

- Updated to PowerModelsDistribution v0.12.0
- Added support for storage in fault study formulation

## v0.3.0

- Added support for InfrastructureModels v0.6.0, which added support for multi-infrastructure modeling
- Added support for PowerModelsDistribution v0.11.2, which added support for multi-infrastructure modeling, and removed all PowerModels dependencies
- Added support for PowerModels v0.18, which added support for multi-infrastructure modeling
- Refactored "fault" data model to be consistent across data models
- Refactored fault study solvers to separate variable creation from constraints
- Removed support for JuMP versions < v0.21
- Updated documentation, and added tutorials in `examples`, which adds Pluto and Gumbo dependencies to the documentation builds
- Refactored all functions related to Distribution data models so that the ENGINEERING data model is used by default
- Removed dependencies on Memento, JSON (this was unused in current code-base)
- Added `parse_json` for parsing outputs from e.g. `build_mc_fault_studies` saved as JSON, which contains matrices and Enums whose format needs to be corrected

## v0.2.0

- Added support for arbitrary number of conductors (PMD v0.10.0+)
- Added support for ideal switch objects (PMD v0.10.1+)
- Converted some `println` to `@debug` to make messages easier to silence

## v0.1.0

- Initial Release
