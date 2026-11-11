/**
 * POST /api/agent
 *
 * Server-side SSE proxy that calls the Snowflake Cortex Agent REST API and
 * streams the response back to the browser. Runs in the SPCS network so it
 * can reach the internal Snowflake API without egress restrictions.
 *
 * Uses the SPCS service token (owner's rights) to authenticate against the
 * Cortex Agent endpoint.
 */

import { getSnowflakeBaseUrl, getRestApiAuthHeader } from "@/lib/snowflake"
import { DEMO_CONFIG } from "@/lib/demo-config"

export const dynamic = "force-dynamic"

export interface ChatMessage {
  role: "user" | "assistant"
  content: string
}

export async function POST(req: Request) {
  try {
    const { messages }: { messages: ChatMessage[] } = await req.json()

    const baseUrl = getSnowflakeBaseUrl()
    if (!baseUrl) {
      return Response.json({ error: "Snowflake base URL not available" }, { status: 503 })
    }

    const authHeader = getRestApiAuthHeader()
    if (!authHeader) {
      return Response.json({ error: "No Snowflake auth token available" }, { status: 503 })
    }

    const agentUrl = `${baseUrl}/api/v2/cortex/agent:run`

    const upstream = await fetch(agentUrl, {
      method: "POST",
      headers: {
        Authorization: authHeader,
        "X-Snowflake-Authorization-Token-Type": "OAUTH",
        "Content-Type": "application/json",
        Accept: "text/event-stream",
      },
      body: JSON.stringify({
        agent: { agent_name: DEMO_CONFIG.snowflake.agentFqn },
        messages: messages.map((m) => ({
          role: m.role,
          content: [{ type: "text", text: m.content }],
        })),
      }),
    })

    if (!upstream.ok) {
      const errText = await upstream.text()
      console.error(new Date().toISOString(), "[agent] upstream error", upstream.status, errText)
      return Response.json(
        { error: `Agent API returned ${upstream.status}: ${errText.slice(0, 200)}` },
        { status: upstream.status },
      )
    }

    // Pipe the SSE stream directly to the client
    return new Response(upstream.body, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        Connection: "keep-alive",
      },
    })
  } catch (e) {
    console.error(new Date().toISOString(), "[agent]", e)
    return Response.json({ error: e instanceof Error ? e.message : "Agent call failed" }, { status: 500 })
  }
}
