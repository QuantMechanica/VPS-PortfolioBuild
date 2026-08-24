#property strict
#property version   "5.0"
#property description "QM5_39002 Sonic R System (Dragon Tunnel & 89 EMA Trend Wave)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_39002
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 39002;
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
input ENUM_TIMEFRAMES strategy_signal_tf           = PERIOD_M15;
input int             strategy_dragon_period       = 34;
input int             strategy_trendwave_period    = 89;
input int             strategy_atr_period          = 14;
input double          strategy_sl_buffer_pips      = 3.0;
input double          strategy_tp_rr_mult          = 2.5;
input bool            strategy_be_enabled          = true;
input double          strategy_be_trigger_r        = 1.0;
input int             strategy_rollover_start_hhmm = 2355;
input int             strategy_rollover_end_hhmm   = 5;
input double          strategy_spread_filter_mult  = 1.8;
input int             strategy_max_slippage_ticks  = 3;
input double          strategy_daily_loss_halt_pct = 2.0;
input double          strategy_daily_hard_stop_pct = 2.5;
input double          strategy_total_dd_halt_pct   = 5.0;
input double          strategy_per_trade_risk_cap_pct = 0.5;

// -----------------------------------------------------------------------------
// State Cache & Indicators
// -----------------------------------------------------------------------------
double g_dragon_high = 0.0;
double g_dragon_low  = 0.0;
double g_trend_wave  = 0.0;
double g_last_atr    = 0.0;
int    g_last_signal = 0;

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
      strategy_dragon_period < 21 || strategy_dragon_period > 50 ||
      strategy_trendwave_period < 55 || strategy_trendwave_period > 144 ||
      strategy_atr_period != 14 || strategy_spread_filter_mult != 1.8)
      return false;
   if(strategy_sl_buffer_pips != 3.0 || strategy_tp_rr_mult != 2.5 ||
      !strategy_be_enabled || strategy_be_trigger_r != 1.0 ||
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

void AdvanceState_OnNewBar()
{
   const double close1 = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: one closed M15 signal close, cached once per new bar (and once at init).
   const double low1   = iLow(_Symbol, strategy_signal_tf, 1);   // perf-allowed: one closed M15 signal low, cached once per new bar (and once at init).
   const double high1  = iHigh(_Symbol, strategy_signal_tf, 1);  // perf-allowed: one closed M15 signal high, cached once per new bar (and once at init).
   if(close1 <= 0.0 || low1 <= 0.0 || high1 <= 0.0)
      return;

   g_dragon_high = QM_EMA(_Symbol, strategy_signal_tf, strategy_dragon_period, 1, PRICE_HIGH);
   g_dragon_low  = QM_EMA(_Symbol, strategy_signal_tf, strategy_dragon_period, 1, PRICE_LOW);
   g_trend_wave  = QM_EMA(_Symbol, strategy_signal_tf, strategy_trendwave_period, 1, PRICE_CLOSE);
   g_last_atr    = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period), 1);

   g_last_signal = 0;

   if(g_dragon_high > 0.0 && g_dragon_low > 0.0 && g_trend_wave > 0.0 && g_last_atr > 0.0)
   {
      // Long: Close[1] > TrendWave[1] AND Low[1] <= Dragon_High[1] AND Close[1] > Dragon_High[1]
      if(close1 > g_trend_wave && low1 <= g_dragon_high && close1 > g_dragon_high)
         g_last_signal = 1;
      // Short: Close[1] < TrendWave[1] AND High[1] >= Dragon_Low[1] AND Close[1] < Dragon_Low[1]
      else if(close1 < g_trend_wave && high1 >= g_dragon_low && close1 < g_dragon_low)
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
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(g_last_signal == 0 || g_last_atr <= 0.0)
      return false;

   const QM_OrderType side = (g_last_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double pip_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_sl_buffer_pips));
   if(pip_dist <= 0.0)
      return false;
   const double buffer = pip_dist;

   double sl = 0.0;
   double tp = 0.0;

   if(side == QM_BUY)
   {
      sl = QM_StopRulesNormalizePrice(_Symbol, g_dragon_low - buffer);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double sl_dist = entry - sl;
      tp = QM_StopRulesNormalizePrice(_Symbol, entry + sl_dist * strategy_tp_rr_mult);
   }
   else
   {
      sl = QM_StopRulesNormalizePrice(_Symbol, g_dragon_high + buffer);
      if(sl <= entry)
         return false;
      const double sl_dist = sl - entry;
      tp = QM_StopRulesNormalizePrice(_Symbol, entry - sl_dist * strategy_tp_rr_mult);
   }

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "SONIC_R_LONG" : "SONIC_R_SHORT";

   return (req.sl > 0.0 && req.tp > 0.0);
}

void Strategy_ManageOpenPosition()
{
   if(!strategy_be_enabled)
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
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(current_sl < open_price)
         {
            const double initial_risk = open_price - current_sl;
            if(initial_risk > 0.0 &&
               bid - open_price >= initial_risk * strategy_be_trigger_r)
               QM_TM_MoveSL(ticket,
                            QM_StopRulesNormalizePrice(_Symbol, open_price),
                            "BE_AT_ORIGINAL_1R");
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(current_sl > open_price)
         {
            const double initial_risk = current_sl - open_price;
            if(initial_risk > 0.0 &&
               open_price - ask >= initial_risk * strategy_be_trigger_r)
               QM_TM_MoveSL(ticket,
                            QM_StopRulesNormalizePrice(_Symbol, open_price),
                            "BE_AT_ORIGINAL_1R");
         }
      }
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

   if(!QM_KillSwitchInit(qm_ea_id,
                         QM_FrameworkMagic(),
                         strategy_daily_hard_stop_pct,
                         strategy_total_dd_halt_pct,
                         strategy_per_trade_risk_cap_pct))
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
