# SPIA Graduate Student Network

A searchable directory of current students and alumni of the graduate
programs at UGA's School of Public & International Affairs: who works on
what, how to reach them, what they're open to helping with, and where
alumni ended up.

This is a working prototype. It is built with Quarto and R and produces a
plain folder of web pages (`_site/`) that can be hosted anywhere.

## How it works, in one paragraph

People fill out a Google Form. Their answers land in a Google Sheet, where
the admin marks each row Approved, Pending, or Rejected. When the site is
built, R reads the sheet, keeps only approved rows, checks each one,
removes anything a person chose to hide, and writes the pages. A final
check reads every output file and stops the build if anything private
slipped through.

## The pages

| Page | File | What it shows |
|---|---|---|
| Directory | `index.qmd` + `assets/directory.js` | Search, filters, A to Z, cards or table |
| Profiles | made by `R/build_profiles.R` | One page per person at `people/<id>/` |
| Alumni & Placements | `alumni.qmd` | Sector chart, map, alumni by graduation year |
| Cohorts | `cohorts.qmd` | Everyone grouped by entry year |
| Research Landscape | `landscape.qmd` | Counts by subfield, method, interest; each row links to the filtered directory |
| About & Join | `about.qmd` | What this is, how to join, privacy in plain language |

## Build it on your computer

You need R (4.3 or newer) and Quarto (1.6 or newer). Install the R
packages once:

```r
install.packages(c("readr", "dplyr", "tidyr", "purrr", "stringr", "jsonlite",
                   "htmltools", "glue", "ggplot2", "svglite", "leaflet",
                   "rmarkdown", "knitr"))
```

Then, from this folder:

```bash
quarto render
```

Open `_site/index.html` in a browser. To preview with live reloading, use
`quarto preview` instead.

The build reads its settings from `_environment`:

- `GSN_DATA_SOURCE`: the responses file (now `data/test/mock_responses.csv`).
- `GSN_MODE`: `test` shows the SPIA faculty test rows with a yellow banner;
  `production` refuses to build if any test row is present.

## Add or edit a person

People add themselves through the form; you never edit pages by hand.

1. Someone submits the form (see `docs/form_setup.md` to create it).
2. You get an email. Open the review sheet and check the row.
3. Set `review_status` to **Approved**. The next build publishes it.

Rules the build follows:

- Only **Approved** rows are shown.
- If one email has several approved rows, the **newest** one is used, so an
  update replaces the old profile once you approve it.
- A **"Remove my profile"** request takes the profile down at the next
  build, without needing approval.
- An approved row with a problem (an unknown subfield, a blurb over 400
  characters, a broken link, a master's student marked ABD) is **skipped**,
  and the reason is printed in the build log and in
  `_reports/validation.txt`. Fix it in the sheet and rebuild.

To check the sheet without building the site:

```bash
Rscript R/validate.R
```

To fix a typo for someone, edit their row in the sheet directly, then
rebuild. Do not change the `id` of a live profile, or old links will break.

## Add a vocab term (a subfield, method, region, sector, or program)

1. Add a line to the matching file in `data/vocab/`. Don't use commas in
   the term.
2. Add the same choice to the form: either in the Forms editor, or in
   `google-form/build_form.gs` if you're creating the form fresh.
3. Rebuild. The new term appears in the directory filters automatically.

## Add a city to the alumni map

Alumni appear on the map when their city is in `data/geocache.csv`. If an
alum's city is missing, the alumni page says how many are left off. Add a
line with the city, country, latitude, and longitude (any map site shows
these), then rebuild.

## Deploy

Every push to `main` triggers `.github/workflows/build.yml`. It builds the
site, runs both checks, and saves the result as a zip called `gsn-site` on
the workflow run page. It also rebuilds nightly, so approved profiles show
up within a day once the live sheet is connected.

Final hosting is still open. The finished `_site/` folder can be:

- uploaded to any web host that serves plain files,
- published as a preview on GitHub Pages (set the repository variable
  `DEPLOY_PAGES` to `true`), or
- linked to or embedded from a SPIA WordPress page.

Before going live with real people:

1. Connect the real Google Sheet (step 4 in `docs/form_setup.md`).
2. Set `GSN_MODE=production` in `_environment`.
3. Replace the placeholder form link and admin email in `R/config.R`,
   `about.qmd`, and `_quarto.yml`.

## Swap in your own theme

All styling lives in `theme/spia.scss` (web pages) and `R/theme_uga.R`
(charts). Replace those two files to change the look.

## Files

```
_quarto.yml              site settings, menu, build steps
_environment             data source and test/production mode
index.qmd ... about.qmd  the pages
assets/directory.js      directory search and filters
R/load_data.R            reads responses, applies review rules, hides fields
R/validate.R             row checks and the plain-language report
R/build_profiles.R       writes people/<id>/index.qmd
R/check_output.R         privacy check on the finished site
R/prerender.R            runs load, validate, and profile writing
R/html.R, R/site.R       shared page pieces
R/config.R               form link, admin email, limits
R/theme_uga.R            chart theme
theme/                   site theme and the black UGA bar
data/vocab/              controlled vocabularies
data/form_map.csv        form question title -> field name
data/geocache.csv        city coordinates for the map
data/test/               faculty test rows and edge-case rows (see its README)
google-form/             script that creates the form and review sheet
docs/                    form setup guide and build decisions
```
