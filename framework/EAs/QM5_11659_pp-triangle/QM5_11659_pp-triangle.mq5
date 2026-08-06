#property strict
#property version   "5.1"
#property description "QM5_11659 pp-triangle - PatternPy rolling triangle labels, H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11659 pp-triangle
// -----------------------------------------------------------------------------
// Approved card: docs/strategy_card.md
// Source: Keith Orange / keithorange, PatternPy,
//   tradingpatterns/tradingpatterns.py::detect_triangle_pattern
// Exact source URL and durable approved card are preserved in docs/.
//
// Literal closed-bar translation of the cited detector. For the just-closed
// bar (shift 1), rolling values span shifts 1..window and the source's
// DataFrame.shift(1) comparison is shift 2 here:
//
//   ASCENDING  = rolling_high >= high[2]
//             && rolling_low  <= low[2]
//             && close[1] > close[2]
//   DESCENDING = rolling_high <= high[2]
//             && rolling_low  >= low[2]
//             && close[1] < close[2]
//
// The rolling window intentionally includes shift 2, exactly as the source
// implementation does. No trendline, breakout buffer, confirmation, TP, or
// other mechanic is added. Entries occur at the next H4 bar open. Positions
// close on the opposite label, a closed-bar breach of the actual entry bar's
// extreme, or the 12-bar baseline time stop. ATR(14) at 2.0x is the card's
// V5 emergency stop. One position per magic; no grid, martingale, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 11659;
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
input int    strategy_window             = 3;    // source baseline; P3: 3..20
input int    strategy_atr_period         = 14;   // card baseline; P3: 14..30
input double strategy_sl_atr_mult        = 2.0;  // card baseline; P3: 1.0..3.0
input int    strategy_max_hold_bars      = 12;   // card baseline; P3: 6..30

// Cached only after QM_IsNewBar() consumes a new H4 bar.
int    g_pattern_dir      = 0;     // +1 Ascending, -1 Descending, 0 none
double g_signal_atr       = 0.0;
bool   g_exit_requested   = false;

int Strategy_ExpectedSlot()
  {
   if(_Symbol == "EURUSD.DWX") return 0;
   if(_Symbol == "GBPUSD.DWX") return 1;
   if(_Symbol == "XAUUSD.DWX") return 2;
   if(_Symbol == "GDAXI.DWX")  return 3; // registry mapping for card GER40
   if(_Symbol == "NDX.DWX")    return 4;
   return -1;
  }

bool Strategy_ConfigurationAuthorized()
  {
   const int expected_slot = Strategy_ExpectedSlot();
   return (qm_ea_id == 11659 && expected_slot >= 0 &&
           qm_magic_slot_offset == expected_slot &&
           (ENUM_TIMEFRAMES)_Period == PERIOD_H4 &&
           strategy_window >= 3 && strategy_window <= 20 &&
           strategy_atr_period >= 14 && strategy_atr_period <= 30 &&
           strategy_sl_atr_mult >= 1.0 && strategy_sl_atr_mult <= 3.0 &&
           strategy_max_hold_bars >= 6 && strategy_max_hold_bars <= 30);
  }

// Compute the source mask and any closed-bar exit request once per H4 bar.
void AdvanceState_OnNewBar()
  {
   g_pattern_dir = 0;
   g_signal_atr = 0.0;
   g_exit_requested = false;

   if(!Strategy_ConfigurationAuthorized())
      return;

   const int window = strategy_window;
   double rolling_high = iHigh(_Symbol, _Period, 1); // perf-allowed: bounded card-authorized OHLC read behind QM_IsNewBar().
   double rolling_low  = iLow(_Symbol, _Period, 1);  // perf-allowed: bounded card-authorized OHLC read behind QM_IsNewBar().
   if(rolling_high <= 0.0 || rolling_low <= 0.0)
      return;

   for(int shift = 2; shift <= window; ++shift)
     {
      const double bar_high = iHigh(_Symbol, _Period, shift); // perf-allowed: bounded card-authorized OHLC read behind QM_IsNewBar().
      const double bar_low  = iLow(_Symbol, _Period, shift);  // perf-allowed: bounded card-authorized OHLC read behind QM_IsNewBar().
      if(bar_high <= 0.0 || bar_low <= 0.0)
         return;
      if(bar_high > rolling_high) rolling_high = bar_high;
      if(bar_low  < rolling_low)  rolling_low  = bar_low;
     }

   const double prior_high = iHigh(_Symbol, _Period, 2);  // perf-allowed: source shift(1), closed-bar gate.
   const double prior_low  = iLow(_Symbol, _Period, 2);   // perf-allowed: source shift(1), closed-bar gate.
   const double close1     = iClose(_Symbol, _Period, 1); // perf-allowed: source close, closed-bar gate.
   const double close2     = iClose(_Symbol, _Period, 2); // perf-allowed: source shift(1), closed-bar gate.
   if(prior_high <= 0.0 || prior_low <= 0.0 || close1 <= 0.0 || close2 <= 0.0)
      return;

   g_signal_atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);

   const bool ascending = (rolling_high >= prior_high &&
                           rolling_low <= prior_low &&
                           close1 > close2);
   const bool descending = (rolling_high <= prior_high &&
                            rolling_low >= prior_low &&
                            close1 < close2);
   if(ascending)
      g_pattern_dir = +1;
   else if(descending)
      g_pattern_dir = -1;

   const int magic = QM_FrameworkMagic();
   int matching_positions = 0;
   bool position_is_long = false;
   datetime entry_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ++matching_positions;
      position_is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      entry_time = (datetime)PositionGetInteger(POSITION_TIME);
     }

   if(matching_positions <= 0)
      return;
   if(matching_positions != 1 || entry_time <= 0)
     {
      g_exit_requested = true;
      return;
     }

   // The opposite PatternPy label is an immediate card-authorized exit.
   if((position_is_long && g_pattern_dir == -1) ||
      (!position_is_long && g_pattern_dir == +1))
      g_exit_requested = true;

   // Recover the actual execution bar deterministically from position time.
   // At the first bar after entry it is shift 1 and therefore fully closed.
   const int entry_shift = iBarShift(_Symbol, _Period, entry_time, false); // perf-allowed: one position-time lookup behind QM_IsNewBar().
   if(entry_shift < 1)
      return;

   if(entry_shift >= strategy_max_hold_bars)
      g_exit_requested = true;

   const double entry_bar_low  = iLow(_Symbol, _Period, entry_shift);  // perf-allowed: one entry-bar structural read behind QM_IsNewBar().
   const double entry_bar_high = iHigh(_Symbol, _Period, entry_shift); // perf-allowed: one entry-bar structural read behind QM_IsNewBar().
   if(position_is_long && entry_bar_low > 0.0 && close1 < entry_bar_low)
      g_exit_requested = true;
   if(!position_is_long && entry_bar_high > 0.0 && close1 > entry_bar_high)
      g_exit_requested = true;
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
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(g_pattern_dir == 0 || g_signal_atr <= 0.0)
      return false;

   const QM_OrderType side = (g_pattern_dir > 0 ? QM_BUY : QM_SELL);
   const double entry = (g_pattern_dir > 0
                         ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                         : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol,
                                         side,
                                         entry,
                                         g_signal_atr,
                                         strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0; // card authorizes no TP; exits are structural/time + hard SL
   req.reason = (g_pattern_dir > 0 ? "patternpy_triangle_ascending"
                                    : "patternpy_triangle_descending");
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No trailing stop, break-even, partial close, or stop mutation.
  }

bool Strategy_ExitSignal()
  {
   return (g_exit_requested &&
           QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
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
   // Sample MAE before any guard can return.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Consume the closed-bar gate exactly once. State must advance before the
   // management/exit hooks so opposite labels and bar-count exits are timely.
   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      AdvanceState_OnNewBar();

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      bool close_succeeded = false;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
            close_succeeded = true;
        }
      if(close_succeeded)
         g_exit_requested = false;
     }

   // Both custom and central news gates suppress entries only. Management and
   // exits above remain available throughout a news window.
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
