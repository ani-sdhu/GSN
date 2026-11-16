# Checks each approved row before it goes on the site.
#
# A row with a problem is skipped (the rest of the site still builds) and
# listed in a plain-language report, so the admin knows what to fix.
# Problems with the setup itself (a missing vocab file, a renamed column)
# stop the build instead, since they would affect everyone.
#
# Run it on its own to check the sheet before a build:
#   Rscript R/validate.R
#   Rscript R/validate.R path/to/responses.csv
# It exits with an error code if any row has a problem.

suppressPackageStartupMessages({
  library(dplyr)
  library(purrr)
  library(stringr)
})

# ---- the report ------------------------------------------------------------

new_report <- function() {
  data.frame(row = integer(0), name = character(0), kind = character(0),
             message = character(0))
}
add_problem <- function(r, row, msg, name = NA_character_) {
  rbind(r, data.frame(row = row, name = name, kind = "problem", message = msg))
}
add_note <- function(r, row, msg, name = NA_character_) {
  rbind(r, data.frame(row = row, name = name, kind = "note", message = msg))
}
merge_reports <- function(a, b) rbind(a, b)

format_report <- function(r, raw = NULL) {
  if (nrow(r) == 0) return("All approved rows passed validation.")
  if (!is.null(raw)) {
    nm <- setNames(paste(raw$first_name, raw$last_name), raw$row_number)
    r$name <- ifelse(is.na(r$name), nm[as.character(r$row)], r$name)
  }
  r <- r[order(r$kind != "problem", r$row), ]
  lines <- sprintf("%s  Row %d (%s): %s",
                   ifelse(r$kind == "problem", "SKIPPED", "note   "),
                   r$row, r$name, r$message)
  n_bad <- length(unique(r$row[r$kind == "problem"]))
  c(sprintf("%d approved row(s) were skipped. Fix them in the sheet and rebuild.",
            n_bad), "", lines)
}

# ---- the checks ------------------------------------------------------------

URL_RE   <- "^https?://[^\\s]+\\.[^\\s]+$"
EMAIL_RE <- "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"
URL_FIELDS <- c("photo_url", "website", "google_scholar", "orcid", "cv_url",
                "linkedin", "bluesky", "x")
ALUMNI_REQUIRED <- c("grad_year", "first_placement_title",
                     "first_placement_org", "sector")
ALUMNI_FIELDS <- c(ALUMNI_REQUIRED, "current_title", "current_org",
                   "current_city", "current_country")
PHD_ONLY_STATUS <- c("Candidate (ABD)", "On the job market")
TEST_STATUS <- "Faculty (test data)"

validate_rows <- function(rows, vocab, mode) {
  report <- new_report()
  bad <- integer(0)

  for (i in seq_len(nrow(rows))) {
    r <- rows[i, ]
    probs <- character(0)
    p <- function(...) probs <<- c(probs, paste0(...))
    is_test <- isTRUE(r$is_test)

    required <- c("first_name", "last_name", "email", "program", "status",
                  "subfields", "interests", "blurb")
    if (!is_test) required <- c(required, "cohort_year")
    for (f in required) if (is.na(r[[f]])) p("'", f, "' is required but empty")

    if (!is.na(r$email) && !str_detect(r$email, EMAIL_RE))
      p("email '", r$email, "' does not look like an email address")

    if (!is.na(r$program) && !r$program %in% vocab$program)
      p("program '", r$program, "' is not in data/vocab/program.csv")

    test_status_ok <- is_test && mode == "test" && identical(r$status, TEST_STATUS)
    if (!is.na(r$status) && !r$status %in% vocab$status && !test_status_ok)
      p("status '", r$status, "' is not in data/vocab/status.csv")

    if (!is.na(r$program) && !str_detect(r$program, "PhD$") &&
        r$status %in% PHD_ONLY_STATUS)
      p("status '", r$status, "' is only for PhD students, but program is '",
        r$program, "'")

    if (!is.na(r$cohort_year) &&
        !str_detect(r$cohort_year, "^(19[89]\\d|20\\d\\d)$"))
      p("cohort year '", r$cohort_year, "' should be a four-digit year")

    for (f in c("subfields", "methods", "regions")) {
      vals <- split_checkbox(r[[f]])[[1]]
      bad_vals <- setdiff(vals, vocab[[f]])
      for (b in bad_vals)
        p(str_sub(f, end = -2), " '", b, "' is not in data/vocab/", f, ".csv")
    }

    n_int <- length(split_semicolon(r$interests)[[1]])
    if (n_int > GSN$interest_max)
      p("has ", n_int, " interest tags; the limit is ", GSN$interest_max)

    if (!is.na(r$blurb) && nchar(r$blurb) > GSN$blurb_max)
      p("research description is ", nchar(r$blurb),
        " characters; the limit is ", GSN$blurb_max)

    for (f in URL_FIELDS) {
      v <- r[[f]]
      if (!is.na(v) && !str_detect(v, URL_RE))
        p(f, " '", v, "' is not a full link (it should start with https://)")
    }
    for (w in split_lines(r$selected_work)[[1]]) {
      parts <- str_trim(str_split_fixed(w, "\\|", 2))
      if (nzchar(parts[2]) && !str_detect(parts[2], URL_RE))
        p("selected work link '", parts[2], "' is not a full link")
    }
    if (length(split_lines(r$selected_work)[[1]]) > 3)
      p("lists more than 3 selected works")

    hidden <- split_checkbox(r$hidden_fields)[[1]]
    for (h in setdiff(hidden, vocab$hideable$label))
      p("hidden field '", h, "' is not in data/vocab/hideable_fields.csv")

    if (identical(r$status, "Alumni")) {
      for (f in ALUMNI_REQUIRED)
        if (is.na(r[[f]])) p("alumni must have '", f, "'")
      if (!is.na(r$sector) && !r$sector %in% vocab$sector)
        p("sector '", r$sector, "' is not in data/vocab/sector.csv")
      if (!is.na(r$grad_year) && !str_detect(r$grad_year, "^(19|20)\\d\\d$"))
        p("graduation year '", r$grad_year, "' should be a four-digit year")
      if (!is.na(r$grad_year) && !is.na(r$cohort_year) &&
          suppressWarnings(as.integer(r$grad_year) < as.integer(r$cohort_year)))
        p("graduation year is before the year they entered")
    } else if (!is.na(r$status)) {
      filled <- ALUMNI_FIELDS[!is.na(unlist(r[ALUMNI_FIELDS]))]
      if (length(filled) > 0)
        p("has alumni-only fields filled in (", paste(filled, collapse = ", "),
          ") but status is '", r$status, "'")
    }

    if (length(probs) > 0) {
      bad <- c(bad, r$row_number)
      for (m in probs) report <- add_problem(report, r$row_number, m,
                                             paste(r$first_name, r$last_name))
    }
  }
  list(report = report, bad_rows = bad)
}

# ---- run on its own --------------------------------------------------------

if (sys.nframe() == 0L) {
  source("R/load_data.R")
  args <- commandArgs(trailingOnly = TRUE)
  src <- if (length(args) > 0) args[1] else gsn_source()
  raw <- read_responses(src)
  res <- clean_people(raw)
  cat(format_report(res$report, raw), sep = "\n")
  cat("\n", nrow(res$people), " people will be shown on the site.\n", sep = "")
  if (any(res$report$kind == "problem")) quit(status = 1)
}
