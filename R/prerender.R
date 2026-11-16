# Runs before Quarto renders any page (see _quarto.yml).
#   1. Loads and validates the responses.
#   2. Saves the cleaned table for the pages to use.
#   3. Writes one profile page per person.
#   4. Writes the validation report to _reports/validation.txt.

source("R/load_data.R")
source("R/build_profiles.R")

raw <- read_responses()
res <- clean_people(raw)
people <- res$people
vocab <- load_vocab()

dir.create("_cache", showWarnings = FALSE)
saveRDS(list(people = people, mode = gsn_mode(), built = Sys.Date()),
        "_cache/people.rds")

n <- write_profiles(people, vocab$open_to)

dir.create("_reports", showWarnings = FALSE)
report_lines <- format_report(res$report, raw)
writeLines(report_lines, "_reports/validation.txt")

message("\n== Graduate Student Network build (", gsn_mode(), " mode) ==")
message(paste(report_lines, collapse = "\n"))
message(n, " profile pages written.\n")
