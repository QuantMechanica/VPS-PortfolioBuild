#property strict
#property version   "5.0"
#property description "QM5_37006 Marcos Lopez de Prado CUSUM Structural Breakout"
// Strategy Card: QM5_37006 (cusum-filter-structural-breakout), G0 APPROVED.
// Source: Lopez de Prado, M. (2018). Advances in Financial Machine Learning. Symmetric CUSUM Filter.

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_37006 — CUSUM Structural Breakout
// -----------------------------------------------------------------------------
// Quality control Cumulative Sum (CUSUM) filter on M15 closed bars:
//   - S_pos = max(0, S_pos + delta_P - mean(delta_P, 50))
//   - S_neg = min(0, S_neg + delta_P - mean(delta_P, 50))
//   - Threshold h = 1.50 * std(delta_P, 50)
//   - Long Entry:  S_pos >= h -> BUY,  SL = 1.5*ATR(14), TP = 2.0*SL_dist (1:2 RR)
//   - Short Entry: S_neg <= -h -> SELL, SL = 1.5*ATR(14), TP = 2.0*SL_dist (1:2 RR)
//   - CUSUM Reset: S_pos = 0, S_neg = 0 on entry execution
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 37006;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_vol_window          = 50;     // Rolling return volatility window in M15 bars
input double strategy_threshold_h         = 1.50;   // Standard deviation multiplier for CUSUM threshold
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 1.50;   // Stop loss ATR multiplier
input double strategy_tp_rr               = 2.00;   // Take profit risk-reward multiplier (1:2.0)
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input int    strategy_max_slippage_ticks  = 3;      // Card ceiling for market-order slippage
input double strategy_daily_loss_limit_pct = 2.0;   // Realized-loss entry halt
input double strategy_daily_drawdown_hard_stop_pct = 2.5;
input double strategy_total_drawdown_stop_pct = 5.0;
input double strategy_per_trade_risk_cap_pct = 1.0;
input int    strategy_state_rebuild_bars  = 512;    // Fail-closed restart replay ceiling

// -----------------------------------------------------------------------------
// Cached State
// -----------------------------------------------------------------------------

double g_cusum_pos    = 0.0;
double g_cusum_neg    = 0.0;
double g_cached_atr1  = 0.0;
double g_cached_h     = 0.0;
double g_strategy_initial_equity = 0.0;
bool   g_cached_valid = false;

//+------------------------------------------------------------------+
//| Configuration and bounded CUSUM state                            |
//+------------------------------------------------------------------+
bool StrategyConfigValid()
{
   if(strategy_vol_window < 20 || strategy_vol_window > 100 ||
      strategy_threshold_h < 1.0 || strategy_threshold_h > 2.5 ||
      strategy_atr_period < 7 || strategy_atr_period > 30 ||
      strategy_sl_atr_mult < 1.0 || strategy_sl_atr_mult > 3.0 ||
      strategy_tp_rr < 1.0 || strategy_tp_rr > 4.0 ||
      MathAbs(strategy_spread_atr_mult - 1.8) > 1e-9)
      return false;

   if(strategy_max_slippage_ticks <= 0 || strategy_max_slippage_ticks > 3 ||
      strategy_daily_loss_limit_pct <= 0.0 || strategy_daily_loss_limit_pct > 2.0 ||
      strategy_daily_drawdown_hard_stop_pct <= 0.0 ||
      strategy_daily_drawdown_hard_stop_pct > 2.5 ||
      strategy_daily_loss_limit_pct > strategy_daily_drawdown_hard_stop_pct ||
      strategy_total_drawdown_stop_pct <= 0.0 ||
      strategy_total_drawdown_stop_pct > 5.0 ||
      strategy_per_trade_risk_cap_pct <= 0.0 ||
      strategy_per_trade_risk_cap_pct > 1.0)
      return false;

   return (strategy_state_rebuild_bars >= strategy_vol_window &&
           strategy_state_rebuild_bars <= 4096);
}

int StrategyDeviationPoints()
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return strategy_max_slippage_ticks;
   return (int)MathMax(1.0,
                       MathCeil(strategy_max_slippage_ticks * tick_size / point));
}

bool CalculateReturnStats(const string sym,
                          const ENUM_TIMEFRAMES tf,
                          const int lookback,
                          const int shift,
                          double &mean_return,
                          double &std_dev)
{
   mean_return = 0.0;
   std_dev = 0.0;
   if(lookback < 5 || shift < 1)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int required = lookback + 1;
   const int copied = CopyRates(sym, tf, shift, required, rates); // perf-allowed: bounded closed-bar refresh/replay only.
   if(copied != required || ArraySize(rates) < required)
      return false;

   double sum = 0.0;
   for(int i = 0; i < lookback; ++i)
      sum += rates[i].close - rates[i+1].close;
   mean_return = sum / (double)lookback;

   double var = 0.0;
   for(int i = 0; i < lookback; ++i)
   {
      const double diff = rates[i].close - rates[i+1].close;
      const double d = diff - mean_return;
      var += d * d;
   }
   std_dev = MathSqrt(var / (double)lookback);
   return (std_dev > 0.0 && MathIsValidNumber(std_dev));
}

bool StrategyApplyClosedBar(const int shift)
{
   double mean_return = 0.0;
   double std_dev = 0.0;
   if(!CalculateReturnStats(_Symbol, PERIOD_M15, strategy_vol_window,
                            shift, mean_return, std_dev))
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M15, shift, 2, rates); // perf-allowed: bounded closed-bar refresh/replay only.
   if(copied != 2 || ArraySize(rates) < 2)
      return false;

   const double centered_return = (rates[0].close - rates[1].close) - mean_return;
   g_cusum_pos = MathMax(0.0, g_cusum_pos + centered_return);
   g_cusum_neg = MathMin(0.0, g_cusum_neg + centered_return);

   if(shift == 1)
   {
      g_cached_atr1 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
      g_cached_h = strategy_threshold_h * std_dev;
      g_cached_valid = (g_cached_atr1 > 0.0 && g_cached_h > 0.0);
   }
   return true;
}

string StrategyStateKey(const string suffix)
{
   return StringFormat("QM_CUSUM_%I64d_%d_%s_%s",
                       AccountInfoInteger(ACCOUNT_LOGIN), qm_ea_id,
                       _Symbol, suffix);
}

bool StrategyPersistState(const datetime completed_bar_time)
{
   if(MQLInfoInteger(MQL_TESTER) != 0)
      return true;
   if(completed_bar_time <= 0)
      return false;

   const string bar_key = StrategyStateKey("BAR");
   GlobalVariableDel(bar_key); // BAR is the commit marker; absence forces reconstruction.
   if(GlobalVariableSet(StrategyStateKey("POS"), g_cusum_pos) == 0 ||
      GlobalVariableSet(StrategyStateKey("NEG"), g_cusum_neg) == 0 ||
      GlobalVariableSet(bar_key, (double)completed_bar_time) == 0)
      return false;
   GlobalVariablesFlush();
   return true;
}

bool StrategyRestoreState(datetime &completed_bar_time)
{
   completed_bar_time = 0;
   if(MQLInfoInteger(MQL_TESTER) != 0)
      return false;

   const string pos_key = StrategyStateKey("POS");
   const string neg_key = StrategyStateKey("NEG");
   const string bar_key = StrategyStateKey("BAR");
   if(!GlobalVariableCheck(pos_key) || !GlobalVariableCheck(neg_key) ||
      !GlobalVariableCheck(bar_key))
      return false;

   const double saved_pos = GlobalVariableGet(pos_key);
   const double saved_neg = GlobalVariableGet(neg_key);
   const double saved_bar = GlobalVariableGet(bar_key);
   if(!MathIsValidNumber(saved_pos) || !MathIsValidNumber(saved_neg) ||
      saved_pos < 0.0 || saved_neg > 0.0 || saved_bar <= 0.0)
      return false;

   g_cusum_pos = saved_pos;
   g_cusum_neg = saved_neg;
   completed_bar_time = (datetime)((long)saved_bar);
   return true;
}

datetime StrategyLastConfirmedEntryTime()
{
   if(!HistorySelect(0, TimeCurrent()))
      return 0;
   const int magic = QM_FrameworkMagic();
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 || (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
         return (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
   }
   return 0;
}

bool StrategyRebuildState()
{
   g_cached_valid = false;
   g_cached_atr1 = 0.0;
   g_cached_h = 0.0;

   const int available = Bars(_Symbol, PERIOD_M15); // perf-allowed: OnInit-only bounded replay sizing.
   if(available < strategy_vol_window + 2)
      return false;

   datetime anchor_time = 0;
   const bool restored = StrategyRestoreState(anchor_time);
   if(!restored)
   {
      g_cusum_pos = 0.0;
      g_cusum_neg = 0.0;
      anchor_time = StrategyLastConfirmedEntryTime();
   }

   int oldest_shift = 0;
   if(anchor_time > 0)
   {
      const int anchor_shift = iBarShift(_Symbol, PERIOD_M15, anchor_time, false); // perf-allowed: OnInit-only recovery anchor.
      if(anchor_shift < 0)
         return false;
      oldest_shift = MathMax(0, anchor_shift - 1);
      if(oldest_shift > strategy_state_rebuild_bars)
         return false;
   }
   else
   {
      oldest_shift = MathMin(strategy_state_rebuild_bars,
                             available - strategy_vol_window - 1);
   }

   for(int shift = oldest_shift; shift >= 1; --shift)
      if(!StrategyApplyClosedBar(shift))
         return false;

   if(oldest_shift == 0)
   {
      double mean_return = 0.0;
      double std_dev = 0.0;
      if(!CalculateReturnStats(_Symbol, PERIOD_M15, strategy_vol_window,
                               1, mean_return, std_dev))
         return false;
      g_cached_atr1 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
      g_cached_h = strategy_threshold_h * std_dev;
      g_cached_valid = (g_cached_atr1 > 0.0 && g_cached_h > 0.0);
   }

   const datetime latest_bar = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: one OnInit persistence key read.
   return (g_cached_valid && latest_bar > 0 && StrategyPersistState(latest_bar));
}

bool AdvanceState_OnNewBar()
{
   g_cached_valid = false;
   if(!StrategyApplyClosedBar(1))
      return false;
   const datetime latest_bar = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: one new-bar persistence key read.
   return (latest_bar > 0 && StrategyPersistState(latest_bar));
}

bool IsRolloverBlackout()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int minute_of_day = dt.hour * 60 + dt.min;
   if(minute_of_day >= 1435 || minute_of_day <= 5)
      return true;
   return false;
}

bool StrategyDailyRealizedLossHalt()
{
   int closed_trades = 0;
   const double realized_pnl = QM_ChartUITodayPnL(0, closed_trades);
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   const double day_start_balance = balance_now - realized_pnl;
   if(balance_now <= 0.0 || day_start_balance <= 0.0)
      return true;
   return (realized_pnl <=
           -(day_start_balance * strategy_daily_loss_limit_pct / 100.0));
}

bool StrategyInitializeTotalDrawdownBaseline()
{
   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity_now <= 0.0 || !MathIsValidNumber(equity_now))
      return false;

   g_strategy_initial_equity = equity_now;
   if(QM_EquityStreamRestoreBaseline("total_drawdown",
                                     "TOTAL_DD_KEY",
                                     "TOTAL_DD_EQUITY",
                                     qm_ea_id,
                                     g_strategy_initial_equity))
      return true;

   return QM_EquityStreamPersistBaseline("total_drawdown",
                                         "TOTAL_DD_KEY",
                                         "TOTAL_DD_EQUITY",
                                         qm_ea_id,
                                         g_strategy_initial_equity);
}

bool StrategyTotalDrawdownHalt()
{
   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_strategy_initial_equity <= 0.0 || equity_now <= 0.0)
      return true;
   const double drawdown_pct = MathMax(0.0,
      (g_strategy_initial_equity - equity_now) /
      g_strategy_initial_equity * 100.0);
   return (drawdown_pct >= strategy_total_drawdown_stop_pct);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(IsRolloverBlackout())
      return true;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) >= 1)
      return true;

   if(StrategyDailyRealizedLossHalt() || StrategyTotalDrawdownHalt())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid || g_cached_atr1 <= 0.0)
      return true;
   return ((ask - bid) > (strategy_spread_atr_mult * g_cached_atr1));
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   // Relative slot 0 resolves through the framework host magic, which was
   // registry-checked for qm_magic_slot_offset and _Symbol during OnInit.
   req.symbol_slot        = 0;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_cached_valid || g_cached_atr1 <= 0.0 || g_cached_h <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   double sl_dist = strategy_sl_atr_mult * g_cached_atr1;
   if(sl_dist <= 0.0)
      return false;

   // Long: S_pos >= h
   if(g_cusum_pos >= g_cached_h)
   {
      req.type   = QM_BUY;
      req.reason = "QM5_37006_CUSUM_BUY";
      req.sl     = ask - sl_dist;
      req.tp     = ask + (sl_dist * strategy_tp_rr);
       return true;
   }
   // Short: S_neg <= -h
   else if(g_cusum_neg <= -g_cached_h)
   {
      req.type   = QM_SELL;
      req.reason = "QM5_37006_CUSUM_SELL";
      req.sl     = bid + sl_dist;
      req.tp     = bid - (sl_dist * strategy_tp_rr);
       return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   return StrategyTotalDrawdownHalt();
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

   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     StrategyDeviationPoints(),
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_drawdown_hard_stop_pct,
                         strategy_total_drawdown_stop_pct,
                         strategy_per_trade_risk_cap_pct))
      return INIT_FAILED;

   // The percentage cap is a live-mode rail. Fixed-dollar gate runs retain
   // the mandated RISK_FIXED=1000 contract.
   if(RISK_PERCENT > 0.0 &&
      !QM_FrameworkSetRiskCapPct(strategy_per_trade_risk_cap_pct))
      return INIT_FAILED;

   if(!StrategyInitializeTotalDrawdownBaseline() || !StrategyRebuildState())
      return INIT_FAILED;

   // Seed the framework new-bar tracker after replay so the first tick cannot
   // apply closed bar [1] a second time.
   QM_IsNewBar(_Symbol, PERIOD_M15);

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
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   const bool strategy_new_bar = QM_IsNewBar(_Symbol, PERIOD_M15);
   if(strategy_new_bar)
   {
      if(!AdvanceState_OnNewBar())
         return;
      QM_EquityStreamOnNewBar();
   }

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

   if(!strategy_new_bar)
      return;

   // Strategy and central filters gate entries only. Protective management
   // and hard-stop exits above remain reachable during blackout conditions.
   if(Strategy_NewsFilterHook(broker_now) || Strategy_NoTradeFilter())
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
      {
         // The card resets CUSUM only after a confirmed framework entry.
         // A broker/risk/news rejection leaves the signal state untouched.
         g_cusum_pos = 0.0;
         g_cusum_neg = 0.0;
         const datetime latest_bar = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: successful-entry persistence only.
         if(latest_bar > 0 && !StrategyPersistState(latest_bar))
            QM_LogEvent(QM_ERROR, "CUSUM_STATE_PERSIST_FAILED", "{}");
      }
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
