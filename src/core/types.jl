struct AdmittanceModel
    data::Dict{String,<:Any}
    y::Matrix{Complex{Float64}}
    v::Matrix{Complex{Float64}}
    i::Matrix{Complex{Float64}}
    delta_i_control::Matrix{Complex{Float64}}
    delta_i::Matrix{Complex{Float64}}
end

@enum ResponseCharateristic ConstantPQ ConstantZ ConstantI ConstantZIP ConstantPAtPF ConstantPV ConstantPFixedQ ConstantPXFixedQ ConstantPQCurrentLimited ConstantV ConstantVCurrentLimited 

@enum Element VoltageSourceElement CurrentSourceElement LoadElement Transformer2WElement Transformer3WElement TransformerCenterTapElement SolarElement GeneratorElement 

@enum Standard IEEE2800 KFactor




