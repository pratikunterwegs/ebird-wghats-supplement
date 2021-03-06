#' ---
#' editor_options: 
#'   chunk_output_type: console
#' ---
#' 
#' # Spatial Autocorrelation of Climatic Predictors
#' 
#' ## Load libraries
#' 
## ----load_libs_supp06,message=FALSE-------------------------------------------
# load libs
library(raster)
library(gstat)
library(stars)
library(purrr)
library(tibble)
library(dplyr)
library(tidyr)
library(glue)
library(scales)
library(gdalUtils)
library(sf)

# plot libs
library(ggplot2)
library(ggthemes)
library(scico)
library(gridExtra)
library(cowplot)
library(ggspatial)

#' make custom functiont to convert matrix to df
raster_to_df <- function(inp) {

  # assert is a raster obj
  assertthat::assert_that("RasterLayer" %in% class(inp),
    msg = "input is not a raster"
  )

  coords <- coordinates(inp)
  vals <- getValues(inp)

  data <- tibble(x = coords[, 1], y = coords[, 2], value = vals)

  return(data)
}

#' 
#' ## Prepare data
#' 
## ----load_data_supp06,message=FALSE-------------------------------------------
# list landscape covariate stacks
landscape_files <- "data/spatial/landscape_resamp01km.tif"
landscape_data <- stack(landscape_files)

# get proper names
elev_names <- c("elev", "slope", "aspect")
chelsa_names <- c("bio_01", "bio_12")
names(landscape_data) <- c(elev_names, chelsa_names, "landcover")

# get chelsa rasters
chelsa <- landscape_data[[chelsa_names]]
chelsa <- purrr::map(as.list(chelsa), raster_to_df)

#' 
#' ## Calculate variograms of environmental layers
#' 
## ----make_variograms,message=FALSE--------------------------------------------
# prep variograms
vgrams <- purrr::map(chelsa, function(z) {
  z <- drop_na(z)
  vgram <- gstat::variogram(value ~ 1, loc = ~ x + y, data = z)
  return(vgram)
})

# save temp
save(vgrams, file = "data/chelsa/chelsaVariograms.rdata")

# get variogram data
vgrams <- purrr::map(vgrams, function(df) {
  df %>% select(dist, gamma)
})
vgrams <- tibble(
  variable = chelsa_names,
  data = vgrams
)

#' 
## ----load_map_data,message = FALSE--------------------------------------------
wg <- st_read("data/spatial/hillsShapefile/Nil_Ana_Pal.shp") %>%
  st_transform(32643)
bbox <- st_bbox(wg)

# Plot
library(rnaturalearth)
land <- ne_countries(
  scale = 50, type = "countries", continent = "asia",
  country = "india",
  returnclass = c("sf")
)

# crop land
land <- st_transform(land, 32643)

#' 
#' ## Visualise variograms of environmental data
#' 
## ----plot_variograms_maps,message=FALSE---------------------------------------
# make ggplot of variograms
yaxis <- c("semivariance", "")
xaxis <- c("", "distance (km)")
fig_vgrams <- purrr::pmap(list(vgrams$data, yaxis, xaxis), function(df, ya, xa) {
  ggplot(df) +
    geom_line(aes(x = dist / 1000, y = gamma), size = 0.2, col = "grey") +
    geom_point(aes(x = dist / 1000, y = gamma), col = "black") +
    scale_x_continuous(labels = comma, breaks = c(seq(0, 100, 25))) +
    scale_y_log10(labels = comma) +
    labs(x = xa, y = ya) +
    theme_few() +
    theme(
      axis.text.y = element_text(angle = 90, hjust = 0.5, size = 8),
      strip.text = element_blank()
    )
})
# fig_vgrams <- purrr::map(fig_vgrams, ggplot2::ggplotGrob)

# make ggplot of chelsa data
chelsa <- as.list(landscape_data[[chelsa_names]]) %>%
  purrr::map(stars::st_as_stars)

# colour palettes
pal <- c("bilbao", "davos")
title <- c(
  "a Annual Mean Temperature",
  "b Annual Precipitation"
)
direction <- c(1, 1)
lims <- list(
  range(values(landscape_data$bio_01), na.rm = T),
  range(values(landscape_data$bio_12), na.rm = T)
)
fig_list_chelsa <-
  purrr::pmap(
    list(chelsa, pal, title, direction, lims),
    function(df, pal, t, d, l) {
      ggplot() +
        stars::geom_stars(data = df) +
        geom_sf(data = land, fill = NA, colour = "black") +
        geom_sf(data = wg, fill = NA, colour = "black", size = 0.3) +
        scale_fill_scico(
          palette = pal, direction = d,
          label = comma, na.value = NA, limits = l
        ) +
        coord_sf(
          xlim = bbox[c("xmin", "xmax")],
          ylim = bbox[c("ymin", "ymax")]
        ) +
        ggspatial::annotation_scale(location = "tr", width_hint = 0.4, text_cex = 1) +
        theme_few() +
        theme(
          legend.position = "top",
          title = element_text(face = "bold", size = 8),
          legend.key.height = unit(0.2, "cm"),
          legend.key.width = unit(1, "cm"),
          legend.text = element_text(size = 8),
          axis.title = element_blank(),
          axis.text.y = element_text(angle = 90, hjust = 0.5),
          panel.background = element_rect(fill = "lightblue"),
          legend.title = element_blank()
        ) +
        labs(x = NULL, y = NULL, title = t)
    }
  )
# fig_list_chelsa <- purrr::map(fig_list_chelsa, ggplotGrob)

#' 
#' # Climatic raster resampling
#' 
#' ## Prepare landcover
#' 
#' To access the classified Sentinel image, please visit: https://code.earthengine.google.com/ec69fc4ffad32a532b25202009243d42
## ----resample_landcover_mult,warning=FALSE, message=FALSE---------------------
# read in landcover raster location
landcover <- "data/landUseClassification/classifiedImage-UTM.tif"
# get extent
e <- bbox(raster(landcover))

# init resolution
res_init <- res(raster(landcover))
# res to transform to 1000m
res_final <- map(c(100, 250, 500, 1e3, 2.5e3), function(x) {
  x * res_init
})

# use gdalutils gdalwarp for resampling transform
# to 1km from 10m
for (i in 1:length(res_final)) {
  this_res <- res_final[[i]]
  this_res_char <- stringr::str_pad(this_res[1], 5, pad = "0")
  gdalUtils::gdalwarp(
    srcfile = landcover,
    dstfile = as.character(glue("data/landUseClassification/lc_{this_res_char}m.tif")),
    tr = c(this_res), r = "mode", te = c(e)
  )
}

#' 
## ----read_resampled_lc,message=FALSE, warning=FALSE---------------------------
# read in resampled landcover raster files as a list
lc_files <- list.files("data/landUseClassification/", pattern = "lc", full.names = TRUE)
lc_data <- map(lc_files, raster)

#' 
#' ## Prepare spatial extent
#' 
## ----load_hills_s06,message=FALSE, warning=FALSE------------------------------
# load hills
library(sf)
hills <- st_read("data/spatial/hillsShapefile/Nil_Ana_Pal.shp")
hills <- st_transform(hills, 32643)
buffer <- st_buffer(hills, 3e4) %>%
  st_transform(4326)
bbox <- st_bbox(hills)

#' 
#' ## Prepare CHELSA rasters
#' 
#' Please download the CHELSA rasters from https://chelsa-climate.org/bioclim/ 
## ----chelsa_rasters_s06,message=FALSE, warning=FALSE--------------------------
# list chelsa files
chelsaFiles <- list.files("data/chelsa/", full.names = TRUE, pattern = "*.tif")

# gather chelsa rasters
chelsaData <- purrr::map(chelsaFiles, function(chr) {
  a <- raster(chr)
  crs(a) <- crs(buffer)
  a <- crop(a, as(buffer, "Spatial"))
  return(a)
})

# stack chelsa data
chelsaData <- raster::stack(chelsaData)
names(chelsaData) <- c("chelsa_bio10_01", "chelsa_bio10_12")

#' 
#' ## Resample prepared rasters
#' 
## ----resample_clim_rasters,message=FALSE--------------------------------------
# make resampled data
resamp_data <- map(lc_data, function(this_scale) {
  rr <- projectRaster(
    from = chelsaData, to = this_scale,
    crs = crs(this_scale), res = res(this_scale)
  )
})

# make a stars list
resamp_data <- map2(resamp_data, lc_data, function(z1, z2) {
  z2[z2 == 0] <- NA
  z2 <- append(z2, as.list(z1)) %>% map(stars::st_as_stars)
}) %>%
  flatten()

