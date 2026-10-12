import QtQuick
import qs.Commons

// The desktop's voice, drawn: a small neural network. Nodes, the connections between
// them, and signals travelling along those connections.
//
// It is the picture of the thing it stands for. At rest a signal crosses now and then
// and the nodes drift a little, the way something idling does. While it listens the
// signals run inwards, towards the middle, and everything is red, as a recording light
// is; while it speaks they run outwards, many at once, and each node flares as a signal
// reaches it.
//
// One drawing for both places it is shown -- the small card in the corner and the large
// one on the dashboard -- so they are plainly the same thing at two sizes. Everything in
// it is a fraction of its own width, which is what lets it be either.
//
//   lively     listening or speaking: every connection carries signals, and quickly
//   listening  the microphone is open: red, and the signals run inwards
//   awake      something is going on at all; when not, it idles
//   running    whether to animate at all. It repaints many times a second, which is
//              only worth doing where somebody can see it. Stopped, it is the network
//              alone, with no signals caught halfway along a line.
//   simple     the bar's size. Seventeen nodes in twenty pixels is a smudge, so there it
//              is the middle node and the ring of six, drawn heavier and filling the
//              square -- the same face with the outer layer left off.
Item {
  id: orb

  property bool awake: false
  property bool lively: false
  property bool listening: false
  property bool running: true
  property bool simple: false

  // Not readonly: the bar draws it in the colour of the module it stands in.
  property color tint: listening ? Color.popupUrgent : Color.popupAccent
  // Signals are a second colour, so that what moves is told from what it moves along.
  property color spark: listening ? Color.popupUrgent : Color.good

  // How much heavier everything is drawn when there are fewer, larger pieces.
  readonly property real weight: simple ? 2.4 : 1

  implicitWidth: Style.voiceOrbSize
  implicitHeight: implicitWidth
  opacity: awake ? 1 : 0.7

  Behavior on opacity {
    NumberAnimation {
      duration: Style.motionEnter
    }
  }

  // How busy it is, 0 to 1, eased towards where it should be so that starting and
  // stopping to speak is a swell and not a switch.
  property real activity: lively ? 1 : (awake ? 0.45 : 0.16)

  Behavior on activity {
    NumberAnimation {
      duration: 500
      easing.type: Easing.OutCubic
    }
  }

  // Time, for everything that moves. Advanced by a timer rather than left to an
  // animation so that it can simply stop when nobody is looking.
  property real t: 0

  Timer {
    interval: orb.lively ? 33 : 50
    repeat: true
    running: orb.running && orb.visible
    onTriggered: {
      orb.t += interval / 1000;
      canvas.requestPaint();
    }
  }

  onTintChanged: canvas.requestPaint()
  onSparkChanged: canvas.requestPaint()
  onRunningChanged: canvas.requestPaint()
  onSimpleChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()

  // The network: where each node sits, on a square of 100, and which are connected.
  // Fixed, and not drawn at random each time: it should be the same face every day. One
  // node in the middle, a ring of six round it and a looser ring of ten outside -- three
  // layers, which is what makes it read as a network and not a constellation.
  readonly property var nodes: {
    var out = [{
        x: 50,
        y: 50,
        layer: 0
      }];
    for (var i = 0; i < 6; i++) {
      var a = i * Math.PI / 3 + 0.35;
      var ring = orb.simple ? 36 : 19;
      out.push({
        x: 50 + Math.cos(a) * ring,
        y: 50 + Math.sin(a) * ring,
        layer: 1
      });
    }
    if (orb.simple)
      return out;
    for (var j = 0; j < 10; j++) {
      var b = j * Math.PI / 5 + 0.1;
      // Not a perfect circle: every other one sits a little further out.
      var reach = j % 2 === 0 ? 40 : 34;
      out.push({
        x: 50 + Math.cos(b) * reach,
        y: 50 + Math.sin(b) * reach,
        layer: 2
      });
    }
    return out;
  }

  // Each connection from the inner node to the outer one, so "outwards" has a meaning.
  readonly property var links: {
    var out = [];
    var i;
    for (i = 1; i <= 6; i++) {
      out.push([0, i]);
      out.push([i, i % 6 + 1]);
    }
    if (orb.simple)
      return out;
    for (i = 0; i < 10; i++) {
      var outer = 7 + i;
      // To the two nearest of the inner ring.
      var near = 1 + Math.round(i * 0.6) % 6;
      out.push([near, outer]);
      out.push([1 + (near % 6), outer]);
      if (i % 2 === 0)
        out.push([outer, 7 + (i + 1) % 10]);
    }
    return out;
  }

  Canvas {
    id: canvas

    anchors.fill: parent

    function shade(color, alpha) {
      return Qt.rgba(color.r, color.g, color.b, Math.max(0, Math.min(1, alpha)));
    }

    onPaint: {
      var ctx = getContext("2d");
      ctx.reset();
      var unit = width / 100;
      var t = orb.t;
      var busy = orb.activity;
      var nodes = orb.nodes;
      var links = orb.links;
      var heavy = orb.weight;
      var i;

      // Where each node is now: its place, and a slow drift round it, each on its own.
      var at = [];
      for (i = 0; i < nodes.length; i++) {
        var drift = nodes[i].layer * 1.1;
        at.push({
          x: (nodes[i].x + Math.sin(t * 0.7 + i * 2.1) * drift) * unit,
          y: (nodes[i].y + Math.cos(t * 0.6 + i * 1.3) * drift) * unit,
          glow: 0
        });
      }

      // The light behind it. Not at the bar's size, where it is a smear on the bar.
      if (!orb.simple) {
        var halo = ctx.createRadialGradient(50 * unit, 50 * unit, 0, 50 * unit, 50 * unit, 46 * unit);
        halo.addColorStop(0, shade(orb.tint, 0.16 + 0.12 * busy));
        halo.addColorStop(1, shade(orb.tint, 0));
        ctx.fillStyle = halo;
        ctx.fillRect(0, 0, width, height);
      }

      // The connections, and the signals on them.
      ctx.lineCap = "round";
      var sparks = [];
      for (i = 0; i < links.length; i++) {
        var from = at[links[i][0]];
        var to = at[links[i][1]];
        ctx.lineWidth = Math.max(orb.simple ? 1 : 0.6, 0.9 * unit * heavy);
        ctx.strokeStyle = shade(orb.tint, (orb.simple ? 0.4 : 0.16) + 0.2 * busy);
        ctx.beginPath();
        ctx.moveTo(from.x, from.y);
        ctx.lineTo(to.x, to.y);
        ctx.stroke();

        // Stopped, nothing travels: a signal frozen halfway is a stray dot.
        if (!orb.running)
          continue;
        // At rest only some connections carry anything; busy, all of them do. Which
        // ones is decided by where the connection is in the list, so it does not flicker.
        if ((i * 7) % 10 >= busy * 10)
          continue;
        var speed = 0.25 + 0.75 * busy + (i % 4) * 0.08;
        var along = (t * speed + i * 0.37) % 1;
        // Listening, a signal runs from the outside in; otherwise from the middle out.
        var place = orb.listening ? 1 - along : along;
        sparks.push({
          x: from.x + (to.x - from.x) * place,
          y: from.y + (to.y - from.y) * place,
          // Brightest in the middle of its run, gone at either end.
          strength: Math.sin(along * Math.PI)
        });
        // A signal arriving lights the node it arrives at.
        var arriving = orb.listening ? links[i][0] : links[i][1];
        if (along > 0.82)
          at[arriving].glow = Math.max(at[arriving].glow, (along - 0.82) / 0.18);
      }

      // The nodes, the middle one largest.
      for (i = 0; i < at.length; i++) {
        var layer = nodes[i].layer;
        var size = (layer === 0 ? 5.2 : layer === 1 ? 3.1 : 2.2) * unit * heavy;
        var spread = orb.simple ? 1.9 : 3.2;
        var lit = at[i].glow * busy;
        var beat = layer === 0 ? 0.5 + 0.5 * Math.sin(t * (1.4 + 3.4 * busy)) : 0;
        if (lit > 0.05 || layer === 0) {
          var flare = ctx.createRadialGradient(at[i].x, at[i].y, 0, at[i].x, at[i].y, size * spread);
          flare.addColorStop(0, shade(layer === 0 ? orb.tint : orb.spark, 0.5 * Math.max(lit, layer === 0 ? 0.35 + 0.35 * beat * busy : 0)));
          flare.addColorStop(1, shade(orb.tint, 0));
          ctx.fillStyle = flare;
          ctx.beginPath();
          ctx.arc(at[i].x, at[i].y, size * spread, 0, Math.PI * 2);
          ctx.fill();
        }
        ctx.fillStyle = shade(orb.tint, 0.55 + 0.45 * Math.max(lit, layer === 0 ? 1 : 0.15));
        ctx.beginPath();
        ctx.arc(at[i].x, at[i].y, size * (1 + 0.25 * lit + 0.12 * beat * busy), 0, Math.PI * 2);
        ctx.fill();
        if (layer === 0) {
          ctx.fillStyle = Qt.rgba(1, 1, 1, 0.75);
          ctx.beginPath();
          ctx.arc(at[i].x, at[i].y, size * 0.42, 0, Math.PI * 2);
          ctx.fill();
        }
      }

      // The signals last, so they run over the lines and not under them.
      for (i = 0; i < sparks.length; i++) {
        var s = sparks[i];
        var r = (1.5 + 0.9 * s.strength) * unit * heavy;
        var light = ctx.createRadialGradient(s.x, s.y, 0, s.x, s.y, r * 2.6);
        light.addColorStop(0, shade(orb.spark, 0.9 * s.strength));
        light.addColorStop(1, shade(orb.spark, 0));
        ctx.fillStyle = light;
        ctx.beginPath();
        ctx.arc(s.x, s.y, r * 2.6, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.85 * s.strength);
        ctx.beginPath();
        ctx.arc(s.x, s.y, r * 0.5, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }
}
