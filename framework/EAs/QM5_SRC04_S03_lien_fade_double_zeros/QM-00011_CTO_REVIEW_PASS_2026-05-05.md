## QM-00011 CTO DL-036 Review PASS

- Task: `QM-00011`
- Date: `2026-05-05`
- EA: `QM5_SRC04_S03_lien_fade_double_zeros` (`ea_id=1009`)
- Strategy Card: `SRC04_S03` (`strategy-seeds/cards/lien-fade-double-zeros_card.md`)
- Verdict: `PASS`

### Hard-rule and Card Conformance Checks

- Entry rules match card:
  - 20 SMA trend-side filter on bar close: `mq5:188-190`, `mq5:214`, `mq5:225`
  - Stop entries offset from round number (`entry_offset_pips`): `mq5:205`, `mq5:209`
  - Long below MA / short above MA logic: `mq5:213-233`
- Exit/management rules match card:
  - 20-pip-class stop offset from figure (`stop_offset_pips` default 20): `mq5:35`, `mq5:206`, `mq5:210`
  - TP1-at-1R and partial close + BE progression: `mq5:253`, `mq5:262-272`, `mq5:287-296`
  - Trailing logic (2-bar default, MA variant optional): `mq5:272-307`
  - No standalone discretionary exit signal: `mq5:317-321`
- Filters match card/framework:
  - Kill-switch gate: `mq5:366-367`
  - News gate: `mq5:368-369`
  - Friday close hook default enabled: `mq5:29`, `mq5:370-371`
- Magic-number schema:
  - Uses framework resolver `QM_Magic(ea_id, slot)`: `mq5:44-48`
  - Position/order ownership by symbol+magic enforced: `mq5:111-114`, `mq5:129-132`
- Risk inputs present:
  - `RISK_FIXED` and `RISK_PERCENT` inputs exist: `mq5:21-22`
  - Framework init selects fixed in tester and percent live via AUTO mode path: `mq5:331-346`
- 4-module structure present:
  - No-Trade gates in `OnTick`: `mq5:366-371`
  - Entry module: `mq5:169-236`
  - Trade management: `mq5:238-315`
  - Trade close signal module: `mq5:317-321`
- No hardcoded symbol:
  - Uses `_Symbol` throughout for trading/data access.
- No external APIs / no ML imports:
  - No `WebRequest`, sockets, or ML libs referenced in EA source.

### Compile Evidence

- `framework/build/compile/20260501_091819/QM5_SRC04_S03_lien_fade_double_zeros.compile.log`
- Result: `0 errors, 0 warnings`.

### Next Action

- P1 evidence is now present in EA folder; Pipeline-Operator can promote to next phase gate (`P2`) for `QUA-743`.
