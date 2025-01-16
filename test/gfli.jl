

using PowerModelsProtection

import PowerModels
import PowerModelsDistribution

import Ipopt

using Printf

const PMD = PowerModelsDistribution

PowerModelsDistribution.silence!()

ipopt_solver = optimizer_with_attributes(Ipopt.Optimizer, "tol" => 1e-6, "print_level" => 0)

data = parse_file("../test/data/dist/gfmi_test.dss")
# Dict{Any, Int64} with 5 entries:
#   "primary"   => 1
#   "sourcebus" => 2
#   "loadbus"   => 3
#   "pv_bus"    => 4
#   "pv_bus1"   => 5

# data["solar"]["pv1"]["transformer_id"] = "tx1"
data["solar"]["pv1"]["grid_forming"] = false
data["solar"]["pv1"]["pv_model"] = 1

# data["solar"]["pv1"]["fault_model"] = Dict{String, Any}(
#     "standard" => IEEE2800,
#     "I2V2" => 2,
#     "priority" => "reactive",
#     "k" => 2,
#     "dead_band" => .1,
# )

data["solar"]["pv1"]["fault_model"] = Dict{String,Any}(
    "standard" => IEEE2800,
    "priority" => "reactive",
    "delta_ir1" => 2,
    "ir1_dead_band" => 0.1,
    "delta_ir2" => 2,
    "ir2_dead_band" => 0.1,
)



data_math = transform_admittance_data_model(data)

model = instantiate_mc_admittance_model(data_math)
y = deepcopy(model.y)
v = compute_mc_pf(y, model)

# add_pre_fault!(v, model)


# phase_resistance = .0001
# ground_resistance = .0001

# """
#     3pg- fault at load bus
# """

# Gf_3p = zeros(Real, 3, 3)
# for i in 1:3
#     for j in 1:3
#         if i != j
#             Gf_3p[i,j] = -1/phase_resistance
#         else
#             Gf_3p[i,j] = 2 * (1/phase_resistance)
#         end
#     end
# end

# bus = model.data["bus"]["3"]
# indx = (1,2)
# y = deepcopy(model.y)
# for i_indx in 1:3
#     for j_indx in 1:3
#         i = model.data["admittance_map"][(bus["bus_i"],bus["terminals"][i_indx])]
#         j = model.data["admittance_map"][(bus["bus_i"],bus["terminals"][j_indx])]
#         y[i,j] += Gf_3p[i_indx,j_indx]
#     end
# end

# v = compute_mc_pf(y, model)



# """
#     lg- fault at load bus
# """

# gp = 1 / phase_resistance
# gf = 1 / ground_resistance
# Gf_lg = zeros(Real, 1, 1)

# Gf_lg[1,1] += gf

# println("*****************************************************")

# bus = model.data["bus"]["3"]
# indx = (1,2)
# y = deepcopy(model.y)
# for i_indx in 1:1
#     for j_indx in 1:1
#         i = model.data["admittance_map"][(bus["bus_i"],bus["terminals"][i_indx])]
#         j = model.data["admittance_map"][(bus["bus_i"],bus["terminals"][j_indx])]
#         y[i,j] += Gf_lg[i_indx,j_indx]
#     end
# end

# v = compute_mc_pf(y, model)

# data = model.data
# gen = data["gen"]["1"]

# transformer = data["transformer"][gen["transformer_id"]]
# f_bus = transformer["f_bus"]
# t_bus = transformer["t_bus"]
# y = transformer["p_matrix"]
# n = size(y)[1]
# _v = zeros(Complex{Float64}, n, 1)
# for (i, j) in enumerate(transformer["f_connections"])
#     if haskey(data["admittance_map"], (f_bus, j))
#         _v[i, 1] = v[data["admittance_map"][(f_bus, j)], 1]
#         else
#              _v[i, 1] = 0.0 + 0.0im
#         end
#     end
# for (i, j) in enumerate(transformer["t_connections"])
#     if haskey(data["admittance_map"], (t_bus, j))
#         _v[i+length(transformer["t_connections"]), 1] = v[data["admittance_map"][(t_bus, j)], 1]
#     else
#         _v[i+length(transformer["t_connections"]), 1] = 0.0 + 0.0im
#     end
# end

# _i = y * _v
# i_012 = inv(PowerModelsProtection._A)*_i[1:3,1]
# v_012 = inv(PowerModelsProtection._A)*_v[1:3,1]

# @printf("inverter phase currents (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(_i[1]), angle(_i[1])*180/pi, abs(_i[2]), angle(_i[2])*180/pi,abs(_i[3]), angle(_i[3])*180/pi)
# @printf("inverter phase voltages (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(_v[1]), angle(_v[1])*180/pi, abs(_v[2]), angle(_v[2])*180/pi, abs(_v[3]), angle(_v[3])*180/pi, abs(_v[4]), angle(_v[4])*180/pi)
# @printf("inverter phase powers (0, 1, 2) = P = %f Q = %f, P = %f Q = %f, P = %f Q = %f\n", real(_v[1]*conj(_i[1])), imag(_v[1]*conj(_i[1])), real(_v[2]*conj(_i[2])), imag(_v[2]*conj(_i[2])), real(_v[3]*conj(_i[3])), imag(_v[3]*conj(_i[3])))
# @printf("inverter sequence currents (0, 1, 2) = %f @ %F, %f @ %f, %f @ %F\n", abs(i_012[1]), angle(i_012[1])*180/pi, abs(i_012[2]), angle(i_012[2])*180/pi,abs(i_012[3]), angle(i_012[3])*180/pi)
# @printf("inverter sequence voltages (0, 1, 2) = %f @ %F, %f @ %f, %f @ %F\n", abs(v_012[1]), angle(v_012[1])*180/pi, abs(v_012[2]), angle(v_012[2])*180/pi,abs(v_012[3]), angle(v_012[3])*180/pi)
# @printf("inverter sequence powers (0, 1, 2) = P = %f Q = %f, P = %f Q = %f, P = %f Q = %f\n", real(v_012[1]*conj(i_012[1])), imag(v_012[1]*conj(i_012[1])), real(v_012[2]*conj(i_012[2])), imag(v_012[2]*conj(i_012[2])), real(v_012[3]*conj(i_012[3])), imag(v_012[3]*conj(i_012[3])))

# sol = compute_mc_pf(model)

# """
#     Normal power flow
# """
# y = deepcopy(model.y)

# v = compute_mc_pf(y, model)
# data = model.data
# gen = data["gen"]["1"]
# transformer = data["transformer"][gen["transformer_id"]]
# f_bus = data["bus"]["$(transformer["f_bus"])"]
# t_bus = data["bus"]["$(transformer["t_bus"])"]
# y = transformer["p_matrix"][5:8,1:8]
# _v = zeros(Complex{Float64}, 8, 1)
# indx = 1
# for (_j, j) in enumerate(f_bus["terminals"])
#     if haskey(data["admittance_map"], (f_bus["bus_i"], j))
#         _v[indx, 1] = v[data["admittance_map"][(f_bus["bus_i"], j)], 1]
#     else
#         _v[indx, 1] = 0.0
#     end
#     global indx += 1
# end
# for (_j, j) in enumerate(t_bus["terminals"])
#     if haskey(data["admittance_map"], (t_bus["bus_i"], j))
#         _v[indx, 1] = v[data["admittance_map"][(t_bus["bus_i"], j)], 1]
#     else
#         _v[indx, 1] = 0.0
#     end
#     global indx += 1
# end
# i_abc = (transformer["p_matrix"][1:4,1:8]*_v)
# i_line = (transformer["p_matrix"][5:8,1:8]*_v)
# i_012 = inv(PowerModelsProtection._A)*i_abc[1:3]
# v_012 = inv(PowerModelsProtection._A)*_v[1:3]
# println("_____power flow____")
# @printf("inverter phase currents (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(i_abc[1]), angle(i_abc[1])*180/pi, abs(i_abc[2]), angle(i_abc[2])*180/pi,abs(i_abc[3]), angle(i_abc[3])*180/pi)
# @printf("inverter phase voltages (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(_v[1]), angle(_v[1])*180/pi, abs(_v[2]), angle(_v[2])*180/pi, abs(_v[3]), angle(_v[3])*180/pi, abs(_v[4]), angle(_v[4])*180/pi)
# @printf("inverter sequence currents (0, 1, 2) = %f @ %F, %f @ %f, %f @ %F\n", abs(i_012[1]), angle(i_012[1])*180/pi, abs(i_012[2]), angle(i_012[2])*180/pi,abs(i_012[3]), angle(i_012[3])*180/pi)
# @printf("inverter sequence voltages (0, 1, 2) = %f @ %F, %f @ %f, %f @ %F\n", abs(v_012[1]), angle(v_012[1])*180/pi, abs(v_012[2]), angle(v_012[2])*180/pi,abs(v_012[3]), angle(v_012[3])*180/pi)

# # i_012 = inv(PowerModelsProtection._A)*i_line[1:3]
# # v_012 = inv(PowerModelsProtection._A)*_v[5:7]
# # @printf("secondary side transformer phase currents (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(i_line[1]), angle(i_line[1])*180/pi, abs(i_line[2]), angle(i_line[2])*180/pi, abs(i_line[3]), angle(i_line[3])*180/pi, abs(i_line[4]), angle(i_line[4])*180/pi)
# # @printf("secondary side transformer phase voltages (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(_v[5]), angle(_v[5])*180/pi, abs(_v[6]), angle(_v[6])*180/pi, abs(_v[7]), angle(_v[7])*180/pi, abs(_v[8]), angle(_v[8])*180/pi)
# # @printf("secondary side transformer sequence currents (0, 1, 2) = %f @ %F, %f @ %f, %f @ %F\n", abs(i_012[1]), angle(i_012[1])*180/pi, abs(i_012[2]), angle(i_012[2])*180/pi,abs(i_012[3]), angle(i_012[3])*180/pi)
# # @printf("secondary side transformer sequence voltages (0, 1, 2) = %f @ %F, %f @ %f, %f @ %F\n", abs(v_012[1]), angle(v_012[1])*180/pi, abs(v_012[2]), angle(v_012[2])*180/pi,abs(v_012[3]), angle(v_012[3])*180/pi)

# # phase_resistance = .0001
# # ground_resistance = .0001


# # """
# #     ll- fault at load bus
# # """

# # gp = 1 / phase_resistance
# # gf = 1 / ground_resistance
# # Gf_ll = zeros(Real, 2, 2)

# # for i in 1:2
# #     for j in 1:2
# #         if i == j
# #             Gf_ll[i,j] = 1 / phase_resistance
# #         else
# #             Gf_ll[i,j] = -1 / phase_resistance
# #         end
# #     end
# # end

# # Gf_ll[1,1] += gf
# # Gf_ll[2,2] += gf


# # bus = model.data["bus"]["3"]
# # y = deepcopy(model.y)
# # for i_indx in 1:2
# #     for j_indx in 1:2
# #         i = model.data["admittance_map"][(bus["bus_i"],bus["terminals"][i_indx])]
# #         j = model.data["admittance_map"][(bus["bus_i"],bus["terminals"][j_indx])]
# #         y[i,j] += Gf_ll[i_indx,j_indx]
# #     end
# # end

# # v = compute_mc_pf(y, model)
# # data = model.data
# # gen = data["gen"]["1"]
# # transformer = data["transformer"][gen["transformer_id"]]
# # f_bus = data["bus"]["$(transformer["f_bus"])"]
# # t_bus = data["bus"]["$(transformer["t_bus"])"]
# # y = transformer["p_matrix"][5:8,1:8]
# # _v = zeros(Complex{Float64}, 8, 1)
# # indx = 1
# # for (_j, j) in enumerate(f_bus["terminals"])
# #     if haskey(data["admittance_map"], (f_bus["bus_i"], j))
# #         _v[indx, 1] = v[data["admittance_map"][(f_bus["bus_i"], j)], 1]
# #     else
# #         _v[indx, 1] = 0.0
# #     end
# #     global indx += 1
# # end
# # for (_j, j) in enumerate(t_bus["terminals"])
# #     if haskey(data["admittance_map"], (t_bus["bus_i"], j))
# #         _v[indx, 1] = v[data["admittance_map"][(t_bus["bus_i"], j)], 1]
# #     else
# #         _v[indx, 1] = 0.0
# #     end
# #     global indx += 1
# # end
# # i_abc = (transformer["p_matrix"][1:4,1:8]*_v)
# # i_line = (transformer["p_matrix"][5:8,1:8]*_v)
# # i_012 = inv(PowerModelsProtection._A)*i_abc[1:3]
# # v_012 = inv(PowerModelsProtection._A)*_v[1:3]
# # println("_____ll-fault____")
# # @printf("inverter phase currents (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(i_abc[1]), angle(i_abc[1])*180/pi, abs(i_abc[2]), angle(i_abc[2])*180/pi,abs(i_abc[3]), angle(i_abc[3])*180/pi)
# # @printf("inverter phase voltages (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(_v[1]), angle(_v[1])*180/pi, abs(_v[2]), angle(_v[2])*180/pi, abs(_v[3]), angle(_v[3])*180/pi, abs(_v[4]), angle(_v[4])*180/pi)
# # @printf("inverter sequence currents (0, 1, 2) = %f @ %F, %f @ %f, %f @ %F\n", abs(i_012[1]), angle(i_012[1])*180/pi, abs(i_012[2]), angle(i_012[2])*180/pi,abs(i_012[3]), angle(i_012[3])*180/pi)
# # @printf("inverter sequence voltages (0, 1, 2) = %f @ %F, %f @ %f, %f @ %F\n", abs(v_012[1]), angle(v_012[1])*180/pi, abs(v_012[2]), angle(v_012[2])*180/pi,abs(v_012[3]), angle(v_012[3])*180/pi)

# # i_012 = inv(PowerModelsProtection._A)*i_line[1:3]
# # v_012 = inv(PowerModelsProtection._A)*_v[5:7]
# # @printf("secondary side transformer phase currents (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(i_line[1]), angle(i_line[1])*180/pi, abs(i_line[2]), angle(i_line[2])*180/pi, abs(i_line[3]), angle(i_line[3])*180/pi, abs(i_line[4]), angle(i_line[4])*180/pi)
# # @printf("secondary side transformer phase voltages (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(_v[5]), angle(_v[5])*180/pi, abs(_v[6]), angle(_v[6])*180/pi, abs(_v[7]), angle(_v[7])*180/pi, abs(_v[8]), angle(_v[8])*180/pi)
# # @printf("secondary side transformer sequence currents (0, 1 ,2) = %f @ %F, %f @ %f, %f @ %F\n", abs(i_012[1]), angle(i_012[1])*180/pi, abs(i_012[2]), angle(i_012[2])*180/pi,abs(i_012[3]), angle(i_012[3])*180/pi)
# # @printf("secondary side transformer sequence voltages (0, 1, 2) = %f @ %F, %f @ %f, %f @ %F\n", abs(v_012[1]), angle(v_012[1])*180/pi, abs(v_012[2]), angle(v_012[2])*180/pi,abs(v_012[3]), angle(v_012[3])*180/pi)



# # """
# #     3pg- fault at load bus
# # """

# # Gf_3p = zeros(Real, 3, 3)
# # for i in 1:3
# #     for j in 1:3
# #         if i != j
# #             Gf_3p[i,j] = -1/phase_resistance
# #         else
# #             Gf_3p[i,j] = 2 * (1/phase_resistance)
# #         end
# #     end
# # end

# # bus = model.data["bus"]["3"]
# # indx = (1,2)
# # y = deepcopy(model.y)
# # for i_indx in 1:3
# #     for j_indx in 1:3
# #         i = model.data["admittance_map"][(bus["bus_i"],bus["terminals"][i_indx])]
# #         j = model.data["admittance_map"][(bus["bus_i"],bus["terminals"][j_indx])]
# #         y[i,j] += Gf_3p[i_indx,j_indx]
# #     end
# # end

# # v = compute_mc_pf(y, model)
# # data = model.data
# # gen = data["gen"]["1"]
# # transformer = data["transformer"][gen["transformer_id"]]
# # f_bus = data["bus"]["$(transformer["f_bus"])"]
# # t_bus = data["bus"]["$(transformer["t_bus"])"]
# # y = transformer["p_matrix"][5:8,1:8]
# # _v = zeros(Complex{Float64}, 8, 1)
# # indx = 1
# # for (_j, j) in enumerate(f_bus["terminals"])
# #     if haskey(data["admittance_map"], (f_bus["bus_i"], j))
# #         _v[indx, 1] = v[data["admittance_map"][(f_bus["bus_i"], j)], 1]
# #     else
# #         _v[indx, 1] = 0.0
# #     end
# #     global indx += 1
# # end
# # for (_j, j) in enumerate(t_bus["terminals"])
# #     if haskey(data["admittance_map"], (t_bus["bus_i"], j))
# #         _v[indx, 1] = v[data["admittance_map"][(t_bus["bus_i"], j)], 1]
# #     else
# #         _v[indx, 1] = 0.0
# #     end
# #     global indx += 1
# # end
# # i_abc = (transformer["p_matrix"][1:4,1:8]*_v)
# # i_line = (transformer["p_matrix"][5:8,1:8]*_v)
# # i_012 = inv(PowerModelsProtection._A)*i_abc[1:3]
# # v_012 = inv(PowerModelsProtection._A)*_v[1:3]
# # println("_____3pg-fault____")
# # @printf("inverter phase currents (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(i_abc[1]), angle(i_abc[1])*180/pi, abs(i_abc[2]), angle(i_abc[2])*180/pi,abs(i_abc[3]), angle(i_abc[3])*180/pi)
# # @printf("inverter phase voltages (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(_v[1]), angle(_v[1])*180/pi, abs(_v[2]), angle(_v[2])*180/pi, abs(_v[3]), angle(_v[3])*180/pi, abs(_v[4]), angle(_v[4])*180/pi)
# # @printf("inverter sequence currents (0, 1, 2) = %f @ %F, %f @ %f, %f @ %F\n", abs(i_012[1]), angle(i_012[1])*180/pi, abs(i_012[2]), angle(i_012[2])*180/pi,abs(i_012[3]), angle(i_012[3])*180/pi)
# # @printf("inverter sequence voltages (0, 1, 2) = %f @ %F, %f @ %f, %f @ %F\n", abs(v_012[1]), angle(v_012[1])*180/pi, abs(v_012[2]), angle(v_012[2])*180/pi,abs(v_012[3]), angle(v_012[3])*180/pi)

# # i_012 = inv(PowerModelsProtection._A)*i_line[1:3]
# # v_012 = inv(PowerModelsProtection._A)*_v[5:7]
# # @printf("secondary side transformer phase currents (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(i_line[1]), angle(i_line[1])*180/pi, abs(i_line[2]), angle(i_line[2])*180/pi, abs(i_line[3]), angle(i_line[3])*180/pi, abs(i_line[4]), angle(i_line[4])*180/pi)
# # @printf("secondary side transformer phase voltages (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(_v[5]), angle(_v[5])*180/pi, abs(_v[6]), angle(_v[6])*180/pi, abs(_v[7]), angle(_v[7])*180/pi, abs(_v[8]), angle(_v[8])*180/pi)
# # @printf("secondary side transformer sequence currents (0, 1 ,2) = %f @ %F, %f @ %f, %f @ %F\n", abs(i_012[1]), angle(i_012[1])*180/pi, abs(i_012[2]), angle(i_012[2])*180/pi,abs(i_012[3]), angle(i_012[3])*180/pi)
# # @printf("secondary side transformer sequence voltages (0, 1, 2) = %f @ %F, %f @ %f, %f @ %F\n", abs(v_012[1]), angle(v_012[1])*180/pi, abs(v_012[2]), angle(v_012[2])*180/pi,abs(v_012[3]), angle(v_012[3])*180/pi)



# # """
# #     lg- fault at load bus
# # """

# # gp = 1 / phase_resistance
# # gf = 1 / ground_resistance
# # Gf_lg = zeros(Real, 1, 1)

# # Gf_lg[1,1] += gf



# # bus = model.data["bus"]["3"]
# # indx = (1,2)
# # y = deepcopy(model.y)
# # for i_indx in 1:1
# #     for j_indx in 1:1
# #         i = model.data["admittance_map"][(bus["bus_i"],bus["terminals"][i_indx])]
# #         j = model.data["admittance_map"][(bus["bus_i"],bus["terminals"][j_indx])]
# #         y[i,j] += Gf_lg[i_indx,j_indx]
# #     end
# # end

# # v = compute_mc_pf(y, model)
# # data = model.data
# # gen = data["gen"]["1"]
# # transformer = data["transformer"][gen["transformer_id"]]
# # f_bus = data["bus"]["$(transformer["f_bus"])"]
# # t_bus = data["bus"]["$(transformer["t_bus"])"]
# # y = transformer["p_matrix"][5:8,1:8]
# # _v = zeros(Complex{Float64}, 8, 1)
# # indx = 1
# # for (_j, j) in enumerate(f_bus["terminals"])
# #     if haskey(data["admittance_map"], (f_bus["bus_i"], j))
# #         _v[indx, 1] = v[data["admittance_map"][(f_bus["bus_i"], j)], 1]
# #     else
# #         _v[indx, 1] = 0.0
# #     end
# #     global indx += 1
# # end
# # for (_j, j) in enumerate(t_bus["terminals"])
# #     if haskey(data["admittance_map"], (t_bus["bus_i"], j))
# #         _v[indx, 1] = v[data["admittance_map"][(t_bus["bus_i"], j)], 1]
# #     else
# #         _v[indx, 1] = 0.0
# #     end
# #     global indx += 1
# # end
# # i_abc = (transformer["p_matrix"][1:4,1:8]*_v)
# # i_line = (transformer["p_matrix"][5:8,1:8]*_v)
# # i_012 = inv(PowerModelsProtection._A)*i_abc[1:3]
# # v_012 = inv(PowerModelsProtection._A)*_v[1:3]
# # println("_____lg-fault____")
# # @printf("inverter phase currents (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(i_abc[1]), angle(i_abc[1])*180/pi, abs(i_abc[2]), angle(i_abc[2])*180/pi,abs(i_abc[3]), angle(i_abc[3])*180/pi)
# # @printf("inverter phase voltages (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(_v[1]), angle(_v[1])*180/pi, abs(_v[2]), angle(_v[2])*180/pi, abs(_v[3]), angle(_v[3])*180/pi, abs(_v[4]), angle(_v[4])*180/pi)
# # @printf("inverter sequence currents (0, 1, 2) = %f @ %F, %f @ %f, %f @ %F\n", abs(i_012[1]), angle(i_012[1])*180/pi, abs(i_012[2]), angle(i_012[2])*180/pi,abs(i_012[3]), angle(i_012[3])*180/pi)
# # @printf("inverter sequence voltages (0, 1, 2) = %f @ %F, %f @ %f, %f @ %F\n", abs(v_012[1]), angle(v_012[1])*180/pi, abs(v_012[2]), angle(v_012[2])*180/pi,abs(v_012[3]), angle(v_012[3])*180/pi)

# # i_012 = inv(PowerModelsProtection._A)*i_line[1:3]
# # v_012 = inv(PowerModelsProtection._A)*_v[5:7]
# # @printf("secondary side transformer phase currents (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(i_line[1]), angle(i_line[1])*180/pi, abs(i_line[2]), angle(i_line[2])*180/pi, abs(i_line[3]), angle(i_line[3])*180/pi, abs(i_line[4]), angle(i_line[4])*180/pi)
# # @printf("secondary side transformer phase voltages (a, b, c) = %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f, %.2f @ %.2f\n", abs(_v[5]), angle(_v[5])*180/pi, abs(_v[6]), angle(_v[6])*180/pi, abs(_v[7]), angle(_v[7])*180/pi, abs(_v[8]), angle(_v[8])*180/pi)
# # @printf("secondary side transformer sequence currents (0, 1 ,2) = %f @ %F, %f @ %f, %f @ %F\n", abs(i_012[1]), angle(i_012[1])*180/pi, abs(i_012[2]), angle(i_012[2])*180/pi,abs(i_012[3]), angle(i_012[3])*180/pi)
# # @printf("secondary side transformer sequence voltages (0, 1, 2) = %f @ %F, %f @ %f, %f @ %F\n", abs(v_012[1]), angle(v_012[1])*180/pi, abs(v_012[2]), angle(v_012[2])*180/pi,abs(v_012[3]), angle(v_012[3])*180/pi)
