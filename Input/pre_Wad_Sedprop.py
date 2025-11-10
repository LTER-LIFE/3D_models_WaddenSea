#!/usr/bin/env python3
import os
import xarray as xr
import pandas as pd
import numpy as np
from scipy.interpolate import griddata
import matplotlib.pyplot as plt

# =========================
# 1. User settings
# =========================
topo_file = "topo_adjusted_dws_200m_2009.nc"   # your topo grid
mud_file  = "samples.csv"                     # your input data
output_file = "porosity.nc"

# =========================
# 2. Load topo grid
# =========================
ds_topo = xr.open_dataset(topo_file)
ds_topo.data_vars

# Use the cell-centered latitude and longitude
lat2d = ds_topo["latc"].values
lon2d = ds_topo["lonc"].values
bathymetry = ds_topo["bathymetry"].values  # 2D array (yc, xc)



# check data by visualization:
plt.figure(figsize=(10,6))
plt.pcolormesh(lon, lat, bathymetry, shading='auto', cmap='terrain')
plt.colorbar(label='bathymetry (m)')
plt.title('bathymetry')
plt.xlabel('Longitude')
plt.ylabel('Latitude')
plt.show()

# ===================================

import xarray as xr
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

# =========================
# 1. Load topo dataset
# =========================
ds_topo = xr.open_dataset("topo_adjusted_dws_200m_2009.nc")

bathy = ds_topo["bathymetry"].values
lon = ds_topo["lonc"].values
lat = ds_topo["latc"].values

# =========================
# 2. Create land mask
# =========================
land_mask = (bathy == -10)
masked_bathy = np.ma.masked_where(land_mask, bathy)

# =========================
# 3. Load porosity sample data
# =========================
mud_df = pd.read_csv("samples.csv")  # your data file
mud_df = mud_df.dropna(subset=["x", "y", "percentage_mud"])

# Empirical function to get porosity (adjust if needed)
def mud_to_porosity(pct_mud):
    return 0.38662 + 0.415 * pct_mud / 100.0

mud_df["porosity"] = mud_to_porosity(mud_df["percentage_mud"])

# =========================
# 4. Plot bathymetry, land, and points
# =========================
plt.figure(figsize=(10, 6))

# (a) Plot water depths
plt.pcolormesh(lon, lat, masked_bathy, shading="auto", cmap="terrain")

# (b) Add colorbar
plt.colorbar(label="Bathymetry (m)")

# (c) Overlay land mask (black)
plt.pcolormesh(lon, lat, np.where(land_mask, 1, np.nan),
               shading="auto", cmap="gray", alpha=0.9)

# (d) Overlay porosity sample points
plt.scatter(mud_df["x"], mud_df["y"],
            c=mud_df["porosity"], cmap="viridis",
            s=10, edgecolor="k", linewidth=0.2, label="Porosity samples")

# (e) Add labels and legend
plt.xlabel("Longitude")
plt.ylabel("Latitude")
plt.title("Bathymetry with Porosity Sample Points")
plt.legend(loc="upper right")
plt.tight_layout()
plt.show()

# =========================
# 5. Quick stats
# =========================
print(f"Total grid cells: {bathy.size}")
print(f"Land cells: {np.sum(land_mask)}")
print(f"Min/Max bathymetry (sea only): {np.nanmin(masked_bathy):.2f} to {np.nanmax(masked_bathy):.2f} m")
print(f"Porosity range in samples: {mud_df['porosity'].min():.2f} to {mud_df['porosity'].max():.2f}")


















