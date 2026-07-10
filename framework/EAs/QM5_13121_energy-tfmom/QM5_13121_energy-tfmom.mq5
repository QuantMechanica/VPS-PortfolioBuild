#property strict
#property version   "5.0"
#property description "QM5_13121 XTI XNG Trend-Filtered Momentum"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_13121 - XTI/XNG trend-filtered cross-sectional momentum
// -----------------------------------------------------------------------------
// Monthly market-neutral energy package:
//   - rank XTI and XNG on synchronized 12-completed-month returns
//   - require the winner above its 7-month moving average and the loser below it
//   - allocate fixed package risk with 60-D1 inverse-volatility weights
// Runtime is Darwinex-native D1 close data only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13121;
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
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_momentum_months        = 12;
input int    strategy_trend_months           = 7;
input int    strategy_volatility_days        = 60;
input int    strategy_history_bars           = 450;
input int    strategy_max_boundary_gap_days  = 10;
input int    strategy_atr_period_d1           = 20;
input double strategy_atr_sl_mult             = 3.5;
input int    strategy_max_hold_days           = 35;
input int    strategy_xti_max_spread_pts      = 1500;
input int    strategy_xng_max_spread_pts      = 3000;
input int    strategy_deviation_points        = 20;

string g_leg_xti = "XTIUSD.DWX";
string g_leg_xng = "XNGUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_month_key = 0;
int      g_last_entry_month_key = 0;
datetime g_pair_entry_time = 0;
double   g_cache_xti_momentum = 0.0;
double   g_cache_xng_momentum = 0.0;
double   g_cache_xti_trend_level = 0.0;
double   g_cache_xng_trend_level = 0.0;
double   g_cache_xti_trend_mean = 0.0;
double   g_cache_xng_trend_mean = 0.0;
double   g_cache_xti_volatility = 0.0;
double   g_cache_xng_volatility = 0.0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xti)
      return 0;
   if(symbol == g_leg_xng)
      return 1;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_leg_xti && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   const long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(spread_points < 0)
      return false;
   if(symbol == g_leg_xti && strategy_xti_max_spread_pts > 0)
      return (spread_points <= strategy_xti_max_spread_pts);
   if(symbol == g_leg_xng && strategy_xng_max_spread_pts > 0)
      return (spread_points <= strategy_xng_max_spread_pts);
   return true;
  }

bool Strategy_IsPairPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_MagicChecked(qm_ea_id, slot, symbol));
  }

int Strategy_OpenPairLegCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         ++count;
     }
   return count;
  }

datetime Strategy_CurrentPairEntryTime()
  {
   datetime earliest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (earliest == 0 || opened < earliest))
         earliest = opened;
     }
   return earliest;
  }

bool Strategy_PairCompositionValid()
  {
   int xti_direction = 0;
   int xng_direction = 0;
   int xti_count = 0;
   int xng_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int direction = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
      if(symbol == g_leg_xti)
        {
         xti_direction = direction;
         ++xti_count;
        }
      else if(symbol == g_leg_xng)
        {
         xng_direction = direction;
         ++xng_count;
        }
     }
   return (xti_count == 1 && xng_count == 1 && xti_direction == -xng_direction);
  }

void Strategy_ClosePair(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
   g_pair_entry_time = 0;
  }

void Strategy_ShiftMonths(const MqlDateTime &base,
                          const int months_back,
                          MqlDateTime &shifted)
  {
   shifted = base;
   const int absolute_month = base.year * 12 + (base.mon - 1) - months_back;
   shifted.year = absolute_month / 12;
   shifted.mon = absolute_month % 12 + 1;
   shifted.day = 1;
   shifted.hour = 0;
   shifted.min = 0;
   shifted.sec = 0;
  }

bool Strategy_CloseBeforeBoundary(const MqlRates &rates[],
                                  const int count,
                                  const datetime boundary,
                                  double &close_price,
                                  datetime &close_time)
  {
   close_price = 0.0;
   close_time = 0;
   for(int i = 0; i < count; ++i)
     {
      if(rates[i].time >= boundary || rates[i].close <= 0.0 || !MathIsValidNumber(rates[i].close))
         continue;
      close_price = rates[i].close;
      close_time = rates[i].time;
      break;
     }
   if(close_time <= 0 || close_price <= 0.0)
      return false;
   const long gap_seconds = (long)(boundary - close_time);
   const long max_gap_seconds = (long)strategy_max_boundary_gap_days * 86400;
   return (gap_seconds > 0 && gap_seconds <= max_gap_seconds);
  }

bool Strategy_LegSignalState(const string symbol,
                             const datetime decision_bar_time,
                             double &momentum_return,
                             double &trend_level,
                             double &trend_mean,
                             double &realized_volatility)
  {
   momentum_return = 0.0;
   trend_level = 0.0;
   trend_mean = 0.0;
   realized_volatility = 0.0;

   MqlDateTime decision_dt;
   TimeToStruct(decision_bar_time, decision_dt);
   if(decision_dt.year <= 0 || decision_dt.mon < 1 || decision_dt.mon > 12)
      return false;

   MqlDateTime end_dt;
   MqlDateTime momentum_dt;
   Strategy_ShiftMonths(decision_dt, 0, end_dt);
   Strategy_ShiftMonths(end_dt, strategy_momentum_months, momentum_dt);
   const datetime end_boundary = StructToTime(end_dt);
   const datetime momentum_boundary = StructToTime(momentum_dt);
   if(end_boundary <= 0 || momentum_boundary <= 0 || end_boundary <= momentum_boundary)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int count = CopyRates(symbol, PERIOD_D1, 1, strategy_history_bars, rates); // perf-allowed: bounded monthly signal copy.
   if(count < 300 || count <= strategy_volatility_days)
      return false;

   datetime end_close_time = 0;
   datetime momentum_close_time = 0;
   double momentum_close = 0.0;
   if(!Strategy_CloseBeforeBoundary(rates, count, end_boundary, trend_level, end_close_time))
      return false;
   if(!Strategy_CloseBeforeBoundary(rates, count, momentum_boundary, momentum_close, momentum_close_time))
      return false;
   if(end_close_time <= momentum_close_time || momentum_close <= 0.0)
      return false;

   double trend_sum = 0.0;
   datetime previous_endpoint_time = 0;
   for(int month_index = 0; month_index < strategy_trend_months; ++month_index)
     {
      MqlDateTime boundary_dt;
      Strategy_ShiftMonths(end_dt, month_index, boundary_dt);
      const datetime boundary = StructToTime(boundary_dt);
      double endpoint_close = 0.0;
      datetime endpoint_time = 0;
      if(boundary <= 0 || !Strategy_CloseBeforeBoundary(rates, count, boundary, endpoint_close, endpoint_time))
         return false;
      if(month_index > 0 && endpoint_time >= previous_endpoint_time)
         return false;
      previous_endpoint_time = endpoint_time;
      trend_sum += endpoint_close;
     }
   trend_mean = trend_sum / (double)strategy_trend_months;

   double sum_returns = 0.0;
   double sum_squares = 0.0;
   for(int i = 0; i < strategy_volatility_days; ++i)
     {
      if(rates[i].close <= 0.0 || rates[i + 1].close <= 0.0)
         return false;
      const double daily_return = MathLog(rates[i].close / rates[i + 1].close);
      if(!MathIsValidNumber(daily_return))
         return false;
      sum_returns += daily_return;
      sum_squares += daily_return * daily_return;
     }
   const double mean_return = sum_returns / (double)strategy_volatility_days;
   const double variance = sum_squares / (double)strategy_volatility_days - mean_return * mean_return;
   if(variance <= 0.0 || !MathIsValidNumber(variance))
      return false;

   momentum_return = MathLog(trend_level / momentum_close);
   realized_volatility = MathSqrt(variance);
   return (trend_mean > 0.0 && MathIsValidNumber(momentum_return) &&
           MathIsValidNumber(trend_mean) && MathIsValidNumber(realized_volatility));
  }

bool Strategy_LoadSignalState(const datetime decision_bar_time,
                              int &pair_direction)
  {
   pair_direction = 0;
   if(!Strategy_LegSignalState(g_leg_xti, decision_bar_time,
                               g_cache_xti_momentum,
                               g_cache_xti_trend_level,
                               g_cache_xti_trend_mean,
                               g_cache_xti_volatility))
      return false;
   if(!Strategy_LegSignalState(g_leg_xng, decision_bar_time,
                               g_cache_xng_momentum,
                               g_cache_xng_trend_level,
                               g_cache_xng_trend_mean,
                               g_cache_xng_volatility))
      return false;

   const double momentum_difference = g_cache_xti_momentum - g_cache_xng_momentum;
   const double rank_epsilon = 1.0e-12;
   if(momentum_difference > rank_epsilon &&
      g_cache_xti_trend_level > g_cache_xti_trend_mean &&
      g_cache_xng_trend_level < g_cache_xng_trend_mean)
      pair_direction = 1;
   else if(momentum_difference < -rank_epsilon &&
           g_cache_xti_trend_level < g_cache_xti_trend_mean &&
           g_cache_xng_trend_level > g_cache_xng_trend_mean)
      pair_direction = -1;
   return true;
  }

void Strategy_AdvanceSignal_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int prior_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(current_month_key <= 0 || prior_month_key <= 0 || current_month_key == prior_month_key)
      return;

   const datetime decision_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: one timestamp on the D1 new-bar path.
   if(decision_bar_time <= 0)
      return;

   g_monthly_rebalance_bar = true;
   g_cache_month_key = current_month_key;
   g_cache_signal_valid = Strategy_LoadSignalState(decision_bar_time, g_cache_pair_direction);
  }

bool Strategy_MaxHoldExceeded()
  {
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_CurrentPairEntryTime();
   if(entry_time <= 0)
      return false;
   const long hold_seconds = (long)MathMax(1, strategy_max_hold_days) * 86400;
   return ((long)(TimeCurrent() - entry_time) >= hold_seconds);
  }

double Strategy_LotsForLeg(const string symbol,
                           const double risk_weight,
                           const double risk_weight_sum)
  {
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 || risk_weight <= 0.0 || risk_weight_sum <= 0.0)
      return 0.0;

   const double sl_points = strategy_atr_sl_mult * atr / point;
   double lots = QM_LotsForRisk(symbol, sl_points) * risk_weight / risk_weight_sum;
   const double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || min_lot <= 0.0 || max_lot <= 0.0 || step <= 0.0)
      return 0.0;

   lots = MathFloor(lots / step) * step;
   if(lots < min_lot)
      return 0.0;
   return MathMin(max_lot, NormalizeDouble(lots, 8));
  }

bool Strategy_OpenLeg(const string symbol,
                      const QM_OrderType type,
                      const double risk_weight,
                      const double risk_weight_sum,
                      const string reason)
  {
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0 || !Strategy_SpreadAllowed(symbol))
      return false;

   const double entry = QM_OrderTypeIsBuy(type) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double stop_dist = strategy_atr_sl_mult * atr;
   const double lots = Strategy_LotsForLeg(symbol, risk_weight, risk_weight_sum);
   if(lots <= 0.0)
      return false;

   QM_BasketOrderRequest req;
   req.symbol = symbol;
   req.type = type;
   req.price = 0.0;
   req.sl = QM_OrderTypeIsBuy(type) ? NormalizeDouble(entry - stop_dist, digits)
                                    : NormalizeDouble(entry + stop_dist, digits);
   req.tp = 0.0;
   req.lots = lots;
   req.reason = reason;
   req.symbol_slot = slot;
   req.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, strategy_deviation_points, req, ticket);
  }

bool Strategy_OpenPair(const int pair_direction)
  {
   if(pair_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadAllowed(g_leg_xti) || !Strategy_SpreadAllowed(g_leg_xng) ||
      g_cache_xti_volatility <= 0.0 || g_cache_xng_volatility <= 0.0)
      return false;

   const bool long_xti_short_xng = (pair_direction > 0);
   const QM_OrderType xti_type = long_xti_short_xng ? QM_BUY : QM_SELL;
   const QM_OrderType xng_type = long_xti_short_xng ? QM_SELL : QM_BUY;
   const string reason = long_xti_short_xng ? "QM5_13121_LONG_XTI_SHORT_XNG_TFMOM"
                                            : "QM5_13121_SHORT_XTI_LONG_XNG_TFMOM";
   const double xti_weight = 1.0 / g_cache_xti_volatility;
   const double xng_weight = 1.0 / g_cache_xng_volatility;
   const double weight_sum = xti_weight + xng_weight;
   if(weight_sum <= 0.0 || !MathIsValidNumber(weight_sum))
      return false;

   const bool xti_ok = Strategy_OpenLeg(g_leg_xti, xti_type, xti_weight, weight_sum, reason);
   const bool xng_ok = Strategy_OpenLeg(g_leg_xng, xng_type, xng_weight, weight_sum, reason);
   if(xti_ok && xng_ok)
     {
      g_pair_entry_time = TimeCurrent();
      return true;
     }

   Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(strategy_momentum_months != 12 || strategy_trend_months != 7 ||
      strategy_volatility_days != 60)
      return true;
   if(strategy_history_bars < 360 || strategy_max_boundary_gap_days < 7 ||
      strategy_max_boundary_gap_days > 10)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_max_hold_days <= 0)
      return true;
   if(strategy_xti_max_spread_pts < 0 || strategy_xng_max_spread_pts < 0 ||
      strategy_deviation_points < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13121_ENERGY_TFMOM_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_monthly_rebalance_bar || g_cache_month_key <= 0)
      return false;
   if(g_cache_month_key == g_last_entry_month_key)
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;
   if(!g_cache_signal_valid || g_cache_pair_direction == 0)
      return false;

   if(Strategy_OpenPair(g_cache_pair_direction))
      g_last_entry_month_key = g_cache_month_key;
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int open_legs = Strategy_OpenPairLegCount();
   if(open_legs <= 0)
      return;
   if(open_legs != 2 || !Strategy_PairCompositionValid())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(g_monthly_rebalance_bar)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(Strategy_MaxHoldExceeded())
      Strategy_ClosePair(QM_EXIT_TIME_STOP);
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsAllowsEntry(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_leg_xti, broker_time, qm_news_temporal, qm_news_compliance))
         return false;
      if(!QM_NewsAllowsTrade2(g_leg_xng, broker_time, qm_news_temporal, qm_news_compliance))
         return false;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_xti, broker_time, qm_news_mode_legacy))
         return false;
      if(!QM_NewsAllowsTrade(g_leg_xng, broker_time, qm_news_mode_legacy))
         return false;
     }
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return !Strategy_NewsAllowsEntry(broker_time);
  }

int OnInit()
  {
   SymbolSelect(g_leg_xti, true);
   SymbolSelect(g_leg_xng, true);

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

   string basket_symbols[2] = {g_leg_xti, g_leg_xng};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1, MathMax(360, strategy_history_bars));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13121\",\"ea\":\"energy-tfmom\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   const bool new_bar = QM_IsNewBar();
   g_monthly_rebalance_bar = false;
   if(new_bar)
      Strategy_AdvanceSignal_OnNewBar();

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return;
     }

   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(!new_bar)
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
