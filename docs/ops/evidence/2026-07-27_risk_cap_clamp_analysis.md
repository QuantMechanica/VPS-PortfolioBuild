# Risk-cap clamp analysis — FTMO campaign deploys at 1×, not 4–8×

**Date:** 2026-07-27
**Author:** Claude
**Scope:** Analysis + proposal only. No EA/framework source edited. No Factory OFF/ON.
**Trigger:** The FTMO multi-account campaign is measured at 4–8× the backtest position
size, but the framework hard-caps per-trade risk at 1% of equity and no current campaign
EA raises that cap.

---

## Executive verdict

**Confirmed.** Every one of the four current FTMO-campaign legs deploys at **1× the
backtest position size (1% of equity per trade)**, regardless of the `RISK_PERCENT=4/8`
in its challenge set file. The framework silently clamps them. The campaign's measured
P(pass) (86.3% OOS, `docs/research/FTMO_MULTI_ACCOUNT_CAMPAIGN_2026-07-26.md`) is a
function of 4×/8× sizing and therefore **is not the behaviour that would be deployed
today**. The book at 1× trades at backtest size — far below the sprint sizing its
statistics assume.

Second finding: even after the cap is correctly raised, the OWNER-ratified ceiling is
**5.0**, so the two 8× legs (10553, 13036) can never reach 8× without breaching the
ceiling. They must be re-sized to ≤5× or the book's risk budget re-derived. The ceiling
is not to be raised (tied to the FTMO daily-loss limit).

---

## 1. The clamp — exact call chain, confirmed file:line by file:line

### 1a. Init sets a 1% cap unconditionally

`framework/include/QM/QM_Common.mqh`

- **:179** `const double risk_cap_money = AccountInfoDouble(ACCOUNT_EQUITY) * 0.01;`
  — the FIXED-mode money rail = 1% of init-time equity.
- **:180** `QM_RiskSizerConfigure(mode, risk_percent, risk_fixed, portfolio_weight, risk_cap_money)`
  — stores that money cap in `g_qm_risk_per_trade_cap_money`.
- **:182** `QM_RiskSizerSetCapPct(1.0);` — **unconditional**, as reported.

`framework/include/QM/QM_RiskSizer.mqh`

- **:68–71** `QM_RiskSizerSetCapPct(cap_pct)` → `g_qm_risk_per_trade_cap_pct = cap_pct;`
  So after init, `g_qm_risk_per_trade_cap_pct = 1.0` for every EA that does not override it.

### 1b. PERCENT-mode sizing is clamped to that 1%

`framework/include/QM/QM_RiskSizer.mqh`, `QM_RiskSizerRiskMoney(equity)` (**:91–117**):

- **:97–98** PERCENT mode: `base_risk = equity * (g_qm_risk_percent / 100.0)`
  → with `RISK_PERCENT=4`: `base_risk = 0.04 × equity`.
- **:104** `weighted_risk = base_risk * g_qm_risk_portfolio_weight` → with weight 1.0,
  `weighted_risk = 0.04 × equity`.
- **:108–110** `cap_global = QM_RiskSizerPercentCap(equity)` (PERCENT branch).
- **:84–89** `QM_RiskSizerPercentCap`: since `g_qm_risk_per_trade_cap_pct = 1.0 > 0`,
  returns `equity × (1.0 / 100.0) = 0.01 × equity`.
- **:111–115** `0.01·eq > 0` and `0.04·eq > 0.01·eq` ⇒ `QM_RiskSizerNoteClamp("per_trade_cap", 0.04·eq, 0.01·eq)`,
  then `weighted_risk = 0.01 × equity`.

Result: `RISK_PERCENT=4` returns **1% of equity** of risk money. `RISK_PERCENT=8` returns
the same 1%. Because lots scale linearly with risk money for a fixed stop
(`QM_LotsForRiskFromSnapshot`, `QM_RiskSizer.mqh:365–391`), **1% risk money = exactly the
1× (backtest) lot size**. The 4×/8× intent collapses to 1×.

Entry-path proof that this is the live sizing route: `QM_Entry.mqh` sizes via
`QM_LotsForRiskAtEntry` (**:288–306**) → `QM_RiskSizerRiskMoney(equity)`
(`QM_RiskSizer.mqh:681`), which is the clamped function above. Standard framework EAs
place entries through `QM_Entry`, so the clamp is on the live path, not a dead branch.

### 1c. RISK_FIXED=1000 in the backtest sits EXACTLY at the cap — verified

Your reading is correct. In the RISK_FIXED backtest (`initial_deposit=100000`,
`RISK_FIXED=1000`):

- `QM_Common.mqh:179` → `risk_cap_money = 100000 × 0.01 = 1000`.
- `QM_RiskSizerRiskMoney` FIXED branch (**:99, :104, :108–110**):
  `base_risk = 1000`, `weighted_risk = 1000 × weight`. At weight 1.0, `= 1000`.
  FIXED uses the **money** cap: `cap_global = g_qm_risk_per_trade_cap_money = 1000`.
- **:111** guard is strict `weighted_risk > cap_global` ⇒ `1000 > 1000` is **false** ⇒
  **no clamp**. Returns 1000.

So RISK_FIXED=1000 rides exactly on the 1% money cap, and the strict inequality means the
clamp never fires — which is precisely why **every backtest was clean and no clamp was
ever observed**. (Corroboration: the Round25 legs sized RISK_FIXED up to 1435 on a 100k
account *would* have clamped; the MT5 validation dodged it via a 1M deposit and live used
the override — `decisions/2026-07-05_ftmo_round25_phase1_deploy.md:43–56`.)

The asymmetry is the trap: FIXED mode is capped in **money** (1000 = boundary, no fire),
but PERCENT mode is capped in **percent** (1.0%), and a percent set file sized for 4× is
4× above that percent cap — so it clamps hard while its RISK_FIXED twin did not.

### 1d. The override exists and must be called from OnInit — no current campaign EA calls it

`framework/include/QM/QM_Common.mqh:315` `QM_FrameworkSetRiskCapPct(const double cap_pct)`
(OWNER-ratified 2026-07-05, Round25 Two-Speed):

- **:317–318** requires `g_qm_fw_initialized` ⇒ must be called **after** `QM_FrameworkInit`.
- **:319** `if(cap_pct <= 0.0 || cap_pct > 5.0) return false;` — hard ceiling **5.0**.
- **:323–325** sets `g_qm_risk_per_trade_cap_money = equity·cap_pct/100` and
  `QM_RiskSizerSetCapPct(cap_pct)`.
- **:326–328** logs `RISK_CAP_OVERRIDE` when `cap_pct ≠ 1.0`.

**Current campaign book** (`docs/ops/evidence/2026-07-27_ftmo_challenge_deploy_manifest.json`):

| Leg | EA | Symbol | set-file RISK_PERCENT | EA has `qm_risk_cap_pct` input? | set file sets it? | deployed cap | deployed size |
|---|---|---|---|---|---|---|---|
| 1 | QM5_13213 balke-gmt3-range-breakout | USDJPY H1 | 4 | **No** | no line | 1.0% | **1×** |
| 2 | QM5_10848 tv-mtf-ambush | XAUUSD H1 | 4 | Yes (default 1.0) | **no line** | 1.0% | **1×** |
| 3 | QM5_10553 mql5-rsioma | XAUUSD H4 | 8 | **No** | no line | 1.0% | **1×** |
| 4 | QM5_13036 balke-go-long-regime | GDAXI M15 | 8 | **No** | no line | 1.0% | **1×** |

Evidence:
- `QM_FrameworkSetRiskCapPct` callers in the tree are only the 12 Round25 EAs
  (10163/10286/10440/10692/10700/10847/10848/10911/11476/12475/12990/12958). Of the four
  campaign legs, **only 10848** is in that set.
- `framework/EAs/QM5_10128_bb-breakout/...mq5:153–175` (representative campaign-class EA)
  and `QM5_13213`, `QM5_10553`, `QM5_13036` call `QM_FrameworkInit` and then log
  `INIT_OK` with **no** `QM_FrameworkSetRiskCapPct` between them.
- The four `*_ftmo_challenge.set` files carry `RISK_FIXED=0`, `RISK_PERCENT=4/4/8/8`,
  `PORTFOLIO_WEIGHT=1`, and **no `qm_risk_cap_pct` line**. So even 10848 (which has the
  input) runs its compiled default `qm_risk_cap_pct = 1.0`
  (`QM5_10848_tv-mtf-ambush.mq5:53`), i.e. still clamped.

All four therefore clamp to 1%. The 8× legs are doubly impossible: `cap_pct=8 > 5.0`
would return false at `QM_Common.mqh:319` ⇒ `INIT_FAILED` even if wired.

---

## 2. Detection trail — and whether any past run actually clamped

**`QM_RiskSizerNoteClamp` is intentionally logger-free.** It only sets globals
(`QM_RiskSizer.mqh:73–79`: `g_qm_risk_clamp_flag/kind/from/to`). By itself it leaves **no**
log line — the sizer is kept logger-free by design (`QM_RiskSizer.mqh:37–39`).

**The trail is emitted by `QM_Entry`, and only there.** `QM_Entry.mqh:287` clears the flag
before sizing; **:311–322** reads it after and emits
`QM_LogEvent(QM_INFO, "RISK_CLAMP", {kind, from, to, lots, symbol, magic})`. For a
per-trade-cap hit, `kind = "per_trade_cap"`. Consequence: a clamp is detectable **only if
the entry is routed through `QM_Entry`** (the standard framework entry). A direct
`QM_LotsForRisk*` caller would clamp silently (flag set, never read).

**Does any past run show `per_trade_cap` clamping? No — none found.**

- Reachable backtest logs under `D:\QM\reports\...`: the only `RISK_CLAMP` events present
  are **`kind="entry_margin_cap"`** (244 occurrences in the FTMO entry-recovery debug set,
  e.g. `D:\QM\reports\debug\ftmo_entry_recovery\QM5_20031_final\...\logger_sample.jsonl`).
  A grep for `"kind":"per_trade_cap"` across that whole tree returns **0**.
- FTMO live terminal logs (`...\Terminal\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Files\QM\`):
  `per_trade_cap` returns **nothing**. The Round25 legs there carry `RISK_CAP_OVERRIDE`
  (10692/10911/11476/12958) — the *override* event, not a clamp — confirming those legs
  raised the cap so the clamp never engaged.

Why the silence is expected, not luck: backtests run FIXED at exactly the 1% money
boundary (§1c, strict `>` → no fire), and the only live deploy (Round25) raised the cap to
match its sizing. The `per_trade_cap` branch has **never triggered in recorded evidence** —
which is exactly why this defect went unnoticed. The first time it *would* fire is a
PERCENT-mode demo run of these four set files, which has not happened yet
(`project_qm_ftmo_multi_account_campaign_2026-07-26.md`: "Nächster Schritt: FTMO-Demo
laufen lassen"). When it does, expect a `RISK_CLAMP` / `per_trade_cap` line on every entry
of all four legs — that storm is itself the auditable proof the book is trading at 1×.

---

## 3. Proposal — minimal, auditable opt-in to a higher cap (ceiling 5.0, not to be raised)

### Option A — set-file-driven input read in OnInit (the ratified Round25 pattern) — RECOMMENDED

Mechanism already exists and is proven: `input double qm_risk_cap_pct = 1.0;` +
`if(!QM_FrameworkSetRiskCapPct(qm_risk_cap_pct)) return INIT_FAILED;` immediately after
`QM_FrameworkInit` (see `QM5_10163_...mq5:49, :258`; `QM5_10848_...mq5:53, :474`). The cap
value lives in the git-tracked set file; init logs `RISK_CAP_OVERRIDE`; a value > 5.0
fails closed at `QM_Common.mqh:319`.

Per-leg cost:
- **10848** already compiles the input ⇒ **set-file-only change**: add `qm_risk_cap_pct=4`
  to its `*_ftmo_challenge.set`. Zero source edit, zero recompile of logic.
- **13213, 10553, 13036** lack the input ⇒ the two-line OnInit addition + recompile, then
  set `qm_risk_cap_pct` in each set file (≤5.0).

Risks:
- Recompile/deploy hazard: farm automation can revert freshly built `.ex5` to committed
  content (`decisions/2026-07-05_ftmo_round25_phase1_deploy.md:87–95`). The **deployed**
  binaries must be pinned + SHA256-verified, exactly as Round25 did.
- The two 8× legs cannot be honoured: `qm_risk_cap_pct` is bounded ≤5.0. Setting 8 →
  `INIT_FAILED` (fail-closed, good — but the leg won't run). See §4.
- Adding an input changes the EA's parameter surface; Q08 8.5-neighborhood and set-file
  parameter-identity checks must be re-confirmed for the three edited EAs (survivor purity).

### Option B — per-EA source edit hardcoding a literal cap (e.g. `QM_FrameworkSetRiskCapPct(4.0)`)

Risks: bakes risk into the binary, invisible to the set file and the deploy manifest;
different accounts/leverages need different binaries; breaks "set file is the single source
of the risk block"; drifts from survivor purity and from the auditable Round25 pattern.
**Reject.**

### Option C — framework-level policy (raise the default, or auto-derive cap from RISK_PERCENT)

E.g. `QM_FrameworkInit` sets `cap_pct = max(1.0, RISK_PERCENT)`, or removes the PERCENT
clamp. Risks: fleet-wide blast radius — changes sizing semantics for all ~3,300 EA source
dirs and invalidates the sizing assumptions behind every gate's committed evidence;
silently un-caps the entire DXZ live book; defeats the safety rail whose whole purpose is
to stop a runaway percent value. This is a hard-bounded framework change — only via an
explicit OWNER decision, never as a campaign expedient. **Reject for this need.**

**Recommendation:** Option A. 10848 = set-file only; 13213/10553/13036 = adopt the exact
Round25 input+call, recompile through the build lane, pin+SHA256 the deployed `.ex5`. Cap
every leg at ≤5.0. Re-size the two 8× legs (§4). Confirm the opt-in worked by asserting
`RISK_CAP_OVERRIDE` at init **and** absence of `per_trade_cap` `RISK_CLAMP` during the
demo run.

---

## 4. What the campaign's deployable leverage actually is today

- **Today, as committed, all four legs deploy at 1× the backtest (1% of equity per
  trade).** The manifest's 4/4/8/8 (`2026-07-27_ftmo_challenge_deploy_manifest.json`) is
  *not* what the framework will size. None of the four set files sets `qm_risk_cap_pct`,
  and three of the four EAs (13213, 10553, 13036) cannot read it at all; the fourth
  (10848) runs its default 1.0. Every leg is silently clamped to 1.0% by
  `QM_Common.mqh:182` → `QM_RiskSizerRiskMoney` (`QM_RiskSizer.mqh:111–115`).
- **The measured 86.3% P(pass) does not describe the deployable book.** That figure is
  computed at 4×/8×; at the deployed 1× the book trades at backtest size, with sprint
  odds far below target. Deploying the current artifacts to demo would test the *wrong*
  book — and (usefully) would emit a `per_trade_cap` `RISK_CLAMP` on every entry, making
  the discrepancy self-evident in the logs.
- **Ceiling reality after a fix:** the maximum any leg can reach is **5×**
  (`QM_Common.mqh:319`, OWNER-ratified, tied to the FTMO daily-loss limit — not to be
  raised). So 13213 and 10848 (4×) are reachable via Option A; **10553 and 13036 (8×) are
  not** — they must be re-sized to ≤5× or the book's risk budget re-derived and the joint
  simulation re-run at the achievable leverages before any demo deploy.

---

## Evidence index

- `framework/include/QM/QM_Common.mqh:179–182` (cap set), `:315–330` (override, ceiling 5.0)
- `framework/include/QM/QM_RiskSizer.mqh:68–71, 84–89, 91–117` (clamp math), `:73–79` (silent NoteClamp)
- `framework/include/QM/QM_Entry.mqh:287, 311–322` (RISK_CLAMP emit — the only trail)
- `framework/EAs/QM5_10848_tv-mtf-ambush/QM5_10848_tv-mtf-ambush.mq5:53, 474` (input present, default 1.0)
- `framework/EAs/QM5_10128_bb-breakout/QM5_10128_bb-breakout.mq5:153–175` (campaign-class EA, no override call)
- `framework/EAs/QM5_{13213,10553,13036,10848}_*/sets/*_ftmo_challenge.set` (RISK_PERCENT 4/4/8/8, no qm_risk_cap_pct)
- `docs/ops/evidence/2026-07-27_ftmo_challenge_deploy_manifest.json` (book + intended leverage)
- `D:\QM\reports\debug\ftmo_entry_recovery\...\logger_sample.jsonl` (244× `entry_margin_cap`, 0× `per_trade_cap`)
- FTMO live logs `...\81A933A9AFC5DE3C23B15CAB19C63850\MQL5\Files\QM\` (`RISK_CAP_OVERRIDE` on Round25 legs; 0× `per_trade_cap`)
- `decisions/2026-07-05_ftmo_round25_phase1_deploy.md:43–56, 87–95` (override provenance + deploy-revert hazard)
- `docs/research/FTMO_MULTI_ACCOUNT_CAMPAIGN_2026-07-26.md` (86.3% measurement basis)
