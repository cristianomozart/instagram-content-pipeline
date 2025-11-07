# Workflow Export Instructions

## How to Export Your n8n Workflow

1. **Open your workflow** in n8n editor
2. **Click the menu** (three dots in top right)
3. **Select "Export"**
4. **Choose format:** JSON
5. **Save as:** `instagram-pinecone.json`
6. **Place in this folder:** `workflow/`

---

## ⚠️ Security Before Committing

**CRITICAL: Remove sensitive data before uploading to GitHub!**

### What to Remove

❌ **Never commit:**
- API Keys in URLs
- Bearer tokens in headers
- Telegram bot tokens
- Webhook URLs with secrets
- Database credentials

✅ **Safe to commit:**
- Node structure and connections
- Code logic (without keys)
- Credential references (by ID/name only)
- Workflow settings

### How to Clean the Export

**Option 1: Manual Review (Recommended)**

Open `instagram-pinecone.json` and search for:
- `apiKey`
- `token`
- `bearer`
- `secret`
- `password`

Replace values with placeholders:
```json
{
  "parameters": {
    "authentication": "headerAuth",
    "headerAuth": {
      "name": "Authorization",
      "value": "Bearer {{ $credentials.apifyApi }}"  // ✅ Good - references credential
    }
  }
}
```

**Option 2: Automated Cleanup Script**

```bash
# Run this before committing
cat instagram-pinecone.json | \
  sed 's/"apiKey":"[^"]*"/"apiKey":"REDACTED"/g' | \
  sed 's/"token":"[^"]*"/"token":"REDACTED"/g' | \
  sed 's/"bearer":"[^"]*"/"bearer":"REDACTED"/g' > \
  instagram-pinecone-clean.json

# Verify cleanup worked
grep -E '(apiKey|token|bearer)' instagram-pinecone-clean.json

# If clean, replace original
mv instagram-pinecone-clean.json instagram-pinecone.json
```

---

## Expected Workflow Structure

Your workflow should export with this structure:

```json
{
  "name": "Instagram Content to Pinecone",
  "nodes": [
    {
      "id": "...",
      "name": "Telegram Bot",
      "type": "n8n-nodes-base.telegram",
      "typeVersion": 1,
      "position": [0, 0],
      "parameters": {},
      "credentials": {
        "telegramApi": {
          "id": "1a2b3c4d",
          "name": "Telegram Bot"
        }
      }
    },
    // ... more nodes
  ],
  "connections": {
    "Telegram Bot": {
      "main": [
        [
          {
            "node": "Start Apify Run",
            "type": "main",
            "index": 0
          }
        ]
      ]
    },
    // ... more connections
  },
  "settings": {
    "executionOrder": "v1"
  }
}
```

---

## Node Checklist

Verify your export includes these nodes:

**Input:**
- [ ] Telegram Bot (or Manual Trigger)

**Apify Integration:**
- [ ] Start Apify Run (HTTP Request)
- [ ] Poll Apify Status (HTTP Request)
- [ ] Check If Still Running (IF node)
- [ ] Wait Before Retry (Wait node)
- [ ] Get Apify Results (HTTP Request)

**Validation:**
- [ ] Normalize Response (Code node)
- [ ] Validate Content (Code node)
- [ ] Check Validation Error (IF node)

**Processing:**
- [ ] Parse Content (Code node)

**Storage:**
- [ ] Pinecone Vector Store

**Notifications:**
- [ ] Success Message (Telegram)
- [ ] Error: No Results (Telegram)

**Total nodes:** 12

---

## Version Information

**Export from:** n8n v1.x or higher  
**Compatible with:** n8n v1.0+  
**Credentials required:** 3 (Apify, Pinecone, Telegram)  
**File size:** ~15-25 KB (typical)

---

## Import Instructions (For Others)

When someone imports this workflow:

1. **Prerequisites:**
   - n8n instance running
   - Credentials configured (see QUICKSTART.md)
   - Pinecone index created

2. **Import Steps:**
   - Click "Import from File" in n8n
   - Select `instagram-pinecone.json`
   - Assign credentials to nodes
   - Activate workflow

3. **Post-Import:**
   - Verify connections (especially "Check Validation Error")
   - Test with sample Instagram URL
   - Monitor first execution

---

## Troubleshooting Export Issues

**Export file is too large (>100KB):**
- Remove execution history: Workflow → Settings → "Clear execution data"
- Export again

**Credentials not working after import:**
- Recreate credentials in target n8n instance
- Reassign to nodes manually

**Connections broken after import:**
- Check "Check Validation Error" IF node
- Verify Output 0 → "Error: No Results"
- Verify success path from "Validate Content" → "Parse Content"

---

## Alternative: Direct Workflow Copy

If you can't export/import, you can rebuild from documentation:

1. **Reference:** `docs/architecture.md` (complete node breakdown)
2. **Follow:** Each node's configuration in the architecture doc
3. **Verify:** Use validation tools to check connections

**Time estimate:** 30-45 minutes to rebuild from docs

---

**Once you've exported and cleaned the workflow, commit it:**

```bash
# Verify it's in the right place
ls -lh workflow/instagram-pinecone.json

# Commit with descriptive message
git add workflow/instagram-pinecone.json
git commit -m "Add Instagram to Pinecone workflow (v1.1.0)"
git push
```
