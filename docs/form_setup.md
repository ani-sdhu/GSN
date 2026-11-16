# Setting up the profile form and review sheet

This takes about 10 minutes and only needs to be done once. You need a
Google account. The form and sheet will belong to whichever account runs
the script, so use the account the admin will keep.

## 1. Create the form and sheet

1. Go to <https://script.google.com> and click **New project**.
2. Delete the sample code in the editor.
3. Open `google-form/build_form.gs` from this repository, copy all of it,
   and paste it into the editor.
4. Click the save icon. Name the project something like "GSN form builder".
5. In the function menu at the top (next to **Debug**), choose `setup`,
   then click **Run**.
6. Google will ask you to authorize the script. It needs permission to
   create a form, create a sheet, and send you email. Approve it. If you
   see "Google hasn't verified this app," click **Advanced**, then
   **Go to GSN form builder**. That warning appears for any personal
   script you write yourself.
7. When it finishes, open **Execution log**. It prints three links:
   - **Form (edit):** where you change questions.
   - **Form (share):** the link you send to students and alumni.
   - **Review sheet:** where submissions arrive and where you approve them.

The form and sheet also appear in your Google Drive.

## 2. Reviewing submissions

Each submission becomes a new row in the review sheet. The script fills
in two of the yellow admin columns for you and emails you.

| Column | What it means |
|---|---|
| `review_status` | Starts as **Pending**. Change it to **Approved** to publish, or **Rejected** to keep it off the site. |
| `id` | The profile's web address (for example `jdoe-2021`). Filled in automatically and reused when the same email submits again. Don't change it once a profile is live, or old links will break. |
| `admin_notes` | Private notes for you. Never shown on the site. |

How the site reads the sheet:

- Only rows marked **Approved** are ever shown.
- If one email address has several approved rows, the newest one wins.
  So an update replaces the old profile once you approve it.
- A **Remove my profile** request takes effect at the next site build,
  even without approval. Removing someone quickly is safer than leaving
  them up by mistake.
- Before approving, check that the email matches the person. Anyone can
  type someone else's name into a form, so your review is the check.

## 3. Rules for editing the form later

- **Renaming a question?** Rename it in `data/form_map.csv` too. The site
  finds each answer by its question title.
- **Adding or renaming a choice** (subfield, method, region, sector)?
  Change the matching file in `data/vocab/` as well, or validation will
  reject rows that use the new choice.
- **No commas inside choices.** Google Sheets stores checkbox answers in
  one cell separated by commas, so "Law, Courts" would be read as two
  choices.
- **Don't move, rename, or delete the yellow admin columns.** Moving
  other columns around is fine, since the site matches columns by name.

## 4. Connecting the sheet to the site

This step comes later, once the site is built. It uses a Google "service
account" (a robot login that can read only the sheets you share with it)
and stores its key as an encrypted GitHub secret, never in the code. The
full steps will be added here in a later stage.
