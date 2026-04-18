// ClaudeCodeNotifier — OpenCode plugin
// Fires native macOS banners for OpenCode session events via
// ~/.claude/OpenCodeNotifier.app. Idle banners fire only after the session
// was busy (avoids startup noise); subagent sessions are filtered out.

import { spawn, spawnSync } from "node:child_process";
import { existsSync } from "node:fs";

const APP_PATH = `${process.env.HOME}/.claude/OpenCodeNotifier.app`;
const DETECT_SCRIPT = `${process.env.HOME}/.claude/hooks/detect-ghostty-tab.sh`;
const TITLE = "OpenCode";

export const OpenCodeNotifierPlugin = async ({ project, directory }) => {
  if (globalThis.__opencodeNotifierLoaded) return {};
  globalThis.__opencodeNotifierLoaded = true;

  const MAX_LABEL = 20;
  const truncate = (s) =>
    s.length > MAX_LABEL ? s.slice(0, MAX_LABEL - 1) + "…" : s;

  const detectGhosttyTab = () => {
    if (!existsSync(DETECT_SCRIPT)) return "";
    try {
      const result = spawnSync("/bin/bash", [DETECT_SCRIPT, String(process.pid)], {
        encoding: "utf8",
        timeout: 2000,
      });
      const idx = (result.stdout || "").trim();
      return idx ? `#${idx}` : "";
    } catch (_) {
      return "";
    }
  };

  const label = () => {
    const tab = detectGhosttyTab();
    if (tab) return tab;
    const dir = project?.directory || directory || process.cwd();
    try {
      return truncate(dir.split("/").filter(Boolean).pop() || "opencode");
    } catch (_) {
      return "opencode";
    }
  };

  const notify = (subtitle, message) => {
    try {
      // Detach so the banner survives if opencode exits immediately after
      // (e.g. `opencode run` one-shot mode).
      const child = spawn(
        "/usr/bin/open",
        ["-n", APP_PATH, "--args", TITLE, subtitle, message],
        { detached: true, stdio: "ignore" },
      );
      child.unref();
    } catch (_) {}
  };

  // Synchronous cache-only subagent lookup. Awaiting `client.session.list()`
  // here races with `opencode run` process shutdown and the notify never fires.
  const childCache = new Map();
  const isChild = (sessionID) => childCache.get(sessionID) === true;
  const busy = new Set();

  return {
    event: async ({ event }) => {
      const type = event?.type;
      const props = event?.properties || {};
      const sessionID = props.sessionID || props.info?.id;

      if (type === "session.created") {
        const info = props.info || props;
        if (info?.id) childCache.set(info.id, !!info.parentID);
        return;
      }

      if (type === "session.status") {
        if (!sessionID) return;
        if (props.status?.type === "busy") busy.add(sessionID);
        return;
      }

      if (type === "session.idle") {
        if (!sessionID || isChild(sessionID) || !busy.has(sessionID)) return;
        busy.delete(sessionID);
        notify(`[${label()}] Task complete`, "OpenCode is waiting for your input");
        return;
      }

      if (type === "session.error") {
        if (!sessionID || isChild(sessionID)) return;
        const err = props.error;
        const msg = err?.data?.message || err?.name || "Session error";
        notify(`[${label()}] Error`, msg);
        return;
      }
    },

    "permission.ask": async (input) => {
      const tool = input?.type || input?.tool || "tool";
      notify(`[${label()}] Permission required`, `OpenCode wants to use ${tool}`);
    },
  };
};
