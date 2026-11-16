// Directory filters, search, and views.
//
// The page embeds the already-cleaned data as JSON (see index.qmd), so
// nothing here can show a hidden field: hidden values never reach the
// browser. Filters are kept in the URL (for example ?interest=voting)
// so tag links on other pages open the directory pre-filtered, and any
// filtered view can be bookmarked or shared.
(function () {
  "use strict";

  var data = JSON.parse(document.getElementById("people-data").textContent);
  var people = data.people;
  var opts = data.options;

  var SELECTS = ["program", "status", "subfield", "method", "region", "cohort"];
  var FIELD = { subfield: "subfields", method: "methods", region: "regions" };

  var el = function (id) { return document.getElementById(id); };
  var esc = function (s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  };
  var arr = function (x) { return Array.isArray(x) ? x : (x == null ? [] : [x]); };

  // ---- build the controls ---------------------------------------------------
  SELECTS.forEach(function (key) {
    var sel = el("f-" + key);
    opts[key].forEach(function (v) {
      var o = document.createElement("option");
      o.value = v; o.textContent = v;
      sel.appendChild(o);
    });
  });

  var openBox = el("open-filters");
  opts.open.forEach(function (o) {
    var id = "open-" + o.field;
    var label = document.createElement("label");
    label.setAttribute("for", id);
    label.innerHTML = '<input type="checkbox" id="' + id + '" value="' + esc(o.field) + '"> ' + esc(o.label);
    openBox.appendChild(label);
  });

  var lettersWithPeople = {};
  people.forEach(function (p) { lettersWithPeople[p.last.charAt(0).toUpperCase()] = true; });
  var letterBox = el("letters");
  "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("").forEach(function (L) {
    var b = document.createElement("button");
    b.type = "button"; b.textContent = L; b.dataset.letter = L;
    b.setAttribute("aria-pressed", "false");
    if (!lettersWithPeople[L]) { b.disabled = true; b.setAttribute("aria-label", L + " (no one)"); }
    letterBox.appendChild(b);
  });

  // ---- state <-> URL ------------------------------------------------------------
  var state = {};
  function readUrl() {
    var q = new URLSearchParams(window.location.search);
    state = {
      q: q.get("q") || "",
      interest: q.get("interest") || "",
      letter: q.get("letter") || "",
      open: (q.get("open") || "").split(",").filter(Boolean),
      sort: q.get("sort") === "cohort" ? "cohort" : "last",
      view: q.get("view") === "table" ? "table" : "cards"
    };
    SELECTS.forEach(function (k) { state[k] = q.get(k) || ""; });
  }
  function writeUrl() {
    var q = new URLSearchParams();
    if (state.q) q.set("q", state.q);
    SELECTS.forEach(function (k) { if (state[k]) q.set(k, state[k]); });
    if (state.interest) q.set("interest", state.interest);
    if (state.letter) q.set("letter", state.letter);
    if (state.open.length) q.set("open", state.open.join(","));
    if (state.sort !== "last") q.set("sort", state.sort);
    if (state.view !== "cards") q.set("view", state.view);
    var s = q.toString();
    history.replaceState(null, "", window.location.pathname + (s ? "?" + s : ""));
  }
  function syncControls() {
    el("q").value = state.q;
    SELECTS.forEach(function (k) { el("f-" + k).value = state[k]; });
    opts.open.forEach(function (o) { el("open-" + o.field).checked = state.open.indexOf(o.field) >= 0; });
    Array.prototype.forEach.call(letterBox.children, function (b) {
      b.setAttribute("aria-pressed", String(b.dataset.letter === state.letter));
    });
    el("sort").value = state.sort;
    document.querySelectorAll(".view-toggle button").forEach(function (b) {
      b.setAttribute("aria-pressed", String(b.dataset.view === state.view));
    });
    var tag = el("active-tag");
    if (state.interest) {
      tag.innerHTML = '<span class="active-tag">Interest: ' + esc(state.interest) +
        ' <button type="button" class="reset-button" id="clear-interest" aria-label="Remove interest filter ' +
        esc(state.interest) + '">×</button></span>';
      el("clear-interest").onclick = function () { state.interest = ""; update(); };
    } else {
      tag.innerHTML = "";
    }
  }

  // ---- filtering ------------------------------------------------------------------
  function matches(p) {
    if (state.program && p.program !== state.program) return false;
    if (state.status && p.status !== state.status) return false;
    if (state.cohort && String(p.cohort) !== state.cohort) return false;
    for (var k in FIELD) {
      if (state[k] && arr(p[FIELD[k]]).indexOf(state[k]) < 0) return false;
    }
    if (state.interest && arr(p.interests).indexOf(state.interest.toLowerCase()) < 0) return false;
    if (state.letter && p.last.charAt(0).toUpperCase() !== state.letter) return false;
    for (var i = 0; i < state.open.length; i++) if (p[state.open[i]] !== true) return false;
    if (state.q) {
      var hay = [p.first, p.last, p.blurb, p.dissertation].concat(arr(p.interests))
        .join(" ").toLowerCase();
      var words = state.q.toLowerCase().split(/\s+/).filter(Boolean);
      for (var w = 0; w < words.length; w++) if (hay.indexOf(words[w]) < 0) return false;
    }
    return true;
  }
  function sorter(a, b) {
    if (state.sort === "cohort") {
      var d = (b.cohort || 0) - (a.cohort || 0);
      if (d !== 0) return d;
    }
    return (a.last + " " + a.first).localeCompare(b.last + " " + b.first);
  }

  // ---- rendering ------------------------------------------------------------------
  var profileHref = function (p) { return "people/" + encodeURIComponent(p.id) + "/index.html"; };
  var statusClass = function (s) {
    return "status-" + s.toLowerCase().replace(/[^a-z]+/g, "-").replace(/-$/, "");
  };
  var ICONS = { "Coursework": "circle", "Candidate (ABD)": "circle-half", "On the job market": "circle-fill",
    "Alumni": "mortarboard-fill", "Faculty (test data)": "square-fill" };
  var badge = function (s) {
    var ic = ICONS[s] ? '<i class="bi bi-' + ICONS[s] + '" aria-hidden="true"></i>' : "";
    return '<span class="status-badge ' + statusClass(s) + '">' + ic + esc(s) + "</span>";
  };
  var initials = function (p) {
    var l = p.last.split(/[\s-]+/);
    return (p.first.charAt(0) + l[l.length - 1].charAt(0)).toUpperCase();
  };
  var avatar = function (p) {
    return p.photo
      ? '<img class="avatar avatar-photo" src="' + esc(p.photo) + '" alt="Photo of ' + esc(p.first + " " + p.last) + '" loading="lazy">'
      : '<div class="avatar avatar-initials" aria-hidden="true">' + esc(initials(p)) + "</div>";
  };
  var interestLink = function (t) {
    return '<a class="tag" href="?interest=' + encodeURIComponent(t) + '">' + esc(t) + "</a>";
  };

  function card(p) {
    var line = p.status === "Alumni"
      ? esc(p.program) + (p.grad_year ? ", " + p.grad_year : "") + (p.current ? "<br>" + esc(p.current) : "")
      : esc(p.program) + (p.cohort ? ", entered " + p.cohort : "");
    return '<article class="person-card">' +
      '<a class="card-photo" href="' + profileHref(p) + '" tabindex="-1" aria-hidden="true">' + avatar(p) + "</a>" +
      '<h2 class="card-name"><a href="' + profileHref(p) + '">' + esc(p.first + " " + p.last) + "</a></h2>" +
      (p.pronouns ? '<p class="card-line">' + esc(p.pronouns) + "</p>" : "") +
      '<p class="card-line">' + badge(p.status) + "</p>" +
      '<p class="card-line">' + line + "</p>" +
      '<p class="card-subfields">' + esc(arr(p.subfields).join(", ")) + "</p>" +
      '<div class="tag-list">' + arr(p.interests).slice(0, 3).map(interestLink).join("") + "</div>" +
      "</article>";
  }
  function table(list) {
    return '<div class="table-scroll"><table class="people-table"><caption class="visually-hidden">Matching people</caption>' +
      "<thead><tr><th scope=\"col\">Name</th><th scope=\"col\">Status</th><th scope=\"col\">Program</th>" +
      "<th scope=\"col\">Entered</th><th scope=\"col\">Subfields</th><th scope=\"col\">Interests</th></tr></thead><tbody>" +
      list.map(function (p) {
        return "<tr><td><a href=\"" + profileHref(p) + "\">" + esc(p.last + ", " + p.first) + "</a></td>" +
          "<td>" + badge(p.status) + "</td><td>" + esc(p.program) + "</td><td>" + esc(p.cohort || "") + "</td>" +
          "<td>" + esc(arr(p.subfields).join(", ")) + "</td>" +
          '<td><div class="tag-list">' + arr(p.interests).slice(0, 3).map(interestLink).join("") + "</div></td></tr>";
      }).join("") + "</tbody></table></div>";
  }

  function update() {
    var list = people.filter(matches).sort(sorter);
    var n = list.length;
    el("result-count").textContent =
      n === 0 ? "No one matches these filters" : n === 1 ? "1 person matches" : n + " people match";
    el("results").innerHTML = n === 0
      ? '<p class="no-results">Try removing a filter, or <button type="button" class="reset-button" id="reset-inline">clear all filters</button>.</p>'
      : state.view === "table" ? table(list)
      : '<div class="card-grid">' + list.map(card).join("") + "</div>";
    var ri = el("reset-inline");
    if (ri) ri.onclick = reset;
    syncControls();
    writeUrl();
  }

  function reset() {
    var keepView = state.view, keepSort = state.sort;
    readUrl();
    state = { q: "", interest: "", letter: "", open: [], sort: keepSort, view: keepView };
    SELECTS.forEach(function (k) { state[k] = ""; });
    update();
  }

  // ---- events ------------------------------------------------------------------------
  var typing;
  el("q").addEventListener("input", function (e) {
    clearTimeout(typing);
    typing = setTimeout(function () { state.q = e.target.value.trim(); update(); }, 150);
  });
  SELECTS.forEach(function (k) {
    el("f-" + k).addEventListener("change", function (e) { state[k] = e.target.value; update(); });
  });
  openBox.addEventListener("change", function () {
    state.open = opts.open.map(function (o) { return o.field; })
      .filter(function (f) { return el("open-" + f).checked; });
    update();
  });
  letterBox.addEventListener("click", function (e) {
    var L = e.target.dataset && e.target.dataset.letter;
    if (!L) return;
    state.letter = state.letter === L ? "" : L;
    update();
  });
  el("sort").addEventListener("change", function (e) { state.sort = e.target.value; update(); });
  document.querySelectorAll(".view-toggle button").forEach(function (b) {
    b.addEventListener("click", function () { state.view = b.dataset.view; update(); });
  });
  el("reset").addEventListener("click", reset);
  // Clicking an interest tag inside the directory filters in place.
  el("results").addEventListener("click", function (e) {
    var a = e.target.closest && e.target.closest("a.tag");
    if (!a) return;
    e.preventDefault();
    state.interest = new URLSearchParams(a.getAttribute("href").slice(1)).get("interest") || "";
    update();
    el("result-count").scrollIntoView({ block: "start" });
  });

  readUrl();
  update();
})();
