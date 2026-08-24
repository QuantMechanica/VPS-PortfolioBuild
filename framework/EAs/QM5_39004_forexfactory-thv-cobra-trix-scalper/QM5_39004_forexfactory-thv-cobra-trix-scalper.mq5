#property strict
#property version   "5.0"
#property description "QM5_39004 forexfactory-thv-cobra-trix-scalper — THV Cobra Trix Scalper (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_39004 forexfactory-thv-cobra-trix-scalper
// -----------------------------------------------------------------------------
// Source: Cobraforex & TAH (2009-2024). THV System V3/V4. Forex Factory (>8M Views).
// Card: artifacts/cards_approved/QM5_39004_forexfactory-thv-cobra-trix-scalper.md (g0_status APPROVED).
//
// Mechanics (closed-bar, M5):
//   - Coral: SMMA(20) on M5.
//   - Fast Trix: TRIX(9) triple-EMA on M5 close.
//   - Slow Trix: TRIX(18) triple-EMA on M5 close.
//   - Long: Close[1] > Coral[1] AND FastTrix[1] > SlowTrix[1] AND FastTrix[1] > 0
//   - Short: Close[1] < Coral[1] AND FastTrix[1] < SlowTrix[1] AND FastTrix[1] < 0
//   - SL: Placed beyond Coral band +/- 2 pips.
//   - TP: 1:2.0 R:R target.
//   - Exit: Fast Trix slope reversal.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 39004;
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
input int    InpCoralPeriod             = 20;     // THV Coral SMMA period
input int    InpFastTrix                = 9;      // Fast Trix period
input int    InpSlowTrix                = 18;     // Slow Trix period
input int    strategy_atr_period        = 14;     // ATR period (M5)
input double strategy_sl_buffer_pips    = 2.0;    // SL buffer beyond Coral in pips
input double strategy_tp_rr             = 2.0;    // Take profit R:R multiple
input int    strategy_rollover_start_hhmm = 2355;
input int    strategy_rollover_end_hhmm   = 5;
input double strategy_spread_filter_mult  = 1.8;
input int    strategy_max_slippage_ticks  = 3;
input double strategy_daily_loss_halt_pct = 2.0;
input double strategy_daily_hard_stop_pct = 2.5;
input double strategy_total_dd_halt_pct   = 5.0;
input double strategy_per_trade_risk_cap_pct = 0.5;

// -----------------------------------------------------------------------------
// File-scope cached state (updated once per new closed bar)
// -----------------------------------------------------------------------------
double g_cached_fast_trix_1 = 0.0;
double g_cached_fast_trix_2 = 0.0;
double g_cached_slow_trix_1 = 0.0;
double g_cached_coral_1     = 0.0;
double g_cached_atr_1       = 0.0;
bool   g_state_ready        = false;

int StrategyHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
}

bool StrategyInRolloverWindow(const datetime t)
{
   const int hhmm = StrategyHhmm(t);
   if(strategy_rollover_start_hhmm > strategy_rollover_end_hhmm)
      return (hhmm >= strategy_rollover_start_hhmm || hhmm < strategy_rollover_end_hhmm);
   return (hhmm >= strategy_rollover_start_hhmm && hhmm < strategy_rollover_end_hhmm);
}

bool StrategyConfigValid()
{
   if(InpCoralPeriod < 14 || InpCoralPeriod > 30 ||
      InpFastTrix < 5 || InpFastTrix > 12 ||
      InpSlowTrix < 12 || InpSlowTrix > 24 || InpFastTrix >= InpSlowTrix ||
      strategy_atr_period != 14 || strategy_spread_filter_mult != 1.8)
      return false;
   if(strategy_sl_buffer_pips != 2.0 || strategy_tp_rr != 2.0 ||
      strategy_max_slippage_ticks <= 0 || strategy_max_slippage_ticks > 3)
      return false;
   if(strategy_rollover_start_hhmm != 2355 || strategy_rollover_end_hhmm != 5)
      return false;
   if(strategy_daily_loss_halt_pct <= 0.0 || strategy_daily_hard_stop_pct <= 0.0 ||
      strategy_daily_loss_halt_pct > strategy_daily_hard_stop_pct ||
      strategy_daily_loss_halt_pct > 2.0 || strategy_daily_hard_stop_pct > 2.5 ||
      strategy_total_dd_halt_pct <= 0.0 || strategy_total_dd_halt_pct > 5.0)
      return false;
   return (strategy_per_trade_risk_cap_pct > 0.0 &&
           strategy_per_trade_risk_cap_pct <= 0.5);
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

// -----------------------------------------------------------------------------
// TRIX calculation helper
// -----------------------------------------------------------------------------
bool CalculateTrix(const int period, const int shift, double &trix_val)
{
   trix_val = 0.0;
   if(period <= 1) return false;
   const int warmup = period * 8 + 10;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M5, shift, warmup, rates); // perf-allowed: exact TRIX triple-EMA close window
   const int available = ArraySize(rates);
   if(copied < period * 3 + 2 || available < copied) return false;

   const double alpha = 2.0 / ((double)period + 1.0);
   const double one_minus_alpha = 1.0 - alpha;
   const int oldest = copied;
   const double seed_close = rates[oldest - 1].close;
   if(seed_close <= 0.0) return false;

   double ema1 = seed_close;
   double ema2 = seed_close;
   double ema3 = seed_close;
   double prev_ema3 = 0.0;

   for(int s = oldest - 1; s >= 0; --s)
   {
      const double cl = rates[s].close;
      if(cl <= 0.0) return false;
      ema1 = alpha * cl + one_minus_alpha * ema1;
      ema2 = alpha * ema1 + one_minus_alpha * ema2;
      ema3 = alpha * ema2 + one_minus_alpha * ema3;

      if(s == 0)
      {
         if(prev_ema3 <= 0.0) return false;
         trix_val = (ema3 - prev_ema3) / prev_ema3;
         return true;
      }
      prev_ema3 = ema3;
   }
   return false;
}

void AdvanceState_OnNewBar()
{
   g_state_ready = false;
   g_cached_fast_trix_1 = 0.0;
   g_cached_fast_trix_2 = 0.0;
   g_cached_slow_trix_1 = 0.0;
   g_cached_coral_1 = 0.0;
   g_cached_atr_1 = 0.0;

   if(!CalculateTrix(InpFastTrix, 1, g_cached_fast_trix_1) ||
      !CalculateTrix(InpFastTrix, 2, g_cached_fast_trix_2) ||
      !CalculateTrix(InpSlowTrix, 1, g_cached_slow_trix_1))
      return;
   g_cached_coral_1 = QM_SMMA(_Symbol, PERIOD_M5, InpCoralPeriod, 1);
   g_cached_atr_1   = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   g_state_ready = (g_cached_coral_1 > 0.0 && g_cached_atr_1 > 0.0);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool StrategyDailyRealizedLossHalt()
{
   int closed_trades = 0;
   const double realized_pnl = QM_ChartUITodayPnL(0, closed_trades);
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   const double day_start_balance = balance_now - realized_pnl;
   if(balance_now <= 0.0 || day_start_balance <= 0.0)
      return true;
   return (realized_pnl <= -(day_start_balance * strategy_daily_loss_halt_pct / 100.0));
}

bool Strategy_NoTradeFilter()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) >= 1)
      return true;

   if(StrategyInRolloverWindow(QM_BrokerToUTC(TimeCurrent())))
      return true;

   if(StrategyDailyRealizedLossHalt())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || !g_state_ready || g_cached_atr_1 <= 0.0)
      return true;

   if(ask > bid && ask - bid > g_cached_atr_1 * strategy_spread_filter_mult)
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(!g_state_ready || g_cached_atr_1 <= 0.0 || g_cached_coral_1 <= 0.0)
      return false;

   const double c1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: single closed bar
   if(c1 <= 0.0) return false;

   const double buf = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_sl_buffer_pips));
   if(buf <= 0.0)
      return false;

   // Long Entry
   if(c1 > g_cached_coral_1 && g_cached_fast_trix_1 > g_cached_slow_trix_1 && g_cached_fast_trix_1 > 0.0)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_cached_coral_1 - buf);
      if(sl <= 0.0 || sl >= ask) return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_tp_rr);
      if(tp <= 0.0) return false;

      req.type               = QM_BUY;
      req.price              = 0.0;
      req.sl                 = sl;
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason             = "THV_COBRA_TRIX_LONG";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   // Short Entry
   if(c1 < g_cached_coral_1 && g_cached_fast_trix_1 < g_cached_slow_trix_1 && g_cached_fast_trix_1 < 0.0)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_cached_coral_1 + buf);
      if(sl <= 0.0 || sl <= bid) return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_tp_rr);
      if(tp <= 0.0) return false;

      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = sl;
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason             = "THV_COBRA_TRIX_SHORT";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   if(!g_state_ready)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY)
         return (g_cached_fast_trix_1 < g_cached_fast_trix_2);
      if(pos_type == POSITION_TYPE_SELL)
         return (g_cached_fast_trix_1 > g_cached_fast_trix_2);
   }
   return false;
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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_M5,
                                            QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                            "V5_WEEKEND_RISK_POLICY"))
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
                         strategy_daily_hard_stop_pct,
                         strategy_total_dd_halt_pct,
                         strategy_per_trade_risk_cap_pct))
      return INIT_FAILED;

   AdvanceState_OnNewBar();

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_39004_forexfactory-thv-cobra-trix-scalper\"}");
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

   const bool strategy_new_bar = QM_IsNewBar(_Symbol, PERIOD_M5);
   if(strategy_new_bar)
   {
      AdvanceState_OnNewBar();
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
      return;
   }

   if(!strategy_new_bar)
      return;

   if(Strategy_NewsFilterHook(broker_now))
      return;

   if(Strategy_NoTradeFilter())
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
