#property strict
#property version   "5.0"
#property description "QM5_13113 Energy Momentum IVol Double Screen"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_13113 - XTI/XNG Momentum + Idiosyncratic-Volatility Double Screen
// -----------------------------------------------------------------------------
// Monthly market-neutral energy basket:
//   - rank XTI and XNG by completed 3-month D1 momentum
//   - estimate each leg's residual volatility against an equal-weight
//     XTI/XNG/XAU/XAG commodity factor over the same window
//   - trade only when the momentum winner is also the lower-IVol leg
// XAU and XAG are read-only factor members. Runtime is Darwinex-native OHLC.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13113;
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
input int    strategy_signal_lookback_d1 = 63;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 3.0;
input int    strategy_max_hold_days      = 35;
input int    strategy_xti_max_spread_pts = 1500;
input int    strategy_xng_max_spread_pts = 3000;
input int    strategy_deviation_points   = 20;

string g_leg_xti = "XTIUSD.DWX";
string g_leg_xng = "XNGUSD.DWX";
string g_factor_xau = "XAUUSD.DWX";
string g_factor_xag = "XAGUSD.DWX";

bool     g_monthly_rebalance_bar = false;
bool     g_cache_signal_valid = false;
int      g_cache_pair_direction = 0;
int      g_cache_month_key = 0;
int      g_last_entry_month_key = 0;
datetime g_pair_entry_time = 0;
double   g_cache_xti_momentum_pct = 0.0;
double   g_cache_xng_momentum_pct = 0.0;
double   g_cache_xti_ivol = 0.0;
double   g_cache_xng_ivol = 0.0;

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

int Strategy_CurrentPairDirection()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != g_leg_xti)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != QM_MagicChecked(qm_ea_id, 0, g_leg_xti))
         continue;
      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return (position_type == POSITION_TYPE_BUY) ? 1 : -1;
     }
   return 0;
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

bool Strategy_ResidualStd(const double &asset_returns[],
                          const double &factor_returns[],
                          const int count,
                          double &residual_std)
  {
   residual_std = 0.0;
   if(count < 20 || ArraySize(asset_returns) < count || ArraySize(factor_returns) < count)
      return false;

   double asset_sum = 0.0;
   double factor_sum = 0.0;
   for(int i = 0; i < count; ++i)
     {
      if(!MathIsValidNumber(asset_returns[i]) || !MathIsValidNumber(factor_returns[i]))
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
   if(factor_variance <= 0.0 || !MathIsValidNumber(factor_variance))
      return false;

   const double beta = covariance / factor_variance;
   const double alpha = asset_mean - beta * factor_mean;
   if(!MathIsValidNumber(alpha) || !MathIsValidNumber(beta))
      return false;

   double residual_sq_sum = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double residual = asset_returns[i] - alpha - beta * factor_returns[i];
      if(!MathIsValidNumber(residual))
         return false;
      residual_sq_sum += residual * residual;
     }

   residual_std = MathSqrt(residual_sq_sum / (double)(count - 2));
   return (residual_std > 0.0 && MathIsValidNumber(residual_std));
  }

bool Strategy_LoadSignalState(int &pair_direction)
  {
   pair_direction = 0;
   g_cache_xti_momentum_pct = 0.0;
   g_cache_xng_momentum_pct = 0.0;
   g_cache_xti_ivol = 0.0;
   g_cache_xng_ivol = 0.0;

   const int lookback = MathMax(21, strategy_signal_lookback_d1);
   const int close_count = lookback + 1;
   double xti_close[];
   double xng_close[];
   double xau_close[];
   double xag_close[];
   ArraySetAsSeries(xti_close, true);
   ArraySetAsSeries(xng_close, true);
   ArraySetAsSeries(xau_close, true);
   ArraySetAsSeries(xag_close, true);

   if(CopyClose(g_leg_xti, PERIOD_D1, 1, close_count, xti_close) != close_count) // perf-allowed: bounded monthly D1 sample.
      return false;
   if(CopyClose(g_leg_xng, PERIOD_D1, 1, close_count, xng_close) != close_count) // perf-allowed: bounded monthly D1 sample.
      return false;
   if(CopyClose(g_factor_xau, PERIOD_D1, 1, close_count, xau_close) != close_count) // perf-allowed: bounded monthly D1 factor sample.
      return false;
   if(CopyClose(g_factor_xag, PERIOD_D1, 1, close_count, xag_close) != close_count) // perf-allowed: bounded monthly D1 factor sample.
      return false;

   double xti_returns[];
   double xng_returns[];
   double factor_returns[];
   ArrayResize(xti_returns, lookback);
   ArrayResize(xng_returns, lookback);
   ArrayResize(factor_returns, lookback);

   for(int i = 0; i < lookback; ++i)
     {
      if(xti_close[i] <= 0.0 || xti_close[i + 1] <= 0.0 ||
         xng_close[i] <= 0.0 || xng_close[i + 1] <= 0.0 ||
         xau_close[i] <= 0.0 || xau_close[i + 1] <= 0.0 ||
         xag_close[i] <= 0.0 || xag_close[i + 1] <= 0.0)
         return false;

      const double xti_return = MathLog(xti_close[i] / xti_close[i + 1]);
      const double xng_return = MathLog(xng_close[i] / xng_close[i + 1]);
      const double xau_return = MathLog(xau_close[i] / xau_close[i + 1]);
      const double xag_return = MathLog(xag_close[i] / xag_close[i + 1]);
      if(!MathIsValidNumber(xti_return) || !MathIsValidNumber(xng_return) ||
         !MathIsValidNumber(xau_return) || !MathIsValidNumber(xag_return))
         return false;

      xti_returns[i] = xti_return;
      xng_returns[i] = xng_return;
      factor_returns[i] = 0.25 * (xti_return + xng_return + xau_return + xag_return);
     }

   g_cache_xti_momentum_pct = 100.0 * MathLog(xti_close[0] / xti_close[lookback]);
   g_cache_xng_momentum_pct = 100.0 * MathLog(xng_close[0] / xng_close[lookback]);
   if(!MathIsValidNumber(g_cache_xti_momentum_pct) || !MathIsValidNumber(g_cache_xng_momentum_pct))
      return false;
   if(!Strategy_ResidualStd(xti_returns, factor_returns, lookback, g_cache_xti_ivol))
      return false;
   if(!Strategy_ResidualStd(xng_returns, factor_returns, lookback, g_cache_xng_ivol))
      return false;

   if(g_cache_xti_momentum_pct > g_cache_xng_momentum_pct &&
      g_cache_xti_ivol < g_cache_xng_ivol)
      pair_direction = 1;
   else if(g_cache_xng_momentum_pct > g_cache_xti_momentum_pct &&
           g_cache_xng_ivol < g_cache_xti_ivol)
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

   g_monthly_rebalance_bar = true;
   g_cache_month_key = current_month_key;
   g_cache_signal_valid = Strategy_LoadSignalState(g_cache_pair_direction);
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
   const string reason = long_xti_short_xng ? "QM5_13113_LONG_XTI_SHORT_XNG_MOM_IVOL"
                                            : "QM5_13113_SHORT_XTI_LONG_XNG_MOM_IVOL";
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
   if(strategy_signal_lookback_d1 < 21)
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
   req.reason = "QM5_13113_ENERGY_MOM_IVOL_HOST";
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

   string basket_symbols[4] = {g_leg_xti, g_leg_xng, g_factor_xau, g_factor_xag};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          MathMax(300, strategy_signal_lookback_d1 + strategy_atr_period_d1 + 30));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13113\",\"ea\":\"energy-mom-ivol\"}");
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

