#property strict
#property version   "5.0"
#property description "QM5_11625 ba-ema-dual — Basana Dual EMA Crossover (symmetric long/short, H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11625 ba-ema-dual
// -----------------------------------------------------------------------------
// Source: Gabriel Martin Becedillas Ruiz / gbeced — Basana dual moving average
//   crossover sample (samples/strategies/dmac.py).
// Card: artifacts/cards_approved/QM5_11625_ba-ema-dual.md (g0_status APPROVED).
//
// Mechanics (symmetric long/short, closed-bar reads at shift 1/2, H4 base):
//   Trigger EVENT (the ONE trigger):
//     Long  : fast_ema[2] <= slow_ema[2]  AND  fast_ema[1] >  slow_ema[1]
//     Short : fast_ema[2] >= slow_ema[2]  AND  fast_ema[1] <  slow_ema[1]
//   Exit (signal-reversal, primary exit):
//     A bearish cross closes any open long; a bullish cross closes any open
//     short. The same cross that closes the old position opens the reverse one
//     (one position per magic — close happens first in OnTick, the new entry
//     fires on the same closed-bar new-bar gate).
//   Emergency stop: sl_atr_mult * ATR(atr_period) from entry price. No TP —
//     signal reversal is the designed exit (req.tp = 0.0 = none).
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of the
//     stop distance (fail-OPEN on .DWX zero modeled spread).
//
// Two-cross trap avoided: the EMA cross is the SINGLE trigger event. There is no
// second simultaneous cross/oscillator condition required on the same bar.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11625;
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
input int    strategy_ema_fast_period    = 12;    // fast EMA period (seed 12)
input int    strategy_ema_slow_period    = 26;    // slow EMA period (seed 26)
input int    strategy_atr_period         = 20;    // ATR period for the emergency stop
input double strategy_sl_atr_mult        = 3.0;   // emergency stop = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — crossover work is in
// Strategy_EntrySignal on the closed-bar path. Fail-OPEN on .DWX zero spread.
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

// Symmetric long/short entry on a fresh EMA cross. Caller guarantees
// QM_IsNewBar() == true (closed-bar gate). One position per symbol/magic.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic. (A reversal cross first closes the
   // existing position via Strategy_ExitSignal in OnTick; on the next new-bar
   // tick the reverse entry can then fire.)
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double fast1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast1 <= 0.0 || slow1 <= 0.0 || fast2 <= 0.0 || slow2 <= 0.0)
      return false;

   // The cross is the SINGLE trigger event (one direction per bar).
   const bool cross_up   = (fast2 <= slow2 && fast1 >  slow1);
   const bool cross_down = (fast2 >= slow2 && fast1 <  slow1);
   if(!cross_up && !cross_down)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(cross_up)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no TP — signal reversal is the exit
      req.reason = "ba_ema_dual_long";
      return true;
     }

   // cross_down
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = 0.0;
   req.reason = "ba_ema_dual_short";
   return true;
  }

// No active trade management beyond the fixed ATR emergency stop. The
// signal-reversal exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Signal-reversal exit: close a long on a bearish cross and a short on a bullish
// cross. One cross event at shift 1/2 — direction-aware vs the open position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double fast1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast1 <= 0.0 || slow1 <= 0.0 || fast2 <= 0.0 || slow2 <= 0.0)
      return false;

   const bool cross_up   = (fast2 <= slow2 && fast1 >  slow1);
   const bool cross_down = (fast2 >= slow2 && fast1 <  slow1);
   if(!cross_up && !cross_down)
      return false;

   // Find this EA's open position direction; reverse-cross closes it.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && cross_down)
         return true;
      if(pos_type == POSITION_TYPE_SELL && cross_up)
         return true;
     }
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
