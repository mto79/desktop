import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// Infrastructure: the clusters, each as a tile. From desktop-dash infra, which asks every
// cluster ocl knows that there is a token for, all at once.
ColumnLayout {
  id: page

  property var info: null
  property bool active: false

  spacing: Style.overviewSpacing

  function tone(state) {
    return state === "healthy" ? Color.good : state === "degraded" ? Color.popupUrgent : state === "updating" ? Color.popupAccent : Color.popupMuted;
  }

  function words(cluster) {
    if (cluster.state === "signed-out")
      return "no token  ·  ocl " + cluster.name;
    if (cluster.state === "degraded")
      return (cluster.nodes - cluster.ready) + " of " + cluster.nodes + " nodes not ready";
    if (cluster.state === "updating")
      return "updating  ·  " + cluster.ready + " of " + cluster.nodes + " nodes ready";
    return cluster.ready + " of " + cluster.nodes + " nodes ready";
  }

  Unconnected {
    visible: !!page.info && page.info.connected === false
    how: page.info && page.info.how ? page.info.how : []
  }

  GridLayout {
    Layout.fillWidth: true
    columns: page.width > 1500 ? 4 : (page.width > 900 ? 3 : 2)
    columnSpacing: Style.overviewSpacing
    rowSpacing: Style.overviewSpacing

    Card {
      order: 0
      appear: page.active
      Layout.columnSpan: parent.columns
      icon: "\u{f048b}"
      title: "Clusters"
      tone: page.info && page.info.trouble > 0 ? Color.popupUrgent : Color.good

      Row {
        spacing: Style.overviewSpacing * 1.5
        topPadding: 6
        bottomPadding: 6

        Figure {
          appear: page.active
          value: page.info ? page.info.clusters.length : 0
          label: "known"
        }
        Figure {
          appear: page.active
          value: page.info ? page.info.signed_in : 0
          label: "signed in"
          tone: Color.popupAccent
        }
        Figure {
          appear: page.active
          value: page.info ? page.info.trouble : 0
          label: "in trouble"
          tone: page.info && page.info.trouble > 0 ? Color.popupUrgent : Color.good
        }
      }
    }

    Repeater {
      model: page.info ? page.info.clusters : []

      delegate: Card {
        id: tile

        required property var modelData
        required property int index

        order: index + 1
        appear: page.active
        icon: "\u{f048b}"
        title: modelData.name
        figure: modelData.version || ""
        tone: page.tone(modelData.state)

        Row {
          spacing: Style.sectionSpacing
          topPadding: 6

          // The light. It breathes when something is wrong, and only then: on a page of
          // steady lights the one that moves is the one to look at.
          Rectangle {
            id: light

            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 12
            radius: 6
            color: tile.tone

            SequentialAnimation on opacity {
              running: tile.modelData.state === "degraded" && page.active
              loops: Animation.Infinite
              onRunningChanged: if (!running)
                light.opacity = 1

              NumberAnimation {
                to: 0.25
                duration: Style.motionBreath / 2
                easing.type: Easing.InOutSine
              }
              NumberAnimation {
                to: 1
                duration: Style.motionBreath / 2
                easing.type: Easing.InOutSine
              }
            }
          }
          Text {
            text: tile.modelData.state.replace("-", " ")
            color: tile.tone
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSize + 2
            font.weight: Style.barLabelWeight
          }
        }
        Quiet {
          text: page.words(tile.modelData)
        }
        // How many of its nodes are ready, as a bar that fills.
        Rectangle {
          visible: (tile.modelData.nodes || 0) > 0
          width: parent.width
          height: 5
          radius: 2.5
          color: Color.popupBorder

          Rectangle {
            height: parent.height
            radius: parent.radius
            color: tile.tone
            width: page.active ? parent.width * (tile.modelData.ready || 0) / Math.max(1, tile.modelData.nodes || 1) : 0

            Behavior on width {
              NumberAnimation {
                duration: 700
                easing.type: Easing.OutCubic
              }
            }
          }
        }
      }
    }
  }
}
