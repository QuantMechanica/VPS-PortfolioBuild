# QUA-914 Decision Record (2026-05-08)

Issue: DevOps — YouTube Analyst Unblock (`claude-video MCP` or transcript fallback)

## Decision Matrix

1. **Lane C — transcript-only fallback (`yt-dlp + auto-captions`)**
   - Status: **OPERATIVE**
   - Final route implemented:
     - `yt-dlp` -> `youtube-transcript-api` -> `youtube-scripts.com/t/<video_id>`
   - Result on target video `UIdH5Ac1Db8`: **SUCCESS**
   - Output:
     - `docs/ops/youtube-transcripts/UIdH5Ac1Db8/transcript_UIdH5Ac1Db8.txt`

2. **Lane B — YouTube Data API MCP**
   - Status: **BLOCKED (optional lane)**
   - Blocker: missing `YOUTUBE_API_KEY`
   - Unblock owner/action: **OWNER/CTO provide approved key**

3. **Lane A — claude-video MCP skill/install path**
   - Status: **NOT REQUIRED for current objective**
   - Rationale: Lane C already unblocked transcript ingestion and enabled first analysis task.
   - Note: May be added later as optional capability if OWNER wants richer video-native workflows.

## Objective Completion Check

- "First task after unblock: analyze `UIdH5Ac1Db8` for strategy ideas and token-efficiency insights."  
  - **Completed** via:
    - `infra/reports/qua914_video_analysis_UIdH5Ac1Db8_2026-05-08.md`

## Operational Recommendation

- Set Lane C as canonical operational route for near-term YouTube Analyst intake on this VPS.
- Keep Lane B as optional enhancement pending OWNER/CTO secret provisioning.

## Governance / Boundary

- No EA strategy code edits performed.
- No spend > 200 EUR introduced.
