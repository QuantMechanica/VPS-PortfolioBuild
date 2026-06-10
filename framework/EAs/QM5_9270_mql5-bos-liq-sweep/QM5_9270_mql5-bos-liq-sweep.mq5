#property strict
#property version   "5.0"
#property description "QuantMechanica V5 — BOS Liquidity Sweep (QM5_9270)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9270 — mql5-bos-liq-sweep
// Source: Allan Munene Mutiiria, MQL5 Articles Part 46 (2025-12-12)
// Strategy: Detect swing H/L with confirmed BOS state; enter on SSL/BSL wick
// sweep that closes back beyond swing, at next bar open. Exit 2R TP or
// opposite-BOS+sweep or 36-bar time stop.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9270;
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
input int    strategy_swing_length      = 5;     // bars each side for swing pivot
input int    strategy_atr_period        = 14;    // ATR period for stop/filter
input double strategy_atr_sl_mult       = 0.5;   // ATR multiplier for stop width
input double strategy_sl_buffer_pips    = 10.0;  // minimum SL buffer in pips
input double strategy_rr_target         = 2.0;   // reward:risk ratio for TP
input int    strategy_max_bars_hold     = 36;    // time stop in H1 bars
input int    strategy_atr_vol_period    = 100;   // lookback for ATR vol filter percentile
input double strategy_atr_pct_floor     = 20.0;  // ATR percentile floor (skip below)

// -----------------------------------------------------------------------------
// File-scope state — updated once per new closed bar
// -----------------------------------------------------------------------------
static double g_swing_high      = 0.0;   // most recent confirmed swing high price
static double g_swing_low       = 0.0;   // most recent confirmed swing low price
static int    g_swing_high_bar  = -1;    // bar index of last confirmed swing high
static int    g_swing_low_bar   = -1;    // bar index of last confirmed swing low
static int    g_bos_state       = 0;     // +1 = bullish BOS, -1 = bearish BOS, 0 = none
static int    g_entry_bar       = -1;    // bar index when current position was opened
static double g_entry_sl        = 0.0;   // SL of current open position (for exit logic)
static bool   g_last_sweep_bull = false; // last detected sweep direction
static bool   g_last_sweep_bear = false;

// Detect swing pivot: true if bar[idx] is a swing high/low with `len` bars each side
// These use iHigh/iLow directly — bespoke structural logic; no QM_* helper covers N-bar pivot scan.
bool IsSwingHigh(int idx, int len)
  {
   double h = iHigh(_Symbol, PERIOD_CURRENT, idx); // perf-allowed
   for(int i = 1; i <= len; i++)
     {
      if(iHigh(_Symbol, PERIOD_CURRENT, idx + i) >= h) return false; // perf-allowed
      if(iHigh(_Symbol, PERIOD_CURRENT, idx - i) >= h) return false; // perf-allowed
     }
   return true;
  }

bool IsSwingLow(int idx, int len)
  {
   double l = iLow(_Symbol, PERIOD_CURRENT, idx); // perf-allowed
   for(int i = 1; i <= len; i++)
     {
      if(iLow(_Symbol, PERIOD_CURRENT, idx + i) <= l) return false; // perf-allowed
      if(iLow(_Symbol, PERIOD_CURRENT, idx - i) <= l) return false; // perf-allowed
     }
   return true;
  }

// Advance structural state from the last closed bar forward.
// Called once per new closed bar via the QM_IsNewBar gate.
void AdvanceState_OnNewBar()
  {
   const int len = strategy_swing_length;
   // The earliest bar whose swing status can be confirmed (needs `len` bars on right)
   // is bar index `len`. Check bar[len] against previous swing H/L.
   if(Bars(_Symbol, PERIOD_CURRENT) < len * 2 + 2) // perf-allowed
      return;

   // --- Update swing high ---
   if(IsSwingHigh(len, len))
     {
      double candidate_high = iHigh(_Symbol, PERIOD_CURRENT, len); // perf-allowed
      // BOS bullish: new HH (higher-high than previous swing high)
      if(g_swing_high > 0 && candidate_high > g_swing_high)
         g_bos_state = 1;   // bullish BOS confirmed
      // BOS bearish: new LH (lower-high in context of prior swing lows)
      else if(g_swing_high > 0 && candidate_high < g_swing_high && g_bos_state == -1)
         g_bos_state = -1;  // keep bearish BOS
      g_swing_high    = candidate_high;
      g_swing_high_bar = len;
     }

   // --- Update swing low ---
   if(IsSwingLow(len, len))
     {
      double candidate_low = iLow(_Symbol, PERIOD_CURRENT, len); // perf-allowed
      // BOS bearish: new LL (lower-low than previous swing low)
      if(g_swing_low > 0 && candidate_low < g_swing_low)
         g_bos_state = -1;  // bearish BOS confirmed
      // BOS bullish: new HL (higher-low in context of prior swing highs)
      else if(g_swing_low > 0 && candidate_low > g_swing_low && g_bos_state == 1)
         g_bos_state = 1;   // keep bullish BOS
      g_swing_low    = candidate_low;
      g_swing_low_bar = len;
     }

   // --- Detect sweep candles (bar[1] = last closed bar) ---
   // Sweep = wick pierces swing level then candle closes back beyond it.
   g_last_sweep_bull = false;
   g_last_sweep_bear = false;

   if(g_swing_low > 0)
     {
      double lo1  = iLow(_Symbol, PERIOD_CURRENT, 1);   // perf-allowed
      double cl1  = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed
      double op1  = iOpen(_Symbol, PERIOD_CURRENT, 1);  // perf-allowed
      // Bullish sweep: wick below swing low, close above swing low, close > open
      if(lo1 < g_swing_low && cl1 > g_swing_low && cl1 > op1)
         g_last_sweep_bull = true;
     }

   if(g_swing_high > 0)
     {
      double hi1  = iHigh(_Symbol, PERIOD_CURRENT, 1);  // perf-allowed
      double cl1  = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed
      double op1  = iOpen(_Symbol, PERIOD_CURRENT, 1);  // perf-allowed
      // Bearish sweep: wick above swing high, close below swing high, close < open
      if(hi1 > g_swing_high && cl1 < g_swing_high && cl1 < op1)
         g_last_sweep_bear = true;
     }
  }

// ATR volatility filter: returns true if ATR(14) is above its `period`-bar 20th percentile
bool ATR_Above_Percentile()
  {
   const int lookback = strategy_atr_vol_period;
   const double pct   = strategy_atr_pct_floor / 100.0;
   if(Bars(_Symbol, PERIOD_CURRENT) < lookback + 2) // perf-allowed
      return false;

   double current_atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(current_atr <= 0.0)
      return false;

   // Collect ATR values over lookback (use closed bars 1..lookback)
   double vals[];
   ArrayResize(vals, lookback);
   for(int i = 0; i < lookback; i++)
      vals[i] = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, i + 1);

   // Simple sort to find percentile threshold
   ArraySort(vals);
   int idx_floor = (int)MathFloor(pct * lookback);
   if(idx_floor < 0) idx_floor = 0;
   if(idx_floor >= lookback) idx_floor = lookback - 1;
   double threshold = vals[idx_floor];

   return current_atr >= threshold;
  }

// Return TRUE to BLOCK trading this tick
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate req with entry order parameters and return TRUE for a new entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Must have established BOS state
   if(g_bos_state == 0)
      return false;

   // Volatility filter
   if(!ATR_Above_Percentile())
      return false;

   const double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double pip_val = point * 10.0;  // 1 pip = 10 points for 5-digit FX

   double atr1 = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr1 <= 0.0) return false;

   const double sl_buf_pts = strategy_sl_buffer_pips * pip_val;
   const double sl_atr_pts = strategy_atr_sl_mult * atr1;
   double sl_dist;

   // ----- LONG entry: bullish BOS + sweep below swing low -----
   if(g_bos_state == 1 && g_last_sweep_bull)
     {
      double sweep_low = iLow(_Symbol, PERIOD_CURRENT, 1); // perf-allowed
      double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      sl_dist = MathMax(ask - sweep_low + sl_buf_pts,
                        ask - sweep_low + sl_atr_pts);
      if(sl_dist <= 0.0) return false;

      double tp_dist = sl_dist * strategy_rr_target;

      req.type   = QM_BUY;
      req.price  = ask;
      req.sl     = ask - sl_dist;
      req.tp     = ask + tp_dist;
      req.reason = "bos-liq-bull";

      g_entry_bar = 0;
      g_entry_sl  = req.sl;
      return true;
     }

   // ----- SHORT entry: bearish BOS + sweep above swing high -----
   if(g_bos_state == -1 && g_last_sweep_bear)
     {
      double sweep_high = iHigh(_Symbol, PERIOD_CURRENT, 1); // perf-allowed
      double bid        = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      sl_dist = MathMax(sweep_high - bid + sl_buf_pts,
                        sweep_high - bid + sl_atr_pts);
      if(sl_dist <= 0.0) return false;

      double tp_dist = sl_dist * strategy_rr_target;

      req.type   = QM_SELL;
      req.price  = bid;
      req.sl     = bid + sl_dist;
      req.tp     = bid - tp_dist;
      req.reason = "bos-liq-bear";

      g_entry_bar = 0;
      g_entry_sl  = req.sl;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists
void Strategy_ManageOpenPosition()
  {
   // No active trailing — SL/TP set at entry; time-stop handled by ExitSignal
  }

// Return TRUE to close the open position now
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Time stop: 36 H1 bars
      if(g_entry_bar >= 0)
        {
         int bars_held = iBarShift(_Symbol, PERIOD_CURRENT,
                                   (datetime)PositionGetInteger(POSITION_TIME), false);
         if(bars_held >= strategy_max_bars_hold)
            return true;
        }

      // Opposite BOS + opposite sweep exit
      if(ptype == POSITION_TYPE_BUY && g_bos_state == -1 && g_last_sweep_bear)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_bos_state == 1 && g_last_sweep_bull)
         return true;
     }
   return false;
  }

// Optional news-filter override
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line
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

   // Warm up swing state from closed bars
   g_swing_high     = 0.0;
   g_swing_low      = 0.0;
   g_swing_high_bar = -1;
   g_swing_low_bar  = -1;
   g_bos_state      = 0;
   g_entry_bar      = -1;
   g_entry_sl       = 0.0;
   g_last_sweep_bull = false;
   g_last_sweep_bear = false;

   // Seed swing state from history (scan back up to 500 bars)
   const int len = strategy_swing_length;
   int total = MathMin(Bars(_Symbol, PERIOD_CURRENT) - len - 1, 500); // perf-allowed
   for(int i = total; i >= len; i--)
     {
      if(IsSwingHigh(i, len))
        {
         double h = iHigh(_Symbol, PERIOD_CURRENT, i); // perf-allowed
         if(g_swing_high <= 0) { g_swing_high = h; g_swing_high_bar = i; }
         else if(h > g_swing_high) { g_bos_state = 1;  g_swing_high = h; g_swing_high_bar = i; }
        }
      if(IsSwingLow(i, len))
        {
         double l = iLow(_Symbol, PERIOD_CURRENT, i); // perf-allowed
         if(g_swing_low <= 0) { g_swing_low = l; g_swing_low_bar = i; }
         else if(l < g_swing_low) { g_bos_state = -1; g_swing_low = l; g_swing_low_bar = i; }
        }
     }

   QM_LogEvent(QM_INFO, "INIT_OK", StringFormat("{\"bos_state\":%d}", g_bos_state));
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

   // Per-tick: advance closed-bar state first
   if(QM_IsNewBar())
     {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
     }

   // Per-tick: trade management
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Per-closed-bar: entry signal (only when no open position)
   if(!QM_IsNewBar())
      return;

   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic) { has_position = true; break; }
     }
   if(has_position) return;

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
