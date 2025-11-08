# Instagram Content to Pinecone Vector Pipeline

Automated workflow that scrapes Instagram posts and stores validated content in Pinecone for AI-powered semantic search and retrieval.

---

## Objective

**Problem:** Need to extract meaningful text content from Instagram posts (captions, transcriptions, alt text) and store it in a vector database for later semantic search and AI applications.

**Solution:** Automated n8n workflow that:
- Accepts Instagram URLs via Telegram
- Scrapes content using Apify's Instagram scraper
- Validates that meaningful content exists (>50 characters)
- Stores validated content in Pinecone vector database
- Sends success/error notifications via Telegram

**Use Cases:**
- Content marketers analyzing competitor posts
- AI researchers building Instagram content datasets
- Social media monitoring and archival systems
- Personal knowledge base from saved Instagram content

---

## Summary

**Workflow Flow:**

1. **Trigger:** User sends Instagram URL via Telegram bot
2. **Scrape:** Apify Instagram scraper extracts post data
3. **Poll:** Wait for Apify job to complete (retry loop)
4. **Normalize:** Handle array/object response variations
5. **Validate:** Check for meaningful content (caption, transcription, text, alt)
6. **Route:** 
   -  Valid content → Parse and vectorize
   -  No content → Send error notification
7. **Store:** Save vectors to Pinecone with metadata
8. **Notify:** Send success message to Telegram

**Expected Result:** Instagram post content is available for semantic search in Pinecone, with full metadata (URL, likes, comments, timestamps).

---

## Architecture Overview

**Tech Stack:**
- **n8n** - Workflow orchestration
- **Apify** - Instagram scraping API
- **Pinecone** - Vector database for embeddings
- **Telegram** - User interface (input/notifications)
- **OpenAI Embeddings** - Text vectorization (via Pinecone integration)

**Data Flow:**
```
Telegram Message (Instagram URL)
    ↓
Apify Instagram Scraper API
    ↓
Response Normalization (Code Node)
    ↓
Content Validation (Code Node)
    ↓
IF Node: Check Validation Error
    ├─ SUCCESS → Parse Content → Pinecone Vector Store
    └─ ERROR → Telegram Error Notification
```

**Key Components:**
1. **Manual Trigger** - Telegram chat webhook
2. **Start Apify Run** - HTTP Request to Apify API
3. **Poll Apify Status** - HTTP Request with retry loop
4. **Get Apify Results** - HTTP Request to dataset endpoint
5. **Normalize Response** - Code node (handles array/object variations)
6. **Validate Content** - Code node (checks content quality)
7. **Check Validation Error** - IF node (route success/error)
8. **Parse Content** - Code node (extract and format content)
9. **Pinecone Vector Store** - Store embeddings
10. **Telegram Notifications** - Success/error messages

---

## Features

### Core Functionality
- **Multi-field content extraction** - Checks caption, text, videoTranscription, and alt fields
- **Content quality validation** - Requires >50 characters of meaningful text
- **Response normalization** - Handles both array and single-object responses from Apify
- **Automatic retries** - Polls Apify status until job completes
- **Error handling** - Detailed error messages for debugging

### Edge Case Handling
- **Empty captions with video transcription** - Falls back to videoTranscription field
- **Photo posts without descriptions** - Catches and reports via Telegram
- **Short captions** - Validates minimum content length (>50 chars)
- **Apify empty datasets** - Throws explicit error before processing
- **Single object vs array responses** - Normalizes to consistent array format
- **Rate limiting** - Handles Apify API errors gracefully

### Automation Logic
- **Conditional routing** - Success path to Pinecone, error path to Telegram
- **Content prioritization** - Checks fields in order: caption → text → videoTranscription → alt
- **Validation with context** - Error messages include which fields were found
- **Metadata preservation** - Stores Instagram URL, likes, comments with vectors

---

## Screenshots

![Workflow Overview](./assets/workflow-overview.png)
*Full workflow showing all nodes and connections*

![Validation Logic](./assets/validation-nodes.png)
*Three-step validation: Normalize → Validate → Route*

![Error Handling](./assets/error-routing.png)
*IF node correctly routes to Parse Content (output 0) and Error handler (output 1)*

---

## Tech Stack Details

**APIs & Services:**
- **Apify Instagram Scraper** (`apify/instagram-scraper`)
  - Endpoint: `https://api.apify.com/v2/acts/apify~instagram-scraper/runs`
  - Authentication: Bearer token
  - Rate limits: Depends on Apify plan

- **Pinecone Vector Database**
  - Dimension: 1536 (OpenAI embeddings)
  - Metric: Cosine similarity
  - Namespace: Configurable per workflow

**n8n Nodes Used:**
- HTTP Request (3 nodes)
- Code (4 nodes)
- IF (5 nodes)
- Wait (2 node)
- Pinecone Vector Store (1 node)
- Telegram (5 nodes)
- OpenAI embeddings (1 node)
- Data loader (1 node)
- Text Spliter (1 node)

**Programming:**
- JavaScript (ES6) for Code nodes
- n8n expressions for dynamic values

---

## Security Notes

**Credentials stored as n8n credentials (NOT in workflow JSON):**
- `APIFY_API_KEY` - Apify authentication token
- `TELEGRAM_BOT_TOKEN` - Telegram bot API token
- `PINECONE_API_KEY` - Pinecone authentication
- `PINECONE_ENVIRONMENT` - Pinecone region/environment

**Best Practices:**
- Never commit actual API keys to version control
- Use n8n's credential system for secure storage
- Webhook URLs should not contain sensitive tokens in query params
- Rotate API keys regularly

**In exported workflow JSON, credentials appear as:**
```json
"credentials": {
  "apifyApi": {
    "id": "placeholder_id",
    "name": "Apify API"
  }
}
```

---

## Known Issues & Solutions

### Issue #1: Type Mismatch - Array vs Object
**Problem:** Apify sometimes returns single object `{...}` instead of array `[{...}]`, causing "Cannot read property 'caption' of undefined" errors.

**Solution:** Added "Normalize Response" Code node to wrap single objects in arrays:
```javascript
let items = $input.all()[0].json;
if (!Array.isArray(items)) {
  items = [items];
}
return items.map(item => ({ json: item }));
```

### Issue #2: Incorrect IF Node Connections
**Problem:** "Check Validation Error" IF node had both outputs (true/false) connected to the same nodes, causing all paths to execute regardless of validation result.

**Solution:** Manually reconnected in n8n UI:
- Output 0 (true/success) → Parse Content
- Output 1 (false/error) → Error: No Results

### Issue #3: Empty Captions on Video Posts
**Problem:** Instagram Reels without captions were rejected even when videoTranscription field had content.

**Solution:** Enhanced "Validate Content" node to check multiple fields in priority order:
```javascript
const contentFields = [
  { name: 'caption', value: data.caption },
  { name: 'text', value: data.text },
  { name: 'videoTranscription', value: data.videoTranscription },
  { name: 'alt', value: data.alt }
];
```

---

## Next Steps & Improvements

**Short-term (Technical Debt):**
- [ ] Modernize `continueOnFail: true` to `onError: 'continueRegularOutput'` for n8n v1.x
- [ ] Add retry logic (`retryOnFail: true`, `maxRetries: 3`) to HTTP nodes
- [ ] Clean up validator false positives (Telegram legacy config warnings)

**Feature Enhancements:**
- [ ] Batch processing - Accept multiple Instagram URLs at once
- [ ] Duplicate detection - Check Pinecone before inserting
- [ ] Content filtering - Skip promotional/sponsored posts
- [ ] Enhanced metadata - Extract hashtags, mentions, location data
- [ ] Webhook endpoint - Allow external systems to trigger scraping

**Performance Optimizations:**
- [ ] Parallel processing - Handle multiple URLs concurrently
- [ ] Caching - Store Apify results temporarily to avoid re-scraping
- [ ] Smart polling - Exponential backoff for Apify status checks

**Analytics & Monitoring:**
- [ ] Success/failure rate tracking
- [ ] Average processing time metrics
- [ ] Daily/weekly scraping reports via Telegram
- [ ] Alert on consecutive failures

---

## Documentation Structure

```
instagram-content-pipeline/
├── README.md                    (this file)
├── workflow/
│   └── instagram-pinecone.json  (n8n workflow export)
├── assets/
│   ├── workflow-overview.png
│   ├── validation-nodes.png
│   └── error-routing.png
├── docs/
│   ├── architecture.md          (technical deep-dive)
│   └── changelog.md             (version history & bug fixes)
```

---

## Contributing

This is a personal learning project, but suggestions are welcome! If you spot bugs or have ideas for improvements, feel free to:
- Open an issue describing the problem
- Fork and submit a PR with fixes
- Share your own variations of this workflow

---

## License

MIT License - Feel free to use, modify, and share this workflow.

---

## Acknowledgments

- **n8n Community** - For the excellent workflow automation platform
- **Apify** - For reliable Instagram scraping API
- **Pinecone** - For managed vector database infrastructure

---

**Built with:** n8n, Apify, Pinecone, Telegram  
**Version:** 1.1.0  
**Last Updated:** November 2025  
**Status:**  Production Ready
