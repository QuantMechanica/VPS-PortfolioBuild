---
ea_id: QM5_4001
slug: elite-multi-factor-scoring
artifact_type: zero_trade_rework_critique
trigger: DL-062_zero_trade_rework_trigger
router_task_id: da37f552-1b96-42f5-aef8-208c67d8efc4
parent_card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_4001_elite-multi-factor-scoring.md
author: claude
written_at: 2026-05-23
verdict: DEAD_CARD_MISSING_PIPELINE_SPEC_AND_STRUCTURAL_ENTRY_TOO_RESTRICTIVE
---

# QM5_4001 elite-multi-factor-scoring — zero-trade rework critique

Router fired DL-062 on `completed=30 / fail=30 / zero_trade=30 (zt_pct=1.0)` with
all 30 runs completing cleanly (no INFRA_FAIL, no INVALID). This is **different from
the other DL-062 false-positive batch**: 30 valid backtests all producing 0 trades
is a real result. However, the card is also critically underspecified — it lacks
mandatory pipeline frontmatter and a credible source — which means the zero-trade
result could reflect implementation gaps rather than strategy mortality.

## 1. Evidence sample

| symbol       | status | verdict | notes                          |
|--------------|--------|---------|--------------------------------|
| EURUSD.DWX   | done   | FAIL    | 0 trades, clean run            |
| GBPUSD.DWX   | done   | FAIL    | 0 trades, clean run (×3 runs)  |
| USDJPY.DWX   | done   | FAIL    | 0 trades, clean run (×3 runs)  |
| XAUUSD.DWX   | done   | FAIL    | 0 trades, clean run            |
| XTIUSD.DWX   | done   | FAIL    | 0 trades, clean run            |
| SP500.DWX    | done   | FAIL    | 0 trades, clean run            |
| NDX.DWX      | done   | FAIL    | 0 trades, clean run            |
| WS30.DWX     | done   | FAIL    | 0 trades, clean run            |
| GDAXI.DWX    | done   | FAIL    | 0 trades, clean run            |
| AUDJPY.DWX   | done   | FAIL    | 0 trades, clean run            |

30 unique runs, all `done/FAIL`, no INVALID, no INFRA_FAIL — the EA initializes
and runs to completion on every symbol/period combination but enters no trades.

## 2. Card status: critically underspecified

The card at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_4001_elite-multi-factor-scoring.md`
is missing all mandatory pipeline frontmatter:

```yaml
# Present in card:
ea_id: QM5_4001
name: The Multi-Factor Quant
priority: elite
trigger: MANUAL_ADVISOR
created_at: 2026-05-20

# MISSING mandatory fields:
g0_status: (absent — should be DRAFT or APPROVED)
r1_track_record: (absent)
r2_mechanical: (absent)
r3_data_available: (absent)
r4_ml_forbidden: (absent)
expected_trades_per_year_per_symbol: (absent)
target_symbols: (absent)
```

The card body contains only 7 lines of strategy description with no timeframe, no
position sizing, no risk parameters, no stop-loss, no exit logic beyond "Score <= 1",
no source citation, no universe declaration.

**This card should not be in `cards_approved/`**. A card in `cards_approved/` must
have completed G0 review per the strategy_card_schema in the router payloads
(`g0_status: APPROVED`, R1-R4 vetted). QM5_4001 has none of this. This is a process
failure — the card was placed in `cards_approved/` as a placeholder/experimental
entry before G0 vetting.

## 3. Structural entry condition analysis

The entry rule: **Long if Score >= 3** where the 4 factors are:
1. SMA(50) > SMA(200) — trend filter (bullish)
2. RSI(14) < 40 — oversold condition
3. ATR(14) > MA(ATR(14)) — expanding volatility
4. BarColor = Green — current bar close > open

`Score >= 3` means at least 3 of the 4 factors must be simultaneously true.

**The combinations that can produce Score=3:**

| Combination | Conditions | Market regime |
|-------------|-----------|---------------|
| {1,2,3} | SMA uptrend + oversold + expanding vol | Bullish trend with sharp selling |
| {1,2,4} | SMA uptrend + oversold + green bar | Buying-the-dip in uptrend |
| {1,3,4} | SMA uptrend + expanding vol + green bar | Normal trending upday |
| {2,3,4} | Oversold + expanding vol + green bar | Bear-trend dead-cat bounce |

Combination {1,3,4} — uptrend + high vol + green bar — is the most common and should
fire frequently on trending pairs (USDJPY 2024 uptrend, NDX 2024 uptrend). Yet USDJPY
and NDX both show 0 trades across multiple clean backtests.

This strongly suggests one of:
a) **Timeframe**: if the EA defaults to M15 or M5, SMA(50) on M15 changes character
   (1-hour moving average) and the combination may be rare on M15 in 2024.
b) **Implementation gap**: the entry rule in the compiled EA may have a logic error
   (e.g., `>=3` implemented as `>3`, or a missing `&&` vs `||` in the multi-condition
   check).
c) **SMA period mismatch**: if the EA uses `SMA(50)` and `SMA(200)` on the same
   timeframe as the execution period (e.g., H1), the SMA(200) warmup requires 200
   bars before any signal can fire. With a 1-year 2024 backtest at H1 (≈6,000 bars
   available), warmup is fine. But if at D1, the model=4 real-tick run on D1 bars
   over 1 year has only ~250 bars — SMA(200) needs exactly 200 to initialize, leaving
   only ~50 bars for signal generation. In those 50 bars, the probability of Score>=3
   firing zero times is possible but unlikely.

Without source code, the implementation hypothesis cannot be resolved here. However,
**the card's underspecification means any implementation is guesswork** — there is
no authoritative spec to code against.

## 4. Why the DL-062 trigger fired

30 valid backtests, all zero-trade, across a diverse symbol universe. This is the
strongest possible zero-trade signal the classifier can receive — and it is technically
correct. The issue is that the zero-trade result is ambiguous:
- It might reflect structural entry-condition over-restriction
- It might reflect a missing implementation detail (timeframe, SMA initialization)
- It cannot be resolved without a proper G0-vetted card

## 5. Verdict and recommended action

**Mark DEAD_CARD at this spec level.** Not "edge is dead" — but "insufficient
specification to determine whether the edge exists." The card must:

1. **Return to G0/DRAFT status (process)**:
   - Remove from `cards_approved/` or clearly annotate `g0_status: DRAFT`
   - Do NOT re-enqueue until G0 review is complete
   - The `MANUAL_ADVISOR` trigger is not a substitute for R1-R4 vetting

2. **Complete G0 vetting (claude/owner)**:
   - R1: Source citation required — "Multi-factor scoring" is not a source. What
     publication or practitioner methodology does this come from? Gray's "Quantitative
     Momentum"? AQR papers? Something else?
   - R2: Timeframe must be specified explicitly in frontmatter and body. The mechanic
     is incomplete without it. Add a `period:` token.
   - R3: Target symbols must be declared. This determines which DWX data paths are
     confirmed available.
   - R4: The scoring rule with fixed SMA/RSI/ATR thresholds is ML-free — PASS if
     thresholds are fixed. Confirm no adaptive re-calibration.
   - Add position sizing spec (no RISK_FIXED or RISK_PERCENT declared).
   - Add stop-loss spec (none declared).

3. **Structural review of entry logic**:
   - If the intent is "buy oversold dips in uptrends": RSI<40 + SMA50>SMA200 is
     the core. ATR>MA(ATR) + BarColor=Green add confirmation. The 4-factor OR-3 gate
     is reasonable BUT RSI<40 in an established uptrend is rare (by design). Realistic
     `expected_trades_per_year_per_symbol` is 5–15 on D1 for a "buy-the-dip in bull
     trend" system.
   - Add `expected_trades_per_year_per_symbol: 10` to the card (D1 basis).

4. **Do NOT relax score threshold to 2**: a score of 2 would include {SMA uptrend +
   green bar} which fires every up-day — that is a buy-and-hold, not a strategy.
   If Score=3 is too restrictive, the right fix is to replace one factor with something
   that fires more usefully (e.g., replace BarColor=Green with "price above EMA20"
   for the {SMA uptrend + oversold + expanding vol + near-term bias} set).

5. **After G0 re-vetting**: if the card clears, rebuild the EA to match the spec,
   run a single EURUSD.DWX D1 seed with `min_trades_required=1` and confirm trades
   fire before full enqueue.

## 6. Falsification

This critique is wrong if:
- The G0-completed card specifies a timeframe (e.g., M15 with shorter SMA periods),
  under which the entry condition fires regularly; AND
- The rebuilt EA produces trades on the stated universe/timeframe.
In that case, the 30 zero-trade backtests reflect a timeframe-implementation mismatch,
not structural impossibility.

## 7. Verification I ran

- Card at `D:\QM\strategy_farm\artifacts\cards_approved\QM5_4001_elite-multi-factor-scoring.md`
  — confirmed missing mandatory frontmatter (no g0_status, R1-R4, expected_trades,
  target_symbols, timeframe, risk spec).
- Direct sqlite: 30 P2 rows, all `done/FAIL`, 0 INVALID, 0 INFRA_FAIL.
  Symbols span full DWX universe (EURUSD, GBPUSD, USDJPY, XAUUSD, XTIUSD, SP500,
  NDX, WS30, GDAXI, AUDJPY...).
- EA build confirmed: `D:\QM\mt5\T1\MQL5\Experts\QM\QM5_4001_elite-multi-factor-scoring.ex5`
  (built 2026-05-21).
- Structural analysis: Score>=3 with {SMA50>200, ATR>MA, BarColor=Green} should
  fire on USDJPY D1 2024 uptrend multiple times per year — zero-trade outcome on a
  clean backtest with no INFRA issues requires an implementation or timeframe
  explanation that cannot be resolved without source code or a complete card spec.
