// Which notifications stay in the notification centre once their toast has gone.
//
// Kept free of QML so node can run it: test/notifications-test.sh does.

// A browser names itself, not the site: a web app's notification arrives as
//
//   app_name "Brave"  body "chat.example.com\n\n@someone: ..."
//
// Split only on something that looks like a host: one line, no spaces, at least one dot,
// followed by a blank line. A body that merely opens with a short sentence is left alone.
function originSplit(body) {
  body = String(body || "");
  var brk = body.indexOf("\n\n");
  if (brk <= 0)
    return null;
  var head = body.slice(0, brk).trim();
  if (head === "" || head.indexOf(" ") !== -1 || head.indexOf(".") === -1)
    return null;
  return { origin: head, rest: body.slice(brk + 2).trim() };
}

// Whether a desktop entry or an application name is a browser's.
function browser(name) {
  name = String(name || "").toLowerCase();
  return name.indexOf("brave") !== -1 || name.indexOf("chrom") !== -1 || name.indexOf("firefox") !== -1;
}

// The host a CHAT_URL="https://..." line in chat.conf names, or "" without one.
function chatHost(conf) {
  var m = /^\s*CHAT_URL=["']?[a-z]+:\/\/([^\/"'\s:]+)/m.exec(String(conf || ""));
  return m ? m[1].toLowerCase() : "";
}

// Kept when the sender is on the list: an application's own name, or for a browser the
// site it came from. A notification that only passes the time of day -- a screenshot
// saved, a setting toggled -- is read in its toast or not at all.
function kept(app, body, fromBrowser, remember) {
  var sender = String(app || "");
  if (fromBrowser) {
    var split = originSplit(body);
    if (!split)
      return false;
    sender = split.origin.toLowerCase();
  }
  return remember.indexOf(sender) !== -1;
}

if (typeof module !== "undefined")
  module.exports = { originSplit: originSplit, browser: browser, chatHost: chatHost, kept: kept };
