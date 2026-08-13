#property strict
#property version   "5.1"
#property description "QM5_11396 Connors Double 7 H4 structural pullback"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11396 connors-double7s-sma200-h4
// -----------------------------------------------------------------------------
// Source: Larry Connors and Cesar Alvarez, Short Term Trading Strategies That
//         Work (2009), Double 7's Strategy; OWNER-approved H4 FX adaptation.
// Card: D:/QM/strategy_farm/artifacts/cards_approved/
//       QM5_11396_connors-double7s-sma200-h4.md.
//
// Mechanical baseline, evaluated only after a completed H4 bar:
//   - Long when Close[1] is above SMA(200) and the lowest close in seven bars.
//   - Short when Close[1] is below SMA(200) and the highest close in seven bars.
//   - Exit a long on a seven-bar highest close; mirror for a short.
//   - Protect every entry with 2 x ATR(14), capped at 50 pips.
//
// This is a low-frequency structural price-extreme edge. It uses only the
// approved SMA trend regime, ATR risk distance, and bounded closed-bar OHLC;
// there is no ML, adaptive threshold, grid, martingale, or per-tick history scan.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 11396;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_sma_period            = 200;
input int    strategy_extreme_lookback      = 7;
input int    strategy_atr_period            = 14;
input double strategy_sl_atr_mult           = 2.0;
input int    strategy_sl_max_pips           = 50;
input int    strategy_spread_cap_pips       = 20;

bool g_exit_requested = false;

bool C7_InputsValid()
  {
   return (qm_ea_id == 11396 &&
           qm_magic_slot_offset >= 0 && qm_magic_slot_offset <= 3 &&
           strategy_sma_period >= 2 && strategy_sma_period <= 500 &&
           strategy_extreme_lookback >= 2 && strategy_extreme_lookback <= 50 &&
           strategy_atr_period >= 2 && strategy_atr_period <= 100 &&
           strategy_sl_atr_mult > 0.0 && strategy_sl_atr_mult <= 10.0 &&
           strategy_sl_max_pips > 0 &&
           strategy_spread_cap_pips > 0);
  }

// Return the last completed bar's position inside the configured close window.
// Both callers are behind the single framework QM_IsNewBar gate.
bool C7_ClosedBarExtremes(bool &out_is_lowest,
                          bool &out_is_highest,
                          double &out_close)
  {
   out_is_lowest = false;
   out_is_highest = false;
   out_close = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: one bounded structural close read behind the framework new-bar gate.
   if(out_close <= 0.0)
      return false;

   out_is_lowest = true;
   out_is_highest = true;
   for(int shift = 2; shift <= strategy_extreme_lookback; ++shift)
     {
      const double close_value = iClose(_Symbol, PERIOD_H4, shift); // perf-allowed: bounded seven-close structural scan behind the framework new-bar gate.
      if(close_value <= 0.0)
         return false;
      if(out_close > close_value)
         out_is_lowest = false;
      if(out_close < close_value)
         out_is_highest = false;
     }
   return true;
  }

void C7_RefreshExitRequestOnNewBar()
  {
   g_exit_requested = false;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return;

   bool is_long = false;
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) ==
                 POSITION_TYPE_BUY);
      found = true;
      break;
     }
   if(!found)
      return;

   bool is_lowest = false;
   bool is_highest = false;
   double close_value = 0.0;
   if(!C7_ClosedBarExtremes(is_lowest, is_highest, close_value))
      return;

   g_exit_requested = is_long ? is_highest : is_lowest;
  }

// Entry-only spread guard. A valid zero modeled spread on .DWX is allowed;
// missing or inverted quotes are blocked until a usable quote arrives.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return true;

   const double spread = ask - bid;
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                       strategy_spread_cap_pips);
   return (cap > 0.0 && spread > 0.0 && spread > cap);
  }

// Caller guarantees QM_IsNewBar() == true. The completed bar at shift 1 is
// therefore entered at the next H4 bar's first available market price.
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

   bool is_lowest = false;
   bool is_highest = false;
   double close_one = 0.0;
   if(!C7_ClosedBarExtremes(is_lowest, is_highest, close_one))
      return false;

   const double sma = QM_SMA(_Symbol,
                             PERIOD_H4,
                             strategy_sma_period,
                             1);
   const double atr = QM_ATR(_Symbol,
                             PERIOD_H4,
                             strategy_atr_period,
                             1);
   if(sma <= 0.0 || atr <= 0.0)
      return false;

   double stop_distance = atr * strategy_sl_atr_mult;
   const double stop_cap = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                            strategy_sl_max_pips);
   if(stop_cap > 0.0)
      stop_distance = MathMin(stop_distance, stop_cap);
   if(stop_distance <= 0.0)
      return false;

   if(close_one > sma && is_lowest)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = QM_StopRulesStopFromDistance(_Symbol,
                                             QM_BUY,
                                             ask,
                                             stop_distance);
      req.reason = "CONNORS_DOUBLE7_LONG";
      return (req.sl > 0.0 && req.sl < ask);
     }

   if(close_one < sma && is_highest)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = QM_StopRulesStopFromDistance(_Symbol,
                                             QM_SELL,
                                             bid,
                                             stop_distance);
      req.reason = "CONNORS_DOUBLE7_SHORT";
      return (req.sl > bid);
     }
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Fixed protective stop plus the structural seven-bar exit from the card.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      g_exit_requested = false;
  }

bool Strategy_ExitSignal()
  {
   return g_exit_requested;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(_Period != PERIOD_H4 || !C7_InputsValid())
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

   g_exit_requested = false;
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

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      C7_RefreshExitRequestOnNewBar();

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      bool matching_position = false;
      bool close_succeeded = false;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
            (int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         matching_position = true;
         if(QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
            close_succeeded = true;
        }
      if(close_succeeded || !matching_position)
         g_exit_requested = false;
      return; // never close and re-enter from the same completed-bar signal
     }

   if(!is_new_bar)
      return;

   QM_EquityStreamOnNewBar();

   // News and spread constraints gate entries only; structural exits, fixed
   // stops, MAE tracking, and Friday close remain active through those windows.
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
      news_allows = QM_NewsAllowsTrade(_Symbol,
                                       broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows || Strategy_NoTradeFilter())
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
