# Runs after Quarto renders the site (see _quarto.yml).
#
# Reads every text file in _site/ and fails the build if it finds:
#   - the name or email of anyone who is NOT published (pending, rejected,
#     removed, skipped by validation, or no consent);
#   - text from an older or unapproved version of a published profile;
#   - a value a person chose to hide;
#   - admin notes, or a copy of the raw responses file.
#
# This checks the actual output files, not just what a browser shows.

source("R/load_data.R")

site_dir <- "_site"
files <- list.files(site_dir, recursive = TRUE, full.names = TRUE,
                    pattern = "\\.(html|json|js|xml|txt|csv)$")
files <- files[!str_detect(files, "/site_libs/")]
text <- setNames(map_chr(files, ~ paste(readLines(.x, warn = FALSE), collapse = "\n")),
                 files)
all_text <- paste(text, collapse = "\n")

escape_html <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  gsub("'", "&#39;", x, fixed = TRUE)
}
found_in <- function(value, haystack) {
  any(map_lgl(unique(c(value, escape_html(value))),
              ~ str_detect(haystack, fixed(.x))))
}

raw <- read_responses()
raw$email <- str_to_lower(raw$email)
people <- readRDS("_cache/people.rds")$people
published_rows <- people$row_number
published_emails <- raw$email[raw$row_number %in% published_rows]

failures <- character(0)
fail <- function(...) failures <<- c(failures, paste0(...))

# 1. Unpublished people: no name or email anywhere.
gone <- raw |> filter(!email %in% published_emails)
for (i in seq_len(nrow(gone))) {
  g <- gone[i, ]
  nm <- paste(g$first_name, g$last_name)
  if (found_in(nm, all_text)) fail("Unpublished person's name appears: ", nm)
  if (!is.na(g$email) && found_in(g$email, all_text))
    fail("Unpublished person's email appears: ", g$email)
}

# 2. Older or unapproved versions of published people.
old <- raw |> filter(email %in% published_emails, !row_number %in% published_rows)
for (i in seq_len(nrow(old))) {
  o <- old[i, ]
  current <- raw$blurb[raw$row_number %in% published_rows & raw$email == o$email]
  if (!is.na(o$blurb) && !identical(o$blurb, current) && found_in(o$blurb, all_text))
    fail("An old or unapproved blurb for row ", o$row_number, " appears on the site")
}

# 3. Hidden fields.
hideable <- read_csv("data/vocab/hideable_fields.csv", show_col_types = FALSE)
visible_values <- function(field, except_row) {
  others <- raw |> filter(row_number %in% published_rows, row_number != except_row)
  if (!field %in% names(others)) return(character(0))
  v <- others[[field]]
  hid <- split_checkbox(others$hidden_fields)
  label <- hideable$label[hideable$field == field]
  v <- v[!map_lgl(hid, ~ length(label) > 0 && label %in% .x)]
  if (field %in% c("committee", "languages", "courses_taught"))
    v <- unlist(split_semicolon(v))
  v
}
for (i in seq_len(nrow(people))) {
  pr <- people[i, ]
  r <- raw[raw$row_number == pr$row_number, ]
  page <- text[file.path(site_dir, "people", pr$id, "index.html")]
  for (f in setdiff(pr$hidden_fields[[1]], c("email_uga", "email_preferred"))) {
    raw_field <- if (f %in% c("email_uga", "email_preferred")) "email" else f
    val <- r[[raw_field]]
    if (is.na(val) || nchar(val) < 4) next
    pieces <- if (raw_field %in% c("committee", "languages", "courses_taught"))
      split_semicolon(val)[[1]] else val
    for (v in pieces) {
      if (!is.na(page) && found_in(v, page))
        fail(pr$id, ": hidden field '", f, "' appears on their profile page")
      if (!v %in% visible_values(raw_field, pr$row_number) && found_in(v, all_text))
        fail(pr$id, ": hidden field '", f, "' appears somewhere on the site")
    }
  }
}

# 4. Admin notes and raw files.
for (n in unique(na.omit(raw$admin_notes))) {
  if (nchar(n) >= 12 && found_in(n, all_text)) fail("An admin note appears: ", n)
}
if (any(str_detect(files, "\\.csv$"))) fail("A CSV file was copied into _site/")
if (str_detect(all_text, fixed("review_status"))) fail("Raw sheet columns appear in _site/")

if (length(failures) > 0) {
  message("\nPRIVACY CHECK FAILED. The site was built but must not be published:\n",
          paste0("  - ", unique(failures), collapse = "\n"))
  quit(status = 1)
}
message("Privacy check passed: ", length(files), " files scanned, ",
        nrow(people), " published people, ",
        length(unique(gone$email)),
        " unpublished people never appear, hidden fields never appear.")
