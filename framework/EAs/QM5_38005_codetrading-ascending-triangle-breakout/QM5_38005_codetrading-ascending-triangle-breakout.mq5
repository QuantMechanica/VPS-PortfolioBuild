#property strict
#property version   "5.1"
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
input ENUM_TIMEFRAMES strategy_signal_tf             = PERIOD_H1;
input int             strategy_pivot_window          = 5;
input int             strategy_search_bars           = 30;
input double          strategy_max_res_slope         = 0.05;
input double          strategy_min_trend_slope       = 0.10;
input int             strategy_vol_sma_period        = 20;
input double          strategy_vol_mult              = 1.3;
input int             strategy_atr_period            = 14;
input double          strategy_sl_buffer_pips        = 2.0;
input double          strategy_triangle_height_mult  = 1.0;
input double          strategy_tp_rr                 = 2.0;
input bool            strategy_trail_enabled         = true;
input double          strategy_trail_trigger_r       = 1.0;
input int             strategy_rollover_start_hhmm   = 2355;
input int             strategy_rollover_end_hhmm     = 5;
input double          strategy_spread_filter_mult    = 1.8;
input int             strategy_max_slippage_ticks    = 3;
input double          strategy_daily_loss_halt_pct   = 2.0;
input double          strategy_daily_hard_stop_pct   = 2.5;
input double          strategy_total_dd_halt_pct     = 5.0;
input double          strategy_per_trade_risk_cap_pct = 0.5;

// -----------------------------------------------------------------------------
// Closed-bar state. Broker-side SL/TP reconstruct the management state after a
// restart; only the latest completed-bar pivots and entry geometry are cached.
// -----------------------------------------------------------------------------
bool   g_state_valid          = false;
double g_last_atr             = 0.0;
double g_last_res_level       = 0.0;
double g_last_sup_level       = 0.0;
double g_last_sl_price        = 0.0;
double g_last_triangle_height = 0.0;
double g_latest_pivot_high    = 0.0;
double g_latest_pivot_low     = 0.0;
int    g_last_signal          = 0;

int StrategyHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
}

bool StrategyInRolloverWindow(const datetime utc_time)
{
   const int hhmm = StrategyHhmm(utc_time);
   if(strategy_rollover_start_hhmm > strategy_rollover_end_hhmm)
      return (hhmm >= strategy_rollover_start_hhmm || hhmm < strategy_rollover_end_hhmm);
   return (hhmm >= strategy_rollover_start_hhmm && hhmm < strategy_rollover_end_hhmm);
}

bool StrategyConfigValid()
{
   if(strategy_signal_tf != PERIOD_H1 ||
      strategy_pivot_window < 3 || strategy_pivot_window > 10 ||
      strategy_search_bars < 20 || strategy_search_bars > 200)
      return false;
   if(strategy_max_res_slope < 0.02 || strategy_max_res_slope > 0.10 ||
      strategy_min_trend_slope <= strategy_max_res_slope ||
      strategy_min_trend_slope > 0.50)
      return false;
   if(strategy_vol_sma_period < 2 ||
      strategy_vol_sma_period > strategy_search_bars + strategy_pivot_window ||
      strategy_vol_mult <= 1.0 || strategy_atr_period < 2)
      return false;
   if(strategy_sl_buffer_pips != 2.0 ||
      strategy_triangle_height_mult != 1.0 || strategy_tp_rr != 2.0 ||
      !strategy_trail_enabled || strategy_trail_trigger_r != 1.0 ||
      strategy_spread_filter_mult <= 0.0)
      return false;
   if(strategy_rollover_start_hhmm < 0 || strategy_rollover_start_hhmm > 2359 ||
      strategy_rollover_end_hhmm < 0 || strategy_rollover_end_hhmm > 2359 ||
      (strategy_rollover_start_hhmm % 100) > 59 ||
      (strategy_rollover_end_hhmm % 100) > 59 ||
      strategy_max_slippage_ticks <= 0 || strategy_max_slippage_ticks > 3)
      return false;
   if(strategy_daily_loss_halt_pct <= 0.0 || strategy_daily_hard_stop_pct <= 0.0 ||
      strategy_daily_loss_halt_pct > strategy_daily_hard_stop_pct ||
      strategy_daily_loss_halt_pct > 2.0 || strategy_daily_hard_stop_pct > 2.5 ||
      strategy_total_dd_halt_pct <= 0.0 || strategy_total_dd_halt_pct > 5.0)
      return false;
   return (strategy_per_trade_risk_cap_pct > 0.0 &&
           strategy_per_trade_risk_cap_pct <= 0.5);
}

int StrategyDeviationPoints()
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return 0;
   return (int)MathMax(1.0,
                       MathCeil(strategy_max_slippage_ticks * tick_size / point));
}

bool StrategyLoadRates(MqlRates &rates[])
{
   const int required = MathMax(strategy_search_bars + strategy_pivot_window,
                                strategy_vol_sma_period);
   if(required <= 0 || required > 256)
      return false;
   ArraySetAsSeries(rates, true);
   const int resized = ArrayResize(rates, required);
   if(resized != required || ArraySize(rates) != required)
      return false;
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, required, rates); // perf-allowed: bounded closed-bar pattern, volume, and pivot cache refresh
   return (copied == required && ArraySize(rates) == copied);
}

bool StrategyIsPivotHigh(MqlRates &rates[], const int shift, const int window)
{
   const int size = ArraySize(rates);
   const int index = shift - 1;
   if(window <= 0 || index < window || index + window >= size)
      return false;
   const double pivot = rates[index].high;
   if(pivot <= 0.0)
      return false;
   for(int k = 1; k <= window; ++k)
   {
      if(rates[index - k].high <= 0.0 || rates[index + k].high <= 0.0 ||
         rates[index - k].high >= pivot || rates[index + k].high >= pivot)
         return false;
   }
   return true;
}

bool StrategyIsPivotLow(MqlRates &rates[], const int shift, const int window)
{
   const int size = ArraySize(rates);
   const int index = shift - 1;
   if(window <= 0 || index < window || index + window >= size)
      return false;
   const double pivot = rates[index].low;
   if(pivot <= 0.0)
      return false;
   for(int k = 1; k <= window; ++k)
   {
      if(rates[index - k].low <= 0.0 || rates[index + k].low <= 0.0 ||
         rates[index - k].low <= pivot || rates[index + k].low <= pivot)
         return false;
   }
   return true;
}

bool StrategyVolumeConfirms(MqlRates &rates[])
{
   const int size = ArraySize(rates);
   if(strategy_vol_sma_period <= 0 || size < strategy_vol_sma_period)
      return false;

   double volume_sum = 0.0;
   for(int i = 0; i < strategy_vol_sma_period; ++i)
   {
      const double volume = (double)rates[i].tick_volume;
      if(volume <= 0.0)
         return false;
      volume_sum += volume;
   }

   const double average_volume = volume_sum / (double)strategy_vol_sma_period;
   const double signal_volume = (double)rates[0].tick_volume;
   return (average_volume > 0.0 &&
           signal_volume > strategy_vol_mult * average_volume);
}

void AdvanceState_OnNewBar()
{
   g_state_valid = false;
   g_last_signal = 0;
   g_last_res_level = 0.0;
   g_last_sup_level = 0.0;
   g_last_sl_price = 0.0;
   g_last_triangle_height = 0.0;
   g_latest_pivot_high = 0.0;
   g_latest_pivot_low = 0.0;
   g_last_atr = QM_ATR(_Symbol, strategy_signal_tf,
                       MathMax(1, strategy_atr_period), 1);
   if(g_last_atr <= 0.0)
      return;

   MqlRates rates[];
   if(!StrategyLoadRates(rates))
      return;
   const int rates_size = ArraySize(rates);
   if(rates_size <= 0 || rates[0].close <= 0.0)
      return;

   double h1 = 0.0, h2 = 0.0;
   int h1_bar = 0, h2_bar = 0;
   double l1 = 0.0, l2 = 0.0;
   int l1_bar = 0, l2_bar = 0;

   const int win = strategy_pivot_window;
   for(int shift = win + 1; shift <= strategy_search_bars; ++shift)
   {
      if(h1 <= 0.0 && StrategyIsPivotHigh(rates, shift, win))
      {
         h1 = rates[shift - 1].high;
         h1_bar = shift;
      }
      else if(h1 > 0.0 && h2 <= 0.0 && StrategyIsPivotHigh(rates, shift, win))
      {
         h2 = rates[shift - 1].high;
         h2_bar = shift;
      }

      if(l1 <= 0.0 && StrategyIsPivotLow(rates, shift, win))
      {
         l1 = rates[shift - 1].low;
         l1_bar = shift;
      }
      else if(l1 > 0.0 && l2 <= 0.0 && StrategyIsPivotLow(rates, shift, win))
      {
         l2 = rates[shift - 1].low;
         l2_bar = shift;
      }

      if(h1 > 0.0 && h2 > 0.0 && l1 > 0.0 && l2 > 0.0)
         break;
   }

   g_latest_pivot_high = h1;
   g_latest_pivot_low = l1;
   if(h1 <= 0.0 || h2 <= 0.0 || l1 <= 0.0 || l2 <= 0.0 ||
      h2_bar <= h1_bar || l2_bar <= l1_bar)
      return;
   if(!StrategyVolumeConfirms(rates))
      return;

   const double buffer = QM_StopRulesPipsToPriceDistance(
      _Symbol, (int)MathRound(strategy_sl_buffer_pips));
   if(buffer <= 0.0)
      return;

   const double resistance_price_slope = (h1 - h2) / (double)(h2_bar - h1_bar);
   const double support_price_slope = (l1 - l2) / (double)(l2_bar - l1_bar);
   const double resistance_slope = resistance_price_slope / g_last_atr;
   const double support_slope = support_price_slope / g_last_atr;
   const double resistance_level = h1 + resistance_price_slope * (double)(h1_bar - 1);
   const double support_level = l1 + support_price_slope * (double)(l1_bar - 1);
   const double triangle_height = resistance_level - support_level;
   const double close1 = rates[0].close;

   if(resistance_level <= 0.0 || support_level <= 0.0 || triangle_height <= 0.0)
      return;

   g_last_res_level = resistance_level;
   g_last_sup_level = support_level;
   g_last_triangle_height = triangle_height;
   g_state_valid = true;

   // Ascending: flat resistance and support rising by >=0.10 ATR per bar.
   if(MathAbs(resistance_slope) <= strategy_max_res_slope &&
      support_slope >= strategy_min_trend_slope &&
      close1 > resistance_level + buffer)
   {
      g_last_signal = 1;
      g_last_sl_price = l1 - buffer;
      return;
   }

   // Descending is the exact mirror: flat support and falling resistance.
   if(MathAbs(support_slope) <= strategy_max_res_slope &&
      resistance_slope <= -strategy_min_trend_slope &&
      close1 < support_level - buffer)
   {
      g_last_signal = -1;
      g_last_sl_price = h1 + buffer;
   }
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool StrategyDailyRealizedLossHalt()
{
   int closed_trades = 0;
   const double realized_pnl = QM_ChartUITodayPnL(0, closed_trades);
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   const double day_start_balance = balance_now - realized_pnl;
   if(balance_now <= 0.0 || day_start_balance <= 0.0)
      return true;
   return (realized_pnl <=
           -(day_start_balance * strategy_daily_loss_halt_pct / 100.0));
}

bool Strategy_NoTradeFilter()
{
   if(StrategyInRolloverWindow(QM_BrokerToUTC(TimeCurrent())))
      return true;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) >= 1)
      return true;

   if(StrategyDailyRealizedLossHalt())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || g_last_atr <= 0.0)
      return true;

   return (ask > bid &&
           ask - bid > g_last_atr * strategy_spread_filter_mult);
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = 0;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(!g_state_valid || g_last_signal == 0 || g_last_atr <= 0.0 ||
      g_last_sl_price <= 0.0 || g_last_triangle_height <= 0.0)
      return false;

   const QM_OrderType side = (g_last_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopRulesNormalizePrice(_Symbol, g_last_sl_price);
   const double target_distance = g_last_triangle_height * strategy_triangle_height_mult;
   if(sl <= 0.0 || target_distance <= 0.0)
      return false;

   double risk_distance = 0.0;
   double tp = 0.0;
   if(side == QM_BUY)
   {
      risk_distance = entry - sl;
      if(risk_distance <= 0.0 ||
         target_distance < strategy_tp_rr * risk_distance)
         return false;
      tp = QM_StopRulesNormalizePrice(_Symbol, entry + target_distance);
   }
   else
   {
      risk_distance = sl - entry;
      if(risk_distance <= 0.0 ||
         target_distance < strategy_tp_rr * risk_distance)
         return false;
      tp = QM_StopRulesNormalizePrice(_Symbol, entry - target_distance);
   }
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "ASC_TRIANGLE_HEIGHT_LONG"
                                 : "DESC_TRIANGLE_HEIGHT_SHORT";
   return true;
}

void Strategy_ManageOpenPosition()
{
   if(!strategy_trail_enabled)
      return;

   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double buffer = QM_StopRulesPipsToPriceDistance(
      _Symbol, (int)MathRound(strategy_sl_buffer_pips));
   if(magic <= 0 || point <= 0.0 || tick_size <= 0.0 || buffer <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            continue;
         if(current_sl < open_price)
         {
            const double initial_risk = open_price - current_sl;
            if(initial_risk > 0.0 &&
               bid - open_price >= initial_risk * strategy_trail_trigger_r)
               QM_TM_MoveSL(ticket,
                            QM_StopRulesNormalizePrice(_Symbol, open_price + tick_size),
                            "TRIANGLE_BE_1R");
         }
         else if(g_latest_pivot_low > 0.0)
         {
            const double trail_sl = QM_StopRulesNormalizePrice(
               _Symbol, g_latest_pivot_low - buffer);
            if(trail_sl > current_sl && trail_sl < bid)
               QM_TM_MoveSL(ticket, trail_sl, "TRIANGLE_SWING_LOW_TRAIL");
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            continue;
         if(current_sl > open_price)
         {
            const double initial_risk = current_sl - open_price;
            if(initial_risk > 0.0 &&
               open_price - ask >= initial_risk * strategy_trail_trigger_r)
               QM_TM_MoveSL(ticket,
                            QM_StopRulesNormalizePrice(_Symbol, open_price - tick_size),
                            "TRIANGLE_BE_1R");
         }
         else if(g_latest_pivot_high > 0.0)
         {
            const double trail_sl = QM_StopRulesNormalizePrice(
               _Symbol, g_latest_pivot_high + buffer);
            if(trail_sl < current_sl && trail_sl > ask)
               QM_TM_MoveSL(ticket, trail_sl, "TRIANGLE_SWING_HIGH_TRAIL");
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
   if(!StrategyConfigValid())
      return INIT_PARAMETERS_INCORRECT;

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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_H1,
                                            QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                            "V5_WEEKEND_RISK_POLICY"))
      return INIT_FAILED;

   const int deviation_points = StrategyDeviationPoints();
   if(deviation_points <= 0)
      return INIT_FAILED;
   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());

   QM_RiskSizerSetCapPct(strategy_per_trade_risk_cap_pct);
   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_hard_stop_pct,
                         strategy_total_dd_halt_pct,
                         strategy_per_trade_risk_cap_pct))
      return INIT_FAILED;

   AdvanceState_OnNewBar();
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_38005_codetrading-ascending-triangle-breakout\"}");
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
   const bool strategy_new_bar = QM_IsNewBar(_Symbol, strategy_signal_tf);
   if(strategy_new_bar)
   {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
   }

   // Existing risk is managed before every entry-only admission filter.
   Strategy_ManageOpenPosition();

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!strategy_new_bar)
      return;
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(Strategy_NoTradeFilter())
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
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
