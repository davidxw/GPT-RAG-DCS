# Guide for Building a Teams App Interface for the Enterprise GPT-RAG Solution Accelerator

## Introduction
This guide describes how to build a modern Teams chat experience for the Enterprise GPT-RAG Solution Accelerator using the **Microsoft 365 Agents Toolkit** (the evolution of the original *Teams Toolkit* for VS Code) and the **Teams AI Library v2**. The resulting bot connects to the GPT-RAG Orchestrator and surfaces answers with first-class RAG UX — token streaming, source citations, an "AI generated" label, and thumbs-up/thumbs-down feedback.

> **What changed vs. previous versions of this guide.** Earlier revisions targeted the legacy *Teams Toolkit* with the *Basic Bot* template (Bot Framework SDK `ActivityHandler`). That stack is now in maintenance. This revision targets:
>
> - **Microsoft 365 Agents Toolkit** (renamed from *Teams Toolkit* in 2025).
> - The **AI Chat Bot / Custom Engine Agent** project template, built on **Teams AI Library v2** (`@microsoft/teams-ai`).
> - **Manifest schema v1.19+** so streaming, citations, the AI-generated label, and the feedback loop can be declared.
> - **Reuse of existing GPT-RAG infrastructure** (VNet-integrated App Service or Function App) plus **private connectivity** to the orchestrator instead of provisioning a new public-facing App Service.

## Key Solution Components
The following are required in addition to those already deployed in the Enterprise RAG Solution Accelerator. **Reuse the accelerator's existing resources wherever possible** — see [Step 3](TEAMS_INTEGRATION_STEP3.md) for the reuse vs. greenfield decision.

- **Azure Bot Service** — the messaging endpoint registration that connects Teams to the bot.
- **Compute host** — one of:
  - the **existing VNet-integrated App Service** from `infra/core/host/appservice.bicep`, or
  - the **existing Function App** from `infra/core/host/functions.bicep` (HTTP-triggered), or
  - a new App Service / Function App / Container App if isolation is required.
- **User-Assigned Managed Identity** — used by the bot to (a) read configuration from Key Vault and (b) acquire tokens for the orchestrator (no shared secrets).
- **Private endpoint or VNet integration** so the bot reaches the orchestrator over the same private network as the rest of the accelerator. The bot's *messaging endpoint* itself remains internet-reachable (Bot Service requires this), but **outbound** traffic to the orchestrator stays private.
- **Entra ID app registration** for the bot, configured for **Teams SSO** so the user's identity can be flowed to the orchestrator via On-Behalf-Of (enables per-user security trimming).

## Prerequisites
Before proceeding, ensure you have:

- An **Azure subscription** with permission to create Bot Service registrations and to assign roles on the existing accelerator resources.
- A **Microsoft 365 tenant** account. For test tenants, see the [Microsoft 365 developer program](https://learn.microsoft.com/microsoftteams/platform/toolkit/tools-prerequisites#microsoft-365-developer-program).
- The **Enterprise GPT-RAG Solution Accelerator** deployed in your subscription, with the orchestrator endpoint reachable from your chosen compute host.
- For tenant publishing, access to a **Teams admin**. For individual testing, custom upload (sideloading) must be enabled in your tenant.
- Permission to **create or update an Entra ID app registration** for the bot (required for SSO).

Set up the following on the development machine:

- [Visual Studio Code](https://code.visualstudio.com/Download).
- **Node.js 18 LTS or later** (Node 20 LTS recommended). The legacy Node 16 requirement no longer applies.
- The **[Microsoft 365 Agents Toolkit](https://marketplace.visualstudio.com/items?itemName=TeamsDevApp.ms-teams-vscode-extension)** extension for VS Code (this is the same Marketplace listing as the former *Teams Toolkit*; it self-rebranded).
- Optional but recommended: the **Microsoft 365 Agents Toolkit CLI** (`@microsoft/m365agentstoolkit-cli`) for headless provisioning in CI.

## Steps

1. **[Create a new Teams app project](TEAMS_INTEGRATION_STEP1.md)** — scaffold an *AI Chat Bot* (Teams AI Library) project with the M365 Agents Toolkit.
2. **[Connect to the GPT-RAG Orchestrator and test locally](TEAMS_INTEGRATION_STEP2.md)** — wire the Teams AI `Application` to the orchestrator with streaming, retries, and structured error handling.
3. **[Provision and deploy Azure resources (reusing accelerator infra)](TEAMS_INTEGRATION_STEP3.md)** — host the bot on the existing VNet-integrated App Service or Function App and reach the orchestrator via private endpoint.
4. **[Build the Teams app package](TEAMS_INTEGRATION_STEP4.md)** — produce the `.zip` for sideloading or store submission.
5. **[Publish the Teams app](TEAMS_INTEGRATION_STEP5.md)** — sideload for testing or submit through the Developer Portal / tenant catalog.
6. **[Add rich RAG UX (citations, streaming, AI label, feedback, SSO)](TEAMS_INTEGRATION_STEP6.md)** — turn the basic bot into a production-grade RAG agent.

## External Resources
- [Microsoft 365 Agents Toolkit overview](https://learn.microsoft.com/microsoftteams/platform/toolkit/teams-toolkit-fundamentals).
- [Teams AI Library](https://learn.microsoft.com/microsoftteams/platform/bots/how-to/teams%20conversational%20ai/teams-conversation-ai-overview).
- [Microsoft 365 Agents SDK](https://learn.microsoft.com/microsoft-365/agents-sdk/).
- [Visual Studio Code](https://code.visualstudio.com/Download).
- [Microsoft 365 developer program](https://learn.microsoft.com/microsoftteams/platform/toolkit/tools-prerequisites#microsoft-365-developer-program).
- [App manifest schema reference (v1.19+)](https://learn.microsoft.com/microsoftteams/platform/resources/schema/manifest-schema).

