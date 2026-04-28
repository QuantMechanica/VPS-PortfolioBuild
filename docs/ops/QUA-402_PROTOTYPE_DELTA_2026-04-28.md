# QUA-402 Prototype-to-Production Delta (2026-04-28)

Issue: `QUA-402`  
Card: `QUA-342` / `SRC04_S03`  
Reference prototype: `C:/QM/worktrees/pipeline-operator/framework/EAs/QM5_SRC04_S03_lien_fade_double_zeros/QM5_SRC04_S03_lien_fade_double_zeros.mq5`

## Objective
Capture exact deltas needed to convert the existing P1 prototype into a V5 production EA once `ea_id` allocation is available.

## Mandatory Deltas
1. **Identity + naming compliance**
- Replace prototype `qm_ea_id = 40303` with allocated numeric registry `ea_id`.
- Move to required path/name: `framework/EAs/QM5_<ea_id>_lien_fade_double_zeros/QM5_<ea_id>_lien_fade_double_zeros.mq5`.

2. **Card-citation inline comments**
- Add card section citations at each rule edge:
  - round-number anchor logic (Card §4)
  - 10-15 pip entry offset and 20 pip stop offset (Card §4)
  - +1R half close + BE move (Card §5)
  - trailing method default (Card §5)
  - optional triple-zero/confluence mode off by default (Card §6)

3. **V5 module structure alignment**
- Refactor `OnStrategyBar/ApplyTrailLogic` logic into named functions:
  - `Strategy_EntrySignal`
  - `Strategy_ManageOpenPosition`
  - `Strategy_ExitSignal`
- Keep no-trade gating in framework path (`QM_KillSwitchCheck`, `QM_NewsAllowsTrade`, `QM_FrameworkHandleFridayClose`).

4. **Input naming normalization**
- Preserve required groups and risk inputs.
- Prefix strategy inputs consistently with `strategy_` to match neighboring EA conventions.

5. **News mode default review**
- Prototype uses `qm_news_mode = QM_NEWS_OFF`; verify with CTO whether `QM_NEWS_PAUSE` is required default in this cohort before submission.

## Items Already Compatible in Prototype
- Uses `#include <QM/QM_Common.mqh>`.
- Uses framework init/shutdown and kill-switch/news/friday-close hooks.
- Uses `QM_Magic(...)` path (not hand-computed magic).
- Contains both `RISK_PERCENT` and `RISK_FIXED` inputs.
- No hardcoded symbol (uses `_Symbol`).

## Post-Unblock Execution Order
1. Apply allocated `ea_id` row in registry (CTO).
2. Clone prototype logic into compliant `QM5_<ea_id>...` file and perform deltas above.
3. Compile target EA clean (no warnings / no build_check violations).
4. Produce CTO EA-vs-Card handoff; no pipeline dispatch.
