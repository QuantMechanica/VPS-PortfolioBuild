#property strict
#property version   "5.0"
#property description "QM5_12955 MQL5 Aroon Crossover"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12955 - MQL5 Aroon Crossover
// -----------------------------------------------------------------------------
// Strategy based on Mohamed Abdelmaaboud (2024), "Building and testing Aroon
// Trading Systems" (MQL5 Articles).
// Computes Aroon Up and Aroon Down over a 25-bar lookback on closed H1 bars.
// Long entry when Aroon Up crosses above Aroon Down.
// Short entry when Aroon Up crosses below Aroon Down.
// Target profit 600 points; protective stop 200 points.
// Positions exit early upon opposite Aroon crossover or framework Friday close.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12955;
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
input int    strategy_aroon_period      = 25;    // Lookback period for Aroon indicator
input int    strategy_tp_points         = 600;   // Take profit distance in points
input int    strategy_sl_points         = 200;   // Stop loss distance in points
input int    strategy_atr_period        = 14;    // ATR period for sanity stop distance
input double strategy_atr_sl_mult       = 2.0;   // ATR stop multiplier if points exceed range
input int    strategy_max_spread_points = 50;    // Max spread allowed at entry

// -----------------------------------------------------------------------------
// Strategy Helpers
// -----------------------------------------------------------------------------

void Strategy_CalculateAroon(const int shift, double &aroon_up, double &aroon_down)
{
   aroon_up = 50.0;
   aroon_down = 50.0;

   if(strategy_aroon_period <= 1 || shift < 0)
      return;

   // perf-allowed: Aroon high/low recency search within closed-bar window
   const int high_shift = iHighest(_Symbol, (ENUM_TIMEFRAMES)_Period, MODE_HIGH, strategy_aroon_period, shift);
   const int low_shift  = iLowest(_Symbol, (ENUM_TIMEFRAMES)_Period, MODE_LOW, strategy_aroon_period, shift);

   if(high_shift < shift || low_shift < shift)
      return;

   const int periods_since_high = high_shift - shift;
   const int periods_since_low  = low_shift - shift;

   aroon_up   = ((double)(strategy_aroon_period - periods_since_high) / (double)strategy_aroon_period) * 100.0;
   aroon_down = ((double)(strategy_aroon_period - periods_since_low)  / (double)strategy_aroon_period) * 100.0;
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

   double up1 = 0.0, down1 = 0.0;
   double up2 = 0.0, down2 = 0.0;

   Strategy_CalculateAroon(1, up1, down1);
   Strategy_CalculateAroon(2, up2, down2);

   const bool bullish_cross = (up2 <= down2 && up1 > down1);
   const bool bearish_cross = (up2 >= down2 && up1 < down1);

   if(!bullish_cross && !bearish_cross)
      return false;

   const QM_OrderType side = bullish_cross ? QM_BUY : QM_SELL;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl = 0.0;
   double tp = 0.0;

   if(strategy_sl_points > 0)
   {
      sl = (side == QM_BUY) ? (entry - strategy_sl_points * point) : (entry + strategy_sl_points * point);
   }
   else
   {
      sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   }

   if(strategy_tp_points > 0)
   {
      tp = (side == QM_BUY) ? (entry + strategy_tp_points * point) : (entry - strategy_tp_points * point);
   }

   if(sl <= 0.0)
      return false;

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = bullish_cross ? "QM5_12955_AROON_CROSS_LONG" : "QM5_12955_AROON_CROSS_SHORT";
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
      double up1 = 0.0, down1 = 0.0;
      Strategy_CalculateAroon(1, up1, down1);

      // Long exit on bearish dominance/cross
      if(ptype == POSITION_TYPE_BUY && up1 < down1)
         return true;

      // Short exit on bullish dominance/cross
      if(ptype == POSITION_TYPE_SELL && up1 > down1)
         return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework Wiring
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

