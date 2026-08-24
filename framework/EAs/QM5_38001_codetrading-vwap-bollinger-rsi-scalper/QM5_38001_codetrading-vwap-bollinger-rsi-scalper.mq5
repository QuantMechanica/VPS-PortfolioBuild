#property strict
#property version   "5.0"
#property description "QM5_38001 CodeTrading VWAP Bollinger RSI Scalper"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_38001
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 38001;
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
input ENUM_TIMEFRAMES strategy_signal_tf         = PERIOD_M5;
input int             strategy_bb_period         = 20;
input double          strategy_bb_dev            = 2.00;
input int             strategy_rsi_period        = 14;
input double          strategy_rsi_oversold      = 30.0;
input double          strategy_rsi_overbought    = 70.0;
input int             strategy_atr_period        = 14;
input double          strategy_atr_sl_mult       = 1.5;
input double          strategy_tp_rr_mult        = 1.8;
input bool            strategy_use_vwap_tp       = true;
input bool            strategy_be_enabled        = true;
input double          strategy_be_trigger_r      = 1.0;
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
int    g_vwap_day_key   = -1;
double g_vwap_pv        = 0.0;
double g_vwap_volume    = 0.0;
double g_session_vwap   = 0.0;
datetime g_vwap_last_bar_time = 0;
double g_bb_upper       = 0.0;
double g_bb_lower       = 0.0;
double g_bb_middle      = 0.0;
double g_rsi            = 50.0;
double g_last_atr       = 0.0;
int    g_last_signal    = 0;

int StrategyDateKey(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
}

int StrategyHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
}

bool StrategyConfigValid()
{
   if(strategy_signal_tf != PERIOD_M5 || strategy_bb_period < 2 ||
      strategy_bb_dev <= 0.0 || strategy_rsi_period < 2 ||
      strategy_atr_period < 2 || strategy_atr_sl_mult <= 0.0 ||
      strategy_tp_rr_mult <= 0.0 || strategy_spread_filter_mult <= 0.0)
      return false;
   if(strategy_rsi_oversold <= 0.0 || strategy_rsi_overbought >= 100.0 ||
      strategy_rsi_oversold >= strategy_rsi_overbought)
      return false;
   if(!strategy_be_enabled || strategy_be_trigger_r != 1.0 ||
      strategy_max_slippage_ticks <= 0)
      return false;
   if(strategy_rollover_start_hhmm < 0 || strategy_rollover_start_hhmm > 2359 ||
      strategy_rollover_end_hhmm < 0 || strategy_rollover_end_hhmm > 2359 ||
      (strategy_rollover_start_hhmm % 100) > 59 ||
      (strategy_rollover_end_hhmm % 100) > 59)
      return false;
   if(strategy_daily_loss_halt_pct <= 0.0 || strategy_daily_hard_stop_pct <= 0.0 ||
      strategy_daily_loss_halt_pct > strategy_daily_hard_stop_pct ||
      strategy_total_dd_halt_pct <= 0.0)
      return false;
   return (strategy_per_trade_risk_cap_pct > 0.0 &&
           strategy_per_trade_risk_cap_pct <= 1.0);
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

bool StrategyInRolloverWindow(const datetime t)
{
   const int hhmm = StrategyHhmm(t);
   if(strategy_rollover_start_hhmm > strategy_rollover_end_hhmm)
      return (hhmm >= strategy_rollover_start_hhmm || hhmm < strategy_rollover_end_hhmm);
   return (hhmm >= strategy_rollover_start_hhmm && hhmm < strategy_rollover_end_hhmm);
}

void StrategyResetVwap(const int day_key)
{
   g_vwap_day_key = day_key;
   g_vwap_pv = 0.0;
   g_vwap_volume = 0.0;
   g_session_vwap = 0.0;
   g_vwap_last_bar_time = 0;
}

bool StrategyAccumulateVwapBar(const MqlRates &bar)
{
   if(bar.high <= 0.0 || bar.low <= 0.0 || bar.close <= 0.0 ||
      bar.tick_volume <= 0)
      return false;

   const double typical = (bar.high + bar.low + bar.close) / 3.0;
   const double volume = (double)bar.tick_volume;
   g_vwap_pv += typical * volume;
   g_vwap_volume += volume;
   if(g_vwap_volume <= 0.0)
      return false;
   g_session_vwap = g_vwap_pv / g_vwap_volume;
   return (g_session_vwap > 0.0);
}

bool StrategyRebuildSessionVwap(const int target_day_key)
{
   const int session_rebuild_bars = 400; // M5 UTC day is at most 288 bars.
   MqlRates history[];
   ArraySetAsSeries(history, true);
   const int copied = CopyRates(_Symbol,
                                strategy_signal_tf,
                                1,
                                session_rebuild_bars,
                                history); // perf-allowed: new-bar/restart session rebuild
   const int history_size = ArraySize(history);
   if(copied < 1 || history_size < copied)
      return false;

   StrategyResetVwap(target_day_key);
   int same_day_bars = 0;
   for(int i = MathMin(copied, history_size) - 1; i >= 0; --i)
   {
      const int bar_day_key = StrategyDateKey(QM_BrokerToUTC(history[i].time));
      if(bar_day_key != target_day_key)
         continue;
      if(!StrategyAccumulateVwapBar(history[i]))
      {
         StrategyResetVwap(target_day_key);
         return false;
      }
      same_day_bars++;
   }

   if(same_day_bars <= 0 || g_session_vwap <= 0.0)
      return false;
   g_vwap_last_bar_time = history[0].time;
   return true;
}

void AdvanceState_OnNewBar()
{
   g_last_signal = 0;

   MqlRates latest[];
   ArraySetAsSeries(latest, true);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, 1, latest); // perf-allowed: new-bar state read
   if(copied < 1 || ArraySize(latest) < 1)
      return;

   const datetime bar_time = latest[0].time;
   const int day_key = StrategyDateKey(QM_BrokerToUTC(bar_time));
   const int bar_seconds = PeriodSeconds(strategy_signal_tf);
   const bool contiguous = (g_vwap_last_bar_time > 0 &&
                            bar_seconds > 0 &&
                            (bar_time - g_vwap_last_bar_time) == bar_seconds);

   if(day_key != g_vwap_day_key || !contiguous)
   {
      if(!StrategyRebuildSessionVwap(day_key))
         return;
   }
   else
   {
      if(!StrategyAccumulateVwapBar(latest[0]))
      {
         StrategyResetVwap(day_key);
         return;
      }
      g_vwap_last_bar_time = bar_time;
   }

   const double high  = latest[0].high;
   const double low   = latest[0].low;
   const double close = latest[0].close;
   const double open  = latest[0].open;

   g_bb_upper  = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   g_bb_lower  = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   g_bb_middle = QM_BB_Middle(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   g_rsi       = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 1, PRICE_CLOSE);
   g_last_atr  = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period), 1);

   if(g_session_vwap > 0.0 && g_bb_lower > 0.0 && g_bb_upper > 0.0 && g_rsi > 0.0)
   {
      // Long: Low[1] <= LowerBB[1] && Close[1] < VWAP[1] && RSI[1] <= 30.0 && Close[1] > Open[1]
      if(low <= g_bb_lower && close < g_session_vwap && g_rsi <= strategy_rsi_oversold && close > open)
         g_last_signal = 1;
      // Short: High[1] >= UpperBB[1] && Close[1] > VWAP[1] && RSI[1] >= strategy_rsi_overbought && Close[1] < Open[1]
      else if(high >= g_bb_upper && close > g_session_vwap && g_rsi >= strategy_rsi_overbought && close < open)
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

bool StrategyCurrentQuoteAndSpreadAllowed(double &ask, double &bid)
{
   ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || g_last_atr <= 0.0)
      return false;

   return ((ask - bid) <= g_last_atr * strategy_spread_filter_mult);
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

   double ask = 0.0;
   double bid = 0.0;
   if(!StrategyCurrentQuoteAndSpreadAllowed(ask, bid))
      return true;

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

   if(g_last_signal == 0 || g_last_atr <= 0.0)
      return false;

   // Recheck the spread at the execution boundary and use the same quote for
   // the request. Calendar/news evaluation may have elapsed since admission.
   double ask = 0.0;
   double bid = 0.0;
   if(!StrategyCurrentQuoteAndSpreadAllowed(ask, bid))
      return false;

   const QM_OrderType side = (g_last_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? ask : bid;
   if(entry <= 0.0)
      return false;

   const double sl_distance = g_last_atr * strategy_atr_sl_mult;
   if(sl_distance <= 0.0)
      return false;

   req.type = side;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, sl_distance);

   double tp = 0.0;
   if(strategy_use_vwap_tp && g_session_vwap > 0.0)
   {
      if(side == QM_BUY && g_session_vwap > entry)
         tp = QM_StopRulesNormalizePrice(_Symbol, g_session_vwap);
      else if(side == QM_SELL && g_session_vwap < entry)
         tp = QM_StopRulesNormalizePrice(_Symbol, g_session_vwap);
   }

   if(tp <= 0.0)
   {
      const double tp_distance = sl_distance * strategy_tp_rr_mult;
      tp = QM_StopRulesTakeFromDistance(_Symbol, side, entry, tp_distance);
   }

   req.tp = tp;
   req.reason = (side == QM_BUY) ? "VWAP_BB_RSI_LONG" : "VWAP_BB_RSI_SHORT";

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

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(current_sl > 0.0 && current_sl < open_price)
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
