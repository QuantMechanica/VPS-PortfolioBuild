#property strict
#property version   "5.0"
#property description "QM5_13143 XTI XNG Expected-Shortfall Rank"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_13143 - XTI/XNG Monthly Expected-Shortfall Rank
// -----------------------------------------------------------------------------
// Monthly structural energy basket:
//   - use D1 bars from the 12 fully completed broker calendar months
//   - expected shortfall = mean of the worst 5% simple daily returns
//   - buy the higher-ES (less damaging tail) leg and short the lower-ES leg
// The finite-sample tail count is ceil(N * 0.05), with at least one return.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 13143;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = false;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_es_window_months         = 12;
input double strategy_tail_probability         = 0.05;
input int    strategy_history_bars             = 400;
input int    strategy_min_daily_observations   = 220;
input int    strategy_atr_period_d1            = 20;
input double strategy_atr_sl_mult              = 3.5;
input int    strategy_max_hold_days            = 40;
input int    strategy_xti_max_spread_pts       = 1500;
input int    strategy_xng_max_spread_pts       = 3000;
input int    strategy_deviation_points         = 20;

string g_leg_xti = "XTIUSD.DWX";
string g_leg_xng = "XNGUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_period_key = 0;
int      g_cache_decision_month_key = 0;
int      g_last_entry_period_key = 0;
datetime g_pair_entry_time = 0;
double   g_cache_xti_es = 0.0;
double   g_cache_xng_es = 0.0;
double   g_cache_es_difference = 0.0;
int      g_cache_xti_observations = 0;
int      g_cache_xng_observations = 0;

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

int Strategy_MonthKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   TimeToStruct(value, parts);
   if(parts.year <= 0 || parts.mon < 1 || parts.mon > 12)
      return 0;
   return parts.year * 100 + parts.mon;
  }

int Strategy_PreviousMonthKey(const int month_key,
                              const int months_back)
  {
   const int year = month_key / 100;
   const int month = month_key % 100;
   if(year <= 0 || month < 1 || month > 12 || months_back <= 0)
      return 0;
   const int serial = year * 12 + month - 1 - months_back;
   if(serial <= 0)
      return 0;
   return (serial / 12) * 100 + (serial % 12) + 1;
  }

int Strategy_PeriodKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   TimeToStruct(value, parts);
   if(parts.year <= 0 || parts.mon < 1 || parts.mon > 12)
      return 0;
   return parts.year * 12 + parts.mon - 1;
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

bool Strategy_ExpectedShortfall(const string symbol,
                                const int decision_month_key,
                                double &es_measure,
                                int &observation_count)
  {
   es_measure = 0.0;
   observation_count = 0;
   if(decision_month_key <= 0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int count = CopyRates(symbol, PERIOD_D1, 1, strategy_history_bars, rates); // perf-allowed: bounded copy only on a monthly D1 rebalance bar.
   if(count < strategy_min_daily_observations + 1)
      return false;

   int expected_month_keys[];
   int month_observations[];
   if(ArrayResize(expected_month_keys, strategy_es_window_months) != strategy_es_window_months ||
      ArrayResize(month_observations, strategy_es_window_months) != strategy_es_window_months)
      return false;

   for(int month_index = 0; month_index < strategy_es_window_months; ++month_index)
     {
      expected_month_keys[month_index] = Strategy_PreviousMonthKey(decision_month_key,
                                                                  month_index + 1);
      month_observations[month_index] = 0;
      if(expected_month_keys[month_index] <= 0)
         return false;
     }

   double daily_returns[];
   if(ArrayResize(daily_returns, count) != count)
      return false;

   for(int i = 0; i < count - 1; ++i)
     {
      const int bar_month_key = Strategy_MonthKeyForTime(rates[i].time);
      if(bar_month_key <= 0)
         return false;

      int expected_index = -1;
      for(int month_index = 0; month_index < strategy_es_window_months; ++month_index)
        {
         if(bar_month_key == expected_month_keys[month_index])
           {
            expected_index = month_index;
            break;
           }
        }
      if(expected_index < 0)
         continue;

      const double close_now = rates[i].close;
      const double close_prior = rates[i + 1].close;
      if(close_now <= 0.0 || close_prior <= 0.0 ||
         !MathIsValidNumber(close_now) || !MathIsValidNumber(close_prior))
         return false;

      const double daily_return = close_now / close_prior - 1.0;
      if(!MathIsValidNumber(daily_return))
         return false;

      daily_returns[observation_count] = daily_return;
      ++observation_count;
      ++month_observations[expected_index];
     }

   for(int month_index = 0; month_index < strategy_es_window_months; ++month_index)
     {
      if(month_observations[month_index] <= 0)
         return false;
     }
   if(observation_count < strategy_min_daily_observations)
      return false;

   if(ArrayResize(daily_returns, observation_count) != observation_count)
      return false;
   ArraySort(daily_returns);

   int tail_count = (int)MathCeil((double)observation_count *
                                  strategy_tail_probability);
   tail_count = MathMax(1, MathMin(observation_count, tail_count));
   double tail_sum = 0.0;
   for(int i = 0; i < tail_count; ++i)
      tail_sum += daily_returns[i];

   es_measure = tail_sum / (double)tail_count;
   return MathIsValidNumber(es_measure);
  }

bool Strategy_LoadSignalState(const datetime decision_bar_time,
                              int &pair_direction)
  {
   pair_direction = 0;
   g_cache_xti_es = 0.0;
   g_cache_xng_es = 0.0;
   g_cache_es_difference = 0.0;
   g_cache_xti_observations = 0;
   g_cache_xng_observations = 0;

   const int decision_month_key = Strategy_MonthKeyForTime(decision_bar_time);
   if(decision_month_key <= 0)
      return false;
   if(!Strategy_ExpectedShortfall(g_leg_xti,
                                  decision_month_key,
                                  g_cache_xti_es,
                                  g_cache_xti_observations))
      return false;
   if(!Strategy_ExpectedShortfall(g_leg_xng,
                                  decision_month_key,
                                  g_cache_xng_es,
                                  g_cache_xng_observations))
      return false;

   g_cache_es_difference = g_cache_xti_es - g_cache_xng_es;
   if(!MathIsValidNumber(g_cache_es_difference))
      return false;
   if(g_cache_es_difference > 1.0e-12)
      pair_direction = 1;
   else if(g_cache_es_difference < -1.0e-12)
      pair_direction = -1;
   return true;
  }

bool Strategy_IsPairMagic(const long magic)
  {
   const int xti_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xti);
   const int xng_magic = QM_MagicChecked(qm_ea_id, 1, g_leg_xng);
   return (magic == xti_magic || magic == xng_magic);
  }

bool Strategy_PeriodAlreadyEntered(const int period_key,
                                   const int decision_month_key)
  {
   if(period_key <= 0 || decision_month_key <= 0)
      return true;
   if(g_last_entry_period_key == period_key)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_PeriodKeyForTime(opened) == period_key)
         return true;
     }

   MqlDateTime start_parts;
   ZeroMemory(start_parts);
   start_parts.year = decision_month_key / 100;
   start_parts.mon = decision_month_key % 100;
   start_parts.day = 1;
   const datetime period_start = StructToTime(start_parts);
   if(period_start <= 0 || !HistorySelect(period_start, TimeCurrent()))
      return true;

   const int deal_count = HistoryDealsTotal();
   for(int i = deal_count - 1; i >= 0; --i)
     {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      const long magic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
      if(!Strategy_IsPairMagic(magic))
         continue;
      const ENUM_DEAL_ENTRY entry_kind = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_PeriodKeyForTime(deal_time) == period_key)
         return true;
     }
   return false;
  }

void Strategy_AdvanceSignal_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   const datetime decision_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cached timestamp on the D1 new-bar path.
   const datetime prior_bar_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: exact first-tradable-bar monthly transition check.
   const int current_month_key = Strategy_MonthKeyForTime(decision_bar_time);
   const int prior_month_key = Strategy_MonthKeyForTime(prior_bar_time);
   if(current_month_key <= 0 || prior_month_key <= 0 ||
      current_month_key == prior_month_key)
      return;

   g_monthly_rebalance_bar = true;
   g_cache_period_key = Strategy_PeriodKeyForTime(decision_bar_time);
   g_cache_decision_month_key = current_month_key;
   g_cache_signal_valid = Strategy_LoadSignalState(decision_bar_time,
                                                   g_cache_pair_direction);
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
   return QM_BasketOpenPosition(qm_ea_id,
                                qm_news_mode_legacy,
                                strategy_deviation_points,
                                req,
                                ticket);
  }

bool Strategy_OpenPair(const int pair_direction)
  {
   if(pair_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadAllowed(g_leg_xti) || !Strategy_SpreadAllowed(g_leg_xng))
      return false;

   const bool long_xti_short_xng = (pair_direction > 0);
   const QM_OrderType xti_type = long_xti_short_xng ? QM_BUY : QM_SELL;
   const QM_OrderType xng_type = long_xti_short_xng ? QM_SELL : QM_BUY;
   const string reason = long_xti_short_xng ? "QM5_13143_LONG_XTI_SHORT_XNG_HIGH_ES"
                                            : "QM5_13143_SHORT_XTI_LONG_XNG_HIGH_ES";
   const double weight_sum = 2.0;

   if(!Strategy_OpenLeg(g_leg_xti, xti_type, 1.0, weight_sum, reason))
      return false;
   if(Strategy_OpenLeg(g_leg_xng, xng_type, 1.0, weight_sum, reason))
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
   if(strategy_es_window_months != 12)
      return true;
   if(MathAbs(strategy_tail_probability - 0.05) > 1.0e-12)
      return true;
   if(strategy_history_bars < 350 || strategy_history_bars > 500)
      return true;
   if(strategy_min_daily_observations < 200 || strategy_min_daily_observations > 240)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
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
   req.reason = "QM5_13143_XTI_XNG_ES_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_monthly_rebalance_bar || g_cache_period_key <= 0 ||
      g_cache_decision_month_key <= 0)
      return false;
   if(Strategy_PeriodAlreadyEntered(g_cache_period_key,
                                    g_cache_decision_month_key))
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;
   if(!g_cache_signal_valid || g_cache_pair_direction == 0)
      return false;

   if(Strategy_OpenPair(g_cache_pair_direction))
      g_last_entry_period_key = g_cache_period_key;
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
      datetime entry_time = g_pair_entry_time;
      if(entry_time <= 0)
         entry_time = Strategy_CurrentPairEntryTime();
      if(Strategy_PeriodKeyForTime(entry_time) != g_cache_period_key)
        {
         Strategy_ClosePair(QM_EXIT_STRATEGY);
         return;
        }
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
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_leg_xti,
                              broker_time,
                              qm_news_temporal,
                              qm_news_compliance))
         return false;
      if(!QM_NewsAllowsTrade2(g_leg_xng,
                              broker_time,
                              qm_news_temporal,
                              qm_news_compliance))
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
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          MathMax(500, strategy_history_bars));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13143\",\"ea\":\"energy-es-rank\"}");
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
