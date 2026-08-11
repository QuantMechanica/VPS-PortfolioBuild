#property strict
#property version   "5.1"
#property description "QM5_11660 pp-wedge - PatternPy rolling wedge labels, H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11660 pp-wedge
// -----------------------------------------------------------------------------
// Approved card: docs/strategy_card.md
// Source: Keith Orange / keithorange, PatternPy,
//   tradingpatterns/tradingpatterns.py::detect_wedge
//
// Literal closed-bar translation of the cited detector. For the just-closed
// bar (shift 1), rolling values span shifts 1..window, source shift(1) is
// shift 2 here, and the rolling trend compares the newest value with the
// oldest value in that same window:
//
//   WEDGE UP   = rolling_high >= high[2]
//             && rolling_low  <= low[2]
//             && high[1] > high[window]
//             && low[1]  > low[window]
//
//   WEDGE DOWN = rolling_high <= high[2]
//             && rolling_low  >= low[2]
//             && high[1] < high[window]
//             && low[1]  < low[window]
//
// No pivot detector, convergence threshold, breakout confirmation, TP, or
// direction reversal is added. Long follows Wedge Up and short follows Wedge
// Down at the next H4 bar open. Positions close on the opposite label, a
// closed-bar breach of the immediately prior bar's extreme, or after 12 H4
// bars. ATR(14) at 2.0x is the card's V5 emergency stop. One position per
// magic; no grid, martingale, banned indicator, or ML mechanic.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 11660;
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
input int    strategy_window             = 3;    // source baseline; Q03: 3..8
input int    strategy_atr_period         = 14;   // card baseline; Q03: 14..30
input double strategy_sl_atr_mult        = 2.0;  // card baseline; Q03: 1.0..3.0
input int    strategy_max_hold_bars      = 12;   // card baseline; Q03: 6..30

// State is advanced only after QM_IsNewBar() accepts a completed H4 bar.
int    g_pattern_dir    = 0;   // +1 Wedge Up, -1 Wedge Down, 0 none
double g_signal_atr     = 0.0;
bool   g_exit_requested = false;

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
   return (qm_ea_id == 11660 &&
           expected_slot >= 0 &&
           qm_magic_slot_offset == expected_slot &&
           (ENUM_TIMEFRAMES)_Period == PERIOD_H4 &&
           strategy_window >= 3 && strategy_window <= 8 &&
           strategy_atr_period >= 14 && strategy_atr_period <= 30 &&
           strategy_sl_atr_mult >= 1.0 && strategy_sl_atr_mult <= 3.0 &&
           strategy_max_hold_bars >= 6 && strategy_max_hold_bars <= 30);
  }

// Translate PatternPy's mask and evaluate card exits once per completed bar.
// Every direct series read is a bounded structural exception and this helper
// is called only from a QM_IsNewBar()-gated path.
void Strategy_AdvanceClosedBarState()
  {
   g_pattern_dir = 0;
   g_signal_atr = 0.0;
   g_exit_requested = false;

   if(!Strategy_ConfigurationAuthorized())
      return;

   const int window = strategy_window;
   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: bounded source OHLC behind QM_IsNewBar().
   const double low1  = iLow(_Symbol, _Period, 1);  // perf-allowed: bounded source OHLC behind QM_IsNewBar().
   if(high1 <= 0.0 || low1 <= 0.0)
      return;

   double rolling_high = high1;
   double rolling_low = low1;
   for(int shift = 2; shift <= window; ++shift)
     {
      const double bar_high = iHigh(_Symbol, _Period, shift); // perf-allowed: bounded source OHLC behind QM_IsNewBar().
      const double bar_low  = iLow(_Symbol, _Period, shift);  // perf-allowed: bounded source OHLC behind QM_IsNewBar().
      if(bar_high <= 0.0 || bar_low <= 0.0)
         return;
      if(bar_high > rolling_high)
         rolling_high = bar_high;
      if(bar_low < rolling_low)
         rolling_low = bar_low;
     }

   const double prior_high = iHigh(_Symbol, _Period, 2);      // perf-allowed: PatternPy shift(1), closed-bar gated.
   const double prior_low  = iLow(_Symbol, _Period, 2);       // perf-allowed: PatternPy shift(1), closed-bar gated.
   const double oldest_high = iHigh(_Symbol, _Period, window); // perf-allowed: rolling trend first value, closed-bar gated.
   const double oldest_low  = iLow(_Symbol, _Period, window);  // perf-allowed: rolling trend first value, closed-bar gated.
   const double close1 = iClose(_Symbol, _Period, 1);         // perf-allowed: card exit close, closed-bar gated.
   if(prior_high <= 0.0 || prior_low <= 0.0 ||
      oldest_high <= 0.0 || oldest_low <= 0.0 || close1 <= 0.0)
      return;

   const int trend_high = (high1 > oldest_high ? +1 :
                           (high1 < oldest_high ? -1 : 0));
   const int trend_low = (low1 > oldest_low ? +1 :
                          (low1 < oldest_low ? -1 : 0));

   const bool wedge_up = (rolling_high >= prior_high &&
                          rolling_low <= prior_low &&
                          trend_high == +1 && trend_low == +1);
   const bool wedge_down = (rolling_high <= prior_high &&
                            rolling_low >= prior_low &&
                            trend_high == -1 && trend_low == -1);
   if(wedge_up)
      g_pattern_dir = +1;
   else if(wedge_down)
      g_pattern_dir = -1;

   g_signal_atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);

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
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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

   if((position_is_long && g_pattern_dir == -1) ||
      (!position_is_long && g_pattern_dir == +1))
      g_exit_requested = true;

   // Card wording is literal: compare this completed close with the prior
   // completed bar's low/high, not the entry bar's extreme.
   if(position_is_long && close1 < prior_low)
      g_exit_requested = true;
   if(!position_is_long && close1 > prior_high)
      g_exit_requested = true;

   const int entry_shift = iBarShift(_Symbol, _Period, entry_time, false); // perf-allowed: one bar-count lookup behind QM_IsNewBar().
   if(entry_shift >= strategy_max_hold_bars)
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
   // The skeleton calls this only after its closed-bar gate. When flat, this
   // is the single state-advance point for the new bar.
   Strategy_AdvanceClosedBarState();

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(g_pattern_dir == 0 || g_signal_atr <= 0.0)
      return false;

   const QM_OrderType side = (g_pattern_dir > 0 ? QM_BUY : QM_SELL);
   const double entry = (side == QM_BUY
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
   req.tp = 0.0;
   req.reason = (g_pattern_dir > 0 ? "patternpy_wedge_up"
                                    : "patternpy_wedge_down");
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Consume the framework bar gate only while a position is open. This keeps
   // structural and time exits available before the skeleton's entry-only
   // news gate, and deliberately prevents a same-bar reversal after closing.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return;
   if(!QM_IsNewBar())
      return;
   Strategy_AdvanceClosedBarState();
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
// Framework wiring - copied from framework/templates/EA_Skeleton.mq5
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
   if(Strategy_NewsFilterHook(broker_now))
      return;
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
