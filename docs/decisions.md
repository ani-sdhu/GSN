# Build decisions

Small decisions made while building the prototype, so they're easy to
review and reverse.

## Look and feel

1. **Modeled on spia.uga.edu, without copying UGA marks.** Same black UGA
   bar with a red rule, white header, red buttons, breadcrumbs, uppercase
   Oswald page titles, Merriweather text, gray dropdown filters, A to Z
   letter buttons, a photo grid, and profile pages with fold-out sections
   and the photo on the right. The UGA arch logo is not used; the header
   is a text wordmark. Colors (#BA0C2F red, #F4F4F4 gray, #554F47 warm
   gray) and fonts were read from SPIA's own stylesheet.
2. **No hero photos.** SPIA pages open with a large photo; we have none
   we're free to use, so pages open with the breadcrumb and title, like
   SPIA's profile pages.
3. **Footer says it's student-run and not an official UGA page.**
4. **"Join the Network" is the red button** in the header, where SPIA has
   "Apply Now."
5. **Research and After Graduation sections start open** on profiles; the
   rest start closed, as on SPIA. Research is the main reason to visit.
6. **Status badges carry an icon and text**, not just a color (open circle
   = Coursework, half circle = ABD, filled circle = job market,
   mortarboard = Alumni).
7. **Initials avatar** (gray square with initials) when there's no photo.

## Directory

8. **Plain JavaScript directory instead of reactable + crosstalk**, as
   discussed: it supports cards, multi-value filters, search, and URL
   filters without extra packages.
9. **Filters live in the URL** (for example `?interest=voting`), so tag
   links and bookmarks open a filtered directory.
10. **Search matches every word** across name, interests, research
    description, and dissertation title.
11. **Clicking an interest tag on a card filters in place**; clicking one
    on a profile or the landscape page opens the directory filtered.
12. **A to Z buttons** copy SPIA's faculty page; letters with no one are
    greyed out.
13. **Cards show the top 3 interest tags** (the first three the person
    listed).
14. **Alumni cards show grad year and current job** instead of entry year.

## Data and review rules

15. **Newest approved row per email wins.** A newer pending update does
    not replace an approved profile.
16. **Removal requests apply without approval.**
17. **Bad rows are skipped, not fatal.** Setup problems (missing vocab
    file, renamed column, two people with the same id) still stop the
    build.
18. **Interest tags are lowercased and de-duplicated** so "Voting" and
    "voting" count once. Similar but different words are not merged yet.
19. **Master's students can't be ABD or on the job market** (validation).
20. **"Email" maps to `email_uga` for students and `email_preferred` for
    alumni**, so the form needs only one email question.
21. **Name, program, status, subfields, interests, and research
    description can't be hidden**; the form says so.
22. **Hiding "Current city and country" hides both**, and takes the person
    off the map (they stay in the alumni table).
23. **Emails show as a plain "Email" link.** You didn't pick an option, so
    this is the simple default; it can be swapped for a click-to-reveal
    button later.

## Test data

24. **Faculty test rows use only what the SPIA directory shows**, with
    fake `example.edu` emails (SPIA hides real ones from scrapers), no
    consent claimed, and a `TEST:` note. They only appear in test builds,
    under a yellow banner, with the status "Faculty (test data)".
25. **Faculty "program" comes from their department** (PADP faculty ->
    PADP PhD; everyone else -> POLS/INTL PhD), only so the filters have
    something to work with.
26. **SPIA research-area tags were mapped to subfields** (for example
    "American Political Institutions" -> American, "Public Finance &
    Budgeting" -> Public Finance). Tags with no clear match (Political
    Behavior, Democratic Politics, Elections, Human Rights, Gender &
    Politics, Race, Ethnicity & Politics, Political Psychology) stay as
    interest tags only.
27. **Faculty photos load from spia.uga.edu** in test builds only.

## Alumni page

28. **Sector chart uses one color with two labeled panels** (Academic,
    Outside academia) instead of two colors: every two-color pairing with
    UGA red failed a colorblind-safety check. The chart has full alt text.
29. **No split by decade.** With 11 alumni it would mostly show empty bars.
    Easy to add once there are more.
30. **Map coordinates are cached by hand** in `data/geocache.csv` (no
    geocoding service is called during builds). Alumni whose city is
    missing are counted in a note above the map.
31. **Map clusters are UGA red** instead of Leaflet's default green.

## Pages

32. **Cohorts page leaves out people without an entry year** (the faculty
    test rows, or anyone who hides it) and says how many.
33. **Research Landscape uses HTML bars instead of a chart**, so each row
    is a real link you can tab to and click.
34. **Quarto's site search is off**; the directory search covers it.

## Build and hosting

35. **Test vs production mode** is set in `_environment`. Production
    refuses to build if a `TEST:` row is present.
36. **The workflow builds and checks the site on every push, nightly, and
    on demand**, and saves `_site/` as a downloadable zip. GitHub Pages
    publishing is there but off until you turn it on.
37. **Placeholders to replace before launch:** form link
    (`forms.example.com`), admin email (`gsn-admin@example.edu`).
38. **Network access added to this cloud environment:** `spia.uga.edu`
    (faculty test data) and `cloud.r-project.org` (to install `leaflet`).
