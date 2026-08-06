#property strict
#property version   "5.0"
#property description "QM5_20236 XAU XAG Realized Volatility-of-Volatility Rank"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_20236 - XAU/XAG Monthly Realized Volatility-of-Volatility Rank
// -----------------------------------------------------------------------------
// Price-native falsification of a commodity option-implied VoV anomaly:
//   - form 252 overlapping realized-volatility estimates
//   - every RV estimate uses 20 completed D1 log returns
//   - realized VoV = population sd(RV) / mean(RV)
//   - buy lower realized VoV, short higher realized VoV for one broker month
// This does not claim to reproduce option-implied volatility-of-volatility.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 20236;
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
input int    strategy_rv_window_d1             = 20;
input int    strategy_vov_samples              = 252;
input int    strategy_history_bars             = 320;
input int    strategy_max_endpoint_gap_days    = 10;
input int    strategy_atr_period_d1             = 20;
input double strategy_atr_sl_mult               = 3.5;
input int    strategy_max_hold_days             = 40;
input int    strategy_xau_max_spread_pts        = 1500;
input int    strategy_xag_max_spread_pts        = 3000;
input int    strategy_deviation_points          = 20;

string g_leg_xau = "XAUUSD.DWX";
string g_leg_xag = "XAGUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_period_key = 0;
int      g_cache_decision_month_key = 0;
int      g_last_attempt_month_key = 0;
datetime g_decision_bar_time = 0;
datetime g_pair_entry_time = 0;
string   g_attempt_state_key = "";
double   g_cache_xau_vov = 0.0;
double   g_cache_xag_vov = 0.0;
double   g_cache_vov_difference = 0.0;
double   g_cache_xau_mean_rv = 0.0;
double   g_cache_xag_mean_rv = 0.0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xau)
      return 0;
   if(symbol == g_leg_xag)
      return 1;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_leg_xau && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   const long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(spread_points < 0)
      return false;
   if(symbol == g_leg_xau && strategy_xau_max_spread_pts > 0)
      return (spread_points <= strategy_xau_max_spread_pts);
   if(symbol == g_leg_xag && strategy_xag_max_spread_pts > 0)
      return (spread_points <= strategy_xag_max_spread_pts);
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

void Strategy_LoadAttemptState()
  {
   g_last_attempt_month_key = 0;
   if(g_attempt_state_key == "" || !GlobalVariableCheck(g_attempt_state_key))
      return;

   const int current_month_key =
      QM_CalendarPeriodKey(PERIOD_MN1, g_leg_xau, 0);
   const double stored = GlobalVariableGet(g_attempt_state_key);
   const int stored_month_key = (int)MathRound(stored);
   if(current_month_key > 0 && MathIsValidNumber(stored) &&
      stored_month_key >= 190001 && stored_month_key <= current_month_key)
     {
      g_last_attempt_month_key = stored_month_key;
      return;
     }

   // Tester terminal globals can outlive a later historical rerun. A marker
   // from the rerun's future must not suppress its earlier monthly decisions.
   GlobalVariableDel(g_attempt_state_key);
  }

bool Strategy_RecordMonthAttempt(const int month_key)
  {
   if(month_key <= 0 || g_attempt_state_key == "")
      return false;
   if(GlobalVariableSet(g_attempt_state_key, (double)month_key) <= 0)
      return false;
   GlobalVariablesFlush();
   g_last_attempt_month_key = month_key;
   return true;
  }

bool Strategy_PairCompositionValid()
  {
   int xau_direction = 0;
   int xag_direction = 0;
   int xau_count = 0;
   int xag_count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsPairPosition())
         continue;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int direction = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
      if(symbol == g_leg_xau)
        {
         xau_direction = direction;
         ++xau_count;
        }
      else if(symbol == g_leg_xag)
        {
         xag_direction = direction;
         ++xag_count;
        }
     }
   return (xau_count == 1 && xag_count == 1 && xau_direction == -xag_direction);
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

bool Strategy_RealizedVoV(const string symbol,
                          const datetime decision_bar_time,
                          double &vov_measure,
                          double &mean_rv)
  {
   vov_measure = 0.0;
   mean_rv = 0.0;
   if(decision_bar_time <= 0)
      return false;

   const int required_closes = strategy_vov_samples + strategy_rv_window_d1 + 1;
   if(required_closes <= 0 || strategy_history_bars < required_closes)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int count = CopyRates(symbol, PERIOD_D1, 1, strategy_history_bars, rates); // perf-allowed: bounded nested-VoV copy only on a monthly D1 rebalance bar.
   if(count < required_closes)
      return false;
   if(rates[0].time <= 0 || rates[0].time >= decision_bar_time)
      return false;
   const long endpoint_gap = (long)(decision_bar_time - rates[0].time);
   if(endpoint_gap < 0 || endpoint_gap > (long)strategy_max_endpoint_gap_days * 86400)
      return false;

   double realized_vols[];
   if(ArrayResize(realized_vols, strategy_vov_samples) != strategy_vov_samples)
      return false;

   double rv_sum = 0.0;
   for(int sample = 0; sample < strategy_vov_samples; ++sample)
     {
      double return_sum = 0.0;
      double return_sq_sum = 0.0;
      for(int k = 0; k < strategy_rv_window_d1; ++k)
        {
         const double close_now = rates[sample + k].close;
         const double close_prior = rates[sample + k + 1].close;
         if(close_now <= 0.0 || close_prior <= 0.0 ||
            !MathIsValidNumber(close_now) || !MathIsValidNumber(close_prior))
            return false;
         const double daily_return = MathLog(close_now / close_prior);
         if(!MathIsValidNumber(daily_return))
            return false;
         return_sum += daily_return;
         return_sq_sum += daily_return * daily_return;
        }

      const double n = (double)strategy_rv_window_d1;
      const double numerator = return_sq_sum - (return_sum * return_sum / n);
      const double variance = numerator / (n - 1.0);
      if(variance <= 1.0e-18 || !MathIsValidNumber(variance))
         return false;
      const double rv = MathSqrt(variance) * MathSqrt(252.0);
      if(rv <= 0.0 || !MathIsValidNumber(rv))
         return false;
      realized_vols[sample] = rv;
      rv_sum += rv;
     }

   mean_rv = rv_sum / (double)strategy_vov_samples;
   if(mean_rv <= 1.0e-12 || !MathIsValidNumber(mean_rv))
      return false;

   double dispersion_sum = 0.0;
   for(int sample = 0; sample < strategy_vov_samples; ++sample)
     {
      const double delta = realized_vols[sample] - mean_rv;
      dispersion_sum += delta * delta;
     }

   const double vov_variance = dispersion_sum / (double)strategy_vov_samples;
   if(vov_variance <= 1.0e-18 || !MathIsValidNumber(vov_variance))
      return false;
   vov_measure = MathSqrt(vov_variance) / mean_rv;
   return (vov_measure > 0.0 && MathIsValidNumber(vov_measure));
  }

bool Strategy_LoadSignalState(const datetime decision_bar_time,
                              int &pair_direction)
  {
   pair_direction = 0;
   g_cache_xau_vov = 0.0;
   g_cache_xag_vov = 0.0;
   g_cache_vov_difference = 0.0;
   g_cache_xau_mean_rv = 0.0;
   g_cache_xag_mean_rv = 0.0;

   if(!Strategy_RealizedVoV(g_leg_xau,
                            decision_bar_time,
                            g_cache_xau_vov,
                            g_cache_xau_mean_rv))
      return false;
   if(!Strategy_RealizedVoV(g_leg_xag,
                            decision_bar_time,
                            g_cache_xag_vov,
                            g_cache_xag_mean_rv))
      return false;

   g_cache_vov_difference = g_cache_xau_vov - g_cache_xag_vov;
   if(!MathIsValidNumber(g_cache_vov_difference))
      return false;

   // Source high-minus-low VoV returns are negative: buy lower VoV.
   if(g_cache_vov_difference < -1.0e-12)
      pair_direction = 1;
   else if(g_cache_vov_difference > 1.0e-12)
      pair_direction = -1;
   return true;
  }

bool Strategy_IsPairMagic(const long magic)
  {
   const int xau_magic = QM_MagicChecked(qm_ea_id, 0, g_leg_xau);
   const int xag_magic = QM_MagicChecked(qm_ea_id, 1, g_leg_xag);
   return (magic == xau_magic || magic == xag_magic);
  }

bool Strategy_PeriodAlreadyEntered(const int period_key,
                                   const int decision_month_key)
  {
   if(period_key <= 0 || decision_month_key <= 0)
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
   g_cache_signal_valid = false;
   g_cache_pair_direction = 0;
   g_decision_bar_time = 0;
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
   g_decision_bar_time = decision_bar_time;
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
   if(!Strategy_SpreadAllowed(g_leg_xau) || !Strategy_SpreadAllowed(g_leg_xag))
      return false;

   const bool long_xau_short_xag = (pair_direction > 0);
   const QM_OrderType xau_type = long_xau_short_xag ? QM_BUY : QM_SELL;
   const QM_OrderType xag_type = long_xau_short_xag ? QM_SELL : QM_BUY;
   const string reason = long_xau_short_xag ? "QM5_20236_LONG_XAU_SHORT_XAG_LOW_VOV"
                                            : "QM5_20236_SHORT_XAU_LONG_XAG_LOW_VOV";
   const double weight_sum = 2.0;

   if(!Strategy_OpenLeg(g_leg_xau, xau_type, 1.0, weight_sum, reason))
      return false;
   if(Strategy_OpenLeg(g_leg_xag, xag_type, 1.0, weight_sum, reason))
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
   if(qm_ea_id != 20236 || qm_magic_slot_offset != 0)
      return true;
   if(strategy_rv_window_d1 != 20 || strategy_vov_samples != 252)
      return true;
   if(strategy_history_bars != 300 && strategy_history_bars != 320 &&
      strategy_history_bars != 400)
      return true;
   if(strategy_history_bars < strategy_vov_samples + strategy_rv_window_d1 + 1)
      return true;
   if(strategy_max_endpoint_gap_days != 7 &&
      strategy_max_endpoint_gap_days != 10)
      return true;
   if(strategy_atr_period_d1 != 14 && strategy_atr_period_d1 != 20 &&
      strategy_atr_period_d1 != 30)
      return true;
   if(MathAbs(strategy_atr_sl_mult - 2.5) > 1.0e-12 &&
      MathAbs(strategy_atr_sl_mult - 3.5) > 1.0e-12 &&
      MathAbs(strategy_atr_sl_mult - 5.0) > 1.0e-12)
      return true;
   if(strategy_max_hold_days != 40)
      return true;
   if(strategy_xau_max_spread_pts != 1000 &&
      strategy_xau_max_spread_pts != 1500 &&
      strategy_xau_max_spread_pts != 2500)
      return true;
   if(strategy_xag_max_spread_pts != 2000 &&
      strategy_xag_max_spread_pts != 3000 &&
      strategy_xag_max_spread_pts != 4500)
      return true;
   if(strategy_deviation_points != 10 && strategy_deviation_points != 20 &&
      strategy_deviation_points != 50)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_20236_XAU_XAG_VOV_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_monthly_rebalance_bar || g_cache_period_key <= 0 ||
      g_cache_decision_month_key <= 0 || g_decision_bar_time <= 0)
      return false;
   if(g_cache_decision_month_key == g_last_attempt_month_key)
      return false;

   // Consume the monthly opportunity before history, signal, spread, news,
   // quote, stop, or order gates so a restart cannot manufacture a retry.
   if(!Strategy_RecordMonthAttempt(g_cache_decision_month_key))
      return false;
   if(Strategy_PeriodAlreadyEntered(g_cache_period_key,
                                    g_cache_decision_month_key))
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;
   g_cache_signal_valid =
      Strategy_LoadSignalState(g_decision_bar_time,
                               g_cache_pair_direction);
   if(!g_cache_signal_valid || g_cache_pair_direction == 0)
      return false;
   if(Strategy_NewsFilterHook(TimeCurrent()))
      return false;

   Strategy_OpenPair(g_cache_pair_direction);
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
      if(!QM_NewsAllowsTrade2(g_leg_xau,
                              broker_time,
                              qm_news_temporal,
                              qm_news_compliance))
         return false;
      if(!QM_NewsAllowsTrade2(g_leg_xag,
                              broker_time,
                              qm_news_temporal,
                              qm_news_compliance))
         return false;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_xau, broker_time, qm_news_mode_legacy))
         return false;
      if(!QM_NewsAllowsTrade(g_leg_xag, broker_time, qm_news_mode_legacy))
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
   SymbolSelect(g_leg_xau, true);
   SymbolSelect(g_leg_xag, true);

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

   if(Strategy_NoTradeFilter())
     {
      QM_FrameworkShutdown();
      return INIT_PARAMETERS_INCORRECT;
     }

   g_attempt_state_key =
      StringFormat("QM5_20236_MONTH_ATTEMPT_%d",
                   QM_MagicChecked(qm_ea_id, 0, g_leg_xau));
   Strategy_LoadAttemptState();

   string basket_symbols[2] = {g_leg_xau, g_leg_xag};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          MathMax(400, strategy_history_bars));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20236\",\"ea\":\"xauxag-vov-rank\"}");
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
