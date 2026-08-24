#property strict
#property version   "5.0"
#property description "QM5_39001 Trading Made Simple (TMS) with TDI Engine"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_39001
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 39001;
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

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int             strategy_tdi_rsi_period      = 13;
input int             strategy_tdi_base_period     = 34;
input int             strategy_ema_period          = 5;
input double          strategy_daily_loss_halt_pct = 2.0;    // Daily realized-loss entry halt percent
input double          strategy_daily_hard_stop_pct = 2.5;    // Daily equity hard stop percent
input double          strategy_total_dd_halt_pct   = 5.0;    // Account-level total drawdown stop percent
input double          strategy_per_trade_risk_cap_pct = 0.5; // Per-trade risk cap percent

const ENUM_TIMEFRAMES STRATEGY_SIGNAL_TF = PERIOD_H1;
const int    STRATEGY_TDI_FAST_PERIOD    = 2;
const int    STRATEGY_TDI_SLOW_PERIOD    = 7;
const int    STRATEGY_ATR_PERIOD         = 14;
const int    STRATEGY_SWING_BARS         = 3;
const int    STRATEGY_SL_BUFFER_PIPS     = 3;
const double STRATEGY_TP_RR_MULT         = 2.0;
const int    STRATEGY_ROLLOVER_START     = 2355;
const int    STRATEGY_ROLLOVER_END       = 5;
const double STRATEGY_SPREAD_MULT        = 1.8;
const int    STRATEGY_MAX_SLIPPAGE_TICKS = 3;

// -----------------------------------------------------------------------------
// State Cache & Indicators
// -----------------------------------------------------------------------------
double g_tdi_fast       = 0.0;
double g_tdi_slow       = 0.0;
double g_tdi_fast_prev  = 0.0;
double g_tdi_slow_prev  = 0.0;
double g_tdi_base       = 0.0;
double g_ema5           = 0.0;
double g_last_atr       = 0.0;
double g_swing_low      = 0.0;
double g_swing_high     = 0.0;
int    g_last_signal    = 0;
bool   g_state_ready    = false;

int StrategyHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
}

bool StrategyInRolloverWindow(const datetime t)
{
   const int hhmm = StrategyHhmm(t);
   if(STRATEGY_ROLLOVER_START > STRATEGY_ROLLOVER_END)
      return (hhmm >= STRATEGY_ROLLOVER_START || hhmm < STRATEGY_ROLLOVER_END);
   return (hhmm >= STRATEGY_ROLLOVER_START && hhmm < STRATEGY_ROLLOVER_END);
}

bool Strategy_ValidateInputs()
{
   if(strategy_tdi_rsi_period < 8 || strategy_tdi_rsi_period > 21)
      return false;
   if(strategy_tdi_base_period < 20 || strategy_tdi_base_period > 50)
      return false;
   if(strategy_ema_period < 3 || strategy_ema_period > 8)
      return false;
   if(strategy_daily_loss_halt_pct <= 0.0 || strategy_daily_loss_halt_pct > 2.0)
      return false;
   if(strategy_daily_hard_stop_pct <= 0.0 || strategy_daily_hard_stop_pct > 2.5)
      return false;
   if(strategy_total_dd_halt_pct <= 0.0 || strategy_total_dd_halt_pct > 5.0)
      return false;
   if(strategy_per_trade_risk_cap_pct <= 0.0 || strategy_per_trade_risk_cap_pct > 0.5)
      return false;
   return true;
}

int Strategy_MaxDeviationPoints()
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double trade_tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || trade_tick <= 0.0)
      return 0;
   return (int)MathCeil((double)STRATEGY_MAX_SLIPPAGE_TICKS * trade_tick / point);
}

bool Strategy_DailyRealizedLossHalt()
{
   int closed_trades = 0;
   const double realized_pnl = QM_ChartUITodayPnL(0, closed_trades);
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   const double day_start_balance = balance_now - realized_pnl;
   if(balance_now <= 0.0 || day_start_balance <= 0.0)
      return true;
   return (realized_pnl <= -(day_start_balance * strategy_daily_loss_halt_pct / 100.0));
}

bool Strategy_TdiSma(const int shift, const int length, double &value)
{
   value = 0.0;
   if(shift < 1 || length <= 0)
      return false;
   double sum = 0.0;
   for(int i = 0; i < length; ++i)
   {
      const double rsi = QM_RSI(_Symbol, STRATEGY_SIGNAL_TF, strategy_tdi_rsi_period, shift + i, PRICE_CLOSE);
      if(rsi == EMPTY_VALUE || rsi < 0.0 || rsi > 100.0)
         return false;
      sum += rsi;
   }
   value = sum / (double)length;
   return true;
}

void Strategy_ClearState()
{
   g_tdi_fast = 0.0;
   g_tdi_slow = 0.0;
   g_tdi_fast_prev = 0.0;
   g_tdi_slow_prev = 0.0;
   g_tdi_base = 0.0;
   g_ema5 = 0.0;
   g_last_atr = 0.0;
   g_swing_low = 0.0;
   g_swing_high = 0.0;
   g_last_signal = 0;
   g_state_ready = false;
}

bool Strategy_RefreshH1State()
{
   Strategy_ClearState();

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, STRATEGY_SIGNAL_TF, 1, STRATEGY_SWING_BARS, rates); // perf-allowed: bounded three-completed-H1-bar card window
   if(copied != STRATEGY_SWING_BARS || ArraySize(rates) < STRATEGY_SWING_BARS)
      return false;

   if(rates[0].close <= 0.0 || rates[0].open <= 0.0)
      return false;

   if(!Strategy_TdiSma(1, STRATEGY_TDI_FAST_PERIOD, g_tdi_fast) ||
      !Strategy_TdiSma(1, STRATEGY_TDI_SLOW_PERIOD, g_tdi_slow) ||
      !Strategy_TdiSma(2, STRATEGY_TDI_FAST_PERIOD, g_tdi_fast_prev) ||
      !Strategy_TdiSma(2, STRATEGY_TDI_SLOW_PERIOD, g_tdi_slow_prev) ||
      !Strategy_TdiSma(1, strategy_tdi_base_period, g_tdi_base))
      return false;

   g_ema5 = QM_EMA(_Symbol, STRATEGY_SIGNAL_TF, strategy_ema_period, 1, PRICE_TYPICAL);
   g_last_atr = QM_ATR(_Symbol, STRATEGY_SIGNAL_TF, STRATEGY_ATR_PERIOD, 1);
   if(g_ema5 <= 0.0 || g_last_atr <= 0.0)
      return false;

   g_swing_low = rates[0].low;
   g_swing_high = rates[0].high;
   for(int i = 1; i < STRATEGY_SWING_BARS && i < ArraySize(rates); ++i)
   {
      if(rates[i].low <= 0.0 || rates[i].high <= 0.0)
         return false;
      if(rates[i].low < g_swing_low)
         g_swing_low = rates[i].low;
      if(rates[i].high > g_swing_high)
         g_swing_high = rates[i].high;
   }

   if(g_tdi_fast > g_tdi_slow && g_tdi_fast > g_tdi_base && rates[0].close > g_ema5)
      g_last_signal = 1;
   else if(g_tdi_fast < g_tdi_slow && g_tdi_fast < g_tdi_base && rates[0].close < g_ema5)
      g_last_signal = -1;

   g_state_ready = true;
   return true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(!g_state_ready)
      return true;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   if(StrategyInRolloverWindow(utc_now))
      return true;

   if(Strategy_DailyRealizedLossHalt())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   if(ask > bid && g_last_atr > 0.0)
   {
      const double spread = ask - bid;
      if(spread > g_last_atr * STRATEGY_SPREAD_MULT)
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
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) >= 1)
      return false;

   if(!g_state_ready || g_last_signal == 0 || g_swing_low <= 0.0 || g_swing_high <= 0.0)
      return false;

   const QM_OrderType side = (g_last_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, STRATEGY_SL_BUFFER_PIPS);
   if(buffer <= 0.0)
      return false;

   double sl = 0.0;
   double tp = 0.0;

   if(side == QM_BUY)
   {
      sl = g_swing_low - buffer;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      const double sl_dist = entry - sl;
      if(sl_dist <= 0.0)
         return false;
      tp = QM_StopRulesNormalizePrice(_Symbol, entry + sl_dist * STRATEGY_TP_RR_MULT);
   }
   else
   {
      sl = g_swing_high + buffer;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      const double sl_dist = sl - entry;
      if(sl_dist <= 0.0)
         return false;
      tp = QM_StopRulesNormalizePrice(_Symbol, entry - sl_dist * STRATEGY_TP_RR_MULT);
   }

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "TMS_TDI_LONG" : "TMS_TDI_SHORT";

   return (req.sl > 0.0 && req.tp > 0.0);
}

void Strategy_ManageOpenPosition()
{
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
      // A cross-back requires the previous and current completed-H1 relationship.
      if(g_state_ready)
      {
         const bool crossed_down = (g_tdi_fast_prev >= g_tdi_slow_prev && g_tdi_fast < g_tdi_slow);
         const bool crossed_up = (g_tdi_fast_prev <= g_tdi_slow_prev && g_tdi_fast > g_tdi_slow);
         if(pos_type == POSITION_TYPE_BUY && crossed_down)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
         }
         else if(pos_type == POSITION_TYPE_SELL && crossed_up)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
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
   if(!Strategy_ValidateInputs())
      return INIT_PARAMETERS_INCORRECT;

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        QM_NEWS_OFF,
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

   const int deviation_points = Strategy_MaxDeviationPoints();
   if(deviation_points <= 0)
      return INIT_FAILED;
   QM_EntryConfigure(qm_ea_id,
                     QM_NEWS_OFF,
                     deviation_points,
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

   // Seed closed-H1 state for restart-safe management. A missing read remains
   // fail-closed and is retried at the first observable H1 bar boundary.
   Strategy_RefreshH1State();

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

   if(QM_FrameworkHandleFridayClose())
      return;

   const bool is_new_h1_bar = QM_IsNewBar(_Symbol, STRATEGY_SIGNAL_TF);
   if(is_new_h1_bar)
      Strategy_RefreshH1State();

   // Entry blackouts must not suppress management or strategy exits.
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

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, QM_NEWS_OFF);
   if(!news_allows)
      return;

   if(!is_new_h1_bar)
      return;

   if(Strategy_NoTradeFilter())
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
