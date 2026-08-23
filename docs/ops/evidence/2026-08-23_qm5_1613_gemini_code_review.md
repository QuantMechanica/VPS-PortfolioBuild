# QM5_1613 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `6cb2150d-fd37-4068-a0cd-5a11e9d90b32`

Source task: `de6c76f5-05f5-46cb-ac53-4fa4b81fc9b1` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_1613_aa-dsp-atsmom/build_identity.json`

Verdict: **REQUEST_CHANGES — do not promote to PIPELINE**

## Findings

### 1. High — entry mechanics do not implement the approved card

The approved card says to open long whenever the completed-bar `ATSMOM > 0` and short whenever `ATSMOM < 0` (`cards_approved/QM5_1613_aa-dsp-atsmom.md`, lines 38-39). The EA instead requires a zero crossing:

```mql5
if(atsmom1 > 0.0 && atsmom2 <= 0.0)   // long
else if(atsmom1 < 0.0 && atsmom2 >= 0.0) // short
```

This is not equivalent to the card. If the EA begins while a regime is already positive/negative, or an ATR stop closes a position while the signal keeps its sign, the approved rule re-enters while the implementation remains flat until another complete sign cycle. `SPEC.md` repeats the unapproved zero-cross interpretation rather than documenting the approved mechanic.

Required correction: implement the card's current-sign entry rule, or obtain a new approved card/identity for the zero-cross strategy. Do not silently reinterpret the card.

### 2. High — mandatory median-spread filter is missing

The approved card requires: skip new entries when D1 spread exceeds `2.5 ×` the 20-day median spread (card line 58). The EA has only an optional absolute-point ceiling:

```mql5
input int strategy_max_spread_points = 0;
if(strategy_max_spread_points > 0 && SYMBOL_SPREAD > strategy_max_spread_points)
   return true;
```

The default `0` disables this filter, and no 20-day median is calculated anywhere. Every generated setfile leaves the strategy-specific defaults untouched, so the required filter is absent in the delivered build.

Required correction: implement the mechanical 20-day median-spread comparison exactly as approved and test both allow/refuse cases.

### 3. High — news denial suppresses risk exits

`OnTick()` returns on `!news_allows` before both `QM_FrameworkHandleFridayClose()` and `Strategy_ExitSignal()`. During a required news blackout, the EA therefore skips its sign-flip exit and can also skip the Friday-close handler. The card specifies daily sign-flip exits; a new-entry blackout must not become an exit blackout.

Required correction: preserve the mandatory news blackout for new entries while allowing risk-reducing strategy and Friday exits. Verify ordering against the V5 framework contract before recompiling.

### 4. High — delivered symbol universe does not match the approved card

The approved baseline has nine symbols:

`SP500.DWX, NDX.DWX, WS30.DWX, GDAXI.DWX, XAUUSD.DWX, USOIL.DWX, EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX`.

The delivery has 13 active magic rows and 13 setfiles. It omits approved `USOIL.DWX` and adds five symbols absent from the card: `AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX, USDCHF.DWX, UK100.DWX`.

Required correction: reconcile the approved card, broker symbol naming and allocator output before any test enqueue. Do not test an expanded universe without OWNER-approved card provenance.

### 5. Medium — SPEC contains control-byte corruption

`SPEC.md` contains three non-whitespace control bytes: `0x07` at byte 75 and `0x1b` at bytes 102 and 1928. They corrupt the slug and source ID. Its risk table also renders the fixed-risk value as `,000` instead of `$1,000`. The strategy specification is therefore not a durable, clean review artifact.

Required correction: regenerate or repair `SPEC.md` from literal source text and add a control-byte check.

## Checks that passed

- Approved card exists with `g0_status: APPROVED`.
- EA registry row `1613 / aa-dsp-atsmom` is active.
- All 13 delivered symbols have active, unique magic rows, even though the delivered universe does not match the card.
- `validate_build_guardrails.py framework/EAs/QM5_1613_aa-dsp-atsmom`: `PASS`, 14 files, zero findings, `max_news_stale_hours=336`.
- All 13 backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- On-disk MQ5 SHA-256 matches `build_identity.json`: `7d9b88cdf5225fecbc69207ee600cb93ae43432e14e03e402f10934197fe9c20`.
- On-disk EX5 SHA-256 matches `build_identity.json`: `23d56a02a2285ba62b4c8e6ece03c1e274187e3ab2e3b0fe5411464c827682ae`.
- Direct first-on-tick MAE tracking is present.
- The implementation is mechanical and contains no ML, martingale or grid logic.

These passes establish artifact consistency and baseline hardening only. They do not cure the strategy-card and risk-ordering defects above, and they are not a pipeline verdict.

## Disposition

No source, binary, registry, setfile, task verdict or trade stream was changed by this review. `T_Live` and AutoTrading were not touched. The review remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code must receive a fresh mandatory Codex review before any acceptance or pipeline enqueue.
