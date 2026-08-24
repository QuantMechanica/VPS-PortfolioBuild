#property strict
#property version   "5.0"
#property description "QM5_38003 CodeTrading Bollinger Engulfing Reversal"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_38003
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 38003;
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
input ENUM_TIMEFRAMES strategy_signal_tf           = PERIOD_H1;
input int             strategy_bb_period           = 20;
input double          strategy_bb_dev              = 2.00;
input int             strategy_rsi_period          = 14;
input double          strategy_rsi_long_max        = 35.0;
input double          strategy_rsi_short_min       = 65.0;
input int             strategy_atr_period          = 14;
input double          strategy_sl_buffer_pips      = 2.0;
input double          strategy_tp_rr               = 2.0;
input bool            strategy_mid_exit_enabled    = true;
input double          strategy_mid_exit_fraction   = 0.50;
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
double g_bb_upper       = 0.0;
double g_bb_lower       = 0.0;
double g_bb_middle      = 0.0;
double g_rsi            = 50.0;
double g_last_atr       = 0.0;
double g_last_low1      = 0.0;
double g_last_high1     = 0.0;
int    g_last_signal    = 0;
long   g_mid_exit_position_id = 0;
bool   g_mid_exit_completed   = false;
bool   g_mid_exit_state_known = false;

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
   if(strategy_signal_tf != PERIOD_H1 || strategy_bb_period < 2 ||
      strategy_bb_dev <= 0.0 || strategy_rsi_period < 2 ||
      strategy_atr_period < 2 || strategy_spread_filter_mult <= 0.0)
      return false;
   if(strategy_rsi_long_max <= 0.0 || strategy_rsi_short_min >= 100.0 ||
      strategy_rsi_long_max >= strategy_rsi_short_min)
      return false;
   if(strategy_sl_buffer_pips != 2.0 || strategy_tp_rr != 2.0 ||
      !strategy_mid_exit_enabled || strategy_mid_exit_fraction != 0.50 ||
      strategy_max_slippage_ticks <= 0 || strategy_max_slippage_ticks > 3)
      return false;
   if(strategy_rollover_start_hhmm < 0 || strategy_rollover_start_hhmm > 2359 ||
      strategy_rollover_end_hhmm < 0 || strategy_rollover_end_hhmm > 2359 ||
      (strategy_rollover_start_hhmm % 100) > 59 ||
      (strategy_rollover_end_hhmm % 100) > 59)
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

bool StrategyVolumeCanSplitHalf(const double volume)
{
   const double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(volume <= 0.0 || volume_min <= 0.0 || volume_step <= 0.0)
      return false;

   const double close_lots = QM_TM_NormalizeVolume(_Symbol,
                                                    volume * strategy_mid_exit_fraction);
   const double runner_lots = volume - close_lots;
   const double tolerance = volume_step * 1e-6;
   return (close_lots >= volume_min - tolerance &&
           runner_lots >= volume_min - tolerance &&
           MathAbs(close_lots - runner_lots) <= tolerance);
}

bool StrategyLoadMidExitState(const long position_id, bool &completed)
{
   completed = false;
   if(position_id <= 0 || !HistorySelectByPosition((ulong)position_id))
      return false;

   const int deals_total = HistoryDealsTotal();
   for(int i = 0; i < deals_total; ++i)
   {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0 ||
         (long)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID) != position_id)
         continue;

      const ENUM_DEAL_TYPE deal_type =
         (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal_ticket, DEAL_TYPE);
      const ENUM_DEAL_ENTRY deal_entry =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      const bool trade_deal = (deal_type == DEAL_TYPE_BUY || deal_type == DEAL_TYPE_SELL);
      if(trade_deal &&
         (deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_OUT_BY ||
          deal_entry == DEAL_ENTRY_INOUT))
      {
         completed = true;
         break;
      }
   }
   return true;
}

bool StrategyMidExitState(const long position_id, bool &completed)
{
   if(g_mid_exit_state_known && g_mid_exit_position_id == position_id)
   {
      completed = g_mid_exit_completed;
      return true;
   }

   bool reconstructed = false;
   if(!StrategyLoadMidExitState(position_id, reconstructed))
      return false;
   g_mid_exit_position_id = position_id;
   g_mid_exit_completed = reconstructed;
   g_mid_exit_state_known = true;
   completed = reconstructed;
   return true;
}

void AdvanceState_OnNewBar()
{
   const double open1  = iOpen(_Symbol, strategy_signal_tf, 1);  // perf-allowed: closed-bar candlestick calculation
   const double close1 = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: closed-bar candlestick calculation
   const double high1  = iHigh(_Symbol, strategy_signal_tf, 1);  // perf-allowed: closed-bar candlestick calculation
   const double low1   = iLow(_Symbol, strategy_signal_tf, 1);   // perf-allowed: closed-bar candlestick calculation

   const double open2  = iOpen(_Symbol, strategy_signal_tf, 2);  // perf-allowed: closed-bar candlestick calculation
   const double close2 = iClose(_Symbol, strategy_signal_tf, 2); // perf-allowed: closed-bar candlestick calculation

   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 ||
      open2 <= 0.0 || close2 <= 0.0)
      return;

   g_bb_upper  = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   g_bb_lower  = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   g_bb_middle = QM_BB_Middle(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   g_rsi       = QM_RSI(_Symbol, strategy_signal_tf, strategy_rsi_period, 1, PRICE_CLOSE);
   g_last_atr  = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period), 1);
   g_last_low1  = low1;
   g_last_high1 = high1;

   g_last_signal = 0;
   if(g_bb_lower > 0.0 && g_bb_upper > 0.0 && g_rsi > 0.0)
   {
      // Bullish Engulfing: Bar 2 is bearish, Bar 1 is bullish, Bar 1 engulfs Bar 2 body
      const bool bull_engulf = (close2 < open2) && (close1 > open1) &&
                                (close1 > open2) && (open1 < close2);
      const bool bull_band_touch = (low1 <= g_bb_lower);
      const bool bull_rsi = (g_rsi <= strategy_rsi_long_max);

      // Bearish Engulfing: Bar 2 is bullish, Bar 1 is bearish, Bar 1 engulfs Bar 2 body
      const bool bear_engulf = (close2 > open2) && (close1 < open1) &&
                                (close1 < open2) && (open1 > close2);
      const bool bear_band_touch = (high1 >= g_bb_upper);
      const bool bear_rsi = (g_rsi >= strategy_rsi_short_min);

      if(bull_engulf && bull_band_touch && bull_rsi)
         g_last_signal = 1;
      else if(bear_engulf && bear_band_touch && bear_rsi)
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

bool StrategySpreadAllowsEntry()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || g_last_atr <= 0.0)
      return false;

   const double spread = ask - bid;
   return (spread <= g_last_atr * strategy_spread_filter_mult);
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

   return !StrategySpreadAllowsEntry();
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

   if(g_last_signal == 0 || g_last_atr <= 0.0)
      return false;

   const QM_OrderType side = (g_last_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                         (int)strategy_sl_buffer_pips);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(buffer <= 0.0 || point <= 0.0)
      return false;

   double sl = 0.0;
   double tp = 0.0;

   if(side == QM_BUY)
   {
      sl = QM_StopRulesNormalizePrice(_Symbol, g_last_low1 - buffer);
      const double sl_dist = entry - sl;
      if(sl_dist <= 0.0)
         return false;
      tp = QM_StopRulesNormalizePrice(_Symbol, entry + strategy_tp_rr * sl_dist);
   }
   else
   {
      sl = QM_StopRulesNormalizePrice(_Symbol, g_last_high1 + buffer);
      const double sl_dist = sl - entry;
      if(sl_dist <= 0.0)
         return false;
      tp = QM_StopRulesNormalizePrice(_Symbol, entry - strategy_tp_rr * sl_dist);
   }

   const double sl_points = MathAbs(entry - sl) / point;
   const ENUM_ORDER_TYPE order_type = (side == QM_BUY) ? ORDER_TYPE_BUY
                                                        : ORDER_TYPE_SELL;
   const double expected_lots = QM_LotsForRiskAtEntry(_Symbol,
                                                       sl_points,
                                                       order_type,
                                                       entry);
   if(!StrategyVolumeCanSplitHalf(expected_lots))
      return false;

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "BOLL_ENGULF_LONG" : "BOLL_ENGULF_SHORT";

   return (req.sl > 0.0 && req.tp > 0.0);
}

void Strategy_ManageOpenPosition()
{
   if(!strategy_mid_exit_enabled || g_bb_middle <= 0.0)
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
      const long position_id = PositionGetInteger(POSITION_IDENTIFIER);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(position_id <= 0 || volume <= 0.0)
         continue;

      bool mid_exit_completed = false;
      if(!StrategyMidExitState(position_id, mid_exit_completed) ||
         mid_exit_completed)
         continue;

      const double market_price = (pos_type == POSITION_TYPE_BUY)
                                  ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0)
         continue;
      const bool middle_touched = (pos_type == POSITION_TYPE_BUY)
                                  ? (market_price >= g_bb_middle)
                                  : (market_price <= g_bb_middle);
      if(!middle_touched || !StrategyVolumeCanSplitHalf(volume))
         continue;

      const double partial_lots = QM_TM_NormalizeVolume(
         _Symbol,
         volume * strategy_mid_exit_fraction);
      if(QM_TM_PartialClose(ticket, partial_lots, QM_EXIT_PARTIAL))
      {
         g_mid_exit_position_id = position_id;
         g_mid_exit_completed = true;
         g_mid_exit_state_known = true;
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
   if(Strategy_EntrySignal(req) && StrategySpreadAllowsEntry())
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
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
      g_mid_exit_state_known = false;
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
