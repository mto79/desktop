import QtQuick
import qs.Commons

// A line through a series of numbers, with the ground under it shaded: where something
// has been going. It is drawn from left to right when it appears.
Item {
  id: trend

  property var values: []
  property color tone: Color.popupAccent
  property bool appear: true

  implicitHeight: 110
  clip: true

  Item {
    id: reveal

    height: parent.height
    width: trend.appear ? trend.width : 0
    clip: true

    Behavior on width {
      NumberAnimation {
        duration: 900
        easing.type: Easing.OutCubic
      }
    }

    Canvas {
      id: canvas

      width: trend.width
      height: trend.height

      onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var v = trend.values;
        if (!v || v.length < 2)
          return;
        var low = Math.min.apply(null, v);
        var high = Math.max.apply(null, v);
        var span = high - low || 1;
        var pad = 6;
        function x(i) {
          return pad + (width - pad * 2) * i / (v.length - 1);
        }
        function y(n) {
          return height - pad - (height - pad * 2) * (n - low) / span;
        }
        ctx.beginPath();
        ctx.moveTo(x(0), y(v[0]));
        for (var i = 1; i < v.length; i++)
          ctx.lineTo(x(i), y(v[i]));
        ctx.lineWidth = 2;
        ctx.strokeStyle = trend.tone;
        ctx.lineJoin = "round";
        ctx.stroke();
        ctx.lineTo(x(v.length - 1), height);
        ctx.lineTo(x(0), height);
        ctx.closePath();
        ctx.fillStyle = Qt.rgba(trend.tone.r, trend.tone.g, trend.tone.b, 0.14);
        ctx.fill();
      }
    }
  }

  onValuesChanged: canvas.requestPaint()
  onToneChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
}
