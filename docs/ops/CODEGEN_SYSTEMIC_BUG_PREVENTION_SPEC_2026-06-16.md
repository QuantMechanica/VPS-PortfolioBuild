# Codegen Systemic-Bug Prevention — Spec for Codex

**Author:** Claude · **Date:** 2026-06-16 · **Routing:** Codex (code task) · **Status:** READY (queue when Codex weekly quota resets — maxed 2026-06-16)

## Why this exists

The 2026-06-16 zero-trade EA rework fixed **~88 EA bugs** across 228 EAs. They were not random — they clustered into **14 systemic classes**, almost all introduced by the **generated-EA codegen** (the `mql5-*/tv-*/ft-*/ftmo-*/grimes-*/et-*/robo-*` families). The EA bodies are written by Codex per `tools/strategy_farm/prompts/codex_build_ea.md`, stamped onto `framework/templates/EA_Skeleton.mq5`. The skeleton itself is clean (empty `Strategy_NoTradeFilter` stub, correct OnTick `QM_IsNewBar` wiring) — **Codex writes the buggy idioms while implementing each strategy.** Hand-fixing the 228 EAs treats symptoms; this spec fixes the **source** so new EAs stop re-inheriting the bugs.

**Scope guard:** This is FORWARD prevention only. Do NOT mass-edit the 228 already-reworked EAs (they carry `// rework v2 2026-06-16` headers and are re-running through Q02). Do NOT mass-patch the 133 spread-guard-flagged EAs — that class is conditional and 15 of them PASS Q02; a blanket patch risks regressions (see Claude's lint note in `memory/project_qm_zero_trade_rework_2026-06-16.md`).

## Deliverable: two-pronged, prompt + gate

Prompts drift; a deterministic gate does not. Do BOTH.

### Prong A — Deterministic build-gate lint (the guarantee)

Add a `.DWX backtest-invariant` idiom scan to `framework/scripts/build_check.ps1` inside the existing `Invoke-ForbiddenScan` function (line ~527), using the existing `Add-Failure` mechanism. Each rule scans the EA's `.mq5`; on match, fail the build with a `BUILD_CHECK_DWX_INVARIANT_<CLASS>` code so the EA cannot reach the pipeline until fixed. Keep it line-attributed (reuse the fixed `(?m)^[^/\r\n]*?` non-comment-line idiom from commit 71090bcb5 — do NOT let `\s*` cross newlines).

The mechanically-detectable, high-confidence rules (FAIL the build):

| Class | FORBIDDEN idiom (regex intent) | Example culprit |
|---|---|---|
| **Fail-closed spread guard** | a blocking branch (`return true` in `*NoTradeFilter`, `return false` in `*SpreadOk/*Allow*/*Pass*/*DataAllows*`) whose condition contains `ask <= bid` (**`<=`**, not `<`) OR `(\bspread\b|current_spread|spread_points|median_spread|rates\[\w+\]\.spread)\s*<=\s*0` | 10495, 11048, 11355, 10884 |
| **Swap-sign entry gate** | entry/exit gated by `SYMBOL_SWAP_(LONG|SHORT)` compared `> 0` / `<= 0` / `< 0` that BLOCKS (vs reading it as a carry signal — allow when the value feeds a ranking/forecast, not a boolean gate) | 10027, 10884 |
| **Lazy / immediately-released handle** | any raw `iATR|iMA|iRSI|iMACD|iADX|iBands|iStochastic|iCustom|iVIDyA|iAO|iCCI|iMomentum` call in EA body (the QM_* readers are mandatory), AND especially `IndicatorRelease` called in the same function as a handle create | 10463, 1258, 9245 |
| **Flat `max_*_points` / points-as-pips** | a fixed range/SL/TP/breakout threshold compared in raw `*_points` against price without a `QM_StopRulesPipsToPriceDistance` / pip_factor conversion (heuristic: `<= *strategy_\w*_points` used as a price gate on multi-digit symbols) — emit a WARNING not a hard fail (higher false-positive risk) | 9300, 10542, 11356 |

Note for the spread rule: distinguish **zero-price** checks (`ask <= 0.0 || bid <= 0.0` / `point <= 0.0`) which are CORRECT defensive guards and must NOT be flagged, from **zero-spread** checks (`ask <= bid`, `spread <= 0`) which block valid .DWX quotes. Only the zero-spread form fails.

### Prong B — Harden the build prompt (`tools/strategy_farm/prompts/codex_build_ea.md`)

Add a new top-level section **"## .DWX backtest invariants — forbidden idioms (the build gate rejects these)"** near the existing "No Trade Filter (time, spread, news)" line (~55). State each class as WRONG → RIGHT so Codex generates correct code on the first pass. Cover all 14 (the 4 gated above PLUS the ones that are real but hard to lint mechanically):

1. **Spread guards never fail-closed on zero spread.** `.DWX` symbols quote `ask == bid` (0 modeled spread) and `SymbolInfoInteger(SYMBOL_SPREAD)`/`iSpread`/`rates[].spread == 0` in the tester.
   - WRONG: `if(ask <= bid) return true;` / `if(spread <= 0 || spread > cap) return false;`
   - RIGHT: only block on a genuinely-wide spread; treat zero/degenerate spread as tradeable: `if(ask > 0 && bid > 0 && ask > bid && (ask-bid) > cap) return true;` (zero-price still blocks; zero-spread passes).
2. **Never gate entry on swap sign.** Reading `SYMBOL_SWAP_*` as a carry SIGNAL is fine; a boolean `if(swap <= 0) reject` blocks every trade on `.DWX` $0-swap. Remove the gate; let the ranking/forecast decide.
3. **Never create indicator handles in the EA body.** Use the pooled `QM_ATR/QM_EMA/QM_RSI/QM_MACD_*/QM_ADX*/QM_BB_*/QM_SMA/QM_Stoch` readers. Never `iX(...)` + `IndicatorRelease` in a signal function — the handle never back-calculates in the tester and returns a constant fallback.
4. **`QM_IsNewBar()` is single-consume per tick.** Call it ONCE in OnTick for the entry gate. An exit hook that calls `QM_IsNewBar()` before the entry gate consumes the new-bar event and starves entry. If the exit must run per closed bar, latch `const bool is_new_bar = QM_IsNewBar();` once and reuse — never call it twice with the same key. (10420/1259/1342/10574.)
5. **Don't require two cross EVENTS on the same bar.** Two fresh crossovers (or cross + oscillator-cross) almost never coincide. Make ONE the trigger and the others STATES (currently-above/below), or allow them within a small lookback window. (Pervasive: 1081/2010/10721/10829/...)
6. **Session/OR windows must be in BROKER time, matched to the symbol.** DXZ broker = NY-Close GMT+2/+3 (DST-aware). US-index cash open 09:30 ET = broker ~16:30; London 08:00 = broker ~09:00; Frankfurt/DAX 09:00 CET = broker ~10:00. A raw-ET/UTC window, or a US-open window on a DAX symbol, builds the range in dead hours → 0 trades. Convert via `QM_BrokerToUTC`/the DST-aware helpers; do not hardcode clock hours. Put per-symbol session params in the setfile. (10709/10760/10770/10780/10930/10958.)
7. **Candle-pattern / gap rules need the prior CLOSE, not the prior RANGE, on 24h CFDs.** `.DWX` index/FX CFDs are gapless: `open[0] == close[1]`. A rule needing `open < prior_low` (Chan gap, piercing line) can never fire. Reference the prior close or an intraday session frame. (1277/10619/10965/10966.)
8. **Compression/range/flat/squeeze gates: scale a MULTI-bar range against a MULTI-bar baseline.** Comparing an N-bar high-low range to a single-bar ATR is always "not flat" → 0 trades. Multiply the ATR baseline by `sqrt(lookback)`. (10526/10914/10915/10964.)
9. **SuperTrend/OTT direction: seed from `hl2` (bar median), not `final_lower`/`final_upper`.** Seeding from a band that sits several ATR away pins the trend and it never flips. Derive `dir@1` and `dir@2` from ONE forward reconstruction, not two convergent ones. (10537/11200/10194.)
10. **No degenerate placeholder params** (e.g. `rsi_period=1` pins RSI; periods of 1). Use the real strategy values.
11. **Monthly (MN1) logic is untestable for `.DWX`** — the tester yields 0 bars on MN1. Make monthly EAs D1-native with a ~21-bar/month (252-day/year) proxy. (1085/1559/1088.)
12. **External-macro-CSV strategies are infeasible** — we have no VIX / futures-curve / interest-rate / yield feed and never will via a checked-in CSV. Do NOT card or build strategies whose only signal is such a file (they hard-fail R3 and produce 0 trades). (1177/1179/1203/1249 — retired.) This is a G0/card-review rule too.
13. **Exact tick-minute gates miss.** `if(TimeCurrent() minute == 45)` fails because the new-bar tick arrives after `:45:59`. Key off `iTime(sym, tf, 0)` bar-open time. (10874.)
14. **CET/ET clock values must be offset to broker time** before use (no direct application of a card's "09:00 CET" to a broker-time chart). (10958.)

Also add to the build prompt's existing DO-NOT list a one-line pointer: "Your EA will be REJECTED by `build_check.ps1` if it contains any forbidden `.DWX` idiom above."

## G0/card-review companion (small, same change-set)

In `tools/strategy_farm/prompts/codex_g0_review.md` + `claude_research_source.md`: reject cards whose only signal source is an external macro feed we don't have (VIX/futures-curve/rates/yields) under R3 — class #12. The trade-frequency calibration anchors were already added (commit 1cba80412); leave them.

## Acceptance criteria

1. `build_check.ps1` gains the `Invoke-ForbiddenScan` `.DWX`-invariant rules (classes 1–3 hard-fail, class 4-points WARNING). Each rule has a unit smoke: feed it one of the named culprit pre-fix snippets → it FAILS; feed the post-fix EA → it PASSES. Use a fixed/non-fixed pair (e.g. `git show` the pre-rework 10495 vs current).
2. The scan does NOT flag the correct zero-price guard (`ask<=0||bid<=0`) and does NOT flag carry EAs that read swap as a signal (10885/1070/1067/10718 must still pass).
3. `codex_build_ea.md` carries the 14-point forbidden-idiom section; a fresh build of any new card produces none of the idioms.
4. Re-run the lint analyzer from the rework note across `framework/EAs` after one new build cycle — no NEW EA (build date > 2026-06-16) carries a hard-fail idiom.
5. No regression: `build_check.ps1` still passes for the current `review_approved` set (spot-check 20 EAs) — i.e. the new rules don't false-positive the existing healthy EAs.

## Evidence / references

- Bug catalogue + per-EA fixes: `memory/project_qm_zero_trade_rework_2026-06-16.md` (Claude's auto-memory).
- Detector logic used to scope: the polarity-resolving spread analyzer in that note (zero-spread-block vs zero-price-guard distinction).
- Skeleton: `framework/templates/EA_Skeleton.mq5` (clean — do not change the OnTick wiring). Build prompt: `tools/strategy_farm/prompts/codex_build_ea.md`. Gate: `framework/scripts/build_check.ps1` `Invoke-ForbiddenScan`.
