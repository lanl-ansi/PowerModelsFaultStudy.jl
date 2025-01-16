"Function to help add keyword arguments to the circuit information dictionary."
function _add_dict(d::Dict)
    k = collect(keys(d))
    v = collect(values(d))
    new_dict = Dict{String,Any}()
    for i = 1:length(k)
        key = k[i]
        new_dict["$key"] = v[i]
    end
    return new_dict
end


"Function to get current that is flowing through the relay or fuse we are looking at. Gets the type of relay from dictionary then uses the proper
method for calculating current through relay operating coil. Outputs a vector."
function _get_current(data::Dict{String,Any}, results::Dict{String,Any}, element, id)
    if haskey(data["protection"]["relays"]["$element"], "$id")
        type = data["protection"]["relays"]["$element"]["$id"]["type"]
    else #means that this is a fuse
        type = "fuse"
    end
    if type == "overcurrent"
        relay_data = data["protection"]["relays"]["$element"]["$id"]
        if haskey(relay_data, "CT")
            ct = relay_data["CT"]
            turns = data["protection"]["C_Transformers"]["$ct"]["turns"]
            I_pi = results["solution"]["line"]["$element"]["ci_fr"]
            I_pr = results["solution"]["line"]["$element"]["cr_fr"]
            I_p = sqrt.(I_pr .^ 2 + I_pi .^ 2)
            I_s = I_p .* turns[2] ./ turns[1]
            return I_s
        else
            Ir = results["solution"]["line"]["$element"]["ci_fr"]
            Ii = results["solution"]["line"]["$element"]["ci_fr"]
            return sqrt.(Ir .^ 2 + Ii .^ 2)
        end
    elseif type == "differential"
        relay_data = data["protection"]["relays"]["$element"]["$id"]
        ct_vec = data["protection"]["relays"]["$element"]["$id"]["CTs"]
        ct_data = data["protection"]["C_Transformers"]
        if haskey(data["bus"], "$element") ## on a bus
            num_ct = length(ct_vec)
            I_s = zeros(3, num_ct)
            I_sr = zeros(3, num_ct)
            for k = 1:num_ct
                ct_id = ct_vec[k]
                turns = ct_data["$ct_id"]["turns"]
                line = ct_data["$ct_id"]["element"]
                if data["line"]["$line"]["f_bus"] == "$element"
                    I_pr = results["solution"]["line"]["$line"]["cr_fr"]
                    I_pi = results["solution"]["line"]["$line"]["ci_fr"]
                    # I_p = I_pr.^2+I_pi.^2
                    I_p = broadcast(abs, (I_pr + im .* I_pi))
                    I_r = I_p
                    I_p = I_p .* (-1)
                else
                    I_pr = results["solution"]["line"]["$line"]["cr_to"]
                    I_pi = results["solution"]["line"]["$line"]["ci_to"]
                    # I_p = I_pr.^2+I_pi.^2
                    I_p = broadcast(abs, (I_pr + im .* I_pi))
                    I_r = I_p
                end
                I_s[:, k] = I_p .* turns[2] ./ turns[1]
                I_sr[:, k] = I_r .* turns[2] ./ turns[1]
            end
            I_op = broadcast(abs, sum(I_s, dims=2))
            I_opr = 2 ./ sum(I_sr, dims=2)
            I_op = I_op .* I_opr
            return vec(I_op)
        elseif !haskey(relay_data, "element2")# length(data["protection"]["relays"]["$element"]["$id"]["element2"]) == 0 ## on a single line
            I_pr = results["solution"]["line"]["$element"]["cr_fr"]
            I_pi = results["solution"]["line"]["$element"]["ci_fr"]
            I_p1 = broadcast(abs, (I_pr + im .* I_pi))
            I_pr = results["solution"]["line"]["$element"]["cr_to"]
            I_pi = results["solution"]["line"]["$element"]["ci_to"]
            I_p2 = broadcast(abs, (I_pr + im .* I_pi))
            turns = ct_data["$(ct_vec[1])"]["turns"]
            I_op = (I_p1 - I_p2) .* turns[2] ./ turns[1]
            I_opr = 2 ./ ((I_p1 + I_p2) .* turns[2] ./ turns[1])
            return broadcast(abs, I_op .* I_opr)
        else ## between two lines
            element2 = data["protection"]["relays"]["$element"]["$id"]["element2"]
            Ipr_fr = results["solution"]["line"]["$element"]["cr_fr"]
            Ipi_fr = results["solution"]["line"]["$element"]["ci_fr"]
            Ip_fr = broadcast(abs, (Ipr_fr + im .* Ipi_fr))
            Ipr_to = results["solution"]["line"]["$element2"]["cr_to"]
            Ipi_to = results["solution"]["line"]["$element2"]["ci_to"]
            Ip_to = broadcast(abs, (Ipr_to + im .* Ipi_to))
            turns = zeros(2, 2)
            turns[:, 1] = ct_data["$(ct_vec[1])"]["turns"]
            turns[:, 2] = ct_data["$(ct_vec[2])"]["turns"]
            I_op = Ip_fr .* turns[1, 2] ./ turns[1, 1] - Ip_to .* turns[2, 2] ./ turns[2, 1]
            I_opr = 2 ./ (Ip_fr .* turns[1, 2] ./ turns[1, 1] + Ip_to .* turns[2, 2] ./ turns[2, 1])
            return broadcast(abs, I_op .* I_opr)
        end
    elseif type == "fuse"
        Ir = results["solution"]["line"]["$element"]["ci_fr"]
        Ii = results["solution"]["line"]["$element"]["ci_fr"]
        return sqrt.(Ir .^ 2 + Ii .^ 2)
    else
        element1 = element
        element2 = data["protection"]["relays"]["$element"]["$id"]["element2"]
        bus1 = data["line"]["$element1"]["f_bus"]
        bus2 = data["line"]["$element2"]["t_bus"]
        Vp1 = results["solution"]["bus"]["$bus1"]["vr"] + im * results["solution"]["bus"]["$bus1"]["vi"]
        Vp2 = results["solution"]["bus"]["$bus2"]["vr"] + im * results["solution"]["bus"]["$bus2"]["vi"]
        Ip1 = results["solution"]["line"]["$element1"]["csr_fr"] + im * results["solution"]["line"]["$element1"]["csi_fr"]
        Ip2 = results["solution"]["line"]["$element2"]["csr_fr"] + im * results["solution"]["line"]["$element2"]["csi_fr"]
        Vs1 = broadcast(angle, _p_to_s(Vp1)) .* 180 ./ pi
        Vs2 = broadcast(angle, _p_to_s(Vp2)) .* 180 ./ pi
        Is1 = broadcast(angle, _p_to_s(Ip1)) .* 180 ./ pi
        Is2 = broadcast(angle, _p_to_s(Ip2)) .* 180 ./ pi
        I_diff = (Is1 - Vs1) - (Is2 - Vs2)
        return broadcast(abs, I_diff)
    end
end


"Same as _get_current but uses mathematical model."
function _get_current_math(data::Dict{Symbol,<:Any}, results::Dict{String,Any}, element, id, pu::Vector)
    relay_data = data[:relay][id]
    type = relay_data["type"]
    if type == "overcurrent"
        vbase = data[data[:relay][id]["prot_obj"]][element]["vbase"]
        if haskey(relay_data, "CT")
            ct = data[:c_transformer][relay_data["ct_enum"]]
            turns = ct["turns"]
            cp_r = results["branch"]["$element"]["csr_fr"]
            cp_i = results["branch"]["$element"]["csi_fr"]
            I = sqrt.(cp_r .^ 2 + cp_i .^ 2) .* turns[2] ./ turns[1]
            return I .* pu[1] .* pu[2] ./ pu[3] ./ [vbase]
        else
            c_r = results["branch"]["$element"]["csr_fr"]
            c_i = results["branch"]["$element"]["csi_fr"]
            I = sqrt.(c_r .^ 2 + c_i .^ 2)
            return I .* pu[1] .* pu[2] ./ pu[3] ./ [vbase]
        end
    elseif type == "differential"
        ct_vec = relay_data["cts_enum"]
        ct_data = data[:c_transformer]
        if relay_data["prot_obj"] == :bus ## on a bus
            num_ct = length(ct_vec)
            I_s = zeros(3, num_ct)
            I_sr = zeros(3, num_ct)
            for k = 1:num_ct
                ct_id = ct_vec[k]
                turns = ct_data[ct_id]["turns"]
                line = ct_data[ct_id]["element_enum"]
                if data[:branch][line]["f_bus"] == relay_data["element_enum"]
                    I_pr = results["branch"]["$line"]["cr_fr"]
                    I_pi = results["branch"]["$line"]["ci_fr"]
                    I_p = broadcast(abs, (I_pr + im .* I_pi))
                    I_r = I_p
                    I_p = I_p .* (-1)
                else
                    I_pr = results["branch"]["$line"]["cr_to"]
                    I_pi = results["branch"]["$line"]["ci_to"]
                    # I_p = I_pr.^2+I_pi.^2
                    I_p = broadcast(abs, (I_pr + im .* I_pi))
                    I_r = I_p
                end
                I_s[:, k] = I_p .* turns[2] ./ turns[1]
                I_sr[:, k] = I_r .* turns[2] ./ turns[1]
            end
            I_op = broadcast(abs, sum(I_s, dims=2))
            I_opr = 2 ./ sum(I_sr, dims=2)
            I_op = I_op .* I_opr
            return vec(I_op)
        elseif !haskey(relay_data, "element2")# length(data["protection"]["relays"]["$element"]["$id"]["element2"]) == 0 ## on a single line
            I_pr = results["branch"]["$element"]["cr_fr"]
            I_pi = results["branch"]["$element"]["ci_fr"]
            I_p1 = broadcast(abs, (I_pr + im .* I_pi))
            I_pr = results["branch"]["$element"]["cr_to"]
            I_pi = results["branch"]["$element"]["ci_to"]
            I_p2 = broadcast(abs, (I_pr + im .* I_pi))
            turns = ct_data["$(ct_vec[1])"]["turns"]
            I_op = (I_p1 - I_p2) .* turns[2] ./ turns[1]
            I_opr = 2 ./ ((I_p1 + I_p2) .* turns[2] ./ turns[1])
            return broadcast(abs, I_op .* I_opr)
        else ## between two lines
            element2 = relay_data["element2_enum"]
            Ipr_fr = results["branch"]["$element"]["cr_fr"]
            Ipi_fr = results["branch"]["$element"]["ci_fr"]
            Ip_fr = broadcast(abs, (Ipr_fr + im .* Ipi_fr))
            Ipr_to = results["branch"]["$element2"]["cr_to"]
            Ipi_to = results["branch"]["$element2"]["ci_to"]
            Ip_to = broadcast(abs, (Ipr_to + im .* Ipi_to))
            turns = zeros(2, 2)
            turns[:, 1] = ct_data[ct_vec[1]]["turns"]
            turns[:, 2] = ct_data[ct_vec[2]]["turns"]
            I_op = Ip_fr .* turns[1, 2] ./ turns[1, 1] - Ip_to .* turns[2, 2] ./ turns[2, 1]
            I_opr = 2 ./ (Ip_fr .* turns[1, 2] ./ turns[1, 1] + Ip_to .* turns[2, 2] ./ turns[2, 1])
            return broadcast(abs, I_op .* I_opr)
        end
    else
        element1 = element
        element2 = relay_data["element2_enum"]
        bus1 = data[:branch][element1]["f_bus"]
        bus2 = data[:branch][element2]["t_bus"]
        Vp1 = results["bus"]["$bus1"]["vr"] + im * results["bus"]["$bus1"]["vi"]
        Vp2 = results["bus"]["$bus2"]["vr"] + im * results["bus"]["$bus2"]["vi"]
        Ip1 = results["branch"]["$element1"]["csr_fr"] + im * results["branch"]["$element1"]["csi_fr"]
        Ip2 = results["branch"]["$element2"]["csr_fr"] + im * results["branch"]["$element2"]["csi_fr"]
        Vs1 = broadcast(angle, _p_to_s(Vp1)) .* 180 ./ pi
        Vs2 = broadcast(angle, _p_to_s(Vp2)) .* 180 ./ pi
        Is1 = broadcast(angle, _p_to_s(Ip1)) .* 180 ./ pi
        Is2 = broadcast(angle, _p_to_s(Ip2)) .* 180 ./ pi
        I_diff = (Is1 - Vs1) - (Is2 - Vs2)
        return broadcast(abs, I_diff)
    end
end


"Function that calculates the short-inverse time of a relay for fast trips."
function _short_time(relay_data::Dict{String,Any}, I::Number)
    A = 0.14
    B = 0.02
    t::Float64 = relay_data["TDS"] * A / ((I / relay_data["TS"])^B - 1)
    op_times = t + relay_data["breaker_time"]
    return op_times
end


"Function that calculates the long-inverse time of a relay for delayed trips."
function _long_time(relay_data::Dict{String,Any}, I::Number)
    A = 120
    B = 2
    t::Float64 = relay_data["TDS"] * A / ((I / relay_data["TS"])^B - 1)
    op_times = t + relay_data["breaker_time"]
    return op_times
end


"Function that calculates short-invers operation time of relay. Uses restraint instead of tap setting."
function _differential_time(relay_data::Dict{String,Any}, I::Number)
    A = 0.14
    B = 0.02
    t::Float64 = relay_data["TDS"] * A / ((I / relay_data["restraint"])^B - 1)
    op_times = t + relay_data["breaker_time"]
    return op_times
end


"Function to apply haskey function to all elements in a vector. Used for checking if all cts are in the
circuit when adding a differential relay. Returns a Bool"
function _check_keys(data::Dict{String,Any}, id::Union{Vector{String},Vector{SubString{String}}})
    function _haskey_ct(id::Union{String,SubString{String}})
        return haskey(data["protection"]["C_Transformers"], "$id")
    end
    bool_vec = zeros(Bool, length(id), 1)
    broadcast!(_haskey_ct, bool_vec, id)
    return sum(bool_vec) == length(id)
end


"Function to convert phase values to sequence values. Takes vector of 3 phases, returns vector of 3 sequences."
function _p_to_s(p_vec::Vector)
    a = -0.5 + im * sqrt(3) / 2
    A = [1 1 1; 1 a^2 a; 1 a a^2]
    s_vec = A * p_vec
    return s_vec
end


"Function that calculated the slope setting of differential relay based on tap setting."
function _restraint(data::Dict{String,Any}, CTs::Vector, TS::Number)::Number
    N = length(CTs)
    Is_rated = zeros(N, 1)
    for i = 1:N
        Is_rated[i] = data["protection"]["C_Transformers"]["$(CTs[i])"]["turns"][2]
    end
    I_rated = sum(Is_rated, dims=1)
    return Ir = TS * 2 / (I_rated[1])
end


"Bisection solver used to help fit a curve to provided points on tcc_curves."
function _bisection(I1, t1, I2, t2)
    function equation(b, I1, t1, I2, t2)
        return log(t2 / t1 * ((I2)^b - 1) + 1) / log(I1) - b
    end
    b = 0
    upper_boundx = 10
    lower_boundx = 0.01
    upper_boundy = equation(10, I1, t1, I2, t2)
    lower_boundy = equation(0.01, I1, t1, I2, t2)
    if upper_boundy == 0
        b = upper_boundx
        window = 0
    elseif lower_boundy == 0
        b = lower_boundx
        window = 0.0
    else
        window = 10.0
    end
    while window > 0.001
        x_guess = lower_boundx + window / 2
        y_guess = equation(x_guess, I1, t1, I2, t2)
        if y_guess != 0
            if sign(y_guess) != sign(upper_boundy)
                lower_boundx = x_guess
                window = upper_boundx - lower_boundx
                lower_boundy = y_guess
            elseif sign(y_guess) != sign(lower_boundy)
                upper_boundx = x_guess
                window = upper_boundx - lower_boundx
                upper_boundy = y_guess
            else
                window = 0
            end
        else
            window = 0
        end
        b = x_guess
    end
    a = t2 * (I2^b - 1)
    return a, b
end
