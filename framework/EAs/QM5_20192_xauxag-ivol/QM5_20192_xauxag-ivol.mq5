#property strict
#property version   "5.0"
#property description "QM5_20192 XAU XAG Pure IVol Spread"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_20192 - XAU/XAG Pure Idiosyncratic-Volatility Spread
// -----------------------------------------------------------------------------
// Monthly source-specified pure-IVol precious-metals basket:
//   - align 253 completed D1 closes for XTI, XNG, XAU, and XAG
//   - regress 252 XAU and XAG returns on their equal-weight commodity factor
//   - buy lower residual volatility and sell higher residual volatility
//   - target equal dollar notional inside one fixed package stop-risk budget
// XTI and XNG are read-only factor members. Runtime is Darwinex-native OHLC.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 20192;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = false;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_ivol_lookback_d1      = 252;
input int    strategy_atr_period_d1          = 20;
input double strategy_atr_sl_mult            = 3.0;
input double strategy_max_notional_mismatch_pct = 20.0;
input int    strategy_max_hold_days          = 35;
input int    strategy_xau_max_spread_pts     = 1500;
input int    strategy_xag_max_spread_pts     = 3000;
input int    strategy_deviation_points       = 20;

string g_leg_xau = "XAUUSD.DWX";
string g_leg_xag = "XAGUSD.DWX";
string g_factor_xti = "XTIUSD.DWX";
string g_factor_xng = "XNGUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_period_key = 0;
int      g_cache_decision_month_key = 0;
int      g_last_entry_period_key = 0;
datetime g_pair_entry_time = 0;
double   g_cache_xau_ivol = 0.0;
double   g_cache_xag_ivol = 0.0;
double   g_cache_ivol_difference = 0.0;
double   g_cache_notional_mismatch_pct = 0.0;

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
   return (_Symbol == g_leg_xau && _Period == PERIOD_D1 &&
           qm_magic_slot_offset == 0);
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
   return ((int)PositionGetInteger(POSITION_MAGIC) ==
           QM_MagicChecked(qm_ea_id, slot, symbol));
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
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsPairPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (earliest == 0 || opened < earliest))
         earliest = opened;
     }
   return earliest;
  }

bool Strategy_PairCompositionValid(const int expected_pair_direction = 0)
  {
   int xau_direction = 0;
   int xag_direction = 0;
   int xau_count = 0;
   int xag_count = 0;
   bool stops_valid = true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsPairPosition())
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int direction = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
      const double stop_loss = PositionGetDouble(POSITION_SL);
      if(stop_loss <= 0.0 || !MathIsValidNumber(stop_loss))
         stops_valid = false;

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

   if(!stops_valid || xau_count != 1 || xag_count != 1 ||
      xau_direction != -xag_direction)
      return false;
   if(expected_pair_direction != 0 && xau_direction != expected_pair_direction)
      return false;
   return true;
  }

int Strategy_MonthKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts) || parts.year <= 0 ||
      parts.mon < 1 || parts.mon > 12)
      return 0;
   return parts.year * 100 + parts.mon;
  }

int Strategy_PeriodKeyForTime(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime parts;
   ZeroMemory(parts);
   if(!TimeToStruct(value, parts) || parts.year <= 0 ||
      parts.mon < 1 || parts.mon > 12)
      return 0;
   return parts.year * 12 + parts.mon;
  }

string Strategy_AttemptStateName()
  {
   return "QM5_20192_XAUXAG_IVOL_ATTEMPT";
  }

bool Strategy_ConsumePeriodAttempt(const int period_key)
  {
   if(period_key <= 0)
      return false;

   const string state_name = Strategy_AttemptStateName();
   if(GlobalVariableCheck(state_name))
     {
      const double stored_value = GlobalVariableGet(state_name);
      if(!MathIsValidNumber(stored_value))
         return false;
      const int stored_period_key = (int)MathRound(stored_value);
      if(stored_period_key >= period_key)
         return false;
     }

   if(GlobalVariableSet(state_name, (double)period_key) <= 0)
      return false;
   GlobalVariablesFlush();
   return true;
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
   if(g_last_entry_period_key == period_key)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         !Strategy_IsPairPosition())
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
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_PeriodKeyForTime(deal_time) == period_key)
         return true;
     }
   return false;
  }

bool Strategy_ResidualStd(const double &asset_returns[],
                          const double &factor_returns[],
                          const int count,
                          double &residual_std)
  {
   residual_std = 0.0;
   if(count != strategy_ivol_lookback_d1 || count <= 2 ||
      ArraySize(asset_returns) < count || ArraySize(factor_returns) < count)
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
   if(factor_variance <= 1.0e-18 || !MathIsValidNumber(factor_variance))
      return false;

   const double beta = covariance / factor_variance;
   const double alpha = asset_mean - beta * factor_mean;
   if(!MathIsValidNumber(alpha) || !MathIsValidNumber(beta))
      return false;

   double residual_sq_sum = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double residual = asset_returns[i] - alpha -
                              beta * factor_returns[i];
      if(!MathIsValidNumber(residual))
         return false;
      residual_sq_sum += residual * residual;
     }

   residual_std = MathSqrt(residual_sq_sum / (double)(count - 2));
   return (residual_std > 0.0 && MathIsValidNumber(residual_std));
  }

bool Strategy_LoadAlignedCloses(double &xti_close[],
                                double &xng_close[],
                                double &xau_close[],
                                double &xag_close[],
                                datetime &aligned_time[])
  {
   const int close_count = strategy_ivol_lookback_d1 + 1;
   const int buffer_count = MathMax(420, close_count + 160);

   MqlRates xti_rates[];
   MqlRates xng_rates[];
   MqlRates xau_rates[];
   MqlRates xag_rates[];
   ArraySetAsSeries(xti_rates, true);
   ArraySetAsSeries(xng_rates, true);
   ArraySetAsSeries(xau_rates, true);
   ArraySetAsSeries(xag_rates, true);

   const int xti_count = CopyRates(g_factor_xti, PERIOD_D1, 1, // perf-allowed: bounded monthly D1 factor sample.
                                   buffer_count, xti_rates);
   const int xng_count = CopyRates(g_factor_xng, PERIOD_D1, 1, // perf-allowed: bounded monthly D1 factor sample.
                                   buffer_count, xng_rates);
   const int xau_count = CopyRates(g_leg_xau, PERIOD_D1, 1, // perf-allowed: bounded monthly D1 traded sample.
                                   buffer_count, xau_rates);
   const int xag_count = CopyRates(g_leg_xag, PERIOD_D1, 1, // perf-allowed: bounded monthly D1 traded sample.
                                   buffer_count, xag_rates);
   if(xti_count < close_count || xng_count < close_count ||
      xau_count < close_count || xag_count < close_count)
      return false;

   ArrayResize(xti_close, close_count);
   ArrayResize(xng_close, close_count);
   ArrayResize(xau_close, close_count);
   ArrayResize(xag_close, close_count);
   ArrayResize(aligned_time, close_count);

   int xti_cursor = 0;
   int xng_cursor = 0;
   int xag_cursor = 0;
   int accepted = 0;

   for(int xau_cursor = 0;
       xau_cursor < xau_count && accepted < close_count;
       ++xau_cursor)
     {
      const datetime target_time = xau_rates[xau_cursor].time;
      if(target_time <= 0)
         continue;

      while(xti_cursor < xti_count &&
            xti_rates[xti_cursor].time > target_time)
         ++xti_cursor;
      while(xng_cursor < xng_count &&
            xng_rates[xng_cursor].time > target_time)
         ++xng_cursor;
      while(xag_cursor < xag_count &&
            xag_rates[xag_cursor].time > target_time)
         ++xag_cursor;

      if(xti_cursor >= xti_count || xng_cursor >= xng_count ||
         xag_cursor >= xag_count)
         break;
      if(xti_rates[xti_cursor].time != target_time ||
         xng_rates[xng_cursor].time != target_time ||
         xag_rates[xag_cursor].time != target_time)
         continue;

      const double xti_value = xti_rates[xti_cursor].close;
      const double xng_value = xng_rates[xng_cursor].close;
      const double xau_value = xau_rates[xau_cursor].close;
      const double xag_value = xag_rates[xag_cursor].close;
      if(xti_value <= 0.0 || xng_value <= 0.0 ||
         xau_value <= 0.0 || xag_value <= 0.0)
         return false;

      xti_close[accepted] = xti_value;
      xng_close[accepted] = xng_value;
      xau_close[accepted] = xau_value;
      xag_close[accepted] = xag_value;
      aligned_time[accepted] = target_time;
      ++accepted;
     }

   if(accepted != close_count)
      return false;
   for(int i = 0; i < close_count - 1; ++i)
     {
      const long gap_seconds =
         (long)(aligned_time[i] - aligned_time[i + 1]);
      if(gap_seconds <= 0 || gap_seconds > 7 * 86400)
         return false;
     }
   return true;
  }

bool Strategy_LoadSignalState(int &pair_direction)
  {
   pair_direction = 0;
   g_cache_xau_ivol = 0.0;
   g_cache_xag_ivol = 0.0;
   g_cache_ivol_difference = 0.0;

   double xti_close[];
   double xng_close[];
   double xau_close[];
   double xag_close[];
   datetime aligned_time[];
   if(!Strategy_LoadAlignedCloses(xti_close, xng_close,
                                  xau_close, xag_close, aligned_time))
      return false;

   const int lookback = strategy_ivol_lookback_d1;
   double xau_returns[];
   double xag_returns[];
   double factor_returns[];
   ArrayResize(xau_returns, lookback);
   ArrayResize(xag_returns, lookback);
   ArrayResize(factor_returns, lookback);

   for(int i = 0; i < lookback; ++i)
     {
      const double xti_return = MathLog(xti_close[i] / xti_close[i + 1]);
      const double xng_return = MathLog(xng_close[i] / xng_close[i + 1]);
      const double xau_return = MathLog(xau_close[i] / xau_close[i + 1]);
      const double xag_return = MathLog(xag_close[i] / xag_close[i + 1]);
      if(!MathIsValidNumber(xti_return) ||
         !MathIsValidNumber(xng_return) ||
         !MathIsValidNumber(xau_return) ||
         !MathIsValidNumber(xag_return))
         return false;

      xau_returns[i] = xau_return;
      xag_returns[i] = xag_return;
      factor_returns[i] = 0.25 *
                          (xti_return + xng_return +
                           xau_return + xag_return);
     }

   if(!Strategy_ResidualStd(xau_returns, factor_returns, lookback,
                            g_cache_xau_ivol) ||
      !Strategy_ResidualStd(xag_returns, factor_returns, lookback,
                            g_cache_xag_ivol))
      return false;

   g_cache_ivol_difference = g_cache_xau_ivol - g_cache_xag_ivol;
   if(!MathIsValidNumber(g_cache_ivol_difference))
      return false;
   if(g_cache_ivol_difference < -1.0e-12)
      pair_direction = 1;  // XAU has lower IVol: long XAU, short XAG.
   else if(g_cache_ivol_difference > 1.0e-12)
      pair_direction = -1; // XAG has lower IVol: short XAU, long XAG.
   return true;
  }

void Strategy_AdvanceSignal_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   g_cache_signal_valid = false;
   g_cache_pair_direction = 0;

   const datetime decision_bar_time =
      iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: cached timestamp on D1 new-bar path.
   const datetime prior_bar_time =
      iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: exact monthly D1 transition check.
   const int current_month_key = Strategy_MonthKeyForTime(decision_bar_time);
   const int prior_month_key = Strategy_MonthKeyForTime(prior_bar_time);
   if(current_month_key <= 0 || prior_month_key <= 0 ||
      current_month_key == prior_month_key)
      return;

   g_monthly_rebalance_bar = true;
   g_cache_period_key = Strategy_PeriodKeyForTime(decision_bar_time);
   g_cache_decision_month_key = current_month_key;
  }

bool Strategy_MaxHoldExceeded()
  {
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_CurrentPairEntryTime();
   if(entry_time <= 0)
      return false;
   const long hold_seconds =
      (long)MathMax(1, strategy_max_hold_days) * 86400;
   return ((long)(TimeCurrent() - entry_time) >= hold_seconds);
  }

double Strategy_CurrentEntryPrice(const string symbol,
                                  const QM_OrderType type)
  {
   MqlTick tick;
   if(!SymbolInfoTick(symbol, tick))
      return 0.0;
   const double entry = QM_OrderTypeIsBuy(type) ? tick.ask : tick.bid;
   if(entry <= 0.0 || !MathIsValidNumber(entry))
      return 0.0;
   return entry;
  }

double Strategy_RiskWeightForEqualNotional(const string symbol,
                                           const QM_OrderType type)
  {
   const double entry = Strategy_CurrentEntryPrice(symbol, type);
   const double atr = QM_ATR(symbol, PERIOD_D1,
                             strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return 0.0;
   const double weight = strategy_atr_sl_mult * atr / entry;
   if(weight <= 0.0 || !MathIsValidNumber(weight))
      return 0.0;
   return weight;
  }

double Strategy_LotsForLeg(const string symbol,
                           const double risk_weight,
                           const double risk_weight_sum)
  {
   const double atr = QM_ATR(symbol, PERIOD_D1,
                             strategy_atr_period_d1, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 || risk_weight <= 0.0 ||
      risk_weight_sum <= 0.0)
      return 0.0;

   const double sl_points = strategy_atr_sl_mult * atr / point;
   double lots = QM_LotsForRisk(symbol, sl_points) *
                 risk_weight / risk_weight_sum;
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

double Strategy_NotionalExposure(const string symbol,
                                 const QM_OrderType type,
                                 const double lots)
  {
   const double entry = Strategy_CurrentEntryPrice(symbol, type);
   const double tick_size =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value =
      SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(entry <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0 || lots <= 0.0)
      return 0.0;
   const double exposure = lots * entry * tick_value / tick_size;
   if(exposure <= 0.0 || !MathIsValidNumber(exposure))
      return 0.0;
   return exposure;
  }

bool Strategy_PrepareLeg(const string symbol,
                         const QM_OrderType type,
                         const double risk_weight,
                         const double risk_weight_sum,
                         const string reason,
                         QM_BasketOrderRequest &req,
                         double &notional)
  {
   notional = 0.0;
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0 || !Strategy_SpreadAllowed(symbol))
      return false;

   const double entry = Strategy_CurrentEntryPrice(symbol, type);
   const double atr = QM_ATR(symbol, PERIOD_D1,
                             strategy_atr_period_d1, 1);
   const double lots = Strategy_LotsForLeg(symbol, risk_weight,
                                            risk_weight_sum);
   if(entry <= 0.0 || atr <= 0.0 || lots <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double stop_distance = strategy_atr_sl_mult * atr;
   const double stop_loss = QM_OrderTypeIsBuy(type)
                            ? NormalizeDouble(entry - stop_distance, digits)
                            : NormalizeDouble(entry + stop_distance, digits);
   if(stop_loss <= 0.0 || !MathIsValidNumber(stop_loss))
      return false;

   notional = Strategy_NotionalExposure(symbol, type, lots);
   if(notional <= 0.0)
      return false;

   req.symbol = symbol;
   req.type = type;
   req.price = 0.0;
   req.sl = stop_loss;
   req.tp = 0.0;
   req.lots = lots;
   req.reason = reason;
   req.symbol_slot = slot;
   req.expiration_seconds = 0;
   return true;
  }

bool Strategy_SubmitLeg(const QM_BasketOrderRequest &req)
  {
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
   if(!Strategy_SpreadAllowed(g_leg_xau) ||
      !Strategy_SpreadAllowed(g_leg_xag))
      return false;

   const bool long_xau_short_xag = (pair_direction > 0);
   const QM_OrderType xau_type = long_xau_short_xag ? QM_BUY : QM_SELL;
   const QM_OrderType xag_type = long_xau_short_xag ? QM_SELL : QM_BUY;
   const string reason = long_xau_short_xag
                         ? "QM5_20192_LONG_XAU_SHORT_XAG_IVOL"
                         : "QM5_20192_SHORT_XAU_LONG_XAG_IVOL";

   const double xau_risk_weight =
      Strategy_RiskWeightForEqualNotional(g_leg_xau, xau_type);
   const double xag_risk_weight =
      Strategy_RiskWeightForEqualNotional(g_leg_xag, xag_type);
   const double risk_weight_sum = xau_risk_weight + xag_risk_weight;
   if(xau_risk_weight <= 0.0 || xag_risk_weight <= 0.0 ||
      risk_weight_sum <= 0.0)
      return false;

   QM_BasketOrderRequest xau_req;
   QM_BasketOrderRequest xag_req;
   double xau_notional = 0.0;
   double xag_notional = 0.0;
   if(!Strategy_PrepareLeg(g_leg_xau, xau_type,
                           xau_risk_weight, risk_weight_sum,
                           reason, xau_req, xau_notional) ||
      !Strategy_PrepareLeg(g_leg_xag, xag_type,
                           xag_risk_weight, risk_weight_sum,
                           reason, xag_req, xag_notional))
      return false;

   const double max_notional = MathMax(xau_notional, xag_notional);
   if(max_notional <= 0.0)
      return false;
   g_cache_notional_mismatch_pct =
      100.0 * MathAbs(xau_notional - xag_notional) / max_notional;
   if(!MathIsValidNumber(g_cache_notional_mismatch_pct) ||
      g_cache_notional_mismatch_pct >
         strategy_max_notional_mismatch_pct)
      return false;

   if(!Strategy_SubmitLeg(xau_req))
      return false;
   if(Strategy_SubmitLeg(xag_req) &&
      Strategy_OpenPairLegCount() == 2 &&
      Strategy_PairCompositionValid(pair_direction))
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
   if(qm_ea_id != 20192 || qm_magic_slot_offset != 0 || qm_rng_seed != 42)
      return true;
   if(RISK_PERCENT != 0.0 || RISK_FIXED != 1000.0 ||
      PORTFOLIO_WEIGHT != 1.0)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE ||
      qm_news_mode_legacy != QM_NEWS_OFF ||
      qm_news_stale_max_hours != 336 || qm_news_min_impact != "high")
      return true;
   if(qm_friday_close_enabled || qm_friday_close_hour_broker != 21 ||
      qm_stress_reject_probability != 0.0)
      return true;
   if(strategy_ivol_lookback_d1 != 252 ||
      strategy_atr_period_d1 != 20 ||
      MathAbs(strategy_atr_sl_mult - 3.0) > 1.0e-12 ||
      MathAbs(strategy_max_notional_mismatch_pct - 20.0) > 1.0e-12 ||
      strategy_max_hold_days != 35)
      return true;
   if(strategy_xau_max_spread_pts != 1500 ||
      strategy_xag_max_spread_pts != 3000 ||
      strategy_deviation_points != 20)
      return true;
   return false;
  }

bool Strategy_NewsAllowsEntry(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_leg_xau, broker_time,
                              qm_news_temporal, qm_news_compliance))
         return false;
      if(!QM_NewsAllowsTrade2(g_leg_xag, broker_time,
                              qm_news_temporal, qm_news_compliance))
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

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_20192_XAU_XAG_IVOL_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_monthly_rebalance_bar || g_cache_period_key <= 0 ||
      g_cache_decision_month_key <= 0)
      return false;
   if(!Strategy_ConsumePeriodAttempt(g_cache_period_key))
      return false;
   if(Strategy_PeriodAlreadyEntered(g_cache_period_key,
                                    g_cache_decision_month_key))
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_NewsAllowsEntry(TimeCurrent()))
      return false;

   g_cache_signal_valid = Strategy_LoadSignalState(g_cache_pair_direction);
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

int OnInit()
  {
   const string attempt_state_name = Strategy_AttemptStateName();
   const int current_period_key = Strategy_PeriodKeyForTime(TimeCurrent());
   if(current_period_key > 0 && GlobalVariableCheck(attempt_state_name))
     {
      const double stored_value = GlobalVariableGet(attempt_state_name);
      if(MathIsValidNumber(stored_value) &&
         (int)MathRound(stored_value) > current_period_key)
         GlobalVariableDel(attempt_state_name);
     }

   SymbolSelect(g_factor_xti, true);
   SymbolSelect(g_factor_xng, true);
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

   string basket_symbols[4] =
      {g_factor_xti, g_factor_xng, g_leg_xau, g_leg_xag};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols, PERIOD_D1, 500);

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_20192\",\"ea\":\"xauxag-ivol\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT",
               StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;
   if(QM_FrameworkHandleFridayClose())
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

   if(Strategy_NoTradeFilter() || !new_bar)
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
