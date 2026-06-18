#property strict
#property version   "5.0"
#property description "QM5_11820 carter-m5-s9-ema50100-macd-m5 — EMA(50/100) trend + MACD-histogram zero-cross trigger, ATR stop/target, EMA(50)-break exit (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11820 carter-m5-s9-ema50100-macd-m5
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         System #9, self-published 2014.
// Card: artifacts/cards_approved/QM5_11820_carter-m5-s9-ema50100-macd-m5.md
//       (g0_status APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1; both directions):
//   Trend STATE   : EMA(50) > EMA(100)  -> long bias   (uptrend)
//                   EMA(50) < EMA(100)  -> short bias   (downtrend)
//   Trigger EVENT : MACD HISTOGRAM (= MACD main - MACD signal) crosses ABOVE
//                   zero for longs / BELOW zero for shorts, within the last
//                   macd_lookback (5) closed bars. ONE crossover event evaluated
//                   over a lookback window — the EMA(50/100) stack is the STATE,
//                   the histogram zero-cross is the single EVENT. This avoids the
//                   two-cross-same-bar zero-trade trap (a fresh EMA cross AND a
//                   fresh histogram cross almost never coincide).
//   Stop          : entry -/+ sl_atr_mult (2.0) * ATR(14).
//   Take profit   : entry +/- tp_atr_mult (4.0) * ATR(14) (same ATR as the stop).
//   Defensive exit: price (close[1]) crosses back through EMA(50) against the
//                   trade by exit_break_pips (10p) — below EMA(50) for longs,
//                   above for shorts. Closes the position manually (separate from
//                   the ATR SL/TP). Per the source's "close if price breaks EMA50
//                   by 10 pips" note.
//   No-Friday-entry: skip new entries on Friday (broker time).
//   Spread guard  : skip only a genuinely wide spread (fail-open on .DWX zero
//                   modeled spread).
//
// Differs from sibling QM5_11550: this card uses a FIXED ATR stop/target (not a
// capped structural stop) and has NO partial-close / breakeven leg — the trigger
// is the MACD HISTOGRAM zero-cross (not the MACD-main zero-cross).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11820;
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
input int    strategy_ema_fast_period   = 50;     // trend fast EMA
input int    strategy_ema_slow_period   = 100;    // trend slow EMA
input int    strategy_macd_fast         = 12;     // MACD fast EMA
input int    strategy_macd_slow         = 26;     // MACD slow EMA
input int    strategy_macd_signal       = 9;      // MACD signal SMA
input int    strategy_macd_lookback     = 5;      // histogram zero-cross within last N closed bars
input int    strategy_atr_period        = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult       = 2.0;    // stop distance  = mult * ATR
input double strategy_tp_atr_mult       = 4.0;    // target distance = mult * ATR
input int    strategy_exit_break_pips   = 10;     // EMA(50) break (pips) closes the position
input bool   strategy_no_friday_entry   = true;   // block new entries on Friday
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// MACD histogram (= main - signal) at a given closed-bar shift.
// -----------------------------------------------------------------------------
double MacdHistogram(const int shift)
  {
   const double main_v   = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                        strategy_macd_slow, strategy_macd_signal, shift);
   const double signal_v = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                          strategy_macd_slow, strategy_macd_signal, shift);
   return (main_v - signal_v);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (regime/signal work is on the
// closed-bar path). Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop-distance reference for the spread cap (ATR-derived, scales per symbol).
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

// Returns true and fills `req` if a fresh entry should fire on this closed bar.
// Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // No-Friday-entry filter (broker time).
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- Trend STATE: EMA(50)/EMA(100) stack (closed bar) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const bool long_state  = (ema_fast > ema_slow);
   const bool short_state = (ema_fast < ema_slow);
   if(!long_state && !short_state)
      return false; // flat stack — no trend bias

   // --- Trigger EVENT: MACD histogram zero-cross in the trend direction within
   //     the last macd_lookback closed bars. ONE crossover event over a window —
   //     the EMA stack is the STATE, not a second event on the same bar. ---
   bool macd_trigger = false;
   const int last_shift = strategy_macd_lookback; // shifts 1..lookback (each cross uses shift & shift+1)
   for(int s = 1; s <= last_shift; ++s)
     {
      const double h_now  = MacdHistogram(s);
      const double h_prev = MacdHistogram(s + 1);
      if(long_state  && h_prev <= 0.0 && h_now > 0.0) { macd_trigger = true; break; }
      if(short_state && h_prev >= 0.0 && h_now < 0.0) { macd_trigger = true; break; }
     }
   if(!macd_trigger)
      return false;

   // --- Direction + entry price ---
   const QM_OrderType side = long_state ? QM_BUY : QM_SELL;
   const double entry = long_state ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Stop / target: fixed ATR multiples off the same ATR value. ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = long_state ? "carter_macd_long" : "carter_macd_short";
   return true;
  }

// No active trade management beyond the fixed ATR stop/target. The defensive
// EMA(50)-break exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: price breaks back through EMA(50) by exit_break_pips against
// the trade — below EMA(50) for longs, above for shorts. Direction is read from
// the live position so the test is correct for either side.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   if(ema_fast <= 0.0)
      return false;
   const double close1 = QM_EMA(_Symbol, _Period, 1, 1); // EMA(1)=close[1], scale-correct closed-bar close
   if(close1 <= 0.0)
      return false;

   const double brk = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_exit_break_pips);
   if(brk <= 0.0)
      return false;

   // Direction from the live position for this EA's magic.
   bool is_buy   = false;
   bool found    = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_buy = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      found  = true;
      break;
     }
   if(!found)
      return false;

   // Long: close if close[1] breaks below EMA(50) by brk. Short: mirror above.
   if(is_buy)
      return (close1 < (ema_fast - brk));
   return (close1 > (ema_fast + brk));
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
