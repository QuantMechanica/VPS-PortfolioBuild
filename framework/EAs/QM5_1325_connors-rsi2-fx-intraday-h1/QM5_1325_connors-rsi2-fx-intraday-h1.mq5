#property strict
#property version   "5.0"
#property description "QM5_1325 Connors RSI-2 ForexFactory intraday FX port (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1325 Connors RSI-2 intraday FX port (H1)
// -----------------------------------------------------------------------------
// FF community intraday-H1 port of the Larry Connors / Cesar Alvarez RSI(2)
// short-term mean-reversion rule. Symmetric BUY+SELL from inception (FX has no
// long-bias). Entry trigger = RSI(2) crossing into the oversold/overbought zone
// on the closed bar, gated by SMA(200) macro bias and SMA(50) intermediate
// trend. Exit = RSI recovery (primary), SMA(5) cross after >=2 bars (fast
// confirm), hard 2xATR SL, 24-bar time-stop, 48-bar hard force-close.
//
// .DWX invariants honoured:
//   - ONE entry EVENT per closed bar (RSI cross-in); SMA filters are STATES.
//   - Spread guard fails OPEN; only blocks a genuinely wide spread (never 0).
//   - QM_IsNewBar() consumed exactly ONCE per OnTick (framework wiring below).
//   - No swap gate. No raw iRSI/iMA/iATR — QM_* readers only.
//   - Hard SL set as a PRICE at entry via QM_StopATR (pip-scale correct).
//   - Re-arm + hold-bar state advanced ONCE per new closed bar (cached).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1325;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_rsi_period        = 2;       // Connors RSI(2); P3-sweep 2-4
input double strategy_rsi_oversold      = 10.0;    // BUY trigger; P3-sweep 5-15
input double strategy_rsi_overbought    = 90.0;    // SELL trigger; P3-sweep 85-95
input double strategy_rsi_exit_buy      = 70.0;    // BUY recovery exit; P3-sweep 60-80
input double strategy_rsi_exit_sell     = 30.0;    // SELL recovery exit; P3-sweep 20-40
input double strategy_rsi_rearm_level   = 50.0;    // re-arm midline cross
input int    strategy_sma_macro         = 200;     // macro bias filter
input int    strategy_sma_inter         = 50;      // intermediate trend filter
input bool   strategy_use_inter_filter  = true;    // P3 can disable SMA(50) gate
input int    strategy_sma_fast          = 5;       // SMA-5 fast-recovery exit
input int    strategy_sma_fast_min_bars = 2;       // bars held before SMA-5 exit arms
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;     // hard SL distance; P3-sweep 1.5-3.0
input int    strategy_time_stop_bars    = 24;      // soft time-stop (1 trading day)
input int    strategy_hard_close_bars   = 48;      // hard force-close ceiling
input int    strategy_spread_median_bars = 20;     // median-spread lookback
input double strategy_spread_median_mult = 1.5;    // wide-spread multiple

// -----------------------------------------------------------------------------
// File-scope cached state — advanced ONCE per closed bar (no second timestamp
// gate inside the advance function; OnTick's QM_IsNewBar() is the single gate).
// -----------------------------------------------------------------------------
datetime g_state_bar        = 0;       // last closed-bar timestamp processed
double   g_rsi_closed       = -1.0;    // RSI(2) at shift 1 (last closed bar)
double   g_sma_macro_closed = 0.0;
double   g_sma_inter_closed = 0.0;
double   g_sma_fast_closed  = 0.0;
double   g_close_closed     = 0.0;
double   g_atr_closed       = 0.0;
bool     g_buy_armed        = true;    // re-arm latch: BUY allowed
bool     g_sell_armed       = true;    // re-arm latch: SELL allowed
bool     g_pos_open_prev    = false;   // was a position open on the prior bar

// -----------------------------------------------------------------------------
// Closed-bar state advance — called once per new bar from OnTick (post-gate).
// -----------------------------------------------------------------------------
void AdvanceState_OnNewBar()
  {
   g_rsi_closed       = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   g_sma_macro_closed = QM_SMA(_Symbol, _Period, strategy_sma_macro, 1);
   g_sma_inter_closed = QM_SMA(_Symbol, _Period, strategy_sma_inter, 1);
   g_sma_fast_closed  = QM_SMA(_Symbol, _Period, strategy_sma_fast, 1);
   g_close_closed     = iClose(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read, gated by QM_IsNewBar
   g_atr_closed       = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);

   // Re-arm logic: once a same-direction position has closed, require RSI(2)
   // to cross back through the midline before a new same-direction signal can
   // fire. Prevents same-noise re-stacking. We detect "position just closed"
   // by the open->closed transition tracked via g_pos_open_prev.
   const bool pos_open_now = (QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
   if(g_pos_open_prev && !pos_open_now)
     {
      // A position closed since the last bar — disarm both directions until
      // RSI crosses the midline in the corresponding direction.
      g_buy_armed  = false;
      g_sell_armed = false;
     }
   if(g_rsi_closed >= 0.0)
     {
      if(g_rsi_closed > strategy_rsi_rearm_level) g_buy_armed  = true;  // RSI back above 50 re-arms BUY
      if(g_rsi_closed < strategy_rsi_rearm_level) g_sell_armed = true;  // RSI back below 50 re-arms SELL
     }
   g_pos_open_prev = pos_open_now;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick. Cheap O(1) checks only.
bool Strategy_NoTradeFilter()
  {
   return false; // 24/5 trigger per card (no intraday session window).
  }

// Fail-OPEN spread guard: only block a GENUINELY wide spread. Never block on
// zero spread (.DWX quotes ask==bid in the tester). Median over recent closed
// bars; current spread compared to a multiple of that median.
bool Strategy_SpreadAllowsEntry()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;   // missing price data — do NOT block on it
   if(ask <= bid)
      return true;   // zero/negative modeled spread (.DWX tester) — allow

   if(strategy_spread_median_bars <= 0 || strategy_spread_median_bars > 64 || strategy_spread_median_mult <= 0.0)
      return true;

   double spreads[64];
   int count = 0;
   for(int i = 1; i <= strategy_spread_median_bars; ++i)
     {
      const long bar_spread = iSpread(_Symbol, _Period, i);
      if(bar_spread <= 0)
         continue;
      spreads[count] = (double)bar_spread;
      ++count;
     }
   if(count <= 0)
      return true;   // no spread history (zero-spread tester) — allow

   for(int i = 1; i < count; ++i)
     {
      const double v = spreads[i];
      int j = i - 1;
      while(j >= 0 && spreads[j] > v)
        {
         spreads[j + 1] = spreads[j];
         --j;
        }
      spreads[j + 1] = v;
     }
   const int mid = count / 2;
   const double median = (count % 2 == 1) ? spreads[mid] : (spreads[mid - 1] + spreads[mid]) * 0.5;
   if(median <= 0.0)
      return true;
   const double current_spread_points = (ask - bid) / point;
   return (current_spread_points <= strategy_spread_median_mult * median);
  }

// Populate `req` and return TRUE if a NEW entry should fire on this closed bar.
// Caller guarantees QM_IsNewBar() == true. The trigger EVENT is the RSI(2)
// crossing INTO the extreme zone on the just-closed bar; SMA filters are STATES.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One position per magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!Strategy_SpreadAllowsEntry())
      return false;

   if(g_rsi_closed < 0.0 || g_sma_macro_closed <= 0.0 || g_close_closed <= 0.0 || g_atr_closed <= 0.0)
      return false;

   // RSI cross-INTO-zone EVENT: previous closed bar (shift 2) was NOT extreme,
   // this closed bar (shift 1 = g_rsi_closed) IS. One fresh trigger per bar.
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi_prev < 0.0)
      return false;

   const bool macro_bull = (g_close_closed > g_sma_macro_closed);
   const bool macro_bear = (g_close_closed < g_sma_macro_closed);
   const bool inter_bull = (!strategy_use_inter_filter) || (g_sma_inter_closed > 0.0 && g_close_closed > g_sma_inter_closed);
   const bool inter_bear = (!strategy_use_inter_filter) || (g_sma_inter_closed > 0.0 && g_close_closed < g_sma_inter_closed);

   const bool rsi_cross_oversold   = (rsi_prev >= strategy_rsi_oversold   && g_rsi_closed < strategy_rsi_oversold);
   const bool rsi_cross_overbought = (rsi_prev <= strategy_rsi_overbought && g_rsi_closed > strategy_rsi_overbought);

   const bool buy_signal  = (macro_bull && inter_bull && rsi_cross_oversold   && g_buy_armed);
   const bool sell_signal = (macro_bear && inter_bear && rsi_cross_overbought && g_sell_armed);

   if(!buy_signal && !sell_signal)
      return false;

   req.type = buy_signal ? QM_BUY : QM_SELL;
   const double entry = (req.type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Hard SL as a PRICE: entry -/+ 2.0 x ATR(14). No TP — exit is RSI-recovery
   // / SMA-5 / time-stop driven (Connors exit-on-recovery).
   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = buy_signal ? "CONNORS_RSI2_H1_LONG" : "CONNORS_RSI2_H1_SHORT";

   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY  && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   return true;
  }

// No trailing / break-even / partial / pyramiding per card. Hard SL is fixed.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: RSI recovery (primary), SMA-5 cross after >=2 bars held
// (fast confirm), time-stop at 24 bars, hard force-close at 48 bars. Uses only
// cached closed-bar state + position bookkeeping (no history scans).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool have_buy  = false;
   bool have_sell = false;
   bool time_stop = false;
   bool hard_stop = false;
   long  bars_held = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      have_buy  = have_buy  || (ptype == POSITION_TYPE_BUY);
      have_sell = have_sell || (ptype == POSITION_TYPE_SELL);

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int secs = PeriodSeconds(_Period);
      if(open_time > 0 && secs > 0)
        {
         bars_held = (TimeCurrent() - open_time) / secs;
         if(strategy_time_stop_bars  > 0 && bars_held >= strategy_time_stop_bars)  time_stop = true;
         if(strategy_hard_close_bars > 0 && bars_held >= strategy_hard_close_bars) hard_stop = true;
        }
     }

   if(!have_buy && !have_sell)
      return false;
   if(hard_stop || time_stop)
      return true;
   if(g_rsi_closed < 0.0)
      return false;

   // RSI-recovery exit (primary Connors exit-on-recovery).
   if(have_buy  && g_rsi_closed > strategy_rsi_exit_buy)
      return true;
   if(have_sell && g_rsi_closed < strategy_rsi_exit_sell)
      return true;

   // SMA-5 fast-recovery cross, only after >=2 bars have passed since entry.
   if(g_sma_fast_closed > 0.0 && g_close_closed > 0.0 && bars_held >= strategy_sma_fast_min_bars)
     {
      if(have_buy  && g_close_closed > g_sma_fast_closed)
         return true;
      if(have_sell && g_close_closed < g_sma_fast_closed)
         return true;
     }

   return false;
  }

// Optional news-filter override — defer to the central two-axis filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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

   // FIRST: advance closed-bar cached state exactly once per new bar.
   const bool new_bar = QM_IsNewBar();
   if(new_bar)
     {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
     }

   // Per-tick: trade management (no-op here — hard SL is fixed).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (reads cached closed-bar state only).
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

   // Per-closed-bar: entry-signal evaluation.
   if(!new_bar)
      return;

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
