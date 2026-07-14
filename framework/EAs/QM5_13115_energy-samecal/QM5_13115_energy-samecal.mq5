#property strict
#property version   "5.0"
#property description "QM5_13115 XTI XNG Same-Calendar-Month Seasonality"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_13115 - XTI/XNG Same-Calendar-Month Energy Seasonality
// -----------------------------------------------------------------------------
// Monthly market-neutral energy basket:
//   - reconstruct each leg's return in this calendar month for prior years
//   - average the synchronized XTI-minus-XNG same-month returns
//   - long the higher seasonal leg and short the lower seasonal leg
// Runtime is Darwinex-native D1 OHLC only; no external or futures-chain data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13115;
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
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_history_years       = 10;
input int    strategy_min_history_years   = 5;
input int    strategy_history_bars        = 3000;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 3.5;
input int    strategy_max_hold_days       = 35;
input int    strategy_xti_max_spread_pts  = 1500;
input int    strategy_xng_max_spread_pts  = 3000;
input int    strategy_deviation_points    = 20;

string g_leg_xti = "XTIUSD.DWX";
string g_leg_xng = "XNGUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_month_key = 0;
int      g_last_entry_month_key = 0;
datetime g_pair_entry_time = 0;
double   g_cache_xti_same_month_return = 0.0;
double   g_cache_xng_same_month_return = 0.0;
double   g_cache_relative_score = 0.0;
int      g_cache_sample_count = 0;

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

bool Strategy_IsPairMagic(const long magic)
  {
   const int xti_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xti);
   const int xng_magic = QM_MagicChecked(qm_ea_id, 1, g_leg_xng);
   return (magic == xti_magic || magic == xng_magic);
  }

bool Strategy_MonthAlreadyEntered(const int month_key)
  {
   if(month_key <= 0)
      return true;
   if(g_last_entry_month_key == month_key)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_MonthKeyForTime(opened) == month_key)
         return true;
     }

   MqlDateTime start_parts;
   ZeroMemory(start_parts);
   start_parts.year = month_key / 100;
   start_parts.mon = month_key % 100;
   start_parts.day = 1;
   const datetime month_start = StructToTime(start_parts);
   if(month_start <= 0 || !HistorySelect(month_start, TimeCurrent()))
      return true; // Fail closed: a restart must not bypass the one-package-per-month guard.

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
      if(Strategy_MonthKeyForTime(deal_time) == month_key)
         return true;
     }
   return false;
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

void Strategy_PreviousMonth(const int year,
                            const int month,
                            int &previous_year,
                            int &previous_month)
  {
   previous_year = year;
   previous_month = month - 1;
   if(previous_month < 1)
     {
      previous_month = 12;
      previous_year--;
     }
  }

bool Strategy_MonthEndClose(const MqlRates &rates[],
                            const int count,
                            const int target_year,
                            const int target_month,
                            double &month_end_close)
  {
   month_end_close = 0.0;
   for(int i = 0; i < count; ++i)
     {
      MqlDateTime dt;
      TimeToStruct(rates[i].time, dt);
      if(dt.year == target_year && dt.mon == target_month)
        {
         month_end_close = rates[i].close;
         return (month_end_close > 0.0 && MathIsValidNumber(month_end_close));
        }
     }
   return false;
  }

bool Strategy_MonthReturn(const MqlRates &rates[],
                          const int count,
                          const int year,
                          const int month,
                          double &month_return)
  {
   month_return = 0.0;
   int previous_year = 0;
   int previous_month = 0;
   Strategy_PreviousMonth(year, month, previous_year, previous_month);

   double month_close = 0.0;
   double previous_close = 0.0;
   if(!Strategy_MonthEndClose(rates, count, year, month, month_close))
      return false;
   if(!Strategy_MonthEndClose(rates, count, previous_year, previous_month, previous_close))
      return false;

   month_return = MathLog(month_close / previous_close);
   return MathIsValidNumber(month_return);
  }

bool Strategy_LoadSignalState(const datetime decision_bar_time,
                              int &pair_direction)
  {
   pair_direction = 0;
   g_cache_xti_same_month_return = 0.0;
   g_cache_xng_same_month_return = 0.0;
   g_cache_relative_score = 0.0;
   g_cache_sample_count = 0;

   MqlDateTime decision_dt;
   TimeToStruct(decision_bar_time, decision_dt);
   if(decision_dt.year <= 0 || decision_dt.mon < 1 || decision_dt.mon > 12)
      return false;

   MqlRates xti_rates[];
   MqlRates xng_rates[];
   ArraySetAsSeries(xti_rates, true);
   ArraySetAsSeries(xng_rates, true);
   const int requested = MathMax(1500, strategy_history_bars);
   const int xti_count = CopyRates(g_leg_xti, PERIOD_D1, 1, requested, xti_rates); // perf-allowed: bounded history is copied only on the monthly decision bar.
   const int xng_count = CopyRates(g_leg_xng, PERIOD_D1, 1, requested, xng_rates); // perf-allowed: bounded history is copied only on the monthly decision bar.
   if(xti_count <= 0 || xng_count <= 0)
      return false;

   double xti_sum = 0.0;
   double xng_sum = 0.0;
   double relative_sum = 0.0;
   const int years = MathMax(strategy_min_history_years, strategy_history_years);
   for(int offset = 1; offset <= years; ++offset)
     {
      const int sample_year = decision_dt.year - offset;
      double xti_return = 0.0;
      double xng_return = 0.0;
      if(!Strategy_MonthReturn(xti_rates, xti_count, sample_year, decision_dt.mon, xti_return))
         continue;
      if(!Strategy_MonthReturn(xng_rates, xng_count, sample_year, decision_dt.mon, xng_return))
         continue;

      const double relative_return = xti_return - xng_return;
      if(!MathIsValidNumber(relative_return))
         continue;
      xti_sum += xti_return;
      xng_sum += xng_return;
      relative_sum += relative_return;
      g_cache_sample_count++;
     }

   if(g_cache_sample_count < strategy_min_history_years)
      return false;

   g_cache_xti_same_month_return = xti_sum / (double)g_cache_sample_count;
   g_cache_xng_same_month_return = xng_sum / (double)g_cache_sample_count;
   g_cache_relative_score = relative_sum / (double)g_cache_sample_count;
   if(!MathIsValidNumber(g_cache_xti_same_month_return) ||
      !MathIsValidNumber(g_cache_xng_same_month_return) ||
      !MathIsValidNumber(g_cache_relative_score))
      return false;

   if(g_cache_relative_score > 1.0e-12)
      pair_direction = 1;
   else if(g_cache_relative_score < -1.0e-12)
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

   const datetime decision_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: one cached timestamp on the D1 new-bar path.
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
   if(!Strategy_SpreadAllowed(g_leg_xti) || !Strategy_SpreadAllowed(g_leg_xng))
      return false;

   const bool long_xti_short_xng = (pair_direction > 0);
   const QM_OrderType xti_type = long_xti_short_xng ? QM_BUY : QM_SELL;
   const QM_OrderType xng_type = long_xti_short_xng ? QM_SELL : QM_BUY;
   const string reason = long_xti_short_xng ? "QM5_13115_LONG_XTI_SHORT_XNG_SAMECAL"
                                            : "QM5_13115_SHORT_XTI_LONG_XNG_SAMECAL";
   const double weight_sum = 2.0;

   const bool xti_ok = Strategy_OpenLeg(g_leg_xti, xti_type, 1.0, weight_sum, reason);
   const bool xng_ok = Strategy_OpenLeg(g_leg_xng, xng_type, 1.0, weight_sum, reason);
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
   if(strategy_history_years < strategy_min_history_years || strategy_min_history_years < 5)
      return true;
   if(strategy_history_bars < 1500)
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
   req.reason = "QM5_13115_ENERGY_SAMECAL_HOST";
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
   if(open_legs != 2 || Strategy_CurrentPairDirection() == 0)
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
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          MathMax(1800, strategy_history_bars));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13115\",\"ea\":\"energy-samecal\"}");
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

