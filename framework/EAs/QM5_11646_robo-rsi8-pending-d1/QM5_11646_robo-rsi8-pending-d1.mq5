#property strict
#property version   "5.1"
#property description "QM5_11646 robo-rsi8-pending-d1 - D1 RSI momentum with one-bar pending stops"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11646 robo-rsi8-pending-d1
// -----------------------------------------------------------------------------
// Approved card: docs/strategy_card.md
// Source: RoboForex Educational Team, Forex Strategy Collection (~2015),
//         "RSI Pending", page 115.
//
// On the first tick of each D1 bar, RSI(8) from the completed bar supplies the
// setup state. RSI > 70 places a buy stop 20 pips above the new D1 open; RSI <
// 30 places a sell stop 20 pips below it. The breakout fill is the entry event.
// An unfilled order expires at the current D1 close. Stops and targets are 2x
// and 4x completed-bar ATR(14), respectively, measured from the pending fill.
// One position and one pending order per magic; no grid, martingale, adaptive
// parameter, discretionary stop mutation, or ML.
//
// The card explicitly permits live bar-0 RSI or confirmed bar-1 RSI. This build
// chooses bar 1 so every decision is reproducible from completed D1 data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 11646;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_rsi_period           = 8;
input double strategy_rsi_buy_level        = 70.0;
input double strategy_rsi_sell_level       = 30.0;
input int    strategy_breakout_offset_pips = 20;
input int    strategy_atr_period           = 14;
input double strategy_sl_atr_mult          = 2.0;
input double strategy_tp_atr_mult          = 4.0;

// Cached only after QM_IsNewBar() consumes a new D1 bar.
int    g_signal_direction  = 0; // +1 buy stop, -1 sell stop, 0 none
double g_signal_atr        = 0.0;
double g_signal_bar_open   = 0.0;
int    g_expiration_seconds = 0;

int Strategy_ExpectedSlot()
  {
   if(_Symbol == "EURUSD.DWX") return 0;
   if(_Symbol == "GBPUSD.DWX") return 1;
   if(_Symbol == "AUDUSD.DWX") return 2;
   if(_Symbol == "USDJPY.DWX") return 3;
   if(_Symbol == "USDCAD.DWX") return 4;
   return -1;
  }

// The approved card specifies fixed strategy parameters and no P3 range.
// Fail closed on any unapproved symbol, slot, timeframe, or mechanic change.
bool Strategy_ConfigurationAuthorized()
  {
   const int expected_slot = Strategy_ExpectedSlot();
   return (qm_ea_id == 11646 &&
           expected_slot >= 0 &&
           qm_magic_slot_offset == expected_slot &&
           (ENUM_TIMEFRAMES)_Period == PERIOD_D1 &&
           strategy_rsi_period == 8 &&
           strategy_rsi_buy_level == 70.0 &&
           strategy_rsi_sell_level == 30.0 &&
           strategy_breakout_offset_pips == 20 &&
           strategy_atr_period == 14 &&
           strategy_sl_atr_mult == 2.0 &&
           strategy_tp_atr_mult == 4.0);
  }

int Strategy_PendingCount(const int magic)
  {
   int count = 0;
   for(int i = 0; i < OrdersTotal(); ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      ++count;
     }
   return count;
  }

// Remove any live order owned by this EA instance. Under this card the only
// possible order is its single pending stop; this also recovers stale state.
void Strategy_RemovePendings(const int magic, const string reason)
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

int Strategy_SecondsToBarClose()
  {
   const datetime bar_open_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: one current-bar read behind QM_IsNewBar().
   if(bar_open_time <= 0)
      return 0;
   const datetime bar_close_time = bar_open_time + PeriodSeconds(PERIOD_D1);
   const int remaining = (int)(bar_close_time - TimeCurrent());
   return (remaining > 0 ? remaining : 0);
  }

// Cancel the preceding bar's order and compute this bar's source-authorized
// setup exactly once. News gates later suppress only the new order placement.
void AdvanceState_OnNewBar()
  {
   g_signal_direction = 0;
   g_signal_atr = 0.0;
   g_signal_bar_open = 0.0;
   g_expiration_seconds = 0;

   if(!Strategy_ConfigurationAuthorized())
      return;

   const int magic = QM_FrameworkMagic();
   Strategy_RemovePendings(magic, "d1_pending_expired");
   if(QM_TM_OpenPositionCount(magic) > 0)
      return;

   // Card ambiguity resolved to the confirmed completed D1 bar (shift 1).
   const double rsi1 = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1);
   if(rsi1 > strategy_rsi_buy_level)
      g_signal_direction = +1;
   else if(rsi1 > 0.0 && rsi1 < strategy_rsi_sell_level)
      g_signal_direction = -1;
   else
      return;

   g_signal_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   g_signal_bar_open = iOpen(_Symbol, PERIOD_D1, 0); // perf-allowed: one current-open read behind QM_IsNewBar().
   g_expiration_seconds = Strategy_SecondsToBarClose();
   if(g_signal_atr <= 0.0 ||
      g_signal_bar_open <= 0.0 ||
      g_expiration_seconds <= 0)
     {
      g_signal_direction = 0;
      g_signal_atr = 0.0;
      g_signal_bar_open = 0.0;
      g_expiration_seconds = 0;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return !Strategy_ConfigurationAuthorized();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0 || Strategy_PendingCount(magic) > 0)
      return false;
   if(g_signal_direction == 0 ||
      g_signal_atr <= 0.0 ||
      g_signal_bar_open <= 0.0 ||
      g_expiration_seconds <= 0)
      return false;

   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                          strategy_breakout_offset_pips);
   if(offset <= 0.0)
      return false;

   const QM_OrderType side = (g_signal_direction > 0 ? QM_BUY_STOP : QM_SELL_STOP);
   const double raw_pending = (g_signal_direction > 0
                               ? g_signal_bar_open + offset
                               : g_signal_bar_open - offset);
   const double pending_price = QM_TM_NormalizePrice(_Symbol, raw_pending);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(pending_price <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   // If the breakout occurred before the first executable tick, the source's
   // pending entry no longer exists; do not convert it into a market order.
   if((g_signal_direction > 0 && pending_price <= ask) ||
      (g_signal_direction < 0 && pending_price >= bid))
      return false;

   const double sl = QM_StopATRFromValue(_Symbol,
                                         side,
                                         pending_price,
                                         g_signal_atr,
                                         strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol,
                                         side,
                                         pending_price,
                                         g_signal_atr,
                                         strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;
   if((g_signal_direction > 0 && (sl >= pending_price || tp <= pending_price)) ||
      (g_signal_direction < 0 && (sl <= pending_price || tp >= pending_price)))
      return false;

   req.type = side;
   req.price = pending_price;
   req.sl = sl;
   req.tp = tp;
   req.reason = (g_signal_direction > 0
                 ? "robo_rsi8_d1_buy_stop"
                 : "robo_rsi8_d1_sell_stop");
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = g_expiration_seconds;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // The card authorizes only the fixed broker-side SL and TP.
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
   // Q08 floating-P&L evidence must be sampled before any guard can return.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // State maintenance is allowed through news windows. Only a new order is
   // gated by news below.
   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      AdvanceState_OnNewBar();

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Custom and central news checks gate entries only; management and exits
   // above remain available throughout news windows.
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!is_new_bar)
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
