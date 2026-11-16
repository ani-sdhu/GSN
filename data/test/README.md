# Test data

`mock_responses.csv` has the same columns as the Google Sheet the form
creates, so the site can be tested before the real form is live.

## What's in it (58 rows)

**30 SPIA faculty rows.** Built only from the public SPIA faculty
directory (spia.uga.edu/directory/faculty/), pulled November 2026:
name, title, department, research-area tags, profile link, and photo.
- Their SPIA research-area tags are mapped to our subfield list.
  The tags themselves become their interest tags.
- Nothing else is invented. Pronouns, "open to" choices, methods,
  cohort year, and consent are left blank.
- Emails are fake (`test+...@example.edu`). The SPIA site deliberately
  hides faculty emails from scrapers, so we don't decode them.
- Status is `Faculty (test data)` and `admin_notes` starts with `TEST:`.
  These rows show up only in a test build. The real build refuses
  any `TEST:` row.

**28 fictional rows** (obviously invented names, `example.edu` and
`example.com` links) that test the review rules:

| Who | What it tests | Should appear? |
|---|---|---|
| 9 current students | all statuses, all five programs (two PhDs, MA, MIP, MPA), open-to flags, hidden fields | yes |
| 11 alumni (2012 to 2025) | every sector, PhD and master's alumni, the placement table and map | yes |
| Wren Quillfeather | approved update, then a newer **pending** update | yes, with the "UPDATED BLURB" text |
| Oskar Mapleton | removal request (no approval needed) | **no** |
| Pendleton Ashby, Marigold Fairweather | pending | **no** |
| Rejecta Nullwood | rejected | **no** |
| Abner Mismatch | approved, but a master's student marked Candidate (ABD) | **no**, and listed in the admin report |
| Brokenrow Testcase | approved, but bad subfield, blurb too long, bad link | **no**, and listed in the admin report |
