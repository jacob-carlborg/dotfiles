import type { Plugin } from "@opencode-ai/plugin";

export const NotificationPlugin: Plugin = async ({
  project,
  client,
  $,
  directory,
  worktree,
}) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        // MacOS sounds can be found on /System/Library/Sounds
        await $`osascript -e 'display notification "Agent is done" with title "opencode"'`;
      }
    },
  };
};
