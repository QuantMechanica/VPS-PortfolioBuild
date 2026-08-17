#property strict
#property version   "5.0"
#property description "QM5_35004 BabyPips Asian Box London Open Breakout"
// Strategy Card: QM5_35004 (babypips-asian-box-london-breakout), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_35004
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 35004;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.5;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
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
input int    strategy_box_start_hhmm      = 0;      // Asian box start time (00:00 GMT)
input int    strategy_box_end_hhmm        = 600;    // Asian box end time (06:00 GMT)
input int    strategy_trade_start_hhmm    = 700;    // London breakout entry start (07:00 GMT)
input int    strategy_trade_end_hhmm      = 900;    // London breakout entry end (09:00 GMT)
input int    strategy_force_close_hhmm    = 1600;   // London session close exit (16:00 GMT)
input double strategy_max_box_pips        = 40.0;   // Maximum allowable Asian range in pips
input double strategy_breakout_buffer_pips= 2.0;    // Breakout confirmation buffer in pips
input double strategy_tp_range_mult       = 2.0;    // 1:2.0 Risk:Reward multiplier (2.0x Asian Range)
input int    strategy_atr_period          = 14;     // ATR period for spread/fallback
input double strategy_spread_atr_mult     = 1.8;    // Spread filter ATR multiplier

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

int GetBarHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
}

bool CalculateAsianBox(double &out_high, double &out_low, double &out_range)
{
   const datetime t_1 = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: closed-bar time behind QM_IsNewBar()
   if(t_1 <= 0) return false;

   MqlDateTime dt_1;
   TimeToStruct(t_1, dt_1);

   double box_high = -DBL_MAX;
   double box_low  = DBL_MAX;
   int bar_count = 0;

   // Search backwards up to 60 M15 bars to find today's 00:00 to 06:00 session
   for(int i = 1; i <= 60; ++i)
   {
      const datetime bar_time = iTime(_Symbol, PERIOD_M15, i); // perf-allowed: closed-bar time behind QM_IsNewBar()
      if(bar_time <= 0) break;

      MqlDateTime bar_dt;
      TimeToStruct(bar_time, bar_dt);

      // Must be on the exact same day
      if(bar_dt.year != dt_1.year || bar_dt.mon != dt_1.mon || bar_dt.day != dt_1.day)
         break;

      const int hhmm = bar_dt.hour * 100 + bar_dt.min;
      if(hhmm >= strategy_box_start_hhmm && hhmm < strategy_box_end_hhmm)
      {
         const double h = iHigh(_Symbol, PERIOD_M15, i); // perf-allowed: closed-bar high behind QM_IsNewBar()
         const double l = iLow(_Symbol, PERIOD_M15, i);  // perf-allowed: closed-bar low behind QM_IsNewBar()
         if(h <= 0.0 || l <= 0.0) return false;

         if(h > box_high) box_high = h;
         if(l < box_low)  box_low  = l;
         bar_count++;
      }
   }

   // 00:00 to 06:00 has 24 M15 bars; accept if at least 16 bars are present
   if(bar_count < 16 || box_high <= 0.0 || box_low >= DBL_MAX || box_high <= box_low)
      return false;

   out_high = box_high;
   out_low  = box_low;
   out_range = box_high - box_low;
   return true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const datetime now = TimeCurrent();
   const int hhmm = GetBarHhmm(now);
   if(hhmm >= 2355 || hhmm < 5)
      return true;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0 && atr_1 > 0.0)
   {
      const double spread_pts = (ask - bid) / point;
      const double atr_pts = atr_1 / point;
      if(spread_pts > strategy_spread_atr_mult * atr_pts)
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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const datetime t_1 = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: closed-bar time behind QM_IsNewBar()
   if(t_1 <= 0) return false;

   const int hhmm_1 = GetBarHhmm(t_1);
   if(hhmm_1 < strategy_trade_start_hhmm || hhmm_1 > strategy_trade_end_hhmm)
      return false;

   double box_high = 0.0, box_low = 0.0, box_range = 0.0;
   if(!CalculateAsianBox(box_high, box_low, box_range))
      return false;

   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0)
      return false;

   if(box_range > strategy_max_box_pips * pip_size)
      return false;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   const double min_sl_dist = (atr_1 > 0.0) ? (0.5 * atr_1) : (10.0 * pip_size);
   const double max_sl_dist = (atr_1 > 0.0) ? (4.0 * atr_1) : (120.0 * pip_size);

   const double close_1 = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: closed-bar close behind QM_IsNewBar()
   const double buffer = strategy_breakout_buffer_pips * pip_size;

   // 1. Long Breakout
   if(close_1 > box_high + buffer)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : close_1;
      double sl_price = (box_high + box_low) * 0.5;
      double sl_dist = exec_price - sl_price;

      if(sl_dist < min_sl_dist)
      {
         sl_dist = min_sl_dist;
         sl_price = exec_price - sl_dist;
      }
      else if(sl_dist > max_sl_dist)
      {
         sl_dist = max_sl_dist;
         sl_price = exec_price - sl_dist;
      }

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl_price;
      req.tp = exec_price + strategy_tp_range_mult * box_range;
      req.reason = "asian_box_long";
      return true;
   }

   // 2. Short Breakout
   if(close_1 < box_low - buffer)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : close_1;
      double sl_price = (box_high + box_low) * 0.5;
      double sl_dist = sl_price - exec_price;

      if(sl_dist < min_sl_dist)
      {
         sl_dist = min_sl_dist;
         sl_price = exec_price + sl_dist;
      }
      else if(sl_dist > max_sl_dist)
      {
         sl_dist = max_sl_dist;
         sl_price = exec_price + sl_dist;
      }

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl_price;
      req.tp = exec_price - strategy_tp_range_mult * box_range;
      req.reason = "asian_box_short";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return;
   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0) return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0 || open_price <= 0.0) continue;

         double r_dist = 0.0;
         if(current_tp > open_price)
            r_dist = (current_tp - open_price) / strategy_tp_range_mult;
         else if(current_sl > 0.0 && current_sl < open_price)
            r_dist = open_price - current_sl;
         else
            r_dist = 20.0 * pip_size;

         if((bid - open_price) >= r_dist)
         {
            const double target_sl = QM_TM_NormalizePrice(_Symbol, open_price + 1.0 * pip_size);
            if(target_sl > current_sl + point * 0.5)
               QM_TM_MoveSL(ticket, target_sl, "asian_box_be_plus_1");
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0 || open_price <= 0.0) continue;

         double r_dist = 0.0;
         if(current_tp > 0.0 && current_tp < open_price)
            r_dist = (open_price - current_tp) / strategy_tp_range_mult;
         else if(current_sl > open_price)
            r_dist = current_sl - open_price;
         else
            r_dist = 20.0 * pip_size;

         if((open_price - ask) >= r_dist)
         {
            const double target_sl = QM_TM_NormalizePrice(_Symbol, open_price - 1.0 * pip_size);
            if(current_sl <= 0.0 || target_sl < current_sl - point * 0.5)
               QM_TM_MoveSL(ticket, target_sl, "asian_box_be_plus_1");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   const datetime now = TimeCurrent();
   const int hhmm = GetBarHhmm(now);
   if(hhmm >= strategy_force_close_hhmm && hhmm < 2355)
      return true;
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

void OnDeinit(const int reason)
{
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
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

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!QM_IsNewBar()) return;
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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
