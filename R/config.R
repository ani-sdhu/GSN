# Site-wide settings. Edit these placeholders when the real form and
# admin address exist.

GSN <- list(
  site_title   = "Graduate Student Network",
  school       = "School of Public & International Affairs",
  # Link to the live Google Form ("Form (share)" link from setup).
  form_url     = "https://forms.example.com/gsn-profile-form",
  # Where "Request an update" and questions go.
  admin_email  = "gsn-admin@example.edu",
  # Prefix in admin_notes that marks a test row.
  test_prefix  = "TEST:",
  # Max characters in a blurb, and max interest tags.
  blurb_max    = 400,
  interest_max = 8,
  # Fields a person may never hide (the site needs them).
  never_hide   = c("id", "first_name", "last_name", "program", "status",
                   "subfields", "interests", "blurb")
)

gsn_mode <- function() {
  m <- tolower(Sys.getenv("GSN_MODE", "production"))
  if (!m %in% c("test", "production")) {
    stop("GSN_MODE must be 'test' or 'production', not '", m, "'.", call. = FALSE)
  }
  m
}

gsn_source <- function() {
  Sys.getenv("GSN_DATA_SOURCE", "data/test/mock_responses.csv")
}
