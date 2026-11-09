import QtQuick
import QtQuick3D
import qs.Commons

// The planet, in 3D, with what desktop-scanner knows about it as dots.
//
// A QtQuick3D scene rather than a Canvas: thousands of points have to turn with the earth,
// and the GPU does that for nothing where a Canvas would redraw each of them on the CPU
// every frame. The dots come from a file per layer (FileInstancing), so ten thousand
// aircraft are one draw call and no QML objects at all.
//
// A frame only costs something when something changed, so what it costs is decided by what
// moves. It turns while nobody is using it, and only then: not once a dot is chosen, not
// zoomed in, and not for more than a minute after the last touch. After that it holds still
// and draws nothing at all. Nothing else here animates forever, on purpose: one endless
// animation anywhere in the scene would redraw the whole planet at the monitor's refresh rate.
//
// The texture is NASA's Black Marble 2016 (public domain).
Item {
  id: globe

  // [{ key, label, colour, file, rows: [[lat, lon, name, detail], ...] }]
  property var layers: []
  // Layers that come and go with where it is looking, the webcams: kept apart, so that new
  // ones do not hand the GPU the ten thousand aircraft again.
  property var extra: []
  // Keys switched off.
  property var hidden: ({})
  property bool running: false
  // A place to mark, or null: { lat, lon }.
  property var home: null
  property var picked: null

  // Where it is looking: spun round the pole, then tilted, so the poles stay upright.
  property real spin: -5
  property real tilt: 25
  property real distance: 285

  readonly property real radius: 100
  // How far above the surface the camera is. Everything that depends on zoom goes by this.
  readonly property real altitude: distance - radius
  // At the middle of the view, one pixel is this many degrees of the planet.
  readonly property real degreesPerPixel: 2 * altitude * Math.tan(22.5 * Math.PI / 180) * (180 / (Math.PI * radius)) / Math.max(1, height)
  // Dots keep their size on screen as the camera nears, and grow a little, so that a plane
  // is something to aim at. Without this one aircraft fills the view at the closest zoom.
  readonly property real dotScale: altitude / 185 * (1 + (1 - Math.min(1, altitude / 185)) * 1.5)
  // A minute after anything was last done, it stops turning. Touched again, it may resume.
  property bool settled: false

  signal chosen(var point)
  // Where it is looking, once it has stopped moving for a moment: the middle of the view
  // and how high above it the camera is.
  signal looked(real lat, real lon, real altitude)

  Timer {
    id: still

    interval: 1200
    onTriggered: globe.looked(globe.tilt, ((-globe.spin + 180) % 360 + 360) % 360 - 180, globe.altitude)
  }
  onSpinChanged: if (!going.running) still.restart()
  onTiltChanged: still.restart()
  onDistanceChanged: still.restart()

  // The same sum as position() in desktop-scanner. Longitude 0 faces +z, east goes to +x.
  function spot(lat, lon, lift) {
    var a = lat * Math.PI / 180, b = lon * Math.PI / 180, r = globe.radius + lift;
    return Qt.vector3d(r * Math.cos(a) * Math.sin(b), r * Math.sin(a), r * Math.cos(a) * Math.cos(b));
  }

  // Every dot by the two-degree square it is in, so that finding the one under the pointer
  // looks at a handful and not at all ten thousand on every movement.
  readonly property real cell: 2
  readonly property var grid: {
    var out = {};
    var all = layers.concat(extra);
    for (var l = 0; l < all.length; l++) {
      var rows = all[l].rows;
      for (var i = 0; i < rows.length; i++) {
        var key = Math.floor(rows[i][0] / cell) + ":" + wrapCell(Math.floor(rows[i][1] / cell));
        (out[key] = out[key] || []).push([all[l], rows[i]]);
      }
    }
    return out;
  }

  function wrapCell(at) {
    var all = Math.round(360 / cell);
    return ((at + all / 2) % all + all) % all;
  }

  // What is under the pointer: a coordinate from where the ray meets the sphere, then the
  // nearest dot to it, within a finger's width of screen. Null off the planet.
  function under(x, y) {
    var hit = view.pick(x, y);
    if (!hit || hit.objectHit !== earth)
      return null;
    var p = turned.mapPositionFromScene(hit.scenePosition);
    // By the direction and not by the radius: the built-in sphere is facets, and a hit on one
    // is short of the true radius, which put a click most of a degree off when zoomed in.
    var lat = Math.atan2(p.y, Math.sqrt(p.x * p.x + p.z * p.z)) * 180 / Math.PI;
    var lon = Math.atan2(p.x, p.z) * 180 / Math.PI;
    var reach = Math.max(0.01, 14 * degreesPerPixel);
    var squeeze = Math.max(0.15, Math.cos(lat * Math.PI / 180));
    var best = null, nearest = reach * reach;
    var cells = Math.ceil(reach / cell), across = Math.ceil(reach / squeeze / cell);
    var homeLat = Math.floor(lat / cell), homeLon = Math.floor(lon / cell);
    for (var y = -cells; y <= cells; y++) {
      for (var x = -across; x <= across; x++) {
        var found = grid[(homeLat + y) + ":" + wrapCell(homeLon + x)];
        if (!found)
          continue;
        for (var i = 0; i < found.length; i++) {
          var layer = found[i][0], row = found[i][1];
          if (hidden[layer.key])
            continue;
          var dlat = row[0] - lat, dlon = row[1] - lon;
          if (dlon > 180)
            dlon -= 360;
          else if (dlon < -180)
            dlon += 360;
          dlon *= squeeze;
          var d = dlat * dlat + dlon * dlon;
          if (d < nearest) {
            nearest = d;
            best = {
              lat: row[0],
              lon: row[1],
              name: row[2],
              detail: row[3],
              layer: layer.label,
              key: layer.key,
              colour: layer.colour,
              hex: layer.key === "planes" || layer.key === "live" ? row[4] : "",
              cam: layer.key === "webcams" ? row[4] : -1,
              link: layer.key === "events" ? row[4] : "",
              heading: layer.key === "planes" || layer.key === "live" ? row[5] : null
            };
          }
        }
      }
    }
    return {
      lat: lat,
      lon: lon,
      point: best
    };
  }

  // Bring a place round to face the camera, and nearer if `closer` says so.
  function face(lat, lon, closer) {
    var target = -lon;
    // The short way round, whatever spin has wound up to.
    target += Math.round((spin - target) / 360) * 360;
    toSpin.to = target;
    toTilt.to = Math.max(-80, Math.min(80, lat));
    toDistance.to = closer ? globe.radius + Math.max(2.5, altitude * closer) : distance;
    going.restart();
    touch();
  }

  function touch() {
    settled = false;
    rest.restart();
  }

  ParallelAnimation {
    id: going

    NumberAnimation {
      id: toSpin

      target: globe
      property: "spin"
      duration: 500
      easing.type: Easing.InOutCubic
    }
    NumberAnimation {
      id: toTilt

      target: globe
      property: "tilt"
      duration: 500
      easing.type: Easing.InOutCubic
    }
    NumberAnimation {
      id: toDistance

      target: globe
      property: "distance"
      duration: 500
      easing.type: Easing.InOutCubic
    }
  }

  Timer {
    id: rest

    interval: 60000
    running: globe.running
    onTriggered: globe.settled = true
  }

  View3D {
    id: view

    anchors.fill: parent
    camera: camera
    environment: SceneEnvironment {
      backgroundMode: SceneEnvironment.Transparent
      antialiasingMode: SceneEnvironment.MSAA
      // Medium is 4x. High is 8x, on a view this size, for edges nobody could tell apart.
      antialiasingQuality: SceneEnvironment.Medium
    }

    PerspectiveCamera {
      id: camera

      z: globe.distance
      fieldOfView: 45
      clipNear: 0.2
      clipFar: 2000
    }
    DirectionalLight {
      eulerRotation.y: -25
      eulerRotation.x: -15
      brightness: 0.55
    }

    Node {
      eulerRotation.x: globe.tilt

      Node {
        id: turned

        eulerRotation.y: globe.spin

        Model {
          id: earth

          source: "#Sphere"
          // The built-in sphere has a radius of 50.
          scale: Qt.vector3d(2, 2, 2)
          pickable: true
          materials: PrincipledMaterial {
            baseColorMap: Texture {
              source: "assets/earth-night.jpg"
              generateMipmaps: true
              mipFilter: Texture.Linear
            }
            emissiveMap: Texture {
              source: "assets/earth-night.jpg"
              generateMipmaps: true
              mipFilter: Texture.Linear
            }
            emissiveFactor: Qt.vector3d(1.7, 1.7, 1.7)
            roughness: 0.85
            metalness: 0
          }
        }
        Model {
          source: "#Sphere"
          scale: Qt.vector3d(2.004, 2.004, 2.004)
          opacity: 0.16
          materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColorMap: Texture {
              source: "assets/graticule.png"
            }
            alphaMode: PrincipledMaterial.Blend
            cullMode: Material.BackFaceCulling
          }
        }

        Repeater3D {
          // Only what has something to draw: an instancing table with no file complains.
          model: globe.layers.filter(function (layer) {
            return layer.file !== "";
          })

          delegate: Model {
            id: dots

            required property var modelData

            source: "#Cube"
            scale: Qt.vector3d(globe.dotScale, globe.dotScale, globe.dotScale)
            visible: !globe.hidden[modelData.key]
            instancing: table

            FileInstancing {
              id: table

              source: "file://" + dots.modelData.file
            }
            materials: PrincipledMaterial {
              lighting: PrincipledMaterial.NoLighting
              baseColor: "white"
            }
          }
        }

        Repeater3D {
          // The webcams, by the same means.
          model: globe.extra.filter(function (layer) {
            return layer.file !== "";
          })

          delegate: Model {
            id: extraDots

            required property var modelData

            source: "#Cube"
            scale: Qt.vector3d(globe.dotScale, globe.dotScale, globe.dotScale)
            visible: !globe.hidden[modelData.key]
            instancing: extraTable

            FileInstancing {
              id: extraTable

              source: "file://" + extraDots.modelData.file
            }
            materials: PrincipledMaterial {
              lighting: PrincipledMaterial.NoLighting
              baseColor: "white"
            }
          }
        }

        // Home, when it is known and may be shown.
        Model {
          visible: globe.home !== null
          source: "#Sphere"
          position: globe.home ? globe.spot(globe.home.lat, globe.home.lon, 0.6) : Qt.vector3d(0, 0, 0)
          scale: Qt.vector3d(0.018 * globe.dotScale, 0.018 * globe.dotScale, 0.018 * globe.dotScale)
          materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: Color.good
          }
        }
        // The dot that was clicked: a white one, a little larger, in its place.
        Model {
          visible: globe.picked !== null
          source: "#Sphere"
          position: globe.picked ? globe.spot(globe.picked.lat, globe.picked.lon, 0.25) : Qt.vector3d(0, 0, 0)
          scale: Qt.vector3d(0.022 * globe.dotScale, 0.022 * globe.dotScale, 0.022 * globe.dotScale)
          materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "white"
          }
        }
      }
    }

    // The edge and the glow are for seeing the planet whole. Inside them, close in, they
    // would only be a blue wash over everything.
    Model {
      visible: globe.altitude > 30
      source: "#Sphere"
      scale: Qt.vector3d(2.008, 2.008, 2.008)
      materials: CustomMaterial {
        shadingMode: CustomMaterial.Unshaded
        vertexShader: "assets/shell.vert"
        fragmentShader: "assets/rim.frag"
        sourceBlend: CustomMaterial.One
        destinationBlend: CustomMaterial.One
        cullMode: Material.BackFaceCulling
        depthDrawMode: Material.NeverDepthDraw
      }
    }
    Model {
      visible: globe.altitude > 30
      source: "#Sphere"
      scale: Qt.vector3d(2.2, 2.2, 2.2)
      materials: CustomMaterial {
        shadingMode: CustomMaterial.Unshaded
        vertexShader: "assets/shell.vert"
        fragmentShader: "assets/atmosphere.frag"
        sourceBlend: CustomMaterial.One
        destinationBlend: CustomMaterial.One
        cullMode: Material.FrontFaceCulling
        depthDrawMode: Material.NeverDepthDraw
      }
    }
  }

  // A slow turn, twenty steps a second. Not while it is being used, and not once it has
  // been left alone long enough: from then on it draws nothing until touched.
  Timer {
    interval: 50
    repeat: true
    running: globe.running && !drag.pressed && globe.picked === null && globe.altitude > 120 && !globe.settled && !going.running
    onTriggered: globe.spin += 0.075
  }

  property var hovering: null
  property real pointerX: 0
  property real pointerY: 0

  // A ray and a search of every row: fine ten times a second, not on each pixel moved.
  Timer {
    id: asking

    interval: 80
    onTriggered: globe.hovering = globe.under(globe.pointerX, globe.pointerY)
  }

  MouseArea {
    id: drag

    property real lastX: 0
    property real lastY: 0
    property bool moved: false

    anchors.fill: parent
    hoverEnabled: true
    preventStealing: true
    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    onPressed: mouse => {
      lastX = mouse.x;
      lastY = mouse.y;
      moved = false;
      going.stop();
      globe.touch();
    }
    onPositionChanged: mouse => {
      globe.pointerX = mouse.x;
      globe.pointerY = mouse.y;
      if (pressed) {
        var pace = globe.degreesPerPixel;
        globe.spin += (mouse.x - lastX) * pace;
        globe.tilt = Math.max(-85, Math.min(85, globe.tilt + (mouse.y - lastY) * pace));
        if (Math.abs(mouse.x - lastX) + Math.abs(mouse.y - lastY) > 1)
          moved = true;
        lastX = mouse.x;
        lastY = mouse.y;
      } else if (!asking.running) {
        asking.start();
      }
    }
    onExited: globe.hovering = null
    onClicked: mouse => {
      if (moved)
        return;
      var found = globe.under(mouse.x, mouse.y);
      globe.picked = found && found.point ? found.point : null;
      globe.chosen(globe.picked);
      globe.touch();
    }
    // Double-click: go there, and three times closer.
    onDoubleClicked: mouse => {
      var found = globe.under(mouse.x, mouse.y);
      if (found)
        globe.face(found.point ? found.point.lat : found.lat, found.point ? found.point.lon : found.lon, 1 / 3);
    }
    // In proportion to the height, so each notch feels the same from orbit to a city.
    onWheel: wheel => {
      going.stop();
      globe.touch();
      globe.distance = globe.radius + Math.max(2.5, Math.min(320, globe.altitude * Math.pow(0.9985, wheel.angleDelta.y)));
    }
  }

  // What is under the pointer, beside it.
  Rectangle {
    readonly property var point: globe.hovering ? globe.hovering.point : null

    visible: point !== null && !drag.pressed
    x: Math.min(globe.width - width - 8, globe.pointerX + 14)
    y: Math.max(8, globe.pointerY - height - 8)
    width: tip.implicitWidth + 16
    height: tip.implicitHeight + 10
    radius: Style.radius
    color: Color.tooltipBackground
    border.width: 1
    border.color: point ? point.colour : Color.popupBorder

    Column {
      id: tip

      anchors.centerIn: parent

      Text {
        text: parent.parent.point ? parent.parent.point.name : ""
        textFormat: Text.PlainText
        color: Color.popupText
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize
        font.weight: Style.barLabelWeight
      }
      Text {
        text: parent.parent.point ? parent.parent.point.layer + (parent.parent.point.detail ? "  ·  " + parent.parent.point.detail : "") : ""
        textFormat: Text.PlainText
        color: Color.popupMuted
        font.family: Style.fontFamily
        font.pixelSize: Style.fontSize - 2
      }
    }
  }

  // Where the pointer is, in the corner, as a scanner's readout.
  Text {
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    anchors.margins: 12
    text: {
      var h = globe.hovering;
      if (!h)
        return "drag to turn  ·  scroll to zoom  ·  click a dot  ·  double-click to go there";
      return Math.abs(h.lat).toFixed(2) + "° " + (h.lat >= 0 ? "N" : "S") + "   " + Math.abs(h.lon).toFixed(2) + "° " + (h.lon >= 0 ? "E" : "W");
    }
    color: Color.popupMuted
    font.family: Style.fontFamily
    font.pixelSize: Style.fontSize - 2
  }
}
