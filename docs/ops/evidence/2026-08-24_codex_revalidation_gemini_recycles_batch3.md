# Codex revalidation — recycled Gemini EA cohort (batch 3)

Date: 2026-08-24  
Branch: `agents/board-advisor`  
Scope: independent, hash-bound code review of router-assigned Gemini outputs. No compile, queue, terminal, registry, or live-trading mutation was performed.

## Decisions

| Router task | EA | Verdict | Blocking finding |
|---|---|---|---|
| `1ba1f9a9-0250-40a3-9a77-d8451b992fbb` | `QM5_9719` | **FAIL / RECYCLE** | News and entry gates precede Friday flatten and card exits; the required V5 lifecycle hooks and `SPEC.md` are absent. |
| `6bd917a5-8444-4499-8784-caddfe2527b3` | `QM5_9913` | **FAIL / RECYCLE** | Card exits remain behind an entry-only filter, and an unapproved spread rule changes trade selection. |
| `a06e3ace-6c6a-437e-9a6e-da3e37700a59` | `QM5_9716` | **FAIL / RECYCLE** | Card exits remain behind the entry filter; the generated spec and 13-symbol package contradict the approved D1 three-index contract. |
| `41c5ecbf-caa4-4f3b-989c-1490a2b767f5` | `QM5_9720` | **FAIL / RECYCLE** | Invalid indicator state returns before open-position management/exits; the spec and symbol package remain nonconforming. |
| `bf0ead8d-bde8-4b4b-838f-cace0a26e5c3` | `QM5_9466` | **FAIL / RECYCLE** | The RSI/time exits remain behind an entry-only filter, and the D1 execution/universe contracts remain incomplete. |

All five tasks must remain in `REVIEW`. This evidence does not authorize pipeline promotion.

## Hash-bound findings

### QM5_9719 — PercentRank channel MR

- MQ5 SHA-256 `daf7f3bde16ead8d3e4d474430ee6724709bf05671fe32838d6c8b46f0a3035e`; EX5 SHA-256 `ac6889489a33f138049c2f69627160f54847d56462f6dd608b0bf643bd202ff5`.
- Source remains at commit `3384cefb84aea3651738e100c8530c6373094120` (2026-08-23); no repair followed the prior recycle.
- `QM_NewsAllowsTrade*` returns before `QM_FrameworkHandleFridayClose`, `Strategy_ManageOpenPosition`, and `Strategy_ExitSignal` (`mq5:206-222`). A news blackout therefore suppresses safety exits and the card's PercentRank/time exits.
- `Strategy_NoTradeFilter()` also precedes management and exits (`mq5:217-222`).
- The EA has no `QM_EquityStreamOnNewBar`, `OnTradeTransaction`, or `OnTester` hook, and its expected `SPEC.md` does not exist.
- The approved card names only `SP500.DWX`, `NDX.DWX`, and `WS30.DWX`; the package contains 13 set files.

### QM5_9913 — RSI(3), low-ADX index MR

- MQ5 SHA-256 `1cb763b49a13d4ccc0a38dd664ef8cd4db6c42766384b16218c808880fe49701`; EX5 SHA-256 `63809aeb7b06b7436aebdc6ac792df294bc3c49b13491f8959311418c7b045e1`.
- Source remains at commit `162a8e5e44ad4bc8bf7d9a60a22aa5db1024d82d` (2026-08-23).
- `Strategy_NoTradeFilter()` returns before the RSI threshold and seven-day time exits in `Strategy_ManageOpenPosition()` (`mq5:180-185` versus `107-138`).
- `strategy_spread_max_atr` is enforced at `mq5:47,54-69`, but that spread rule is absent from the approved Strategy Card.
- The generated spec itself lists the expanded 13-symbol package, including the three symbols identified in the prior close as outside the card universe.

### QM5_9716 — Trend-Stretch Ratio index MR

- MQ5 SHA-256 `549544da3cba15017b487c0ebd16e19d4778c7a2f85ba09e0c79f19a3bf43a5e`; EX5 SHA-256 `c59061e92e9e9ff364e6651bfd6c7b479b1caa84f37e4cbcf340829c298f9fc6`.
- Source remains at commit `f31b1cfff75d8e8acbd87994785b5a52de124f38` (2026-08-23).
- `Strategy_NoTradeFilter()` returns before both the seven-day time stop and zero-cross exit (`mq5:211-216`). The spread/warm-up entry filter can suspend mandatory exits.
- The approved card is D1-only and names exactly `SP500.DWX`, `NDX.DWX`, and `WS30.DWX`. The generated spec instead says H1, says there are no strategy inputs despite nine declared strategy inputs, and declares 13 symbols; the package has the same 13 set files.

### QM5_9720 — ADX regime-filter trend

- MQ5 SHA-256 `0a432e165805faa1f08eed7e775d3ac0ca16a0429729ac29075b27bbf56d9d3d`; EX5 SHA-256 `90760f8de52ce58f124b7c265c9373cdc04815d37ba739c4b7730563313a0533`.
- Source remains at commit `4f4c4ac5d8286cca5da53c679d320abb6883cd82` (2026-08-23).
- `AdvanceState_OnNewBar()` can leave `g_state_valid=false`; `Strategy_NoTradeFilter()` then returns before both `Strategy_ManageOpenPosition()` and `Strategy_ExitSignal()` (`mq5:287-298`). Missing indicator data must fail closed for entries without disabling an existing position's trail/time/opposite-cross handling.
- `SPEC.md` stops after section 2 and does not document the required universe/timeframe/expected behavior/source/testing sections.
- The approved symbol contract includes `XTIUSD.DWX`; the 13-set package omits it and adds the five symbols named in the prior close.

### QM5_9466 — Connors R2 D1

- MQ5 SHA-256 `3537d969bb5c629d93eb18b91640f5227b44cd2290d92a564803b21dc47cd6d4`; EX5 SHA-256 `f0f7faafebc99819cac1eff9c492a4b7b087d9fcecbda27f24de2d907bd8d681`.
- Source remains at commit `f31f2ea4b9e33be04f351d62d33edb15b00eb38f` (2026-08-23).
- The card-required RSI(2)>75 exit and ten-D1-bar time stop are evaluated only after `Strategy_NoTradeFilter()` (`mq5:188-193`). Entry-only warm-up/spread conditions can therefore suspend exits.
- The source uses D1 indicators but a bare chart-period `QM_IsNewBar()` (`mq5:217`) and declares no D1 execution contract in `OnInit`.
- The approved index-proxy contract is `SP500.DWX`, `NDX.DWX`, and `WS30.DWX`; the spec and package expand it to 13 symbols.

## Focused verification

- `validate_build_guardrails.py` returned `PASS` with `max_news_stale_hours=336` and no findings for all five current MQ5 files at 2026-08-24T13:56Z. The semantic defects above are outside that static guard's proof scope.
- Set audit returned 13 files per EA, with zero violations of `RISK_FIXED > 0`, `RISK_PERCENT = 0`, or the 336-hour maximum.
- Current source commits/hashes, approved card mechanics, source control-flow ordering, specs, and packaged set counts were read directly from the canonical checkout and approved-card store.

## Required next action

Repair each task's cited source/spec/universe defects, generate a fresh governed build identity, and resubmit for independent Codex review. Do not self-approve the Gemini outputs or move them to the pipeline from this artifact.
