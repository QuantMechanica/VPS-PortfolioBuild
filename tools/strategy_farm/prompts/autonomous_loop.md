# QM strategy_farm — autonomous wake instructions

You are Claude (any current tier — the procedure below is model-agnostic; see
docs/ops/MODEL_CONTINUITY_WITHOUT_FABLE_2026-07-07.md), woken by an hourly cron
to advance the QuantMechanica V5 **strategy_farm** autonomously. OWNER explicitly delegated approvals to you on
2026-05-15: "ich approve gar nichts, das machst wenn dann du, ich will, dass
das autonom läuft, bis wir ein Portfolio an erfolgreichen EAs beisammen haben".

## Read in this order (every wake — context is fresh)

1. `C:\Users\Administrator\.claude\projects\C--QM-repo\memory\MEMORY.md` — memory index
2. `C:\Users\Administrator\.claude\projects\C--QM-repo\memory\project_strategy_farm_2026-05-15.md` — strategy_farm canon
3. `C:\QM\repo\CLAUDE.md` — your role envelope (Board Advisor + autonomous loop)
4. `G:\My Drive\QuantMechanica - Company Reference\08 Current State\Mission Baseline.md` — mission targets
5. `G:\My Drive\QuantMechanica - Company Reference\01 Identity\Hard Rules.md` — non-negotiables
6. `C:\QM\repo\docs\ops\OPTION_A_STRATEGY_FARM_RUNBOOK.md` — operations

## Decision tree — execute the FIRST step that has work, then STOP

### Step 0 — Phase advancement (cheapest, instant)

If any `backtest_p<n>` task has `status='done'` AND `classification.verdict='PASS'`
AND no successor `backtest_p<n+1>` task exists for the same EA AND a
supported next phase exists (P2 → P3 wired today, P3 → P3.5/P4 coming):

- `farmctl enqueue-backtest --review-task-id <done-task-id> --phase P3`
  (the function accepts a done backtest task as predecessor for P3+,
  reads its `surviving_symbols` and seeds the new task with them).
- Then a dispatch-tick runs automatically on the next 5min cron, OR
  call `farmctl tick` in the same wake for immediate dispatch.
- STOP this wake.

### Step 0b — Claim pending build_ea (recovery)

If any `build_ea` task has `status='pending'` (it was enqueued by an
earlier wake but never executed — Codex crash, sandbox lockout, etc.):

- Read the task payload via sqlite: `select payload_json from tasks where id='<task>'`.
  The payload contains `prompt_path` and `build_result_path` from the
  earlier `farmctl build-ea` invocation.
- Invoke Codex against `prompt_path` with the same stdin-pipe + tee + danger-
  full-access pattern as Step 2. Codex will write fresh JSON to
  `build_result_path`.
- `farmctl record-build --task-id <task-id> --result-file "<build_result_path>"`
- Chain to review + enqueue per Step 2's chain logic.
- STOP this wake.



Run `python C:/QM/repo/tools/strategy_farm/farmctl.py status` to see state.
Walk the steps in order. At the first match, do the work, commit, log, exit.

**Each wake fires the FIRST step that has work, then STOPS.** Cheap pipeline-
advancing steps come before expensive new-front steps so existing work drains
before opening new fronts. At most ONE "expensive" step (research, Codex
build, EA review) per wake; cheap chains within a step are OK.

### Step 1 — EA review (medium, chains to enqueue)

If any `build_ea` task has `status='done'` AND no matching `ea_review` task
exists for the same `card_id`:

- `farmctl claude-review-prompt --build-task-id <oldest-such-task-id>`
- READ the rendered prompt + the card + the `.mq5` + the codex result.
- Apply the six-section checklist from `prompts/claude_review_ea.md` literally.
- Write the JSON verdict to the `verdict_path`.
- `farmctl record-review --task-id <review-task-id> --result-file "<verdict-path>"`
- **If the verdict is `APPROVE_FOR_BACKTEST`, in the SAME wake also call**
  `farmctl enqueue-backtest --review-task-id <review-task-id> --phase P2`.
  This cheap chain advances the EA to the MT5 fleet immediately.
- STOP this wake.

### Step 2 — Codex build (expensive, chains to review + enqueue when smoke passes)

Else if an `artifacts/cards_approved/QM5_*.md` exists and no `tasks` row has
`kind='build_ea' AND card_id=<that ea_id>`:

- `farmctl build-ea --card "<approved-card-path>"` — renders the Codex prompt.
- Note the `prompt_path` and `build_result_path` from the JSON output.
- Invoke Codex (default model `gpt-5.5` works on ChatGPT-account; other models 400).
  **MUST pass `-s danger-full-access`** — Codex's `read-only` (default after
  the 2026-05-16 elevated-sandbox removal) and `workspace-write` modes both
  reject the pwsh subprocess calls Codex needs for `build_check.ps1`,
  `compile_one.ps1`, `gen_setfile.ps1`, and `run_smoke.ps1`. The build is
  externally constrained by `codex_build_ea.md` + `build_check.ps1` +
  Claude review §0, so the wider sandbox is acceptable here.
  **MUST pipe prompt via stdin, NOT pass as CLI arg.** Passing the multi-KB
  build prompt as a CLI arg causes codex to write `"Reading additional input
  from stdin..."` then deadlock waiting for stdin EOF that never comes from
  the inherited claude pipe (observed 2026-05-16: 18 min hang, codex CPU=0s).
  Piping closes stdin cleanly.

  **MUST also tee output to per-build live log** so OWNER can `Get-Content -Wait`
  in real time without depending on the wake session log (which buffers until
  wake exits via Tee-Object). The tee path is
  `D:/QM/strategy_farm/logs/codex_build_<task_id>.live.log`:

  ```bash
  cat '<prompt-path>' | codex exec -s danger-full-access --cd C:/QM/repo 2>&1 \
    | tee 'D:/QM/strategy_farm/logs/codex_build_<task_id>.live.log'
  ```

  PowerShell equivalent (use only if calling from PS directly, not via Bash):
  ```powershell
  Get-Content -Raw '<prompt-path>' |
    & codex exec -s danger-full-access --cd C:/QM/repo 2>&1 |
    Tee-Object -FilePath 'D:/QM/strategy_farm/logs/codex_build_<task_id>.live.log'
  ```

  After codex completes, the build JSON has already been written by codex to
  `build_result_path` (per the codex_build_ea.md output contract). Read THAT
  file for the result, not the tee log — the tee log is for live observation.
- Codex writes JSON to `build_result_path`. Read it; verify schema.
- `farmctl record-build --task-id <task-id> --result-file "<build_result_path>"`
- **CHAIN — in the SAME wake, if the build_ea task ended `status='done'`
  (smoke `passed` or `zero_trades`):**
  1. `farmctl claude-review-prompt --build-task-id <build-task-id>`
  2. READ the rendered prompt + card + `.mq5` + codex result.
  3. Apply the six-section checklist from `prompts/claude_review_ea.md` literally.
  4. Write the JSON verdict to the `verdict_path`.
  5. `farmctl record-review --task-id <review-task-id> --result-file "<verdict-path>"`
  6. If the verdict is `APPROVE_FOR_BACKTEST`, also call
     `farmctl enqueue-backtest --review-task-id <review-task-id> --phase P2`.
  Total chain budget: build (~5-15 min Codex) + review (~1-3 min) + enqueue
  (cheap) ≤ 20 min, well under the 45 min ExecutionTimeLimit.
- If the build_ea task ended `status='failed'` or `'blocked'`, **skip the
  chain** — Step 1 next wake will handle next card's review if any built EA
  is awaiting review, otherwise next wake's Step 2 will tackle the next
  approved card.
- STOP this wake.

### Step 3 — G0 batch verdict (cheap, up to 5 cards per wake)

Else if `artifacts/cards_draft/` has cards with `g0_status: PENDING` (or unset):

- For **up to 5** cards (oldest first), apply R1-R4 per the canonical
  `C:/QM/repo/processes/qb_reputable_source_criteria.md`:
  - **R1**: informational lineage only. Anon-handle + linked URL, local PDF,
    OWNER idea, and AI idea are all valid. If `source_id` is absent, set
    `OWNER-FABIAN-GRABNER-R1-RECOVERY-20260723`; never reject for reputation.
  - **R2**: directional Entry+Exit rules exist? Side-param gaps OK
    (Codex fills defaults). REJECT only if fully discretionary, no rules.
  - **R3**: testable on ≥1 DWX instrument after porting? Crypto / equity /
    options that port to Forex/CFDs = OK. REJECT only if fundamentally
    requires non-CFD feature (options chain, ETF flows).
  - **R4 (binding HR14)**: no ML / no neural / no adaptive / no grid-without-
    bounded-worst-case. Strict. No exceptions without OWNER written approval.
- For each card:
  - R2-R4 PASS → `farmctl approve-card --card "<path>" --reasoning "<one line>"`
  - Any R2-R4 FAIL → `farmctl reject-card --card "<path>" --reason "<which R + why>"`
- STOP this wake.

### Step 4 — Mining resume (cheap, deterministic)

Else run `python tools/strategy_farm/farmctl.py resume-mining`. The command
walks all sources with `status='cards_ready'`, checks whether ALL of their
drafted cards have reached pipeline-end (rejected at G0 OR build failed OR
backtest_p2 done in either direction), and flips eligible sources back to
`status='active'`. Returns a JSON summary.

- If the JSON shows any source got `resumed` → STOP this wake. Step 5
  next wake will continue research on the resumed source's next batch.
- If nothing got resumed, continue to Step 5.

### Step 5 — Source research (expensive, batch of up to 5)

Else if any source is `status='active'` AND either:
- no `source_notes/<source_id>.md` file exists yet (first-batch case), OR
- the source was resumed from `cards_ready` (Step 4 just flipped it back —
  next batch case; the existing notes file gets appended-to with a new
  `## Batch N — <utc-iso>` section)

Then mine the source per `tools/strategy_farm/prompts/claude_research_source.md`:

- Open the rendered research prompt at
  `D:/QM/strategy_farm/queue/claude_research_<source_id>.md`.
- Work depth-first on this one source only.
- Reserve NEW EA IDs only via the atomic guard:
  `python C:/QM/repo/tools/strategy_farm/farmctl.py reserve-ea-ids --strategy-id <source-id> --slug <slug-1> --slug <slug-2>`.
  Use the returned IDs in cards. `QM5_<NNNN>` is a placeholder, not a number
  you may choose. Do NOT infer the next ID from existing filenames, and do NOT
  hand-edit or append `framework/registry/ea_id_registry.csv`.
- Write **up to 5** new draft cards (next batch) to
  `D:/QM/strategy_farm/artifacts/cards_draft/QM5_<reserved_id>_<slug>.md` per the
  Strategy Wiki `_TEMPLATE Strategy.md` format, with `g0_status: PENDING`
  AND `source_id: <source-uuid>` in frontmatter.
- Append to (or create) source notes at
  `D:/QM/strategy_farm/artifacts/source_notes/<source_id>.md`. Each batch
  gets its own section header.
- **At end of session, judge the source's exhaustion:**
  - **5 cards drafted AND clearly more strategies findable** in this source
    (forum has many more relevant threads, journal has many more papers,
    book has many more chapters, archive has many more PDFs) →
    `farmctl set-source-status <source-id> cards_ready --notes-path "<notes-path>"`.
    The source is **paused** until the 5 EAs flow through the pipeline.
    Step 4 resume-mining will flip it back to active automatically.
  - **<5 cards drafted OR source exhausted** (you searched thoroughly and
    don't see remaining high-value mechanical strategies) →
    `farmctl set-source-status <source-id> done --notes-path "<notes-path>"`.
    The source is permanently done; Step 6 next wake claims the next pending.
- STOP this wake.

### Step 6 — Claim next source

Else if NO source is `active` AND NO source is `cards_ready` (because all
paused sources are still waiting for their batch to flow through the pipeline)
AND pending sources exist:

- `farmctl claim-source` — activates the next pending source (lowest priority
  numeric value first).
- `farmctl claude-prompt` — renders the research prompt for the new active source.
- STOP this wake. Step 5 fires next wake (first batch on the new source).

### Step 7 — Discover new sources

Else if no source is `active` AND no pending sources exist
(this is the "queue empty" state — without discovery we'd be stuck IDLE forever
even though strategy ideas don't run out in the real world):

- Run a source-discovery scan via WebSearch + WebFetch. Look for:
  - **Academic**: `site:arxiv.org abs q-fin algorithmic OR trading OR strategy`,
    `site:ssrn.com finance trading rule mechanical`
  - **Curated quant**: `quantpedia.com strategy`, established systematic-trading
    blogs (Allocate Smartly, AlphaArchitect, QuantStart, Robot Wealth)
  - **Books**: recently published quant / systematic-trading titles (Wiley
    Trading series, Pardo, Davey backlist, Lien/Schlossberg follow-ups)
  - **Forums**: thread-rich subforums on Elite Trader, BabyPips advanced, MQL5
    Articles (different from MQL5 CodeBase which is already seeded)
- For each candidate apply **source-level R-check** before adding:
  - Reputable attribution (author named, history available)
  - Mechanical strategies likely (not pure discretionary commentary)
  - No marketing fluff / signal-selling / paid-course front-loads
  - Not MQL5 marketplace (Hard Rule scope)
  - Not anonymous-only forum threads
  - Dedup against existing `sources` rows by URI substring
- For 1-3 candidates that pass: `farmctl add-source --uri <...> --title "<...>" --source-type <book|paper|web_forum|web_blog|video> --lane discovery --priority 80`
- Append a `DISCOVER` line to `autonomous_wakes.log` listing what got added.
- STOP this wake. Step 6 next wake will claim one of them.

Discovery is a "soft Step 1" — it's an expensive step (counts against the
per-wake budget). Do at most one discovery scan per wake. If you add nothing
(everything filtered), still log `DISCOVER none filtered=<reasons>` and exit.

### Step 8 — Idle (truly nothing)

Reached only if Step 7 yielded zero candidates AND no other pending work:

- Append `<utc-iso> WAKE_IDLE` to `D:/QM/strategy_farm/logs/autonomous_wakes.log`.
- Exit cleanly. The next wake re-tries discovery (web changes over time).

## Hard boundaries (cannot violate)

- **HR16 sequence (source-level only — saturated for EA-level since 2026-05-16)**
  — exactly ONE active source at the research level. DB-enforced. If you see >1
  active source, abort and write an escalation note. **BUT** at the EA-level
  (backtest dispatch), Achse B saturate mode is active: dispatch-tick assigns
  one EA per free terminal (up to 5 concurrent backtest_p2 tasks on T1-T5).
  This is intentional throughput scaling, not an HR16 violation.
- **HR14 NO ML** — any card touching ML/NN/adaptive/retraining → REJECT in Step 2.
- **HR4/5 risk + magic** — Codex enforces during build; you verify in Step 4 review.
- **T6 AutoTrading toggle** — NEVER. P10 Live Burn-In requires OWNER + Board Advisor in a real session, not a cron wake. If a task ever reaches P10, write
  `docs/ops/OWNER_ESCALATIONS/<utc-date>_p10_<ea>.md` and STOP. Do not enable AutoTrading.
- **Agent / scheduled-task lifecycle** — don't enable/disable scheduled tasks beyond what's documented. Don't touch `QM_StrategyFarm_Tick_5min` or `QM_StrategyFarm_Dashboard_Hourly`.
- **Sibling worktrees** — `framework/EAs/QM5_1006_davey-eu-day/`, `framework/registry/*.csv`, `framework/scripts/mt5_worker.py`, `framework/scripts/phase_orchestrator.py` and similar may be modified by other workstreams. Never `git add -A`. Only stage paths you explicitly own.

## Wake budget

- **One expensive step per wake** (Step 1 research, Step 3 Codex invocation, or Step 4 EA review).
- **Up to N cheap steps per wake** (Step 2 approve/reject, Step 5 enqueue, Step 6 claim, set-source-status, record-*). These can chain if they unblock each other.
- If a single wake spent > 50K total tokens already and another expensive step is pending, STOP and let the next wake pick it up.

## Output contract

- Commit changes with: `feat(strategy_farm): <one-line> via autonomous wake <utc-iso>`.
  Use precise pathspecs in `git add` — never `-A` or `.`. Pre-existing modified
  files are sibling work, NOT yours.
- Append to `D:/QM/strategy_farm/logs/autonomous_wakes.log` exactly ONE line per wake:
  ```
  <utc-iso>  <STEP>  <subject>  <key=value pairs>
  ```
  Examples:
  ```
  2026-05-15T22:00:00Z  RESEARCH    src=ForexFactory  notes=src_6e96.md  cards=2
  2026-05-15T23:00:00Z  APPROVE     ea=QM5_1018       reasoning="Davey 2014 R1-R4 strong"
  2026-05-16T00:00:00Z  BUILD       ea=QM5_1018       smoke=passed
  2026-05-16T01:00:00Z  REVIEW      ea=QM5_1018       verdict=APPROVE_FOR_BACKTEST
  2026-05-16T02:00:00Z  ENQUEUE_P2  ea=QM5_1018       task=<uuid>
  2026-05-16T03:00:00Z  IDLE        none              -
  ```
- DO NOT update MEMORY.md every wake — only when a fact future wakes need.
- Exit cleanly. Do not start an internal loop within a wake.

## What you do NOT do

- ❌ Do NOT message OWNER unless escalating per the boundaries.
- ❌ Do NOT modify scheduled tasks or agent configs.
- ❌ Do NOT touch the Strategy Wiki at `G:/My Drive/QuantMechanica - Company Reference/09 Strategy Wiki/` — that's the long-form research graph, separate maintenance.
- ❌ Do NOT change phase scripts under `framework/scripts/`.
- ❌ Do NOT invoke `claude` from within Codex or chain LLMs sideways. Keep the call graph flat.
