# Guide for Building a Teams App Interface for Enterprise GPT-RAG Solution Accelerator

*Ensure all prerequisites listed in [the main guide](TEAMS_INTEGRATION_MAIN.md#prerequisites) are completed before proceeding.*

## Step 1: Create a new Teams app project

This step replaces the legacy *Teams Toolkit → Basic Bot* flow with the modern **Microsoft 365 Agents Toolkit → AI Chat Bot (Teams AI Library)** template. The AI Chat Bot template is purpose-built for LLM/RAG scenarios — it ships with first-class support for streaming, citations, the AI-generated content label, and the feedback loop that we configure in [Step 6](TEAMS_INTEGRATION_STEP6.md).

### 1.1 Open the Agents Toolkit

1. Open **Visual Studio Code**.
2. Select the **Microsoft 365 Agents Toolkit** icon in the sidebar (formerly *Teams Toolkit* — the extension self-rebranded; the Marketplace ID is unchanged).
3. Choose **Create a New App** (or **Create a New Agent**, depending on the toolkit version).

![Agents Toolkit, Create New App](../media/teams-guide-Step1a.png)

### 1.2 Choose the project type

1. Select **Agent / Bot** as the app capability.
2. From the template list, choose **AI Chat Bot** (also labelled *Custom Engine Agent* in newer versions). Do **not** pick *Basic Bot* — that template is the legacy Bot Framework starter and lacks the RAG-specific primitives this guide relies on.

   > If you want the same project to also be invokable from **Microsoft 365 Copilot Chat**, select the *Custom Engine Agent* variant. The Teams scope and the Copilot scope share the same code; only the manifest differs.

3. Choose **TypeScript** as the programming language. (The same flow works for JavaScript, Python and C#; this guide uses TypeScript for parity with the prior revision.)
4. Select a **Large Language Model** option of **Azure OpenAI** when prompted. This only seeds local config keys — the app will actually call the GPT-RAG Orchestrator (which fronts Azure OpenAI), wired up in [Step 2](TEAMS_INTEGRATION_STEP2.md). Leave the model name as the default for now.
5. Select **Browse** and pick a folder for the project workspace.
6. Enter an application name such as `GPTRAGTeams` (alphanumeric only). Press **Enter**.

### 1.3 Verify the generated project

After scaffolding completes, the workspace should contain:

| Path | Purpose |
| ---- | ------- |
| `src/app/app.ts` (or `src/index.ts`) | Teams AI Library `Application` instance — the entry point for all messages. |
| `src/prompts/chat/` | Prompt templates and `config.json` (system prompt + model parameters). |
| `appPackage/manifest.json` | Teams app manifest. **Confirm `"manifestVersion": "1.19"` or later**; bump it if the toolkit generated an older version. |
| `m365agents.yml` (formerly `teamsapp.yml`) | Toolkit lifecycle definition: `provision`, `deploy`, `publish`. |
| `infra/` | Bicep for the bot's Azure resources (Bot Service registration, optional App Service Plan / Function App). We will **trim this** in [Step 3](TEAMS_INTEGRATION_STEP3.md) to reuse existing accelerator infra. |
| `env/` | Per-environment config (`.env.local`, `.env.dev`, etc.). |

### 1.4 Confirm the SDK versions

Open `package.json` and verify dependency versions roughly match:

```jsonc
{
  "dependencies": {
    "@microsoft/teams-ai": "^2.0.0",            // Teams AI Library v2
    "@microsoft/agents-bot-hosting": "^1.0.0",  // M365 Agents SDK runtime (replaces botbuilder-* in maintenance)
    "botbuilder": "^4.22.0",                    // still present for Activity types
    "express": "^4.x",
    "restify": "^11.x"
  }
}
```

If `@microsoft/teams-ai` is at a `1.x` version, run `npm install @microsoft/teams-ai@latest` — the streaming, citation and feedback APIs used in [Step 2](TEAMS_INTEGRATION_STEP2.md) and [Step 6](TEAMS_INTEGRATION_STEP6.md) are v2-only.

---

Proceed to [Step 2: Connect to GPT-RAG Orchestrator and test locally](TEAMS_INTEGRATION_STEP2.md).

## Additional Resources
- [Prerequisites - main guide](TEAMS_INTEGRATION_MAIN.md#prerequisites).
- [Step 2: Connect to GPT-RAG Orchestrator and test locally](TEAMS_INTEGRATION_STEP2.md).
- [Step 6: Add rich RAG UX](TEAMS_INTEGRATION_STEP6.md).

## External Resources
- [Install the Microsoft 365 Agents Toolkit](https://learn.microsoft.com/microsoftteams/platform/toolkit/install-teams-toolkit?tabs=vscode).
- [Teams AI Library overview](https://learn.microsoft.com/microsoftteams/platform/bots/how-to/teams%20conversational%20ai/teams-conversation-ai-overview).
- [Custom Engine Agents for Microsoft 365 Copilot](https://learn.microsoft.com/microsoft-365-copilot/extensibility/overview-custom-engine-agent).
- [Manifest schema v1.19+](https://learn.microsoft.com/microsoftteams/platform/resources/schema/manifest-schema).
- [Directory structure for app types](https://learn.microsoft.com/microsoftteams/platform/toolkit/create-new-project#directory-structure-for-different-app-types).
