# 🚀 Quick Start Guide

## Prerequisites

**Required Accounts:**
- [n8n](https://n8n.io) - Workflow automation platform
- [Apify](https://apify.com) - Instagram scraping API
- [Pinecone](https://pinecone.io) - Vector database
- [Telegram](https://telegram.org) - Bot for user interface

**Technical Requirements:**
- n8n instance (cloud or self-hosted)
- Basic understanding of workflow automation
- API keys from all services above

---

## Setup Steps

### 1. Clone This Repository

```bash
git clone <your-repo-url>
cd instagram-content-pipeline
```

### 2. Configure n8n Credentials

In your n8n instance, create credentials for:

**Apify API:**
- Name: `Apify Production`
- Type: `Apify API`
- API Token: `<your-apify-token>`

**Pinecone:**
- Name: `Pinecone Production`
- Type: `Pinecone API`
- API Key: `<your-pinecone-key>`
- Environment: `<your-pinecone-env>` (e.g., `us-east-1-aws`)

**Telegram Bot:**
- Name: `Telegram Bot`
- Type: `Telegram`
- Access Token: `<your-bot-token>`

**How to get credentials:**
- Apify: Dashboard → Settings → API Tokens
- Pinecone: Console → API Keys
- Telegram: Chat with [@BotFather](https://t.me/BotFather) → `/newbot`

### 3. Create Pinecone Index

```bash
# Via Pinecone Console or API
curl -X POST "https://api.pinecone.io/indexes" \
  -H "Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "instagram-content",
    "dimension": 1536,
    "metric": "cosine"
  }'
```

**Important Settings:**
- **Name:** `instagram-content` (or update workflow to match)
- **Dimension:** `1536` (OpenAI text-embedding-ada-002)
- **Metric:** `cosine`

### 4. Import Workflow

1. Open n8n interface
2. Click "Import from File"
3. Select `workflow/instagram-pinecone.json`
4. Assign credentials to nodes:
   - "Start Apify Run" → Apify API
   - "Poll Apify Status" → Apify API
   - "Get Apify Results" → Apify API
   - "Pinecone Vector Store" → Pinecone API
   - "Success Message" → Telegram Bot
   - "Error: No Results" → Telegram Bot

### 5. Configure Telegram Bot

**Set webhook or use polling:**

**Option A: Webhook (Recommended)**
```bash
# Set webhook URL to your n8n webhook endpoint
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://your-n8n-instance.com/webhook/telegram-bot"}'
```

**Option B: Manual Trigger**
- Use n8n's manual trigger
- Send test message via Telegram
- Workflow executes on each message

### 6. Test the Workflow

**Test with various Instagram URLs:**

1. **Standard Post:**
   ```
   https://www.instagram.com/p/ABC123/
   ```
   Expected: Success message with likes/comments

2. **Video/Reel:**
   ```
   https://www.instagram.com/reel/DEF456/
   ```
   Expected: Uses videoTranscription if no caption

3. **Image-Only:**
   ```
   https://www.instagram.com/p/GHI789/
   ```
   Expected: Error message (no meaningful content)

### 7. Verify Pinecone Storage

```python
# Check vector was stored
import pinecone

pinecone.init(api_key="YOUR_KEY", environment="YOUR_ENV")
index = pinecone.Index("instagram-content")

# Query index
results = index.query(
    vector=[0.1] * 1536,  # Dummy vector
    top_k=10,
    include_metadata=True
)

print(results)
```

---

## Troubleshooting

### Workflow Fails Immediately

**Check:**
- [ ] All credentials are assigned to nodes
- [ ] Pinecone index exists and has correct dimensions
- [ ] Telegram bot token is valid

**Error:** "Apify returned empty dataset"
- Instagram URL is invalid or private
- Post was deleted
- Rate limit reached

**Error:** "No substantial content found"
- This is expected behavior for image-only posts
- Try URL with text caption or video transcription

### Connection Issues

**Verify IF node connections:**
1. Open workflow in editor
2. Click "Check Validation Error" node
3. Verify outputs:
   - Output 0 (green) → "Error: No Results"
   - Output 1 (red) → Not connected

### Performance Issues

**If workflow is slow:**
- Apify scraping: 10-30s (normal)
- Polling: Up to 100s max (retry loop)
- Total: 20-140s average

**Optimization:**
- Reduce polling wait time: 5s → 2s
- Enable Apify webhooks (eliminates polling)

---

## Usage Examples

### Basic Usage

**Via Telegram Bot:**
1. Start chat with your bot
2. Send Instagram URL: `https://instagram.com/p/ABC123/`
3. Wait for confirmation (~45s average)
4. Receive success or error notification

### Advanced: Batch Processing

**Modify workflow to accept multiple URLs:**
```javascript
// In trigger node, accept newline-separated URLs
const urls = $json.message.text.split('\n');
return urls.map(url => ({ json: { url } }));
```

**Send message:**
```
https://instagram.com/p/ABC123/
https://instagram.com/p/DEF456/
https://instagram.com/p/GHI789/
```

### Semantic Search

**Query stored vectors:**
```python
import pinecone
from openai import OpenAI

# Initialize
pinecone.init(api_key="...", environment="...")
openai_client = OpenAI(api_key="...")
index = pinecone.Index("instagram-content")

# Search query
query = "sunset beach photos"
query_embedding = openai_client.embeddings.create(
    input=query,
    model="text-embedding-ada-002"
).data[0].embedding

# Find similar content
results = index.query(
    vector=query_embedding,
    top_k=5,
    include_metadata=True,
    filter={"likesCount": {"$gte": 1000}}
)

# Print results
for match in results.matches:
    print(f"URL: {match.metadata['url']}")
    print(f"Score: {match.score}")
    print(f"Likes: {match.metadata['likesCount']}")
    print("---")
```

---

## Configuration Options

### Workflow Settings

**Modify validation threshold:**
```javascript
// In "Validate Content" node, change line:
field.value.trim().length > 50

// To:
field.value.trim().length > 100  // Stricter
// Or:
field.value.trim().length > 20   // More lenient
```

**Change content field priority:**
```javascript
// In "Validate Content" node, reorder:
const contentFields = [
  { name: 'videoTranscription', value: data.videoTranscription },  // Videos first
  { name: 'caption', value: data.caption },
  { name: 'text', value: data.text },
  { name: 'alt', value: data.alt }
];
```

**Adjust polling timeout:**
```javascript
// In "Check If Still Running" node:
// Max retries = 20 → Change to 40 for slower scraping
// Wait time = 5s → Change to 3s for faster polling
```

---

## Maintenance

### Daily Tasks

**Monitor workflow executions:**
1. Check n8n execution history
2. Review error notifications in Telegram
3. Look for patterns in failures

### Weekly Tasks

**Check API quotas:**
- Apify: Dashboard → Usage
- Pinecone: Console → Usage
- OpenAI: Platform → Usage

**Review stored vectors:**
```python
# Check index size
index.describe_index_stats()
```

### Monthly Tasks

**Rotate API keys:**
1. Generate new keys in each platform
2. Update n8n credentials
3. Test workflow with new keys
4. Deactivate old keys

**Clean up old vectors:**
```python
# Delete vectors older than 90 days
index.delete(
    filter={"scrapedAt": {"$lt": "2024-08-01T00:00:00Z"}}
)
```

---

## Cost Estimates

**Based on 100 posts/month:**

| Service | Cost | Notes |
|---------|------|-------|
| **Apify** | $10-20 | Instagram Scraper Actor |
| **Pinecone** | $0-10 | Free tier: 1GB storage |
| **OpenAI** | $0.50-1 | Embeddings: $0.0001/1K tokens |
| **n8n** | $0-20 | Free self-hosted / Cloud starter |
| **Telegram** | $0 | Free API |
| **Total** | **$10-50/month** | Varies by volume |

**Scale estimates:**
- 1,000 posts/month: $50-150
- 10,000 posts/month: $200-500

---

## Resources

**Documentation:**
- [n8n Docs](https://docs.n8n.io)
- [Apify API](https://docs.apify.com/api/v2)
- [Pinecone Docs](https://docs.pinecone.io)
- [Telegram Bot API](https://core.telegram.org/bots/api)

**Community:**
- [n8n Forum](https://community.n8n.io)
- [n8n Discord](https://discord.gg/n8n)

**Support:**
- Workflow issues: Open GitHub issue
- n8n questions: n8n community forum
- API issues: Contact service provider

---

## Next Steps

**After basic setup:**
1. ✅ Test with 10+ different Instagram post types
2. ✅ Verify all error scenarios work
3. ✅ Check Pinecone vectors are searchable
4. ✅ Monitor first week of production usage

**Enhancements to consider:**
- [ ] Implement batch URL processing
- [ ] Add duplicate detection
- [ ] Set up monitoring alerts
- [ ] Create analytics dashboard
- [ ] Add content filtering rules

---

**Need Help?**
- Check `docs/architecture.md` for technical details
- Review `docs/changelog.md` for known issues
- Open an issue on GitHub

**Ready to deploy?** Follow the [Deployment Checklist](docs/changelog.md#deployment-notes) in the changelog.
