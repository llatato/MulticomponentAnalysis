
struct CalibrationCurve
    component_names
    check_mass_fractions
    check_areas #vector of vectors
    transfer_factor_vector
end

struct AnalyzedSample
    calibration
    peak_areas
    mass_fractions
end

function CalibrationCurve(component_names, check_mass_fractions, check_areas)
    area_ratios = [ [areas[1]/areas[i] for i in eachindex(areas)[2:end]] for areas in check_areas ]
    
    mass_fraction_ratios = [check_mass_fractions[1]/check_mass_fractions[i] for i in eachindex(check_mass_fractions)[2:end]]
    mass_fraction_ratio_matrix = Diagonal(mass_fraction_ratios)
    
    tau_vectors = [ mass_fraction_ratio_matrix \ areas for areas in area_ratios]
    tau_avg = mean(tau_vectors)
    tau_errs = std(tau_vectors)
    tau_measurements = [tau_avg[i] ± tau_errs[i] for i in eachindex(tau_avg, tau_errs)]
    
    return CalibrationCurve(component_names, check_mass_fractions, check_areas, tau_measurements)
end

function AnalyzedSample(curve::CalibrationCurve, peak_areas)
    num_components = length(curve.component_names)
    
    # calculate area ratios and convert to measurements
    area_ratios = [ [areas[1]/areas[i] for i in eachindex(areas)[2:end]] for areas in peak_areas ]
    area_ratios_avg = mean(area_ratios)
    area_ratios_errs = std(area_ratios)
    area_ratios_measurements = [area_ratios_avg[i] ± area_ratios_errs[i] for i in eachindex(area_ratios_avg,area_ratios_errs)]
    
    # set up for A matrix
    row_1 = fill(-1,num_components)
    other_rows = [ [ i == 1 ? (curve.transfer_factor_vector[j] / area_ratios_measurements[j]) : (i == j + 1 ? (-1 ± 0) : (0 ± 0)) for i in 1:(num_components)] for j in 1:(num_components-1) ]
    all_rows = pushfirst!(other_rows,row_1)
    
    # set up A x * b matrix system of equations
    A_matrix = vcat([v' for v in all_rows]...)
    b_vec = [i == 1 ? (-1 ± 0) : (0 ± 0) for i in 1:num_components]
    mass_fractions = A_matrix \ b_vec
    return AnalyzedSample(curve, peak_areas, mass_fractions)
end

pretend_areas = [
    [100, 55, 20, 11],
    [100, 52, 22, 10],
    [100, 46, 18, 12]
]

curve = CalibrationCurve(["a","b","c","d"],[0.7,0.2,0.05,0.05], pretend_areas)
AnalyzedSample(curve, pretend_areas)