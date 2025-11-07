# 🏗️ Architecture Documentation

## System Architecture

### High-Level Overview

```
┌─────────────────┐
│  Telegram Bot   │ ← User sends Instagram URL
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   n8n Workflow  │
│  ┌───────────┐  │
│  │  Apify    │  │ ← Scrape Instagram
│  │  Scraper  │  │
│  └─────┬─────┘  │
│        │        │
│        ▼        │
│  ┌───────────┐  │
│  │ Normalize │  │ ← Handle response format
│  │ Response  │  │
│  └─────┬─────┘  │
│        │        │
│        ▼        │
│  ┌───────────┐  │
│  │ Validate  │  │ ← Check content quality
│  │ Content   │  │
│  └─────┬─────┘  │
│        │        │
│     ┌──┴──┐     │
│     ▼     ▼     │
│  Valid  Error   │
│     │     │     │
│     ▼     ▼     │
│  Parse  Notify  │
└────┬─────────────┘
     │
     ▼
┌─────────────────┐
│    Pinecone     │ ← Store vectors
│ Vector Database │
└─────────────────┘
```

---

## Node-by-Node Technical Breakdown

### 1. Manual Trigger (Telegram)
**Type:** Webhook / Manual Trigger  
**Purpose:** Entry point for workflow execution

**Configuration:**
- Listens for Telegram bot messages
- Extracts Instagram URL from message text
- Passes user chat ID for response routing

**Input Example:**
```json
{
  "message": {
    "chat": {
      "id": 123456789
    },
    "text": "https://www.instagram.com/p/ABC123/"
  }
}
```

---

### 2. Start Apify Run
**Type:** HTTP Request  
**Method:** POST  
**Endpoint:** `https://api.apify.com/v2/acts/apify~instagram-scraper/runs`

**Purpose:** Initiate Instagram scraping job

**Request Headers:**
```json
{
  "Authorization": "Bearer {{ $credentials.apifyApi }}",
  "Content-Type": "application/json"
}
```

**Request Body:**
```json
{
  "directUrls": [
    "{{ $json.message.text }}"
  ],
  "resultsType": "details",
  "resultsLimit": 1
}
```

**Response:**
```json
{
  "data": {
    "id": "run_abc123xyz",
    "status": "RUNNING",
    "defaultDatasetId": "dataset_xyz789"
  }
}
```

**Output Variables:**
- `runId` - For status polling
- `datasetId` - For result retrieval

---

### 3. Poll Apify Status
**Type:** HTTP Request (in retry loop)  
**Method:** GET  
**Endpoint:** `https://api.apify.com/v2/actor-runs/{{ $node["Start Apify Run"].json.data.id }}`

**Purpose:** Check if scraping job completed

**Polling Strategy:**
- Initial call: Immediate after job start
- Retry interval: 5 seconds (via Wait node)
- Max retries: 20 (100 seconds total timeout)
- Exit conditions: Status = "SUCCEEDED" or "FAILED"

**Response Handling:**
```javascript
// Check if still running
const status = $json.data.status;
if (status === "RUNNING" || status === "READY") {
  // Continue retry loop
  return { retry: true };
} else if (status === "SUCCEEDED") {
  // Exit loop, proceed to Get Results
  return { retry: false, datasetId: $json.data.defaultDatasetId };
} else {
  // Failed - throw error
  throw new Error(`Apify job failed: ${status}`);
}
```

**Loop Structure:**
```
Poll Status → Check If Still Running (IF)
     ↑              │               │
     │              ├─ Running → Wait 5s
     │              │               │
     └──────────────┘               │
                                    └─ Done → Get Results
```

---

### 4. Get Apify Results
**Type:** HTTP Request  
**Method:** GET  
**Endpoint:** `https://api.apify.com/v2/datasets/{{ $node["Poll Apify Status"].json.datasetId }}/items`

**Purpose:** Retrieve scraped Instagram data

**Response Variations:**

**Case A: Single Item (Object)**
```json
{
  "url": "https://instagram.com/p/ABC123/",
  "caption": "Check out this amazing sunset! 🌅",
  "text": null,
  "videoTranscription": null,
  "alt": "Photo by @user at sunset beach",
  "likesCount": 1523,
  "commentsCount": 89,
  "timestamp": "2025-11-07T10:30:00Z"
}
```

**Case B: Multiple Items (Array)**
```json
[
  {
    "url": "https://instagram.com/p/ABC123/",
    "caption": "First post..."
  },
  {
    "url": "https://instagram.com/p/DEF456/",
    "caption": "Second post..."
  }
]
```

**Case C: Empty Dataset**
```json
[]
```

**Problem:** Inconsistent response format requires normalization.

---

### 5. Normalize Response
**Type:** Code Node  
**Language:** JavaScript  
**Purpose:** Standardize Apify response to always be an array

**Full Code:**
```javascript
// Normalize Apify response to always be an array
let items = $input.all()[0].json;

// If single object, wrap in array
if (!Array.isArray(items)) {
  items = [items];
}

// If empty array or no items, throw error
if (items.length === 0) {
  throw new Error('Apify returned empty dataset - post may be deleted or private');
}

// Return as array of items
return items.map(item => ({ json: item }));
```

**Configuration:**
- `continueOnFail: true` - Allows error to be caught by downstream nodes
- Input: Single execution from "Get Apify Results"
- Output: Array of standardized items

**Error Handling:**
- Empty datasets throw explicit error
- Error is caught by error path (red output)
- Telegram notification triggered with error details

---

### 6. Validate Content
**Type:** Code Node  
**Language:** JavaScript  
**Purpose:** Verify meaningful content exists (>50 chars)

**Full Code:**
```javascript
// Validate Instagram content has meaningful data
const data = $input.first().json;

// Check for any content fields (order of priority)
const contentFields = [
  { name: 'caption', value: data.caption },
  { name: 'text', value: data.text },
  { name: 'videoTranscription', value: data.videoTranscription },
  { name: 'alt', value: data.alt }
];

// Find first non-empty content field with >50 characters
const validContent = contentFields.find(field => 
  field.value && field.value.trim().length > 50
);

if (!validContent) {
  // Log what we got for debugging
  const foundFields = contentFields
    .filter(f => f.value)
    .map(f => `${f.name}: ${f.value.substring(0, 30)}...`);
  
  throw new Error(
    `No substantial content found. ` +
    `Found fields: ${foundFields.join(', ') || 'none'}. ` +
    `Minimum 50 characters required.`
  );
}

// Pass through if valid
return [$input.first()];
```

**Validation Rules:**
1. Check fields in priority order: caption → text → videoTranscription → alt
2. Field must be non-null and non-empty
3. Content must be >50 characters after trimming whitespace
4. First valid field found = pass validation

**Error Output Format:**
```json
{
  "error": {
    "message": "No substantial content found. Found fields: caption: Short text..., alt: Image desc.... Minimum 50 characters required."
  }
}
```

**Configuration:**
- `continueOnFail: true` - Routes to error path when validation fails
- Input: Single item from "Normalize Response"
- Outputs:
  - **Success path (green):** Valid content → "Parse Content"
  - **Error path (red):** Invalid content → "Check Validation Error"

---

### 7. Check Validation Error
**Type:** IF Node  
**Purpose:** Route workflow based on validation result

**Condition:**
```javascript
{{ $json.error !== undefined }}
```

**Logic:**
- If `$json.error` exists → validation failed → route to "Error: No Results"
- If `$json.error` is undefined → validation passed → route to "Parse Content"

**Connection Structure:**
```
Validate Content (Code Node)
    │
    ├─ Success Output (green) → Parse Content
    │
    └─ Error Output (red) → Check Validation Error (IF)
                                 │
                                 ├─ Output 0 (true) → Error: No Results
                                 └─ Output 1 (false) → [unused]
```

**Critical Fix Applied:**
- **Before (Broken):** Both IF outputs connected to same nodes
- **After (Fixed):** Output 0 → Error handler, Output 1 → Success path

---

### 8. Parse Content
**Type:** Code Node  
**Language:** JavaScript  
**Purpose:** Extract and format content for Pinecone storage

**Full Code:**
```javascript
const data = $input.first().json;

// Extract content from available fields
const contentParts = [
  data.caption,
  data.text,
  data.videoTranscription,
  data.alt
].filter(Boolean); // Remove null/undefined

const extractedContent = contentParts.join('\n\n');

if (extractedContent.length === 0) {
  throw new Error('No text content could be extracted from the Instagram post');
}

// Format for Pinecone
return [{
  json: {
    text: extractedContent,
    metadata: {
      url: data.url,
      type: data.type || 'unknown',
      likesCount: data.likesCount || 0,
      commentsCount: data.commentsCount || 0,
      timestamp: data.timestamp,
      source: 'instagram',
      scrapedAt: new Date().toISOString()
    }
  }
}];
```

**Output Format:**
```json
{
  "text": "Check out this amazing sunset! 🌅\n\nPhoto by @user at sunset beach",
  "metadata": {
    "url": "https://instagram.com/p/ABC123/",
    "type": "GraphImage",
    "likesCount": 1523,
    "commentsCount": 89,
    "timestamp": "2025-11-07T10:30:00Z",
    "source": "instagram",
    "scrapedAt": "2025-11-07T15:45:00Z"
  }
}
```

---

### 9. Pinecone Vector Store
**Type:** Pinecone Vector Store Node  
**Purpose:** Generate embeddings and store in vector database

**Configuration:**
- **Index:** `instagram-content`
- **Namespace:** `production` (or env-specific)
- **Embedding Model:** OpenAI text-embedding-ada-002 (1536 dimensions)
- **Metadata:** Stored with vector for filtering

**Vector Generation:**
1. Text field → OpenAI Embeddings API → 1536-dim vector
2. Vector + metadata → Pinecone index
3. Pinecone generates unique ID automatically

**Query Example (Future Use):**
```python
# Semantic search in Pinecone
results = index.query(
  vector=query_embedding,
  top_k=10,
  include_metadata=True,
  filter={
    "source": {"$eq": "instagram"},
    "likesCount": {"$gte": 1000}
  }
)
```

---

### 10. Success Notification
**Type:** Telegram Node  
**Method:** Send Message  
**Purpose:** Confirm successful storage

**Message Template:**
```
✅ Content stored successfully!

URL: {{ $node["Get Apify Results"].json.url }}
Likes: {{ $node["Parse Content"].json.metadata.likesCount }}
Comments: {{ $node["Parse Content"].json.metadata.commentsCount }}

Vector ID: {{ $node["Pinecone Vector Store"].json.id }}
```

---

### 11. Error Notification
**Type:** Telegram Node  
**Method:** Send Message  
**Purpose:** Inform user of failures

**Message Template:**
```
❌ No content extracted from Instagram.

Error: {{ $json.error.message }}

This might happen if:
- The post has no text/caption (photos without descriptions)
- Content is too short (<50 characters)
- The URL is invalid or post is private
- The post was deleted

Please try a different post.
```

---

## Error Handling Architecture

### Three-Level Error Strategy

**Level 1: API Failures**
- Apify run fails → Caught by "Poll Apify Status"
- HTTP errors → Caught by `continueOnFail` on HTTP nodes
- Telegram notification with API error details

**Level 2: Data Quality Issues**
- Empty datasets → "Normalize Response" throws error
- No valid content → "Validate Content" throws error
- Routes to "Check Validation Error" IF node

**Level 3: Processing Errors**
- Pinecone storage fails → Telegram error notification
- Parsing errors → Caught by Code node error handling

### Error Flow Diagram

```
┌─────────────┐
│ Apify Error │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ Empty Dataset?  │───Yes───┐
└──────┬──────────┘         │
       │No                  │
       ▼                    │
┌─────────────────┐         │
│ Invalid Content?│───Yes───┤
└──────┬──────────┘         │
       │No                  │
       ▼                    ▼
┌─────────────────┐   ┌──────────┐
│ Store in        │   │ Telegram │
│ Pinecone        │   │  Error   │
└─────────────────┘   └──────────┘
```

---

## Performance Considerations

### Latency Breakdown

| Stage | Typical Duration | Notes |
|-------|-----------------|-------|
| Apify Run Start | 1-2s | API call |
| Instagram Scraping | 10-30s | Depends on post type |
| Polling Loop | 5-100s | 5s intervals, max 20 retries |
| Result Retrieval | 1-2s | API call |
| Validation | <100ms | Local processing |
| Embedding Generation | 1-3s | OpenAI API |
| Pinecone Storage | 500ms-1s | Vector upsert |
| **Total** | **20-140s** | Average: 45s |

### Bottlenecks

1. **Apify Scraping:** Slowest step, 10-30s
   - **Mitigation:** Cannot optimize (external API)
   - **Workaround:** Batch processing for multiple URLs

2. **Polling Interval:** Adds unnecessary 5s delays
   - **Current:** Fixed 5s wait
   - **Improvement:** Exponential backoff (1s → 2s → 5s → 10s)

3. **Sequential Processing:** No parallelization
   - **Current:** One URL at a time
   - **Improvement:** Split into multiple workflow instances

### Optimization Opportunities

**Short-term:**
- Reduce initial polling wait to 2s (most jobs complete in 10-15s)
- Add Apify webhook for instant completion notification

**Long-term:**
- Implement queue system for batch URL processing
- Cache Apify results to avoid re-scraping same URLs
- Pre-generate embeddings for common content patterns

---

## Data Model

### Instagram Post Schema (Apify Response)

```typescript
interface InstagramPost {
  url: string;                    // Post URL
  type: 'GraphImage' | 'GraphVideo' | 'GraphSidecar';
  caption?: string;               // Main text content
  text?: string;                  // Alternative text field
  videoTranscription?: string;    // Auto-generated transcript (Reels)
  alt?: string;                   // Image alt text
  likesCount: number;
  commentsCount: number;
  timestamp: string;              // ISO 8601 format
  ownerUsername: string;
  hashtags?: string[];
  mentions?: string[];
}
```

### Pinecone Vector Schema

```typescript
interface PineconeVector {
  id: string;                     // Auto-generated UUID
  values: number[];               // 1536-dim embedding vector
  metadata: {
    url: string;                  // Original Instagram URL
    type: string;                 // Post type
    likesCount: number;
    commentsCount: number;
    timestamp: string;            // Post creation time
    source: 'instagram';          // Always 'instagram'
    scrapedAt: string;           // Workflow execution time
    text?: string;               // Original text (optional)
  };
}
```

---

## Security Architecture

### Credential Management

**n8n Credentials System:**
- All API keys stored in n8n's encrypted credential store
- Credentials never appear in workflow JSON exports
- Workflow references credentials by ID and name only

**Example Credential Reference:**
```json
{
  "credentials": {
    "apifyApi": {
      "id": "1a2b3c4d",
      "name": "Apify Production"
    }
  }
}
```

### API Key Rotation Strategy

1. **Apify:** Monthly rotation recommended
2. **Pinecone:** Quarterly rotation
3. **Telegram Bot:** Rotate on suspected compromise

### Data Privacy

**PII Handling:**
- Instagram usernames stored in metadata (public data)
- No personal user data collected from Telegram
- Chat IDs used only for response routing (not stored)

**Content Storage:**
- Only public Instagram posts processed
- No authentication or private content access
- Respects Instagram's rate limits and ToS

---

## Monitoring & Observability

### Key Metrics to Track

**Success Metrics:**
- Total posts processed
- Average processing time
- Pinecone storage success rate
- Validation pass rate

**Error Metrics:**
- Apify job failure rate
- Empty dataset occurrences
- Validation rejection rate
- Pinecone storage errors

### Recommended Logging

**Add to workflow:**
```javascript
// In each Code node
console.log(`[${new Date().toISOString()}] ${nodeName}: Processing...`);
console.log(`Input: ${JSON.stringify($input.first().json)}`);
```

**n8n Execution Logs:**
- Enable workflow execution history
- Set retention to 30 days minimum
- Export logs for analysis

---

## Deployment Checklist

**Pre-deployment:**
- [ ] All credentials configured in n8n
- [ ] Pinecone index created (1536 dimensions, cosine similarity)
- [ ] Telegram bot token configured
- [ ] Apify account has sufficient credits
- [ ] Test workflow with sample URLs

**Post-deployment:**
- [ ] Activate workflow in n8n
- [ ] Test with various Instagram post types
- [ ] Monitor first 10 executions for errors
- [ ] Set up alerts for consecutive failures
- [ ] Document any edge cases encountered

---

## Troubleshooting Guide

### Common Issues

**1. "Apify returned empty dataset"**
- **Cause:** Post is private, deleted, or URL is invalid
- **Fix:** Verify URL is correct and post is public

**2. "No substantial content found"**
- **Cause:** Post has no text (image-only, short caption)
- **Fix:** Expected behavior - notify user via Telegram

**3. "Cannot read property 'caption' of undefined"**
- **Cause:** Response format mismatch (should be fixed by Normalize node)
- **Fix:** Check "Normalize Response" node is connected properly

**4. Pinecone storage fails**
- **Cause:** Index doesn't exist or wrong dimensions
- **Fix:** Ensure index is 1536-dim, using cosine metric

**5. IF node executes both paths**
- **Cause:** Incorrect connection structure
- **Fix:** Verify Output 0 → Error handler, Output 1 → Success path

---

## Version History

**v1.1.0 (Current)** - November 2025
- Added "Normalize Response" node
- Enhanced "Validate Content" with multi-field checking
- Fixed IF node connection structure
- Improved error messages

**v1.0.0** - Initial Version
- Basic Instagram → Pinecone pipeline
- Single-field validation (caption only)
- Known issues with response format handling
