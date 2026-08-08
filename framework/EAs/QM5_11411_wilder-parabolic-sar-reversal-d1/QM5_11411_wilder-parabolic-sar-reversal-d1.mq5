#property strict
#property version   "5.0"
#property description "QM5_11411 Wilder Parabolic SAR reversal D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Strategy Card: QM5_11411 wilder-parabolic-sar-reversal-d1
// Source: J. Welles Wilder Jr., New Concepts in Technical Trading Systems
//         (1978), Section II: Parabolic Time/Price System.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11411;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;    // live setfiles select 0.5%
input double RISK_FIXED                 = 1000.0; // tester default
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_sar_step             = 0.02;
input double strategy_sar_maximum          = 0.20;
input bool   strategy_use_di_filter        = false;
input int    strategy_di_period            = 14;
input int    strategy_max_sl_pips          = 100;
input int    strategy_spread_cap_pips      = 25;

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// No strategy-specific time gate exists. Parameter validation lives here;
// the card's spread cap is entry-only so it cannot suspend risk management.
bool Strategy_NoTradeFilter()
  {
   if(strategy_sar_step <= 0.0 ||
      strategy_sar_maximum <= strategy_sar_step ||
      strategy_di_period <= 0 ||
      strategy_max_sl_pips <= 0 ||
      strategy_spread_cap_pips <= 0)
      return true;
   return false;
  }

// Closed-bar PSAR flip. When flat without a fresh flip, seed the current PSAR
// side so the source's always-in-market rule survives startup/Friday closure.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   MqlRates signal_bar;
   MqlRates previous_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, signal_bar) ||
      !QM_ReadBar(_Symbol, PERIOD_D1, 2, previous_bar))
      return false;

   const double sar_now = QM_SAR(_Symbol, PERIOD_D1,
                                 strategy_sar_step,
                                 strategy_sar_maximum,
                                 1);
   const double sar_previous = QM_SAR(_Symbol, PERIOD_D1,
                                      strategy_sar_step,
                                      strategy_sar_maximum,
                                      2);
   if(sar_now <= 0.0 || sar_previous <= 0.0 ||
      signal_bar.low <= 0.0 || signal_bar.high <= 0.0 ||
      previous_bar.low <= 0.0 || previous_bar.high <= 0.0)
      return false;

   const bool current_long = (sar_now < signal_bar.low);
   const bool current_short = (sar_now > signal_bar.high);
   const bool previous_long = (sar_previous < previous_bar.low);
   const bool previous_short = (sar_previous > previous_bar.high);
   const bool flip_long = (previous_short && current_long);
   const bool flip_short = (previous_long && current_short);

   int direction = 0;
   bool fresh_flip = false;
   if(flip_long)
     {
      direction = 1;
      fresh_flip = true;
     }
   else if(flip_short)
     {
      direction = -1;
      fresh_flip = true;
     }
   else if(current_long)
      direction = 1;
   else if(current_short)
      direction = -1;

   if(direction == 0)
      return false;

   if(strategy_use_di_filter)
     {
      const double plus_di = QM_ADX_PlusDI(_Symbol, PERIOD_D1,
                                           strategy_di_period, 1);
      const double minus_di = QM_ADX_MinusDI(_Symbol, PERIOD_D1,
                                             strategy_di_period, 1);
      if(plus_di <= 0.0 || minus_di <= 0.0)
         return false;
      if(direction > 0 && plus_di <= minus_di)
         return false;
      if(direction < 0 && minus_di <= plus_di)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(
      _Symbol, strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return false;
   if(ask > bid && (ask - bid) > spread_cap)
      return false;

   const QM_OrderType side = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? ask : bid;
   const double max_stop_distance = QM_StopRulesPipsToPriceDistance(
      _Symbol, strategy_max_sl_pips);
   if(max_stop_distance <= 0.0)
      return false;

   double sl = sar_now;
   if(direction > 0)
     {
      if(sl >= entry)
         return false;
      sl = MathMax(sl, entry - max_stop_distance);
     }
   else
     {
      if(sl <= entry)
         return false;
      sl = MathMin(sl, entry + max_stop_distance);
     }
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   if(sl <= 0.0 ||
      (direction > 0 && sl >= entry) ||
      (direction < 0 && sl <= entry))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   if(direction > 0)
      req.reason = fresh_flip ? "wilder_psar_flip_long" : "wilder_psar_seed_long";
   else
      req.reason = fresh_flip ? "wilder_psar_flip_short" : "wilder_psar_seed_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Advance the server-side SAR stop once per D1 calendar bar. The framework
// calendar helper keeps this O(1) per tick without consuming QM_IsNewBar().
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return;
   if(!QM_IsNewCalendarPeriod(PERIOD_D1))
      return;

   const double sar = QM_SAR(_Symbol, PERIOD_D1,
                             strategy_sar_step,
                             strategy_sar_maximum,
                             1);
   if(sar <= 0.0)
      return;
   const double normalized_sar = QM_StopRulesNormalizePrice(_Symbol, sar);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(normalized_sar <= 0.0 || bid <= 0.0 || ask <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(position_type == POSITION_TYPE_BUY &&
         normalized_sar < bid &&
         (current_sl <= 0.0 || normalized_sar > current_sl))
         QM_TM_MoveSL(ticket, normalized_sar, "wilder_psar_trail_long");
      else if(position_type == POSITION_TYPE_SELL &&
              normalized_sar > ask &&
              (current_sl <= 0.0 || normalized_sar < current_sl))
         QM_TM_MoveSL(ticket, normalized_sar, "wilder_psar_trail_short");
     }
  }

// Close once the just-closed D1 bar places PSAR on the opposite side of the
// position. A calendar key makes the closed-bar state a once-daily decision.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   static int processed_exit_key = 0;
   const int exit_key = QM_CalendarPeriodKey(PERIOD_D1);
   if(exit_key <= 0 || exit_key == processed_exit_key)
      return false;

   MqlRates signal_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, signal_bar))
      return false;
   const double sar = QM_SAR(_Symbol, PERIOD_D1,
                             strategy_sar_step,
                             strategy_sar_maximum,
                             1);
   if(sar <= 0.0 || signal_bar.low <= 0.0 || signal_bar.high <= 0.0)
      return false;

   processed_exit_key = exit_key;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY && sar > signal_bar.high)
         return true;
      if(position_type == POSITION_TYPE_SELL && sar < signal_bar.low)
         return true;
     }
   return false;
  }

// No card-specific news override; the central P8-callable gate remains active.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
   // Q08 evidence lifecycle: this must precede every early return.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Management and strategy exits remain active through news windows.
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

   // The central news gate blocks only new entries.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
