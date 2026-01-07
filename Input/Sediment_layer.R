require(terra)
require(ggplot2)
require(tidyterra)
require(ncdf4)
library(leaflet)

path <- paste0(ncfile_path, "\\2024_11_18_Franken_SuppInfo3B_BelowMurkyWaters_Silt\\")

ncfile_path <- "C:\\Users\\qzhan\\OneDrive - NIOZ\\Attachments\\01_LTER-LIFE\\03_Model\\3D_models_WaddenSea\\Input\\"

topo_nc   <- paste0(ncfile_path, "topo_adjusted_dws_200m_2009.nc")

nc_topo <- nc_open(topo_nc)
topo_arr <- ncvar_get(nc_topo, "bathymetry")

lonc <- ncvar_get(nc_topo, "lonc")
latc <- ncvar_get(nc_topo, "latc")

# Convert GETM grid to points (x=lon, y=lat, z=bathymetry)
df <- data.frame(
  lon = as.vector(lonc),
  lat = as.vector(latc),
  bathymetry = as.vector(topo_arr)
)

# df already has lon/lat/bathymetry
# Reduce point size for performance
leaflet(df) %>%
  addTiles() %>%
  addCircleMarkers(
    lng = ~lon, lat = ~lat,
    radius = 2,
    color = ~colorNumeric("viridis", bathymetry)(bathymetry),
    stroke = FALSE, fillOpacity = 0.8,
    label = ~paste0("Bathymetry: ", round(bathymetry,2), " m")
  ) %>%
  addLegend(
    pal = colorNumeric("viridis", df$bathymetry),
    values = df$bathymetry,
    title = "Bathymetry (m)"
  )

# --- User paths (change if needed) ---
tif_file  <- "2024_11_18_Franken_SuppInfo3B_BelowMurkyWaters_Silt.tif"
topo_nc   <- "topo_adjusted_dws_200m_2009.nc"
out_nc    <- paste0(ncfile_path, "sediment_mud_fraction.nc")

# --- 1. load inputs ---
silt <- rast(paste0(path,"2024_11_18_Franken_SuppInfo3B_BelowMurkyWaters_Silt.tif"))
nc_topo <- nc_open(paste0(ncfile_path, "topo_adjusted_dws_200m_2009.nc"))
nc_Sedprop_NS <- nc_open(paste0(ncfile_path, "Ben_Sedprop.nc"))

ggplot()+
  geom_spatraster(data = silt)

bathy_nc <- rast(paste0(ncfile_path, "topo_adjusted_dws_200m_2009.nc"))
ggplot()+
  geom_spatraster(data = bathy_nc, aes(fill=bathymetry))

bathy_nc_flipped <- flip(bathy_nc, "vertical")
ggplot()+
  geom_spatraster(data = bathy_nc_flipped, aes(fill=bathymetry))

Sedprop_NS_nc <- rast(paste0(ncfile_path, "Ben_Sedprop.nc"))
ggplot()+
  geom_spatraster(data = Sedprop_NS_nc, aes(fill=Porosity))


lonc <- ncvar_get(nc, "lonc")  # [xc, yc]
latc <- ncvar_get(nc, "latc")  # [xc, yc]
dim_xc <- dim(lonc)[1]
dim_yc <- dim(lonc)[2]

nc_close(nc)

# Quick info
cat("TIFF CRS:", crs(silt), "\n")
# cat("TIFF extent (proj units):", ext(silt), "\n")
cat("GETM lon range:", range(lonc, na.rm = TRUE), "\n")
cat("GETM lat range:", range(latc, na.rm = TRUE), "\n")


# --- 2. reproject TIFF to geographic lon/lat (EPSG:4326) ---
# Only reproject once; do not use on every point.
silt_ll <- project(silt, "EPSG:4326")

# Confirm overlap: compute bounding boxes
tif_bbox <- ext(silt_ll)            # xmin,xmax,ymin,ymax in lon/lat
getm_lon_rng <- range(lonc, na.rm=TRUE)
getm_lat_rng <- range(latc, na.rm=TRUE)
tif_bbox
# cat("Reprojected TIFF bbox (lon/lat):", tif_bbox, "\n")
cat("GETM lon range:", paste(getm_lon_rng, collapse=", "), "\n")
cat("GETM lat range:", paste(getm_lat_rng, collapse=", "), "\n")

# If GETM grid is outside the TIFF bbox, many NAs will result.
# You can check overlap easily:
if ( (getm_lon_rng[1] > tif_bbox[2]) || (getm_lon_rng[2] < tif_bbox[1]) ||
     (getm_lat_rng[1] > tif_bbox[4]) || (getm_lat_rng[2] < tif_bbox[3]) ) {
  warning("GETM grid is outside TIFF extent -> resulting values will be NA. Check projections/extent.")
}

# --- 3. prepare target coordinates (cell centers) for sampling ---
# lonc, latc are arrays [xc, yc]. We'll sample at each (lonc[i,j], latc[i,j]).
xy <- cbind(as.vector(lonc), as.vector(latc))   # N x 2, order matches as.vector(lonc)

# --- 4. sample the reprojected TIFF at those coords with bilinear interpolation ---
# terra::extract supports method = "bilinear"
vals <- terra::extract(silt_ll, xy, method = "bilinear")

# terra::extract returns a vector (or data.frame). If multiple layers, it returns a data.frame
# For a single-layer raster, vals will be a vector. Ensure numeric vector:
if (is.data.frame(vals)) {
  # first column is ID when multiple points; second column the value
  # But when extract with matrix of points, terra returns a vector for single-layer.
  # Handle both.
  v <- as.numeric(vals[, ncol(vals)])   # last column is the value
} else {
  v <- as.numeric(vals)
}

# --- 5. check and reshape to [xc, yc] array ---
cat("Sampled values: total cells =", length(v), "\n")
na_count <- sum(is.na(v))
cat("NAs from sampling:", na_count, " (", round(100*na_count/length(v),2), "% )\n")

# reshape into array ordered the same as lonc/latc (which were from ncvar_get)
# ncdf4 expects arrays with dims matching definition order (xc, yc)
silt_arr <- array(v, dim = c(dim_xc, dim_yc))


# Optional: quick visual check using terra plotting (convert to SpatRaster)
# To plot with terra/ggplot you need to create a raster from the lon/lat values.
# We'll create a SpatRaster with the same number of cols/rows and assign the sampled values.
# Note: this creates a *regular* raster that is merely used for plotting (visualization), not accurate geometry.
tmp <- rast(ncols = dim_yc, nrows = dim_xc,
            xmin = min(lonc, na.rm=TRUE), xmax = max(lonc, na.rm=TRUE),
            ymin = min(latc, na.rm=TRUE), ymax = max(latc, na.rm=TRUE),
            crs = "EPSG:4326")
# terra expects values in column-major order matching cell sequence; use as.vector(t(silt_arr)) to align
values(tmp) <- as.vector(t(silt_arr))
# plot(tmp)   # uncomment to visually inspect in interactive session

# If many NAs: identify where
if (na_count > 0) {
  nas_idx <- which(is.na(v))
  # example check first few NA coordinates
  cat("Example NA coords (first 6):\n")
  print(head(xy[nas_idx, , drop = FALSE], 6))
  cat("They may lie outside TIFF bbox or over nodata in the TIFF.\n")
}

########################################
# --- 6. OPTIONAL: replace NA with sentinel or nearby fill ---
# Example: set NA -> -999.0 for NetCDF missing value
fill_na_with <- -999.0
silt_arr_filled <- silt_arr
silt_arr_filled[is.na(silt_arr_filled)] <- fill_na_with

# --- 6b. CALCULATE POROSITY  -------------------------------
# Equation:
# Porosity = 0.387 + 0.415 * (fraction of silt & clay - SPM content)
porosity_arr <- 0.387 + 0.415 * (silt_arr_filled/100)
# Ensure NA fill value
porosity_arr[is.na(porosity_arr)] <- fill_na_with   ### ADDED

# --- 7. WRITE NETCDF (including lonc/latc variables to mimic topo file) ---
# Build dimensions (use xc, yc names and lengths matching topo)
xc_dim <- ncdim_def("xc", units="m", vals = 1:dim_xc)
yc_dim <- ncdim_def("yc", units="m", vals = 1:dim_yc)

# define variables: lonc and latc (float arrays), and mud variable
lon_var <- ncvar_def("lonc", "degree_east", list(xc_dim, yc_dim), 
                     missval = 1e20, longname = "longitude at T-points", prec = "float")
lat_var <- ncvar_def("latc", "degree_north", list(xc_dim, yc_dim), 
                     missval = 1e20, longname = "latitude at T-points", prec = "float")
mud_var <- ncvar_def("mud_fraction", "percent", list(xc_dim, yc_dim),
                     missval = -999.0, longname = "sediment mud content (%)", prec = "float")

### ADDED NEW VARIABLE
por_var <- ncvar_def("porosity", "1", 
                     list(xc_dim, yc_dim), missval = -999.0,
                     longname = "sediment porosity (0–1)", prec = "float")

# create file and write
ncnew <- nc_create(out_nc, vars = list(lon_var, lat_var, mud_var, por_var))

# Put arrays. ncvar_put expects arrays matching dimension order (xc,yc)
ncvar_put(ncnew, "lonc", lonc)
ncvar_put(ncnew, "latc", latc)
ncvar_put(ncnew, "mud_fraction", silt_arr_filled)

### ADDED
ncvar_put(ncnew, "porosity", porosity_arr)

# Global attributes - mimic your topo file a bit
ncatt_put(ncnew, 0, "type", "Sediment mud fraction file for GETM")
ncatt_put(ncnew, 0, "gridid", "North Sea and Wadden Sea")
ncatt_put(ncnew, 0, "history", paste("Created:", date()))

nc_close(ncnew)
cat("Wrote NetCDF:", out_nc, "\n")

sed_nc <- rast(paste0(ncfile_path, "sediment_mud_fraction.nc"))
ggplot()+
  geom_spatraster(data = sed_nc, aes(fill=porosity)) + 
  scale_fill_viridis_c(
    limits = c(0,1)
  )

sed_nc_flipped <- flip(sed_nc, "vertical")  # or "horizontal"
ggplot() +
  geom_spatraster(data = sed_nc_flipped, aes(fill = porosity)) +
  scale_fill_viridis_c(limits = c(0, 1))




