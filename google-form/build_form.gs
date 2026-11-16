/**
 * SPIA Graduate Student Network: form and review sheet builder
 *
 * What this does (run it once):
 *   1. Creates a Google Form for profile submissions.
 *   2. Creates a Google Sheet and links it to the form, so every
 *      submission lands in it as a new row.
 *   3. Adds three admin-only columns to the response tab:
 *        review_status  (Pending, Approved, Rejected)
 *        id             (the profile's web address, filled in for you)
 *        admin_notes    (your private notes, never shown on the site)
 *   4. Installs a trigger so each new submission is marked Pending,
 *      gets an id, and sends you an email.
 *
 * How to run it: see docs/form_setup.md in the repository.
 *
 * Keep in sync: the choice lists below must match data/vocab/*.csv,
 * and the question titles must match data/form_map.csv. The site
 * reads columns by these titles, so if you rename a question in the
 * form, rename it in data/form_map.csv too.
 *
 * Choice text must not contain commas. Google Sheets stores checkbox
 * answers as one cell separated by commas, so a comma inside a choice
 * would split it in two.
 */

var CONFIG = {
  formTitle: 'SPIA Graduate Student Network: Profile Form',
  sheetTitle: 'SPIA Graduate Student Network: Responses',
  reviewOptions: ['Pending', 'Approved', 'Rejected'],
  adminColumns: ['review_status', 'id', 'admin_notes']
};

var VOCAB = {
  program: ['POLS/INTL PhD', 'PADP PhD', 'POLS/INTL MA', 'MIP', 'MPA'],
  status: ['Coursework', 'Candidate (ABD)', 'On the job market', 'Alumni'],
  subfields: ['American', 'Comparative', 'International Relations',
    'Political Theory', 'Methods', 'Law & Courts', 'Public Management',
    'Public Policy', 'Public Finance'],
  methods: ['Survey', 'Experiments', 'Text as Data', 'Time Series',
    'Panel/Causal Inference', 'Formal Theory', 'Network Analysis',
    'Qualitative/Archival', 'Interviews/Ethnography', 'GIS/Spatial',
    'Machine Learning'],
  regions: ['United States', 'Latin America', 'Sub-Saharan Africa',
    'East Asia', 'Europe', 'Middle East & North Africa', 'South Asia',
    'Global'],
  sector: ['Tenure Track', 'Teaching-Focused', 'Postdoc', 'Government',
    'Think Tank/Research Org', 'Nonprofit/IGO', 'Industry', 'Other'],
  openTo: ['Coauthoring', 'Reading drafts', 'Mock job talks', 'Mentoring',
    'Coffee chats'],
  hideable: ['Pronouns', 'Email address', 'Advisor', 'Committee members',
    'Year I entered the program', 'Research languages', 'Dissertation title',
    'Selected work', 'Courses taught', 'Photo', 'Personal website',
    'Google Scholar', 'ORCID', 'CV link', 'LinkedIn', 'Bluesky',
    'X (Twitter)', 'Current job title', 'Current organization',
    'Current city and country']
};

var REQUEST = {
  add: 'Add a new profile',
  update: 'Update my existing profile',
  remove: 'Remove my profile from the site'
};

/** Main entry point. Select this function in the editor and click Run. */
function setup() {
  var ss = SpreadsheetApp.create(CONFIG.sheetTitle);
  var form = buildForm_();
  form.setDestination(FormApp.DestinationType.SPREADSHEET, ss.getId());
  SpreadsheetApp.flush();

  var sheet = findResponseSheet_(ss);
  addAdminColumns_(sheet);
  removeDefaultTab_(ss, sheet);

  ScriptApp.newTrigger('onFormSubmitHandler')
    .forSpreadsheet(ss)
    .onFormSubmit()
    .create();

  Logger.log('Form (edit):  ' + form.getEditUrl());
  Logger.log('Form (share): ' + form.getPublishedUrl());
  Logger.log('Review sheet: ' + ss.getUrl());
}

function buildForm_() {
  var form = FormApp.create(CONFIG.formTitle);
  form.setDescription(
    'Use this form to add yourself to the SPIA Graduate Student Network, ' +
    'update your profile, or remove it. Nothing you submit goes on the ' +
    'site until an admin reviews it. Removal requests take effect at the ' +
    'next site update without waiting for review.');
  form.setProgressBar(true);
  form.setConfirmationMessage(
    'Thanks. An admin will review your submission before it appears on ' +
    'the site. To change something later, submit this form again with the ' +
    'same email address.');

  // Page 1: who you are and what you want to do
  text_(form, 'First name', true);
  text_(form, 'Last name', true);
  form.addTextItem()
    .setTitle('Email address')
    .setHelpText('Current students: use your UGA address so we can confirm ' +
      'it is you. Alumni: use an address you plan to keep. You can hide ' +
      'this from your public profile at the end of the form.')
    .setRequired(true)
    .setValidation(FormApp.createTextValidation()
      .requireTextIsEmail()
      .setHelpText('Please enter a valid email address.')
      .build());
  var requestItem = form.addMultipleChoiceItem()
    .setTitle('What would you like to do?')
    .setRequired(true);

  // Page 2: program basics
  var programPage = form.addPageBreakItem().setTitle('Your program');
  text_(form, 'Pronouns', false);
  form.addMultipleChoiceItem()
    .setTitle('Program')
    .setHelpText('MA is the Master of Arts in Political Science & ' +
      'International Affairs. MIP is the Master of International Policy. ' +
      'MPA is the Master of Public Administration (joint-degree students ' +
      'such as MPA/JD should choose MPA).')
    .setChoiceValues(VOCAB.program)
    .setRequired(true);
  form.addTextItem()
    .setTitle('Year you entered the program')
    .setHelpText('For example, 2021.')
    .setRequired(true)
    .setValidation(FormApp.createTextValidation()
      .requireNumberBetween(1980, 2100)
      .setHelpText('Please enter a four-digit year.')
      .build());
  text_(form, 'Advisor', false);
  form.addTextItem()
    .setTitle('Committee members')
    .setHelpText('Separate names with semicolons, for example: ' +
      'Jane Smith; Ravi Patel');
  var statusItem = form.addMultipleChoiceItem()
    .setTitle('Current status')
    .setHelpText('Candidate (ABD) and On the job market are for PhD ' +
      'students. Current master\'s students should choose Coursework.')
    .setRequired(true);

  // Page 3: alumni only (people who pick "Alumni" land here)
  var alumniPage = form.addPageBreakItem()
    .setTitle('After graduation')
    .setHelpText('This section is only for alumni.');
  form.addTextItem()
    .setTitle('Year you finished your degree')
    .setRequired(true)
    .setValidation(FormApp.createTextValidation()
      .requireNumberBetween(1980, 2100)
      .setHelpText('Please enter a four-digit year.')
      .build());
  text_(form, 'First job title after graduating', true,
    'For example, Assistant Professor.');
  text_(form, 'First job organization', true);
  text_(form, 'Current job title', false);
  text_(form, 'Current organization', false);
  text_(form, 'Current city', false,
    'Used to place you on the alumni map.');
  text_(form, 'Current country', false);
  form.addMultipleChoiceItem()
    .setTitle('Sector')
    .setHelpText('Which best describes your current job?')
    .setChoiceValues(VOCAB.sector)
    .setRequired(true);

  // Page 4: research
  var researchPage = form.addPageBreakItem().setTitle('Your research');
  form.addCheckboxItem()
    .setTitle('Subfields')
    .setChoiceValues(VOCAB.subfields)
    .setRequired(true);
  form.addParagraphTextItem()
    .setTitle('Research interests')
    .setHelpText('Up to 8 short topics, separated by semicolons, for ' +
      'example: voting; state legislatures; public opinion')
    .setRequired(true)
    .setValidation(FormApp.createParagraphTextValidation()
      .requireTextMatchesPattern('^[^;]+(;[^;]+){0,7}$')
      .setHelpText('Please list between 1 and 8 topics separated by ' +
        'semicolons.')
      .build());
  form.addCheckboxItem()
    .setTitle('Methods')
    .setChoiceValues(VOCAB.methods);
  form.addCheckboxItem()
    .setTitle('Regions you study')
    .setChoiceValues(VOCAB.regions);
  text_(form, 'Research languages', false,
    'Separate with semicolons, for example: Spanish; Portuguese');
  form.addParagraphTextItem()
    .setTitle('Short description of your research')
    .setHelpText('2 to 3 sentences in plain language, 400 characters at ' +
      'most. Write it for a smart reader outside your subfield.')
    .setRequired(true)
    .setValidation(FormApp.createParagraphTextValidation()
      .requireTextLengthLessThanOrEqualTo(400)
      .setHelpText('Please keep this to 400 characters or fewer.')
      .build());
  text_(form, 'Dissertation or thesis title', false,
    'PhD students: your dissertation. Master\'s students: a thesis or ' +
    'capstone title, if you have one.');
  form.addParagraphTextItem()
    .setTitle('Selected work')
    .setHelpText('Up to 3 items, one per line, written as Title | Link. ' +
      'For example: Who Votes Early? | https://example.com/paper.pdf');
  text_(form, 'Courses taught as instructor of record', false,
    'Separate with semicolons, for example: POLS 1101; INTL 1100');

  // Page 5: links
  var linksPage = form.addPageBreakItem()
    .setTitle('Links')
    .setHelpText('All optional. Please paste full links starting with ' +
      'https://');
  ['Photo link', 'Personal website', 'Google Scholar', 'ORCID', 'CV link',
    'LinkedIn', 'Bluesky', 'X (Twitter)'].forEach(function (title) {
    form.addTextItem()
      .setTitle(title)
      .setValidation(FormApp.createTextValidation()
        .requireTextIsUrl()
        .setHelpText('Please paste a full link starting with https://')
        .build());
  });

  // Page 6: open to, privacy, consent
  form.addPageBreakItem().setTitle('Connecting and privacy');
  form.addCheckboxItem()
    .setTitle('I am open to')
    .setHelpText('Check anything you would be happy for other SPIA ' +
      'students to contact you about.')
    .setChoiceValues(VOCAB.openTo);
  form.addCheckboxItem()
    .setTitle('Keep these off my public profile')
    .setHelpText('Anything you check here will never appear on the site. ' +
      'Your name, program, status, subfields, interests, and research ' +
      'description are always shown.')
    .setChoiceValues(VOCAB.hideable);
  form.addCheckboxItem()
    .setTitle('Consent')
    .setChoiceValues(['I agree to have this profile shown publicly on the ' +
      'SPIA Graduate Student Network site. I can ask to remove it at ' +
      'any time.'])
    .setRequired(true);

  // Branching: wire up choices now that the pages exist
  requestItem.setChoices([
    requestItem.createChoice(REQUEST.add, programPage),
    requestItem.createChoice(REQUEST.update, programPage),
    requestItem.createChoice(REQUEST.remove, FormApp.PageNavigationType.SUBMIT)
  ]);
  statusItem.setChoices(VOCAB.status.map(function (s) {
    return statusItem.createChoice(s, s === 'Alumni' ? alumniPage : researchPage);
  }));

  return form;
}

function text_(form, title, required, help) {
  var item = form.addTextItem().setTitle(title).setRequired(!!required);
  if (help) item.setHelpText(help);
  return item;
}

function findResponseSheet_(ss) {
  var sheets = ss.getSheets();
  for (var i = 0; i < sheets.length; i++) {
    if (sheets[i].getFormUrl()) return sheets[i];
  }
  throw new Error('Could not find the form response tab. Try running setup again.');
}

function addAdminColumns_(sheet) {
  var start = sheet.getLastColumn() + 1;
  sheet.getRange(1, start, 1, CONFIG.adminColumns.length)
    .setValues([CONFIG.adminColumns])
    .setFontWeight('bold')
    .setBackground('#fff2cc');

  var rule = SpreadsheetApp.newDataValidation()
    .requireValueInList(CONFIG.reviewOptions, true)
    .setAllowInvalid(false)
    .build();
  sheet.getRange(2, start, sheet.getMaxRows() - 1, 1).setDataValidation(rule);
  sheet.setFrozenRows(1);
}

function removeDefaultTab_(ss, keep) {
  ss.getSheets().forEach(function (s) {
    if (s.getSheetId() !== keep.getSheetId() && s.getLastRow() === 0) {
      ss.deleteSheet(s);
    }
  });
}

/**
 * Runs on every submission: marks the row Pending, fills in an id,
 * and emails the person who ran setup (the admin).
 */
function onFormSubmitHandler(e) {
  var sheet = e.range.getSheet();
  var row = e.range.getRow();
  var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];
  var col = function (name) { return headers.indexOf(name) + 1; };

  var get = function (name) {
    var c = col(name);
    return c > 0 ? String(sheet.getRange(row, c).getValue()).trim() : '';
  };

  var email = get('Email address').toLowerCase();
  var id = findExistingId_(sheet, headers, email, row) ||
    makeId_(get('First name'), get('Last name'), get('Year you entered the program'));

  sheet.getRange(row, col('review_status')).setValue('Pending');
  sheet.getRange(row, col('id')).setValue(id);

  var request = get('What would you like to do?');
  var name = get('First name') + ' ' + get('Last name');
  MailApp.sendEmail(
    Session.getEffectiveUser().getEmail(),
    'GSN: ' + request + ' (' + name + ')',
    name + ' submitted the profile form.\n\n' +
    'Request: ' + request + '\n' +
    'Email: ' + email + '\n' +
    'Row: ' + row + '\n\n' +
    (request === REQUEST.remove
      ? 'Removal requests take effect at the next site build. No action needed.\n'
      : 'To publish it, set review_status to Approved in the sheet.\n') +
    e.range.getSheet().getParent().getUrl());
}

/** If this email submitted before, reuse that id so the profile URL stays the same. */
function findExistingId_(sheet, headers, email, currentRow) {
  var emailCol = headers.indexOf('Email address');
  var idCol = headers.indexOf('id');
  if (emailCol < 0 || idCol < 0 || currentRow < 3) return '';
  var data = sheet.getRange(2, 1, currentRow - 2, headers.length).getValues();
  for (var i = data.length - 1; i >= 0; i--) {
    if (String(data[i][emailCol]).trim().toLowerCase() === email && data[i][idCol]) {
      return String(data[i][idCol]);
    }
  }
  return '';
}

/** Builds ids like jdoe-2021 (first initial, last name, cohort year). */
function makeId_(first, last, cohort) {
  var slug = function (s) {
    return s.normalize('NFD').replace(/[̀-ͯ]/g, '')
      .toLowerCase().replace(/[^a-z0-9]+/g, '');
  };
  var base = slug(first).charAt(0) + slug(last);
  return cohort ? base + '-' + cohort : base;
}
