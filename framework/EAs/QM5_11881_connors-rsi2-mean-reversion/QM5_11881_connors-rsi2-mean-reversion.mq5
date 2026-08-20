#property strict
#property version   "5.0"
#property description "QM5_11881 Connors RSI(2) mean reversion on D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_11881 - Connors RSI(2) Mean Reversion
// -----------------------------------------------------------------------------
// Card-exact D1 baseline:
//   LONG  close[1] > SMA(200)[1], close[1] < close[2], RSI(2)[1] < 10
//   SHORT close[1] < SMA(200)[1], close[1] > close[2], RSI(2)[1] > 90
//   EXIT  long RSI(2)[1] > 65, short RSI(2)[1] < 35, or 10 held D1 bars
//   RISK  frozen 2.0 * ATR(14) hard stop, no fixed take-profit
//
// Signals use only completed D1 bars and are advanced once per framework
// new-bar edge. The level rules are literal: no extra crossover, stop-cap,
// trend-break, spread, session, or discretionary filters are added.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 11881;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                   = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact             = "high";
input QM_NewsMode qm_news_mode_legacy       = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled        = true;
input int    qm_friday_close_hour_broker    = 21;

input group "Stress"
input double qm_stress_reject_probability   = 0.0;

input group "Strategy"
input int    strategy_rsi_period             = 2;
input double strategy_rsi_long_entry         = 10.0;
input double strategy_rsi_short_entry        = 90.0;
input double strategy_rsi_exit_long          = 65.0;
input double strategy_rsi_exit_short         = 35.0;
input int    strategy_sma_period             = 200;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 2.0;
input int    strategy_max_holding_bars       = 10;

bool          g_bar_state_valid = false;
double        g_close_1         = 0.0;
double        g_close_2         = 0.0;
double        g_sma_1           = 0.0;
double        g_rsi_1           = 0.0;
double        g_atr_1           = 0.0;
bool          g_exit_due        = false;
QM_ExitReason g_exit_reason     = QM_EXIT_STRATEGY;

// -----------------------------------------------------------------------------
// Deterministic host and state helpers.
// -----------------------------------------------------------------------------

string Strategy_ExpectedSymbolForSlot(const int slot)
  {
   switch(slot)
     {
      case 0:  return "EURUSD.DWX";
      case 1:  return "GBPUSD.DWX";
      case 2:  return "USDJPY.DWX";
      case 3:  return "USDCAD.DWX";
      case 4:  return "USDCHF.DWX";
      case 5:  return "AUDUSD.DWX";
      case 6:  return "NZDUSD.DWX";
      case 7:  return "EURJPY.DWX";
      case 8:  return "GBPJPY.DWX";
      case 9:  return "NDX.DWX";
      case 10: return "WS30.DWX";
      case 11: return "SP500.DWX";
      default: return "";
     }
  }

bool Strategy_IsHostChart()
  {
   const string expected =
      Strategy_ExpectedSymbolForSlot(qm_magic_slot_offset);
   return (qm_ea_id == 11881 &&
           expected != "" &&
           _Symbol == expected &&
           _Period == PERIOD_D1);
  }

void Strategy_ResetBarState()
  {
   g_bar_state_valid = false;
   g_close_1 = 0.0;
   g_close_2 = 0.0;
   g_sma_1 = 0.0;
   g_rsi_1 = 0.0;
   g_atr_1 = 0.0;
  }

void Strategy_AdvanceBarState()
  {
   Strategy_ResetBarState();

   MqlRates last_closed;
   MqlRates prior_closed;
   ZeroMemory(last_closed);
   ZeroMemory(prior_closed);
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, last_closed) ||
      !QM_ReadBar(_Symbol, PERIOD_D1, 2, prior_closed))
      return;

   const double sma_value =
      QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1);
   const double rsi_value =
      QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1);
   const double atr_value =
      QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   if(last_closed.close <= 0.0 ||
      prior_closed.close <= 0.0 ||
      sma_value <= 0.0 ||
      atr_value <= 0.0 ||
      rsi_value < 0.0 ||
      rsi_value > 100.0 ||
      !MathIsValidNumber(last_closed.close) ||
      !MathIsValidNumber(prior_closed.close) ||
      !MathIsValidNumber(sma_value) ||
      !MathIsValidNumber(rsi_value) ||
      !MathIsValidNumber(atr_value))
      return;

   g_close_1 = last_closed.close;
   g_close_2 = prior_closed.close;
   g_sma_1 = sma_value;
   g_rsi_1 = rsi_value;
   g_atr_1 = atr_value;
   g_bar_state_valid = true;
  }

int Strategy_OpenPositionDirection()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY)
         return 1;
      if(position_type == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

void Strategy_EvaluateExitOnNewBar()
  {
   const int direction = Strategy_OpenPositionDirection();
   if(direction == 0)
     {
      g_exit_due = false;
      g_exit_reason = QM_EXIT_STRATEGY;
      return;
     }

   // Preserve a due exit until the position is actually flat so a transient
   // broker rejection is retried on later ticks.
   if(g_exit_due)
      return;

   const int held_bars =
      QM_TM_HeldPeriodsForMagic(QM_FrameworkMagic(),
                                _Symbol,
                                PERIOD_D1);
   if(strategy_max_holding_bars > 0 &&
      held_bars >= strategy_max_holding_bars)
     {
      g_exit_due = true;
      g_exit_reason = QM_EXIT_TIME_STOP;
      return;
     }

   if(!g_bar_state_valid)
      return;

   if((direction > 0 && g_rsi_1 > strategy_rsi_exit_long) ||
      (direction < 0 && g_rsi_1 < strategy_rsi_exit_short))
     {
      g_exit_due = true;
      g_exit_reason = QM_EXIT_STRATEGY;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return !Strategy_IsHostChart();
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

   if(!g_bar_state_valid ||
      QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   QM_OrderType side = QM_BUY;
   string reason = "";

   if(g_close_1 > g_sma_1 &&
      g_close_1 < g_close_2 &&
      g_rsi_1 < strategy_rsi_long_entry)
     {
      side = QM_BUY;
      reason = "CONNORS_RSI2_LONG";
     }
   else if(g_close_1 < g_sma_1 &&
           g_close_1 > g_close_2 &&
           g_rsi_1 > strategy_rsi_short_entry)
     {
      side = QM_SELL;
      reason = "CONNORS_RSI2_SHORT";
     }
   else
      return false;

   const double entry_price = QM_EntryMarketPrice(side);
   if(entry_price <= 0.0 || !MathIsValidNumber(entry_price))
      return false;

   double stop_price =
      QM_StopATRFromValue(_Symbol,
                          side,
                          entry_price,
                          g_atr_1,
                          strategy_atr_sl_mult);
   stop_price = QM_StopRulesNormalizePrice(_Symbol, stop_price);
   if(stop_price <= 0.0 || !MathIsValidNumber(stop_price))
      return false;
   if((side == QM_BUY && stop_price >= entry_price) ||
      (side == QM_SELL && stop_price <= entry_price))
      return false;

   req.type = side;
   req.sl = stop_price;
   req.reason = reason;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // The card authorizes only the frozen broker-side ATR stop.
  }

bool Strategy_ExitSignal()
  {
   if(Strategy_OpenPositionDirection() == 0)
     {
      g_exit_due = false;
      g_exit_reason = QM_EXIT_STRATEGY;
      return false;
     }
   return g_exit_due;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!Strategy_IsHostChart())
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

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               "{\"ea\":\"QM5_11881_connors-rsi2-mean-reversion\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO,
               "DEINIT",
               StringFormat("{\"reason\":%d}", reason));
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

   // Consume the D1 edge once. All indicator and bar reads are confined to
   // this branch; per-tick management below reads only cached state.
   const bool new_bar = QM_IsNewBar(_Symbol, PERIOD_D1);
   if(new_bar)
     {
      Strategy_AdvanceBarState();
      Strategy_EvaluateExitOnNewBar();
      QM_EquityStreamOnNewBar();
     }

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int index = PositionsTotal() - 1; index >= 0; --index)
        {
         const ulong ticket = PositionGetTicket(index);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
            (int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, g_exit_reason);
        }
      return;
     }

   // News gates entries only. Position management and exits above continue
   // through blackout windows.
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows =
         QM_NewsAllowsTrade2(_Symbol,
                             broker_now,
                             qm_news_temporal,
                             qm_news_compliance);
   else
      news_allows =
         QM_NewsAllowsTrade(_Symbol,
                            broker_now,
                            qm_news_mode_legacy);
   if(!news_allows || !new_bar)
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
