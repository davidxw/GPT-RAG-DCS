# Guide for Building a Teams App Interface for Enterprise GPT-RAG Solution Accelerator

*Ensure all steps in [Step 3](TEAMS_INTEGRATION_STEP3.md) are completed before proceeding.*

## Step 4: Build the Teams app package

The Teams app package is a `.zip` containing the manifest, icons, and (optionally) localization resources. It is what users sideload, and what you submit to the Developer Portal.

### 4.1 Confirm the manifest is up to date

Before zipping, open `appPackage/manifest.json` and verify:

- `"manifestVersion": "1.19"` (or later). v1.19+ is required for the `bots[].supportsStreaming`, `supportsAIGeneratedContent`, citation entities, and the feedback loop that [Step 6](TEAMS_INTEGRATION_STEP6.md) enables.
- The bot's `botId` matches the Entra ID app registration created during provisioning.
- `scopes` includes the surfaces you want — `personal` (1:1 chat), `team`, and/or `groupChat`.
- For Custom Engine Agent reach into Microsoft 365 Copilot Chat, the `copilotAgents` section is present.

### 4.2 Zip the package

1. Open the **Microsoft 365 Agents Toolkit** sidebar.
2. Choose **Utility → Zip Teams App Package**.

   ![Zip Teams App Package](../media/teams-guide-Step4a.png)

3. Select the **manifest JSON** file (`appPackage/manifest.json`).

   ![Manifest file selection](../media/teams-guide-Step4b.png)

4. Choose the **environment** (`local`, `dev`, `prod`, …). The toolkit substitutes environment-specific values (bot id, endpoint URLs) into the manifest at this point. See [Environments in the M365 Agents Toolkit](https://learn.microsoft.com/microsoftteams/platform/toolkit/teamsfx-multi-env).

   ![Environment selection](../media/teams-guide-Step4c.png)

5. Wait for the build to complete. The output `.zip` is written to `appPackage/build/appPackage.<env>.zip`.

   ![Local Address link](../media/teams-guide-Step4d.png)

6. Inspect the build output. You should see the zip alongside the rendered `manifest.<env>.json` — review that file to confirm the substituted bot id and endpoint look correct before publishing.

   ![Teams App Files](../media/teams-guide-Step4e.png)

### 4.3 Validate (optional but recommended)

Run the Teams App validator before publishing — either via **Utility → Validate Application → Validate using App Validation Tool** in the toolkit, or via the [App validation page in the Developer Portal](https://dev.teams.microsoft.com/validation). It catches manifest issues that the toolkit does not (icon contrast, missing privacy URL, oversized descriptions, etc.).

---

Proceed to [Step 5: Publish the Teams app](TEAMS_INTEGRATION_STEP5.md).

## Additional Resources
- [Step 3: Provision and deploy Azure resources](TEAMS_INTEGRATION_STEP3.md).
- [Step 5: Publish the Teams app](TEAMS_INTEGRATION_STEP5.md).
- [Step 6: Add rich RAG UX](TEAMS_INTEGRATION_STEP6.md).

## External Resources
- [Teams app package](https://learn.microsoft.com/microsoftteams/platform/concepts/build-and-test/apps-package).
- [App manifest schema reference (v1.19+)](https://learn.microsoft.com/microsoftteams/platform/resources/schema/manifest-schema).
- [Environments in the Microsoft 365 Agents Toolkit](https://learn.microsoft.com/microsoftteams/platform/toolkit/teamsfx-multi-env).
- [App validation in the Developer Portal](https://dev.teams.microsoft.com/validation).
