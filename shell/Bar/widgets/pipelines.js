// The pipelines widget's tooltip, laid out the way the bar's other tooltips are: a title
// line that answers the hover, the detail under it, and what a click does last.
//
// Kept free of QML so node can run it: test/pipelines-layout-test.sh does.

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

// A line is a list of pieces, each a text and the colour it is drawn in -- "" for the
// tooltip's own. Plain, they are just joined; styled, each is escaped and coloured.
function piece(text, colour) {
  return { text: text, colour: colour || "" };
}

function escape(text) {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    // StyledText runs spaces together, and the layout is made of them.
    .replace(/ /g, "&nbsp;");
}

function render(lines, styled) {
  return lines.map(function (line) {
    return line.map(function (p) {
      if (!styled)
        return p.text;
      return p.colour ? '<font color="' + p.colour + '">' + escape(p.text) + "</font>" : escape(p.text);
    }).join("");
  }).join(styled ? "<br>" : "\n");
}

// requests: what desktop-pipelines leaves in pipelines.json. first: the one a click
// opens. stale: GitLab could not be reached, and this is as it was last seen.
// colours: the bar's, by status and "muted" -- given, the result is StyledText with
// each status mark in its colour and the titles quieter than the names; left out, it
// is plain text.
function tooltip(requests, first, stale, colours) {
  requests = requests || [];
  var c = colours || {};
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
      counts.push(piece(n + " " + words[status], c[status]));
  });

  var head = [piece("Pipelines")];
  counts.forEach(function (p, i) {
    head.push(piece(i === 0 ? "  \u00b7  " : ", "), p);
  });
  var lines = [head];
  if (stale)
    lines.push([piece("GitLab not reachable, as last seen", c.muted)]);

  // Sorted by how much it matters; the order the timer found them in breaks ties.
  var sorted = withPipeline.map(function (r, i) {
    return { r: r, i: i };
  }).sort(function (a, b) {
    return rank(a.r.status) - rank(b.r.status) || a.i - b.i;
  }).map(function (x) {
    return x.r;
  });

  if (sorted.length)
    lines.push([]);
  sorted.slice(0, shown).forEach(function (r) {
    var mark = (glyphs[r.status] || "") + "  ";
    var rest = cut(name(r.ref) + (isDraft(r) ? "  draft" : ""), width - mark.length);
    lines.push([piece(mark, c[r.status]), piece(rest)]);
    lines.push([piece(indent + cut(title(r.title), width - indent.length), c.muted)]);
  });

  var more = [];
  if (sorted.length > shown)
    more.push((sorted.length - shown) + " more");
  if (without > 0)
    more.push(without + " without a pipeline");
  if (more.length)
    lines.push([], [piece(more.join("  \u00b7  "), c.muted)]);

  // Inside the 40 characters: a longer hint wrapped onto a second line.
  lines.push([], [piece(first && first.status !== "none" ? "Click: details \u00b7 right-click: " + words[first.status] : "Click for details")]);
  return render(lines, !!colours);
}

// The panel's sections: one per GitLab desktop-pipelines asks -- every host glab is
// logged in to, in the order it asks them -- with its merge requests that have a pipeline,
// most urgent first, and how many have none. A host with nothing open is still a section,
// so a GitLab you added shows up before you have opened anything on it.
function groups(info) {
  info = info || {};
  var requests = info.requests || [];
  var hosts = (info.hosts || []).map(function (h) {
    return h.host;
  });
  requests.forEach(function (r) {
    if (hosts.indexOf(r.host) === -1)
      hosts.push(r.host);
  });
  return hosts.map(function (host) {
    var state = (info.hosts || []).filter(function (h) {
      return h.host === host;
    }).map(function (h) {
      return h.state;
    })[0] || "ok";
    var mine = requests.filter(function (r) {
      return r.host === host;
    });
    var listed = mine.filter(function (r) {
      return r.status !== "none";
    }).map(function (r, i) {
      return { r: r, i: i };
    }).sort(function (a, b) {
      return rank(a.r.status) - rank(b.r.status) || a.i - b.i;
    }).map(function (x) {
      return {
        status: x.r.status,
        glyph: glyphs[x.r.status] || "",
        urgent: x.r.status === "failed" || x.r.status === "running" || x.r.status === "pending",
        name: name(x.r.ref) + (isDraft(x.r) ? "  draft" : ""),
        title: title(x.r.title),
        word: words[x.r.status],
        pipelineUrl: x.r.pipelineUrl,
        url: x.r.url
      };
    });
    return {
      host: host,
      reachable: state === "ok",
      open: mine.length,
      requests: listed,
      without: mine.length - listed.length
    };
  });
}

// The panel's headline, in words: the worst there is, or that all is quiet.
function summary(info) {
  var requests = (info && info.requests) || [];
  if (requests.length === 0)
    return "nothing open";
  for (var i = 0; i < order.length; i++) {
    var n = requests.filter(function (r) {
      return r.status === order[i];
    }).length;
    if (n > 0 && order[i] !== "success")
      return n + " " + words[order[i]];
  }
  return requests.some(function (r) {
    return r.status === "success";
  }) ? "all passed" : "no pipelines";
}

if (typeof module !== "undefined")
  module.exports = { tooltip: tooltip, name: name, title: title, groups: groups, summary: summary };
