#' ---
#' editor_options: 
#'   chunk_output_type: console
#' ---
#' 
#' # Selecting species of interest
#' 
#' This script shows the proportion of checklists that report a particular species across every 25km by 25km grid across the Nilgiris and the Anamalais. Using this analysis, we arrived at a final list of species for occupancy modeling.
#' 
#' We derived this list from inclusion criteria adapted from the State of India’s Birds 2020 [@viswanathan2020]. Initially, we considered all 561 species in eBird that occurred within the outlines of our study area. We then considered only those species that had a minimum of 1000 detections each between 2013 and 2019 (reducing to 303 species). Next, the study area was divided into 25 x 25 km cells following Viswanathan et al. (2020). We then kept only those species that occurred in at least 5% of all checklists across 50% of the 25 x 25 km cells from where they have been reported (reducing to 93 species). We used the above criteria to ensure as much uniform sampling of a species as possible across our study area and to reduce any erroneous associations between environmental drivers and species occupancy. Across our final list of 93 species, we analyzed a total of ~3.2 million detections (presences) between 2013 and 2019. 
#' 
#' ## Prepare libraries
#' 
## ----setup_sup_02-------------------------------------------------------------
# load libraries
library(data.table)
library(readxl)
library(magrittr)
library(stringr)
library(dplyr)
library(tidyr)
library(readr)

library(ggplot2)
library(ggthemes)
library(scico)

# round any function
round_any <- function(x, accuracy = 25000) {
  round(x / accuracy) * accuracy
}

#' 
#' ## Read species of interest
#' 
#' We initally considered all species that 
## ----soi_supplement,message=FALSE, warning=FALSE------------------------------
# add species of interest
specieslist <- read.csv("data/01_list-all-spp-byCount.csv")
speciesOfInterest <- specieslist$scientific_name

#' 
#' ## Load raw data for locations
#' 
## ----load_raw_data_supp02-----------------------------------------------------
# read in shapefile of the study area to subset by bounding box
library(sf)
wg <- st_read("data/spatial/hillsShapefile/Nil_Ana_Pal.shp")
box <- st_bbox(wg)

# read in data and subset
# To access the latest dataset, please visit: https://ebird.org/data/download and set the file path accordingly.
ebd <- fread("data/ebd_IN_relApr-2020.txt")
ebd <- ebd[between(LONGITUDE, box["xmin"], box["xmax"]) &
  between(LATITUDE, box["ymin"], box["ymax"]), ]
ebd <- ebd[year(`OBSERVATION DATE`) >= 2013, ]

# make new column names
newNames <- str_replace_all(colnames(ebd), " ", "_") %>%
  str_to_lower()
setnames(ebd, newNames)

# keep useful columns
columnsOfInterest <- c(
  "scientific_name", "observation_count", "locality",
  "locality_id", "locality_type", "latitude",
  "longitude", "observation_date", "sampling_event_identifier"
)

ebd <- ebd[, ..columnsOfInterest]

#' 
#' Add a spatial filter and assign grids of 25km x 25km. 
#' 
## ----strict_filter_supp02-----------------------------------------------------
# strict spatial filter and assign grid
locs <- ebd[, .(longitude, latitude)]

# transform to UTM and get 20km boxes
coords <- setDF(locs) %>%
  st_as_sf(coords = c("longitude", "latitude")) %>%
  `st_crs<-`(4326) %>%
  bind_cols(as.data.table(st_coordinates(.))) %>%
  st_transform(32643) %>%
  mutate(id = 1:nrow(.))

# convert wg to UTM for filter
wg <- st_transform(wg, 32643)
coords <- coords %>%
  filter(id %in% unlist(st_contains(wg, coords))) %>%
  rename(longitude = X, latitude = Y) %>%
  bind_cols(as.data.table(st_coordinates(.))) %>%
  st_drop_geometry() %>%
  as.data.table()

# remove unneeded objects
rm(locs)
gc()

coords <- coords[, .N, by = .(longitude, latitude, X, Y)]

ebd <- merge(ebd, coords, all = FALSE, by = c("longitude", "latitude"))

ebd <- ebd[(longitude %in% coords$longitude) &
  (latitude %in% coords$latitude), ]

#' 
#' ## Get proportional obs counts in 25km cells
#' 
## ----count_obs_cell-----------------------------------------------------------
# round to 25km cell in UTM coords
ebd[, `:=`(X = round_any(X), Y = round_any(Y))]

# count checklists in cell
ebd_summary <- ebd[, nchk := length(unique(sampling_event_identifier)),
  by = .(X, Y)
]

# count checklists reporting each species in cell and get proportion
ebd_summary <- ebd_summary[, .(nrep = length(unique(
  sampling_event_identifier
))),
by = .(X, Y, nchk, scientific_name)
]

ebd_summary[, p_rep := nrep / nchk]

# filter for soi
ebd_summary <- ebd_summary[scientific_name %in% speciesOfInterest, ]

# complete the dataframe for no reports
# keep no reports as NA --- allows filtering based on proportion reporting
ebd_summary <- setDF(ebd_summary) %>%
  complete(
    nesting(X, Y), scientific_name # ,
    # fill = list(p_rep = 0)
  ) %>%
  filter(!is.na(p_rep))

#' 
#' ## Which species are reported sufficiently in checklists?
#' 
## -----------------------------------------------------------------------------
# A total of 42 unique grids (of 25km by 25km) across the study area
# total number of checklists across unique grids

tot_n_chklist <- ebd_summary %>%
  distinct(X, Y, nchk)

# species-specific number of grids
spp_grids <- ebd_summary %>%
  group_by(scientific_name) %>%
  distinct(X, Y) %>%
  count(scientific_name,
    name = "n_grids"
  )

# Write the above two results
write_csv(tot_n_chklist, "data/nchk_per_grid.csv")
write_csv(spp_grids, "data/ngrids_per_spp.csv")

# left-join the datasets
ebd_summary <- left_join(ebd_summary, spp_grids, by = "scientific_name")

# check the proportion of grids across which this cut-off is met for each species
# Is it > 90% or 70%?
# For example, with a 3% cut-off, ~100 species are occurring in >50%
# of the grids they have been reported in

p_cutoff <- 0.05 # Proportion of checklists a species has been reported in
grid_proportions <- ebd_summary %>%
  group_by(scientific_name) %>%
  tally(p_rep >= p_cutoff) %>%
  mutate(prop_grids_cut = n / (spp_grids$n_grids)) %>%
  arrange(desc(prop_grids_cut))

grid_prop_cut <- filter(
  grid_proportions,
  prop_grids_cut > p_cutoff
)

# Write the results
write_csv(grid_prop_cut, "data/chk_5_percent.csv")

# Identifying the number of species that occur in potentially <5% of all lists
total_number_lists <- sum(tot_n_chklist$nchk)

spp_sum_chk <- ebd_summary %>%
  distinct(X, Y, scientific_name, nrep) %>%
  group_by(scientific_name) %>%
  mutate(sum_chk = sum(nrep)) %>%
  distinct(scientific_name, sum_chk)

# Approximately 90 to 100 species occur in >5% of all checklists
prop_all_lists <- spp_sum_chk %>%
  mutate(prop_lists = sum_chk / total_number_lists) %>%
  arrange(desc(prop_lists))

#' 
#' ## Figure: Checklist distribution
#' 
## ----load_map_plot_data-------------------------------------------------------
# add land
library(rnaturalearth)
land <- ne_countries(
  scale = 50, type = "countries", continent = "asia",
  country = "india",
  returnclass = c("sf")
)

# crop land
land <- st_transform(land, 32643)

#' 
## ----plot_obs_distributions,echo=FALSE----------------------------------------
# make plot
wg <- st_transform(wg, 32643)
bbox <- st_bbox(wg)

# get a plot of number of checklists across grids
plotNchk <-
  ggplot() +
  geom_sf(data = land, fill = "grey90", col = NA) +
  geom_tile(
    data = tot_n_chklist,
    aes(X, Y, fill = nchk), lwd = 0.5, col = "grey90"
  ) +
  geom_sf(data = wg, fill = NA, col = "black", lwd = 0.3) +
  scale_fill_scico(
    palette = "lajolla",
    direction = 1,
    trans = "log10",
    limits = c(1, 10000),
    breaks = 10^c(1:4)
  ) +
  coord_sf(xlim = bbox[c("xmin", "xmax")], ylim = bbox[c("ymin", "ymax")]) +
  theme_few() +
  theme(
    legend.position = "right",
    axis.title = element_blank(),
    axis.text.y = element_text(angle = 90),
    panel.background = element_rect(fill = "lightblue")
  ) +
  labs(fill = "number\nof\nchecklists")

# export data
ggsave(plotNchk,
  filename = "figs/fig_number_checklists_25km.png", height = 12,
  width = 7, device = png(), dpi = 300
)
dev.off()

# filter list of species
ebd_filter <- semi_join(ebd_summary, grid_prop_cut, by = "scientific_name")

plotDistributions <-
  ggplot() +
  geom_sf(data = land, fill = "grey90", col = NA) +
  geom_tile(
    data = ebd_filter,
    aes(X, Y, fill = p_rep), lwd = 0.5, col = "grey90"
  ) +
  geom_sf(data = wg, fill = NA, col = "black", lwd = 0.3) +
  scale_fill_scico(palette = "lajolla", direction = 1, label = scales::percent) +
  facet_wrap(~scientific_name, ncol = 12) +
  coord_sf(xlim = bbox[c("xmin", "xmax")], ylim = bbox[c("ymin", "ymax")]) +
  ggthemes::theme_few(
    base_family = "TT Arial",
    base_size = 8
  ) +
  theme(
    legend.position = "right",
    strip.text = element_text(face = "italic"),
    axis.title = element_blank(),
    axis.text.y = element_text(angle = 90),
    panel.background = element_rect(fill = "lightblue")
  ) +
  labs(fill = "prop.\nreporting\nchecklists")

# export data
ggsave(plotDistributions,
  filename = "figs/fig_species_distributions.png",
  height = 25, width = 25, device = png(), dpi = 300
)
dev.off()

#' 
#' ![Proportion of checklists reporting a species in each grid cell (25km side) between 2013 and 2019. Checklists were filtered to be within the boundaries of the Nilgiris and the Anamalai hills (black outline), but rounding to 25km cells may place cells outside the boundary. Deeper shades of red indicate a higher proportion of checklists reporting a species.](figs/fig_species_distributions.png)
#' 
#' ## Prepare the species list
#' 
## -----------------------------------------------------------------------------
# write the new list of species that occur in at least 5% of checklists across a minimum of 50% of the grids they have been reported in

new_sp_list <- semi_join(specieslist, grid_prop_cut, by = "scientific_name")

write_csv(new_sp_list, "data/03_list-of-species-cutoff.csv")

