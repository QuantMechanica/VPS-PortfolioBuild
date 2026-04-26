# Episode Guide (YouTube)

> **V5 Source:** Notion `Episode Guide (YouTube)` (id `34947da5-8f4a-8168-8ca7-ff3e1097b8d4`)
> **Migrated to repo:** 2026-04-26

**Channel:** `youtube.com/@quantmechanica`
**Language:** English
**Style:** Data-driven, no hype, professional. No clickbait thumbnails. Screen-cast + voiceover + occasional face-cam.
**Cadence:** 1-2 episodes per week during active build, monthly retrospectives later.

## Episode Roadmap (First Season)

### Foundation Arc (Episodes 1-5)

#### EP01 — The Reset: Why I'm Starting Over After 6 Months
- Date: target 2026-04-25 (slipping; revisit)
- Length: 8-12 min
- Content: the story of V1-V4, what worked (strategy archive, research discipline), what didn't (tech debt, over-parallelization, scope creep). The decision to rebuild fresh on VPS with revised Paperclip company.
- CTA: subscribe, newsletter, follow the rebuild live
- Screen shots: old local setup chaos, new VPS terminal blank-slate

#### EP02 — Ordering the VPS (Hetzner AX42, BYOL Plan, Eval-First Windows)
- Length: 6-8 min
- Content: live walkthrough of Hetzner AX42 order, the Contabo→Hetzner pivot story (Contabo blocks BYOL Windows), the Eval-first strategy (defer MyOEM license to Month 5), break-even math vs. alternatives (Mini-PC, Hyonix). Show actual Hetzner checkout pages. Real spend revealed on camera.
- Expense reveal: Month 1 first-month spend ≈ €204 (€75.60/mo + €128.40 one-time setup)
- Learning: research provider BYOL policies BEFORE buying software licenses (Codex review 2026-04-21 caught the Contabo BYOL block before MyOEM purchase)

#### EP03 — Installing Windows Server via KVM Console
- Length: 15-20 min
- Content: KVM console install, VirtIO drivers, RDP setup, IPBan, first successful RDP connect from local PC
- Gotchas highlighted: TPM choice, common install pitfalls

#### EP04 — New DarwinexZero Account + Tick Data Suite Migration
- Length: 10-15 min
- Content: open a fresh DarwinexZero account (new account number, zero history, per 2026-04-21 Board decision), KYC walkthrough (redacted), MT5 Demo login. Move existing Tick Data Suite license from local PC to the VPS (license valid ~2 more weeks; renewal decision pending). Download first tick history for EURUSD + key factory symbols via TDS on VPS.
- Learning: Verify vendor compatibility via practical experience, not just marketing pages. TDS public site emphasizes MT4 framing, but TDS works for MT5 tick-data import workflows. Board review 2026-04-21: Codex and Claude-Assistant almost dropped TDS from V5 based on public docs alone; OWNER's hands-on knowledge corrected the mistake. Lesson: ask the operator before deleting tools they actually use.
- TDS renewal decision flagged for Month 1 (expires ~2026-05-05): Monthly €32.90 / Yearly €189 / Lifetime €549. Recommendation TBD.

#### EP05 — 6× MT5 Instances: 5 Factory + 1 Live/Demo
- Length: 12-15 min
- Content: parallel MT5 install under 6 data paths, T1-T5 factory terminals, T6 Demo/Live terminal, Darwinex login, symbol import on base instance, symbol copy pattern to factory instances, T6 isolation rules
- Learning: `.DWX` symbols as custom symbols, the "never delete bases/" rule

### Company Formation Arc (Episodes 6-9)

#### EP06 — Installing Paperclip + Hiring the First Agents
- Content: Paperclip daemon install, creating "QuantMechanica V5" company, hiring CEO + CTO + Research + Documentation-KM agents with revised English prompts
- Show the prompts on screen (now in `paperclip-prompts/` in repo), explain the V1→V5 learnings baked in

#### EP07 — The Research Agent's First Mission: One Source, All Strategies
- Content: dispatching Research agent to mine one specific source (e.g., a classic quant book or a well-known strategy paper). Watch the source-by-source methodology in action.
- Learning: why depth-first beats breadth-first

#### EP08 — Building the First EA From a Research Finding
- Content: Research → Development handoff, CTO writes the first EA from a single extracted strategy, first backtest
- Learning: enhancement doctrine (exit-only OK, entry filters kill trades); V5 framework's 4-module Modularity in action

#### EP09 — First Baseline Sweep + First PASS/FAIL Decision
- Content: Pipeline Operator dispatches baseline sweep, CEO agent makes first PASS/FAIL call, how the 2-agent cross-challenge works
- Learning: smoke ≠ BL-equivalent, the SM_261 lesson

### Expansion Arc (Episodes 10+)

EP10+ topics TBD based on what happens. Maintain the discipline: each episode covers a real milestone or lesson, not filler.

## Production Discipline

- **No episode without real progress.** If a week has no shippable milestone, skip rather than pad.
- **Thumbnails: data-driven, not hype.** Dark mode, Emerald `#10b981` accent. No shocked-face reaction shots.
- **Every episode includes a specific learning or decision**, not just a progress log.
- **Board review before publish.** Claude-Assistant + Codex sanity-check the claims and numbers.
- **Expense reveal where relevant.** Every episode with a purchase shows the actual number.
- **Support CTA.** End every video, YouTube description, episode page, and newsletter issue with a small Buy-me-a-coffee support CTA. Project support, not investment ask.

## Episode Artifacts

For each episode, archive under `episodes/EP{nn}-{slug}/`:

- Script outline (`script.md`)
- Recording (`.mp4`, canonical on YouTube only, local for archive)
- Thumbnail (`.png`)
- Show-notes blog post (crosspost to quantmechanica.com)
- Newsletter issue (`newsletter.md`)
- Buy-me-a-coffee CTA copy
- Relevant commit hashes
