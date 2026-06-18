#property strict
#property version   "5.0"
#property description "QM5_12427 ea31337-rsi — EA31337 RSI threshold/momentum reversal (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12427 ea31337-rsi
// -----------------------------------------------------------------------------
// Source: EA31337 Strategy-RSI (Stg_RSI.mqh SignalOpen()).
//   https://github.com/EA31337/Strategy-RSI/blob/master/Stg_RSI.mqh
// Card: artifacts/cards_approved/QM5_12427_ea31337-rsi.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1, RSI period 16 on weighted price):
//   EA31337 SignalOpenLevel = 24 -> long band 50-24=26, short band 50+24=74.
//   Long:
//     STATE  : RSI(1) < (50 - level)                       (oversold zone)
//     EVENT  : RSI(1) > RSI(2)                             (RSI turning up)
//     STATE  : RSI(1) - RSI(3) >= level/10                 (2-bar momentum, +2.4)
//   Short (mirror):
//     STATE  : RSI(1) > (50 + level)
//     EVENT  : RSI(1) < RSI(2)
//     STATE  : RSI(3) - RSI(1) >= level/10
//   The single trigger is the turn (RSI(1) vs RSI(2)). The threshold-band and
//   the 2-bar percent-move are STATES, not a second cross EVENT — this avoids
//   the .DWX two-cross-same-bar zero-trade trap.
//
//   Stop   : ATR-based (source stop method 1/level 2 not directly portable ->
//            V5 framework default ATR stop, per card Stop Loss note).
//   Take   : RR multiple of the stop distance.
//   Exits  : (a) time exit after exit_max_bars closed bars held;
//            (b) opposite RSI signal (long open + fresh short trigger, or vice
//                versa) closes early.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12427;
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
input int    strategy_rsi_period         = 16;     // EA31337 RSI period (weighted price)
input double strategy_signal_level       = 24.0;   // EA31337 SignalOpenLevel (band offset from 50)
input int    strategy_atr_period         = 14;     // ATR period for the stop
input double strategy_sl_atr_mult        = 2.0;    // stop distance = mult * ATR
input double strategy_tp_rr              = 1.5;    // take-profit RR multiple of the stop
input int    strategy_exit_max_bars      = 30;     // EA31337 close-time: exit after N bars held
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Shared RSI signal evaluation (closed-bar). Returns +1 long / -1 short / 0.
// -----------------------------------------------------------------------------
int RsiSignal()
  {
   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1, PRICE_WEIGHTED);
   const double rsi2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2, PRICE_WEIGHTED);
   const double rsi3 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 3, PRICE_WEIGHTED);
   if(rsi1 <= 0.0 || rsi2 <= 0.0 || rsi3 <= 0.0)
      return 0;

   const double long_band  = 50.0 - strategy_signal_level;   // default 26
   const double short_band = 50.0 + strategy_signal_level;   // default 74
   const double min_move   = strategy_signal_level / 10.0;    // default 2.4

   // Long: oversold STATE + RSI turning up EVENT + 2-bar up-move STATE.
   if(rsi1 < long_band && rsi1 > rsi2 && (rsi1 - rsi3) >= min_move)
      return 1;

   // Short: overbought STATE + RSI turning down EVENT + 2-bar down-move STATE.
   if(rsi1 > short_band && rsi1 < rsi2 && (rsi3 - rsi1) >= min_move)
      return -1;

   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
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

   const int sig = RsiSignal();
   if(sig == 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(sig > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ea31337_rsi_long";
      return true;
     }

   // sig < 0 -> short
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "ea31337_rsi_short";
   return true;
  }

// Fixed ATR stop/RR target carry the position; no active trailing.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: time stop (>= exit_max_bars held) OR opposite RSI signal.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find this EA's open position to read its direction + open time.
   long pos_type = -1;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type  = PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(pos_type < 0)
      return false;

   // Time exit: bars held = elapsed broker seconds / bar seconds. Pure time
   // math (no iTime/Bars strategy reads). PeriodSeconds() is framework-safe.
   const int bar_secs = PeriodSeconds(_Period);
   if(bar_secs > 0 && open_time > 0)
     {
      const long held_bars = (long)((TimeCurrent() - open_time) / bar_secs);
      if(held_bars >= strategy_exit_max_bars)
         return true;
     }

   // Opposite-signal exit: long open + fresh short trigger, or short open +
   // fresh long trigger.
   const int sig = RsiSignal();
   if(pos_type == POSITION_TYPE_BUY && sig < 0)
      return true;
   if(pos_type == POSITION_TYPE_SELL && sig > 0)
      return true;

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
