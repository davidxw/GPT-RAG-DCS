# Guide for Building a Teams App Interface for Enterprise GPT-RAG Solution Accelerator

*Ensure all steps in [Step 5: Publish the Teams app](TEAMS_INTEGRATION_STEP5.md) are completed before proceeding.*

## Step 6: Add rich RAG UX (citations, streaming, AI label, feedback, SSO)

Steps 1–5 give you a working Teams bot that proxies questions to the GPT-RAG Orchestrator. This step turns it into a **production-grade RAG agent** by enabling the Teams chat affordances that users expect from a modern AI experience:

- **Token streaming** — answers appear as they are generated.
- **Citations** — numbered footnotes that open the source document on click.
- **AI-generated content label** — a "AI generated" badge under each reply.
- **Feedback loop** — thumbs-up / thumbs-down with an optional comment, posted back to the bot for logging.
- **Adaptive Card rendering** — a structured card that exposes the orchestrator's `thought_process` behind a "View reasoning" toggle.
- **Single Sign-On (Entra ID)** — flow the user's identity to the orchestrator via On-Behalf-Of so per-user security trimming works end-to-end.

Each sub-section is independent — adopt them in any order — but enabling them all is recommended.

---

### 6.1 Update the manifest

Open `appPackage/manifest.json` and ensure these fields are present:

```jsonc
{
  "manifestVersion": "1.19",
  "bots": [
    {
      "botId": "${{BOT_ID}}",
      "scopes": ["personal", "groupChat", "team"],
      "supportsStreaming": true,
      "supportsAIGeneratedContent": true,
      "supportsFiles": true
    }
  ]
}
```

These flags are what unlock the streaming, AI label, file-upload, and citation behaviours below. Without them, Teams ignores the corresponding entities on outgoing activities.

---

### 6.2 Enable streaming

Streaming is a property of the Teams AI Library `Application`, so wrapping the orchestrator call in a `streamingResponse` is enough:

```typescript
app.activity("message", async (context) => {
  const question = (context.activity.text ?? "").trim();
  if (!question) return;

  const stream = context.streamingResponse;          // provided by Teams AI v2
  stream.queueInformativeUpdate("Searching the knowledge base…");

  const result = await callOrchestrator({
    question,
    conversation_id: context.activity.conversation.id,
    user_id: context.activity.from?.aadObjectId,
    user_token: await getOboTokenForUser(context),    // see §6.6
  });

  // If the orchestrator returns the answer in chunks, queue each one;
  // otherwise queue the whole answer as a single chunk.
  stream.queueTextChunk(result.answer);

  stream.setCitations((result.citations ?? []).map((c, i) => ({
    "@type": "Claim",
    position: i + 1,
    appearance: {
      "@type": "DigitalDocument",
      name: c.title,
      url: c.url,
      abstract: c.snippet,
      encodingFormat: "text/html",
      usageInfo: c.sensitivity_label
        ? { "@type": "CreativeWork", name: c.sensitivity_label }
        : undefined,
    },
  })));

  await stream.endStream({
    generatedByAILabel: true,           // §6.4
    feedbackLoop: { type: "default" },  // §6.5
  });
});
```

If your orchestrator currently returns one JSON blob, consider exposing an **SSE / chunked HTTP** endpoint so the bot can `queueTextChunk` per token. Even without true streaming from the orchestrator, the `queueInformativeUpdate` call alone removes most of the perceived latency.

---

### 6.3 Emit citations

Citations come from the same `setCitations` call shown above. The orchestrator already returns retrieved chunks; expose them in the response shape used in [Step 2](TEAMS_INTEGRATION_STEP2.md):

```jsonc
{
  "answer": "…with inline references like [1] and [2].",
  "citations": [
    {
      "title": "Employee Handbook 2026",
      "url": "https://contoso.sharepoint.com/.../handbook.pdf",
      "snippet": "Employees accrue 20 days of annual leave per year…",
      "sensitivity_label": "Confidential"
    },
    {
      "title": "HR Policy 14.2",
      "url": "https://contoso.sharepoint.com/.../policy-14-2.aspx",
      "snippet": "Annual leave carry-over is capped at five days…"
    }
  ]
}
```

When the user clicks `[1]` in the rendered answer, Teams opens a side card with the title, snippet, sensitivity label and link — i.e. **users can view the source documents directly from the chat**. The `position` number on each citation must match the inline `[n]` markers in the answer text; ensure the orchestrator's prompt instructs the model to insert `[n]` markers in order.

---

### 6.4 AI-generated content label

The label is enabled in two places:

- `supportsAIGeneratedContent: true` in the manifest (§6.1).
- `generatedByAILabel: true` in the `endStream` call (§6.2), or `entities: [{ type: "https://schema.org/Message", "@context": "https://schema.org", additionalType: ["AIGeneratedContent"] }]` on a non-streamed activity.

Apply the label to **all** model-generated replies. Do **not** apply it to deterministic responses (e.g. "Sorry, I couldn't reach the knowledge service") — those are not AI-generated.

---

### 6.5 Feedback loop

With `feedbackLoop: { type: "default" }` (§6.2) — or `feedbackLoopEnabled: true` on a non-streamed activity — Teams renders 👍 / 👎 controls and an optional comment dialog under each AI reply. When the user reacts, Teams sends an `invoke` activity of name `message/submitAction` back to the bot. Handle it and persist:

```typescript
app.feedbackLoop(async (context, _state, feedback) => {
  await persistFeedback({
    conversationId: context.activity.replyToId,
    userId: context.activity.from?.aadObjectId,
    rating: feedback.actionValue.reaction,        // "like" | "dislike"
    comment: feedback.actionValue.feedback,       // free text or undefined
    timestamp: new Date().toISOString(),
  });
});
```

Persist feedback into **Cosmos DB** (the same account the accelerator already uses for conversations) and emit a custom event into **Application Insights** for offline evaluation pipelines and prompt tuning.

---

### 6.6 Single Sign-On + On-Behalf-Of

So that the orchestrator can apply **per-user security trimming** (see [`docs/CUSTOMIZATIONS_SEARCH_TRIMMING.md`](CUSTOMIZATIONS_SEARCH_TRIMMING.md)), the bot must call the orchestrator **as the user**, not as itself.

1. **Enable Teams SSO** during provisioning. The Agents Toolkit's `m365agents.yml` has an `aadApp/create` and `aadApp/update` action that creates the bot's Entra ID app registration and exposes a scope (e.g. `access_as_user`). Add the orchestrator's app id to the `knownClientApplications`.
2. **Add SSO to the manifest**:

   ```jsonc
   {
     "webApplicationInfo": {
       "id": "${{AAD_APP_CLIENT_ID}}",
       "resource": "api://botid-${{BOT_ID}}"
     }
   }
   ```

3. **Acquire a user token** at the start of each turn:

   ```typescript
   import { OnBehalfOfUserCredential } from "@microsoft/teamsfx";

   async function getOboTokenForUser(context: TurnContext): Promise<string> {
     const ssoToken = await context.adapter.getUserToken(
       context, "graph", undefined
     );
     const credential = new OnBehalfOfUserCredential(ssoToken.token, {
       authorityHost: "https://login.microsoftonline.com",
       tenantId: process.env.AAD_APP_TENANT_ID!,
       clientId: process.env.AAD_APP_CLIENT_ID!,
       clientSecret: process.env.AAD_APP_CLIENT_SECRET!,
     });
     const orchestratorToken = await credential.getToken(
       `${process.env.ORCHESTRATOR_AUDIENCE}/.default`
     );
     return orchestratorToken!.token;
   }
   ```

4. **Forward the user token** to the orchestrator (the `user_token` field already plumbed through `callOrchestrator` in [Step 2](TEAMS_INTEGRATION_STEP2.md)). Update the orchestrator to read this token and use its `oid` / `groups` claims for AI Search security trimming.

If the user has not yet consented to the bot, `getUserToken` returns `null`. Reply with an OAuth card (`CardFactory.oauthCard`) to prompt for consent — the Teams AI Library has an `app.authentication` helper that wraps this pattern.

---

### 6.7 Adaptive Card rendering of the structured response

For richer answers — especially NL2SQL results, multi-step reasoning, or answers with many citations — render the response as an Adaptive Card 1.5 instead of plain text. Wrap the streaming reply with a final Adaptive Card that exposes:

- The headline answer.
- A **collapsible "Show sources"** section listing each citation as an `Action.OpenUrl`.
- A **collapsible "View reasoning"** section that renders `result.thought_process` (for debugging / power users — gate this on a feature flag and never expose it externally).
- **Suggested follow-up questions** as `Action.Submit` buttons (the orchestrator can return up to three follow-ups in a `suggested_followups` field).

Keep card payloads under the **28 KB Teams activity limit** — for very long answers, keep the streamed text as the primary surface and use the card only for the metadata (sources, followups, reasoning toggle).

---

### 6.8 Putting it all together — checklist

Before declaring the Teams experience production-ready:

- [ ] `manifestVersion` ≥ `1.19` and the four `supports*` flags are set (§6.1).
- [ ] All AI replies use `streamingResponse` and call `endStream({ generatedByAILabel: true, feedbackLoop: { type: "default" } })` (§§6.2, 6.4, 6.5).
- [ ] The orchestrator returns `citations[]` and the bot maps them with `setCitations` (§6.3).
- [ ] Feedback events are persisted to Cosmos and surfaced in App Insights (§6.5).
- [ ] SSO is enabled, OBO tokens are forwarded, and the orchestrator honours the user's identity for security trimming (§6.6).
- [ ] Adaptive Cards are used for structured responses; long answers stay below the 28 KB activity limit (§6.7).
- [ ] All deterministic / error replies do **not** carry the AI-generated label.
- [ ] App Insights dashboards exist for: turn count, average orchestrator latency, error rate, thumbs-down rate, and SSO consent failures.

---

## Additional Resources
- [Step 5: Publish the Teams app](TEAMS_INTEGRATION_STEP5.md).
- [`docs/CUSTOMIZATIONS_SEARCH_TRIMMING.md`](CUSTOMIZATIONS_SEARCH_TRIMMING.md) — per-user security trimming on AI Search.
- [`docs/QUERYING_CONVERSATIONS.md`](QUERYING_CONVERSATIONS.md) — schema for Cosmos conversation/feedback documents.

## External Resources
- [Stream bot messages](https://learn.microsoft.com/microsoftteams/platform/bots/how-to/bot-messages-ai-generated-content#stream-bot-messages).
- [Format AI bot messages — citations and AI-generated label](https://learn.microsoft.com/microsoftteams/platform/bots/how-to/bot-messages-ai-generated-content).
- [Collect feedback from users](https://learn.microsoft.com/microsoftteams/platform/bots/how-to/conversations/conversation-messages?tabs=dotnet#feedback-buttons).
- [Teams SSO for bots](https://learn.microsoft.com/microsoftteams/platform/bots/how-to/authentication/bot-sso-overview).
- [On-Behalf-Of flow with `@microsoft/teamsfx`](https://learn.microsoft.com/microsoftteams/platform/toolkit/add-single-sign-on).
- [Adaptive Cards in Teams](https://learn.microsoft.com/microsoftteams/platform/task-modules-and-cards/cards/cards-reference).
- [Custom Engine Agents for Microsoft 365 Copilot](https://learn.microsoft.com/microsoft-365-copilot/extensibility/overview-custom-engine-agent).
