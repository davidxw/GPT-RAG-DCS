# SharePoint Setup

This section explains how to configure SharePoint as a data source for the `ragindex` GPT-RAG Azure AI Search Index, using the `Sites.Selected` permission to limit access to specific site collections.

> [!IMPORTANT]
> **Tested ingestor version.** This fork (GPT-RAG-DCS) currently pins the ingestion Function App to
> [`Azure/gpt-rag-ingestion` `release/1.0.1`](https://github.com/Azure/gpt-rag-ingestion/tree/release/1.0.1).
> The behaviour described below &mdash; environment variables, schedule, supported formats, ACL handling,
> and known limits &mdash; reflects that branch. Newer upstream releases (e.g. `main`/v2.x) change
> the connector substantially and may not match this guide.

## How the SharePoint connector works (1.0.1)

The connector is built on a **pull-from-SharePoint, push-to-Search** model:

- **Pull from SharePoint** &mdash; two timer-triggered Python Azure Functions inside the GPT-RAG
  ingestion Function App poll Microsoft Graph on a schedule. SharePoint itself does not push events
  to GPT-RAG (no webhook, no change-notification subscription, no Azure AI Search built-in
  SharePoint indexer); discovery happens entirely via outbound Graph calls from the Function App.
- **Push to Azure AI Search** &mdash; once a file is downloaded and chunked, the Function App
  upserts the chunks + embeddings directly into the `ragindex` Azure AI Search index. The Search
  service is never given direct access to SharePoint.

The two functions are:

| Function | Purpose | Trigger (per [`function_app.py`](https://github.com/Azure/gpt-rag-ingestion/blob/release/1.0.1/function_app.py) on `release/1.0.1`) |
|---|---|---|
| `sharepoint_index_files` | List files in the configured site/folder via Graph, decide which need (re-)indexing (by comparing `metadata_storage_last_modified`), download, chunk, embed, and upsert into `ragindex`. | Timer trigger. |
| `sharepoint_purge_deleted_files` | Walk the index, ask Graph whether each indexed SharePoint file still exists, and delete index entries for files that no longer do. | `schedule="0 */60 * * * *"` &mdash; every 60&nbsp;minutes. |

> [!NOTE]
> The upstream README sometimes describes both functions as running every 10&nbsp;minutes. On the
> `release/1.0.1` branch the purger's CRON expression is actually every 60&nbsp;minutes &mdash; verify
> the schedule in `function_app.py` for the version you have deployed, and override via Function App
> application settings if you need a different cadence.

Both functions are gated by `SHAREPOINT_CONNECTOR_ENABLED=true`. Both target the **single**
site + folder + file-format set defined by the `SHAREPOINT_*` environment variables below &mdash;
1.0.1 does not support multiple sites or folders from one Function App.

### Prerequisites  

Before executing this procedure ensure you have the necessary roles for each step:  

| Steps | Required Role(s) |
|--------|------------------|
| **Register app and assign `Sites.Selected`.** | Global Administrator, Application Administrator, or Cloud Application Administrator. |
| **Grant admin consent.** | Global Administrator or Application Administrator. |
| **Get SharePoint Site ID via Graph API.** | SharePoint Administrator, Global Administrator, or a user with access to the site. |
| **Assign site permissions via Graph API.** | SharePoint Administrator or Global Administrator. |


## Procedure

1. **Register an Application in Azure Entra ID**

   - **Sign in to the Azure Portal**: Go to [Azure Portal](https://portal.azure.com/).

   - **Register a New Application**:

     - Navigate to **Azure Active Directory** > **App registrations** > **New registration**.
     - **Name**: Enter a name for your application (e.g., `SharePointDataIngestionApp`).
     - **Supported Account Types**: Choose **Accounts in this organizational directory only**.
     - **Redirect URI**: Leave this field empty.
     - Click **Register**.

    ![Register Application](../media/sharepoint-register-app.png)

   - **Record Application IDs**:

     - *Save the **Application ID** and **Tenant ID** for later use.*

    ![Register Application](../media/sharepoint-record-app-id.png)

2. **Configure API Permissions**

   - **Navigate to API Permissions**:

     - In your registered application, go to **API permissions** > **Add a permission**.

   - **Add Microsoft Graph Permissions**:

     - Select **Microsoft Graph** > **Application permissions**.
     - Search for and add the following permission:

       - **`Sites.Selected`**

     - Click **Add permissions**.

   - **Grant Admin Consent**:

     - Click **Grant admin consent for [Your Tenant Name]**.
     - Confirm the action when prompted.

     ![Grant Admin Consent](../media/sharepoint-site-selected-app.png)
     *Granting admin consent for `Sites.Selected` permission*

3. **Assign Access to Specific Site Collections**

   The `Sites.Selected` permission requires you to explicitly grant the application access to specific site collections. This step must be performed using the Microsoft Graph API.

   > [!NOTE]
   > Currently, assigning site permissions using `Sites.Selected` cannot be done through the Azure Portal. You need to use Microsoft Graph API or PowerShell.

   - **Gather Site Information**:

     - **Site URL**: Navigate to the SharePoint site you wish to index and note its URL (e.g., `https://yourdomain.sharepoint.com/sites/YourSiteName`).
     - **Site ID**: You can retrieve the Site ID using Microsoft Graph API.

    ![Getting site URL](../media/sharepoint-site-url.png)
    *Getting site URL*

   - **Retrieve Site ID**:

     - **Use Microsoft Graph Explorer**:

       - Go to [Microsoft Graph Explorer](https://developer.microsoft.com/graph/graph-explorer).
       - Sign in with an account that has access to the site.
       - Make a `GET` request to:

         ```http
         GET https://graph.microsoft.com/v1.0/sites/{hostname}:/{server-relative-path}
         ```

         Replace `{hostname}` with your SharePoint domain (e.g., `yourdomain.sharepoint.com`) and `{server-relative-path}` with the site path (e.g., `/sites/YourSiteName`).

       - **Example**:

         ```http
         GET https://graph.microsoft.com/v1.0/sites/yourdomain.sharepoint.com:/sites/YourSiteName
         ```

       - The response will include the `id` of the site.

    ![Getting site ID](../media/sharepoint-site-id.png)
    *Getting site ID*    

   - **Grant the Application Access to the Site**:

     - **Make a `POST` Request to Grant Permissions**:

       - In Microsoft Graph Explorer, make a `POST` request to:

         ```http
         POST https://graph.microsoft.com/v1.0/sites/{site-id}/permissions
         ```

         Replace `{site-id}` with the ID obtained in the previous step.

       - **Request Body**:

         ```json
         {
           "roles": ["read"],
           "grantedToIdentities": [
             {
               "application": {
                 "id": "your_application_id",
                 "displayName": "Your Application Name"
               }
             }
           ]
         }
         ```


         - Replace `your_application_id` with your application's **Client ID**.
         - Replace `Your Application Name` with your application's name.
         - The `"roles"` can be `"read"` or `"write"` depending on your needs.

       - **Example**:

         ```json
         {
           "roles": ["read"],
           "grantedToIdentities": [
             {
               "application": {
                 "id": "12345678-90ab-cdef-1234-567890abcdef",
                 "displayName": "SharePointDataIngestionApp"
               }
             }
           ]
         }
         ```

   - **Run the Query** and ensure you receive a `201 Created` response.

   - **Repeat** the permission assignment for each site you wish to index.

    ![Assign Site Permissions](../media/sharepoint-site-permissions-created.png)
         *Assigning site permissions via Microsoft Graph Explorer*
    
    
   - **If you encounter a permission denied error when trying to assign site permissions**:
    
    If you encounter a permission error, like the one shown in the next screen, it may be necessary to grant permissions to your user.
    
    ![Assign Site Permissions](../media/sharepoint-site-permissions-403.png)
    *Permission error when assigning permissions*
    
    If this is the case, grant the required permissions as shown in the next image.
    
    ![Assign Site Permissions](../media/sharepoint-site-permissions-403-02.png)
    *Adding consent for user to apply permissions*

4. **Create a Client Secret**

   - **Navigate to Certificates & Secrets**:

     - Under the **Manage** section of your application, select **Certificates & secrets**.

   - **Add a New Client Secret**:

     - Under **Client secrets**, click on **New client secret**.
     - **Description**: Provide a description for the client secret (e.g., `SharePointClientSecret`).
     - **Expires**: Choose an appropriate expiration period that suits your needs.
     - Click **Add**.

   - **Record the Client Secret Value**:

     - *Copy and securely store the **Client Secret Value** for later use.*

       > **Note**: Do not copy the "Secret ID" as it is not required.

    ![Register Application](../media/sharepoint-secret-app.png)

> [!NOTE]
> Done! You have completed the necessary permissions for SharePoint. Now, to complete the configuration in your Function App:

5. **Gather SharePoint Site Information**

   - **Site Domain**: The domain of your SharePoint site (e.g., `yourdomain.sharepoint.com`).
   - **Site Name**: The name of your SharePoint site (e.g., `YourSiteName`).
   - **Site Folder**: Folder path to index (e.g., `/Shared Documents/General`). Leave empty for root.
   - **File Formats**: Specify the file formats to index (e.g., `pdf,docx,pptx`).

6. **Update Function App Environment Variables**

   - **Navigate to Function App Configuration**:

     - In the Azure Portal, go to your **Function App** > **Configuration** > **Application settings**.

   - **Set the Following Environment Variables**:

     ```plaintext
     # Enable or disable the SharePoint connector
     SHAREPOINT_CONNECTOR_ENABLED=true
     
     SHAREPOINT_TENANT_ID=your_actual_tenant_id
     SHAREPOINT_CLIENT_ID=your_actual_client_id
     SHAREPOINT_CLIENT_SECRET_NAME=sharepoint_keyvault_secret_name (Default to sharepointClientSecret)
     SHAREPOINT_SITE_DOMAIN=your_actual_site_domain
     SHAREPOINT_SITE_NAME=your_actual_site_name
     SHAREPOINT_SITE_FOLDER=/your/folder/path # Leave empty if using the root folder
     SHAREPOINT_FILES_FORMAT=pdf,docx,pptx
     ```

     - Replace placeholders with the actual values obtained from previous steps.

   - **Add SharePoint Client Secret to KeyVault**:
     - Add the SharePoint client secret value to the GPT-RAG Key Vault. You can use **sharepointClientSecret** as the secret name, or if you choose a custom name, make sure to add it to the `SHAREPOINT_CLIENT_SECRET_NAME` environment variable.

  >[!NOTE]
  > Leave `SHAREPOINT_FILES_FORMAT` empty to include the following default extensions: vtt, xlsx, xls, pdf, png, jpeg, jpg, bmp, tiff, docx, pptx.

  > [!TIP]
  > The target index name defaults to `ragindex`. If your deployment uses a different index, set
  > `AZURE_SEARCH_SHAREPOINT_INDEX_NAME` on the Function App as well.

   - **Save and Restart**:

     - Click **Save** to apply the changes.
     - Restart the Function App to ensure the new settings take effect.


> [!NOTE] 
> Done! You have completed the SharePoint configuration procedure.

## Known limits and operational notes (1.0.1)

Keep these in mind when sizing a SharePoint deployment against the pinned 1.0.1 ingestor. None
of them block normal use of small/medium document libraries, but they materially affect large or
active ones.

- **Single site / single folder per Function App.** The `SHAREPOINT_*` settings target one
  site + one folder. To index multiple sites or multiple top-level folders, either deploy
  additional Function Apps or wait for an upstream connector that supports a list of sources.
- **Microsoft Graph paging is not implemented.** `sharepoint_files_indexer` reads only the first
  page of `GET /drives/{id}/root/children` (Graph default ~200 items). Document libraries with
  more than one page of matching files will silently have items beyond page&nbsp;1 omitted from
  the index. Workarounds: partition into sub-folders below the configured root, or run separate
  Function Apps per sub-folder.
- **Moves and renames can produce duplicate index entries.** 1.0.1 keys index entries by the
  SharePoint item ID and the purger checks per-item existence rather than using Graph delta
  query. A file that is moved or renamed inside the indexed folder may appear under both old
  and new identities until the purger removes the stale entry.
- **No Graph 429 / `Retry-After` handling.** Large initial loads or rapid re-indexes can hit
  Microsoft Graph throttling. If you see ingestion stalls, look in the Function App logs for HTTP
  429 responses from `graph.microsoft.com` and consider lowering the cadence, narrowing
  `SHAREPOINT_FILES_FORMAT`, or partitioning by folder.
- **ACLs are partially captured, not fully trimmed end-to-end.** The connector reads each
  file's read-permission users and groups via Graph and writes them to the
  `metadata_security_id` field of every chunk (users from `grantedToIdentitiesV2` /
  `grantedToIdentities`, groups from `grantedToV2.siteGroup.displayName`). Two caveats:
  - Only the **file's own** permissions are read &mdash; permissions inherited from the
    parent folder or site are not walked.
  - Whether queries actually filter on `metadata_security_id` at runtime is a property of the
    **orchestrator**, not the ingestor. Verify in the orchestrator before relying on per-user
    security trimming for SharePoint content.
- **Function timeout requires Premium/Dedicated.** The ingestion Function App's `host.json`
  sets `functionTimeout: 01:00:00`, which exceeds the 10-minute Consumption-plan ceiling. The
  Function App must run on a Premium or App Service (Dedicated) plan.
- **Client secret rotation.** Auth uses the application client secret stored in the GPT-RAG
  Key Vault as `sharepointClientSecret` (or whatever `SHAREPOINT_CLIENT_SECRET_NAME` points to).
  Track the expiry you chose in step 4 above and rotate the Key Vault secret value before it
  expires &mdash; ingestion will start failing with `AADSTS7000222`-style errors otherwise.
  Federated identity credentials on the Function App's managed identity would remove this
  rotation entirely, but are not implemented in the 1.0.1 connector.

## Validation

1. **Test Data Ingestion**

   - **Trigger the Ingestion Process**:

     - Wait for the data ingestion scheduled run.

   - **Monitor Logs**:

     - Check the Function App logs to verify that the SharePoint connector is running without errors.

2. **Verify Indexed Data**

   - **Check Azure AI Index**:

     - Go to your Azure AI Index to confirm that the SharePoint data has been successfully indexed.

   - **Perform Search Queries**:

     - Execute search queries to ensure that content from the specific SharePoint sites is retrievable.

> [!NOTE]
> Using `Sites.Selected` ensures that your application only has access to the SharePoint sites you've explicitly granted permissions to, enhancing security by limiting access scope.

---

**Additional Information:**

- **Removing Permissions**:

  If you need to revoke the application's access to a site, you can delete the permission via Microsoft Graph API:

  ```http
  DELETE https://graph.microsoft.com/v1.0/sites/{site-id}/permissions/{permission-id}
  ```

  - You can obtain the `permission-id` by listing the permissions:

    ```http
    GET https://graph.microsoft.com/v1.0/sites/{site-id}/permissions
    ```

- **Understanding `Sites.Selected` Permission**:

  - The `Sites.Selected` permission by itself does not grant access to any SharePoint site collections.
  - It allows your application to access only the site collections that you explicitly grant it access to.
  - This approach adheres to the principle of least privilege, enhancing security.
