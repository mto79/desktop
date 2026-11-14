// What opencode is doing, told to the desktop as Claude Code and codex tell it through their hooks.
//
// opencode has no hooks; it has plugins, and a plugin hears its events. This one turns those
// into the hook JSON desktop-agent-state reads, so an opencode agent is shown the same way
// everywhere a Claude one is: its dot in the tmux sidebar and on its tab, the bar, the
// dashboard, and a notification when it is waiting for you and you are not looking.
//
//   session.status busy      UserPromptSubmit   working     a turn begins
//   permission.asked         Notification       waiting     a permission prompt
//   permission.replied       PostToolUse        working     answered: back at it
//   session.idle             Stop               done        the turn is finished
//   session.error            Stop               done        ended, not with a result
//
// One record per opencode process rather than per conversation: the pane is what is shown
// and gone to, and one opencode switches conversations within it. Its pid goes with it, so
// a record whose opencode has gone is removed (desktop-agent-sessions).
//
// Installed to ~/.config/opencode/plugin/ with the rest of config/. It must never be what
// breaks opencode: every call is detached, and every failure is swallowed.

import { spawn } from "node:child_process"
import { homedir } from "node:os"
import { join } from "node:path"

const STATE = join(homedir(), ".local/share/desktop/bin/desktop-agent-state")

export const DesktopAgentState = async ({ directory }) => {
  const session = `opencode-${process.pid}`
  let state = ""

  const send = (event, extra = {}) => {
    try {
      const child = spawn(STATE, [], {
        stdio: ["pipe", "ignore", "ignore"],
        detached: true,
        env: { ...process.env, DESKTOP_AGENT_PID: String(process.pid), DESKTOP_AGENT_KIND: "opencode" },
      })
      child.on("error", () => {})
      child.stdin.on("error", () => {})
      child.stdin.end(JSON.stringify({ hook_event_name: event, session_id: session, cwd: directory, ...extra }))
      child.unref()
    } catch {
      // Not there, or not runnable: opencode goes on as if this plugin were not.
    }
  }

  send("SessionStart")

  return {
    // What was asked, kept with the turn, as Claude Code's prompt is: the notification at the
    // end of it says what it was the answer to.
    "chat.message": async (_input, output) => {
      const prompt = (output?.parts || [])
        .filter((part) => part?.type === "text" && !part.synthetic)
        .map((part) => part.text)
        .join(" ")
      if (prompt && state !== "working") {
        state = "working"
        send("UserPromptSubmit", { prompt })
      }
    },
    event: async ({ event }) => {
      switch (event?.type) {
        case "session.status":
          if (event.properties?.status?.type === "busy" && state !== "working" && state !== "waiting") {
            state = "working"
            send("UserPromptSubmit")
          }
          break
        case "permission.asked":
          state = "waiting"
          send("Notification", { notification_type: "permission_prompt", message: event.properties?.permission || "" })
          break
        case "permission.replied":
          state = "working"
          send("PostToolUse")
          break
        case "session.idle":
        case "session.error":
          state = "done"
          send("Stop")
          break
      }
    },
  }
}
