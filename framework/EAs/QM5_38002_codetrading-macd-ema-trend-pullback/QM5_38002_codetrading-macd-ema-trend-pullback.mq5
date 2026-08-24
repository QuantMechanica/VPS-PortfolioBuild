#property strict
#property version   "5.0"
#property description "QM5_38002 CodeTrading MACD EMA Trend Pullback"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_38002
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 38002;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_M15;
input int             strategy_trend_ema_period   = 200;
input int             strategy_pullback_ema_period = 50;
input int             strategy_fast_macd_period   = 12;
input int             strategy_slow_macd_period   = 26;
input int             strategy_signal_macd_period = 9;
input int             strategy_atr_period         = 14;
input int             strategy_swing_lookback     = 5;
input double          strategy_sl_buffer_pips     = 2.0;
input double          strategy_tp_rr_mult         = 2.0;
input bool            strategy_trailing_enabled   = true;
input double          strategy_trail_atr_mult     = 2.0;
input int             strategy_rollover_start_hhmm = 2355;
input int             strategy_rollover_end_hhmm   = 5;
input double          strategy_spread_filter_mult  = 1.8;
input int             strategy_max_slippage_ticks = 3;
input double          strategy_daily_loss_halt_pct = 2.0;
input double          strategy_daily_hard_stop_pct = 2.5;
input double          strategy_total_drawdown_stop_pct = 5.0;
input double          strategy_per_trade_risk_cap_pct = 0.5;

// -----------------------------------------------------------------------------
// State Cache & Indicators
// -----------------------------------------------------------------------------
double g_trend_ema    = 0.0;
double g_pullback_ema = 0.0;
double g_last_atr     = 0.0;
double g_swing_low    = 0.0;
double g_swing_high   = 0.0;
int    g_last_signal  = 0;

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
   if(strategy_signal_tf != PERIOD_M15 ||
      strategy_trend_ema_period < 1 || strategy_pullback_ema_period < 1 ||
      strategy_fast_macd_period < 1 || strategy_slow_macd_period < 2 ||
      strategy_signal_macd_period < 1 || strategy_atr_period < 1)
      return false;
   if(strategy_fast_macd_period >= strategy_slow_macd_period ||
      strategy_swing_lookback != 5 || strategy_sl_buffer_pips != 2.0 ||
      strategy_tp_rr_mult != 2.0 || !strategy_trailing_enabled ||
      strategy_trail_atr_mult != 2.0 || strategy_spread_filter_mult != 1.8)
      return false;
   if(strategy_rollover_start_hhmm < 0 || strategy_rollover_start_hhmm > 2359 ||
      strategy_rollover_end_hhmm < 0 || strategy_rollover_end_hhmm > 2359 ||
      (strategy_rollover_start_hhmm % 100) > 59 ||
      (strategy_rollover_end_hhmm % 100) > 59)
      return false;
   if(strategy_max_slippage_ticks <= 0 || strategy_max_slippage_ticks > 3 ||
      strategy_daily_loss_halt_pct <= 0.0 || strategy_daily_loss_halt_pct > 2.0 ||
      strategy_daily_hard_stop_pct <= 0.0 || strategy_daily_hard_stop_pct > 2.5 ||
      strategy_daily_loss_halt_pct > strategy_daily_hard_stop_pct ||
      strategy_total_drawdown_stop_pct <= 0.0 || strategy_total_drawdown_stop_pct > 5.0)
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
   // Clear first so a failed closed-bar read cannot leave a stale setup armed.
   g_trend_ema = 0.0;
   g_pullback_ema = 0.0;
   g_last_atr = 0.0;
   g_swing_low = 0.0;
   g_swing_high = 0.0;
   g_last_signal = 0;

   MqlRates swing_rates[];
   ArraySetAsSeries(swing_rates, true);
   const int copied = CopyRates(_Symbol,
                                strategy_signal_tf,
                                1,
                                strategy_swing_lookback,
                                swing_rates); // perf-allowed: bounded closed-bar refresh behind QM_IsNewBar()/OnInit
   if(copied != strategy_swing_lookback ||
      ArraySize(swing_rates) < strategy_swing_lookback)
      return;

   double swing_low = swing_rates[0].low;
   double swing_high = swing_rates[0].high;
   if(swing_low <= 0.0 || swing_high <= 0.0)
      return;
   for(int i = 1; i < strategy_swing_lookback && i < ArraySize(swing_rates); ++i)
   {
      if(swing_rates[i].low <= 0.0 || swing_rates[i].high <= 0.0)
         return;
      swing_low = MathMin(swing_low, swing_rates[i].low);
      swing_high = MathMax(swing_high, swing_rates[i].high);
   }

   g_trend_ema    = QM_EMA(_Symbol, strategy_signal_tf, strategy_trend_ema_period, 1, PRICE_CLOSE);
   g_pullback_ema = QM_EMA(_Symbol, strategy_signal_tf, strategy_pullback_ema_period, 1, PRICE_CLOSE);
   g_last_atr     = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period), 1);

   const double macd_main_1 = QM_MACD_Main(_Symbol, strategy_signal_tf, strategy_fast_macd_period, strategy_slow_macd_period, strategy_signal_macd_period, 1, PRICE_CLOSE);
   const double macd_sig_1  = QM_MACD_Signal(_Symbol, strategy_signal_tf, strategy_fast_macd_period, strategy_slow_macd_period, strategy_signal_macd_period, 1, PRICE_CLOSE);
   const double macd_main_2 = QM_MACD_Main(_Symbol, strategy_signal_tf, strategy_fast_macd_period, strategy_slow_macd_period, strategy_signal_macd_period, 2, PRICE_CLOSE);
   const double macd_sig_2  = QM_MACD_Signal(_Symbol, strategy_signal_tf, strategy_fast_macd_period, strategy_slow_macd_period, strategy_signal_macd_period, 2, PRICE_CLOSE);

   const double macd_hist_1 = macd_main_1 - macd_sig_1;
   const double macd_hist_2 = macd_main_2 - macd_sig_2;

   const double close_1 = swing_rates[0].close;
   const double low_1   = swing_rates[0].low;
   const double high_1  = swing_rates[0].high;

   if(g_trend_ema > 0.0 && g_pullback_ema > 0.0 && g_last_atr > 0.0 &&
      close_1 > 0.0 && low_1 > 0.0 && high_1 > 0.0)
   {
      g_swing_low = swing_low;
      g_swing_high = swing_high;
      // Long: Close[1] > EMA(200)[1] && Low[1] <= EMA(50)[1] && MACD_Hist[1] > 0 && MACD_Hist[2] <= 0
      if(close_1 > g_trend_ema && low_1 <= g_pullback_ema && macd_hist_1 > 0.0 && macd_hist_2 <= 0.0)
         g_last_signal = 1;
      // Short: Close[1] < EMA(200)[1] && High[1] >= EMA(50)[1] && MACD_Hist[1] < 0 && MACD_Hist[2] >= 0
      else if(close_1 < g_trend_ema && high_1 >= g_pullback_ema && macd_hist_1 < 0.0 && macd_hist_2 >= 0.0)
         g_last_signal = -1;
   }
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
   if(StrategyInRolloverWindow(QM_BrokerToUTC(TimeCurrent())))
      return true;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) >= 1)
      return true;

   if(StrategyDailyRealizedLossHalt())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || g_last_atr <= 0.0)
      return true;

   if(ask > bid)
   {
      const double spread = ask - bid;
      if(spread > g_last_atr * strategy_spread_filter_mult)
         return true;
   }

   return false;
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

   // Re-evaluate entry-only controls immediately before deriving order prices.
   if(Strategy_NoTradeFilter())
      return false;

   if(g_last_signal == 0 || g_last_atr <= 0.0 ||
      g_swing_low <= 0.0 || g_swing_high <= 0.0)
      return false;

   const QM_OrderType side = (g_last_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl_buffer = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                            (int)strategy_sl_buffer_pips);
   if(sl_buffer <= 0.0)
      return false;

   const double raw_sl = (side == QM_BUY) ? (g_swing_low - sl_buffer)
                                          : (g_swing_high + sl_buffer);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
   const double sl_distance = (side == QM_BUY) ? (entry - sl) : (sl - entry);
   const double tp_distance = sl_distance * strategy_tp_rr_mult;
   if(sl_distance <= 0.0 || tp_distance <= 0.0)
      return false;

   req.type = side;
   req.sl = sl;
   req.tp = QM_StopRulesTakeFromDistance(_Symbol, side, entry, tp_distance);
   req.reason = (side == QM_BUY) ? "MACD_EMA_PULLBACK_LONG" : "MACD_EMA_PULLBACK_SHORT";

   return (req.sl > 0.0 && req.tp > 0.0);
}

void Strategy_ManageOpenPosition()
{
   if(!strategy_trailing_enabled || g_last_atr <= 0.0)
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

      QM_TM_TrailATR(ticket, MathMax(1, strategy_atr_period), strategy_trail_atr_mult);
   }
}

bool Strategy_ExitSignal()
{
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

   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     StrategyDeviationPoints(),
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());

   if(RISK_FIXED <= 0.0 &&
      !QM_FrameworkSetRiskCapPct(strategy_per_trade_risk_cap_pct))
      return INIT_FAILED;

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_hard_stop_pct,
                         strategy_total_drawdown_stop_pct,
                         strategy_per_trade_risk_cap_pct))
      return INIT_FAILED;

   // Seed ATR/swing state so a restarted open position is managed immediately.
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
