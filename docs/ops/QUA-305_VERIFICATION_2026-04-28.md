# QUA-305 Verification Snapshot

Date: 2026-04-28
Issue: QUA-305

## Evidence from EA source

```text
3:#property description "QM5_1004 Davey ES Breakout (SRC01_S04)"
4:// Strategy Card: SRC01_S04 (davey-es-breakout), CEO G0 APPROVED.
6:#include <QM/QM_Common.mqh>
9:input group "QuantMechanica V5 Framework"
13:input group "Risk"
14:input double RISK_PERCENT                 = 0.0;
15:input double RISK_FIXED                   = 1000.0;
18:input group "News"
21:input group "Friday Close"
25:input group "Strategy"
26:input int    breakout_lookback            = 20;   // Card §6
27:input int    strategy_atr_period                   = 14;   // Card §6
28:input double atr_stop_mult                = 2.0;  // Card §4/§6
35:   // Hard rule: magic must be derived via QM_Magic(ea_id, slot).
36:   return QM_Magic(qm_ea_id, qm_magic_slot_offset);
84:   // Card §4: protective ATR stop from entry.
96:   // Card §3: previous bar close must break above prior lookback highs.
111:   // Card §3: previous bar close must break below prior lookback lows.
121:bool Strategy_EntrySignal(QM_EntryRequest &req)
140:      req.reason = "SRC01_S04_LONG_BREAKOUT";
149:      req.reason = "SRC01_S04_SHORT_BREAKOUT";
156:void Strategy_ManageOpenPosition()
158:   // Card §4: no trailing/partial logic; maintain protective stop only.
178:bool Strategy_ExitSignal()
180:   // Card §4/§8: no standalone close signal.
220:      // Card §3/§4: opposite breakout closes and reverses.
233:                        RISK_PERCENT,
234:                        RISK_FIXED,
241:   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"SRC01_S04\",\"ea\":\"QM5_1004_davey_es_breakout\"}");
263:   Strategy_ManageOpenPosition();
264:   if(Strategy_ExitSignal())
268:   if(Strategy_EntrySignal(req))
```
