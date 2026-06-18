#property strict
#property version   "5.0"
#property description "QM5_11639 robo-ma6-35-150-365-h1 — RoboForex 'Base 150' four-SMA stack (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11639 robo-ma6-35-150-365-h1
// -----------------------------------------------------------------------------
// Source: RoboForex Educational Team, "Forex Strategy Collection" (~2015),
//         strategy "Base 150", pages 78-79.
// Card: artifacts/cards_approved/QM5_11639_robo-ma6-35-150-365-h1.md (APPROVED).
//
// Mechanics (closed-bar reads at shift 1; SMA 6/35/150/365 on H1):
//   The slow-MA stack (35/150/365) + the SMA150 "base" define the trend STATE.
//   The SMA6 cross of SMA35 in that trend direction is the single trigger EVENT.
//
//   LONG  STATE : close1 > SMA150  AND  SMA150 slope up (SMA150[1] > SMA150[2])
//                 AND  close1 > SMA365  AND  SMA35 > SMA150 (stack aligned up).
//   LONG  EVENT : SMA6 crosses up through SMA35 (SMA6[2] <= SMA35[2] &&
//                                                SMA6[1] >  SMA35[1]).
//   SHORT STATE : close1 < SMA150  AND  SMA150 slope down (SMA150[1] < SMA150[2])
//                 AND  close1 < SMA365  AND  SMA35 < SMA150 (stack aligned down).
//   SHORT EVENT : SMA6 crosses down through SMA35.
//
//   Two-cross trap avoided: ONLY the SMA6/SMA35 cross is an EVENT; everything
//   else (base position, slope, 365 confirmation, stack order) is a STATE read
//   on the same closed bar.
//
//   Stop         : 2*ATR(14) from entry (card factory default; structural ref
//                  SMA35/SMA150).  Take profit : 4*ATR(14) (RR via same ATR).
//   Defensive exit: opposite SMA6/SMA35 cross -> close manually.
//   Spread guard : block only a genuinely wide spread (.DWX models 0 spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11639;
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
input int    strategy_sma_fast_period   = 6;     // SMA6   — short-term trigger MA
input int    strategy_sma_med_period    = 35;    // SMA35  — medium-term MA (cross partner)
input int    strategy_sma_base_period   = 150;   // SMA150 — the "base" / central trend
input int    strategy_sma_long_period   = 365;   // SMA365 — very long-term confirmation
input int    strategy_atr_period        = 14;    // ATR period (stop / target)
input double strategy_sl_atr_mult       = 2.0;   // stop distance  = mult * ATR
input double strategy_tp_atr_mult       = 4.0;   // target distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

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
      return false; // no ATR yet — defer to entry gate, do not block here

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

   // --- All four SMAs on the last closed bar (shift 1). ---
   const double sma6_1   = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   const double sma35_1  = QM_SMA(_Symbol, _Period, strategy_sma_med_period,  1);
   const double sma150_1 = QM_SMA(_Symbol, _Period, strategy_sma_base_period, 1);
   const double sma365_1 = QM_SMA(_Symbol, _Period, strategy_sma_long_period, 1);
   if(sma6_1 <= 0.0 || sma35_1 <= 0.0 || sma150_1 <= 0.0 || sma365_1 <= 0.0)
      return false;

   // Prior-bar values for the cross EVENT (SMA6/SMA35) and the base slope STATE.
   const double sma6_2   = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 2);
   const double sma35_2  = QM_SMA(_Symbol, _Period, strategy_sma_med_period,  2);
   const double sma150_2 = QM_SMA(_Symbol, _Period, strategy_sma_base_period, 2);
   if(sma6_2 <= 0.0 || sma35_2 <= 0.0 || sma150_2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- LONG: trend STATE (stack up + base + 365) + SMA6/SMA35 cross-up EVENT.
   const bool long_state = (close1   > sma150_1) &&            // above the base
                           (sma150_1 > sma150_2) &&            // base slope up
                           (close1   > sma365_1) &&            // long-term confirm
                           (sma35_1  > sma150_1);              // stack aligned up
   const bool long_event = (sma6_2 <= sma35_2) && (sma6_1 > sma35_1);

   // --- SHORT: mirror.
   const bool short_state = (close1   < sma150_1) &&
                            (sma150_1 < sma150_2) &&
                            (close1   < sma365_1) &&
                            (sma35_1  < sma150_1);
   const bool short_event = (sma6_2 >= sma35_2) && (sma6_1 < sma35_1);

   QM_OrderType dir;
   if(long_state && long_event)
      dir = QM_BUY;
   else if(short_state && short_event)
      dir = QM_SELL;
   else
      return false;

   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, dir, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, dir, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir == QM_BUY) ? "base150_long" : "base150_short";
   return true;
  }

// No active management beyond the fixed ATR stop/target. Defensive exit below.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: opposite SMA6/SMA35 cross relative to the open position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double sma6_1  = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   const double sma35_1 = QM_SMA(_Symbol, _Period, strategy_sma_med_period,  1);
   const double sma6_2  = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 2);
   const double sma35_2 = QM_SMA(_Symbol, _Period, strategy_sma_med_period,  2);
   if(sma6_1 <= 0.0 || sma35_1 <= 0.0 || sma6_2 <= 0.0 || sma35_2 <= 0.0)
      return false;

   const bool cross_down = (sma6_2 >= sma35_2) && (sma6_1 < sma35_1);
   const bool cross_up   = (sma6_2 <= sma35_2) && (sma6_1 > sma35_1);

   // Determine the side of the open position for this magic.
   bool is_long = false;
   bool found   = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      found   = true;
      break;
     }
   if(!found)
      return false;

   if(is_long && cross_down)
      return true;   // long position, fast crosses below medium -> exit
   if(!is_long && cross_up)
      return true;   // short position, fast crosses above medium -> exit

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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
