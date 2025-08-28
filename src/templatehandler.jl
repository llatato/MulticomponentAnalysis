

module GCHelper
    ###### define templating system ######
    using XLSX
    # input fields
    const component_sheet_title = "Component Information"
    const check_standard_sheet_title = "Check Standard"
    const unknown_sheet_title = "Unknown Sample 1"

    const default_file_name = "Gas Chromatography Multicomoponent Template (rename this!).xlsx"

    const component_count, component_number, component_name, info_component_count_start = "B2", "B4", "B5", "C4"

    const check_component, check_composition, component_injection_label_start, check_component_count_start = "B2", "B4", "B6", "C2"

    const unknown_sample_name, unknown_injection_label_start, unknown_component, unknown_component_count_start = "B2", "B6", "B4", "C4"

    #data for component number and component component names

    const component_num_val, component_names_start = "C2", "C5"

    #check standard info 
    const check_mass_frac_start, check_peak_areas_start = "C4" , "C6"


    #sample field info
    const sample_name, sample_peak_areas_start = "C2", "C6"

    # Component Summary
    const sample_report_start = "B8"

    # Ratio sample_report_start
    const ratio_report_start = "B2"

    function add_component_sheet_headers(sheet)
        sheet[component_count] = "Number of Components:"; sheet[component_number] = "Component Number:"; sheet[component_name] = "Component Name:"
        sheet[info_component_count_start] = vcat(collect(1:3),"...")
    end

    function add_check_sheet_headers(sheet)
        sheet[check_component] = "Component:"; sheet[check_composition] = "Check Standard Composition (mass fractions):"; 
        
        sheet[component_injection_label_start, dim = 1] = 
        ["Check Standard Peak Areas (Injection 1 on this row):",
        "Injection 2 Peak Areas",
        "Injection 3 Peak Areas",
        "continue pattern, injections with valid peak areas are auto-detected…"
        ]

        sheet[check_component_count_start] = vcat(collect(1:3),"...")
    end

    function add_unknown_sheet_headers(sheet)
        sheet["A1"] = "copy this sheet for however many samples you want analyzed."
        sheet[unknown_sample_name] = "Sample Name:"; sheet[unknown_component] = "Component:"
        
        sheet[unknown_injection_label_start, dim = 1] = 
        ["Peak Areas (Injection 1 on this row):",
        "Injection 2 Peak Areas",
        "Injection 3 Peak Areas",
        "continue pattern, injections with valid peak areas are auto-detected…"
        ]

        sheet[unknown_component_count_start] = vcat(collect(1:3),"...")

    end
    
    function get_row(sheet, ref)
        cell = XLSX.getcell(sheet,ref)
        row = XLSX.row_number(cell)
        return row 
    end

    function get_column(sheet,ref)
        cell = XLSX.getcell(sheet,ref)
        col = XLSX.column_number(cell)
        return col
    end

    # takes in a cell reference (e.g. "B1") and a length and returns the horizontal vector of that length.
    function get_vector(sheet, ref, length)
        row = get_row(sheet, ref)
        col = get_column(sheet, ref)
        vec = sheet[row, col:(col+length-1)]
        return vec 
    end

    function column_to_letter(column_number::Int)
        s = ""
        n = column_number
        while n > 0
            n, r = divrem(n - 1, 26)
            s = string(Char(r + 'A'),s)
        end
        return s
    end

    function get_peak_areas(sheet, top_left_cell, num_components)
        peak_area_start_row = get_row(sheet,top_left_cell)
        peak_area_start_column = get_column(sheet,top_left_cell)
        peak_area_start_column_letter = column_to_letter(peak_area_start_column)
        peak_area_end_column_letter = column_to_letter(peak_area_start_column + num_components -1)
        peak_areas_table = XLSX.gettable(sheet, peak_area_start_column_letter*":"*peak_area_end_column_letter; first_row = peak_area_start_row, header = false, infer_eltypes = true).data
        peak_areas = collect.(eachrow(hcat(peak_areas_table...)))
        return peak_areas 
    end
end


function generatetemplate(filepath = GCHelper.default_file_name)
    XLSX.openxlsx(filepath, mode = "w"; enable_cache = true) do xf
        sheet = xf[1]
        XLSX.rename!(sheet, GCHelper.component_sheet_title)
        #create component sheet
        GCHelper.add_component_sheet_headers(sheet)
        #create check standard sheet
        sheet = XLSX.addsheet!(xf, GCHelper.check_standard_sheet_title)
        GCHelper.add_check_sheet_headers(sheet)
        #create unknown template sheet
        sheet = XLSX.addsheet!(xf, GCHelper.unknown_sheet_title)
        GCHelper.add_unknown_sheet_headers(sheet)

    end
end


function readtemplate(filepath)
    xf = XLSX.readxlsx(filepath)
    
    #open component sheet and get component names
    sheet = xf[GCHelper.component_sheet_title]

    num_components = sheet[GCHelper.component_num_val]
    if ismissing(num_components)
        throw(MissingException("Please specify the number of components."))
    end

    component_names = GCHelper.get_vector(sheet, GCHelper.component_names_start, num_components)

    #open check standard sheet and get mass fractions/peak areas
    sheet = xf[GCHelper.check_standard_sheet_title]
    
    check_mass_fractions = GCHelper.get_vector(sheet, GCHelper.check_mass_frac_start, num_components)
    check_peak_areas = GCHelper.get_peak_areas(sheet, GCHelper.check_peak_areas_start, num_components)
    
    calibration_curve = CalibrationCurve(component_names, check_mass_fractions, check_peak_areas)
    
    
    # handle and bundle the unknown samples

    sheetnames = XLSX.sheetnames(xf)
    skip_sheets = Set([GCHelper.component_sheet_title,GCHelper.check_standard_sheet_title])
    analyzed_samples = Vector{Tuple{Any, Any, MulticomponentAnalysis.AnalyzedSample}}()

    for sname in sheetnames 
        if sname ∈ skip_sheets
            println("Skipping $sname"*", not an analyzable sample.")
            continue
        end
        sheet = xf[sname]
        peak_areas = GCHelper.get_peak_areas(sheet, GCHelper.sample_peak_areas_start, num_components)
        analysis = AnalyzedSample(calibration_curve,peak_areas)
        
        if ismissing(sheet[GCHelper.sample_name])
            sample_name = sname 
        else
            sample_name = sheet[GCHelper.sample_name]
        end
        
        sample = (sample_name,sname, analysis)
        push!(analyzed_samples, sample)
    end

    return analyzed_samples, num_components
end


function processtemplate(template_path, results_path; overwrite = true)
    
    analyzed_samples, num_components = readtemplate(template_path)

    if template_path == results_path
        @warn("The template and results file paths were the same")
    end
    cp(template_path, results_path; force=overwrite)
    
    XLSX.openxlsx(results_path, mode = "rw") do xf
        sheet = xf[GCHelper.component_sheet_title]

        sheet[GCHelper.info_component_count_start] = vcat(collect(1:num_components))


        col = GCHelper.get_column(sheet,GCHelper.sample_report_start)
        row = GCHelper.get_row(sheet,GCHelper.sample_report_start)
        
        for sample in analyzed_samples
        name_header = "Sample Name: " * string(sample[1])
        sheet_header = "Sheet Name: " * string(sample[2])
        
        sheet[row, col] = name_header
        sheet[row + 1, col] = sheet_header
        
        sheet[row, col + 1] = Measurements.value.(sample[3].mass_fractions)
        sheet[row, col + num_components +1 ] = "Mass Fractions"

        sheet[row + 1, col + 1] = Measurements.uncertainty.(sample[3].mass_fractions)
        sheet[row + 1, col + num_components + 1] = "Mass Fraction Errors"

        row += 3
        end

        sheet = xf[GCHelper.check_standard_sheet_title]
        sheet[GCHelper.check_component_count_start] = vcat(collect(1:num_components))

        col = GCHelper.get_column(sheet,GCHelper.check_composition)
        row = GCHelper.get_row(sheet,GCHelper.check_composition) + 1

        sheet[row, col] = "Transfer Factor Vector (wrt component 1):"
        sheet[row, col + 1] = "Basis Component (N/A)"
        sheet[row, col + 2] = string.(analyzed_samples[1][3].calibration.transfer_factor_vector)

        col = GCHelper.get_column(sheet,GCHelper.ratio_report_start)
        row = GCHelper.get_row(sheet,GCHelper.ratio_report_start)
        col += num_components + 2

        for sample in analyzed_samples
            sheet = xf[string(sample[2])]
            sheet[GCHelper.unknown_component_count_start] = vcat(collect(1:num_components))
            
            
            comps = sample[3].calibration.component_names
            mass_fractions = sample[3].mass_fractions
            sname = string(sample[1])
            row = GCHelper.get_row(sheet,GCHelper.ratio_report_start)
            
            for ratiosample in analyzed_samples
                rsname = string(ratiosample[1])

                sheet[row,col] = "Component Mass Ratio Matrix"
                sheet[row + 1, col] = sname * "/" * rsname 
                sheet[row + 2, col] = permutedims(comps)
                sheet[row + 1, col + 1] = comps
                mass_fractions_comparison = ratiosample[3].mass_fractions
                ratio_matrix = mass_fractions ./ mass_fractions_comparison'
                sheet[row + 2, col + 1] = string.(ratio_matrix)
                diagonal = diag(ratio_matrix)
                diag_vals = (x -> x.val).(diagonal)
                diag_errs = (x -> x.err).(diagonal)

                sheet[row, col + num_components + 2 ] = "Matrix Diagonal"
                sheet[row+1, col + num_components + 2] = "Values"
                sheet[row+1, col + num_components + 3] = "Errors"
                sheet[row+2, col + num_components + 2 ] = permutedims(permutedims(diag_vals))
                sheet[row+2, col + num_components + 3 ] = permutedims(permutedims(diag_errs))
                row += num_components + 4
            end

        end

    end
    return analyzed_samples
end

