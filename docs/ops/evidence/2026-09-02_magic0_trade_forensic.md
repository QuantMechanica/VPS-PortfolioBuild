# DXZ account 4000090541 — magic=0 trade forensic

Task: `ee18d088-24e6-4aee-9400-4e5b83625efa`. Read-only review for the 2026-09-06 OWNER session.

## Attribution verdict

The two questioned **closing deals are not two untagged positions**:

1. **EURUSD position 3168177717 is conclusively QM5_11421.** Its entry deal `148992255` carries magic `114210000` and comment `squeeze_long_buystop`; the EA log records `ENTRY_ACCEPTED`/`TM_OPEN` for ticket 3168177717. At `2026-07-24T17:59:57Z` the same EA records `FRIDAY_CLOSE {closed:1}`. The terminal journal then records the 0.43-lot close order `3168855887`, and only that broker closing deal has magic 0/empty comment. Position-lifecycle attribution must inherit the opening magic. Net lifecycle loss is **-$262.00** including the opening commission (-$1.23) and closing net (-$260.77). This is neither manual nor orphaned.

2. **NDX position 3169151197 remains external/manual-unknown, not a governed sleeve.** It opened long 1.00 lot at 28537.2 (`2026-07-27T11:53:04Z`) and was SL-closed at 28383.8 (`13:33:06Z`), total net **-$1,539.50** including both -$2.75 commissions. Both deals have magic 0 and the entry comment is empty; the close comment is `[sl 28385.0]`. The terminal journal contains only server deal notifications for the open and close—there is no local request/accepted/order sequence. No per-EA log contains the position/order/deal IDs or a matching entry event. The active NDX charts are QM5_13128 and QM5_10440, whose configured registry magics are nonzero; neither produced this trade. Its 1.00-lot size also does not match their governed entries.

The available export records magic and comment but not MT5 `DEAL_REASON`, so it cannot distinguish desktop-manual, mobile/web, another terminal, copier, or an ungoverned EA that emitted magic 0. The defensible label is therefore **external/manual-unknown (high confidence it is outside the 24-sleeve book; origin subtype unresolved)**. OWNER/broker history with `DEAL_REASON` is needed for the final subtype.

## Evidence paths

- `C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\journal\live_deals_normalized.csv`, rows 48, 56, 62, 64; header shows no reason/origin field.
- `C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\QM5_11421_ea-11421.log`, lines 482–483 and 529–530.
- `C:\QM\mt5\T_Live\MT5_Base\logs\20260722.log`, lines 155–157 (EUR order); `20260723.log`, line 20 (fill); `20260724.log`, lines 75–84 (Friday close); `20260727.log`, lines 40 and 46 (NDX server notifications).
- `C:\QM\mt5\T_Live\MT5_Base\MQL5\Profiles\Charts\DarwinexZero_V2_LiveOps\chart10.chr` (QM5_13128/NDX) and `chart11.chr` (QM5_10440/NDX), both `expertmode=1` with nonzero registry identities.
- Export implementation: `framework\monitor\QM_AccountMonitor.mq5`, lines 613–616 (magic, position and comment fields).

Focused verification repeated exact-ID searches across every T_Live terminal journal and per-EA JSONL log, checked both NDX chart blocks, and reconciled all deals by `position_id`. No T_Live file, terminal state, sealed rule, or database row was changed.
