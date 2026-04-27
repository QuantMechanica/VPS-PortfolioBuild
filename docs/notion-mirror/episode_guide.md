<!--
AUTO-GENERATED MIRROR — DO NOT EDIT.
Source: Notion page 34947da58f4a81688ca7ff3e1097b8d4
Title: Episode Guide (YouTube)
Mirrored: 2026-04-27T11:24:00Z by Documentation-KM (QUA-151)
Editing surface: Notion. Direct edits will be overwritten by the next sync.
Manifest: infra/notion-sync/manifest.yaml
-->

# Episode Guide (YouTube)

**Channel:** [youtube.com/@quantmechanica](http://youtube.com/@quantmechanica)
**Language:** English
**Style:** Data-driven, no hype, professional. No clickbait thumbnails. Screen-cast + voiceover + occasional face-cam.
**Cadence:** 1–2 episodes per week during active build, monthly retrospectives later.

## Episode Roadmap (First Season)

### Foundation Arc (Episodes 1–5)

**EP01 — The Reset: Why I'm Starting Over After 6 Months**

- Date: target 2026-04-25
- Length: 8–12 min
- Content: the story of V1–V4, what worked (strategy archive, research discipline), what didn't (tech debt, over-parallelization, scope creep). The decision to rebuild fresh on VPS with revised Paperclip company.
- CTA: subscribe, newsletter, follow the rebuild live
- Screen shots: old local setup chaos, new VPS terminal blank-slate

**EP02 — Ordering the VPS (Hetzner AX42, BYOL Plan, Eval-First Windows)**

- Length: 6–8 min
- Content: live walkthrough of Hetzner AX42 order, the Contabo→Hetzner pivot story (Contabo blocks BYOL Windows), the Eval-first strategy (defer MyOEM license to Month 5), break-even math vs. alternatives (Mini-PC, Hyonix). Show actual Hetzner checkout pages. Real spend revealed on camera.
- Expense reveal: **Month 1 first-month spend — to be verified at Hetzner checkout screenshot** (approximately €46/mo + €39 one-time setup = ~€85 first month; exact EUR including VAT confirmed at checkout)
- Learning highlighted: research provider BYOL policies BEFORE buying software licenses (Codex review 2026-04-21 caught the Contabo BYOL block before MyOEM purchase)

**EP03 — Installing Windows Server via KVM Console**

- Length: 15–20 min
- Content: KVM console install, VirtIO drivers, RDP setup, IPBan, first successful RDP connect from local PC
- Gotchas highlighted: TPM choice, common install pitfalls

**EP04 — New DarwinexZero Account + Tick Data Suite Migration**

- Length: 10–15 min
- Content: open a fresh DarwinexZero account (new account number, zero history, per 2026-04-21 Board decision), KYC walkthrough (redacted), MT5 Demo login. Move existing Tick Data Suite license from local PC to the VPS (Fabian's license is valid ~2 more weeks; renewal decision pending). Download first tick history for EURUSD + key factory symbols via TDS on VPS.
- Learning highlighted: Verify vendor compatibility via **practical experience**, not just marketing pages. TDS's public site emphasizes MT4 framing, but TDS is functional for MT5 tick-data import workflows — Fabian has been running it in V1–V4. Board review 2026-04-21: Codex and Claude-Assistant almost dropped TDS from V5 based on public docs alone; Fabian's hands-on knowledge corrected the mistake. Lesson: ask the operator before deleting tools they actually use.
- TDS renewal decision flagged for Month 1 (license expires ~2026-05-05): Monthly €32.90 / Yearly €189 / Lifetime €549. Recommendation TBD based on first weeks of VPS operation.

**EP05 — 6x MT5 Instances: 5 Factory + 1 Live/Demo**

- Length: 12–15 min
- Content: parallel MT5 install under 6 data paths, T1-T5 factory terminals, T6 Demo/Live terminal, Darwinex login, symbol import on base instance, symbol copy pattern to factory instances, T6 isolation rules
- Learning highlighted: .DWX symbols as custom symbols, the "never delete bases/" rule

### Company Formation Arc (Episodes 6–9)

**EP06 — Installing Paperclip + Hiring the First Agents**

- Content: Paperclip daemon install, creating "QuantMechanica V5" company, hiring CEO + CTO + Research agents with revised English prompts
- Show the prompts on screen, explain the learnings baked in

**EP07 — The Research Agent's First Mission: One Source, All Strategies**

- Content: dispatching Research agent to mine one specific source (e.g., a classic quant book or a well-known strategy paper). Watch the source-by-source methodology in action.
- Learning highlighted: why depth-first beats breadth-first

**EP08 — Building the First EA From a Research Finding**

- Content: Research → Development handoff, CTO writes the first EA from a single extracted strategy, first backtest
- Learning highlighted: enhancement doctrine (exit-only OK, entry filters kill trades)

**EP09 — First Baseline Sweep + First PASS/FAIL Decision**

- Content: Pipeline Operator dispatches baseline sweep, CEO agent makes first PASS/FAIL call, how the 2-agent cross-challenge works
- Learning highlighted: smoke ≠ BL-equivalent, the SM_261 lesson

### Expansion Arc (Episodes 10+)

- EP10+ topics TBD based on what happens. Maintain the discipline: each episode covers a real milestone or lesson, not filler.

## Production Discipline

- **No episode without real progress.** If a week has no shippable milestone, we skip rather than pad.
- **Thumbnails: data-driven, not hype.** Dark navy/teal brand palette. No shocked-face reaction shots.
- **Every episode includes a specific learning or decision**, not just a progress log.
- **Board review before publish.** Claude-Assistant + Codex sanity-check the claims and numbers.
- **Expense reveal where relevant.** Every episode with a purchase shows the actual number.
- **Support CTA.** End every video, YouTube description, episode page, and newsletter issue with a small Buy-me-a-coffee support CTA. This is project support, not an investment ask.

## Episode Artifacts

For each episode, archive under `/episodes/EP{nn}-{slug}/`:

- Script outline (.md)
- Recording (.mp4, canonical on YouTube only, local for archive)
- Thumbnail (.png)
- Show-notes blog post (crosspost to [quantmechanica.com](http://quantmechanica.com))
- Newsletter issue
- Buy-me-a-coffee CTA copy
- Relevant commit hashes
