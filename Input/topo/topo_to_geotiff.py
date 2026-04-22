"""
topo_to_geotiff.py
------------------
Export a GETM topo/bathymetry NetCDF file to a georeferenced GeoTIFF (EPSG:4326)
that can be opened directly in QGIS or any other GIS tool.

The GETM topo file stores bathymetry on a Cartesian projected grid but already
contains 2-D latitude/longitude arrays (lonc, latc). This script uses those
coordinate arrays to interpolate the bathymetry onto a regular lon/lat grid and
writes the result as a Float32 GeoTIFF.

Usage
-----
Run with default paths (processes topos2_dws_500m.nc in the same directory):

    python topo_to_geotiff.py

Or supply a custom input file and output path:

    python topo_to_geotiff.py --input /path/to/topo.nc --output /path/to/out.tif

Dependencies
------------
    conda install netCDF4 numpy scipy rasterio
    (all available in the getm-bfm conda environment defined in conda_env.yml)
"""

import argparse
import os

import numpy as np
from netCDF4 import Dataset
from scipy.interpolate import griddata
import rasterio
from rasterio.transform import from_bounds
from rasterio.crs import CRS


# ---------------------------------------------------------------------------
# Defaults (paths relative to this script)
# ---------------------------------------------------------------------------
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_INPUT  = os.path.join(_SCRIPT_DIR, "topos2_dws_500m.nc")
DEFAULT_OUTPUT = os.path.join(_SCRIPT_DIR, "topos2_dws_500m_georef.tif")


def topo_to_geotiff(input_nc: str, output_tif: str, resolution: float | None = None) -> None:
    """
    Read a GETM topo NetCDF file and write a georeferenced GeoTIFF.

    Parameters
    ----------
    input_nc : str
        Path to the GETM topo NetCDF file (must contain variables
        ``bathymetry``, ``lonc``, and ``latc``).
    output_tif : str
        Path for the output GeoTIFF file.
    resolution : float or None
        Target resolution in degrees for the output regular grid.  If None
        (default), the resolution is derived automatically from the spatial
        extent and the number of source grid cells.
    """
    print(f"Reading {input_nc} ...")
    with Dataset(input_nc, "r") as ds:
        bath  = ds.variables["bathymetry"][:]          # (yc, xc), masked array
        lon2d = ds.variables["lonc"][:]                # (yc, xc)
        lat2d = ds.variables["latc"][:]                # (yc, xc)
        nodata = float(ds.variables["bathymetry"].missing_value)

    # Replace masked / fill values with NaN
    if np.ma.is_masked(bath):
        bath = bath.filled(np.nan)
    bath = np.where(bath == nodata, np.nan, bath)

    # ------------------------------------------------------------------
    # Build a regular lon/lat target grid
    # ------------------------------------------------------------------
    lon_min, lon_max = float(lon2d.min()), float(lon2d.max())
    lat_min, lat_max = float(lat2d.min()), float(lat2d.max())

    if resolution is None:
        # Match the approximate source grid density
        ny, nx = bath.shape
        res_lon = (lon_max - lon_min) / nx
        res_lat = (lat_max - lat_min) / ny
        resolution = min(res_lon, res_lat)

    print(f"  lon range : {lon_min:.4f} – {lon_max:.4f}°E")
    print(f"  lat range : {lat_min:.4f} – {lat_max:.4f}°N")
    print(f"  target resolution : {resolution:.6f}°")

    out_lons = np.arange(lon_min, lon_max + resolution, resolution)
    out_lats = np.arange(lat_min, lat_max + resolution, resolution)
    grid_lon, grid_lat = np.meshgrid(out_lons, out_lats)

    # ------------------------------------------------------------------
    # Interpolate bathymetry onto the regular grid (skip NaN source cells)
    # ------------------------------------------------------------------
    print("Interpolating bathymetry to regular lon/lat grid ...")
    valid = ~np.isnan(bath)
    points  = np.column_stack([lon2d[valid].ravel(), lat2d[valid].ravel()])
    values  = bath[valid].ravel()

    grid_bath = griddata(
        points,
        values,
        (grid_lon, grid_lat),
        method="linear",
    )

    # Flip so that row 0 = north (required by GeoTIFF convention)
    grid_bath = grid_bath[::-1, :]
    out_lats_flipped = out_lats[::-1]

    out_height, out_width = grid_bath.shape
    nodata_out = -9999.0
    grid_bath = np.where(np.isnan(grid_bath), nodata_out, grid_bath)

    # ------------------------------------------------------------------
    # Write GeoTIFF (EPSG:4326, WGS84)
    # ------------------------------------------------------------------
    # Affine transform: upper-left corner → lower-right corner
    transform = from_bounds(
        lon_min, lat_min, lon_max, lat_max,
        out_width, out_height,
    )

    crs = CRS.from_epsg(4326)

    print(f"Writing {output_tif} ...")
    with rasterio.open(
        output_tif,
        "w",
        driver="GTiff",
        height=out_height,
        width=out_width,
        count=1,
        dtype="float32",
        crs=crs,
        transform=transform,
        nodata=nodata_out,
        compress="deflate",
    ) as dst:
        dst.write(grid_bath.astype("float32"), 1)
        dst.update_tags(
            long_name="bathymetry",
            units="m",
            source=os.path.basename(input_nc),
        )

    print(f"Done.  Open '{output_tif}' in QGIS as a raster layer (CRS: EPSG:4326).")


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Export a GETM topo NetCDF to a georeferenced GeoTIFF for QGIS."
    )
    parser.add_argument(
        "--input", "-i",
        default=DEFAULT_INPUT,
        help=f"Input GETM topo NetCDF file (default: {DEFAULT_INPUT})",
    )
    parser.add_argument(
        "--output", "-o",
        default=DEFAULT_OUTPUT,
        help=f"Output GeoTIFF file (default: {DEFAULT_OUTPUT})",
    )
    parser.add_argument(
        "--resolution", "-r",
        type=float,
        default=None,
        help="Output grid resolution in degrees (default: auto-derived from source grid)",
    )
    args = parser.parse_args()

    topo_to_geotiff(args.input, args.output, args.resolution)
