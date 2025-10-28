# MulticomponentAnalysis.jl

**Fast, automated quantitative analysis of n-component mixtures from analytical detector data with automatic error propagation**

## Overview

MulticomponentAnalysis.jl is a Julia package designed to streamline quantitative analysis of multicomponent mixtures in analytical chemistry. It takes raw detector data from any analytical instrument (GC, HPLC, FAAS, UV-Vis, MS, etc.) and uses Relative Response Factors (RRFs) to determine mixture composition through linear algebra.

### Key Features

- **Universal Detector Support**: Works with any analytical detector that produces peak area or height data
- **Excel Templating**: Generate templates for non-programmers; operators can use Excel without writing code
- **Automatic Error Propagation**: Integrates Measurements.jl to calculate linearly propagated uncertainties
- **n-Component Mixtures**: Handles arbitrary number of components with rigorous mathematics
- **Fast Analysis**: Complete data analysis in seconds, from raw peak areas to final mass fractions with uncertainties
- **Multiple Injections**: Leverages replicate measurements to improve precision

## Theory & Mathematics

### The Problem

In analytical chemistry, the presence of different compounds are measured by detector responses. The challenge is to convert measured detector signals (peak areas or heights) into actual mass fractions in the mixture.

### Relative Response Factors (RRFs)

The package uses **relative response factors** (τ), which are the ratio of the detector sensitivity of one component to another.

#### Calibration: Determining Relative Response Factors

Given a calibration standard with known composition:
- Known mass fractions: w₁, w₂, ..., wₙ
- Measured peak areas: A₁, A₂, ..., Aₙ

The relative response factor τᵢ relates component i to the reference component:

```
τᵢ = (w₁/wᵢ) / (A₁/Aᵢ)
```

This can be rearranged to show the physical meaning:

```
τᵢ = (w₁/A₁) / (wᵢ/Aᵢ)
```

The relative response factor is the ratio of sensitivities (w/A), showing how component i responds relative to the reference component.

**Repeat Analyses**: The package first calculates RRF and relative peak areas (e.g., A₁/Aᵢ) for each analysis run (e.g., multiple injections in chromatography). Standard deviations are then calculated for only relative responses, eliminating uncertainties associated with run-to-run variability (e.g., variations in injection volume).

#### Sample Analysis: Solving for Unknown Compositions

Once relative response factors are established from a set of runs on a calibration sample, unknown sample compositions are determined by solving a system of linear equations. This analysis inherently assumes that the composition range of each analyte across all of your calibration samples/samples is within its linear dynamic range (detector response is linear for each analyte across the entire composition range of your samples).

**Given:**
- Relative response factors: τ₂, τ₃, ..., τₙ (with uncertainties)
- Measured peak area ratios: r₂ = A₁/A₂, r₃ = A₁/A₃, ... (from multiple injections with uncertainties)

**Constraints:**
1. Mass fractions sum to 1: x₁ + x₂ + ... + xₙ = 1
2. Relative response factor relationship: xᵢ = (τᵢ/rᵢ) × x₁ for each component i

This creates the matrix equation **Ax = b**:

```
┌                          ┐ ┌  ┐   ┌   ┐
│ -1    -1    -1   ... -1  │ │x₁│   │-1 │
│ τ₂/r₂ -1     0   ...  0  │ │x₂│   │ 0 │
│ τ₃/r₃  0    -1   ...  0  │ │x₃│ = │ 0 │
│  ...                     │ │..│   │...│
│ τₙ/rₙ  0     0   ... -1   │ │xₙ│   │ 0 │
└                          ┘ └  ┘   └   ┘
```

Solving this system yields mass fractions for each component. If there are impurities in your system or your calibration standard, then mass fractions will be relative to only the components present. 

### Error Propagation

The package uses [Measurements.jl](https://github.com/JuliaPhysics/Measurements.jl) to automatically propagate uncertainties through all calculations:

1. **Calibration uncertainties**: Standard deviation of relative response factors from multiple injections
2. **Sample uncertainties**: Standard deviation of area ratios from multiple injections
3. **Combined mass fraction uncertainty**: Linear algebra operations automatically propagate error originating from sources

This provides rigorous uncertainty estimates for final mass fractions with no manual error propagation required.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/llatato/MulticomponentAnalysis")
```

Or in the Julia REPL package mode (press `]`):

```julia
pkg> add https://github.com/llatato/MulticomponentAnalysis
```

## Quick Start

### Step 1: Generate a Template

```julia
using MulticomponentAnalysis

# Generate a blank Excel template
generatetemplate(AnalyticalApparatus(), joinpath(@__DIR__, "experiment1.xlsx"))
```

This creates an Excel file with three sheets ready to fill in.

### Step 2: Fill the Template

Open the generated Excel file and fill in your data:

#### Sheet 1: "Component Information"
- Cell C2: Enter number of components (e.g., 5)
- Row starting at C5: Enter component names (e.g., "Benzene", "Toluene", etc.)

#### Sheet 2: "Check Standard"
- Row starting at C4: Enter known mass fractions for the analytes in your calibration standard (must sum to ~1.0)
- Rows starting at C6: Enter peak areas from each injection (or run) of the calibration standard
  - One row per injection
  - Generalizes to any number of injections

#### Sheet 3+: "Unknown Sample 1" (and copies for additional samples)
- Cell C2 (optional): Enter sample name
- Rows starting at C6: Enter peak areas from each injection
  - One row per injection
  - Copy this sheet for additional samples, changing name and sheet title as necessary

### Step 3: Process the Template

```julia
# Analyze and write results
results = processtemplate(
    AnalyticalApparatus(),
    "experiment1.xlsx",      # Input: filled template path
    "experiment1_results.xlsx"        # Output: results file
)
```

This performs all calculations and writes results back to Excel.
