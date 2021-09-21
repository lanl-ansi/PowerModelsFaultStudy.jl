""
function calculate_error_percentage(value::Float64, base::Float64)
    return abs(1-value/base)
end
