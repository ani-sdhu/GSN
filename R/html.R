# Small HTML building blocks shared by every page.

suppressPackageStartupMessages({
  library(htmltools)
  library(purrr)
  library(stringr)
})

has <- function(x) {
  if (is.null(x)) return(FALSE)
  if (is.list(x)) return(length(x) > 0)
  length(x) > 0 && !all(is.na(x)) && any(nzchar(x))
}

full_name <- function(p) paste(p$first_name, p$last_name)

initials <- function(first, last) {
  first_word <- str_split(first, "\\s+")[[1]][1]
  last_parts <- str_split(last, "[\\s-]+")[[1]]
  toupper(paste0(str_sub(first_word, 1, 1), str_sub(last_parts[length(last_parts)], 1, 1)))
}

status_class <- function(status) {
  paste0("status-", str_replace_all(str_to_lower(status), "[^a-z]+", "-") |>
           str_remove("-$"))
}

STATUS_ICONS <- c("Coursework" = "circle", "Candidate (ABD)" = "circle-half",
                  "On the job market" = "circle-fill", "Alumni" = "mortarboard-fill",
                  "Faculty (test data)" = "square-fill")

status_badge <- function(status) {
  ic <- unname(STATUS_ICONS[status])
  span(class = paste("status-badge", status_class(status)),
       if (!is.na(ic)) tags$i(class = paste0("bi bi-", ic), `aria-hidden` = "true"),
       status)
}

# Photo if there is one, otherwise a gray box with initials.
avatar <- function(p, size = "lg") {
  if (has(p$photo_url)) {
    img(src = p$photo_url, alt = paste("Photo of", full_name(p)),
        class = paste("avatar avatar-photo", paste0("avatar-", size)),
        loading = "lazy")
  } else {
    div(class = paste("avatar avatar-initials", paste0("avatar-", size)),
        role = "img", `aria-label` = paste("Initials of", full_name(p)),
        initials(p$first_name, p$last_name))
  }
}

breadcrumbs <- function(...) {
  items <- list(...)
  parts <- map(seq_along(items), function(i) {
    it <- items[[i]]
    if (is.null(it$href)) span(`aria-current` = "page", it$text)
    else a(href = it$href, it$text)
  })
  sep <- span(class = "crumb-sep", `aria-hidden` = "true", ">")
  tags$nav(class = "breadcrumbs", `aria-label` = "Breadcrumb",
      tagList(head(unlist(map(parts, ~ list(.x, sep)), recursive = FALSE), -1)))
}

page_header <- function(title, crumbs) {
  tagList(crumbs, h1(class = "page-title", title))
}

# Tag links go back to the directory, pre-filtered.
tag_link <- function(text, param, root) {
  a(class = "tag", href = paste0(root, "index.html?", param, "=",
                                 utils::URLencode(text, reserved = TRUE)),
    text)
}

render_html <- function(x) as.character(x)

# Wraps HTML so Quarto passes it through untouched.
raw_block <- function(x) {
  paste0("```{=html}\n", render_html(x), "\n```\n")
}

# Yellow banner shown on every page of a test build.
test_banner <- function(mode) {
  if (!identical(mode, "test")) return(NULL)
  div(class = "test-banner", role = "note",
      tags$strong("Test build. "),
      "Rows marked “Faculty (test data)” come from the public SPIA ",
      "faculty directory and are here only to test the layout. Everyone ",
      "else is fictional. Do not publish this build.")
}
