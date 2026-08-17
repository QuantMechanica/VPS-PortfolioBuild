# QM5_33003 (ehlers-superpassband-fisher-cycle-scalper) Build & Verification Evidence

- Task ID: `835cea6d-11ab-4330-ad7d-c5117b37cb31`
- EA ID: `QM5_33003`
- Date: 2026-08-17
- Branch: `agents/board-advisor`
- Target symbols: `EURUSD.DWX` (slot 0), `GBPUSD.DWX` (slot 1), `USDJPY.DWX` (slot 2)
- Timeframe: `H1`
- Magic Numbers: `330030000` (slot 0), `330030001` (slot 1), `330030002` (slot 2)

## Summary of Implementation

Implemented John Ehlers' 2nd-order SuperPassBand filter and Fisher Transform DSP cycle scalper mechanically per approved strategy card `QM5_33003_ehlers-superpassband-fisher-cycle-scalper.md`:
- HighPass filter strips DC trend drift from price series ($a_1 = 5.45 / 40$).
- SuperPassBand filter isolates dominant cycle frequencies ($a_2 = 5.45 / 10$).
- Fisher Transform converts normalized cycle oscillations to Gaussian probability distribution.
- Shift=1 closed H1 bar trigger evaluation: Long when Fisher crosses above Trigger line in deep oversold territory ($\le -1.50$); Short when Fisher crosses below Trigger line in deep overbought territory ($\ge +1.50$).
- Risk & Trade Management: 1.5x ATR initial stop loss, 3.0x ATR take profit (1:2.0 R:R), and zero-crossing cycle exit when Fisher returns to 0.0.
- No-trade filter: spread filter relative to ATR, 23:55-00:05 rollover blackout, and single concurrent position guard.

## Verification Checklist

- **Magic Numbers Registry**: Registered all 3 portable DWX basket symbols in `framework/registry/magic_numbers.csv` (`330030000`, `330030001`, `330030002`).
- **Magic Resolver**: Regenerated `framework/include/QM/QM_MagicResolver.mqh` via `python framework/scripts/update_magic_resolver.py` (17,319 rows kept, 0 dropped).
- **SPEC Document**: Created `framework/EAs/QM5_33003_ehlers-superpassband-fisher-cycle-scalper/SPEC.md` and validated with `validate_spec_doc.py` -> `PASS`.
- **Build Check & Compilation**: Ran `build_check.ps1` -> `PASS` (0 errors, 0 warnings; `.ex5` compiled cleanly).
- **Setfile Generation**: Generated `EURUSD.DWX`, `GBPUSD.DWX`, and `USDJPY.DWX` backtest setfiles in `sets/` with `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- **Build Guardrails**: Verified via `tools/strategy_farm/validate_build_guardrails.py` -> `PASS` (`max_news_stale_hours: 336`, `verdict: PASS`).
- **Smoke Status**: `deferred_p2_smoke` recorded due to headless scheduled execution; Q02 will provide runtime backtest evidence.

## State Disposition

Artifact ready for Codex review.
