#' ---
#' editor_options: 
#'   chunk_output_type: console
#' ---
#' 
#' # Climate in Relation to Landcover
#' 
#' This script showcases how climatic predictors vary as a function of land cover types across our study area. 
#' 
#' ## Prepare libraries
#' 
## ----prep_libs_supp04---------------------------------------------------------
# load libs
library(raster)
library(glue)
library(purrr)
library(dplyr)
library(tidyr)

# plotting options
library(ggplot2)
library(ggthemes)
library(scico)

# get ci func
ci <- function(x) {
  qnorm(0.975) * sd(x, na.rm = T) / sqrt(length(x))
}

#' 
#' ## Prepare environmental data
#' 
## ----load_rasters_supp4-------------------------------------------------------
# read landscape prepare for plotting
landscape <- stack("data/spatial/landscape_resamp01km.tif")

# get proper names
elev_names <- c("elev", "slope", "aspect")
chelsa_names <- c("bio_01", "bio_12")

names(landscape) <- as.character(glue('{c(elev_names, chelsa_names, "landcover")}'))

#' 
## ----get_data_at_lc-----------------------------------------------------------
# make duplicate stack
land_data <- landscape[[c("landcover", chelsa_names)]]

# convert to list
land_data <- as.list(land_data)

# map get values over the stack
land_data <- purrr::map(land_data, raster::getValues)
names(land_data) <- c("landcover", chelsa_names)

# conver to dataframe and round to 100m
land_data <- bind_cols(land_data)
land_data <- drop_na(land_data) %>%
  filter(landcover != 0) %>%
  pivot_longer(
    cols = contains("bio"),
    names_to = "clim_var"
  ) # %>%
# group_by(landcover, clim_var) %>%
# summarise_all(.funs = list(~mean(.), ~ci(.)))

#' 
#' ## Climatic variables over landcover
#' 
#' Figure code is hidden in versions rendered as HTML and PDF.
#' 
## ----plot_clim_lc,echo=FALSE--------------------------------------------------
# plot in facets
fig_climate_lc <- ggplot(land_data) +
  geom_jitter(aes(
    x = landcover - 0.25, y = value,
    col = factor(landcover)
  ),
  width = 0.2,
  size = 0.1, alpha = 0.1, shape = 4
  ) +
  geom_boxplot(aes(x = landcover + 0.25, y = value, group = landcover),
    width = 0.2,
    outlier.size = 0.2, alpha = 0.3, fill = NA
  ) +
  scale_colour_scico_d(begin = 0.2, end = 0.8) +
  scale_y_continuous(labels = scales::comma) +
  scale_x_continuous(breaks = c(1:7)) +
  facet_wrap(~clim_var, scales = "free_y") +
  theme_few() +
  theme(legend.position = "none") +
  labs(x = "landcover class", y = "CHELSA variable value")

# save as png
ggsave(fig_climate_lc,
  filename = "figs/fig_climate_landcover.png",
  height = 5, width = 8, device = png(), dpi = 300
)
dev.off()

#' 
#' ![CHELSA climatic variables (Annual Mean Temperature on the left and Annual Precipitation on the right) are plotted as a function of landcover type. Grey points in the background represent raw data.](figs/fig_climate_landcover.png)
