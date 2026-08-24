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
input double          strategy_daily_loss_limit_pct = 2.0;
input double          strategy_daily_drawdown_hard_stop_pct = 2.5;
input double          strategy_total_drawdown_stop_pct = 5.0;

// -----------------------------------------------------------------------------
// Closed-bar indicator cache and mechanical risk-limit state.
// -----------------------------------------------------------------------------
double g_strategy_cached_atr      = 0.0;
double g_strategy_cached_med_ema  = 0.0;
double g_strategy_initial_equity  = 0.0;
double g_strategy_day_start_balance = 0.0;
int    g_strategy_day_key         = -1;
bool   g_strategy_daily_entry_halted = false;
bool   g_strategy_daily_hard_halted  = false;
bool   g_strategy_total_halted       = false;
bool   g_strategy_entry_blocked      = false;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return true;

   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   const double equity_now  = AccountInfoDouble(ACCOUNT_EQUITY);
   const datetime broker_now = TimeCurrent();

   MqlDateTime broker_dt;
   TimeToStruct(broker_now, broker_dt);
   const int day_key = broker_dt.year * 1000 + broker_dt.day_of_year;

   if(g_strategy_initial_equity <= 0.0 && equity_now > 0.0)
      g_strategy_initial_equity = equity_now;

   if(g_strategy_day_key != day_key)
   {
      g_strategy_day_key = day_key;
      g_strategy_day_start_balance = (balance_now > 0.0) ? balance_now : equity_now;
      g_strategy_daily_entry_halted = false;
      g_strategy_daily_hard_halted = false;
   }

   if(g_strategy_day_start_balance > 0.0)
   {
      const double realized_loss_pct = MathMax(0.0,
         (g_strategy_day_start_balance - balance_now) / g_strategy_day_start_balance * 100.0);
      const double daily_drawdown_pct = MathMax(0.0,
         (g_strategy_day_start_balance - equity_now) / g_strategy_day_start_balance * 100.0);

      if(strategy_daily_loss_limit_pct > 0.0 &&
         realized_loss_pct >= strategy_daily_loss_limit_pct)
         g_strategy_daily_entry_halted = true;

      if(strategy_daily_drawdown_hard_stop_pct > 0.0 &&
         daily_drawdown_pct >= strategy_daily_drawdown_hard_stop_pct)
         g_strategy_daily_hard_halted = true;
   }

   if(g_strategy_initial_equity > 0.0)
   {
      const double total_drawdown_pct = MathMax(0.0,
         (g_strategy_initial_equity - equity_now) / g_strategy_initial_equity * 100.0);
      if(strategy_total_drawdown_stop_pct > 0.0 &&
         total_drawdown_pct >= strategy_total_drawdown_stop_pct)
         g_strategy_total_halted = true;
   }

   const datetime utc_now = QM_BrokerToUTC(broker_now);
   MqlDateTime utc_dt;
   TimeToStruct(utc_now, utc_dt);
   const int utc_hhmm = utc_dt.hour * 100 + utc_dt.min;
   bool rollover_blocked = false;
   if(strategy_rollover_start_hhmm > strategy_rollover_end_hhmm)
      rollover_blocked = (utc_hhmm >= strategy_rollover_start_hhmm ||
                          utc_hhmm < strategy_rollover_end_hhmm);
   else
      rollover_blocked = (utc_hhmm >= strategy_rollover_start_hhmm &&
                          utc_hhmm < strategy_rollover_end_hhmm);

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool spread_blocked = (ask <= 0.0 || bid <= 0.0);

   if(!spread_blocked && ask > bid && g_strategy_cached_atr > 0.0)
   {
      const double spread = ask - bid;
      if(spread > g_strategy_cached_atr * strategy_spread_filter_mult)
         spread_blocked = true;
   }

   g_strategy_entry_blocked = (rollover_blocked || spread_blocked ||
                               g_strategy_daily_entry_halted ||
                               g_strategy_daily_hard_halted ||
                               g_strategy_total_halted);

   // Entry filters must not make management unreachable for existing risk.
   const bool has_open_position = (QM_TM_OpenPositionCount(magic) > 0);
   return (g_strategy_entry_blocked && !has_open_position);
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

   if(strategy_fast_ema_period <= 0 || strategy_med_ema_period <= 0 ||
      strategy_slow_ema_period <= 0 || strategy_atr_period <= 0 ||
      strategy_sl_buffer_pips <= 0 || strategy_tp_rr <= 0.0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, strategy_signal_tf,
                                  strategy_fast_ema_period, 1, PRICE_CLOSE);
   const double ema_med = QM_EMA(_Symbol, strategy_signal_tf,
                                 strategy_med_ema_period, 1, PRICE_CLOSE);
   const double ema_slow = QM_EMA(_Symbol, strategy_signal_tf,
                                  strategy_slow_ema_period, 1, PRICE_CLOSE);
   const double atr_last = QM_ATR(_Symbol, strategy_signal_tf,
                                  strategy_atr_period, 1);

   g_strategy_cached_med_ema = ema_med;
   g_strategy_cached_atr = atr_last;

   if(ema_fast <= 0.0 || ema_med <= 0.0 || ema_slow <= 0.0 || atr_last <= 0.0)
      return false;

   const double open1  = iOpen(_Symbol, strategy_signal_tf, 1);  // perf-allowed: card-authorized closed-bar candle body behind QM_IsNewBar().
   const double high1  = iHigh(_Symbol, strategy_signal_tf, 1);  // perf-allowed: card-authorized closed-bar pullback extreme behind QM_IsNewBar().
   const double low1   = iLow(_Symbol, strategy_signal_tf, 1);   // perf-allowed: card-authorized closed-bar pullback extreme behind QM_IsNewBar().
   const double close1 = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: card-authorized closed-bar candle body behind QM_IsNewBar().
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   if(g_strategy_entry_blocked || g_strategy_daily_entry_halted ||
      g_strategy_daily_hard_halted || g_strategy_total_halted)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) >= 1)
      return false;

   int signal = 0;
   if(ema_fast > ema_med && ema_med > ema_slow &&
      low1 <= ema_fast && close1 > ema_med && close1 > open1)
      signal = 1;
   else if(ema_fast < ema_med && ema_med < ema_slow &&
           high1 >= ema_fast && close1 < ema_med && close1 < open1)
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

   const double raw_sl = (side == QM_BUY) ? (ema_slow - buffer)
                                           : (ema_slow + buffer);
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
   if(g_strategy_daily_hard_halted || g_strategy_total_halted)
      return;

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
   return (g_strategy_daily_hard_halted || g_strategy_total_halted);
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

   if(Strategy_NoTradeFilter())
      return;

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

   // Custom and central news filters gate only the entry path. Protective
   // management and hard-stop exits above remain reachable through news.
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
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
