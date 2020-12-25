# Supplementary Material for _Using citizen science to parse climatic and landcover influences on bird occupancy within a tropical biodiversity hotspot_

This repository contains supplementary materials for a manuscript that uses citizen science data to parse the role of climate and land cover on avian occupancy across the Western Ghats. 

The manuscript's source code can be found at https://github.com/pratikunterwegs/eBirdOccupancy

## [Readable version](https://pratikunterwegs.github.io/ebird-wghats-supplement/)

An easy to read version of this supplementary material is available in bookdown format by clicking on the heading above.

Below we describe what each script of the Supplementary material is intended to achieve.

- _01_supplement01-spp-chk-per-grid.rmd:_. We arrive at the final list of species for analysis by considering only those species that occurred in at least 5% of all checklists across 50% of the 25 x 25 km cells from where they have been reported.  

- _02_supplement02-landCover-classification-GEE.rmd:_. This script was used to classify a 2019 Sentinel composite image across the Nilgiris and the Anamalais into seven distinct land cover types. The code can also be viewed on GEE at this link here: https://code.earthengine.google.com/ec69fc4ffad32a532b25202009243d42. 

- _03_supplement03-spatialAutocorr-climate.rmd:_. Here, we tested for spatial autocorrelation among climatic predictors, which included Annual Mean Temperature and Annual Precipitation. 

- _04_supplement04-climate-vs-landcover.rmd:_. This script showcases how climatic predictors (temperature and precipitation) varied as a function of land cover across the study area. 

- _05_supplement05-obsExp-vs-time.rmd:_. Observer expertise scores were calculated for unique observers across the study area between 2013 and 2019. In this script, we plot the number of species reported as a function of CCI (Checklist Calibration Index)/measure of observer expertise. In addition, we showcase how the distribution of expertise scores varied as a function of land cover types.  

- _06_supplement06-effort-vs-spatialIndependence.rmd:_. In this script, we checked how many checklists/data would be retained given a particular value of distance to account for spatial independence. We show that over 80% of checklists are retained with a distance cutoff of 1km. 

- _07_supplement07-spThin-mult-approaches.rmd:_. In this script, a number of thinning approaches were tested to determine which method retained the highest proportion of points, while accounting for sampling effort (time and distance).  

- _08_results_occupancy_predictors.rmd:_. In this script, we plot species-specific probabilities of occupancy as a function of significant environmental predictors.  

Methods and format are derived from [Strimas-Mackey et al.](https://cornelllabofornithology.github.io/ebird-best-practices/), the supplement to [Johnston et al. (2019)](https://www.biorxiv.org/content/10.1101/574392v1).

## Attribution

Please contact the following in case of interest in the project.

[Vijay Ramesh (lead author)](https://evolecol.weebly.com/)  
PhD student, Columbia University

[Pratik Gupte (repo maintainer)](https://github.com/pratikunterwegs)  
PhD student, University of Groningen 
