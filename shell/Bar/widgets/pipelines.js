// The pipelines widget's tooltip, laid out the way the bar's other tooltips are: a title
// line that answers the hover, the detail under it, and what a click does last.
//
// Kept free of QML so node can run it: test/pipelines-tooltip-test.sh does.

// Most urgent first. "none" -- a merge request with no pipeline -- is not listed one by
// one: it says nothing about CI, and four of them pushed the ones that did off the end.
var order = ["failed", "running", "pending", "success", "canceled"];

var words = {
  failed: "failed",
  running: "running",
  pending: "waiting",
  success: "passed",
  canceled: "cancelled",
  none: "no pipeline"
};

// The bar font's: a filled circle for an outcome, a clock for one still to come.
var glyphs = {
  failed: "\u{f0159}",
  running: "\u{f0996}",
  pending: "\u{f0150}",
  success: "\u{f05e0}",
  canceled: "\u{f073a}"
};

// The tooltip is 320px of a 13px monospace font, 8px a character: 40 characters a line.
var width = 40;
var indent = "   ";
var shown = 6;

function cut(text, max) {
  return text.length <= max ? text : text.slice(0, max - 1).replace(/\s+$/, "") + "…";
}

// "tb/openshift/ocp-helm-charts!484" -> "ocp-helm-charts !484": the group path is the same
// for nearly every one, and the project is what you know a merge request by.
function name(ref) {
  var match = /([^/]+)!(\d+)$/.exec(ref || "");
  return match ? match[1] + " !" + match[2] : ref || "";
}

// GitLab's own "Draft: " prefix, said once after the name instead of eating the title.
function title(text) {
  return (text || "").replace(/^\s*(Draft|WIP)\s*:\s*/i, "").trim();
}

function isDraft(request) {
  return !!request.draft || /^\s*(Draft|WIP)\s*:/i.test(request.title || "");
}

function rank(status) {
  var i = order.indexOf(status);
  return i === -1 ? order.length : i;
}

// requests: what desktop-pipelines leaves in pipelines.json. first: the one a click
// opens. stale: GitLab could not be reached, and this is as it was last seen.
function tooltip(requests, first, stale) {
  requests = requests || [];
  var withPipeline = requests.filter(function (r) {
    return r.status !== "none";
  });
  var without = requests.length - withPipeline.length;

  var counts = [];
  order.forEach(function (status) {
    var n = withPipeline.filter(function (r) {
      return r.status === status;
    }).length;
    if (n > 0)
      counts.push(n + " " + words[status]);
  });

  var lines = ["Pipelines" + (counts.length ? "  ·  " + counts.join(", ") : "")];
  if (stale)
    lines.push("GitLab not reachable, as last seen");

  // Sorted by how much it matters; the order the timer found them in breaks ties.
  var sorted = withPipeline.map(function (r, i) {
    return { r: r, i: i };
  }).sort(function (a, b) {
    return rank(a.r.status) - rank(b.r.status) || a.i - b.i;
  }).map(function (x) {
    return x.r;
  });

  if (sorted.length)
    lines.push("");
  sorted.slice(0, shown).forEach(function (r) {
    var head = (glyphs[r.status] || "") + "  " + name(r.ref);
    if (isDraft(r))
      head += "  draft";
    lines.push(cut(head, width));
    lines.push(indent + cut(title(r.title), width - indent.length));
  });

  var rest = [];
  if (sorted.length > shown)
    rest.push((sorted.length - shown) + " more");
  if (without > 0)
    rest.push(without + " without a pipeline");
  if (rest.length)
    lines.push("", rest.join("  \u00b7  "));

  // Inside the 40 characters: a longer hint wrapped onto a second line.
  lines.push("", first && first.status !== "none" ? "Click: " + words[first.status] + "  \u00b7  right-click: all MRs" : "Right-click: all your MRs");
  return lines.join("\n");
}

if (typeof module !== "undefined")
  module.exports = { tooltip: tooltip, name: name, title: title };
