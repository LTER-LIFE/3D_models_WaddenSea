#!/usr/bin/env python3
import os
import xarray as xr
import pandas as pd
import numpy as np
from scipy.interpolate import griddata # for interpolation
import matplotlib.pyplot as plt

import esda, libpysal # spatial analysis libraries
from libpysal.weights import KNN # for spatial weights
from esda.moran import Moran # for spatial autocorrelation
import geopandas as gpd # project coordinates
from scipy.spatial import cKDTree # for fast neighbor search

from pykrige.ok import OrdinaryKriging # kriging interpolation
from skgstat import Variogram, OrdinaryKriging

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
    # Equation 33 in van der Molen et al., J. Sea Res 127 (2017).
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
# 6. Project coordinates to meters
# =========================

# Convert sample points to GeoDataFrame
gdf = gpd.GeoDataFrame(
    mud_df,
    geometry=gpd.points_from_xy(mud_df.x, mud_df.y),
    crs="EPSG:4326"  # lon/lat
)

# Project to UTM zone 31N (meters)
gdf_utm = gdf.to_crs("EPSG:32631")
mud_df["x_m"] = gdf_utm.geometry.x
mud_df["y_m"] = gdf_utm.geometry.y

# Project model grid
lon_flat = ds_topo["lonc"].values.flatten()
lat_flat = ds_topo["latc"].values.flatten()
grid_gdf = gpd.GeoDataFrame(geometry=gpd.points_from_xy(lon_flat, lat_flat), crs="EPSG:4326")
grid_utm = grid_gdf.to_crs("EPSG:32631")
grid_x = grid_utm.geometry.x.values.reshape(ds_topo["lonc"].shape)
grid_y = grid_utm.geometry.y.values.reshape(ds_topo["latc"].shape)

# =========================
# 7. Inverse distance weighting interpolation
# =========================

def idw_interpolation(xy_points, values, xi, yi, radius=1000, power=2):
    """
    IDW interpolation for scattered points onto grid
    xy_points: (N,2) array of sample coordinates in meters
    values: (N,) array of sample porosity
    xi, yi: 2D grid coordinates (meters)
    radius: influence radius (meters)
    power: inverse distance power
    """
    xi_flat = xi.flatten()
    yi_flat = yi.flatten()
    interp = np.full_like(xi_flat, np.nan, dtype=float)
    
    # Build KDTree for fast neighbor search
    tree = cKDTree(xy_points)
    
    for i, (xg, yg) in enumerate(zip(xi_flat, yi_flat)):
        idxs = tree.query_ball_point([xg, yg], r=radius)
        if len(idxs) > 0:
            dists = np.sqrt((xy_points[idxs,0]-xg)**2 + (xy_points[idxs,1]-yg)**2) 
            weights = 1.0 / (dists**power)
            interp[i] = np.sum(weights * values[idxs]) / np.sum(weights)
    
    return interp.reshape(xi.shape)

# Run IDW
points_xy = np.column_stack((mud_df["x_m"], mud_df["y_m"]))
values = mud_df["porosity"].values

porosity_idw = idw_interpolation(points_xy, values, grid_x, grid_y, radius=1000, power=2)

# Mask land
land_mask = ds_topo["bathymetry"].values == -10
porosity_idw_masked = np.where(land_mask, np.nan, porosity_idw)

# =========================
# Plot IDW-interpolated porosity
# =========================
plt.figure(figsize=(10,6))
plt.pcolormesh(ds_topo["lonc"], ds_topo["latc"], porosity_idw_masked,
               shading="auto", cmap="viridis")
plt.colorbar(label="Porosity")
# plt.scatter(mud_df["x"], mud_df["y"], c="k", s=10, label="Samples")
plt.xlabel("Longitude")
plt.ylabel("Latitude")
plt.title("Porosity - IDW interpolation (radius=1 km)")
plt.legend()
plt.show()


# =========================
# 7 Kriging interpolation  
# =========================
# Check for spatial autocorrelation
# Moran’s I statistic
# Measures global autocorrelation (values between -1 and 1):
coords = list(zip(mud_df.x, mud_df.y))
w = KNN.from_array(coords, k=5)
moran = Moran(mud_df.porosity, w)
print(moran.I, moran.p_sim)
# If I > 0.3 and p_sim < 0.05, there’s significant positive autocorrelation.
# print(moran.I, moran.p_sim)
# 0.8059314999249731 0.001

# =========================
# Kriging with radius-limited neighbors
# =========================
from skgstat import Variogram, OrdinaryKriging


