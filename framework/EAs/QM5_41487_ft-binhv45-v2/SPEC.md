# QM5_41487_ft-binhv45-v2 — Strategy Spec

**EA ID:** QM5_41487
**Slug:** `ft-binhv45-v2`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (freqtrade-strategies `BinHV45.py`)
**Author of this spec:** Claude
**Last revised:** 2026-09-22

---

## 0. Lineage — Second-Chance v2 of QM5_11211 (NEW lineage, M1 -> M5)

This is a **new lineage**, not a byte-exact clone, per the Strategy Second-Chance
Programme (`docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md` §5, Wave 2
style-supersession, revision task `f05399de-2945-4ab3-8006-896e5b150b3a`, APPROVED).
`QM5_11211` (`ft-binhv45`) was retired 2026-08-21 by OWNER-approved D1 disposition
(action=RETIRE only; `docs/ops/evidence/2026-08-21_ea_id_disposition_963.csv`); its
original card was rejected at G0 on 2026-05-23 under the superseded §17 scalping
doctrine ("M1 entry requires closedelta > close*17/1000 ... implausible to support
>=2 trades/year/symbol"), and **the EA was never built** — no `framework/EAs/QM5_11211*`
source exists anywhere in this repo's history (verified: `git log --all
--diff-filter=A -- '*11211*'` returns no EA-source hits, only card/evidence docs), so
this task implements from the approved card rather than cloning a parent source, per
the task SOP's "clone ... byte-exact if present (else implement from the card)".

To comply with the active Edge Lab charter design box (M5-M15 scalping only, no
sub-minute HFT), the retest adapts execution from the original raw-M1 freqtrade
strategy to **M5**. Everything else (Bollinger(40,2) capitulation-drop mechanism,
long-only, no sell signal) is a direct mechanisation of the public source.

---

## 1. Strategy Logic

BinHV45 capitulation-drop reversal. On each new M5 bar the EA reads the last
closed bar (shift 1 for the Bollinger/close reads, shift 2 for the prior close):
Bollinger Bands(40, 2) on M5 Close give `mid`/`lower`; `bbdelta = |mid-lower|`,
`closedelta = |close[1]-close[2]|`, `tail = |close[1]-low[1]|`. A long fires when
(a) the band has expanded (`bbdelta > close[1] * bbdelta_per_mille/1000`), (b) the
bar moved fast (`closedelta > close[1] * closedelta_per_mille/1000`), (c) the lower
tail was small (`tail < bbdelta * tail_per_mille/1000`), (d) price pierced the
lower band (`close[1] < lower[1]`), and (e) the bar closed negative
(`close[1] <= close[2]`) — i.e. a sharp, low-wick capitulation drop through the
lower band. Entry is a market buy at the next bar's open. The source has no sell
signal (`exit_long=0`): the trade lives until the ROI target or the hard safety
stop fires, or the framework's Friday-close sweep flattens it. Long-only (no
short side in the source).

### TP/SL interpretation note (card ambiguity, resolved and documented per SOP)

The card states SL as an explicit `Min(1.5*ATR(14,M5), 0.05*entry_price)` (the
tighter/closer-to-entry of the two), but states TP as a parenthetical
`"+1.25% of price (or +1.5 * ATR(14, M5))"` without an explicit combinator. This
spec reads the TP the same way as the SL — **the tighter of the two distances**
(`Min(1.25%*entry, 1.5*ATR)`) — for two reasons: (1) internal consistency with the
card's own explicit SL formula, and (2) OWNER's conservative-fills doctrine for
execution-aware prescreens (`OWNER-DEC-FTMO-DUAL-TRACK-20260921`: "conservative
fills ... that avoid the harness-v1 fill fragility"). This is a judgment call, not
a silent guess — flagged here for Q02+ review; if OWNER/critique prefers the
looser (Max) combinator or a fixed 1.25% target ignoring ATR, that is a
`strategy_tp_pct` / `strategy_tp_atr_mult` parameter-only change, not a rebuild.
The card's Exit Logic prose also mentions "ATR trailing" in the same sentence as
ROI/hard-stop/weekend-close; no trailing formula or parameters are given anywhere
in the card (including the Codex Implementation Notes), so this is read as
descriptive of the ATR-derived hard stop, not a separate trailing-stop feature —
`Strategy_ManageOpenPosition()` is a no-op, matching the "no trailing" precedent
of the sibling Second-Chance build (QM5_41486).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 40 | fixed (card) | Bollinger Bands period |
| `strategy_bb_deviation` | 2.0 | fixed (card) | Bollinger Bands deviation |
| `strategy_bbdelta_per_mille` | 7.0 | fixed (card default) | Band-expansion threshold, ‰ of close |
| `strategy_closedelta_per_mille` | 17.0 | sweep `[3,7,17]` (card) | Bar-velocity threshold, ‰ of close |
| `strategy_tail_per_mille` | 25.0 | fixed (card default) | Minimal-lower-tail threshold, ‰ of bbdelta |
| `strategy_tp_pct` | 1.25 | fixed (card) | ROI target, % of entry price |
| `strategy_tp_atr_mult` | 1.5 | fixed (card) | ROI target ATR alternative, × ATR(14) |
| `strategy_atr_period` | 14 | fixed (card) | ATR period for TP/SL |
| `strategy_sl_atr_mult` | 1.5 | fixed (card) | SL ATR component, × ATR(14) |
| `strategy_sl_pct_cap` | 5.0 | fixed (card) | SL hard cap, % of entry |
| `strategy_spread_cap_pct_of_sl` | 6.0 | fixed (card) | Spread must be <= this % of the planned stop distance |

`closedelta_per_mille` is the only card-designated sweep parameter (Q07/Q13
parameter optimization); all others are card-fixed defaults.

---

## 3. Symbol Universe

**Designed for (per card):**
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX` — liquid FX majors; capitulation-drop
  dislocations rapidly absorbed by liquidity providers.
- `XAUUSD.DWX` — metal; same capitulation-absorption thesis, higher ATR scale
  (handled natively by the ATR-based TP/SL, no symbol-specific tuning needed).

**Explicitly NOT for:** anything outside the card's four target symbols —
no index CFDs, no crypto-adjacent instruments.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30-80 (card estimate); falsification floor 15/yr despite closedelta sweep` |
| Typical hold time | `minutes to hours (M5 scalp horizon, ROI/ATR-bounded)` |
| Expected drawdown profile | `~4.0% (card estimate); single-position cap + hard SL bound tail risk` |
| Regime preference | `mean-revert (sharp one-sided capitulation snapback)` |
| Win rate target (qualitative) | `moderate-high (tight ROI target vs. wider SL distance)` |

---

## 6. Source Citation

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** `external open-source strategy repository`
**Pointer:** `BinHV45.py`, `freqtrade-strategies` (GitHub),
`user_data/strategies/berlinguyinca/BinHV45.py`, commit
`dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4`.
**R1-R4 verdict (G0):** R1-R4 PASS per
`artifacts/cards_approved/QM5_41487_ft-binhv45-v2.md` (G0 APPROVED 2026-09-21,
OWNER-DEC-FTMO-FULL-THROTTLE-20260921 Track C RUN_NOW; OWNER-DEC-D3-20260915
Second-Chance).

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4, Build Guardrail) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (card: 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## 8. Identity & Registry

| Field | Value |
|---|---|
| `qm_ea_id` | 41487 |
| Magic (EURUSD.DWX, slot 0) | 414870000 |
| Magic (GBPUSD.DWX, slot 1) | 414870001 |
| Magic (USDJPY.DWX, slot 2) | 414870002 |
| Magic (XAUUSD.DWX, slot 3) | 414870003 |
| Registry commit | `6ff6c70c94` (governed allocator, resolver regenerated) |
| Parent (reference only, never built, never reopened) | `QM5_11211_ft-binhv45` (retired 2026-08-21) |

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 (QM5_11211) | 2026-05-23 | G0 REJECTED (superseded §17 scalping doctrine, M1) | Never built; 0 work items, 0 metrics |
| v2 (this EA, QM5_41487) | 2026-09-22 | Second-Chance new-lineage rerun of QM5_11211 on M5 (task `6ae8518a-975b-4c0f-bb92-09e4cd36713b`) | Implemented from card (no parent source existed); M1->M5 per Edge Lab charter design box |
