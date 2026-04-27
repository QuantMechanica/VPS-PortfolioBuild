# 2026-04-27 - QUA-94 rates span probe evidence

Tool:
- `infra/scripts/probe_verify_rates_span.py` (read-only)

Command set:

```powershell
python C:\QM\repo\infra\scripts\probe_verify_rates_span.py --symbol XNGUSD.DWX --chunk-days 1 --tail-hours 24
python C:\QM\repo\infra\scripts\probe_verify_rates_span.py --symbol XTIUSD.DWX --chunk-days 1 --tail-hours 24
python C:\QM\repo\infra\scripts\probe_verify_rates_span.py --symbol XAUUSD.DWX --chunk-days 1 --tail-hours 24
python C:\QM\repo\infra\scripts\probe_verify_rates_span.py --symbol WS30.DWX --chunk-days 1 --tail-hours 24
```

Observed:

| Symbol | expected M1 | oneshot_count | chunked_count (1d) | tail_window_count (24h) | notes |
| --- | ---: | ---: | ---: | ---: | --- |
| `XNGUSD.DWX` | 383,654 | 0 (`Invalid params`) | 0 | 0 | custom symbol selectable/visible, but no bars returned |
| `XTIUSD.DWX` | 443,430 | 0 (`Invalid params`) | 0 | 0 | same pattern as XNG |
| `XAUUSD.DWX` | 446,753 | 0 (`Invalid params`) | 0 | 0 | same pattern as XNG |
| `WS30.DWX` | 445,870 | 0 (`Invalid params`) | 100,251 | 0 | partial recovery via chunking, not full span |

Interpretation:
- This is not a clean "all symbols identical" failure mode.
- `XNGUSD.DWX` remains hard-zero across oneshot + chunked + tail-window reads.
- `WS30.DWX` can return bars in chunked mode, indicating verifier read-path behavior differs by symbol family/session state.
- Escalation should include both:
  - verifier runtime hardening (`symbol_select`/warm-up/retry/chunked fallback), and
  - MT5 data-visibility investigation for commodity custom symbols (`XNG`/`XTI`/`XAU`) where reads stay at zero.
