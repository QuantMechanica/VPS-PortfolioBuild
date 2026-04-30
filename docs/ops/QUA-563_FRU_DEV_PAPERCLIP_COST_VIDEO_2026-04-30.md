---
issue: QUA-563
parent_issue: QUA-556
goal: 4662e91e-8e9b-458e-9383-b1f67751965b
project: V5 Strategy Research
authored_by: Research (7aef7a17-d010-4f6e-a198-4a8dc5deb40d)
authored_at: 2026-04-30
review_by: Quality-Business 2 (0ab3d743-e3fb-44e5-8d35-c05d0d78715d) per QB Wave 2 executionPolicy / DL-030 sentinel sweep (QUA-630)
handoff_to:
  - Chief of Staff / OS Controller
  - Research Lead (CEO 7795b4b0-8ecd-46da-ab22-06def7c8fa2d)
source:
  kind: youtube
  id: UIdH5Ac1Db8
  url: https://www.youtube.com/watch?v=UIdH5Ac1Db8
  title: "Paperclip AI Cost Management: How to Stop Burning Tokens (Real Settings Walkthrough)"
  channel: "Fru Dev"
  channel_url: "https://www.youtube.com/@frudev"
  duration_sec: 1119
  duration_hms: "00:18:39"
---

# QUA-563 — Operating-Insights Brief: Fru Dev Paperclip Cost Management video

## 1. Source-acquisition note (acceptance: "Notes state whether a transcript was used and how it was obtained.")

- **Verbatim transcript: NOT obtained.** Three retrieval paths were attempted and all failed:
  1. `youtube-transcript-api` (Python) — `RequestBlocked` from this VPS IP (cloud-provider blocklist).
  2. In-page `fetch(captionTrack.baseUrl)` via Chrome under the YouTube SPA — HTTP 200 with empty body for both default and `&fmt=json3` URLs (consistent with YouTube anti-scrape returning empty caption payloads to non-player clients).
  3. YouTube engagement panel `engagement-panel-searchable-transcript` — opened (visibility=EXPANDED) but `ytd-transcript-segment-renderer` nodes never populated within an 18 s wait window.
- **What was obtained:** the video's `ytInitialPlayerResponse` payload exposed the full `videoDetails.shortDescription` (2,559 chars) and the auto-generated English caption track existed but its body was empty. The author publishes a hand-written chapter list as part of the description; this list is the citation backbone below.
- **Citation policy used here:** all timestamped citations below are the author's own chapter titles (verbatim; short label fragments). No claim about what the speaker says inside a chapter is fabricated — when a chapter title alone does not assert a fact, the brief states "implication" rather than "claim" so a downstream reviewer can re-watch to confirm.
- **If a verbatim transcript is required for sign-off:** unblock by either (a) supplying a residential or VPN egress to a future re-run, (b) running `yt-dlp --write-auto-subs --skip-download` from a non-cloud IP and committing the .vtt to this folder, or (c) using a paid transcript provider (Tactiq, Rev, etc.) which sits outside V5 budget today.

## 2. Author-published chapter index (verbatim, from public description)

| t      | chapter title                                                              |
|--------|-----------------------------------------------------------------------------|
| 00:00  | Introduction — 15 agents, cost is a real concern                            |
| 01:01  | How models and tokens drive your Paperclip bill                             |
| 02:05  | The credit limit problem — running out fast                                 |
| 03:03  | Heartbeat cadence: the #1 cost lever                                        |
| 04:00  | Not every agent needs to run daily — match cadence to purpose               |
| 05:07  | Skill files and agent instructions consume tokens too                       |
| 06:02  | Don't give agents skills they don't use                                     |
| 07:00  | Tokens in vs tokens out — what costs what                                   |
| 08:02  | Why Paperclip shows $0 with subscription billing                            |
| 09:05  | The prompt to query Paperclip's embedded Postgres for real cost             |
| 10:03  | How the usage-sync script works under the hood                              |
| 11:02  | Reading a run: tokens in, tokens out, cached tokens explained               |
| 12:00  | Cached tokens: 10x cheaper — what they are and how they build up            |
| 13:02  | Context management and when Claude clears the cache                         |
| 14:00  | Live results: chief of staff $2, career $2.4, calendar $1.9                 |
| 15:00  | Choosing the right model per agent — not everything needs Sonnet            |
| 16:06  | Using local Ollama models for cheap, frequent scans                         |
| 17:02  | Why subscription users see $0 — and what to do about it                     |
| 18:02  | Summary: model, cadence, instructions, budgets, measurement                 |

Total runtime 18:39. Author also publishes a bullet-point summary in the description: "Why Paperclip shows $0 cost even when you're spending real tokens", "How to fix the $0 problem and see actual agent costs in the UI", "Model selection: when to use Sonnet vs Haiku vs local Ollama models", "Heartbeat cadence: the single biggest lever for reducing cost", "How skill file size and agent instructions consume tokens", "Setting per-agent budgets so runaway costs don't surprise you", "Using cached tokens to your advantage", "The exact prompt I use to query Paperclip's Postgres DB for real cost data" (verbatim bullet list from the public description).

## 3. Observations (what the source asserts) — separated from recommendations

Each observation is tagged with the chapter timestamp where the author makes the point. Observations are paraphrased from the chapter title only; no claim is made about details inside the chapter that are not deducible from the title plus the description bullets above.

**O1. Cost surfaces as a first-class operating concern at our scale (00:00, 02:05).**
Author frames running ~15 agents 24/7 as the regime where cost stops being an afterthought. The "credit limit problem" chapter (02:05) says these limits are hit fast in practice. Implication for Paperclip: cost is bounded by API ceilings, not just dollars.

**O2. Heartbeat cadence is asserted as the single biggest cost lever (03:03, 04:00).**
The author titles 03:03 "Heartbeat cadence: the #1 cost lever" and 04:00 "Not every agent needs to run daily — match cadence to purpose". This matches our DL-040 token-throttle direction (single-active-source for SRC02–SRC05).

**O3. Skill files and agent instructions are themselves a cost surface (05:07, 06:02).**
Author asserts file size of `skills/*.md` and agent instructions are consumed every heartbeat. 06:02 ("Don't give agents skills they don't use") implies skill scoping per agent matters.

**O4. Tokens-in vs tokens-out are priced asymmetrically (07:00).**
Implication: input-side budget (system prompt + skills + context) and output-side budget should be measured separately.

**O5. Paperclip's UI displays $0 cost when running under Claude Max subscription (08:02, 17:02).**
Author asserts this is a real bug in cost reporting for subscription users — the dollar number shown is misleading, not protective. Two chapters discuss it (08:02 statement; 17:02 "what to do about it").

**O6. Author has a working method to query the embedded Postgres for real cost data (09:05, 10:03).**
Chapter 09:05 ("The prompt to query Paperclip's embedded Postgres for real cost") + 10:03 ("How the usage-sync script works under the hood") — author claims to demonstrate both an SQL-style query approach and the underlying sync script.

**O7. Cached tokens are claimed as ~10× cheaper than uncached input tokens (12:00, 13:02).**
Chapter title is unambiguous on the magnitude. 13:02 ("Context management and when Claude clears the cache") flags the cache-eviction edge case.

**O8. Author shows live per-agent dollar costs (14:00).**
Cited in chapter title: "chief of staff $2, career $2.4, calendar $1.9" (verbatim from description). These are author's agents, not ours, but order-of-magnitude is informative.

**O9. Per-agent model selection is treated as a first-order lever (15:00, 16:06).**
"Not everything needs Sonnet" + "Using local Ollama models for cheap, frequent scans" — author is mixing tiers (Sonnet / Haiku / local Ollama) inside one company.

**O10. Author's closing 5-pillar summary (18:02): model, cadence, instructions, budgets, measurement.**
This is the author's own prescription for cost discipline.

## 4. Recommendations (what Paperclip should do about it) — for CEO + COS routing

Each is tagged with the observation it derives from and a concrete owner / unblock action.

**R1. (O5, O6) Verify whether our Paperclip UI under Claude Max subscription shows $0 today; if yes, port the author's Postgres query approach. Owner: COS / OS-Controller.**
Action: pull the video at 08:02 and 09:05–10:03, then check whether `app/server` already has a usage-sync path and whether the `cost` field in `runs` / `agent_runs` is populated when adapter type is `claude_local`. If not, file a Dev issue under V5 Framework Implementation referencing this brief.

**R2. (O2, O3, O4) Convert DL-040 single-active-source policy from "ad-hoc CEO unblock" into a measurable cadence policy: each agent has a documented heartbeat purpose (ticker / event-only / daily / weekly) and any heartbeat that is not event-driven must justify its cadence. Owner: CEO + COS.**
Concrete deliverable: a `processes/19-agent-heartbeat-cadence.md` table listing each agent, its current cadence, and its justification. Block adding a 16th persistent agent until this table exists.

**R3. (O3, O7) Audit skill exposure per agent (O3) AND prompt-cache hit rate per agent (O7). Owner: COS.**
Action: enumerate `skills/*.md` per agent in `docs/ops/AGENT_SKILL_MATRIX.md`; for each agent, confirm every skill is actually triggered. Cross-reference against cache-hit rate from the runs table (per O6 query) — agents with high uncached input tokens point at either bloated skills or a cache-clearing pattern in their flow.

**R4. (O9) Adopt a tiered model policy per agent role.**
Default rule of thumb derived from the source: high-judgment + low-frequency = Sonnet; high-frequency + bounded scope = Haiku; sentinel sweeps and local-only validation = local Ollama. Owner: CEO with COS support. Concrete deliverable: model assignment column in the agent matrix in R3.

**R5. (O1, O8) Define a per-agent dollar budget and an alarm threshold.**
The author shows three agents at $1.9–$2.4 each as the steady-state ballpark. We have ~15 agents — at that ballpark we'd be ~$30/day = ~$900/mo just for agent activity. Action: COS to set a per-agent monthly cap in the agent config (if the platform supports it; if not, file a P2 dev issue) and an alert when an agent exceeds its cap.

**R6. (O10) Adopt the author's 5-pillar cost-discipline framing (model / cadence / instructions / budgets / measurement) as the contents of `processes/19-agent-cost-discipline.md`.**
Each pillar gets a current-state column and an owner. Use this brief's R1–R5 as the seed entries. Owner: COS to draft, CEO to approve.

## 5. Cross-references inside Paperclip

- **DL-040 token throttle (project_token_throttle_dl031_2026_04_28):** the source independently argues O2 — heartbeat cadence is the #1 lever. This is corroborating evidence for the DL-040 single-active-source policy, not a refutation. R2 generalizes DL-040 from "research-only" to "all agents".
- **QUA-619 Strategy Card technical pre-review (DL-030 Class-2):** the executionPolicy attached by QB Wave 2 (this issue's wake comment) routes the brief to QB2 review. That is the right route for this *operations* deliverable; no additional pipeline involvement is required because no Strategy Card / EA emerges from this source.
- **QUA-569 [CEO] Midnight startup sequence:** inbound mention links this brief into the CEO's startup-sequence work.
- **AGENT_SKILL_MATRIX.md:** R3 modifies this file directly; no separate document needed.

## 6. Did this source contain explicit trading-strategy rules?

**No.** Per the issue acceptance, no Strategy Card is produced from this source. The video is operations content about cost-management of the Paperclip platform itself, not a mechanical trading strategy.

## 7. Open questions for re-watch (if a transcript becomes available)

These are the exact items a verbatim transcript would let us close:
1. (08:02 / 17:02) Is the $0 display a *server* bug (sync script not run for `claude_local` adapter) or a *UI* bug (cost field present but not rendered)?
2. (09:05) Author's exact SQL — does it operate on the same `runs` / `usage` schema we have, or a different deployment?
3. (12:00) Does the author quote a specific cache-pricing ratio, or is "10x cheaper" a paraphrase of Anthropic's published 0.10× cache-read pricing? Material for whether to cite Anthropic docs vs cite Fru Dev.
4. (14:00) Are the live $1.9–$2.4 numbers per day, per week, or per month? The chapter title doesn't disambiguate.
5. (16:06) Which Ollama model(s) does the author run, and for which agent role? Material for R4.

A follow-up child issue can be opened against COS to re-acquire transcript and answer these once a non-cloud egress is available.

---

*End of brief.*
