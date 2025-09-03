module MulticomponentAnalysis

using Measurements
using XLSX
using LinearAlgebra
using Statistics


include("Calibration.jl")
include("templatehandler.jl")


export AnalyticalApparatus
export generatetemplate
export readtemplate
export processtemplate


end # module MulticomponentAnalysis
