# Assets Folder - Screenshots & Diagrams

## Required Screenshots

### 1. Workflow Overview (`workflow-overview.png`)

**What to capture:**
- Full workflow view showing all nodes
- Connections between nodes visible
- All node names clearly readable

**How to take:**
1. Open workflow in n8n editor
2. Zoom to fit all nodes (Ctrl/Cmd + 0)
3. Take full screenshot
4. Save as `workflow-overview.png`

**Recommended tool:**
- macOS: Cmd + Shift + 4 (select area)
- Windows: Win + Shift + S
- Linux: Flameshot / Spectacle

**Tips:**
- Use light theme for better readability
- 1920x1080 or higher resolution
- PNG format (not JPG for clarity)

---

### 2. Validation Nodes (`validation-nodes.png`)

**What to capture:**
- "Normalize Response" node (open parameters panel)
- "Validate Content" node (open parameters panel)
- Code visible in both nodes

**How to take:**
1. Open "Normalize Response" node
2. Expand code editor to show full script
3. Take screenshot showing:
   - Node name
   - Code content
   - Parameter settings
4. Repeat for "Validate Content" node

**Alternative:**
- Create side-by-side comparison
- Use image editor to combine both screenshots

---

### 3. Error Routing (`error-routing.png`)

**What to capture:**
- "Check Validation Error" IF node
- Connections visible:
  - Input from "Validate Content"
  - Output 0 to "Error: No Results"
  - Success path to "Parse Content"

**How to take:**
1. Click "Check Validation Error" node
2. Zoom in to show connections clearly
3. Ensure output numbers (0, 1) are visible
4. Capture node + immediate neighbors

**Highlight:**
- Mark Output 0 (green) connection
- Mark Output 1 (if used)
- Use arrows or annotations if needed

---

## Optional Diagrams

### 4. Architecture Diagram (`architecture-diagram.png`)

**Create with:**
- [Excalidraw](https://excalidraw.com) (free, online)
- [Draw.io](https://app.diagrams.net) (free, online)
- [Figma](https://figma.com) (free tier available)

**Content:**
```
┌──────────┐
│ Telegram │
└─────┬────┘
      │
      ▼
┌──────────┐
│   n8n    │
│ Workflow │
└─────┬────┘
      │
      ├──→ Apify (Instagram Scraper)
      │
      ├──→ Normalize Data
      │
      ├──→ Validate Content
      │
      ├──→ Parse & Format
      │
      └──→ Pinecone (Vector Storage)
```

---

### 5. Error Flow Diagram (`error-flow-diagram.png`)

**Visual representation:**
```
┌─────────────────┐
│ Get Apify Data  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Normalize     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│    Validate     │
└────┬───────┬────┘
     │       │
     │ Valid │ Error
     ▼       ▼
  Parse   Notify
```

---

## Screenshot Specifications

**Format:** PNG (preferred) or JPG  
**Resolution:** Minimum 1280px width  
**File Size:** <2MB per image  
**Color Mode:** RGB  
**Background:** Light theme for clarity  

---

## Naming Convention

```
workflow-overview.png           # Full workflow view
validation-nodes.png            # Normalize + Validate nodes
error-routing.png               # IF node connections
architecture-diagram.png        # High-level flow (optional)
error-flow-diagram.png          # Error handling (optional)
execution-success.png           # Sample success (optional)
execution-error.png             # Sample error (optional)
```

---

## Image Editing Tips

### Annotations

**Add callouts for:**
- Important nodes: "This node normalizes array/object responses"
- Critical settings: "continueOnFail: true enables error handling"
- Connection flows: "Output 0 → Error path"

**Tools:**
- macOS: Preview (built-in)
- Windows: Paint / Paint 3D
- Cross-platform: [Ksnip](https://github.com/ksnip/ksnip) (free)

### Highlighting

**Use:**
- Red boxes for errors
- Green boxes for success paths
- Yellow boxes for validation steps
- Arrows to show flow direction

**Avoid:**
- Too many annotations (cluttered)
- Low-contrast colors
- Text too small to read

---

## Example Screenshot Workflow

```bash
# 1. Take screenshots
# (Use native OS tool or app)

# 2. Organize files
mv ~/Downloads/Screenshot*.png ./assets/
cd assets/

# 3. Rename appropriately
mv Screenshot_1.png workflow-overview.png
mv Screenshot_2.png validation-nodes.png
mv Screenshot_3.png error-routing.png

# 4. Optimize file size (optional)
# Using ImageMagick:
mogrify -resize '1920x>' -quality 85 *.png

# 5. Verify images load correctly
ls -lh *.png
```

---

## Placeholders (If Screenshots Not Available)

If you can't take screenshots yet, use text placeholders:

**In README.md:**
```markdown
![Workflow Overview](./assets/workflow-overview.png)
*[Screenshot pending - shows full workflow with all nodes]*
```

**Create text file:**
```bash
echo "Screenshot instructions: See assets/README.md" > workflow-overview.placeholder
```

---

## Quality Checklist

Before committing screenshots:

- [ ] All node names are readable
- [ ] Connections are clearly visible
- [ ] No sensitive data visible (API keys, tokens)
- [ ] File size is reasonable (<2MB)
- [ ] Format is PNG for clarity
- [ ] Named according to convention
- [ ] Referenced correctly in README.md

---

## Privacy & Security

**CRITICAL: Review before uploading!**

❌ **Never include in screenshots:**
- API keys or tokens in node settings
- Telegram chat IDs
- Personal identifiable information
- Production environment URLs with secrets
- Database connection strings

✅ **Safe to include:**
- Node types and configurations
- Generic code examples
- Connection structure
- Execution counts (without data)
- Error messages (without sensitive details)

**Before uploading:**
1. Check each screenshot for sensitive data
2. Blur/redact any credentials visible
3. Use generic/example data in visible fields

---

## Screenshot Alternatives

If you can't take screenshots, alternatives:

**Text Descriptions:**
```markdown
### Workflow Structure

The workflow consists of 12 nodes arranged in this sequence:
1. Telegram Bot (trigger)
2. Start Apify Run (HTTP)
3. ...
```

**ASCII Diagrams:**
```
Telegram → HTTP → Code → IF → Pinecone
                     ↓
                   Error
```

**Video Walkthrough:**
- Record 2-minute screen capture
- Upload to YouTube (unlisted)
- Link from README.md

---

## AI-Generated Diagrams (Advanced)

**Use Claude or ChatGPT to generate:**
1. Copy workflow JSON
2. Ask AI: "Create Mermaid diagram from this workflow"
3. Render with [Mermaid Live](https://mermaid.live)
4. Export as PNG

**Example prompt:**
```
Create a Mermaid flowchart diagram showing this n8n workflow:
- Telegram trigger
- Apify scraping (with retry loop)
- Normalize → Validate → Route
- Pinecone storage
- Success/error notifications
```

---

**Ready to add screenshots?**

1. Take screenshots following guidelines above
2. Place in this `assets/` folder
3. Reference in `README.md`:
   ```markdown
   ![Description](./assets/filename.png)
   ```
4. Verify images display correctly on GitHub
5. Commit and push

```bash
git add assets/*.png
git commit -m "Add workflow screenshots"
git push
```
