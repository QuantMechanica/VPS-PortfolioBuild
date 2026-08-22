#property strict
#property version   "5.0"
#property description "QM5_1345 Chan COT Speculator Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_1345 - Chan COT Speculator Momentum
// -----------------------------------------------------------------------------
// Structural momentum sleeve based on Ernest Chan COT / directional volume-flow
// momentum. Computes the ratio of cumulative upside to downside directional
// displacement over the formation lookback.
// Long entry when ratio >= 3.0 (bullish dominance); short entry when ratio <= 0.333
// (bearish dominance). Positions exit when ratio reverts across parity (1.0)
// or via 2.0x D1 ATR catastrophic stop.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1345;
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
input int    strategy_lookback_period   = 60;    // Lookback bars for directional momentum ratio
input double strategy_ratio_entry_long  = 3.0;   // Minimum ratio for long entry
input double strategy_ratio_entry_short = 0.333; // Maximum ratio for short entry
input double strategy_ratio_exit        = 1.0;   // Ratio exit threshold (parity)
input int    strategy_atr_period        = 14;    // ATR period for protective stop
input double strategy_atr_sl_mult       = 2.0;   // ATR stop multiplier
input int    strategy_max_hold_days     = 120;   // Max hold duration in trading days
input int    strategy_max_spread_points = 100;   // Max spread filter (points)

// Cached state updated on new bar
double g_cached_ratio = 1.0;
datetime g_last_bar_time = 0;

// -----------------------------------------------------------------------------
// Strategy Helpers
// -----------------------------------------------------------------------------

double Strategy_CalculateRatio()
{
   if(strategy_lookback_period <= 1)
      return 1.0;

   double pos_move = 0.0;
   double neg_move = 0.0;

   for(int i = 1; i <= strategy_lookback_period; ++i)
   {
      const double c_curr = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, i);     // perf-allowed: D1 momentum lookback
      const double c_prev = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, i + 1); // perf-allowed: D1 momentum lookback
      if(c_curr <= 0.0 || c_prev <= 0.0)
         continue;

      const double diff = c_curr - c_prev;
      if(diff > 0.0)
         pos_move += diff;
      else if(diff < 0.0)
         neg_move += (-diff);
   }

   if(neg_move <= 1e-7)
      return (pos_move > 0.0) ? 10.0 : 1.0;

   return (pos_move / neg_move);
}

bool Strategy_HasPosition(const int side)
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(side == 1 && ptype == POSITION_TYPE_BUY)
         return true;
      if(side == -1 && ptype == POSITION_TYPE_SELL)
         return true;
      if(side == 0)
         return true;
   }
   return false;
}

// -----------------------------------------------------------------------------
// Strategy Hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(strategy_max_spread_points > 0)
   {
      const int spread_pts = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_pts > strategy_max_spread_points)
         return true;
   }
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

   if(Strategy_HasPosition(0))
      return false;

   g_cached_ratio = Strategy_CalculateRatio();

   QM_OrderType side = QM_BUY;
   bool signal = false;

   if(g_cached_ratio >= strategy_ratio_entry_long)
   {
      side = QM_BUY;
      signal = true;
   }
   else if(g_cached_ratio <= strategy_ratio_entry_short && g_cached_ratio > 0.0)
   {
      side = QM_SELL;
      signal = true;
   }

   if(!signal)
      return false;

   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.sl = sl;
   req.reason = (side == QM_BUY) ? "QM5_1345_COT_MOMO_LONG" : "QM5_1345_COT_MOMO_SHORT";
   return true;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_ratio = Strategy_CalculateRatio();

      // Long position exit when ratio falls to parity or below
      if(ptype == POSITION_TYPE_BUY && current_ratio <= strategy_ratio_exit)
         return true;

      // Short position exit when ratio rises to parity or above
      if(ptype == POSITION_TYPE_SELL && current_ratio >= strategy_ratio_exit)
         return true;

      // Time stop exit
      if(strategy_max_hold_days > 0)
      {
         const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
         if(open_time > 0 && (TimeCurrent() - open_time) >= (strategy_max_hold_days * 86400))
            return true;
      }
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
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

