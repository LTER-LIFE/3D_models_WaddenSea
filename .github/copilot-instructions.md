# AI Coding Instructions for GETM-ERSEM Wadden Sea Model

## Project Overview
This repository contains a 3D hydrodynamic-biogeochemical model setup for the Dutch Wadden Sea using:
- **GETM** (General Estuarine Transport Model) - hydrodynamics
- **ERSEM/BFM** (European Regional Seas Ecosystem Model / Benthic Fauna Model) - biogeochemistry
- **Grid**: 200m resolution 3D model (`dws_200m` - the primary simulation domain)

## Critical Architecture Patterns

### Model Configuration Structure
- **Config location**: `dws_200m/` contains all domain-specific configs and namelists
- **Key files**:
  - `dws_200m.xml` - main model run configuration (points to actual XML variant like `dws_200m.xml_Sonja`)
  - `getm.inp_example` - GETM parameter file template (1352+ lines)
  - `.nml` files - NAMELIST files for BFM biogeochemistry parameters (`Phyto.nml`, `PelBac.nml`, `Bioturbation.nml`, etc.)
  - `bio.inp` / `bio.nml` - biogeochemical model settings

### Multiple Run Variants
- Different scientists maintain variants: `dws_200m.xml_Sonja`, `dws_200m.xml_Ulf`, `dws_200m.xml_Kiki`, `dws_200m.xml_SonjaBaseRuns`
- Each variant may have different parameter sets or input data
- When modifying configs, check if multiple variants need updates

### Data Pipeline: Restart Files & Hotstart Processing
**Common workflow in `input_scripts/interp_hotstart/`**:
1. **Hotstart files** provide initial conditions from previous runs (NetCDF format, path: `/export/lv1/user/` or `/export/lv9/user/`)
2. **Layer reduction scripts** (`reduce_layers_hotstart.py`) halve vertical resolution for computational efficiency:
   - Read NETCDF4 format input
   - Aggregate/average layers along `zax` dimension
   - Special handling for `ho` and `hn` variables (sum instead of average)
   - Write NETCDF3_CLASSIC output
   - Preserve variable attributes except `_FillValue`, `assignValue`, `getValue`
3. **Preprocessing scripts** (`pre_Wad_Sedprop.py`, `porosity_conv_R_python.py`) handle sediment properties, bathymetry adjustments

### Conda Environment
- Environment: `getm-bfm` defined in `conda_env.yml` (Python 3.11)
- Key packages: `netCDF4`, `xarray`, `numpy`, `rasterio`, `scipy`
- Create with: `conda env create -f conda_env.yml`

## Python Script Conventions

### Hotstart/Preprocessing Scripts
- **File paths**: Typically use full paths (`/export/lv1/`, `/export/lv9/` on HPC systems)
- **NetCDF handling**: Use `netCDF4.Dataset`, switch format explicitly (`NETCDF4` for input, `NETCDF3_CLASSIC` for output)
- **Array operations**: Import with `from numpy import *` (legacy pattern, prefer explicit imports for new code)
- **I/O pattern**: Hard-coded paths with commented alternatives for environment variables

**Example pattern** from `reduce_layers_hotstart.py`:
```python
from netCDF4 import Dataset
infile = Dataset(infname, 'r', format='NETCDF4')
outfile = Dataset(ofname, 'w', format='NETCDF3_CLASSIC')
# Preserve attributes except system fields
for att in var.ncattrs():
    if att not in ['_FillValue', 'assignValue', 'getValue', 'typecode']:
        setattr(outvar, att, getattr(var, att))
```

### Geospatial/Rasterio Scripts
- Use `rasterio` for GeoTIFF operations, `xarray` for NetCDF complex datasets
- Coordinate projections: Handle EPSG transformations (e.g., from local CRS to EPSG:4326)
- Interpolation: `scipy.interpolate.griddata`, `pykrige.ok.OrdinaryKriging`, `esda` for spatial analysis

## Container & Compilation
- **Dockerfile** and **getm_configure.sh** in `Container/` for building model executable
- **Module environment**: Uses EasyBuild modules on HPC (`netCDF-Fortran/4.4.4-foss-2018a`, etc.)
- **Compilation flags** in `getm.sh`: Set via environment variables (`NETCDF_VERSION`, `GETM_PARALLEL=true`)

## External Dependencies & Remote Storage
- **MinIO S3 storage**: Credentials in scripts for `scruffy.lab.uvalight.net:9000` (see `reduce_layers_hotstart.py` for pattern)
- **HPC paths**: `/export/lv1/` and `/export/lv9/` directories on Laplace cluster
- **Git repository**: Track model source trees separately (`GOTMDIR`, `FABMDIR`, `BFMDIR`, `GETMDIR`)

## Key Workflows & Commands

### Running Model
- Use PBS scripts (`.pbs` files) for HPC job submission
- Execution via `run_all` scripts in `dws_200m/` with different user variants
- Parallel mode: Set `parallel = .true.` in GETM input file

### Data Processing
1. **Prepare hotstart**: Use `reduce_layers_hotstart.py` to downsample from coarser grid
2. **Adjust bathymetry**: Apply `.adjust` files (`bathymetry.adjust`, `mask.adjust`)
3. **Mix restart files**: Scripts in `input_scripts/interp_hotstart/mix_restartfiles_*` for blending fields

### Debugging
- Check `log/` directory and `.info.pid` files for runtime info
- Output configs in `output*.yaml` files control which variables are saved
- Many scripts include commented debug code - uncomment as needed

## Project-Specific Conventions
1. **Dimension names**: `zax` for vertical (layer) dimension in restart files
2. **Variable naming**: BFM variables prefixed with `Ben` (benthic) or `Pel` (pelagic)
3. **File naming**: Restart files include domain and date (e.g., `restart_201501_hydro.nc`)
4. **Variant tracking**: Multiple `.xml` files allow different scientific teams to maintain configs without conflicts

## Common Modifications
- **Change grid resolution**: Modify layer count in dimension setup → regenerate restart files
- **Update biogeochemistry**: Edit `.nml` parameter files in `dws_200m/`
- **Adjust inputs**: Modify `bdy_*.nc`, `rivers.nc`, `initial.nc` via preprocessing scripts
- **Switch run variant**: Point `dws_200m.xml` symlink or XML include to different variant file
