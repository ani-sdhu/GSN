# Reads the form responses and turns them into one clean row per person.
#
# The steps, in order:
#   1. Read the responses (CSV now, Google Sheet later) and rename the
#      question-title columns to short field names using data/form_map.csv.
#   2. Apply removal requests: a "Remove my profile" request drops every
#      earlier row from that email address, approved or not.
#   3. Keep only rows the admin marked Approved.
#   4. Handle TEST rows (see GSN_MODE in _environment).
#   5. Keep the newest approved row per email address.
#   6. Validate each row (R/validate.R). Rows with problems are skipped
#      and listed in the report; the rest of the site still builds.
#   7. Split list fields, turn "open to" answers into TRUE/FALSE, and
#      blank out every field the person asked to hide.
#
# Everything after this file only ever sees the cleaned table, so hidden
# fields and unpublished rows cannot leak into a page by accident.

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(stringr)
})

source("R/config.R")
source("R/validate.R")

REQUEST_REMOVE <- "Remove my profile from the site"

# ---- helpers ---------------------------------------------------------------

read_vocab <- function(name) {
  path <- file.path("data/vocab", paste0(name, ".csv"))
  if (!file.exists(path)) stop("Missing vocab file: ", path, call. = FALSE)
  read_csv(path, col_types = cols(.default = col_character()),
           progress = FALSE)
}

load_vocab <- function() {
  list(
    program   = read_vocab("program")$term,
    status    = read_vocab("status")$term,
    subfields = read_vocab("subfields")$term,
    methods   = read_vocab("methods")$term,
    regions   = read_vocab("regions")$term,
    sector    = read_vocab("sector")$term,
    open_to   = read_vocab("open_to"),
    hideable  = read_vocab("hideable_fields")
  )
}

# Checkbox answers arrive as "A, B, C" (Google Sheets joins them with
# comma + space). Free-text lists use semicolons. Selected work uses one
# item per line.
split_checkbox  <- function(x) split_on(x, ",\\s+")
split_semicolon <- function(x) split_on(x, "\\s*;\\s*")
split_lines     <- function(x) split_on(x, "\\s*[\r\n]+\\s*")

split_on <- function(x, pattern) {
  map(x, function(v) {
    if (is.na(v) || !nzchar(str_trim(v))) return(character(0))
    out <- str_trim(str_split(v, pattern)[[1]])
    out[nzchar(out)]
  })
}

blank_to_na <- function(x) {
  x <- str_trim(as.character(x))
  x[!is.na(x) & !nzchar(x)] <- NA_character_
  x
}

make_id <- function(first, last, cohort) {
  slug <- function(s) {
    s <- iconv(s, to = "ASCII//TRANSLIT")
    str_remove_all(str_to_lower(s), "[^a-z0-9]")
  }
  base <- paste0(str_sub(slug(first), 1, 1), slug(last))
  ifelse(is.na(cohort) | !nzchar(cohort), base, paste0(base, "-", cohort))
}

# ---- 1. read ---------------------------------------------------------------

read_responses <- function(source = gsn_source()) {
  if (str_detect(source, "^https?://")) {
    # Later: read the private Google Sheet with googlesheets4 using a
    # service account key stored as a GitHub secret. Not wired up yet.
    stop("Reading from a Google Sheet is not set up yet. ",
         "Set GSN_DATA_SOURCE to a CSV path for now.", call. = FALSE)
  }
  if (!file.exists(source)) {
    stop("Data source not found: ", source, call. = FALSE)
  }
  raw <- read_csv(source, col_types = cols(.default = col_character()),
                  progress = FALSE, na = character())

  map_tbl <- read_csv("data/form_map.csv",
                      col_types = cols(.default = col_character()),
                      progress = FALSE)

  missing <- setdiff(map_tbl$question, names(raw))
  if (length(missing) > 0) {
    stop("These columns are missing from the responses: ",
         paste(missing, collapse = "; "),
         ". If a form question was renamed, update data/form_map.csv.",
         call. = FALSE)
  }
  raw <- raw[, map_tbl$question]
  names(raw) <- map_tbl$field
  raw$row_number <- seq_len(nrow(raw)) + 1L   # matches the sheet row
  raw |> mutate(across(-row_number, blank_to_na))
}

# ---- 2 to 7. clean ---------------------------------------------------------

clean_people <- function(raw, mode = gsn_mode(), vocab = load_vocab()) {
  report <- new_report()

  raw <- raw |>
    mutate(
      email = str_to_lower(email),
      submitted_at = as.POSIXct(submitted_at, format = "%m/%d/%Y %H:%M:%S",
                                tz = "America/New_York"),
      is_test = !is.na(admin_notes) &
        str_starts(admin_notes, fixed(GSN$test_prefix))
    )

  bad_time <- raw |> filter(is.na(submitted_at))
  if (nrow(bad_time) > 0) {
    stop("Rows with an unreadable Timestamp: ",
         paste(bad_time$row_number, collapse = ", "), call. = FALSE)
  }

  # 2. removal requests
  removals <- raw |>
    filter(request_type == REQUEST_REMOVE) |>
    group_by(email) |>
    summarise(removed_at = max(submitted_at), .groups = "drop")
  removed_rows <- raw |>
    inner_join(removals, by = "email") |>
    filter(submitted_at <= removed_at, request_type != REQUEST_REMOVE)
  for (i in seq_len(nrow(removed_rows))) {
    report <- add_note(report, removed_rows$row_number[i],
                       "removed at the person's request")
  }
  kept <- raw |>
    filter(request_type != REQUEST_REMOVE | is.na(request_type)) |>
    anti_join(removed_rows |> select(row_number), by = "row_number")

  # 3. approved only
  kept <- kept |> filter(review_status %in% "Approved")

  # 4. test rows
  if (mode == "production" && any(kept$is_test)) {
    stop("This is a production build, but rows ",
         paste(kept$row_number[kept$is_test], collapse = ", "),
         " are TEST rows. Remove them, or set GSN_MODE=test.", call. = FALSE)
  }

  # 5. newest approved row per email
  kept <- kept |>
    arrange(desc(submitted_at)) |>
    distinct(email, .keep_all = TRUE)

  # Consent is required for every real row. TEST rows never claim consent,
  # which is why they are allowed only in test builds.
  no_consent <- kept |> filter(is.na(consent) & !is_test)
  for (i in seq_len(nrow(no_consent))) {
    report <- add_problem(report, no_consent$row_number[i],
                          "no consent given, so it is not shown")
  }
  kept <- kept |> filter(!is.na(consent) | is_test)

  # Fill missing ids (normally the form script does this)
  kept <- kept |>
    mutate(id = coalesce(id, make_id(first_name, last_name, cohort_year)))

  # 6. validate row by row
  v <- validate_rows(kept, vocab, mode)
  report <- merge_reports(report, v$report)
  kept <- kept |> filter(!row_number %in% v$bad_rows)

  dup <- kept |> count(id) |> filter(n > 1)
  if (nrow(dup) > 0) {
    stop("Two different email addresses share the id(s): ",
         paste(dup$id, collapse = ", "),
         ". Give one of them a different id in the sheet.", call. = FALSE)
  }

  # 7. shape for the site
  people <- kept |>
    mutate(
      subfields      = split_checkbox(subfields),
      methods        = split_checkbox(methods),
      regions        = split_checkbox(regions),
      open_to_list   = split_checkbox(open_to),
      hidden_labels  = split_checkbox(hidden_fields),
      interests      = map(split_semicolon(interests),
                           ~ unique(str_to_lower(.x))),
      languages      = split_semicolon(languages),
      committee      = split_semicolon(committee),
      courses_taught = split_semicolon(courses_taught),
      selected_work  = map(split_lines(selected_work), parse_work),
      cohort_year    = as.integer(cohort_year),
      grad_year      = as.integer(grad_year),
      last_updated   = as.Date(submitted_at, tz = "America/New_York"),
      email_uga       = if_else(status != "Alumni", email, NA_character_),
      email_preferred = if_else(status == "Alumni", email, NA_character_)
    )

  for (j in seq_len(nrow(vocab$open_to))) {
    people[[vocab$open_to$field[j]]] <-
      map_lgl(people$open_to_list, ~ vocab$open_to$label[j] %in% .x)
  }

  people$hidden_fields <- map(people$hidden_labels, function(lbls) {
    f <- vocab$hideable$field[match(lbls, vocab$hideable$label)]
    f <- f[!is.na(f)]
    if ("email" %in% f) f <- c(f, "email_uga", "email_preferred")
    if ("current_city" %in% f) f <- c(f, "current_country")
    setdiff(f, GSN$never_hide)
  })

  people <- apply_hidden(people)

  people <- people |>
    select(-any_of(c("email", "open_to", "open_to_list", "hidden_labels",
                     "consent", "review_status", "admin_notes",
                     "request_type", "submitted_at"))) |>
    arrange(last_name, first_name)

  list(people = people, report = report)
}

parse_work <- function(lines) {
  if (length(lines) == 0) return(list())
  map(head(lines, 3), function(l) {
    parts <- str_trim(str_split_fixed(l, "\\|", 2))
    list(title = parts[1], url = if (nzchar(parts[2])) parts[2] else NA)
  })
}

# Blank out every hidden field, row by row. List fields become empty,
# text fields become NA.
apply_hidden <- function(people) {
  for (i in seq_len(nrow(people))) {
    for (f in people$hidden_fields[[i]]) {
      if (!f %in% names(people)) next
      if (is.list(people[[f]])) {
        people[[f]][i] <- list(if (f == "selected_work") list() else character(0))
      } else {
        people[[f]][i] <- NA
      }
    }
  }
  people
}

# One call that does everything, used by the pre-render script.
load_people <- function(source = gsn_source(), mode = gsn_mode()) {
  clean_people(read_responses(source), mode = mode)
}
