#property strict
#property version   "5.0"
#property description "QM5_1613 Alpha Architect DSP Averaged TSMOM 3-6-9-12"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1613
// -----------------------------------------------------------------------------
// Card: aa-dsp-atsmom (source ede348b4-0fa7-5be1-baa8-09e9089b67b7)
// Henry Stern, "An Introduction to Digital Signal Processing for Trend Following",
// Alpha Architect (2020-08-13, updated 2025-03).
//
// Strategy logic:
//   Averaged Time Series Momentum (3, 6, 9, 12 lookbacks):
//   ATSMOM = 0.7043 * (Close(1) - 0.25*Close(4) - 0.25*Close(7) - 0.25*Close(10) - 0.25*Close(13))
//   where Close(k) is the completed daily close shifted by k bars.
//
// Entry:
//   Long : ATSMOM(1) > 0.0
//   Short: ATSMOM(1) < 0.0
//
// Exit:
//   Long : ATSMOM(1) <= 0.0
//   Short: ATSMOM(1) >= 0.0
//
// Stop Loss:
//   2.5 * ATR(20, D1)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1613;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_min_daily_bars     = 30;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 2.5;
input int    strategy_spread_median_days = 20;
input double strategy_spread_median_mult = 2.5;

// -----------------------------------------------------------------------------
// Helper functions
// -----------------------------------------------------------------------------

bool ReadD1Close(const int shift, double &value)
{
   value = 0.0;
   double buf[];
   if(ArrayResize(buf, 1) != 1)
      return false;
   ArraySetAsSeries(buf, true);
   const int got = CopyClose(_Symbol, PERIOD_D1, shift, 1, buf); // perf-allowed: bounded one-close read behind the D1 new-bar gate.
   if(got != 1 || ArraySize(buf) < 1 || buf[0] <= 0.0)
      return false;
   value = buf[0];
   return true;
}

bool ComputeATSMOM(const int shift, double &val)
{
   val = 0.0;
   double c1 = 0.0, c4 = 0.0, c7 = 0.0, c10 = 0.0, c13 = 0.0;
   if(!ReadD1Close(shift, c1) ||
      !ReadD1Close(shift + 3, c4) ||
      !ReadD1Close(shift + 6, c7) ||
      !ReadD1Close(shift + 9, c10) ||
      !ReadD1Close(shift + 12, c13))
      return false;
   val = 0.7043 * (c1 - 0.25 * c4 - 0.25 * c7 - 0.25 * c10 - 0.25 * c13);
   return true;
}

bool Strategy_SpreadAllowsEntry()
{
   if(strategy_spread_median_days < 2 || strategy_spread_median_mult <= 0.0)
      return false;

   int spreads[];
   if(ArrayResize(spreads, strategy_spread_median_days) != strategy_spread_median_days)
      return false;

   const int copied = CopySpread(_Symbol,
                                 PERIOD_D1,
                                 1,
                                 strategy_spread_median_days,
                                 spreads); // perf-allowed: bounded completed-D1 sample behind the D1 new-bar gate.
   if(copied != strategy_spread_median_days || ArraySize(spreads) < strategy_spread_median_days)
      return false;

   for(int i = 0; i < ArraySize(spreads); ++i)
   {
      if(spreads[i] <= 0)
         return false;
   }
   ArraySort(spreads);

   const int upper = copied / 2;
   if(upper <= 0 || upper >= ArraySize(spreads))
      return false;
   const double median_spread = ((copied % 2) == 0)
                                ? ((double)spreads[upper - 1] + (double)spreads[upper]) * 0.5
                                : (double)spreads[upper];
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(median_spread <= 0.0 || current_spread <= 0)
      return false;

   return ((double)current_spread <= strategy_spread_median_mult * median_spread);
}

bool Strategy_HasOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
   }
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(_Period != PERIOD_D1)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(qm_friday_close_enabled && dt.day_of_week == 5 && dt.hour >= qm_friday_close_hour_broker)
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_D1)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   const int required_history = (strategy_min_daily_bars > strategy_spread_median_days)
                                ? strategy_min_daily_bars
                                : strategy_spread_median_days;
   if(Bars(_Symbol, PERIOD_D1) < required_history + 2)
      return false;

   if(!Strategy_SpreadAllowsEntry())
      return false;

   double atsmom1 = 0.0;
   if(!ComputeATSMOM(1, atsmom1))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   bool has_signal = false;

   if(atsmom1 > 0.0)
   {
      side = QM_BUY;
      has_signal = true;
   }
   else if(atsmom1 < 0.0)
   {
      side = QM_SELL;
      has_signal = true;
   }

   if(!has_signal)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "AA_DSP_ATSMOM_LONG" : "AA_DSP_ATSMOM_SHORT";
   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      double atsmom1 = 0.0;
      if(!ComputeATSMOM(1, atsmom1))
         return false;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && atsmom1 <= 0.0)
         return true;
      if(ptype == POSITION_TYPE_SELL && atsmom1 >= 0.0)
         return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
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
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   // Protective management remains tick-responsive. Card-defined signal work
   // below runs exactly once for each newly completed D1 bar.
   Strategy_ManageOpenPosition();

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   QM_EquityStreamOnNewBar();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(Strategy_NoTradeFilter())
      return;

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
