using Test
using MulticomponentAnalysis
using Measurements

@testset "MulticomoponentAnalysis.jl" begin

    test_template = joinpath(@__DIR__, "test_templates", "testtemplate.xlsx")
    output_template = joinpath(@__DIR__, "template_results","test_template_output.xlsx")
    generatetemplate(joinpath(@__DIR__, "test_templates", "blank_template.xlsx"))

    analysis= readtemplate(test_template)

    processed_template = processtemplate(test_template, output_template)

    processed_template[1][3].calibration.transfer_factor_vector

    @test processed_template[1][3].mass_fractions[end].val ≈ 0.058257652690548965
    @test processed_template[1][3].mass_fractions[end].err ≈ 0.0030639999702493643
end