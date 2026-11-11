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

// Who a notification is from: the application, or for a browser the site, as the toast's
// header already shows it. notify-send without --app-name is nobody in particular.
function sender(app, body, fromBrowser) {
  if (fromBrowser) {
    var split = originSplit(body);
    if (split)
      return split.origin.toLowerCase();
  }
  app = String(app || "");
  return app === "" || app === "notify-send" ? "Other" : app;
}

// Which conversation a notification belongs to: its sender and its title. A group chat
// sends each message with the chat's name as the title -- 34 from "ivo, merijn" in one
// afternoon -- so the title is what tells one conversation from the next. Case and runs
// of spaces do not make a second one.
function thread(app, summary, body, fromBrowser) {
  return sender(app, body, fromBrowser) + "\u0001" + String(summary || "").replace(/\s+/g, " ").trim().toLowerCase();
}

// Rows -- anything with a `key` from thread() -- gathered into conversations, in the order
// the rows came: given newest first, the first row of each is its newest message and the
// conversations come out newest first too.
function threads(rows) {
  var byKey = {};
  var order = [];
  for (var i = 0; i < rows.length; i++) {
    var key = rows[i].key;
    if (byKey[key] === undefined) {
      byKey[key] = [];
      order.push(key);
    }
    byKey[key].push(rows[i]);
  }
  var out = [];
  for (var t = 0; t < order.length; t++)
    out.push({ key: order[t], newest: byKey[order[t]][0], rows: byKey[order[t]] });
  return out;
}

if (typeof module !== "undefined")
  module.exports = { originSplit: originSplit, browser: browser, chatHost: chatHost, kept: kept, sender: sender, thread: thread, threads: threads };
