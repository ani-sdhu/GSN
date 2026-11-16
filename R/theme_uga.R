# ggplot2 theme for the site. Placeholder modeled on spia.uga.edu:
# one accent color (UGA red), black text, light gray grid.
# Swap this file for your own UGA theme when ready.

UGA_RED  <- "#BA0C2F"
UGA_INK  <- "#1F1F1F"
UGA_MUTED <- "#554F47"
UGA_GRID <- "#E4E4E4"

theme_uga <- function(base_size = 13) {
  ggplot2::theme_minimal(base_size = base_size, base_family = "sans") +
    ggplot2::theme(
      text = ggplot2::element_text(colour = UGA_INK),
      plot.title = ggplot2::element_text(face = "bold", size = base_size * 1.15),
      plot.title.position = "plot",
      axis.text = ggplot2::element_text(colour = UGA_MUTED),
      axis.title = ggplot2::element_text(colour = UGA_MUTED, size = base_size * 0.85),
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_line(colour = UGA_GRID, linewidth = 0.4),
      strip.text = ggplot2::element_text(face = "bold", hjust = 0, size = base_size),
      plot.margin = ggplot2::margin(8, 16, 8, 8)
    )
}
