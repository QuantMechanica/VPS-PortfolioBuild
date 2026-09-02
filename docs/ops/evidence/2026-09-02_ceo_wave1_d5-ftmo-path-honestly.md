# D5 — FTMO Path, Honestly (CEO audit, 2026-09-02)

Author: claude-headless (board-advisor lane). Read-only. Every number below is file/DB-evidenced.

## TL;DR for the buy/no-buy decision

**No-buy today.** A positive-EV challenge purchase is **not supportable on current evidence**, for one
decisive reason that survives every modeling choice: the only out-of-sample data we have — ~40 days of
live DXZ trading — realized a **negative** Sharpe (~-3.25, task-stated; corroborated by the live book
sitting below its high-water mark, equity 99,204.86 vs HWM 101,871.44, DD 2.62%, and the Vault's "only
10 of 24 EAs traded in 7 days, P&L stagnant"). Under a negative-Sharpe book the probability of reaching
+10% before -10% is ~2-6% and the break-even challenge fee collapses to ≈ $0. The historical "+2.4
Sharpe" case that makes the challenge look positive-EV is exactly the case the live draw has already
contradicted. You cannot pass a +10% target with a book that is currently bleeding.

A second finding blocks the analysis independently: **the sealed EV evidence no longer reproduces.** The
audit scripts read a *mutable* stream directory that has since shrunk from 21 sleeves to 5, and
`audit_ev_funded_account.py` has no anchor guard, so it silently reports numbers on a 5-sleeve book. The
`EV_FUNDED_ACCOUNT.md` headline (break-even fee $15k-26k at 0.50×) is stale by an order of magnitude.

---

## (1) Rulepack diff — `FTMO_2S_100K_SWING_V1.json` vs current FTMO rules (2026)

Current rules verified against the official page (`https://ftmo.com/en/trading-objectives/`, WebFetch
2026-09-02) and the in-repo snapshot `docs/ops/evidence/2026-07-29_ftmo_official_rules_snapshot.json`;
pricing/refund via web search (propfirmkey, jptradingcapital, ftmo.com how-it-works, Sep-2026).

### What the rulepack gets RIGHT (confirmed unchanged)
- Phase-1 target 10% / Verification 5% (`official_rules[ftmo_2s_phase1_profit_target/…verification…]`).
- Max daily loss 5% of initial, Prague midnight balance anchor, equity incl. open PnL/swap/commission
  (`ftmo_2s_max_daily_loss`). ✔ matches current.
- Max loss 10% **static** from initial (floor $90,000), not trailing (`ftmo_2s_maximum_loss`). ✔
- Minimum 4 trading days per phase, qualifier = position **opened** (`ftmo_2s_minimum_trading_days`). ✔
- **No time limit** on the 2-step evaluation (`ftmo_2s_no_time_limit`). ✔ (The `decisions/2026-07-26…`
  doc and older memory still speak of a "60-day P1 / 30-day P2" deadline — that is an *internal QM speed
  doctrine / modeling window*, NOT an FTMO rule. The rulepack is correct; the doctrine docs are the ones
  that read as if FTMO imposes a clock.)
- Swing: news restriction not applicable, weekend/overnight not restricted (`ftmo_swing_news`,
  `ftmo_swing_weekend`). ✔
- EA limits 200 simultaneous orders / 2000 positions-per-day / hyperactive >2000 req/day
  (`ftmo_ea_server_limits`). ✔

### Fields the rulepack LACKS or under-specifies (ranked by decision impact)

| # | Gap | Current FTMO fact | Why it matters | Severity |
|---|-----|-------------------|----------------|----------|
| 1 | **No challenge fee/price field** | $100k 2-step = **$540** | The whole EV analysis is expressed as a "break-even fee" *because the fee is nowhere in the repo* (rulepack `fee_note`, script docstring). With price absent, EV is undecidable by construction. | HIGH |
| 2 | **No fee-refund rule** | FTMO refunds **100% of the evaluation fee** with the first payout | Flips EV: effective fee ≈ $0 *conditional on reaching a first payout*. The audit ignores it entirely → break-even fees are understated as a hurdle. | HIGH |
| 3 | **Profit split hardcoded 80%, no ladder** | 80% base, **up to 90%** (and 90% under Scaling Plan — rulepack's own note) | `audit_ev PAYOUT_SHARE=0.80`. Understates funded-account value 12.5%. | MEDIUM |
| 4 | **No Swing leverage field** | Swing = **1:30 FX, 1:15 metals/oil** (07-30 snapshot `leverageSwing`) vs 1:100/1:50 standard | Halves sizing headroom on the gold/oil-heavy book — a hard constraint on whether the current book can even be expressed on Swing. | MEDIUM |
| 5 | **No scaling plan** | +25% allocation / 4 months on profitable accounts, split → 90% | Materially changes the funded-account survival value the EV rests on. | MEDIUM |
| 6 | **No payout cadence field** | On-demand, first at ~14 days, then flexible (bi-weekly default) | Gates the fee-refund timing (#2) and the funded-model withdrawal cadence (audit assumes rigid 60-day withdrawal — a modeling choice, not FTMO's). | LOW |
| 7 | **$400k per-trader/strategy allocation cap** | Documented in `challenge_book_60d.py` docstring, NOT a rulepack field | Binds multi-account campaigns. | LOW |
| 8 | **Freshness stale** | Snapshot `as_of 2026-07-29`; go-criterion `ftmo_rule_snapshot_fresh` demands ≤7 days | Today is 35 days stale → any purchase requires a fresh re-hash first (this is a binding process gate, not a content error). | HIGH (process) |
| 9 | **Non-swing news restriction not recorded** | Standard accounts: no open/close within 2 min of high-impact news | Rulepack is Swing-scoped so OK, but the account-type choice should be explicit since it is the reason news is unrestricted. | LOW |

**Bottom line on (1):** the rulepack's *rule facts* are accurate and current; its **economic fields
(price, fee-refund, split ladder, scaling, leverage) are missing**, and those are exactly the fields a
buy/no-buy decision needs. Add them before the EV question can even be posed cleanly.

---

## (2) Barrier math — P(pass) under three regimes

The binding constraint is first-passage: **P(reach +10% before -10% static, never breaching -5%
daily)**, chained P1→P2. I recomputed it on the **sealed** `dxz_final_20260719` streams (24 jsonl,
schema `time`/`net`/`mae_acct`), rebuilt directly rather than through the mutable engine (see finding
below). Script: `scratchpad/wave1/ev_sealed.py`. Sealed book reconstructed = 24 sleeves, 2028 trading
days, span 3004d, 50 non-overlapping 60-day windows; worst close-day -6.21%, worst MAE-floor day -7.93%.

Three regimes (σ held constant, drift shifted to hit the target annualized Sharpe):
- **modeled** — streams as-is, annualized Sharpe **+2.13** (the historical case; the sealed-book number
  the whole FTMO program is built on).
- **live-consistent** — mean-shifted to Sharpe **-3.25** (the realized 40-day live draw, treated as a
  pessimistic draw per task).
- **mixture** — per-attempt 50/50 of the two (probabilities and payouts averaged).

Break-even fee = mean payout per attempt ÷ E[attempts-to-funded], payout split 80%, profit withdrawn
every 60d (conservative — retained profit would lengthen survival).

### At 0.50× sizing (rev6-recommended low sizing)

| basis | regime | P1 | P2\|P1 | funded | E[att]→funded | payout mean | **break-even fee** |
|---|---|---:|---:|---:|---:|---:|---:|
| close | modeled | 30% | 40% | 12% | 8.3 | $77,547 | **$9,306** |
| close | live | 2% | — | 0% | ∞ | $176 | **~$0** |
| close | mixture | 16% | — | 6% | 16.7 | $38,862 | **$2,332** |
| overlap-floor | modeled | 30% | 40% | 12% | 8.3 | $62,091 | **$7,451** |
| overlap-floor | live | 2% | — | 0% | ∞ | $173 | **~$0** |
| overlap-floor | mixture | 16% | — | 6% | 16.7 | $31,132 | **$1,868** |

### At 1.00× sizing

| basis | regime | P1 | P2\|P1 | funded | E[att]→funded | payout mean | **break-even fee** |
|---|---|---:|---:|---:|---:|---:|---:|
| close | modeled | 68% | 59% | 40% | 2.5 | $42,495 | **$16,998** |
| close | live | 6% | — | 0% | ∞ | $250 | **~$0** |
| close | mixture | 37% | — | 20% | 5.0 | $21,373 | **$4,275** |
| overlap-floor | modeled | 56% | 64% | 36% | 2.8 | $21,509 | **$7,743** |
| overlap-floor | live | 4% | — | 0% | ∞ | $0 | **~$0** |
| overlap-floor | mixture | 30% | — | 18% | 5.6 | $10,755 | **$1,936** |

### EV range and interpretation

- **Modeled regime:** break-even fee $7,451–$16,998. At a $540 fee this is **strongly positive-EV**
  (EV per attempt ≈ payout×P − fee ≫ 0; with fee-refund #2 it is more so).
- **Live-consistent regime:** P1 ~2–6%, funded ~0%, payout ≈ $0 → break-even ≈ $0. **EV = −$540 per
  attempt.** Catastrophic; you fund essentially never and lose the fee every time.
- **Mixture:** break-even $1,868–$4,275, nominally still > $540. **But this only looks positive because
  it puts 50% weight on the modeled regime the live data already refutes.**

**EV envelope, per paid attempt, at $540 fee:**
- optimistic (modeled true): ≈ **+$4,600 to +$16,500** (payout×P_funded − fee)
- pessimistic (live true): ≈ **−$540**
- 50/50 mixture: ≈ **+$1,300 to +$3,700**

**Is a positive-EV purchase supportable today? NO.** Three reasons:
1. The positive EV is entirely carried by the modeled regime, and the **live book is the actual draw** —
   40 days at negative realized Sharpe is the live-consistent, not the modeled, case. A Bayesian update
   after 40 days of −3.25 Sharpe should down-weight the modeled regime well below 50%, pushing the
   mixture EV toward −$540.
2. The rulepack's **own go-criteria fail**: `ftmo_phase1_probability_gate` requires point ≥80% and
   lower-95% ≥70%; even the *modeled* case is 30% (0.50×) / 56–68% (1.00×). Not close.
   `ftmo_free_trial_gate` requires ≥1 clean exact-profile trial — the free-trial task
   `QM_FTMO_TrialPulse` currently dies on its time limit every run (silent-failure FAIL), so that gate
   is not even measurable.
3. The **modeled evidence itself is no longer reproducible** (next finding). You would be buying on a
   number you can't regenerate.

**Contrarian note (welcome per instructions):** the EV_FUNDED_ACCOUNT.md conclusion — "low sizing
0.50× is where EV is maximal and the two measurement bases agree" — is *directionally sound and worth
preserving*: at 0.50× the close and MAE-floor break-even fees are within ~20% of each other ($9,306 vs
$7,451), whereas at 1.00× they diverge 2× ($16,998 vs $7,743). Low sizing is the robust choice **if you
ever buy**. But "which sizing" is a second-order question; "is the book positive-Sharpe out of sample"
is the first-order one, and today it is not.

### FINDING D5-A (CRITICAL, evidence integrity): sealed EV no longer reproduces
- `audit_intraday_sizing_sweep.py --selftest` → `reproduced: False`. The engine
  `challenge_book_60d.py` reads `STREAMS = D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades`
  (line ~78), a **mutable live dir now holding 45 files but resolving to only 5 sleeves / 1826 trading
  days** (was 21 sleeves / 2128 days). Selftest mismatch: sleeves expected 21 got **5**; worst_close
  expected -6.95% got -4.27%; days≤-5% expected 20 got **0**.
- `audit_ev_funded_account.py` has **no anchor guard** and silently produced a 5-sleeve result today:
  0.50× close P1 20% / break-even **$1,591** — vs the sealed 2026-08-19 artifact
  (`artifacts/audit_ev_funded_account_20260819.json`) 0.50× close P1 **56%** / break-even **$26,253**.
  The published `docs/ops/EV_FUNDED_ACCOUNT.md` headline ($15k-26k break-even at 0.50×) is stale by an
  order of magnitude.
- Impact: any FTMO decision citing EV_FUNDED_ACCOUNT.md or re-running the audit script gets numbers off
  by ~16× at the recommended sizing, with no warning. The scripts that DO have guards refuse to report;
  the money-relevant one does not.
- Fix (codex, ~2h, GREEN): point the audit scripts at the **sealed** `dxz_final_20260719` path (or a
  content-hashed frozen copy), add the same anchor/fingerprint selftest guard used by the sweep so the
  EV script refuses to report on a drifted stream. Then re-run the EV series for the record.

---

## (3) Atomic pre-trade daily-loss budgeter — design (no code)

Rulepack `deployment_boundary.runtime_integration = NOT_IMPLEMENTED`. The framework already has most of
the scaffolding; the missing piece is a narrow, well-defined one.

**What already exists (grep evidence):**
- `framework/include/QM/QM_FTMOGovernorPolicy.mqh` — per-phase policy with `official_daily_loss=5000`,
  `QM_FTMO_Floors(midnight_balance,…)` computing `official_daily_floor = midnight_balance − 5000`, plus
  internal `entry_daily_stop` / `liquidation_daily_stop` / `internal_total_floor`, keyed on
  `prague_day_key`. **The FTMO daily anchor is already correctly modeled** = the Prague (Europe/Prague)
  CE(S)T midnight *balance*, minus the fixed $5,000, tested against equity incl. open PnL/swap/comm.
- `framework/include/QM/QM_FTMOGovernorClient.mqh` — a cross-EA coordination channel over **MT5
  GlobalVariables** with a per-account `entry_lock` key, a `day_key` (Prague day), `generation`,
  `ready`, `heartbeat`, `scale` keys. This is the shared-state substrate a budgeter needs.
- `framework/include/QM/QM_PropFirm.mqh` — prop-phase awareness + flatten-at-target, and
  `prop_anchor_risk_to_start` (size off the immutable start balance). **BUT** it logs
  `prop_anchor_not_wired` / `"risk_anchor_wired":false` (lines 461-470): the anchor is telemetry only,
  **not wired to the entry sizing path**. This is the concrete "NOT_IMPLEMENTED".

**Where the reservation lives:** in the EA's pre-trade path, immediately before `OrderSend`/`trade.*`,
inside `QM_PropEntryAllowed()` (QM_PropFirm.mqh) — the existing entry gate — extended with a *reservation
step* that talks to the shared GlobalVariable ledger through the existing `entry_lock`.

**The atomic reservation protocol (concurrent sleeves on one FTMO account):**
1. **Daily anchor:** on each new Prague day (`QM_FTMO_PragueDayKey`), the governor publishes
   `midnight_balance` and derives the day's **internal daily budget** `B_day = 0.03 × 100000 = $3,000`
   (rulepack `qm_ftmo_projected_daily_loss_budget`, 3% with a 2-pt buffer to the official 5%). Reset the
   shared `committed_open_stop_risk` counter to the sum of stop-risk of still-open positions (not zero —
   overnight positions carry their reservation across the anchor).
2. **Pre-trade reservation (atomic CAS):** before sending, the sleeve computes its planned stop-loss in
   account $ (`lots × stop_distance × tick_value` = the same quantity RISK_FIXED already sizes to).
   Acquire `entry_lock` via `GlobalVariableSetOnCondition` (MT5's compare-and-set — the only atomic
   primitive in the platform; spin with a short deadline, fail-closed to "no entry" on timeout). Under
   the lock: read `committed_open_stop_risk` + realized-day-loss-so-far; if
   `realized_day_loss + committed + this_stop_risk ≤ B_day` **and** the total-DD budget
   `qm_ftmo_total_drawdown_budget (7%)` and the per-trade (1%), cluster (1.5%), book (2.5%) caps all
   hold, then **add this_stop_risk to `committed_open_stop_risk`** and release the lock; else release and
   **refuse the entry** (log `prop_budget_refused`). The add-then-send order guarantees no two concurrent
   sleeves can both pass a check that only one budget slot allows — the reservation is committed *before*
   the order exists.
3. **Release:** on position close (or SL/TP fill), atomically subtract that position's reserved
   stop-risk from `committed_open_stop_risk` under the lock. Trailing stops that *reduce* risk may
   lower the reservation; never raise it without a fresh check.
4. **Correlated-cluster accounting:** reservations are tagged by a cluster id (symbol × mechanic) so the
   1.5% cluster cap (`qm_ftmo_correlated_cluster_risk`) is enforced on the *sum* — several magic numbers
   can be one economic trade (rulepack rationale).
5. **Crash safety:** GlobalVariables persist in the terminal; on EA re-init, rebuild
   `committed_open_stop_risk` by scanning open positions (each carries its SL) rather than trusting a
   possibly-stale counter — mirrors the existing `prop_anchor` restart concern (QM_PropFirm.mqh:353).
6. **Midnight entry freeze:** block new reservations 23:50–00:10 Prague (rulepack
   `qm_ftmo_midnight_entry_window`) so the anchor flip is unambiguous; management/close continues.

**FTMO daily anchor, stated precisely:** the loss limit is `equity < midnight_balance − $5,000`, where
`midnight_balance` is the account *balance* (not equity) at 00:00:00 Europe/Prague, and equity includes
open PnL, swap, and commission. The budgeter's internal floor sits $2,000 above that (3% not 5%). This
is exactly what `QM_FTMO_Floors` already computes; the budgeter's *new* work is only the atomic
*reservation of not-yet-realized stop risk* across concurrent sleeves — the one thing GlobalVariable
telemetry does today (read floors) that it does NOT do (reserve forward risk atomically).

**Scope/authority:** design only. Wiring it touches EA runtime → ROT-adjacent (requires a new reviewed
rulepack version + OWNER authorization per `deployment_boundary`). It does not toggle AutoTrading.

---

## (4) Swing swap-compatibility of the live book

Cost source: FTMO 07-30 symbol snapshot `docs/ops/evidence/2026-07-30_ftmo_book3_symbol_cost_snapshot.json`
(only **3 symbols normalized** — a documented GAP for the rest) plus the whole-book swap reconciliation
`D:/QM/reports/ultracode_20260726/wsd2/wsd_whole_book_swap.md` (per-sleeve overnight count `O/N` and
`Lot-nights` exposure) and `decisions/2026-07-26_ftmo_trial_deferral_and_swap_scenario.md`.

FTMO Swing overnight swaps (points, 07-30 snapshot):
- **USD/JPY** swapLong **+0.92** (positive), swapShort −19.78; leverageSwing 30.
- **USOIL/XTIUSD** swapLong **+4.22** (positive), swapShort −26.8; leverageSwing 15.
- **XAU/USD** swapLong **−66.21** (brutal), swapShort −23.55; leverageSwing 15.

### Swing-COMPATIBLE (swap-immune, light, or positive-carry)
| Sleeve | O/N | Lot-nights | Basis | Verdict |
|---|---:|---:|---|---|
| **13213/USDJPY** | 0 | 0.0 | intraday-flat → swap-immune | BEST |
| **13301/GDAXI** | 1 | 2.4 | effectively intraday-flat | immune |
| **10919/XTIUSD** | 14 | 13.6 | FTMO oil long +4.22, light exposure | compatible |
| **12969/USDJPY** | 329 | 519.0 | strongly **positive carry** (embedded +$3,018; FTMO JPY long +0.92) | compatible despite high exposure |
| **11708/EURUSD** | 128 | 192.0 | mild **positive** embedded carry (+$307) | compatible |
| 12567/XNGUSD | 51 | 37.9 | nat-gas, no FTMO snapshot (GAP) | likely light |

### Swing-HOSTILE (swap cost center — the bulk of the book)
| Sleeve | O/N | Lot-nights | Why |
|---|---:|---:|---|
| **10403/XAUUSD** | 180 | 180.7 | gold long × FTMO −66.21 pts/night — dominant single cost |
| 10513/XAUUSD | 79 | 84.3 | gold long |
| 1556/XAUUSD | 46 | 30.2 | gold long |
| 12989/XAUUSD | 29 | 47.2 | gold long |
| 12567/XAUUSD | 61 | 36.9 | gold long |
| **11422/USDCAD** | 157 | 959.0 | largest lot-night exposure in book (no FTMO snapshot; likely negative carry) |
| **10706/GBPUSD** | 135 | 840.9 | very high exposure |
| 10911/GDAXI | 113 | 147.7 | index, embedded −$1,699 |
| 11132/SP500 | 59 | 134.5 | index, embedded −$1,002 |
| 13128/NDX | 57 | 14.3 | index, embedded −$472 |

**Book-level:** the DXZ live book is **gold-long- and index-heavy → net swap-hostile for a Swing
account.** `wsd_whole_book_swap.md` measures overnight exposure `book_weighted_lot_nights ≈ 1,341`
(FINAL24b); at an illustrative −$5/lot/night that is **−$6,704 ≈ 7.5% of book net**, and FTMO's actual
gold-long swap (−66 pts) is far worse than −$5 on the gold legs. The 07-26 current-rate capture already
found the drag is dominated by **gold long (−58.6 pts/night)** and XTIUSD, with **USDJPY the one
positive carry** — i.e. the same conclusion from live-account rates.

**Consequence for FTMO:** a Swing FTMO account holding this book overnight pays a swap tax on precisely
the sleeves (gold longs) that carry most of its edge, and Swing leverage on metals/oil is only 1:15.
The FTMO-viable subset is small: the two USDJPY sleeves, GDAXI-intraday (13301), oil (10919), and
EURUSD (11708) — a handful, not a diversified book. **A gold-light / positive-carry-weighted book is a
prerequisite** for FTMO Swing, and composing one is a separate piece of work from the current DXZ book.

---

## Minimal evidence package the OWNER needs for buy/no-buy

1. **This EV table** (regenerated on the sealed streams after D5-A is fixed) — showing modeled vs
   live-consistent vs mixture.
2. **A fresh FTMO rule + price snapshot** (≤7 days old — today's is 35d stale) with the missing economic
   fields (price $540, fee-refund, split ladder, leverage, scaling) added to the rulepack.
3. **One clean free-trial run** on the exact candidate binaries/sets — currently *impossible* because
   `QM_FTMO_TrialPulse` dies on its time limit every run (silent-failure FAIL). Fix that first.
4. **A positive out-of-sample live Sharpe** on the DXZ book (or an FTMO-viable sub-book) — the single
   condition that would move the mixture EV off −$540. The 40-day live draw is currently the opposite.
5. **The daily-loss budgeter implemented and free-trial-validated** (deliverable 3) — the rulepack's own
   `ftmo_free_trial_gate` requires zero operational defects, and an un-budgeted book breaches on the −5%
   daily before it ever reaches +10%.

## Recommendation
**NO-BUY.** Hold the OWNER FTMO park (OWNER-DEC-FTMO-PARK-UNTIL-25) — it is correct, but for a sharper
reason than "25 pairs": the book must first demonstrate a **positive realized out-of-sample Sharpe**.
Until then every regime that matters (the live one) prices the challenge at −$540/attempt. In the
meantime, three GREEN/low-cost items compound: (a) fix D5-A stream drift + add the anchor guard so EV is
trustworthy; (b) add the five economic fields to the rulepack; (c) fix the free-trial pulse task. None
spend money or touch T_Live.
