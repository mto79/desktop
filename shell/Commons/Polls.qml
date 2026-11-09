pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// One copy of each thing the bars poll, however many bars there are.
//
// A bar widget exists once per monitor, and each used to run its own timer and its own
// process. On three monitors that was every status script three times over: a third of a
// core of nothing but asking the same questions, most of it fuser walking /proc for the
// camera. So a widget joins a poll instead, by its command, and they all hear one answer.
//
// Nobody is looking at a machine that has been idle for five minutes, so nothing is asked
// then. The first thing after that is to ask everything again, so the bar is right by the
// time it is seen. A call counts as not idle: Awake holds an inhibitor, which this honours.
//
//   poll = Polls.join(command, milliseconds)
//   Connections { target: poll; function onRead(text) { ... } }
//   Polls.leave(poll)      // when the widget goes
Singleton {
  id: root

  property var polls: ({})

  IdleMonitor {
    id: idle

    timeout: 300
  }

  readonly property bool away: idle.isIdle

  component Poll: QtObject {
    id: poll

    required property var command
    required property int every
    required property string key
    property int joined: 0
    // The last answer, for a widget that joins after it came: a monitor plugged in.
    property string last: ""
    property bool answered: false

    signal read(string text)

    function now() {
      if (!process.running)
        process.running = true;
    }

    property Process process: Process {
      id: process

      command: poll.command

      stdout: StdioCollector {
        onStreamFinished: {
          poll.last = text;
          poll.answered = true;
          poll.read(text);
        }
      }
    }

    property Timer timer: Timer {
      interval: poll.every
      repeat: true
      running: !root.away
      triggeredOnStart: true
      onTriggered: poll.now()
    }
  }

  Component {
    id: pollComponent

    Poll {}
  }

  function join(command, every) {
    var key = every + " " + JSON.stringify(command);
    var poll = polls[key];
    if (!poll) {
      poll = pollComponent.createObject(root, {
        command: command,
        every: every,
        key: key
      });
      polls[key] = poll;
    }
    poll.joined++;
    return poll;
  }

  function leave(poll) {
    if (!poll)
      return;
    poll.joined--;
    if (poll.joined <= 0) {
      delete polls[poll.key];
      poll.destroy();
    }
  }
}
