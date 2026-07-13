#property strict
#property version   "5.0"
#property description "QM5_13203 XTI XNG Downside-Beta Rank"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_13203 - XTI/XNG Monthly Downside-Beta Rank
// -----------------------------------------------------------------------------
// Source-aligned, price-native commodity downside-beta falsification:
//   - load 252 synchronized completed D1 returns for XTI, XNG, and SP500
//   - compute the trailing mean SP500 return
//   - estimate each energy leg's OLS beta, with an intercept, using only days
//     when SP500 return is below that trailing mean
//   - buy the lower downside-beta energy leg and short the higher-beta leg
//   - renew the paired package once per broker month
// SP500.DWX is a read-only equity-market proxy and is never traded by this EA.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 13203;
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
input int    strategy_lookback_d1              = 252;
input int    strategy_min_down_days            = 100;
input double strategy_beta_tie_epsilon         = 1.0e-8;
input int    strategy_history_bars             = 420;
input int    strategy_max_endpoint_gap_days    = 10;
input int    strategy_atr_period_d1             = 20;
input double strategy_atr_sl_mult               = 3.5;
input int    strategy_max_hold_days             = 40;
input int    strategy_xti_max_spread_pts        = 1500;
input int    strategy_xng_max_spread_pts        = 3000;
input int    strategy_deviation_points          = 20;

string g_leg_xti      = "XTIUSD.DWX";
string g_leg_xng      = "XNGUSD.DWX";
string g_factor_sp500 = "SP500.DWX";

bool     g_monthly_rebalance_bar      = false;
bool     g_cache_signal_valid         = false;
int      g_cache_pair_direction       = 0;
int      g_cache_period_key           = 0;
int      g_cache_decision_month_key   = 0;
int      g_last_entry_period_key      = 0;
datetime g_pair_entry_time            = 0;
double   g_cache_xti_downside_beta    = 0.0;
double   g_cache_xng_downside_beta    = 0.0;
double   g_cache_downside_beta_diff   = 0.0;
double   g_cache_sp500_mean_return    = 0.0;
int      g_cache_downside_days        = 0;

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
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
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

bool Strategy_LoadSynchronizedReturns(const datetime decision_bar_time,
                                      double &xti_returns[],
                                      double &xng_returns[],
                                      double &sp500_returns[],
                                      double &sp500_mean_return)
  {
   sp500_mean_return = 0.0;
   if(decision_bar_time <= 0 || strategy_lookback_d1 != 252)
      return false;

   const int required_closes = strategy_lookback_d1 + 1;
   if(strategy_history_bars < required_closes)
      return false;

   MqlRates xti_rates[];
   MqlRates xng_rates[];
   MqlRates sp500_rates[];
   ArraySetAsSeries(xti_rates, true);
   ArraySetAsSeries(xng_rates, true);
   ArraySetAsSeries(sp500_rates, true);

   // perf-allowed: three bounded D1 copies only on the monthly source path.
   const int xti_count = CopyRates( // perf-allowed
                                   g_leg_xti, PERIOD_D1, 1,
                                   strategy_history_bars, xti_rates);
   const int xng_count = CopyRates( // perf-allowed
                                   g_leg_xng, PERIOD_D1, 1,
                                   strategy_history_bars, xng_rates);
   const int sp500_count = CopyRates( // perf-allowed
                                     g_factor_sp500, PERIOD_D1, 1,
                                     strategy_history_bars, sp500_rates);
   if(xti_count < required_closes || xng_count < required_closes ||
      sp500_count < required_closes)
      return false;

   datetime common_times[];
   double common_xti[];
   double common_xng[];
   double common_sp500[];
   if(ArrayResize(common_times, required_closes) != required_closes ||
      ArrayResize(common_xti, required_closes) != required_closes ||
      ArrayResize(common_xng, required_closes) != required_closes ||
      ArrayResize(common_sp500, required_closes) != required_closes)
      return false;

   int xti_index = 0;
   int xng_index = 0;
   int sp500_index = 0;
   int common_count = 0;
   while(xti_index < xti_count && xng_index < xng_count &&
         sp500_index < sp500_count && common_count < required_closes)
     {
      const datetime xti_time = xti_rates[xti_index].time;
      const datetime xng_time = xng_rates[xng_index].time;
      const datetime sp500_time = sp500_rates[sp500_index].time;
      if(xti_time <= 0 || xng_time <= 0 || sp500_time <= 0)
         return false;

      datetime latest_time = xti_time;
      if(xng_time > latest_time)
         latest_time = xng_time;
      if(sp500_time > latest_time)
         latest_time = sp500_time;

      const bool common_time =
         (xti_time == xng_time && xti_time == sp500_time);
      if(common_time)
        {
         const double xti_close = xti_rates[xti_index].close;
         const double xng_close = xng_rates[xng_index].close;
         const double sp500_close = sp500_rates[sp500_index].close;
         if(xti_close <= 0.0 || xng_close <= 0.0 || sp500_close <= 0.0 ||
            !MathIsValidNumber(xti_close) ||
            !MathIsValidNumber(xng_close) ||
            !MathIsValidNumber(sp500_close))
            return false;
         if(common_count > 0 && xti_time >= common_times[common_count - 1])
            return false;

         common_times[common_count] = xti_time;
         common_xti[common_count] = xti_close;
         common_xng[common_count] = xng_close;
         common_sp500[common_count] = sp500_close;
         ++common_count;
         ++xti_index;
         ++xng_index;
         ++sp500_index;
         continue;
        }

      // Series arrays run newest to oldest. Advance every series currently at
      // the latest timestamp until all three timestamps meet.
      if(xti_time == latest_time)
         ++xti_index;
      if(xng_time == latest_time)
         ++xng_index;
      if(sp500_time == latest_time)
         ++sp500_index;
     }

   if(common_count != required_closes || common_times[0] >= decision_bar_time)
      return false;
   const long endpoint_gap = (long)(decision_bar_time - common_times[0]);
   if(endpoint_gap < 0 ||
      endpoint_gap > (long)strategy_max_endpoint_gap_days * 86400)
      return false;

   if(ArrayResize(xti_returns, strategy_lookback_d1) != strategy_lookback_d1 ||
      ArrayResize(xng_returns, strategy_lookback_d1) != strategy_lookback_d1 ||
      ArrayResize(sp500_returns, strategy_lookback_d1) != strategy_lookback_d1)
      return false;

   double sp500_sum = 0.0;
   for(int sample = 0; sample < strategy_lookback_d1; ++sample)
     {
      const int older_index = strategy_lookback_d1 - sample;
      const int newer_index = older_index - 1;
      const double xti_value =
         common_xti[newer_index] / common_xti[older_index] - 1.0;
      const double xng_value =
         common_xng[newer_index] / common_xng[older_index] - 1.0;
      const double sp500_value =
         common_sp500[newer_index] / common_sp500[older_index] - 1.0;
      if(!MathIsValidNumber(xti_value) ||
         !MathIsValidNumber(xng_value) ||
         !MathIsValidNumber(sp500_value))
         return false;
      xti_returns[sample] = xti_value;
      xng_returns[sample] = xng_value;
      sp500_returns[sample] = sp500_value;
      sp500_sum += sp500_value;
     }

   sp500_mean_return = sp500_sum / (double)strategy_lookback_d1;
   return MathIsValidNumber(sp500_mean_return);
  }

bool Strategy_DownsideBeta(const double &asset_returns[],
                           const double &market_returns[],
                           const double market_mean_return,
                           double &downside_beta,
                           int &downside_days)
  {
   downside_beta = 0.0;
   downside_days = 0;
   if(ArraySize(asset_returns) != strategy_lookback_d1 ||
      ArraySize(market_returns) != strategy_lookback_d1 ||
      !MathIsValidNumber(market_mean_return))
      return false;

   double asset_sum = 0.0;
   double market_sum = 0.0;
   for(int i = 0; i < strategy_lookback_d1; ++i)
     {
      if(!MathIsValidNumber(asset_returns[i]) ||
         !MathIsValidNumber(market_returns[i]))
         return false;
      if(market_returns[i] >= market_mean_return)
         continue;
      asset_sum += asset_returns[i];
      market_sum += market_returns[i];
      ++downside_days;
     }
   if(downside_days < strategy_min_down_days)
      return false;

   const double asset_mean = asset_sum / (double)downside_days;
   const double market_downside_mean = market_sum / (double)downside_days;
   double covariance = 0.0;
   double market_variance = 0.0;
   for(int i = 0; i < strategy_lookback_d1; ++i)
     {
      if(market_returns[i] >= market_mean_return)
         continue;
      const double market_delta = market_returns[i] - market_downside_mean;
      covariance += (asset_returns[i] - asset_mean) * market_delta;
      market_variance += market_delta * market_delta;
     }
   if(market_variance <= 1.0e-16 || !MathIsValidNumber(market_variance))
      return false;

   // Demeaning the selected observations estimates the source regression with
   // an intercept; division by n versus n-1 cancels in covariance / variance.
   downside_beta = covariance / market_variance;
   return MathIsValidNumber(downside_beta);
  }

bool Strategy_LoadSignalState(const datetime decision_bar_time,
                              int &pair_direction)
  {
   pair_direction = 0;
   g_cache_xti_downside_beta = 0.0;
   g_cache_xng_downside_beta = 0.0;
   g_cache_downside_beta_diff = 0.0;
   g_cache_sp500_mean_return = 0.0;
   g_cache_downside_days = 0;

   double xti_returns[];
   double xng_returns[];
   double sp500_returns[];
   if(!Strategy_LoadSynchronizedReturns(decision_bar_time,
                                        xti_returns,
                                        xng_returns,
                                        sp500_returns,
                                        g_cache_sp500_mean_return))
      return false;

   int xti_downside_days = 0;
   int xng_downside_days = 0;
   if(!Strategy_DownsideBeta(xti_returns,
                             sp500_returns,
                             g_cache_sp500_mean_return,
                             g_cache_xti_downside_beta,
                             xti_downside_days))
      return false;
   if(!Strategy_DownsideBeta(xng_returns,
                             sp500_returns,
                             g_cache_sp500_mean_return,
                             g_cache_xng_downside_beta,
                             xng_downside_days))
      return false;
   if(xti_downside_days != xng_downside_days)
      return false;
   g_cache_downside_days = xti_downside_days;

   g_cache_downside_beta_diff =
      g_cache_xti_downside_beta - g_cache_xng_downside_beta;
   if(!MathIsValidNumber(g_cache_downside_beta_diff))
      return false;

   // The source's high-minus-low downside-beta spread is negative. Express the
   // falsification as low-minus-high: long the lower-beta energy leg.
   if(g_cache_downside_beta_diff < -strategy_beta_tie_epsilon)
      pair_direction = 1;  // XTI beta is lower: long XTI, short XNG.
   else if(g_cache_downside_beta_diff > strategy_beta_tie_epsilon)
      pair_direction = -1; // XNG beta is lower: short XTI, long XNG.
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

void Strategy_AdvanceSignal_OnNewBar()
  {
   g_monthly_rebalance_bar = false;
   const int current_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 0);
   const int prior_month_key = QM_CalendarPeriodKey(PERIOD_MN1, _Symbol, 1);
   if(current_month_key <= 0 || prior_month_key <= 0 ||
      current_month_key == prior_month_key)
      return;

   MqlRates decision_rates[1];
   // perf-allowed: one current host D1 bar on the monthly new-bar path.
   if(CopyRates( // perf-allowed
                _Symbol, PERIOD_D1, 0, 1, decision_rates) != 1 ||
      decision_rates[0].time <= 0)
      return;

   g_monthly_rebalance_bar = true;
   g_cache_period_key = Strategy_PeriodKeyForTime(decision_rates[0].time);
   g_cache_decision_month_key = current_month_key;
   g_cache_signal_valid = Strategy_LoadSignalState(decision_rates[0].time,
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
   double lots =
      QM_LotsForRisk(symbol, sl_points) * risk_weight / risk_weight_sum;
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

   const double entry = QM_OrderTypeIsBuy(type)
                        ? SymbolInfoDouble(symbol, SYMBOL_ASK)
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
   req.sl = QM_OrderTypeIsBuy(type)
            ? NormalizeDouble(entry - stop_dist, digits)
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
   const string reason = long_xti_short_xng
                         ? "QM5_13203_LONG_XTI_SHORT_XNG_LOW_DBETA"
                         : "QM5_13203_SHORT_XTI_LONG_XNG_LOW_DBETA";
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
   if(strategy_lookback_d1 != 252 || strategy_min_down_days != 100 ||
      MathAbs(strategy_beta_tie_epsilon - 1.0e-8) > 1.0e-16)
      return true;
   if(strategy_history_bars < 360 || strategy_history_bars > 500)
      return true;
   if(strategy_max_endpoint_gap_days < 7 ||
      strategy_max_endpoint_gap_days > 10)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_max_hold_days != 40)
      return true;
   if(strategy_xti_max_spread_pts <= 0 || strategy_xng_max_spread_pts <= 0 ||
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
   req.reason = "QM5_13203_XTI_XNG_DOWNBETA_HOST";
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
   SymbolSelect(g_factor_sp500, true);

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

   string basket_symbols[3] = {g_leg_xti, g_leg_xng, g_factor_sp500};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          MathMax(500, strategy_history_bars));

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"card\":\"QM5_13203\",\"ea\":\"energy-downbeta\"}");
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
