module MulticomponentAnalysis

using Measurements
using XLSX
using LinearAlgebra
using Statistics

include("templatehandler.jl")
export generatetemplate
export readtemplate
export processtemplate

include("Calibration.jl")
end # module MulticomponentAnalysis
