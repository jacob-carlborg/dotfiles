import type { Plugin } from "@opencode-ai/plugin"

const CONTEXT_1M_BETA = "context-1m-2025-08-07"

const SUPPORTED_MODELS = [
  "opus-4-6",
  "opus-4.6",
  "sonnet-4-5",
  "sonnet-4.5",
  "sonnet-4-20250514",
]

export const plugin: Plugin = async () => ({
  "chat.params": async (input, output) => {
    if (input.model.providerID !== "anthropic") return
    if (!input.model.api.id.includes("claude")) return
    if (!SUPPORTED_MODELS.some((m) => input.model.api.id.includes(m))) return
    const existing = output.options.anthropicBeta ?? []
    if (existing.includes(CONTEXT_1M_BETA)) return
    output.options.anthropicBeta = [...existing, CONTEXT_1M_BETA]
  },
})
