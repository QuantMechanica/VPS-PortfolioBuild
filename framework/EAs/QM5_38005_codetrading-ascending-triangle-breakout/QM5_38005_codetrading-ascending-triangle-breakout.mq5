#property strict
#property version   "5.0"
#property description "QM5_38005 CodeTrading Ascending Triangle Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_38005
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 38005;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf           = PERIOD_H1;
input int             strategy_pivot_window        = 4;
input int             strategy_search_bars         = 30;
input double          strategy_max_res_slope       = 0.05;
input int             strategy_vol_sma_period      = 20;
input double          strategy_vol_mult            = 1.3;
input int             strategy_atr_period          = 14;
input double          strategy_sl_buffer_pips      = 2.0;
input double          strategy_tp_rr               = 2.0;
input bool            strategy_trail_enabled       = true;
input double          strategy_trail_trigger_r     = 1.0;
input int             strategy_rollover_start_hhmm = 2355;
input int             strategy_rollover_end_hhmm   = 5;
input double          strategy_spread_filter_mult  = 1.8;

// -----------------------------------------------------------------------------
// State Cache & Indicators
// -----------------------------------------------------------------------------
double g_last_atr       = 0.0;
double g_last_res_level = 0.0;
double g_last_sup_level = 0.0;
double g_last_sl_price  = 0.0;
int    g_last_signal    = 0;

int StrategyHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
}

bool StrategyInRolloverWindow(const datetime t)
{
   const int hhmm = StrategyHhmm(t);
   if(strategy_rollover_start_hhmm > strategy_rollover_end_hhmm)
      return (hhmm >= strategy_rollover_start_hhmm || hhmm < strategy_rollover_end_hhmm);
   return (hhmm >= strategy_rollover_start_hhmm && hhmm < strategy_rollover_end_hhmm);
}

bool IsPivotHigh(const int shift, const int window)
{
   const double h = iHigh(_Symbol, strategy_signal_tf, shift); // perf-allowed: closed-bar pivot scan
   if(h <= 0.0) return false;
   for(int k = 1; k <= window; ++k)
   {
      const double h_prev = iHigh(_Symbol, strategy_signal_tf, shift + k); // perf-allowed: closed-bar pivot scan
      const double h_next = iHigh(_Symbol, strategy_signal_tf, shift - k); // perf-allowed: closed-bar pivot scan
      if(h_prev <= 0.0 || h_next <= 0.0 || h_prev >= h || h_next >= h)
         return false;
   }
   return true;
}

bool IsPivotLow(const int shift, const int window)
{
   const double l = iLow(_Symbol, strategy_signal_tf, shift); // perf-allowed: closed-bar pivot scan
   if(l <= 0.0) return false;
   for(int k = 1; k <= window; ++k)
   {
      const double l_prev = iLow(_Symbol, strategy_signal_tf, shift + k); // perf-allowed: closed-bar pivot scan
      const double l_next = iLow(_Symbol, strategy_signal_tf, shift - k); // perf-allowed: closed-bar pivot scan
      if(l_prev <= 0.0 || l_next <= 0.0 || l_prev <= l || l_next <= l)
         return false;
   }
   return true;
}

void AdvanceState_OnNewBar()
{
   g_last_atr = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period), 1);
   g_last_signal = 0;
   g_last_res_level = 0.0;
   g_last_sup_level = 0.0;
   g_last_sl_price = 0.0;

   const double close1 = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: closed-bar pattern check
   if(close1 <= 0.0 || g_last_atr <= 0.0) return;

   // Volume filter
   double vol_sum = 0.0;
   int vol_count = 0;
   for(int v = 1; v <= strategy_vol_sma_period; ++v)
   {
      const double vol_v = (double)iVolume(_Symbol, strategy_signal_tf, v); // perf-allowed: closed-bar volume check
      if(vol_v > 0.0)
      {
         vol_sum += vol_v;
         vol_count++;
      }
   }
   const double cur_vol = (double)iVolume(_Symbol, strategy_signal_tf, 1); // perf-allowed: closed-bar volume check
   const double avg_vol = (vol_count > 0) ? (vol_sum / vol_count) : 0.0;
   const bool vol_ok = (cur_vol >= avg_vol * strategy_vol_mult || avg_vol <= 0.0);

   if(!vol_ok) return;

   // Find two recent pivot highs and two recent pivot lows
   double h1 = 0.0, h2 = 0.0;
   int h1_bar = 0, h2_bar = 0;
   double l1 = 0.0, l2 = 0.0;
   int l1_bar = 0, l2_bar = 0;

   const int win = strategy_pivot_window;
   for(int s = win + 1; s <= strategy_search_bars; ++s)
   {
      if(h1 <= 0.0 && IsPivotHigh(s, win))
      {
         h1 = iHigh(_Symbol, strategy_signal_tf, s); // perf-allowed: closed-bar pivot scan
         h1_bar = s;
      }
      else if(h1 > 0.0 && h2 <= 0.0 && IsPivotHigh(s, win))
      {
         h2 = iHigh(_Symbol, strategy_signal_tf, s); // perf-allowed: closed-bar pivot scan
         h2_bar = s;
      }

      if(l1 <= 0.0 && IsPivotLow(s, win))
      {
         l1 = iLow(_Symbol, strategy_signal_tf, s); // perf-allowed: closed-bar pivot scan
         l1_bar = s;
      }
      else if(l1 > 0.0 && l2 <= 0.0 && IsPivotLow(s, win))
      {
         l2 = iLow(_Symbol, strategy_signal_tf, s); // perf-allowed: closed-bar pivot scan
         l2_bar = s;
      }

      if(h1 > 0.0 && h2 > 0.0 && l1 > 0.0 && l2 > 0.0)
         break;
   }

   const double pip_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_sl_buffer_pips));
   const double buffer = (pip_dist > 0.0) ? pip_dist : (strategy_sl_buffer_pips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0);

   // Ascending Triangle Check: Flat Resistance + Ascending Support
   if(h1 > 0.0 && h2 > 0.0 && l1 > 0.0 && l2 > 0.0)
   {
      const double res_avg = (h1 + h2) / 2.0;
      const double res_diff_rel = MathAbs(h1 - h2) / res_avg;

      if(res_diff_rel <= strategy_max_res_slope && l1 > l2 && close1 > res_avg + buffer)
      {
         g_last_signal = 1;
         g_last_res_level = res_avg;
         g_last_sl_price = l1 - buffer;
         return;
      }

      // Descending Triangle Check: Flat Support + Descending Resistance
      const double sup_avg = (l1 + l2) / 2.0;
      const double sup_diff_rel = MathAbs(l1 - l2) / sup_avg;

      if(sup_diff_rel <= strategy_max_res_slope && h1 < h2 && close1 < sup_avg - buffer)
      {
         g_last_signal = -1;
         g_last_sup_level = sup_avg;
         g_last_sl_price = h1 + buffer;
         return;
      }
   }
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(StrategyInRolloverWindow(TimeCurrent()))
      return true;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) >= 1)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   if(ask > bid && g_last_atr > 0.0)
   {
      const double spread = ask - bid;
      if(spread > g_last_atr * strategy_spread_filter_mult)
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

   if(g_last_signal == 0 || g_last_atr <= 0.0 || g_last_sl_price <= 0.0)
      return false;

   const QM_OrderType side = (g_last_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl = g_last_sl_price;
   double tp = 0.0;

   if(side == QM_BUY)
   {
      if(sl >= entry)
         sl = entry - g_last_atr * 1.5;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      const double sl_dist = entry - sl;
      if(sl_dist <= 0.0)
         return false;
      tp = QM_StopRulesNormalizePrice(_Symbol, entry + strategy_tp_rr * sl_dist);
   }
   else
   {
      if(sl <= entry)
         sl = entry + g_last_atr * 1.5;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      const double sl_dist = sl - entry;
      if(sl_dist <= 0.0)
         return false;
      tp = QM_StopRulesNormalizePrice(_Symbol, entry - strategy_tp_rr * sl_dist);
   }

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "ASC_TRIANGLE_BRK_LONG" : "DESC_TRIANGLE_BRK_SHORT";

   return (req.sl > 0.0 && req.tp > 0.0);
}

void Strategy_ManageOpenPosition()
{
   if(!strategy_trail_enabled || g_last_atr <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double sl_dist = (current_sl > 0.0 && current_sl < open_price) ? (open_price - current_sl) : (g_last_atr * 1.5);
         const double r_trigger = sl_dist * strategy_trail_trigger_r;
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

         if(bid - open_price >= r_trigger && (current_sl < open_price || current_sl == 0.0))
         {
            const double new_sl = QM_StopRulesNormalizePrice(_Symbol, open_price + 2.0 * point);
            QM_TM_MoveSL(ticket, new_sl, "BE_LOCK");
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double sl_dist = (current_sl > open_price) ? (current_sl - open_price) : (g_last_atr * 1.5);
         const double r_trigger = sl_dist * strategy_trail_trigger_r;
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

         if(open_price - ask >= r_trigger && (current_sl > open_price || current_sl == 0.0))
         {
            const double new_sl = QM_StopRulesNormalizePrice(_Symbol, open_price - 2.0 * point);
            QM_TM_MoveSL(ticket, new_sl, "BE_LOCK");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
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
   if(Strategy_NewsFilterHook(broker_now))
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   AdvanceState_OnNewBar();
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
