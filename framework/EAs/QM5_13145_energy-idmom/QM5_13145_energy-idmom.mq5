#property strict
#property version   "5.0"
#property description "QM5_13145 XTI XNG Idiosyncratic Momentum"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_13145 - XTI/XNG 11-Month Idiosyncratic Momentum
// -----------------------------------------------------------------------------
// Monthly opposite-side energy package:
//   - reconstruct eleven completed monthly returns for XTI/XNG/XAU/XAG
//   - remove each energy leg's exposure to an equal-weight commodity factor
//   - buy the higher cumulative residual-return leg and short the lower leg
//   - hold one broker calendar month with equal fixed-risk halves
// Runtime is Darwinex-native D1 close data only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 13145;
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
input int    strategy_ranking_months           = 11;
input int    strategy_history_bars            = 420;
input int    strategy_max_boundary_gap_days   = 10;
input int    strategy_atr_period_d1            = 20;
input double strategy_atr_sl_mult              = 3.5;
input int    strategy_max_hold_days            = 35;
input int    strategy_xti_max_spread_pts       = 1500;
input int    strategy_xng_max_spread_pts       = 3000;
input int    strategy_deviation_points         = 20;

string g_leg_xti = "XTIUSD.DWX";
string g_leg_xng = "XNGUSD.DWX";
string g_factor_xau = "XAUUSD.DWX";
string g_factor_xag = "XAGUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_period_key = 0;
int      g_cache_decision_month_key = 0;
int      g_last_entry_period_key = 0;
datetime g_pair_entry_time = 0;
double   g_cache_xti_idmom = 0.0;
double   g_cache_xng_idmom = 0.0;
double   g_cache_xti_beta = 0.0;
double   g_cache_xng_beta = 0.0;
double   g_cache_score_difference = 0.0;

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

bool Strategy_MonthlyReturns(const string symbol,
                             const datetime decision_bar_time,
                             double &monthly_returns[])
  {
   ArrayResize(monthly_returns, 0);
   if(strategy_ranking_months < 2)
      return false;

   MqlDateTime decision_dt;
   TimeToStruct(decision_bar_time, decision_dt);
   if(decision_dt.year <= 0 || decision_dt.mon < 1 || decision_dt.mon > 12)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int count = CopyRates(symbol, PERIOD_D1, 1, strategy_history_bars, rates); // perf-allowed: bounded copy only on a monthly D1 rebalance bar.
   if(count < MathMax(180, strategy_ranking_months * 18))
      return false;

   double boundary_close[];
   datetime boundary_close_time[];
   const int endpoint_count = strategy_ranking_months + 1;
   ArrayResize(boundary_close, endpoint_count);
   ArrayResize(boundary_close_time, endpoint_count);
   ArrayInitialize(boundary_close, 0.0);
   ArrayInitialize(boundary_close_time, 0);

   const long max_gap_seconds = (long)strategy_max_boundary_gap_days * 86400;
   for(int endpoint = 0; endpoint < endpoint_count; ++endpoint)
     {
      MqlDateTime boundary_dt;
      Strategy_ShiftMonths(decision_dt, endpoint, boundary_dt);
      const datetime boundary_time = StructToTime(boundary_dt);
      if(boundary_time <= 0)
         return false;

      for(int i = 0; i < count; ++i)
        {
         if(rates[i].time >= boundary_time)
            continue;
         if(rates[i].close <= 0.0 || !MathIsValidNumber(rates[i].close))
            continue;
         boundary_close[endpoint] = rates[i].close;
         boundary_close_time[endpoint] = rates[i].time;
         break;
        }

      const long boundary_gap = (long)(boundary_time - boundary_close_time[endpoint]);
      if(boundary_close_time[endpoint] <= 0 || boundary_close[endpoint] <= 0.0 ||
         boundary_gap <= 0 || boundary_gap > max_gap_seconds)
         return false;
     }

   ArrayResize(monthly_returns, strategy_ranking_months);
   for(int month = 0; month < strategy_ranking_months; ++month)
     {
      if(boundary_close_time[month] <= boundary_close_time[month + 1])
         return false;
      monthly_returns[month] = MathLog(boundary_close[month] /
                                       boundary_close[month + 1]);
      if(!MathIsValidNumber(monthly_returns[month]))
         return false;
     }
   return true;
  }

bool Strategy_IdiosyncraticMomentum(const double &asset_returns[],
                                    const double &factor_returns[],
                                    const int count,
                                    double &score,
                                    double &beta,
                                    double &residual_std)
  {
   score = 0.0;
   beta = 0.0;
   residual_std = 0.0;
   if(count < 6 || ArraySize(asset_returns) < count ||
      ArraySize(factor_returns) < count)
      return false;

   double asset_sum = 0.0;
   double factor_sum = 0.0;
   for(int i = 0; i < count; ++i)
     {
      if(!MathIsValidNumber(asset_returns[i]) ||
         !MathIsValidNumber(factor_returns[i]))
         return false;
      asset_sum += asset_returns[i];
      factor_sum += factor_returns[i];
     }

   const double asset_mean = asset_sum / (double)count;
   const double factor_mean = factor_sum / (double)count;
   double covariance = 0.0;
   double factor_variance = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double factor_delta = factor_returns[i] - factor_mean;
      covariance += (asset_returns[i] - asset_mean) * factor_delta;
      factor_variance += factor_delta * factor_delta;
     }
   if(factor_variance <= 1.0e-16 || !MathIsValidNumber(factor_variance))
      return false;

   beta = covariance / factor_variance;
   const double alpha = asset_mean - beta * factor_mean;
   if(!MathIsValidNumber(alpha) || !MathIsValidNumber(beta))
      return false;

   double residual_sq_sum = 0.0;
   for(int i = 0; i < count; ++i)
     {
      // Shpak-Human-Nardon Eq. (3): alpha controls model misspecification
      // and is deliberately not subtracted from the ranking residual return.
      const double ranking_residual = asset_returns[i] -
                                      beta * factor_returns[i];
      const double fitted_residual = asset_returns[i] - alpha -
                                     beta * factor_returns[i];
      if(!MathIsValidNumber(ranking_residual) ||
         !MathIsValidNumber(fitted_residual))
         return false;
      score += ranking_residual;
      residual_sq_sum += fitted_residual * fitted_residual;
     }

   residual_std = MathSqrt(residual_sq_sum / (double)(count - 2));
   return (MathIsValidNumber(score) && MathIsValidNumber(residual_std) &&
           residual_std > 0.0);
  }

bool Strategy_LoadSignalState(const datetime decision_bar_time,
                              int &pair_direction)
  {
   pair_direction = 0;
   g_cache_xti_idmom = 0.0;
   g_cache_xng_idmom = 0.0;
   g_cache_xti_beta = 0.0;
   g_cache_xng_beta = 0.0;
   g_cache_score_difference = 0.0;

   double xti_returns[];
   double xng_returns[];
   double xau_returns[];
   double xag_returns[];
   if(!Strategy_MonthlyReturns(g_leg_xti, decision_bar_time, xti_returns) ||
      !Strategy_MonthlyReturns(g_leg_xng, decision_bar_time, xng_returns) ||
      !Strategy_MonthlyReturns(g_factor_xau, decision_bar_time, xau_returns) ||
      !Strategy_MonthlyReturns(g_factor_xag, decision_bar_time, xag_returns))
      return false;

   const int count = strategy_ranking_months;
   double factor_returns[];
   ArrayResize(factor_returns, count);
   for(int i = 0; i < count; ++i)
     {
      factor_returns[i] = 0.25 * (xti_returns[i] + xng_returns[i] +
                                  xau_returns[i] + xag_returns[i]);
      if(!MathIsValidNumber(factor_returns[i]))
         return false;
     }

   double xti_residual_std = 0.0;
   double xng_residual_std = 0.0;
   if(!Strategy_IdiosyncraticMomentum(xti_returns,
                                     factor_returns,
                                     count,
                                     g_cache_xti_idmom,
                                     g_cache_xti_beta,
                                     xti_residual_std))
      return false;
   if(!Strategy_IdiosyncraticMomentum(xng_returns,
                                     factor_returns,
                                     count,
                                     g_cache_xng_idmom,
                                     g_cache_xng_beta,
                                     xng_residual_std))
      return false;

   g_cache_score_difference = g_cache_xti_idmom - g_cache_xng_idmom;
   if(!MathIsValidNumber(g_cache_score_difference))
      return false;
   if(g_cache_score_difference > 1.0e-12)
      pair_direction = 1;
   else if(g_cache_score_difference < -1.0e-12)
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
   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int prior_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(current_month_key <= 0 || prior_month_key <= 0 ||
      current_month_key == prior_month_key)
      return;

   MqlRates decision_bars[1];
   if(CopyRates(_Symbol, PERIOD_D1, 0, 1, decision_bars) != 1) // perf-allowed: one host timestamp on the D1 new-bar path.
      return;
   const datetime decision_bar_time = decision_bars[0].time;

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
   const string reason = long_xti_short_xng ? "QM5_13145_LONG_XTI_SHORT_XNG_IDMOM"
                                            : "QM5_13145_SHORT_XTI_LONG_XNG_IDMOM";
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
   if(strategy_ranking_months != 11)
      return true;
   if(strategy_history_bars < 380 || strategy_history_bars > 500)
      return true;
   if(strategy_max_boundary_gap_days < 7 || strategy_max_boundary_gap_days > 10)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_max_hold_days != 35)
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
   req.reason = "QM5_13145_XTI_XNG_IDMOM_HOST";
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
   SymbolSelect(g_factor_xau, true);
   SymbolSelect(g_factor_xag, true);

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

   string basket_symbols[4] = {g_leg_xti, g_leg_xng,
                               g_factor_xau, g_factor_xag};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          MathMax(420, strategy_history_bars));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13145\",\"ea\":\"energy-idmom\"}");
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
