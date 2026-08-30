#property strict
#property version   "5.0"
#property description "QM5_38006 CodeTrading Hammer & Doji Pivot Rejection"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_38006
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 38006;
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
input int             strategy_ema_period          = 50;
input double          strategy_max_body_ratio      = 0.25;
input double          strategy_min_wick_ratio      = 0.60;
input double          strategy_zone_atr_mult       = 0.50;
input int             strategy_atr_period          = 14;
input int             strategy_sl_buffer_pips      = 2;
input double          strategy_tp_rr_mult          = 1.8;
input bool            strategy_be_enabled          = true;
input double          strategy_be_trigger_r        = 1.0;
input int             strategy_rollover_start_hhmm = 2355;
input int             strategy_rollover_end_hhmm   = 5;
input double          strategy_spread_filter_mult  = 1.8;
input int             strategy_max_slippage_ticks  = 3;
input double          strategy_daily_loss_halt_pct = 2.0;
input double          strategy_daily_hard_stop_pct = 2.5;
input double          strategy_total_dd_halt_pct   = 5.0;

// -----------------------------------------------------------------------------
// State Cache & Indicators
// -----------------------------------------------------------------------------
double g_ema50           = 0.0;
double g_last_atr        = 0.0;
double g_last_low1       = 0.0;
double g_last_high1      = 0.0;
int    g_last_signal     = 0;
double g_initial_equity  = 0.0;
bool   g_total_dd_halted = false;

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
   if(strategy_signal_tf != PERIOD_H1 ||
      strategy_ema_period < 20 || strategy_ema_period > 100 ||
      strategy_atr_period != 14 || strategy_spread_filter_mult != 1.8)
      return false;
   if(strategy_max_body_ratio < 0.15 || strategy_max_body_ratio > 0.35 ||
      strategy_min_wick_ratio < 0.50 || strategy_min_wick_ratio > 0.75 ||
      strategy_zone_atr_mult != 0.50)
      return false;
   if(strategy_sl_buffer_pips != 2 || strategy_tp_rr_mult != 1.8 ||
      !strategy_be_enabled || strategy_be_trigger_r != 1.0 ||
      strategy_max_slippage_ticks != 3)
      return false;
   // Card InpRiskPercent maps to the canonical framework RISK_PERCENT input.
   // Zero is required for backtests; live values must stay inside 0.20-1.00%.
   if(RISK_PERCENT != 0.0 && (RISK_PERCENT < 0.20 || RISK_PERCENT > 1.00))
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
   return true;
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
   g_last_signal = 0;
   g_ema50 = 0.0;
   g_last_atr = 0.0;
   g_last_low1 = 0.0;
   g_last_high1 = 0.0;

   const double open1  = iOpen(_Symbol, strategy_signal_tf, 1);  // perf-allowed: closed-bar candlestick calculation
   const double close1 = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: closed-bar candlestick calculation
   const double high1  = iHigh(_Symbol, strategy_signal_tf, 1);  // perf-allowed: closed-bar candlestick calculation
   const double low1   = iLow(_Symbol, strategy_signal_tf, 1);   // perf-allowed: closed-bar candlestick calculation

   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return;

   g_ema50     = QM_EMA(_Symbol, strategy_signal_tf, strategy_ema_period, 1, PRICE_CLOSE);
   g_last_atr  = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period), 1);
   g_last_low1  = low1;
   g_last_high1 = high1;

   const double range = high1 - low1;
   if(range > 0.0 && g_last_atr > 0.0 && g_ema50 > 0.0)
   {
      const double body = MathAbs(close1 - open1);
      const double upper_wick = high1 - MathMax(open1, close1);
      const double lower_wick = MathMin(open1, close1) - low1;

      // Hammer (Bullish Rejection): Body <= 0.25 * Range, Lower Wick >= 0.60 * Range, Close > Open, Low near EMA50
      const bool is_hammer = (body <= strategy_max_body_ratio * range) &&
                             (lower_wick >= strategy_min_wick_ratio * range) &&
                             (close1 > open1);
      const bool long_zone = (MathAbs(low1 - g_ema50) <= strategy_zone_atr_mult * g_last_atr);

      // Shooting Star (Bearish Rejection): Body <= 0.25 * Range, Upper Wick >= 0.60 * Range, Close < Open, High near EMA50
      const bool is_shooting_star = (body <= strategy_max_body_ratio * range) &&
                                    (upper_wick >= strategy_min_wick_ratio * range) &&
                                    (close1 < open1);
      const bool short_zone = (MathAbs(high1 - g_ema50) <= strategy_zone_atr_mult * g_last_atr);

      if(is_hammer && long_zone)
         g_last_signal = 1;
      else if(is_shooting_star && short_zone)
         g_last_signal = -1;
   }
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool StrategyTotalDrawdownHaltCheck()
{
   if(strategy_total_dd_halt_pct <= 0.0)
      return false;

   if(g_initial_equity <= 0.0)
   {
      g_initial_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(g_initial_equity <= 0.0)
         g_initial_equity = AccountInfoDouble(ACCOUNT_BALANCE);
   }

   const double equity_now = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_initial_equity > 0.0 && equity_now > 0.0)
   {
      const double total_dd_pct = ((g_initial_equity - equity_now) / g_initial_equity) * 100.0;
      if(total_dd_pct >= strategy_total_dd_halt_pct)
      {
         if(!g_total_dd_halted)
         {
            g_total_dd_halted = true;
            QM_LogEvent(QM_ERROR, "TOTAL_DD_HALT",
                        StringFormat("{\"initial_equity\":%.2f,\"equity_now\":%.2f,\"total_dd_pct\":%.6f,\"halt_pct\":%.6f}",
                                     g_initial_equity, equity_now, total_dd_pct, strategy_total_dd_halt_pct));
         }
      }
   }

   if(g_total_dd_halted)
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(magic > 0 && PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_KILLSWITCH);
      }
      return true;
   }

   return false;
}

bool StrategyDailyRealizedLossHalt()
{
   MqlDateTime ts;
   TimeToStruct(TimeCurrent(), ts);
   ts.hour = 0;
   ts.min = 0;
   ts.sec = 0;
   const datetime day_start = StructToTime(ts);
   const datetime now = TimeCurrent();

   if(!HistorySelect(day_start, now))
   {
      QM_LogEvent(QM_ERROR, "HISTORY_SELECT_FAILED",
                  StringFormat("{\"day_start\":%I64d,\"now\":%I64d,\"action\":\"fail_closed_entry_halt\"}",
                               (long)day_start, (long)now));
      return true;
   }

   double realized_pnl = 0.0;
   int closed_trades = 0;
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;

      const long entry = (long)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         continue;

      realized_pnl += HistoryDealGetDouble(deal, DEAL_PROFIT);
      realized_pnl += HistoryDealGetDouble(deal, DEAL_SWAP);
      realized_pnl += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      ++closed_trades;
   }

   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   const double day_start_balance = balance_now - realized_pnl;
   if(balance_now <= 0.0 || day_start_balance <= 0.0)
   {
      QM_LogEvent(QM_WARN, "INVALID_BALANCE_BASELINE",
                  StringFormat("{\"balance_now\":%.2f,\"day_start_balance\":%.2f,\"realized_pnl\":%.2f}",
                               balance_now, day_start_balance, realized_pnl));
      return true;
   }

   if(realized_pnl <= -(day_start_balance * strategy_daily_loss_halt_pct / 100.0))
   {
      QM_LogEvent(QM_WARN, "DAILY_REALIZED_LOSS_HALT",
                  StringFormat("{\"realized_pnl\":%.2f,\"day_start_balance\":%.2f,\"loss_pct\":%.4f,\"limit_pct\":%.4f,\"closed_trades\":%d}",
                               realized_pnl, day_start_balance,
                               (-realized_pnl / day_start_balance) * 100.0,
                               strategy_daily_loss_halt_pct,
                               closed_trades));
      return true;
   }

   return false;
}

bool StrategyCurrentSpreadAllowsEntry()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || g_last_atr <= 0.0)
      return false;

   return ((ask - bid) <= g_last_atr * strategy_spread_filter_mult);
}

bool Strategy_NoTradeFilter()
{
   if(StrategyTotalDrawdownHaltCheck())
      return true;

   if(StrategyInRolloverWindow(QM_BrokerToUTC(TimeCurrent())))
      return true;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) >= 1)
      return true;

   if(StrategyDailyRealizedLossHalt())
      return true;

   return !StrategyCurrentSpreadAllowsEntry();
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
   if(buffer <= 0.0)
      return false;

   double sl = 0.0;
   double tp = 0.0;

   if(side == QM_BUY)
   {
      sl = QM_StopRulesNormalizePrice(_Symbol, g_last_low1 - buffer);
      const double sl_dist = entry - sl;
      if(sl_dist <= 0.0)
         return false;
      tp = QM_StopRulesNormalizePrice(_Symbol, entry + sl_dist * strategy_tp_rr_mult);
   }
   else
   {
      sl = QM_StopRulesNormalizePrice(_Symbol, g_last_high1 + buffer);
      const double sl_dist = sl - entry;
      if(sl_dist <= 0.0)
         return false;
      tp = QM_StopRulesNormalizePrice(_Symbol, entry - sl_dist * strategy_tp_rr_mult);
   }

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "HAMMER_PIVOT_LONG" : "SHOOTING_STAR_PIVOT_SHORT";

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
                         1.0)) // Framework cap: preserves canonical $1,000 risk on $100k backtests.
      return INIT_FAILED;

   g_initial_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_initial_equity <= 0.0)
      g_initial_equity = AccountInfoDouble(ACCOUNT_BALANCE);
   g_total_dd_halted = false;

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
   if(StrategyTotalDrawdownHaltCheck())
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
      // Re-read the live spread at the execution boundary. News/calendar
      // checks above may take time, so the earlier admission value is stale.
      if(!StrategyCurrentSpreadAllowsEntry())
         return;

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
