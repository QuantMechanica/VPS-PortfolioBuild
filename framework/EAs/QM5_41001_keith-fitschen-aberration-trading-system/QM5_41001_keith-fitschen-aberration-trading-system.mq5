#property strict
#property version   "5.0"
#property description "QM5_41001 Keith Fitschen Aberration Commodity Trend System"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_41001
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41001;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "Loss Limits"
input double strategy_daily_loss_halt_pct = 2.0; // Card: Account daily realized loss >= 2.0%
input double strategy_daily_hard_stop_pct = 2.5; // Card: Maximum daily drawdown hard stop 2.5%
input double strategy_total_dd_stop_pct   = 5.0; // Card: Maximum total drawdown stop 5.0%

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
input ENUM_TIMEFRAMES strategy_signal_tf           = PERIOD_D1;
input int             strategy_sma_period          = 30;
input double          strategy_dev_multiplier      = 3.00;
input int             strategy_atr_period          = 14;
input double          strategy_atr_sl_mult         = 2.5;
input bool            strategy_use_mid_exit        = true;
input int             strategy_rollover_start_hhmm = 2355;
input int             strategy_rollover_end_hhmm   = 5;
input double          strategy_spread_filter_mult  = 1.8;

// -----------------------------------------------------------------------------
// State Cache & Indicators
// -----------------------------------------------------------------------------
double g_bb_upper1     = 0.0;
double g_bb_lower1     = 0.0;
double g_bb_upper2     = 0.0;
double g_bb_lower2     = 0.0;
double g_bb_middle1    = 0.0;
double g_last_atr      = 0.0;
double g_last_close1   = 0.0;
double g_last_close2   = 0.0;
int    g_last_signal   = 0;

// The approved execution contract fixes market-order slippage at three trade
// ticks.  QM_Entry expects deviation in points, so translate the symbol's
// trade-tick size without permitting a wider rounded-up tolerance.
int StrategyEntryDeviationPoints()
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0 || tick_size <= 0.0)
      return 0;

   const double max_price_deviation = 3.0 * tick_size;
   return (int)MathFloor((max_price_deviation / point) + 1.0e-9);
}

int StrategyHhmm(const datetime t)
{
   const datetime utc = QM_BrokerToUTC(t);
   MqlDateTime dt;
   TimeToStruct((utc > 0) ? utc : t, dt);
   return dt.hour * 100 + dt.min;
}

bool StrategyInRolloverWindow(const datetime t)
{
   const int hhmm = StrategyHhmm(t);
   if(strategy_rollover_start_hhmm > strategy_rollover_end_hhmm)
      return (hhmm >= strategy_rollover_start_hhmm || hhmm < strategy_rollover_end_hhmm);
   return (hhmm >= strategy_rollover_start_hhmm && hhmm < strategy_rollover_end_hhmm);
}

bool Strategy_ValidateInputs()
{
   if(strategy_daily_loss_halt_pct <= 0.0 || strategy_daily_hard_stop_pct <= 0.0 ||
      strategy_daily_loss_halt_pct > strategy_daily_hard_stop_pct || strategy_total_dd_stop_pct <= 0.0)
      return false;
   if(strategy_sma_period < 2 || strategy_dev_multiplier <= 0.0 || strategy_atr_period < 1 || strategy_atr_sl_mult <= 0.0)
      return false;
   return true;
}

bool Strategy_DailyRealizedLossHalt()
{
   int closed_trades = 0;
   const double realized_pnl = QM_ChartUITodayPnL(0, closed_trades);
   const double balance_now = AccountInfoDouble(ACCOUNT_BALANCE);
   const double day_start_balance = balance_now - realized_pnl;
   if(balance_now <= 0.0 || day_start_balance <= 0.0)
      return true;
   if(realized_pnl < 0.0)
   {
      const double loss_pct = (-realized_pnl / day_start_balance) * 100.0;
      if(loss_pct >= strategy_daily_loss_halt_pct)
         return true;
   }
   return false;
}

void AdvanceState_OnNewBar()
{
   g_last_signal = 0;
   g_bb_upper1   = 0.0;
   g_bb_lower1   = 0.0;
   g_bb_upper2   = 0.0;
   g_bb_lower2   = 0.0;
   g_bb_middle1  = 0.0;
   g_last_atr    = 0.0;
   g_last_close1 = 0.0;
   g_last_close2 = 0.0;

   const double close1 = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: closed-bar calculation
   const double close2 = iClose(_Symbol, strategy_signal_tf, 2); // perf-allowed: closed-bar calculation

   if(close1 <= 0.0 || close2 <= 0.0)
      return;

   g_bb_upper1   = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_sma_period, strategy_dev_multiplier, 1, PRICE_CLOSE);
   g_bb_lower1   = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_sma_period, strategy_dev_multiplier, 1, PRICE_CLOSE);
   g_bb_upper2   = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_sma_period, strategy_dev_multiplier, 2, PRICE_CLOSE);
   g_bb_lower2   = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_sma_period, strategy_dev_multiplier, 2, PRICE_CLOSE);
   g_bb_middle1  = QM_BB_Middle(_Symbol, strategy_signal_tf, strategy_sma_period, strategy_dev_multiplier, 1, PRICE_CLOSE);
   g_last_atr    = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period), 1);
   g_last_close1 = close1;
   g_last_close2 = close2;

   if(g_bb_upper1 > 0.0 && g_bb_lower1 > 0.0 && g_bb_upper2 > 0.0 && g_bb_lower2 > 0.0 && g_last_atr > 0.0)
   {
      // Long: Close[1] > UpperBand[1] && Close[2] <= UpperBand[2]
      if(close1 > g_bb_upper1 && close2 <= g_bb_upper2)
         g_last_signal = 1;
      // Short: Close[1] < LowerBand[1] && Close[2] >= LowerBand[2]
      else if(close1 < g_bb_lower1 && close2 >= g_bb_lower2)
         g_last_signal = -1;
   }
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(StrategyInRolloverWindow(TimeCurrent()))
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
   if(QM_TM_OpenPositionCount(magic) >= 1)
      return false;

   if(g_last_signal == 0 || g_last_atr <= 0.0)
      return false;

   const QM_OrderType side = (g_last_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl_dist = g_last_atr * strategy_atr_sl_mult;
   if(sl_dist <= 0.0)
      return false;

   double sl = 0.0;
   if(side == QM_BUY)
   {
      sl = QM_StopRulesNormalizePrice(_Symbol, entry - sl_dist);
   }
   else
   {
      sl = QM_StopRulesNormalizePrice(_Symbol, entry + sl_dist);
   }

   req.type = side;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "ABERRATION_LONG" : "ABERRATION_SHORT";

   return (req.sl > 0.0);
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

      // Midline trailing exit on closed bar:
      // Close long when Close[1] < SMA(30, D1)[1]
      // Close short when Close[1] > SMA(30, D1)[1]
      if(strategy_use_mid_exit && g_bb_middle1 > 0.0 && g_last_close1 > 0.0)
      {
         if(pos_type == POSITION_TYPE_BUY && g_last_close1 < g_bb_middle1)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
         }
         else if(pos_type == POSITION_TYPE_SELL && g_last_close1 > g_bb_middle1)
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

   if(!QM_FrameworkDeclareExecutionContract(strategy_signal_tf,
                                            QM_FRIDAY_CLOSE_CARD_RULE,
                                            "QM5_41001 Keith Fitschen Aberration Commodity Trend System D1"))
      return INIT_FAILED;

   const int entry_deviation_points = StrategyEntryDeviationPoints();
   if(entry_deviation_points <= 0)
      return INIT_FAILED;
   QM_EntryConfigure(qm_ea_id,
                     qm_news_mode_legacy,
                     entry_deviation_points,
                     qm_stress_reject_probability,
                     qm_news_temporal,
                     qm_news_compliance,
                     QM_FrameworkMagic());

   QM_KillSwitchInit(qm_ea_id, QM_FrameworkMagic(), strategy_daily_hard_stop_pct, strategy_total_dd_stop_pct, 1.0);

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
   if(Strategy_NewsFilterHook(broker_now))
      return;

   if(QM_FrameworkHandleFridayClose())
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

   if(Strategy_NoTradeFilter())
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

   AdvanceState_OnNewBar();
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
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
