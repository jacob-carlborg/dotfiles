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
      const name = project.name ?? project.worktree;

      if (event.type === "permission.asked") {
        await $`osascript -e 'display notification "${name}" with title "Agent is asking for permission"'`;
      }

      if (event.type === "session.idle") {
        await $`osascript -e 'display notification "${name}" with title "Agent is done"'`;
      }
    },
  };
};
