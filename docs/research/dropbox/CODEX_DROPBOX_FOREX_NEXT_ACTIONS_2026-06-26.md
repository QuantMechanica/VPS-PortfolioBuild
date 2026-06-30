# Codex Dropbox Forex Pass - Next Actions

**Date:** 2026-06-26  
**Scope:** `C:\Users\Administrator\Dropbox\Finanzen\Forex`, existing Dropbox research artefacts, live farm evidence.  
**Status:** actionable triage, no strategy/pipeline code changed.

## Access Finding

The Dropbox desktop client was not running; only `DbxSvc.exe` was active. I started
`C:\Program Files (x86)\Dropbox\Client\Dropbox.exe`, but the Forex files still behaved as
online-only placeholders:

- `.vtt`, `.srt`, `.txt`, `.pdf`, `.mq5` reads return `The cloud file provider is not running`
  or Python `OSError [Errno 22] Invalid argument`.
- 870 text/subtitle files are inventoried, but 0 were readable in the current session.
- This means I did not treat video/PDF content as read. The source-grounded material available
  today is the prior local inventory and the farm database/evidence.

Implication: do not restart video-based card extraction until Dropbox files are hydrated and
the video-AI contract is source-anchored. The previous Gemini Wave-A1 failure already proved
that filename-only hallucination is a real risk.

## What Is Worth Mining Next

### 1. Code-first / non-video sources

These can produce real work without trusting video summaries.

| Priority | Source | Why | Action |
|---:|---|---|---|
| 1 | FTMO March 2026 portfolio package | Existing inventory says 11 ML-free portfolio EAs plus documented strategy registry; strongest code-first source in the whole Dropbox inventory. | Locate/hydrate package, extract `SM_015 OvernightDrift` first, then USDJPY Asian/Ichimoku/NNFX and XTI/XAG trend packages. |
| 2 | `Ftmo/week1-2` rule-based ICT/SMC code | SilverBullet, SMC, Donchian, AsianRange are V5-compatible and no-ML. | Do not create new generic ICT cards; port/test the concrete rule-based EAs or reconcile with existing session-family EAs. |
| 3 | `ss94n...8Currency...` | Prior pass found only one real strategy: `Anna` SMA(10/40) cross, 30-pip SL/trail. | Low priority card only if we need cheap FX breadth; not a mission-critical edge. |
| 4 | `EA - FTMO - Trading Course` | Source code is FSB Pro generated: Envelopes(5,0.08), MACD(8/19/2), SpreadLevel(30), ChandeMomentum(15/30), 4.9% account stop. Videos/PDFs are required for human rule context. | Do not mine from filenames. If forced, build one source-code-derived experimental card, clearly marked FSB-generated and M1/P5b-bound. |

### 2. Hydrate-then-mine sources

These look promising from filenames/metadata, but I would not claim content until readable.

| Source | Why It Looks Useful | Caution |
|---|---|---|
| `WB Trading` | Has specific PDFs for Higher-Timeframe Bias, Price Reversion, DAX/GBPUSD trade records, Session Momentum. | Hydration needed; likely discretionary details in videos/PDF charts. |
| `WondaFX` | Has `Trading Plan.pdf`, `Market Behaviour.pdf`, sessions script. | Need exact rules; funded-trader material may be discretionary. |
| `Wyckoff Video Course` | Crypto Wyckoff slides may map to BTC/ETH or index accumulation/distribution filters. | Needs visual interpretation; lower priority than code-first sources. |
| `MQL5 PROJECTS` strategy courses | Titles map to concrete mechanics: candlestick breakout, FVG, HMA trend, anti-persistence MR, carry/rollover. | Most are video-only; mine only after local video AI is fixed or files are hydrated with readable code/PDFs. |

## Existing Farm Candidates To Salvage Before New Dropbox Cards

These have real test evidence and are closer to becoming sleeves.

| Priority | Candidate | Current Evidence | Next Action |
|---:|---|---|---|
| 1 | `QM5_10440:mql5-ohlc-mtf` on `NDX.DWX` | Q08 `FAIL_SOFT`, PF about 1.22, 441-451 trades, high net profit in metrics. | Fix/redo Q08 stream and rerun Q09 with main. This is nearer to a sleeve than any new Dropbox extraction. |
| 2 | `QM5_10692:tv-ls-ms` on `NDX.DWX` | Q09 `PASS_PORTFOLIO` exists in pipeline evidence; live candidate stale due stream/evidence issue. | Redump NDX stream, rerun/admit cleanly, dedupe candidates. |
| 3 | `QM5_10815:tv-post-vwap` on `GDAXI.DWX` | Q08 `FAIL_HARD`, but metrics show PF 2.20, 66 trades, positive net. | Inspect Q08 hard-fail criteria and path robustness. Possible robust DD/PBO issue, not obvious edge absence. |
| 4 | `QM5_10911:grimes-complex-pb` on `GDAXI.DWX` | Q08 `FAIL_HARD`, PF 1.15, 268 trades, positive net. | Review whether hard fail is robustness/PBO; if yes, try risk filter/ablation rather than new strategy. |
| 5 | `QM5_10115:tv-ma-scalper-relief` on `GDAXI.DWX` | Q08 `FAIL_HARD`, PF 1.08, 430 trades. | Lower conviction; only after 10815/10911. |
| 6 | `QM5_11165:weiss-rsi-ma` on `AUDCAD.DWX` | Q08 `FAIL_HARD`, PF 1.14, 173 trades. | Interesting because it is actual FX breadth; inspect why hard-failed. |
| 7 | `QM5_12567:cum-rsi2-commodity` on `XNGUSD.DWX` | Q09 `NEED_MORE_DATA`, 14 trades under the new 20 floor; Q07 PF 1.41, DD 1.89. | Keep as watchlist/data-gap. Do not lower floor again just to admit it. |

## Recommended Sequence

1. Finish the current live recovery: NDX stream redump for `10440` and `10692`; Q09 rerun/admit.
2. Run a "late-fail autopsy" on `10815`, `10911`, `11165`: extract Q08 hard-fail reason from the runner internals, not just `aggregate.json`.
3. Hydrate or locally copy only the code-first Dropbox packages first: FTMO March 2026, `Ftmo/week1-2`, WB PDFs.
4. Draft at most 3 new cards from source-grounded non-video material:
   - `SM_015 OvernightDrift` / GBPUSD session-calendar family.
   - USDJPY AsianRange/Ichimoku/NNFX portfolio component.
   - One energy/metals trend or MR component from XTI/XAG portfolio material.
5. Keep video-only courses paused until files are readable and the extraction tool proves source access.

## Bottom Line

The best immediate EA potential is not in unprocessed videos. It is in:

- NDX late-stage survivors already in the farm.
- GDAXI/AUDCAD late hard-fails that have enough trades and positive PF.
- Code-first Dropbox packages, especially FTMO March 2026 and rule-based ICT/SMC sources.

Video courses may still contain good ideas, but with the current Dropbox placeholder state and the
known Gemini hallucination failure, they are not a safe first lever.
