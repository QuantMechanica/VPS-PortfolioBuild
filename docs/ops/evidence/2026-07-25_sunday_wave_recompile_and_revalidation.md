# Sunday wave 2026-07-26 — recompile + Q10 revalidation (run log)

- Started: 2026-07-24 ~21:00Z, OWNER authorisation "Ja, starte heute, schalte factory dazu
  gerne off" + "Leg los, folge deinen Empfehlungen".
- Branch: `agents/board-advisor` in the canonical checkout `C:/QM/repo`.
- Scope: 24 live sleeves + QM5_20048 (OWNER-promoted) + 6 admission candidates = 31 sleeves
  over 26 unique EAs.

## Why the wave needs a recompile at all

Every live binary predates the P0/P1 framework fix bundle (oldest live .ex5 2026-07-13, newest
2026-07-22; fixes landed 2026-07-20+). The deployed .ex5 therefore no longer matches the binary
that produced each sleeve's Q02–Q10 evidence. Recompiling closes that gap but invalidates the
evidence chain, which is what the Q10 revalidation below re-establishes.

Fix commits verified present in the build tree before compiling: `5b21b9b1d`, `37196e79d`,
`6e92c8062`, `bd9c3e049`, `8154d302f`, `51778300b`. The four commits on `origin/main` not in this
tree are docs-only.

## Recompile result: 24 of 26 EAs

All 24 hash-verified as genuinely changed (pre/post SHA256 recorded in
`scratchpad/wave_inventory.json`). 0 errors, 0 warnings across the set. Symbol scope
`SINGLE_SYMBOL_OK` except 12778 and 13117 which are correctly `BASKET_OK`.

**`--force` was mandatory.** `compile_ea.py` caches on "ex5 newer than mq5". The `.mq5` sources
are unchanged — only `framework/include/QM/*.mqh` moved — so without `--force` all 26 would have
been silently skipped as cached. That is the no-op-compile trap; the canary build of 11422
confirmed the binary hash actually changes before the batch ran.

Artifacts auto-committed by the pump (`0b867ada6`, `e68499506`), so no dirty-guard deadlock for
the concurrent strategy-farming session.

### Build guardrail: 5 EAs blocked, 3 of them spuriously

`validate_build_guardrails` validated the WHOLE EA directory, so stale setfiles for symbols that
were never promoted blocked EAs whose shipped setfile is clean:

| EA | wave symbol(s) | verdict |
|---|---|---|
| 1567_demark-td | EURUSD (live), XAGUSD | collateral — 31/37 setfiles fail, neither of ours |
| 10919_grimes-overshoot | XTIUSD (live) | collateral — 3/4 fail, XTIUSD clean |
| 10939_grimes-context-pb | GBPUSD (live) | collateral — 4/5 fail, GBPUSD clean |
| 10513_mql5-ichimoku | XAUUSD (live) | **genuinely affected** |
| 10815_tv-post-vwap | GDAXI, EURUSD (candidates) | **genuinely affected** |

Resolved for the three collateral cases by `--setfile-scope` (commit `9f6404b28`), which narrows
the guardrail to the setfiles a build actually ships. The `.mq5` is always checked and the
default no-flag path is byte-identical to before, so the factory pump and all existing callers
are unaffected. Regression-tested both directions before commit: default verdicts unchanged on
10919/10513 (FAIL) and 13128/20048 (PASS); scoped verdicts PASS for the three collateral EAs and
still FAIL for 10513/XAUUSD and 10815/EURUSD with findings pointing at their own setfiles.

## Finding: 10513/XAUUSD manifest provenance is wrong

Not a live-trading defect, but it must not ship unexamined.

`QM5_10513_mql5-ichimoku_XAUUSD.DWX_D1_backtest.set` (dated 2026-05-28) carries
`card_defaults_source=not_found` and **zero** `strategy_*` lines — it runs the EA's compiled
defaults (tenkan 9 / kijun 26 / senkou_b 52 / atr 14).

The live preset `..._XAUUSD.DWX_D1_live.set` runs a **tuned** configuration:
tenkan 6 / kijun 18 / senkou_b 68 / atr 18.

The real gate evidence came from `..._requal_D1_backtest.set` and `..._backtest_ablation_04.set`
(7 strategy lines each); the param-less base setfile was used only for one Q02 run on
2026-07-09. But `gen_dxz_final_manifest.py`'s `resolve()` picks `glob(*{sym}*backtest.set)[0]` —
alphabetically first — so the **sealed manifest documents the stale param-less file as the
sleeve's backtest basis**. The manifest's declared evidence basis does not describe the live
configuration.

Audited across the whole book: **1 of 24** sleeves is affected (10513/XAUUSD, risk 0.3050).
The other 23 manifest `backtest_set` entries carry real strategy parameters. The problem is
contained, and the guardrail found exactly the right sleeve.

10513 is therefore excluded from tonight's revalidation and does not ship Sunday without an
OWNER decision. `resolve()` should select deterministically rather than alphabetically —
tracked separately.

## Factory OFF

Executed ~00:20Z via `Factory_OFF.ps1` (shell already elevated, `Read-Host` piped). 8 work items
interrupted — snapshot in `scratchpad/interrupted_by_factory_off.json`; they requeue, so the cost
is compute time, not data. One of the eight (T8, Q02 QM5_9454/GDAXI) had been claimed since
**2026-06-28** and was a stale zombie rather than live work.

All ten `terminal_worker.py` daemons stopped; one orphaned `D:\QM\mt5\T9\terminal64.exe` killed
with path-anchored selection. **T_Live untouched** — `QM_T_Live_Watchdog` still Running,
`C:\QM\mt5\T_Live\MT5_Base\terminal64.exe` alive throughout.

## Q10 revalidation (running)

24 sleeves (23 live + 20048) across T1–T10, heaviest symbols scheduled first so the XAU tail gets
maximum runway — observed Q10 runtimes range from 10 min (NDX/USDCAD) to 5 118 min (10145/XAU).
Timeout 28 800 s per run. Driver: `scratchpad/revalidate_q10.py`; results stream to
`scratchpad/q10_revalidation_results.json`, log at `scratchpad/q10_revalidation.log`.

Each result is to be diffed against the sleeve's prior Q10 verdict. A material deviation means
the framework fixes changed that EA's behaviour and the sleeve needs full re-evidence, not just
a Q10 stamp.

## Open before Sunday

1. **10513/XAUUSD** — provenance above. Ship on the old binary, fix the setfile provenance, or
   drop from the book. OWNER decision.
2. **10815/tv-post-vwap** (candidates GDAXI + EURUSD) — same guardrail class, and it is a
   VWAP *session* strategy where session bounds are load-bearing. Needs a real look, not a
   cosmetic setfile edit.
3. **News calendar is forward-stale** — `news_calendar_stale.flag`: newest event 2026-07-24
   14:00Z, required now+2 d. Historical coverage 2015–2025 is complete so backtests are
   unaffected, but the go-live verification requires a current calendar. Must be refreshed
   before the chart session.
4. **Q09_PORTFOLIO recompute** for 20048 + the 6 candidates against the actual live composition
   (prior verdicts were measured against a different book base and are partly sequentially
   chained).
5. **Allocation rebuild** at TOTAL_RISK 12.0 over the final admitted composition — the 24-sleeve
   table in `decisions/2026-07-24_dxz_total_risk_975_to_12.md` is superseded the moment
   composition changes.
6. **Factory is OFF** — must be restored with `Factory_ON.ps1 -NoPause` once the revalidation
   completes, or the harvest queue stays dead.
