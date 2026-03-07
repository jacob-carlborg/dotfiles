import type { Plugin } from "@opencode-ai/plugin";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));

export const NotificationPlugin: Plugin = async ({
  project,
  client,
  $,
  directory,
  worktree,
}) => {
  // Get the TTY of the opencode process (our parent) to identify the iTerm2 session.
  const tty = `/dev/${(await $`ps -o tty= -p ${process.ppid}`.text()).trim()}`;

  // Check if terminal-notifier is available for clickable notifications.
  const hasTerminalNotifier =
    (await $`which terminal-notifier`.nothrow().quiet()).exitCode === 0;

  // Resolve the app icon path relative to this plugin file.
  const appIconUrl = `file://${resolve(__dirname, "opencode_icon_dark.png")}`;

  // AppleScript to find and activate the iTerm2 session matching this TTY.
  const focusScript = `
    tell application "iTerm2"
      activate
      repeat with aWindow in windows
        repeat with aTab in tabs of aWindow
          repeat with aSession in sessions of aTab
            if tty of aSession is "${tty}" then
              select aTab
              select aSession
              select aWindow
              return
            end if
          end repeat
        end repeat
      end repeat
    end tell`;

  async function notify(title: string, message: string) {
    if (hasTerminalNotifier) {
      const executeCmd = `osascript -e '${focusScript}'`;
      await $`terminal-notifier -title ${title} -message ${message} -appIcon ${appIconUrl} -execute ${executeCmd}`;
    } else {
      await $`osascript -e ${"display notification \"" + message + "\" with title \"" + title + "\""}`;
    }
  }

  async function isSubAgent(event: Event): Promise<boolean> {
    const session = await client
      .session
      .get({ path: { id: event.properties.sessionID }})

    return !!session.data.parentID
  }

  return {
    event: async ({ event }) => {
      const name = project.name ?? project.worktree;

      if (event.type === "permission.asked") {
        await notify("Agent is asking for permission", name);
      }

      if (event.type === "question.asked") {
        await notify("Agent is asking a question", name);
      }

      if (event.type === "session.idle" && !await isSubAgent(event)) {
        await notify("Agent is done", name);
      }
    },
  };
};
