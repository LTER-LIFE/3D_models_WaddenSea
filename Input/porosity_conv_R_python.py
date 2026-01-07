import numpy as np
import rasterio
from rasterio.warp import transform, reproject, Resampling
from netCDF4 import Dataset
import matplotlib.pyplot as plt

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------
path = r"C:\Users\qzhan\OneDrive - NIOZ\Attachments\01_LTER-LIFE\03_Model\3D_models_WaddenSea\Input\2024_11_18_Franken_SuppInfo3B_BelowMurkyWaters_Silt\\"
ncfile_path = r"C:\Users\qzhan\OneDrive - NIOZ\Attachments\01_LTER-LIFE\03_Model\3D_models_WaddenSea\Input\\"

tif_file  = "2024_11_18_Franken_SuppInfo3B_BelowMurkyWaters_Silt.tif"
topo_nc   = "topo_adjusted_dws_200m_2009.nc"
out_nc    = ncfile_path + "sediment_mud_fraction.nc"

# ------------------------------------------------------------
# 1. Load TIFF (silt) and GETM topology
# ------------------------------------------------------------
tif_path = path + tif_file
nc_path  = ncfile_path + topo_nc

src = rasterio.open(tif_path)
silt_crs = src.crs

# Read GETM grid (lonc, latc)
nc = Dataset(nc_path, "r")
lonc = nc.variables["lonc"][:]   # shape [xc, yc]
latc = nc.variables["latc"][:]
nc.close()

dim_xc, dim_yc = lonc.shape

print("TIFF CRS:", silt_crs)
print("GETM lon range:", np.nanmin(lonc), np.nanmax(lonc))
print("GETM lat range:", np.nanmin(latc), np.nanmax(latc))

# ------------------------------------------------------------
# 2. Reproject TIFF to EPSG:4326
# ------------------------------------------------------------
dst_crs = "EPSG:4326"

# Create output array for reprojected TIFF
transform_src = src.transform
profile = src.profile

# Read original data
silt_data = src.read(1)

# Build new transform & array shape via rasterio.warp
from rasterio.warp import calculate_default_transform
transform_ll, width_ll, height_ll = calculate_default_transform(
    src.crs, dst_crs, src.width, src.height, *src.bounds
)

silt_ll = np.empty((height_ll, width_ll), dtype=silt_data.dtype)

reproject(
    source=silt_data,
    destination=silt_ll,
    src_transform=transform_src,
    src_crs=src.crs,
    dst_transform=transform_ll,
    dst_crs=dst_crs,
    resampling=Resampling.nearest,
)

# ------------------------------------------------------------
# 3. Sample TIFF at GETM grid cell centers
# ------------------------------------------------------------
# Prepare flat coordinate list
xy = np.column_stack([lonc.ravel(), latc.ravel()])

# Convert lon/lat → pixel row/col
rows, cols = rasterio.transform.rowcol(transform_ll, xy[:, 0], xy[:, 1])

# Bilinear sampling handled above during reprojection
# Here we extract nearest values; could interpolate manually if needed
vals = np.full(len(rows), np.nan)
mask = (rows >= 0) & (rows < height_ll) & (cols >= 0) & (cols < width_ll)
vals[mask] = silt_ll[rows[mask], cols[mask]]

# reshape back to GETM dims
silt_arr = vals.reshape(dim_xc, dim_yc)

# ------------------------------------------------------------
# 4. Handle NA and compute porosity
# ------------------------------------------------------------
fill_na_with = -999.0

silt_arr_filled = np.where(np.isnan(silt_arr), fill_na_with, silt_arr)

# R formula: porosity = 0.387 + 0.415 * (silt_fraction/100)
porosity_arr = 0.387 + 0.415 * (silt_arr_filled / 100.0)

porosity_arr = np.where(silt_arr_filled == fill_na_with,
                        fill_na_with,
                        porosity_arr)

# ------------------------------------------------------------
# 5. Write to NetCDF
# ------------------------------------------------------------
ncnew = Dataset(out_nc, "w", format="NETCDF4")

# dimensions
ncnew.createDimension("xc", dim_xc)
ncnew.createDimension("yc", dim_yc)

# variables
lon_var = ncnew.createVariable("lonc", "f4", ("xc", "yc"), fill_value=1e20)
lat_var = ncnew.createVariable("latc", "f4", ("xc", "yc"), fill_value=1e20)
mud_var = ncnew.createVariable("mud_fraction", "f4", ("xc", "yc"), fill_value=fill_na_with)
por_var = ncnew.createVariable("porosity", "f4", ("xc", "yc"), fill_value=fill_na_with)

lon_var[:] = lonc
lat_var[:] = latc
mud_var[:] = silt_arr_filled
por_var[:] = porosity_arr

# global attributes
ncnew.type = "Sediment mud fraction file for GETM"
ncnew.gridid = "North Sea and Wadden Sea"

from datetime import datetime
ncnew.history = "Created: " + datetime.now().strftime("%Y-%m-%d %H:%M")

ncnew.close()
print("Wrote NetCDF:", out_nc)

# ------------------------------------------------------------
# 6. Optional: Plot porosity 0–1, missing in black
# ------------------------------------------------------------
plt.figure(figsize=(6,5))
plot_arr = porosity_arr.copy()
plot_arr[plot_arr < 0] = np.nan  # remove -999
plt.imshow(plot_arr, origin="lower", vmin=0, vmax=1, cmap="viridis")
plt.colorbar(label="Porosity (0–1)")
plt.title("Sediment Porosity")
plt.show()

