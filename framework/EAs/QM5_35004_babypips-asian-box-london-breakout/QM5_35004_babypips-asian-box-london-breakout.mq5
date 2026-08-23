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
input double RISK_PERCENT                 = 0.0;
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
input int    strategy_atr_period          = 14;     // ATR period for spread filter
input double strategy_spread_atr_mult     = 1.8;    // Spread filter ATR multiplier
input double strategy_daily_loss_halt_pct = 2.0;    // Daily realized loss entry halt percent
input double strategy_daily_hard_stop_pct = 2.5;    // Maximum daily drawdown hard stop percent
input double strategy_total_dd_halt_pct   = 5.0;    // Maximum total drawdown stop percent
input double strategy_per_trade_risk_cap_pct = 0.5; // Per-trade risk cap percent

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

int StrategyHhmm(const datetime value)
{
   MqlDateTime parts;
   TimeToStruct(value, parts);
   return parts.hour * 100 + parts.min;
}

int StrategyDateKey(const datetime value)
{
   MqlDateTime parts;
   TimeToStruct(value, parts);
   return parts.year * 10000 + parts.mon * 100 + parts.day;
}

bool StrategyInRolloverWindow(const datetime utc_time)
{
   const int hhmm = StrategyHhmm(utc_time);
   return (hhmm >= 2355 || hhmm < 5);
}

bool StrategyDailyEntryHalt()
{
   if(g_qm_ks_day_start_equity <= 0.0)
      return false;

   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity_now <= 0.0)
      return true;

   const double pnl_pct = ((equity_now - g_qm_ks_day_start_equity) / g_qm_ks_day_start_equity) * 100.0;
   return (pnl_pct <= -strategy_daily_loss_halt_pct);
}

bool CalculateAsianBox(double &out_high, double &out_low, double &out_range)
{
   const datetime t_1 = iTime(_Symbol, PERIOD_M15, 1);
   if(t_1 <= 0) return false;

   const datetime utc_1 = QM_BrokerToUTC(t_1);
   const int date_key_1 = StrategyDateKey(utc_1);

   double box_high = -DBL_MAX;
   double box_low  = DBL_MAX;
   int bar_count = 0;

   // Search backwards up to 96 M15 bars to find today's 00:00 to 06:00 GMT session
   for(int i = 1; i <= 96; ++i)
   {
      const datetime bar_time = iTime(_Symbol, PERIOD_M15, i);
      if(bar_time <= 0) break;

      const datetime utc_bar = QM_BrokerToUTC(bar_time);
      const int bar_date_key = StrategyDateKey(utc_bar);

      // Must be on the exact same UTC day
      if(bar_date_key != date_key_1)
      {
         if(bar_date_key < date_key_1)
            break;
         continue;
      }

      const int hhmm = StrategyHhmm(utc_bar);
      if(hhmm >= strategy_box_start_hhmm && hhmm < strategy_box_end_hhmm)
      {
         const double h = iHigh(_Symbol, PERIOD_M15, i);
         const double l = iLow(_Symbol, PERIOD_M15, i);
         if(h <= 0.0 || l <= 0.0) return false;

         if(h > box_high) box_high = h;
         if(l < box_low)  box_low  = l;
         bar_count++;
      }
   }

   // 00:00 to 06:00 GMT on M15 has exactly 24 bars (00:00, 00:15, ..., 05:45)
   if(bar_count != 24 || box_high <= 0.0 || box_low <= 0.0 || box_high <= box_low)
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
   const datetime broker_now = TimeCurrent();
   const datetime utc_now = QM_BrokerToUTC(broker_now);

   // 1. Rollover Blackout in UTC (23:55 to 00:05 GMT)
   if(StrategyInRolloverWindow(utc_now))
      return true;

   // 2. Spread Filter (> 1.8 * ATR(14, M15)[1])
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

   // 3. Daily Loss Limit (2.0% entry halt)
   if(StrategyDailyEntryHalt())
      return true;

   // 4. Max Open Positions (>= 1)
   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) >= 1)
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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const datetime t_1 = iTime(_Symbol, PERIOD_M15, 1);
   if(t_1 <= 0) return false;

   const datetime utc_1 = QM_BrokerToUTC(t_1);
   const int hhmm_1 = StrategyHhmm(utc_1);
   if(hhmm_1 < strategy_trade_start_hhmm || hhmm_1 > strategy_trade_end_hhmm)
      return false;

   double box_high = 0.0, box_low = 0.0, box_range = 0.0;
   if(!CalculateAsianBox(box_high, box_low, box_range))
      return false;

   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   if(pip_size <= 0.0)
      return false;

   if(box_range > strategy_max_box_pips * pip_size)
      return false;

   const double close_1 = iClose(_Symbol, PERIOD_M15, 1);
   const double buffer = strategy_breakout_buffer_pips * pip_size;

   // 1. Long Breakout
   if(close_1 > box_high + buffer)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : close_1;
      const double sl_price = (box_high + box_low) * 0.5;
      const double tp_price = exec_price + strategy_tp_range_mult * box_range;

      if(sl_price <= 0.0 || sl_price >= exec_price || tp_price <= exec_price)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl_price;
      req.tp = tp_price;
      req.reason = "asian_box_long";
      return true;
   }

   // 2. Short Breakout
   if(close_1 < box_low - buffer)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : close_1;
      const double sl_price = (box_high + box_low) * 0.5;
      const double tp_price = exec_price - strategy_tp_range_mult * box_range;

      if(sl_price <= 0.0 || sl_price <= exec_price || tp_price >= exec_price)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl_price;
      req.tp = tp_price;
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
   const datetime broker_now = TimeCurrent();
   const datetime utc_now = QM_BrokerToUTC(broker_now);
   const int hhmm_utc = StrategyHhmm(utc_now);
   if(hhmm_utc >= strategy_force_close_hhmm && hhmm_utc < 2355)
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

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_hard_stop_pct,
                         strategy_total_dd_halt_pct,
                         strategy_per_trade_risk_cap_pct))
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

   // 1. Manage open positions and evaluate exit signals before entry filters
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

   // 2. News filter check
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   // 3. Entry-only filter (spread, rollover, 2% daily loss halt, max open positions)
   if(Strategy_NoTradeFilter()) return;

   // 4. Bar evaluation for entry
   if(!QM_IsNewBar(_Symbol, PERIOD_M15)) return;
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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
