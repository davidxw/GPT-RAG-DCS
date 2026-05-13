# Guide for Building a Teams App Interface for Enterprise GPT-RAG Solution Accelerator

*Ensure all steps in [Step 4: Build the Teams app package](TEAMS_INTEGRATION_STEP4.md) are completed before proceeding.*

## Step 5: Publish the Teams app

Once you have a packaged `.zip`, you have three publishing paths:

| Path | Audience | When to use |
| ---- | -------- | ----------- |
| **Custom upload (sideload)** | The signed-in user only | Smoke testing on your own account. Requires custom upload to be enabled in the tenant. |
| **Developer Portal → Publish to your org** | Whole tenant (after admin approval) | Production rollout inside your organization. |
| **Developer Portal → Publish to the Teams Store** | Public | Only relevant if you intend to distribute the bot externally. Uncommon for GPT-RAG. |

### 5.1 Custom upload (individual testing)

1. In the Teams client (desktop or web), select **Apps → Manage your apps → Upload an app**.

   ![Upload Teams App](../media/teams-guide-Step5a.png)

2. Choose **Upload a custom app**.

   ![Upload a custom app](../media/teams-guide-Step5b.png)

3. Select the `.zip` produced in [Step 4](TEAMS_INTEGRATION_STEP4.md) (e.g. `appPackage/build/appPackage.dev.zip`).

   ![Select Zip File](../media/teams-guide-Step5c.png)

4. Click **Add**.

   ![Add button](../media/teams-guide-Step5d.png)

5. Wait for the app to install.

   ![App Added Success](../media/teams-guide-Step5f.png)

6. Open the bot, ask a question, and confirm the answer comes back from the orchestrator.

   ![Test prompt](../media/teams-guide-Step5g.png)

   ![Chat Response](../media/teams-guide-Step5h.png)

### 5.2 Tenant-wide publishing via the Developer Portal

For a controlled tenant rollout:

1. Open the [Developer Portal for Teams](https://dev.teams.microsoft.com/).
2. **Apps → Import app** and upload your `.zip`.
3. Run **App validation** and resolve any errors.
4. **Publish → Publish to your org** to submit the app to your **Teams Admin Center → Manage apps** queue.
5. A Teams admin reviews and approves; the app then appears in the **Built for your org** category for users in the tenant.

Full instructions: [Publish a Teams app to your org](https://learn.microsoft.com/microsoftteams/platform/toolkit/publish-your-teams-apps-using-developer-portal).

### 5.3 Custom Engine Agent in Microsoft 365 Copilot (optional)

If you scaffolded the project as a **Custom Engine Agent** in [Step 1](TEAMS_INTEGRATION_STEP1.md), the same package also makes the bot available inside **Microsoft 365 Copilot Chat**. After tenant approval, users can `@`-mention the agent from Copilot Chat and reach the orchestrator without ever leaving Copilot. No separate codebase or hosting is required.

---

Once the bot is reachable in Teams, continue to [Step 6: Add rich RAG UX (citations, streaming, AI label, feedback, SSO)](TEAMS_INTEGRATION_STEP6.md) to turn the basic responder into a production-grade RAG agent.

## Additional Resources
- [Step 4: Build the Teams app package](TEAMS_INTEGRATION_STEP4.md).
- [Step 6: Add rich RAG UX](TEAMS_INTEGRATION_STEP6.md).

## External Resources
- [Publish Teams apps using the Agents Toolkit](https://learn.microsoft.com/microsoftteams/platform/toolkit/publish#upload-app-package).
- [Integrate with the Developer Portal](https://learn.microsoft.com/microsoftteams/platform/toolkit/publish-your-teams-apps-using-developer-portal).
- [Teams admin centre — manage custom apps](https://learn.microsoft.com/microsoftteams/manage-apps).