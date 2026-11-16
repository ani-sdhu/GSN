# Loaded at the top of every page. Gives the page the cleaned people
# table plus the shared HTML helpers. Never reads the raw responses.
source("R/config.R")
source("R/html.R")
suppressPackageStartupMessages({ library(dplyr); library(tidyr) })
.gsn <- readRDS("_cache/people.rds")
people <- .gsn$people
build_mode <- .gsn$mode
open_to_vocab <- readr::read_csv("data/vocab/open_to.csv", show_col_types = FALSE)
