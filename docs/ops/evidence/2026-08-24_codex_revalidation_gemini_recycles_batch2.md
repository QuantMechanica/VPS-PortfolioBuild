# Codex revalidation — recycled Gemini EA cohort (batch 2)

Date: 2026-08-24  
Branch: `agents/board-advisor`  
Decision scope: code review only; no pipeline promotion, compile enqueue, backtest enqueue, terminal action, or registry mutation.

## Verdict summary

| Router task | EA | Verdict | Blocking reason |
|---|---|---|---|
| `b0616421-88f4-4370-b053-b96031a43386` | `QM5_9910` | **FAIL / RECYCLE** | The approved card's 5.0 ATR catastrophic backstop remains unimplemented, and the entry-only no-trade filter can suppress position management and exits. |
| `cd6442dd-4ad9-4845-862a-2ef6e3ec0172` | `QM5_9468` | **FAIL / RECYCLE** | The required three-D1-bar exit remains behind the entry filter; the D1 execution contract and stop-exit cooldown accounting remain incomplete. |
| `3ba5f88c-e843-4969-b8b7-152a38d240e9` | `QM5_9914` | **FAIL / RECYCLE** | ZLEMA cross-back/time exits remain behind an entry filter, and the implementation retains a spread filter absent from the approved card. |
| `3281881e-4597-4243-9a2b-e8d7c4fa6360` | `QM5_35005` | **FAIL / REVIEW** | The source repair passes current static checks, but its EX5 is stale and the governed `COMPILE_EA` work item is still pending; no current strict, hash-bound build identity exists. |

These are Gemini-origin reviews. They remain in `REVIEW`; this artifact does not authorize movement to `PIPELINE`.

## Hash-bound source review

### QM5_9910 — TEMA/ADX trend

- Current MQ5 SHA-256: `8d19dff75f54158b7f2ff026f12cf0a582a961b4e720fea00318e7cc41c0c78c`.
- Current EX5 SHA-256: `39c32ccdc46237df0cfabfe7255ba1994c29a46159c4d604343df5871bcaeb08`.
- The source is unchanged since commit `5ebcdb11d1b0c27dd8679f1430d61ab6b8efd51f` (2026-08-23).
- The approved card requires a catastrophic backstop at `5.0 * ATR(14, D1)`. The input `strategy_catastrophic_atr_mult` is only validated (`mq5:44,87`); the entry stop is instead built with `strategy_trail_atr_mult` (`mq5:131-145`). This is a dead strategy input and a missing card mechanism.
- `Strategy_NoTradeFilter()` returns before both `Strategy_ManageOpenPosition()` and `Strategy_ExitSignal()` (`mq5:262-267`). An entry-only filter therefore suspends the card's Chandelier maintenance, opposite-cross exit, and 60-day time stop.

### QM5_9468 — Connors RSI(4), three-day D1

- Current MQ5 SHA-256: `f34b09783e49b2b84319c15b56ff1d42620bb6ab76a16af21ef9954d5e76b4c7`.
- Current EX5 SHA-256: `b466bc58004efef8f721cbc0e19fe40add71bf71605fac7e00a47a23ccba0729`.
- The source is unchanged since commit `b08062cdb763a14c531d16222865a1006b6e4b51` (2026-08-23).
- The card-required fixed three-D1-bar close is implemented inside `Strategy_ManageOpenPosition()` (`mq5:123-149`), but `Strategy_NoTradeFilter()` returns first (`mq5:191-194`). Spread/warm-up entry conditions can therefore extend a supposedly fixed holding horizon.
- `g_last_exit_time` is written only after explicit EA close calls (`mq5:143-146,208-211`); no trade-transaction reconciliation records stop-loss exits, so the three-bar cooldown is not enforced after every exit.
- The source evaluates D1 data but uses a bare chart-period `QM_IsNewBar()` (`mq5:223`) and declares no D1 execution contract during initialization.

### QM5_9914 — Bandy ZLEMA distance trend

- Current MQ5 SHA-256: `92bbba767ef24e3c7307ccfb73685261d38110c57782b1eaf2ccaf251031474e`.
- Current EX5 SHA-256: `fcffbe005da21a7c504a30ff1627dab8b94d550c6d8dd50dac89b3e17f48ae8d`.
- The source is unchanged since commit `162a8e5e44ad4bc8bf7d9a60a22aa5db1024d82d` (2026-08-23).
- The card-required ZLEMA cross-back and 30-day exits are in `Strategy_ManageOpenPosition()` (`mq5:150-190`), but the no-trade filter returns first (`mq5:232-235`). Entry conditions can suppress mandatory exits.
- The implementation adds `strategy_spread_max_atr` and rejects entries on that basis (`mq5:45,90-92`), although the approved card's additional filters do not authorize a spread/ATR rule. This changes trade selection rather than merely implementing the card.
- D1 indicators are driven by a bare chart-period `QM_IsNewBar()` (`mq5:261`) with no declared D1 initialization contract.

### QM5_35005 — SMA crossover pullback

- Current MQ5 SHA-256: `8c5457fc7cc7b10af168f89089b7320a5118d43078f87ed73232de18bbe0d4fc`.
- Current EX5 SHA-256: `28ef9a97341ab09666f4b8ac6a817bbdabe806c968fbc96279a0e1be0b2fbd59`.
- Source commit `82755f48a664abf1b0cc1fe5fa8833a8f3721aec` repairs the prior semantic findings: the 2.0/2.5/5.0 rails are wired, the rollover window converts broker time to UTC, and management precedes entry-only filters.
- The EX5 still predates that repair. `farmctl work-items --ea QM5_35005` reports compile work item `73d3e2a5-1743-40b5-b744-878543577bf2` as `COMPILE_EA_pending`; the three existing Q02 work items were not touched.
- Because no governed compile and strict build check bind the current MQ5 and EX5 hashes, the repaired source cannot be accepted into the pipeline yet.

## Focused verification

- `validate_build_guardrails.py` on all five inspected MQ5 files (the four task EAs plus the concurrently inspected `QM5_9579`) returned `PASS`, `max_news_stale_hours=336`, and no findings at 2026-08-24T13:43Z.
- `build_gate_hardening.py --repo-root C:/QM/repo --ea-label <EA>` returned exit 0 and no mechanical failures for each task EA. This does not supersede the semantic card review above.
- Set-file audit: `QM5_35005` (3 sets), `QM5_9910` (13), `QM5_9468` (13), and `QM5_9914` (13) all have `RISK_FIXED > 0`, `RISK_PERCENT = 0`, and no news-staleness value above 336.
- No compiler, terminal, factory, backtest, routing, registry-write, or live-trading command was executed.

## Required next action

- `QM5_9910`, `QM5_9468`, and `QM5_9914`: repair the identified source/card-contract defects, rebuild, and return with new hash-bound evidence for fresh Codex review.
- `QM5_35005`: allow the governed compile worker to consume the already-pending `COMPILE_EA` item, then run strict build verification against the current hashes and resubmit. Do not promote from this review artifact.
