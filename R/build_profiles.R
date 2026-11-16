# Writes one profile page per person at people/<id>/index.qmd.
# The folder is rebuilt from scratch on every build (and is gitignored),
# so a removed person's page disappears too.

source("R/html.R")

LINK_FIELDS <- list(
  website        = list(label = "Personal Website", icon = "globe"),
  cv_url         = list(label = "Curriculum Vitae", icon = "file-earmark-text"),
  google_scholar = list(label = "Google Scholar", icon = "mortarboard"),
  orcid          = list(label = "ORCID", icon = "person-badge"),
  linkedin       = list(label = "LinkedIn", icon = "linkedin"),
  bluesky        = list(label = "Bluesky", icon = "cloud"),
  x              = list(label = "X (Twitter)", icon = "twitter-x")
)

icon <- function(name) tags$i(class = paste0("bi bi-", name), `aria-hidden` = "true")

accordion <- function(title, ..., open = FALSE) {
  tags$details(class = "spia-accordion", open = if (open) NA else NULL,
               tags$summary(title), div(class = "accordion-body", ...))
}

field_row <- function(label, value) {
  if (!has(value)) return(NULL)
  div(class = "field-row", h3(class = "field-label", label),
      div(class = "field-value", value))
}

tag_list <- function(values, param, root) {
  if (!has(values)) return(NULL)
  div(class = "tag-list", map(values, ~ tag_link(.x, param, root)))
}

plain_list <- function(values) {
  if (!has(values)) return(NULL)
  paste(values, collapse = ", ")
}

profile_html <- function(p, open_to_vocab, root = "../../", mode = gsn_mode()) {
  name <- full_name(p)
  subtitle <- if (identical(p$status, "Alumni")) {
    paste0(p$program, " alum", if (has(p$grad_year)) paste0(", ", p$grad_year) else "")
  } else {
    paste0(p$status, ", ", p$program)
  }

  links <- compact(imap(LINK_FIELDS, function(meta, f) {
    if (!has(p[[f]])) return(NULL)
    tags$li(a(href = p[[f]], icon(meta$icon), " ", meta$label))
  }))

  work <- p$selected_work[[1]]
  work_list <- if (length(work) > 0) {
    tags$ul(class = "work-list", map(work, function(w) {
      tags$li(if (!is.na(w$url)) a(href = w$url, w$title) else w$title)
    }))
  }

  open_flags <- open_to_vocab$label[map_lgl(open_to_vocab$field, ~ isTRUE(p[[.x]]))]

  email <- coalesce(p$email_uga, p$email_preferred)

  research <- accordion(
    "Research", open = TRUE,
    field_row("Subfields", tag_list(p$subfields[[1]], "subfield", root)),
    field_row("Research interests", tag_list(p$interests[[1]], "interest", root)),
    field_row("Methods", tag_list(p$methods[[1]], "method", root)),
    field_row("Regions", tag_list(p$regions[[1]], "region", root)),
    field_row("Research languages", plain_list(p$languages[[1]])),
    field_row(if (str_detect(p$program, "PhD")) "Dissertation" else "Thesis or capstone",
              if (has(p$dissertation_title)) em(p$dissertation_title)),
    field_row("Selected work", work_list)
  )

  advising <- if (has(p$advisor) || has(p$committee[[1]])) accordion(
    "Advising",
    field_row("Advisor", p$advisor),
    field_row("Committee", plain_list(p$committee[[1]]))
  )

  teaching <- if (has(p$courses_taught[[1]])) accordion(
    "Course Instruction",
    p("Instructor of record:"),
    tags$ul(map(p$courses_taught[[1]], tags$li))
  )

  alumni <- if (identical(p$status, "Alumni")) accordion(
    "After Graduation", open = TRUE,
    field_row("Graduated", p$grad_year),
    field_row("First position", paste(c(p$first_placement_title, p$first_placement_org)[
      !is.na(c(p$first_placement_title, p$first_placement_org))], collapse = ", ")),
    field_row("Current position", {
      cur <- c(p$current_title, p$current_org)
      if (any(!is.na(cur))) paste(cur[!is.na(cur)], collapse = ", ")
    }),
    field_row("Location", {
      loc <- c(p$current_city, p$current_country)
      if (any(!is.na(loc))) paste(loc[!is.na(loc)], collapse = ", ")
    }),
    field_row("Sector", p$sector)
  )

  update_link <- paste0(
    "mailto:", GSN$admin_email,
    "?subject=", utils::URLencode(paste0("Update request: ", name, " (", p$id, ")"),
                                  reserved = TRUE))

  tagList(
    test_banner(mode),
    page_header(name, breadcrumbs(
      list(text = "Home", href = paste0(root, "index.html")),
      list(text = "Directory", href = paste0(root, "index.html")),
      list(text = name)
    )),
    div(class = "profile-grid",
      div(class = "profile-main",
        h2(class = "profile-subtitle", subtitle),
        if (has(p$pronouns)) p(class = "pronouns", "Pronouns: ", p$pronouns),
        if (length(links) > 0) tags$ul(class = "profile-links", links),
        p(class = "profile-blurb", p$blurb),
        research, advising, teaching, alumni
      ),
      tags$aside(class = "profile-side",
        avatar(p, "lg"),
        p(class = "side-name", name),
        p(class = "side-line", p$program),
        if (has(p$cohort_year)) p(class = "side-line", paste("Entered", p$cohort_year)),
        p(class = "side-line", status_badge(p$status)),
        if (has(email)) p(class = "side-line", a(href = paste0("mailto:", email), "Email")),
        if (length(open_flags) > 0) div(class = "open-to",
          h3(class = "side-heading", "Open to"),
          tags$ul(class = "open-to-list",
                  map(open_flags, ~ tags$li(icon("check-circle-fill"), " ", .x)))
        ),
        p(class = "last-updated",
          paste0("Last updated ", str_squish(format(p$last_updated, "%B %e, %Y")), "."),
          tags$br(), a(href = update_link, "Request an update"))
      )
    )
  )
}

write_profiles <- function(people, open_to_vocab, dir = "people") {
  unlink(dir, recursive = TRUE)
  dir.create(dir, showWarnings = FALSE)
  for (i in seq_len(nrow(people))) {
    p <- people[i, ]
    d <- file.path(dir, p$id)
    dir.create(d, showWarnings = FALSE, recursive = TRUE)
    yaml <- paste0(
      "---\n",
      "title: \"", str_replace_all(full_name(p), '"', '\\\\"'), "\"\n",
      "description: \"", p$status, ", ", p$program, "\"\n",
      "---\n\n")
    writeLines(c(yaml, raw_block(profile_html(p, open_to_vocab))),
               file.path(d, "index.qmd"))
  }
  invisible(nrow(people))
}
