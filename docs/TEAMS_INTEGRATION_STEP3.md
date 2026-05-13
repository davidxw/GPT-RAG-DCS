# Guide for Building a Teams App Interface for Enterprise GPT-RAG Solution Accelerator

*Ensure all steps in [Step 2](TEAMS_INTEGRATION_STEP2.md) are completed before proceeding.*

## Step 3: Provision and deploy Azure resources (reusing accelerator infra)

The accelerator already provisions hardened, VNet-integrated compute and a private network path to the orchestrator. **Reuse those resources rather than letting the Agents Toolkit stand up a new public-facing App Service.** This keeps the bot inside the same security boundary as the rest of the GPT-RAG deployment and avoids opening a second egress path to Azure OpenAI.

### 3.1 Decide where the bot will run

Pick the host that best matches your operational model:

| Option | When to choose it | Bicep reference |
| ------ | ----------------- | --------------- |
| **Reuse the existing App Service** | Default. The accelerator's web frontend host already has VNet integration, Managed Identity, App Insights and Key Vault wiring. | [`infra/core/host/appservice.bicep`](../infra/core/host/appservice.bicep) |
| **Reuse the existing Function App** | You prefer a serverless model and your traffic is bursty. | [`infra/core/host/functions.bicep`](../infra/core/host/functions.bicep) |
| **New App Service / Function App / Container App** | You need strict isolation between the Teams bot and the web frontend (separate identity, separate scaling, separate deployment cadence). | New module under `infra/core/host/`. |

Whichever option you choose, the **Azure Bot Service** registration is always new — there is one Bot Service per messaging endpoint.

### 3.2 Trim the Agents Toolkit's default infrastructure

The scaffolded `infra/` folder under the Teams project assumes a standalone deployment. Edit it so that **only the Bot Service registration and role assignments are created by the toolkit**, and the compute target is referenced by resource id.

Edit `m365agents.yml` (formerly `teamsapp.yml`) so the `provision` lifecycle only:

1. Reads the existing compute resource id (App Service or Function App) from the environment file.
2. Creates / updates the **Azure Bot Service** registration, pointing its **messaging endpoint** to `https://<existing-host>/api/messages`.
3. Creates / updates the bot's **Entra ID app registration** (used by the messaging endpoint and by SSO in [Step 6](TEAMS_INTEGRATION_STEP6.md)).
4. Assigns the **existing user-assigned Managed Identity** to the bot host (no new identity).
5. Grants that Managed Identity the **role on the orchestrator** required to call it (e.g. a custom role, or `Cognitive Services User` if the orchestrator wraps Azure OpenAI directly).

Add the following to `env/.env.<env>` to point the toolkit at the accelerator's resources:

```dotenv
EXISTING_RESOURCE_GROUP=<rg-of-accelerator>
EXISTING_APP_SERVICE_ID=/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Web/sites/<webapp>
EXISTING_USER_ASSIGNED_MI_ID=/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<mi>
ORCHESTRATOR_RESOURCE_ID=/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Web/sites/<orchestrator-func>
```

> The existing App Service / Function App must have a **path** free for the bot's `/api/messages` route. If the host is already serving the GPT-RAG web frontend on `/`, the bot can co-exist on `/api/messages`; otherwise, choose the Function App or stand up a dedicated host.

### 3.3 Keep the bot's outbound traffic private

The bot's **inbound** messaging endpoint must be reachable from the Bot Service (i.e. the public internet, optionally protected by Front Door + WAF). The bot's **outbound** traffic to the orchestrator should stay on the VNet:

- Confirm the host has **VNet integration** enabled against the accelerator's VNet (see [`infra/core/network/vnet.bicep`](../infra/core/network/vnet.bicep)).
- Confirm a **private endpoint** for the orchestrator exists in that VNet, and that the corresponding **Private DNS Zone** ([`infra/core/network/private-dns-zones.bicep`](../infra/core/network/private-dns-zones.bicep)) resolves the orchestrator hostname to the private IP.
- Set `WEBSITE_VNET_ROUTE_ALL=1` (App Service) or `vnetRouteAllEnabled: true` (Function App) so all egress goes through the VNet.

### 3.4 Provision and deploy

1. Open the **Microsoft 365 Agents Toolkit** sidebar.
2. **Sign in to Microsoft 365** and **Sign in to Azure**.
3. Choose **Provision** under the **Lifecycle** section. Select the subscription and the **existing resource group** that holds the accelerator. The toolkit will create the Bot Service registration and the Entra ID app, and bind them to the existing host.
4. Once provisioning completes, choose **Deploy**. This packages the Node.js app and deploys it into the existing App Service / Function App.
5. In the Azure Portal, confirm:
   - The Bot Service shows **Messaging endpoint** = `https://<existing-host>/api/messages` and **Microsoft App ID** = the toolkit-created app registration.
   - The host has the **user-assigned Managed Identity** attached.
   - **App settings** include `ORCHESTRATOR_ENDPOINT`, `ORCHESTRATOR_AUDIENCE`, and (if needed) `KEYVAULT_NAME`.

### 3.5 Smoke test

From a Teams client where you've sideloaded the previous Step 2 build, send a question. Tail the host's **Application Insights** (`requests`, `dependencies`, `traces`) and confirm:

- The bot received the message activity.
- The outbound call to the orchestrator left over the **private endpoint** (the dependency target should be the private FQDN).
- A response was returned to the user within `ORCHESTRATOR_TIMEOUT_MS`.

---

Proceed to [Step 4: Build the Teams app package](TEAMS_INTEGRATION_STEP4.md).

## Additional Resources
- [Step 2: Connect to GPT-RAG Orchestrator and test locally](TEAMS_INTEGRATION_STEP2.md).
- [Step 4: Build the Teams app package](TEAMS_INTEGRATION_STEP4.md).
- [Step 6: Add rich RAG UX](TEAMS_INTEGRATION_STEP6.md).
- Relevant accelerator Bicep:
  [`infra/core/host/appservice.bicep`](../infra/core/host/appservice.bicep),
  [`infra/core/host/functions.bicep`](../infra/core/host/functions.bicep),
  [`infra/core/network/vnet.bicep`](../infra/core/network/vnet.bicep),
  [`infra/core/network/private-dns-zones.bicep`](../infra/core/network/private-dns-zones.bicep),
  [`infra/core/network/private-endpoint.bicep`](../infra/core/network/private-endpoint.bicep).

## External Resources
- [Provision cloud resources with the Agents Toolkit](https://learn.microsoft.com/microsoftteams/platform/toolkit/provision).
- [Deploy a Teams app to the cloud](https://learn.microsoft.com/microsoftteams/platform/toolkit/deploy).
- [Integrate App Service with an Azure virtual network](https://learn.microsoft.com/azure/app-service/overview-vnet-integration).
- [Azure Functions networking options](https://learn.microsoft.com/azure/azure-functions/functions-networking-options).
- [Azure Bot Service messaging endpoint requirements](https://learn.microsoft.com/azure/bot-service/bot-builder-howto-deploy-azure).
