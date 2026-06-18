#property strict
#property version   "5.0"
#property description "QM5_11386 4h-macd513-ema-cascade-zero-cross — H4 MACD(5,13,1) zero-cross + EMA(365) trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11386 4h-macd513-ema-cascade-zero-cross
// -----------------------------------------------------------------------------
// Source: "4 Hour MACD Forex Strategy" (anonymous PDF, contact prbain@tradingsmart.com).
// Card: artifacts/cards_approved/QM5_11386_4h-macd513-ema-cascade-zero-cross.md
//       (g0_status APPROVED). Source ID be088e52-82be-5132-9057-cf081d189aa3.
//
// Mechanics (closed-bar reads at shift 1; H4):
//   Trend STATE (EMA(365) trend filter — the "cascade" anchor):
//     LONG  : EMA365 sloping up  (EMA365@1 > EMA365@6, a 5-bar / 20H slope window)
//             AND close@1 > EMA365@1.
//     SHORT : EMA365 sloping down (EMA365@1 < EMA365@6) AND close@1 < EMA365@1.
//   Trigger EVENT (the SINGLE event; MACD can be negative — NO sign-as-validity guard):
//     MACD(5,13,1) histogram (signal=1 -> MODE_MAIN is the histogram value) crosses zero.
//     LONG  : macd@2 <= 0  AND  macd@1 > 0   (fresh cross UP through zero).
//     SHORT : macd@2 >= 0  AND  macd@1 < 0   (fresh cross DOWN through zero).
//   The EMA cascade is a STATE, the MACD zero-cross is the one EVENT — never two
//   cross-events on the same bar (avoids the two-cross zero-trade trap).
//   Stop         : ATR(14) * sl_atr_mult from entry.
//   Take profit  : ATR(14) * tp_atr_mult from entry (same ATR value as the stop).
//   Management   : move SL to breakeven once price has advanced +be_trigger_atr * ATR.
//   Spread guard : block ONLY a genuinely wide spread (> spread_pct_of_stop of the
//                  stop distance). Fail-OPEN on .DWX zero modeled spread.
//
// MACD-validity note: QM_MACD_Main returns 0.0 both for a true zero crossing and
// for a failed read. The histogram legitimately spans negative values, so we do
// NOT treat sign/zero of the MACD as a readiness flag. Readiness is gated on the
// strictly-positive EMA(365) / ATR reads instead, which share the same closed
// H4 bars; if those are valid the MACD reads on the same bars are valid too.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11386;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_macd_fast         = 5;      // MACD fast EMA period
input int    strategy_macd_slow         = 13;     // MACD slow EMA period
input int    strategy_macd_signal       = 1;      // MACD signal period (1 = histogram is MACD line)
input int    strategy_ema_trend_period  = 365;    // EMA(365) trend filter / cascade anchor
input int    strategy_ema_slope_bars    = 5;      // slope window (bars) for the EMA(365) trend
input int    strategy_atr_period        = 14;     // ATR period (stop / target / management)
input double strategy_sl_atr_mult       = 1.5;    // stop distance = mult * ATR
input double strategy_tp_atr_mult       = 3.0;    // target distance = mult * ATR
input double strategy_be_trigger_atr    = 1.0;    // move SL to breakeven at +mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip only if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// a 0 / negative modeled spread is never a reason to block.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Readiness via strictly-positive reads (NOT via the MACD sign) ---
   const double ema_now   = QM_EMA(_Symbol, _Period, strategy_ema_trend_period, 1);
   const double ema_slope = QM_EMA(_Symbol, _Period, strategy_ema_trend_period,
                                   1 + strategy_ema_slope_bars);
   if(ema_now <= 0.0 || ema_slope <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- Trigger EVENT: MACD(5,13,1) zero-line cross (signal=1 -> MODE_MAIN) ---
   // MACD legitimately runs negative; do NOT guard on its sign for validity.
   const double macd_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, 2);

   const bool trend_up   = (ema_now > ema_slope) && (close1 > ema_now);
   const bool trend_down = (ema_now < ema_slope) && (close1 < ema_now);

   const bool cross_up   = (macd_prev <= 0.0 && macd_now > 0.0);
   const bool cross_down = (macd_prev >= 0.0 && macd_now < 0.0);

   QM_OrderType side;
   if(trend_up && cross_up)
      side = QM_BUY;
   else if(trend_down && cross_down)
      side = QM_SELL;
   else
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "macd513_zerocross_long" : "macd513_zerocross_short";
   return true;
  }

// Move SL to breakeven once price has advanced +be_trigger_atr * ATR.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;

   // Breakeven trigger expressed in pips so the framework helper can scale it.
   const double trig_dist = strategy_be_trigger_atr * atr_value;
   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(pip <= 0.0)
      return;
   const int trig_pips = (int)MathRound(trig_dist / pip);
   if(trig_pips <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_MoveToBreakEven(ticket, trig_pips, 2);
     }
  }

// No discretionary exit beyond the fixed ATR stop/target + breakeven shift.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
