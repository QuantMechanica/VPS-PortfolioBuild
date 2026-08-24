#property strict
#property version   "5.0"
#property description "QM5_38004 CodeTrading Triple EMA Momentum Scalper"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_38004
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 38004;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf           = PERIOD_M5;
input int             strategy_fast_ema_period     = 8;
input int             strategy_med_ema_period      = 21;
input int             strategy_slow_ema_period     = 55;
input int             strategy_atr_period          = 14;
input int             strategy_sl_buffer_pips      = 2;
input double          strategy_tp_rr               = 2.0;
input bool            strategy_trail_enabled       = true;
input double          strategy_trail_trigger_r     = 1.0;
input int             strategy_rollover_start_hhmm = 2355;
input int             strategy_rollover_end_hhmm   = 5;
input double          strategy_spread_filter_mult  = 1.8;
input int             strategy_max_slippage_ticks  = 3;
input double          strategy_daily_loss_limit_pct = 2.0;
input double          strategy_daily_drawdown_hard_stop_pct = 2.5;
input double          strategy_total_drawdown_stop_pct = 5.0;
input double          strategy_per_trade_risk_cap_pct = 0.5;

// -----------------------------------------------------------------------------
// Closed-bar state. The cache is seeded in OnInit and refreshed before any
// entry admission on each new M5 bar, so restart management and spread checks
// never depend on a stale or zero ATR/EMA value.
// -----------------------------------------------------------------------------
double g_strategy_cached_fast_ema = 0.0;
double g_strategy_cached_med_ema  = 0.0;
double g_strategy_cached_slow_ema = 0.0;
double g_strategy_cached_atr      = 0.0;
double g_strategy_cached_open1    = 0.0;
double g_strategy_cached_high1    = 0.0;
double g_strategy_cached_low1     = 0.0;
double g_strategy_cached_close1   = 0.0;
double g_strategy_initial_equity  = 0.0;
bool   g_strategy_state_ready     = false;

bool StrategyConfigValid()
{
   if(strategy_signal_tf != PERIOD_M5 ||
      strategy_fast_ema_period < 5 || strategy_fast_ema_period > 12 ||
      strategy_med_ema_period < 15 || strategy_med_ema_period > 30 ||
      strategy_slow_ema_period < 40 || strategy_slow_ema_period > 80 ||
      strategy_fast_ema_period >= strategy_med_ema_period ||
      strategy_med_ema_period >= strategy_slow_ema_period ||
      strategy_atr_period != 14)
      return false;

   if(strategy_sl_buffer_pips != 2 || MathAbs(strategy_tp_rr - 2.0) > 1e-9 ||
      !strategy_trail_enabled || MathAbs(strategy_trail_trigger_r - 1.0) > 1e-9 ||
      MathAbs(strategy_spread_filter_mult - 1.8) > 1e-9 ||
      strategy_max_slippage_ticks <= 0 || strategy_max_slippage_ticks > 3)
      return false;

   if(strategy_rollover_start_hhmm < 0 || strategy_rollover_start_hhmm > 2359 ||
      strategy_rollover_end_hhmm < 0 || strategy_rollover_end_hhmm > 2359 ||
      (strategy_rollover_start_hhmm % 100) > 59 ||
      (strategy_rollover_end_hhmm % 100) > 59)
      return false;

   if(strategy_daily_loss_limit_pct <= 0.0 ||
      strategy_daily_loss_limit_pct > 2.0 ||
      strategy_daily_drawdown_hard_stop_pct <= 0.0 ||
      strategy_daily_drawdown_hard_stop_pct > 2.5 ||
      strategy_daily_loss_limit_pct > strategy_daily_drawdown_hard_stop_pct ||
      strategy_total_drawdown_stop_pct <= 0.0 ||
      strategy_total_drawdown_stop_pct > 5.0)
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

void AdvanceState_OnNewBar()
{
   g_strategy_state_ready = false;
   g_strategy_cached_fast_ema = 0.0;
   g_strategy_cached_med_ema = 0.0;
   g_strategy_cached_slow_ema = 0.0;
   g_strategy_cached_atr = 0.0;
   g_strategy_cached_open1 = 0.0;
   g_strategy_cached_high1 = 0.0;
   g_strategy_cached_low1 = 0.0;
   g_strategy_cached_close1 = 0.0;

   const double ema_fast = QM_EMA(_Symbol, strategy_signal_tf,
                                  strategy_fast_ema_period, 1, PRICE_CLOSE);
   const double ema_med = QM_EMA(_Symbol, strategy_signal_tf,
                                 strategy_med_ema_period, 1, PRICE_CLOSE);
   const double ema_slow = QM_EMA(_Symbol, strategy_signal_tf,
                                  strategy_slow_ema_period, 1, PRICE_CLOSE);
   const double atr_last = QM_ATR(_Symbol, strategy_signal_tf,
                                  strategy_atr_period, 1);
   const double open1 = iOpen(_Symbol, strategy_signal_tf, 1);    // perf-allowed: one closed-bar read per new-bar refresh.
   const double high1 = iHigh(_Symbol, strategy_signal_tf, 1);    // perf-allowed: one closed-bar read per new-bar refresh.
   const double low1 = iLow(_Symbol, strategy_signal_tf, 1);      // perf-allowed: one closed-bar read per new-bar refresh.
   const double close1 = iClose(_Symbol, strategy_signal_tf, 1);  // perf-allowed: one closed-bar read per new-bar refresh.

   if(ema_fast <= 0.0 || ema_med <= 0.0 || ema_slow <= 0.0 ||
      atr_last <= 0.0 || open1 <= 0.0 || high1 <= 0.0 ||
      low1 <= 0.0 || close1 <= 0.0)
      return;

   g_strategy_cached_fast_ema = ema_fast;
   g_strategy_cached_med_ema = ema_med;
   g_strategy_cached_slow_ema = ema_slow;
   g_strategy_cached_atr = atr_last;
   g_strategy_cached_open1 = open1;
   g_strategy_cached_high1 = high1;
   g_strategy_cached_low1 = low1;
   g_strategy_cached_close1 = close1;
   g_strategy_state_ready = true;
}

bool StrategyInRolloverWindow(const datetime utc_time)
{
   MqlDateTime utc_dt;
   TimeToStruct(utc_time, utc_dt);
   const int utc_hhmm = utc_dt.hour * 100 + utc_dt.min;
   if(strategy_rollover_start_hhmm > strategy_rollover_end_hhmm)
      return (utc_hhmm >= strategy_rollover_start_hhmm ||
              utc_hhmm < strategy_rollover_end_hhmm);
   return (utc_hhmm >= strategy_rollover_start_hhmm &&
           utc_hhmm < strategy_rollover_end_hhmm);
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
   if(!g_strategy_state_ready)
      return true;

   if(StrategyInRolloverWindow(QM_BrokerToUTC(TimeCurrent())))
      return true;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) >= 1)
      return true;

   if(StrategyDailyRealizedLossHalt() || StrategyTotalDrawdownHalt())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid || g_strategy_cached_atr <= 0.0)
      return true;

   return ((ask - bid) >
           g_strategy_cached_atr * strategy_spread_filter_mult);
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = 0;
   req.expiration_seconds = 0;

   if(!g_strategy_state_ready)
      return false;

   int signal = 0;
   if(g_strategy_cached_fast_ema > g_strategy_cached_med_ema &&
      g_strategy_cached_med_ema > g_strategy_cached_slow_ema &&
      g_strategy_cached_low1 <= g_strategy_cached_fast_ema &&
      g_strategy_cached_close1 > g_strategy_cached_med_ema &&
      g_strategy_cached_close1 > g_strategy_cached_open1)
      signal = 1;
   else if(g_strategy_cached_fast_ema < g_strategy_cached_med_ema &&
           g_strategy_cached_med_ema < g_strategy_cached_slow_ema &&
           g_strategy_cached_high1 >= g_strategy_cached_fast_ema &&
           g_strategy_cached_close1 < g_strategy_cached_med_ema &&
           g_strategy_cached_close1 < g_strategy_cached_open1)
      signal = -1;

   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                         strategy_sl_buffer_pips);
   if(buffer <= 0.0)
      return false;

   const double raw_sl = (side == QM_BUY)
                         ? (g_strategy_cached_slow_ema - buffer)
                         : (g_strategy_cached_slow_ema + buffer);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
   if(sl <= 0.0 || (side == QM_BUY && sl >= entry) ||
      (side == QM_SELL && sl <= entry))
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "TRIPLE_EMA_MOM_LONG" : "TRIPLE_EMA_MOM_SHORT";

   return (req.sl > 0.0 && req.tp > 0.0);
}

void Strategy_ManageOpenPosition()
{
   if(!strategy_trail_enabled || g_strategy_cached_med_ema <= 0.0 ||
      strategy_tp_rr <= 0.0 || strategy_trail_trigger_r <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

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
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      const double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price <= 0.0 || current_tp <= 0.0 || point <= 0.0)
         continue;

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double initial_r = (current_tp - open_price) / strategy_tp_rr;
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(initial_r > 0.0 && bid > 0.0 &&
            bid - open_price >= initial_r * strategy_trail_trigger_r)
         {
            const double new_sl = QM_StopRulesNormalizePrice(_Symbol,
                                                              g_strategy_cached_med_ema);
            if(new_sl > 0.0 && new_sl < bid && new_sl > current_sl + point)
               QM_TM_MoveSL(ticket, new_sl, "TRAIL_EMA21");
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double initial_r = (open_price - current_tp) / strategy_tp_rr;
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(initial_r > 0.0 && ask > 0.0 &&
            open_price - ask >= initial_r * strategy_trail_trigger_r)
         {
            const double new_sl = QM_StopRulesNormalizePrice(_Symbol,
                                                              g_strategy_cached_med_ema);
            if(new_sl > ask && (current_sl == 0.0 || new_sl < current_sl - point))
               QM_TM_MoveSL(ticket, new_sl, "TRAIL_EMA21");
         }
      }
   }
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

   // The percentage cap is a live-mode rail. Fixed-dollar gate runs retain the
   // mandated RISK_FIXED=1000 contract and are not silently converted to % risk.
   if(RISK_PERCENT > 0.0 &&
      !QM_FrameworkSetRiskCapPct(strategy_per_trade_risk_cap_pct))
      return INIT_FAILED;

   if(!StrategyInitializeTotalDrawdownBaseline())
      return INIT_FAILED;

   AdvanceState_OnNewBar();

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

   const bool strategy_new_bar = QM_IsNewBar(_Symbol, strategy_signal_tf);
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
   }

   if(!strategy_new_bar)
      return;

   // Custom, strategy, and central news filters gate only the entry path.
   // Protective management and hard-stop exits above remain reachable.
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
