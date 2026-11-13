// What this opencode is doing, told to the desktop the way Claude Code's hooks tell it.
//
// opencode has no hooks of its own to wire, so its tabs were always shown idle: the sidebar,
// the tab marks, the bar and the notifications had nothing from it. Its plugin events are
// translated here into the hook events desktop-agent-state already takes from claude, and
// passed with this agent's name and process, so it shows like claude does:
//
//   session.status busy, after idle   UserPromptSubmit   working: a turn begins
//   permission.asked / .updated       Notification       waiting: it wants an answer
//   permission.replied                PostToolUse        working again
//   session.idle                      Stop               done
//
// Deployed to ~/.config/opencode/plugins/, which opencode loads by itself. The pane comes
// from TMUX and TMUX_PANE, which opencode inherits from its tmux pane and passes on.
//
// Never in the way: every call is fire-and-forget, and a failure is swallowed.

import { spawn } from "node:child_process"

export const DesktopState = async ({ directory }) => {
  const busy = new Map()

  const tell = (event, session, extra = {}) => {
    if (!session) return
    try {
      const child = spawn("desktop-agent-state", [], {
        stdio: ["pipe", "ignore", "ignore"],
        env: { ...process.env, DESKTOP_AGENT_NAME: "opencode", DESKTOP_AGENT_PID: String(process.pid) },
      })
      child.on("error", () => {})
      child.stdin.on("error", () => {})
      child.stdin.end(JSON.stringify({ hook_event_name: event, session_id: session, cwd: directory, ...extra }))
    } catch {}
  }

  return {
    event: async ({ event }) => {
      const p = event.properties || {}
      switch (event.type) {
        case "session.status": {
          const now = p.status && p.status.type === "busy"
          if (now && !busy.get(p.sessionID)) tell("UserPromptSubmit", p.sessionID)
          busy.set(p.sessionID, now)
          break
        }
        case "permission.asked":
        case "permission.updated":
          tell("Notification", p.sessionID, {
            notification_type: "permission_prompt",
            message: p.title || "a permission is asked",
          })
          break
        case "permission.replied":
          tell("PostToolUse", p.sessionID)
          break
        case "session.idle":
          busy.set(p.sessionID, false)
          tell("Stop", p.sessionID)
          break
      }
    },
  }
}
