# Antigravity FTMO-Compliance and Failure-Mode Critique: Sunday 2026-09-27 Go/No-Go Gate

- **Ticket ID:** `cb0eb674-2a22-4ccf-a88e-a40a78cf391a` (task8: `cb0eb674`)
- **Author:** Gemini (Antigravity CLI / Cross-Provider Independent Critique)
- **Authority:** `OWNER-DEC-FTMO-FINAL-MEGA-20260921` (§N, §Q, §R, §28, §77)
- **Target Deliverable:** `docs/ops/evidence/2026-09-21_ftmo_final_mega_prompt/agy_sunday_gonogo_critique_cb0eb674.md`
- **Execution Mode:** Read-only analysis; no MT5 terminal, demo account, or T_Live interaction.
- **Evaluation Timestamp:** 2026-09-21T19:22:30Z (Local: 2026-09-21T21:22:30+02:00)

---

## Executive Summary & Verdicts

| Question | Topic | Verdict | Key Finding |
|---|---|---|---|
| **Q1** | FTMO Rules vs `d6189118` Specification | **CONFIRMED WITH MODIFICATIONS** | Official 2-Step rule confirmed via live fetch (2026-09-21T19:21:58Z). `d6189118` models the 00:00 CE(S)T boundary and DST divergence correctly, but must explicitly resolve the semantic difference between official midnight balance and the internal `max(balance, equity)` cushion. |
| **Q2** | Sunday Launch Failure Modes | **12 MODES ANALYZED (4 UNCOVERED)** | Evaluated 12 critical structural failure modes. 8 are covered by the current checklist and `94a15624`, but 4 critical modes are uncovered or under-specified: Live news feed source verification, preflight server-request throttling, MT5 terminal global AutoTrading flag verification, and holiday/low-tick rollover handling. |
| **Q3** | Demo-Day Classification Rules (`4505b206`) | **DISPUTED (REQUIRES SHARPER CRITERIA)** | Collector data alone is sufficient for boundary math, but "nearest approach to Daily-Loss guard" on an account level fails to detect sleeve-level localized stress or near-misses. A sharper multi-layer criterion is proposed. |
| **Q4** | Server-Request Compliance (§28) | **DISPUTED (THRESHOLD DANGEROUSLY HIGH)** | Book entries (13.37/14d) generate only ~10–20 server requests/day (~99% headroom vs FTMO's 2,000 limit). A monitoring threshold of 2,000 is ineffective because 2,000 is the external ban limit; warning must trigger at 200/day and circuit-breaker halt at 500/day. |
| **Q5** | Most Dangerous Item & Minimal Proof | **CONFIRMED: KILL-SWITCH ANCHOR / ROLLOVER** | Launching with the unaligned kill-switch anchor and TimeCurrent weekend freeze risks immediate catastrophic account forfeiture. Minimal clearing proof requires a 4-point verification chain (Compile receipt, runtime event proof, state-file readback, and midnight rollover event). |

---

## Question 1: Official FTMO Rules vs `d6189118` Specification

### 1.1 Live Rule Verification from Official FTMO Sources

Verified against official live FTMO pages on **2026-09-21T19:21:58Z**:
- **Source 1:** [FTMO Trading Objectives](https://ftmo.com/en/trading-objectives/) (HTTP 200, fetched live 2026-09-21T19:21:58Z)
- **Source 2:** [FTMO FAQ: Difference Between Balance and Equity](https://ftmo.com/en/faq/what-is-the-difference-between-balance-and-equity/) (HTTP 200, fetched live 2026-09-21T19:22:16Z)
- **Source 3:** Bound snapshot `docs/ftmo/FTMO_RULES_SNAPSHOT_2026-09-18.md`

#### Verbatim Official Rule Text (FTMO 100k 2-Step Standard)
> *"The Maximum Daily Loss rule establishes a limit (the Maximum Daily Loss Limit) below which your account equity (i.e., Balance + Open Positions P/L ± Swaps – Commissions) cannot drop. If the equity drops below this limit, the rule is considered violated.*  
> *The Maximum Daily Loss Limit is recalculated daily at 00:00 CE(S)T as the difference between:*  
> *- the **account balance** recorded at 00:00 CE(S)T of the current day and*  
> *- the **Maximum Daily Loss Amount**, which is **5%** of the Initial Simulated Capital.*  
> *On the first day of trading, the account balance used for this calculation is the Initial Simulated Capital.*  
> *This calculated limit remains in effect until the next recalculation at 00:00 CE(S)T of the following day.*  
> *This rule applies to both phases (FTMO Challenge and Verification) of the FTMO Challenge: 2-Step as well as the subsequent FTMO Account (2-Step)."*  
> — Source: [ftmo.com/en/trading-objectives/](https://ftmo.com/en/trading-objectives/)

#### Key Rule Comparisons & Snapshot Alignment
1. **Maximum Daily Loss:** Recalculated daily at 00:00 CE(S)T based on **balance** at midnight minus $5,000 (5% of $100,000 initial simulated capital). Tested continuously against live **equity**. Snapshot 2026-09-18 correctly mirrors this.
2. **Maximum Loss:** For the 2-Step Challenge, the rule is **static 10%** of initial capital ($10,000 max loss, floor at $90,000). *(Note: FTMO introduced a trailing Max Loss for its 1-Step product, but 2-Step Standard remains strictly static at $90,000, exactly as bound in snapshot row 22).*
3. **Minimum Trading Days:** 4 trading days per phase (a trading day is defined as a CE(S)T calendar day with at least one newly opened position).
4. **Leverage:** 1:100 on Forex, 1:50 on major indices, 1:30 on metals/commodities.
5. **Execution / Restrictions:** EAs and scalping allowed. No news trading or weekend holding restrictions during Challenge/Verification phases (restrictions apply only to funded Standard accounts).

### 1.2 Evaluation of `d6189118` Specification

The specification in router ticket `d6189118` addresses:
1. **Prague Day-Key Helper & DST Divergence:**
   - MetaTrader server clocks (such as FTMO-Demo at `ts_broker`) align to US market close (UTC+3 in summer, UTC+2 in winter).
   - In stable seasons (summer/winter), Europe/Prague is UTC+2 / UTC+1, resulting in a constant **-1 hour** offset from the trade server.
   - During the US/EU DST divergence windows (mid-to-late March and late October to early November), the US and EU clocks shift 1 to 3 weeks apart. During these windows, the offset is **-2 hours**.
   - `d6189118` Requirement 2 correctly mandates a deterministic day-key helper tested at boundaries for 2026-03-08..03-29 and 2026-10-25..11-01, forbidding a hard-coded `-1`. This is **SOUND AND REQUIRED**.
2. **Equity-vs-Balance Semantics:**
   - Official FTMO rule states: Baseline is `balance` at 00:00 CE(S)T.
   - Existing framework code (`QM_KillSwitch.mqh:124-131`) implements `g_qm_ks_anchor_use_max_be`, which uses `MathMax(AccountEquity, AccountBalance)`.
   - Critique: If floating P/L is positive at midnight, `MathMax` sets a higher baseline, creating a tighter (more conservative) daily drawdown limit for the EA. If floating P/L is negative, `MathMax` equals `Balance`, exactly matching FTMO.
   - `d6189118` Requirement 3 correctly requires encoding this as an explicit named enum mode (`FTMO_BALANCE_AT_MIDNIGHT` vs `MAX_BALANCE_EQUITY`) rather than an ambiguous boolean.

---

## Question 2: Failure-Mode Analysis of the Sunday Launch

We analyze 12 concrete failure modes that could cause the representative Demo generation (starting Sunday 2026-09-27) to begin structurally invalid.

| # | Failure Mode | Detection Mechanism | Operational Consequence | Status in Checklist / 94a15624 |
|---|---|---|---|---|
| **1** | **Wrong Day Anchor Mode** (Raw equity instead of Prague midnight balance) | `ftmo_trial_pulse.py` parses `ks_state` file `anchor_mode`; `sunday_preflight.py` row `ACCOUNT RISK` | EA daily breaker anchors to depleted equity or rolls at wrong time, allowing breach of official 5% limit. | **COVERED** (Checklist row 41, 94a15624 §3) |
| **2** | **Wrong Book Tag / Unscoped Signal** (Default `portfolio_dd.signal` path) | `ftmo_trial_pulse.py` scans `KS_BOOK_TAG_SET`; `sunday_preflight.py` checks file paths | Cross-talk between live books (DXZ halt halts FTMO demo or vice versa). | **COVERED** (Checklist row 41, 94a15624 §1, §3) |
| **3** | **Stale `.ex5` Binary** (Installed binary does not match rebuilt sources) | `genesis_manifest.py verify` recomputes SHA-256 of installed `.ex5` files against receipt | Running binary executes pre-fix code without Prague rollover logic. Burn-in invalid. | **COVERED** (Checklist row 40, 94a15624 §2) |
| **4** | **Setfile Parameter Drift** (Local `.set` values differ from canonical manifest) | `genesis_manifest.py verify` checks SHA-256 of active `.set` files | Sizing, stop loss, or indicator settings deviate from validated research package. | **COVERED** (Checklist row 40, 94a15624 §2) |
| **5** | **Magic Number Collision** (Two sleeves share a magic, or overlap with another book) | `sunday_preflight.py` row `CODE/ARTIFACT: magic registry clean` | Order attribution, position counts, and sleeve P&L completely corrupted. | **COVERED** (Checklist row 40, 94a15624 §3) |
| **6** | **Live News Source Pointing to Stale Archive** | **UNCOVERED IN PREFLIGHT** (Only backtest DST audit `a36a5983` is tracked) | EA either fails closed (`INIT_FAILED` due to expired calendar) or fails open, trading through high-impact news. | **UNCOVERED / GAP** |
| **7** | **Server-Request Hyperactivity / Spam Loop** | `ftmo_trial_pulse.py` counts `TM_*` events post-facto; **NO preflight check** | Broker detects >2,000 requests/day, automatically bans IP / terminates account. | **UNCOVERED IN PREFLIGHT** |
| **8** | **Weekend / Holiday Rollover Freeze** (`TimeCurrent` static over weekend) | Tested by `d6189118` Requirement 8 unit tests; `sunday_preflight.py` | Sunday market open restores Friday's stale anchor, distorting Day 1 limit by up to $33–$200+. | **PARTIALLY COVERED** (In `d6189118`, not in Sunday checklist) |
| **9** | **Terminal Restart Midday Erasing KS State** | `QM_KillSwitchSaveState()` / `RestoreState()` unit tests; pulse state monitor | Terminal reboot or crash grants a second full daily loss budget on the same calendar day. | **COVERED** (Checklist row 41) |
| **10** | **Partial Chart Attachment** (Only 4 or 5 of 6 charts loaded/active) | `ftmo_trial_pulse.py` checks `magics_seen == 6`; `sunday_preflight.py` post-attach row | Portfolio risk balance distorted (missing diversification/hedges, incorrect total risk). | **COVERED** (Checklist row 44, 94a15624 §3) |
| **11** | **Unclean Initial Demo State** (Pre-existing positions or non-100k balance) | `sunday_preflight.py` checks account history, open positions, balance == $100,000.00 | Account starting point is contaminated; metrics cannot be certified. | **COVERED** (Checklist row 44, 94a15624 §3) |
| **12** | **Terminal Global AutoTrading Disabled** | **NO automated preflight check** (Visual inspection only) | EAs attach with smiley 'X' icon; no trades execute; 14-day clock runs blank. | **UNCOVERED / GAP** |

---

## Question 3: Critique of Demo-Day Classification Rules (`4505b206`)

### 3.1 Decidability from Collector Data Alone
The telemetry collected in `trial_telemetry_raw.jsonl` contains:
- `ts_utc`, `ts_broker`, `prague_day_key`
- Account balance and equity at 1-minute intervals (including 21:00Z and 22:00Z boundaries)
- Open position tickets, floating P/L, swaps, and commissions

**Finding:** Collector data is **sufficient** to determine:
1. Exact Prague midnight balance and broker midnight equity.
2. Floating P/L and open positions across boundaries.
3. Actual persisted `day_start_equity` across all six `ks_state` files.

### 3.2 Critique of the "Nearest Approach to Daily-Loss Guard" Criterion
The ticket `4505b206` defines `POTENTIALLY_DIFFERENT` as:
> *"anchors differ or floating P/L existed at a boundary, but the difference could not have changed any trading decision because the day never came within X of the guard threshold - state X and the nearest approach."*

**Defects in the Current Criterion:**
1. **Account-Level vs Sleeve-Level Masking:** The six EAs each run an independent kill switch instance. Evaluating only account-level equity approach to -$3,000 ($97,000 floor) ignores whether an individual sleeve experienced localized drawdown that approached its sleeve-level per-trade or daily limit.
2. **Undefined Margin $X$:** The criterion fails to define the safety buffer $X$. If the anchor error was $\Delta = \$33.82$, an approach within $\$100$ might be within the noise floor of execution slippage.
3. **Position Sizing Feedback:** Even if the kill switch never halted trading, does the anchor error affect subsequent position sizing or lot calculation? For fixed-risk EAs, sizing derives from balance/equity; an anchor difference could alter lot sizes on subsequent days.

### 3.3 Proposed Sharper Classification Rule
A day is classified into one of three mutually exclusive states:
1. **`BEHAVIOR_IDENTICAL`:**
   - $|\text{Balance}_{\text{Prague}} - \text{Anchor}_{\text{Persisted}}| = \$0.00$, AND
   - Floating P/L at both 21:00Z and 22:00Z was exactly $\$0.00$, AND
   - No open positions spanned either boundary.
2. **`POTENTIALLY_DIFFERENT`:**
   - Boundary difference $\Delta = |\text{Balance}_{\text{Prague}} - \text{Anchor}_{\text{Persisted}}| > \$0.00$, BUT
   - Minimum intraday equity distance to internal halt:
     $$\min_{t} (\text{Equity}_t - \text{HaltThreshold}) \ge \max(10 \times \Delta, \$500.00)$$
   - Zero halt events occurred, and no sleeve-level drawdown exceeded 50% of its risk budget.
3. **`MATERIALLY_INVALID`:**
   - Minimum intraday equity distance to halt was $< 10 \times \Delta$ or $< \$500.00$, OR
   - Any halt or trade rejection occurred that would have evaluated differently under the true Prague anchor, OR
   - Telemetry boundary data is missing (e.g. collector started mid-day, as on 2026-09-18).

---

## Question 4: Server-Request Compliance Analysis (§28)

### 4.1 Daily Request Budget & Volume Estimation
FTMO Rule: Maximum 2,000 server requests per day (orders, modifications, cancellations). Exceeding this triggers automatic account suspension for hyperactivity.

From `FTMO_DEMO_ACCEPTANCE_CONTRACT_v1.md` §2.2:
- Roster D2g6 expected entries over 14 calendar days = **13.37 entries** (~0.95 entries/calendar day; ~1.34 entries/business day).
- Sleeve breakdown:
  - 13213 USDJPY: 0.74 entries/bd (breakout with bracket)
  - 10706 GBPUSD: 0.24 entries/bd
  - 10700 XAUUSD: 0.26 entries/bd
  - 10403 XAUUSD: 0.15 entries/bd
  - 11422 USDCAD: 0.14 entries/bd
  - 41219 XAUUSD: 0.06 entries/bd

**Server Requests Generated Per Entry:**
- Open: 1 request (`OrderSend` market order with SL/TP).
- Modifications: EAs in D2g6 operate on H1/D1 bars. Trailing stop or break-even logic modifies SL at most once per bar close. Average active trade duration is 1–3 days.
- Close: 0 client requests if closed by broker SL/TP hit; 1 request if closed by EA signal.
- **Estimated requests per trade:** Mean = 4 requests; Max = 12 requests.

**Daily Book Load:**
$$\text{Normal Daily Requests} = 1.34 \text{ trades/bd} \times 4 \text{ requests/trade} \approx 5.4 \text{ requests/day}$$
$$\text{P99 Peak Daily Requests} = 5 \text{ trades/day} \times 12 \text{ requests/trade} \approx 60 \text{ requests/day}$$

**Headroom:**
- Normal operating demand consumes **0.27%** of the 2,000 daily budget.
- Headroom exceeds **97%** (>1,940 requests) even during extreme multi-sleeve entry spikes.

### 4.2 Critique of the 2,000 Request Monitor Threshold
`ftmo_trial_pulse.py` sets:
```python
SERVER_REQUEST_WARN = 1500
SERVER_REQUEST_LIMIT = 2000
```

**CRITIQUE:**
Setting the monitor alert limit at **2,000 is dangerous and ineffective**:
1. **Zero Protection Against Broker Ban:** 2,000 is FTMO's external termination threshold. Triggering an alert at 2,000 notifies the operator *after* the account has already been flagged or banned.
2. **Abnormal Behavior Masked:** For a book that normally generates 10–50 requests/day, generating 1,000 requests indicates a catastrophic bug (e.g. an infinite `OrderModify` loop on tick). Waiting until 1,500 to warn allows a rogue EA to hammer the broker for thousands of cycles.

**Recommendation:**
- Set `SERVER_REQUEST_WARN = 200` (4x peak volume, detects looping immediately).
- Set `SERVER_REQUEST_LIMIT = 500` (leaves 1,500 requests of safety buffer before FTMO threshold).
- Add a rate-of-change burst breaker: alert if $>25$ requests occur within any 60-second window.

---

## Question 5: Single Most Dangerous Launch Item & Minimal Proof Chain

### 5.1 Identification
The **single most dangerous item** to launch without is:
> **The Kill-Switch Prague-Midnight Anchor & Non-Tick Rollover Engine (`d6189118`)**

**Rationale:**
FTMO's 5% Daily Loss rule ($5,000 limit) resets strictly at 00:00 CE(S)T.
As diagnosed in `4fd8222f` and `4505b206`:
1. The currently deployed aliases use `offset=0`, rolling at 21:00Z (broker midnight) instead of 22:00Z (Prague midnight). During that 1-hour window, an adverse market move could violate FTMO's daily limit while the EA believes it is operating on a fresh budget.
2. The deployed aliases rely on `TimeCurrent()` to advance the day key. Over weekends and market closures, `TimeCurrent()` freezes, causing Sunday restarts to restore a stale Friday anchor.
Launching the representative 14-day demo with this flaw guarantees that the burn-in evidence will be corrupted or invalidated at the first weekend rollover or overnight gap.

### 5.2 Minimal Proof Chain to Clear for Launch
To clear this item for Sunday launch, the following 4-point verification chain must be produced:

1. **Compilation & Binding Proof:**
   - Artifact: `docs/ops/evidence/2026-09-21_ftmo_ks_governed_initializer/RECEIPT_build_check.md`
   - Proof: All 6 EAs compile with 0 errors / 0 warnings against the governed `QM_FtmoInit` include, with explicit SHA-256 binary hash matching the installed `.ex5`.
2. **Runtime Configuration Event Proof:**
   - Artifact: Demo terminal EA log (`MQL5/Files/QM/QM5_*.log`)
   - Proof: During initialization, each EA emits:
     - `KS_DAY_ANCHOR_SET` with `offset_hours` matching Prague calendar (-1 in stable summer, -2 in DST divergence) and `use_max_balance_equity=true`.
     - `KS_BOOK_TAG_SET` with the explicit generation book tag (`FTMO_DEMO_BOOK_V3_...`).
3. **Persisted State File Readback Proof:**
   - Artifact: The six `MQL5/Files/QM/ks_state_*.txt` files.
   - Proof: Readback shows `day_key == current_prague_day`, `anchor_offset == -1`, `anchor_mode == 1`, and `day_start_equity == AccountBalance` at 22:00Z.
4. **Autonomous Rollover Proof:**
   - Artifact: Live EA logs at the subsequent 00:00 CE(S)T boundary.
   - Proof: Emission of `KS_DAY_ROLLOVER` proving day key transition and anchor refresh occurred at 00:00 Prague time, verified to work even without tick activity (via timer/wall-clock).

---

## Ranked Checklist Additions (Decidable One-Liners)

The following 6 concrete checklist checks must be added to `docs/ftmo/FTMO_SUNDAY_LAUNCH_STATUS.md` and `sunday_preflight.py`:

1. `[CRITICAL]` **CODE/EXECUTION: Live News Feed Binding** — Verify all 6 EAs point to the active daily news calendar (`D:/QM/data/news_calendar/` and `FILE_COMMON`) with mtime < 24h, and not a static historical backtest CSV.
2. `[CRITICAL]` **OPERATIONS: MT5 Terminal AutoTrading Flag** — Verify `TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) == 1` and EA chart property `trading_allowed == true` on all 6 charts before release.
3. `[CRITICAL]` **ACCOUNT RISK: Weekend Non-Tick Rollover Proof** — Verify `QM_KillSwitch` recomputes Prague day key using local wall-clock / OnTimer independently of `TimeCurrent()` upon Sunday restart.
4. `[HIGH]` **OPERATIONS: Server Request Anomaly Thresholds** — Set `SERVER_REQUEST_WARN = 200` and `SERVER_REQUEST_LIMIT = 500` in `ftmo_trial_pulse.py` with a 60-second burst alarm (>25 requests/min).
5. `[HIGH]` **ACCOUNT RISK: Clean Initial Demo Balance Verification** — Verify `AccountInfoDouble(ACCOUNT_BALANCE) == 100000.00`, `PositionsTotal() == 0`, and `OrdersTotal() == 0` immediately prior to chart attach.
6. `[MEDIUM]` **CODE/ARTIFACT: Sleeve P&L Attribution Pre-Launch Dry-Run** — Run `sleeve_attribution.py` against pre-launch state to verify reconciliation identity `Sum(Sleeve_PnL) == Account_PnL` holds to $0.00.
