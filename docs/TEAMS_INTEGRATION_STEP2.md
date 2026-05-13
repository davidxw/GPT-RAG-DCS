# Guide for Building a Teams App Interface for Enterprise GPT-RAG Solution Accelerator

*Ensure all steps in [Step 1](TEAMS_INTEGRATION_STEP1.md) are completed before proceeding.*

## Step 2: Connect to the GPT-RAG Orchestrator and test locally

In this step you replace the template's default LLM call with a call to the **GPT-RAG Orchestrator**, while keeping the Teams AI Library `Application` so that you inherit streaming, citation and feedback support out of the box (configured in [Step 6](TEAMS_INTEGRATION_STEP6.md)).

> **Why not just `fetch()` like the previous version?** A raw `fetch()` in `teamsBot.ts` works, but it bypasses everything the Teams AI Library gives you for free: typed activity handlers, automatic state/turn management, the streaming response builder, and the citation / feedback APIs. Using the `Application` primitive now means [Step 6](TEAMS_INTEGRATION_STEP6.md) is mostly a configuration change rather than a rewrite.

### 2.1 Configure the orchestrator endpoint

Add the orchestrator settings to **`env/.env.local`** (and to the per-environment files later):

```dotenv
# Orchestrator
ORCHESTRATOR_ENDPOINT=https://<your-orchestrator-host>/api/orc
ORCHESTRATOR_AUDIENCE=api://<orchestrator-app-id>     # used by Step 6 (SSO/OBO)
ORCHESTRATOR_TIMEOUT_MS=60000

# Key Vault (optional — only if you keep a fallback API key)
KEYVAULT_NAME=<your-kv-name>
ORCHESTRATOR_KEY_SECRET_NAME=orchestrator-function-key
```

> **Do not check secrets into source.** The toolkit-generated `.gitignore` already excludes `env/.env.*.user`. Per-environment user secrets belong in `env/.env.<env>.user`, which the toolkit encrypts when committed.

### 2.2 Create an orchestrator client

Create **`src/orchestrator/client.ts`**:

```typescript
import { DefaultAzureCredential } from "@azure/identity";

export interface OrchestratorRequest {
  question: string;
  conversation_id: string;
  user_id?: string;
  user_token?: string; // populated in Step 6 once SSO is wired up
}

export interface OrchestratorCitation {
  title: string;
  url?: string;
  snippet?: string;
  sensitivity_label?: string;
}

export interface OrchestratorResponse {
  answer: string;
  conversation_id: string;
  citations?: OrchestratorCitation[];
  thought_process?: string;
}

const credential = new DefaultAzureCredential();
const audience = process.env.ORCHESTRATOR_AUDIENCE!;
const endpoint = process.env.ORCHESTRATOR_ENDPOINT!;
const timeoutMs = Number(process.env.ORCHESTRATOR_TIMEOUT_MS ?? 60000);

export async function callOrchestrator(
  req: OrchestratorRequest
): Promise<OrchestratorResponse> {
  // Prefer a Managed-Identity-issued token over a function key.
  const token = await credential.getToken(`${audience}/.default`);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const res = await fetch(endpoint, {
      method: "POST",
      signal: controller.signal,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token!.token}`,
      },
      body: JSON.stringify(req),
    });

    if (!res.ok) {
      const body = await res.text().catch(() => "");
      throw new Error(`Orchestrator HTTP ${res.status}: ${body.slice(0, 500)}`);
    }
    return (await res.json()) as OrchestratorResponse;
  } finally {
    clearTimeout(timer);
  }
}
```

> The client uses **Managed Identity** (`DefaultAzureCredential`) by default. Locally, `DefaultAzureCredential` falls back to your `az login` identity. In Azure, it uses the user-assigned Managed Identity attached to the host (configured in [Step 3](TEAMS_INTEGRATION_STEP3.md)). The Key Vault lookup pattern from earlier guide revisions is no longer needed unless you must support a function-key fallback.

### 2.3 Wire the orchestrator into the Teams AI `Application`

Open **`src/app/app.ts`** (the file may be `src/index.ts` in some template versions) and replace the default `app.ai.prompt(...)` handler with a call to the orchestrator. A minimal v2 Teams AI Library handler looks like:

```typescript
import { Application, TurnContext } from "@microsoft/teams-ai";
import { MemoryStorage } from "botbuilder";
import { callOrchestrator } from "../orchestrator/client";

export const app = new Application({
  storage: new MemoryStorage(),
  // AI/feedback/streaming options are added in Step 6
});

app.activity("message", async (context: TurnContext) => {
  const question = (context.activity.text ?? "").trim();
  if (!question) return;

  const conversationId = context.activity.conversation.id;
  const userId = context.activity.from?.aadObjectId ?? context.activity.from?.id;

  // Show a "thinking" indicator while the orchestrator works.
  await context.sendActivity({ type: "typing" });

  try {
    const result = await callOrchestrator({
      question,
      conversation_id: conversationId,
      user_id: userId,
      // user_token: populated in Step 6 once SSO is wired
    });

    // For now, send the answer as plain text.
    // Step 6 replaces this with a streamed reply that includes citations,
    // an "AI generated" label, and the feedback loop.
    await context.sendActivity(result.answer);
  } catch (err) {
    console.error("Orchestrator call failed", err);
    await context.sendActivity(
      "Sorry — I couldn't reach the knowledge service. Please try again in a moment."
    );
  }
});
```

Key points compared to the legacy `teamsBot.ts` sample:

- **`conversation.id` is still the correlation key** — the orchestrator continues to manage history under that id, so prior conversation memory still works.
- **Errors are surfaced**, not silently swallowed.
- **Auth is token-based**, not key-based.
- **No raw `fetch()` from the activity handler** — the orchestrator client is isolated and unit-testable.

### 2.4 Test locally

1. From the **Microsoft 365 Agents Toolkit** sidebar, choose **Debug → Debug in Microsoft 365 Agents Playground** (or **Debug in Teams (Edge/Chrome)**). The Playground is the modern replacement for the older "App Test Tool" and lets you exercise the bot without sideloading.
2. Send a question that you know the indexed corpus can answer.
3. Confirm the orchestrator is being called with `conversation_id` and that the answer is rendered in the chat.

If the local run fails to authenticate to the orchestrator, run `az login` in a terminal and restart debugging — `DefaultAzureCredential` will then pick up your user identity.

---

Proceed to [Step 3: Provision and deploy Azure resources (reusing accelerator infra)](TEAMS_INTEGRATION_STEP3.md).

## Additional Resources
- [Step 1: Create a new Teams app project](TEAMS_INTEGRATION_STEP1.md).
- [Step 3: Provision and deploy Azure resources](TEAMS_INTEGRATION_STEP3.md).
- [Step 6: Add rich RAG UX](TEAMS_INTEGRATION_STEP6.md).

## External Resources
- [Microsoft 365 Agents Playground](https://learn.microsoft.com/microsoftteams/platform/toolkit/debug-your-teams-app-test-tool?tabs=vscode%2Cclijs).
- [Teams AI Library `Application` reference](https://learn.microsoft.com/microsoftteams/platform/bots/how-to/teams%20conversational%20ai/how-conversation-ai-core-capabilities).
- [`DefaultAzureCredential` overview](https://learn.microsoft.com/azure/developer/javascript/sdk/authentication/credential-chains).
