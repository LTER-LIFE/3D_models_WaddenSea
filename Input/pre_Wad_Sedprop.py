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

# =========================
# Check for spatial autocorrelation
# =========================
# Moran’s I statistic
# Measures global autocorrelation (values between -1 and 1):



# =========================

import xarray as xr
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy.interpolate import griddata

# =========================
# 1️⃣ Load topo dataset
# =========================
ds_topo = xr.open_dataset("topo_adjusted_dws_200m_2009.nc")

bathy = ds_topo["bathymetry"].values
lon2d = ds_topo["lonc"].values
lat2d = ds_topo["latc"].values

# =========================
# 2️⃣ Load porosity sample data
# =========================
mud_df = pd.read_csv("samples.csv")
mud_df = mud_df.dropna(subset=["x", "y", "percentage_mud"])  # remove missing rows

# Define empirical relationship (adjust to your data if needed)
def mud_to_porosity(pct_mud):
    return 0.38662 + 0.415 * pct_mud / 100.0

mud_df["porosity"] = mud_to_porosity(mud_df["percentage_mud"])

# =========================
# 3️⃣ Interpolate porosity to model grid
# =========================
# Points in (lon, lat)
points = np.column_stack((mud_df["x"], mud_df["y"]))
values = mud_df["porosity"]

# Linear interpolation first
porosity_grid = griddata(points, values, (lon2d, lat2d), method="linear")

# Fill NaNs (outside convex hull) with nearest neighbor
nan_mask = np.isnan(porosity_grid)
if np.any(nan_mask):
    porosity_grid[nan_mask] = griddata(
        points, values, (lon2d[nan_mask], lat2d[nan_mask]),
        method="nearest"
    )

# =========================
# 4️⃣ Mask land
# =========================
land_mask = (bathy == -10)
porosity_masked = np.where(land_mask, np.nan, porosity_grid)

# =========================
# 5️⃣ Visualization
# =========================
fig, axs = plt.subplots(1, 2, figsize=(16, 6), constrained_layout=True)

# --- (a) Measured porosity samples ---
ax = axs[0]
sc = ax.scatter(mud_df["x"], mud_df["y"],
                c=mud_df["porosity"], cmap="viridis",
                s=10, edgecolor="k", linewidth=0.2)
ax.set_title("Measured Porosity (Sample Points)")
ax.set_xlabel("Longitude")
ax.set_ylabel("Latitude")
plt.colorbar(sc, ax=ax, label="Porosity")

# --- (b) Interpolated porosity field ---
ax = axs[1]
pc = ax.pcolormesh(lon2d, lat2d, porosity_masked,
                   shading="auto", cmap="viridis")
# overlay land (black)
ax.pcolormesh(lon2d, lat2d, np.where(land_mask, 1, np.nan),
              shading="auto", cmap="gray", alpha=0.9)
ax.set_title("Interpolated Porosity (Masked by Land)")
ax.set_xlabel("Longitude")
ax.set_ylabel("Latitude")
plt.colorbar(pc, ax=ax, label="Porosity")

plt.show()

# =========================
# 6️⃣ Quick diagnostics
# =========================
print(f"Bathymetry range: {np.nanmin(bathy):.2f} to {np.nanmax(bathy):.2f} m")
print(f"Porosity (samples): {mud_df['porosity'].min():.3f} – {mud_df['porosity'].max():.3f}")
print(f"Porosity (grid): {np.nanmin(porosity_masked):.3f} – {np.nanmax(porosity_masked):.3f}")
print(f"Land cells: {np.sum(land_mask)} / {land_mask.size}")











