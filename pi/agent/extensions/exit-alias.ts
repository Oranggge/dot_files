import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  pi.registerCommand("exit", {
    description: "Exit pi cleanly",
    handler: async (_args, ctx) => {
      ctx.shutdown();
    },
  });

  pi.on("input", async (event, ctx) => {
    if (event.source === "extension") {
      return { action: "continue" };
    }

    if (event.text.trim().toLowerCase() === "exit") {
      ctx.shutdown();
      return { action: "handled" };
    }

    return { action: "continue" };
  });
}
