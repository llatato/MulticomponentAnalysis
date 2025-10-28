module MulticomponentAnalysis
using Measurements
using XLSX
using LinearAlgebra
using Statistics

export AnalyticalApparatus
export generatetemplate
export readtemplate
export processtemplate

include("Calibration.jl")
include("templatehandler.jl")

end # module MulticomponentAnalysis
