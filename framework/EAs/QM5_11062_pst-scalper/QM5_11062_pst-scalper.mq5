#property strict
#property version   "5.0"
#property description "QM5_11062 pst-scalper - pysystemtrade bracket mean-reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11062 pst-scalper
// Source: Rob Carver / pst-group pysystemtrade provided scalper system.
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_11062_pst-scalper.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11062;
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
input int    strategy_horizon_seconds          = 600;
input int    strategy_range_segments           = 4;
input double strategy_limit_mult_F             = 0.75;
input double strategy_stop_mult_K              = 0.875;
input double strategy_spread_mult              = 0.25;
input double strategy_slippage_ticks           = 1.0;
input int    strategy_min_slippage_units_L_to_K = 5;
input int    strategy_min_stop_ticks           = 3;
input double strategy_std_dev_budget_ccy       = 150.0;
input double strategy_min_R_override_points    = 0.0;
input double strategy_max_R_override_points    = 0.0;
input int    strategy_session_start_h          = 7;
input int    strategy_session_end_h            = 20;
input int    strategy_cutoff_horizons          = 3;

// Return TRUE to BLOCK trading this tick. This hook handles the card's session
// gate and session-close pending-order cancellation. Exact spread-vs-R gating is
// done in Strategy_EntrySignal after R is estimated on the closed-bar path.
bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);

   int start_h = strategy_session_start_h;
   int end_h = strategy_session_end_h;
   if(start_h < 0)
      start_h = 0;
   if(start_h > 23)
      start_h = 23;
   if(end_h < 0)
      end_h = 0;
   if(end_h > 23)
      end_h = 23;

   const int secs_now = dt.hour * 3600 + dt.min * 60 + dt.sec;
   int secs_end = end_h * 3600;
   bool inside_session = false;
   if(start_h < end_h)
     {
      inside_session = (dt.hour >= start_h && dt.hour < end_h);
     }
   else if(start_h > end_h)
     {
      inside_session = (dt.hour >= start_h || dt.hour < end_h);
      if(dt.hour >= start_h)
         secs_end += 24 * 3600;
     }
   else
     {
      inside_session = true;
      secs_end = secs_now + 24 * 3600;
     }

   int cutoff_secs = strategy_cutoff_horizons * strategy_horizon_seconds;
   if(cutoff_secs < 0)
      cutoff_secs = 0;
   const int secs_to_close = secs_end - secs_now;
   const bool too_close_to_close = (secs_to_close <= cutoff_secs);
   const bool block_now = (!inside_session || too_close_to_close);

   if(block_now && magic > 0)
     {
      for(int i = OrdersTotal() - 1; i >= 0; --i)
        {
         const ulong order_ticket = OrderGetTicket(i);
         if(order_ticket == 0 || !OrderSelect(order_ticket))
            continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)
            continue;
         if((int)OrderGetInteger(ORDER_MAGIC) != magic)
            continue;
         QM_TM_RemovePendingOrder(order_ticket, "pst_session_close_cancel");
        }
     }

   return block_now;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
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

   int pending_count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong order_ticket = OrderGetTicket(i);
      if(order_ticket == 0 || !OrderSelect(order_ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      pending_count++;
     }
   if(pending_count > 0)
      return false;

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0 || strategy_horizon_seconds <= 0 || strategy_range_segments <= 0)
      return false;

   int bars_per_horizon = (int)MathCeil((double)strategy_horizon_seconds / (double)period_seconds);
   if(bars_per_horizon < 1)
      bars_per_horizon = 1;
   const int bars_needed = bars_per_horizon * strategy_range_segments;
   if(bars_needed <= 0 || bars_needed > 240)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, bars_needed, rates); // perf-allowed: bounded closed-bar horizon range inside EntrySignal's QM_IsNewBar gate
   if(copied < bars_needed)
      return false;

   double range_sum = 0.0;
   for(int seg = 0; seg < strategy_range_segments; ++seg)
     {
      double high_value = -DBL_MAX;
      double low_value = DBL_MAX;
      for(int j = 0; j < bars_per_horizon; ++j)
        {
         const int idx = seg * bars_per_horizon + j;
         if(rates[idx].high > high_value)
            high_value = rates[idx].high;
         if(rates[idx].low < low_value)
            low_value = rates[idx].low;
        }
      if(high_value <= 0.0 || low_value <= 0.0 || high_value <= low_value)
         return false;
      range_sum += (high_value - low_value);
     }

   double r_value = range_sum / strategy_range_segments;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size_raw = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(point <= 0.0)
      return false;
   const double tick_size = (tick_size_raw > 0.0) ? tick_size_raw : point;

   const double stop_gap_ratio = strategy_stop_mult_K - strategy_limit_mult_F;
   if(stop_gap_ratio <= 0.0)
      return false;

   double min_r = 0.0;
   if(strategy_min_R_override_points > 0.0)
      min_r = strategy_min_R_override_points * point;
   else
     {
      double slippage_ticks = strategy_slippage_ticks;
      if(slippage_ticks < 0.5)
         slippage_ticks = 0.5;
      min_r = (tick_size * strategy_min_slippage_units_L_to_K * slippage_ticks) / stop_gap_ratio;
     }

   double max_r = 0.0;
   if(strategy_max_R_override_points > 0.0)
      max_r = strategy_max_R_override_points * point;
   else if(tick_value > 0.0 && tick_size > 0.0 && strategy_std_dev_budget_ccy > 0.0)
     {
      const double horizons_per_day = (60.0 * 60.0 * 8.0) / (double)strategy_horizon_seconds;
      if(horizons_per_day > 0.0)
        {
         const double budget_per_trade = (2.0 * strategy_std_dev_budget_ccy) / MathSqrt(horizons_per_day);
         const double value_of_one_price_unit = tick_value / tick_size;
         if(value_of_one_price_unit > 0.0)
            max_r = budget_per_trade / (stop_gap_ratio * value_of_one_price_unit);
        }
     }

   if(min_r > 0.0 && r_value < min_r)
      r_value = min_r;
   if(max_r > 0.0 && r_value > max_r)
      r_value = max_r;
   if(r_value <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > strategy_spread_mult * r_value)
      return false;

   const double mid = 0.5 * (ask + bid);
   const double bracket_offset = strategy_limit_mult_F * (r_value * 0.5);
   if(mid <= 0.0 || bracket_offset <= 0.0)
      return false;

   double stop_distance = stop_gap_ratio * r_value;
   const double min_stop = strategy_min_stop_ticks * tick_size;
   if(stop_distance < min_stop)
      stop_distance = min_stop;
   if(stop_distance <= 0.0)
      return false;

   const double buy_price = QM_TM_NormalizePrice(_Symbol, mid - bracket_offset);
   const double sell_price = QM_TM_NormalizePrice(_Symbol, mid + bracket_offset);
   const double buy_sl = QM_TM_NormalizePrice(_Symbol, buy_price - stop_distance);
   const double sell_sl = QM_TM_NormalizePrice(_Symbol, sell_price + stop_distance);
   if(buy_price <= 0.0 || sell_price <= 0.0 || buy_sl <= 0.0 || sell_sl <= 0.0)
      return false;

   QM_EntryRequest buy_req;
   buy_req.type = QM_BUY_LIMIT;
   buy_req.price = buy_price;
   buy_req.sl = buy_sl;
   buy_req.tp = 0.0;
   buy_req.reason = "pst_buy_bracket";
   buy_req.symbol_slot = qm_magic_slot_offset;
   buy_req.expiration_seconds = strategy_horizon_seconds;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   req.type = QM_SELL_LIMIT;
   req.price = sell_price;
   req.sl = sell_sl;
   req.tp = 0.0;
   req.reason = "pst_sell_bracket";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_horizon_seconds;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   int position_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      position_count++;
     }

   int pending_count = 0;
   ulong single_pending_ticket = 0;
   for(int j = OrdersTotal() - 1; j >= 0; --j)
     {
      const ulong order_ticket = OrderGetTicket(j);
      if(order_ticket == 0 || !OrderSelect(order_ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      pending_count++;
      single_pending_ticket = order_ticket;
     }

   // Card state cleanup: flat with a single leftover bracket/stop order is
   // an unmatched order state, so cancel it before placing a new bracket pair.
   if(position_count == 0 && pending_count == 1 && single_pending_ticket > 0)
      QM_TM_RemovePendingOrder(single_pending_ticket, "pst_flat_unmatched_cancel");
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
// Framework wiring - do NOT edit below this line unless you know why.
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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
