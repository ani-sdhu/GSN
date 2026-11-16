# Test data

## `mock_responses.csv` (what the site is built from)

30 rows, one per SPIA faculty member, built only from the public SPIA
faculty directory (spia.uga.edu/directory/faculty/), pulled November 2026:
name, title, department, research-area tags, profile link, and photo.

- Their SPIA research-area tags are mapped to our subfield list.
  The tags themselves become their interest tags.
- Nothing else is invented. Pronouns, "open to" choices, methods,
  cohort year, alumni details, and consent are left blank.
- Emails are fake (`test+...@example.edu`). The SPIA site deliberately
  hides faculty emails from scrapers, so we don't decode them.
- Status is `Faculty (test data)` and `admin_notes` starts with `TEST:`.
  These rows show up only in a test build. The real build refuses
  any `TEST:` row.

Because faculty have no alumni records, entry years, or methods, the
Alumni and Cohorts pages show "not yet" messages in this build.

## `edge_cases.csv` (never shown on the site)

28 invented rows used only to test the review rules from the command
line. The site build does not read this file. Run:

```bash
Rscript R/validate.R data/test/edge_cases.csv
```

It should report two skipped rows (a master's student marked ABD, and a
row with a bad subfield, a blurb that is too long, and a broken link) and
one removal. Delete this file if you don't want it in the repository.
