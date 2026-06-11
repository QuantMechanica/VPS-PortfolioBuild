#property strict
#property version   "5.0"
#property description "QM5_9637 — Williams OCR Reversal H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9637 — Williams OCR Reversal H4
// Source: Larry Williams OCR ForexFactory cluster
//         (6e967762-b26d-59a3-b076-35c17f2e7c36)
// Logic: H4 bars with a large body relative to ATR (OCR >= 0.85 × ATR14) that
// then fail to continue beyond their high/low before closing back inside the
// open provide a counter-trend entry in the opposite direction.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9637;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period          = 14;   // ATR lookback for OCR sizing and stops
input double strategy_ocr_min_ratio       = 0.85; // min |close-open| / ATR14 for a valid setup bar
input double strategy_pierce_atr_mult     = 0.05; // ATR buffer beyond extreme for false-continuation pierce
input double strategy_range_filter_mult   = 3.0;  // setup bars with range > N×ATR are skipped
input double strategy_sl_atr_mult         = 0.20; // ATR buffer beyond running extreme for stop-loss
input double strategy_tp_rr               = 1.6;  // take-profit as multiple of initial risk
input int    strategy_time_stop_bars      = 10;   // maximum H4 bars to hold before closing
input int    strategy_atr_median_period   = 100;  // lookback for ATR median volatility filter

// ---------------------------------------------------------------------------
// Watch-state machine (OCR setup → false-continuation trigger)
// ---------------------------------------------------------------------------
// g_watch_state: 0=idle, 1=bull_setup watching for short, -1=bear_setup watching for long
int    g_watch_state       = 0;
int    g_bars_watched      = 0;
double g_setup_high        = 0.0;  // High of setup bar (OCR exit reference for shorts)
double g_setup_low         = 0.0;  // Low  of setup bar (OCR exit reference for longs)
double g_setup_open        = 0.0;  // Open of setup bar (close-back confirmation threshold)
double g_setup_atr_val     = 0.0;  // ATR at setup bar (pierce threshold base)
double g_running_h_extreme = 0.0;  // running max High since setup bar (SL base for shorts)
double g_running_l_extreme = 0.0;  // running min Low  since setup bar (SL base for longs)
bool   g_pierced           = false; // true once false-continuation pierce has occurred
int    g_pierce_bar_idx    = 0;     // g_bars_watched value when pierce was first detected

// ---------------------------------------------------------------------------
// Open-position exit tracking
// ---------------------------------------------------------------------------
double g_ocr_exit_level  = 0.0;  // close beyond this level triggers immediate exit
int    g_entry_bar_count = 0;    // iBars() snapshot at entry time (for time stop)

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void ResetWatchState()
  {
   g_watch_state       = 0;
   g_bars_watched      = 0;
   g_setup_high        = 0.0;
   g_setup_low         = 0.0;
   g_setup_open        = 0.0;
   g_setup_atr_val     = 0.0;
   g_running_h_extreme = 0.0;
   g_running_l_extreme = 0.0;
   g_pierced           = false;
   g_pierce_bar_idx    = 0;
  }

// Compute median of the last median_period ATR(atr_period) values.
// Called once per new H4 bar inside the QM_IsNewBar gate — O(median_period) indicator reads.
double CalcATRMedian(const string sym, const ENUM_TIMEFRAMES tf,
                     const int atr_period, const int median_period)
  {
   double vals[];
   ArrayResize(vals, median_period);
   for(int i = 0; i < median_period; i++)
      vals[i] = QM_ATR(sym, tf, atr_period, i + 1);
   ArraySort(vals);
   if(median_period % 2 == 0)
      return (vals[median_period / 2 - 1] + vals[median_period / 2]) / 2.0;
   return vals[median_period / 2];
  }

// ---------------------------------------------------------------------------
// Strategy hooks
// ---------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Skip if a position is already open for this magic on this symbol.
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
        { ResetWatchState(); return false; }
     }

   // Read the last completed H4 bar (shift=1).
   // iOpen/iHigh/iLow: perf-allowed — structural OHLC required for OCR body/range/extreme logic.
   const double open1  = iOpen (_Symbol, PERIOD_H4, 1);
   const double high1  = iHigh (_Symbol, PERIOD_H4, 1);
   const double low1   = iLow  (_Symbol, PERIOD_H4, 1);
   const double close1 = QM_SMA(_Symbol, PERIOD_H4, 1, 1);  // SMA(1,shift=1) = close[1]
   const double atr1   = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);

   if(atr1 <= 0.0 || open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   // --------------------------------------------------------------------------
   // Advance watch-state machine on the current closed bar.
   // --------------------------------------------------------------------------
   if(g_watch_state != 0)
     {
      g_bars_watched++;
      g_running_h_extreme = MathMax(g_running_h_extreme, high1);
      g_running_l_extreme = MathMin(g_running_l_extreme, low1);

      // ---- Bull OCR setup → watching for SHORT entry ----
      if(g_watch_state == 1)
        {
         const double pierce_thresh = g_setup_high + strategy_pierce_atr_mult * g_setup_atr_val;

         if(!g_pierced)
           {
            if(high1 > pierce_thresh)
              {
               g_pierced        = true;
               g_pierce_bar_idx = g_bars_watched;

               if(close1 < g_setup_open)
                 {
                  // Pierce and close-back on the same bar → enter SHORT
                  const double sl_level = g_running_h_extreme + strategy_sl_atr_mult * atr1;
                  const double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  if(sl_level <= bid) { ResetWatchState(); return false; }

                  req.type   = QM_SELL;
                  req.price  = bid;
                  req.sl     = sl_level;
                  req.tp     = bid - strategy_tp_rr * (sl_level - bid);
                  req.reason = "OCR_SHORT";

                  g_ocr_exit_level  = g_setup_high;
                  g_entry_bar_count = iBars(_Symbol, PERIOD_H4);  // perf-allowed: time-stop bar reference
                  ResetWatchState();
                  return true;
                 }
               // Pierce but no close-back yet; wait for the following bar.
              }
            else if(g_bars_watched >= 2)
              {
               ResetWatchState();  // 2 bars elapsed without pierce → setup expired
              }
           }
         else  // pierced; waiting for following-bar close-back confirmation
           {
            if(g_bars_watched == g_pierce_bar_idx + 1)
              {
               if(close1 < g_setup_open)
                 {
                  // Following bar confirmed close-back → enter SHORT
                  const double sl_level = g_running_h_extreme + strategy_sl_atr_mult * atr1;
                  const double bid      = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  if(sl_level <= bid) { ResetWatchState(); return false; }

                  req.type   = QM_SELL;
                  req.price  = bid;
                  req.sl     = sl_level;
                  req.tp     = bid - strategy_tp_rr * (sl_level - bid);
                  req.reason = "OCR_SHORT";

                  g_ocr_exit_level  = g_setup_high;
                  g_entry_bar_count = iBars(_Symbol, PERIOD_H4);  // perf-allowed
                  ResetWatchState();
                  return true;
                 }
               ResetWatchState();  // following bar did not close back → no trade
              }
            else if(g_bars_watched > g_pierce_bar_idx + 1)
              {
               ResetWatchState();
              }
           }
        }

      // ---- Bear OCR setup → watching for LONG entry ----
      else if(g_watch_state == -1)
        {
         const double pierce_thresh = g_setup_low - strategy_pierce_atr_mult * g_setup_atr_val;

         if(!g_pierced)
           {
            if(low1 < pierce_thresh)
              {
               g_pierced        = true;
               g_pierce_bar_idx = g_bars_watched;

               if(close1 > g_setup_open)
                 {
                  // Pierce and close-back on the same bar → enter LONG
                  const double sl_level = g_running_l_extreme - strategy_sl_atr_mult * atr1;
                  const double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  if(sl_level >= ask) { ResetWatchState(); return false; }

                  req.type   = QM_BUY;
                  req.price  = ask;
                  req.sl     = sl_level;
                  req.tp     = ask + strategy_tp_rr * (ask - sl_level);
                  req.reason = "OCR_LONG";

                  g_ocr_exit_level  = g_setup_low;
                  g_entry_bar_count = iBars(_Symbol, PERIOD_H4);  // perf-allowed
                  ResetWatchState();
                  return true;
                 }
              }
            else if(g_bars_watched >= 2)
              {
               ResetWatchState();
              }
           }
         else  // pierced; waiting for following-bar close-back confirmation
           {
            if(g_bars_watched == g_pierce_bar_idx + 1)
              {
               if(close1 > g_setup_open)
                 {
                  // Following bar confirmed close-back → enter LONG
                  const double sl_level = g_running_l_extreme - strategy_sl_atr_mult * atr1;
                  const double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  if(sl_level >= ask) { ResetWatchState(); return false; }

                  req.type   = QM_BUY;
                  req.price  = ask;
                  req.sl     = sl_level;
                  req.tp     = ask + strategy_tp_rr * (ask - sl_level);
                  req.reason = "OCR_LONG";

                  g_ocr_exit_level  = g_setup_low;
                  g_entry_bar_count = iBars(_Symbol, PERIOD_H4);  // perf-allowed
                  ResetWatchState();
                  return true;
                 }
               ResetWatchState();
              }
            else if(g_bars_watched > g_pierce_bar_idx + 1)
              {
               ResetWatchState();
              }
           }
        }

      return false;  // still in watch window, no signal this bar
     }

   // --------------------------------------------------------------------------
   // Idle: check if the just-closed bar qualifies as an OCR setup.
   // --------------------------------------------------------------------------
   const double body  = MathAbs(close1 - open1);
   const double range = high1 - low1;

   if(range > strategy_range_filter_mult * atr1) return false;   // wide-range filter
   if(body / atr1 < strategy_ocr_min_ratio)       return false;   // OCR body-size filter

   // ATR median filter: only accept setups when current ATR is above its 100-bar median.
   const double atr_median = CalcATRMedian(_Symbol, PERIOD_H4, strategy_atr_period,
                                            strategy_atr_median_period);
   if(atr1 < atr_median) return false;

   if(close1 > open1)  // bull OCR → watch for failed upside continuation → SHORT
     {
      g_watch_state       =  1;
      g_bars_watched      =  0;
      g_setup_high        = high1;
      g_setup_low         = low1;
      g_setup_open        = open1;
      g_setup_atr_val     = atr1;
      g_running_h_extreme = high1;
      g_running_l_extreme = low1;
      g_pierced           = false;
      g_pierce_bar_idx    = 0;
     }
   else if(close1 < open1)  // bear OCR → watch for failed downside continuation → LONG
     {
      g_watch_state       = -1;
      g_bars_watched      =  0;
      g_setup_high        = high1;
      g_setup_low         = low1;
      g_setup_open        = open1;
      g_setup_atr_val     = atr1;
      g_running_h_extreme = high1;
      g_running_l_extreme = low1;
      g_pierced           = false;
      g_pierce_bar_idx    = 0;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // No intra-trade management; SL and TP are fixed at entry.
   // Exit conditions handled in Strategy_ExitSignal.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   bool has_position = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
         pos_type     = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         has_position = true;
         break;
        }
     }

   if(!has_position)
     {
      g_entry_bar_count = 0;
      g_ocr_exit_level  = 0.0;
      return false;
     }

   // Time stop: close after strategy_time_stop_bars H4 bars have formed since entry.
   if(g_entry_bar_count > 0)
     {
      const int bars_elapsed = iBars(_Symbol, PERIOD_H4) - g_entry_bar_count;  // perf-allowed
      if(bars_elapsed >= strategy_time_stop_bars) return true;
     }

   // Exit if last closed bar's close moves back beyond the original OCR extreme.
   if(g_ocr_exit_level > 0.0)
     {
      const double close1 = QM_SMA(_Symbol, PERIOD_H4, 1, 1);  // close[1] via SMA(1,shift=1)
      if(pos_type == POSITION_TYPE_SELL && close1 > g_ocr_exit_level) return true;
      if(pos_type == POSITION_TYPE_BUY  && close1 < g_ocr_exit_level) return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;  // defer to QM_NewsAllowsTrade2 in the framework
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9637_williams-ocr-reversal-h4\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
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

   if(!QM_IsNewBar())
      return;

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
