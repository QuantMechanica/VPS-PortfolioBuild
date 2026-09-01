# QM5_41276_eurchf-franc-rev - Strategy Spec

**EA ID:** QM5_41276
**Slug:** `eurchf-franc-rev`
**Source:** `AI-CODEX-EURCHF-FRANC-REVERSAL-20260901`
**Author of this spec:** OpenAI Codex
**Last revised:** 2026-09-01

## 1. Strategy Logic

This EA implements a structural, long-only H4 reversal on exact symbol
`EURCHF.DWX`. On the first tick of each new H4 bar it reads 251 completed bars
once and caches all entry and strategy-exit state. Let C0 be the newest
completed close. Its forty-close z score is calculated against C1 through C40
with population deviation (divisor forty), so C0 never contaminates its own
reference sample. The longer range uses the closes C1 through C250.

A market BUY is eligible only when all three conditions are true:

1. the z score is strictly below -2.0;
2. C0 is at or below the lower ten percent boundary of the prior 250-close
   high-low range; and
3. C0 closes above both its own open and C1.

The initial structural stop is the signal low minus 0.25 signal-bar ATR. The
entry-stop distance is the larger of this structural distance and 1.25 ATR;
the signal is rejected when the result exceeds 2.50 ATR. A broker hard target
is placed 1.50 ATR above entry. The EA closes when a newly cached z score is
strictly above -0.50, after eighteen elapsed H4 periods, on the enabled Friday
sweep, or through the framework/broker safety lifecycle. It has no short side,
retry, averaging, scale-in, pyramid, grid, martingale, trail, break-even, or
partial close.

## 2. Parameters

The Q02 baseline is locked; there is no optimization surface.

| Parameter | Default | Status | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | H4 | locked | closed-bar strategy clock |
| `strategy_z_lookback` | 40 | locked | ex-current reference closes |
| `strategy_z_entry` | -2.0 | locked | strict long threshold |
| `strategy_z_exit` | -0.5 | locked | strict strategy-exit threshold |
| `strategy_range_lookback` | 250 | locked | ex-current close-range window |
| `strategy_lower_decile` | 0.10 | locked | lower range fraction |
| `strategy_atr_period` | 14 | locked | signal-bar ATR period |
| `strategy_swing_buffer_atr` | 0.25 | locked | buffer below signal low |
| `strategy_min_stop_atr` | 1.25 | locked | minimum entry-stop distance |
| `strategy_max_stop_atr` | 2.50 | locked | maximum admitted stop distance |
| `strategy_target_atr` | 1.50 | locked | hard-target distance |
| `strategy_max_hold_bars` | 18 | locked | elapsed H4 time stop |
| `strategy_max_spread_points` | 50 | locked | positive entry-spread ceiling |
| `strategy_deviation_points` | 20 | locked | framework execution tolerance |

The phase-controlled RNG seed, stress-rejection probability, and two news axes
remain framework inputs; they do not change the strategy formula.

## 3. Symbol Universe

**Designed for:** exact `EURCHF.DWX`, registry slot 0, magic `412760000`.

The build is single-symbol only. It must not be attached to another EURCHF
alias or transplanted to another CHF cross. The DarwinexZero symbol registry
contains native research history for `EURCHF.DWX`; no confirmed live-order
alias is asserted and this build authorizes no live action.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Host timeframe | H4 |
| Signal timeframe | H4 |
| Multi-timeframe reads | none |
| Decision timing | once per newly completed H4 bar |
| Raw history work | one bounded 251-bar `CopyRates` call per H4 advance |
| Per-tick work | MAE, kill switch, Friday close, elapsed-time exit, cached exit |

## 5. Expected Behaviour

This is an intentionally low-frequency, episodic CHF-stress rebound sleeve.
The ordering prior is about 12 to 25 completed positions per full post-warm-up
year, usually held from one H4 bar through three elapsed days. Q02 must retire
the sleeve if any full post-warm-up year has fewer than ten distinct entry
days, if economics are nonpositive, or if the mechanical fixtures disagree.

Persistent EURCHF repricing can cluster stop losses. A discontinuous CHF gap
can fill beyond the requested hard stop, so the specified stop distance is not
a realized-loss cap. Q04 owns walk-forward stability and downstream stress
gates own that tail; the diversity premise is not evidence of decorrelation.

## 6. Source Citation

The exact formula is an AI-originated governed source:

- **Source ID:** `AI-CODEX-EURCHF-FRANC-REVERSAL-20260901`
- **Source packet:**
  `strategy-seeds/sources/AI-CODEX-EURCHF-FRANC-REVERSAL-20260901/source.md`
- **Source approval:**
  `decisions/2026-09-01_eurchf_franc_strength_reversal_source_approval.md`
- **Approved execution contract:**
  `strategy-seeds/cards/approved/QM5_41276_eurchf-franc-rev_card.md`
- **Research-ticket lineage:**
  `docs/research/ORTHOGONAL_RETURN_SOURCES_PROGRAM_2026-08-13.md`, candidate 7
- **Official-source carrier lineage:** Grisse and Nitschka (2013), Swiss
  National Bank Working Paper 2013-04, through the complete local source
  packet `strategy-seeds/sources/EIA-SNB-XTI-USDCHF-RSPREAD-2026/source.md`

The official lineage supports only CHF safe-haven relevance. It does not
establish this rule, its direction, trade frequency, profitability, or a
permanent policy floor. Public-page retrieval was policy-deferred, and no
unretrieved paper result enters the mechanics. The approved card records the
bounded R1 verdict, deterministic R2 PASS, native-history R3 PASS, and
non-ML R4 PASS.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

Every entry is preflighted through `QM_LotsForRisk`; the V5 entry path performs
the authoritative sizing. The governed Q02 set fixes `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. News temporal mode defaults OFF,
compliance defaults NONE, and legacy news mode stays OFF. Friday close is
enabled at broker hour 21. Only one owned BUY may exist, with its hard stop and
target attached to the initial market request. The later rows describe the V5
convention only; this unit authorizes no portfolio-gate, deploy-manifest,
`T_Live`, or AutoTrading action.

## Revision History

| Version | Date | Reason | Evidence |
|---|---|---|---|
| v1 | 2026-09-01 | Initial governed EURCHF diversity build | build task `b80cad71-1ed5-428e-8e29-67d47196b21b` |
