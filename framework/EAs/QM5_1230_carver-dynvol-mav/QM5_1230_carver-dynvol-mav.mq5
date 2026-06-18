#property strict
#property version   "5.0"
#property description "QM5_1230 carver-dynvol-mav — Carver Dynamic-Vol Starter MAV (trend MA-cross + dynamic-vol stop, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1230 carver-dynvol-mav
// -----------------------------------------------------------------------------
// Source: Rob Carver, qoppac.blogspot.com 2020-12 "Dynamic trend following"
//         (Leveraged Trading starter system + dynamic-vol-control variant).
// Card: artifacts/cards_approved/QM5_1230_carver-dynvol-mav.md (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads at shift 1; one position per symbol/magic):
//   Trend STATE  : fast_ma = EMA(16), slow_ma = EMA(64). raw_signal =
//                  +1 if fast>slow, -1 if fast<slow, 0 if equal.
//   Entry EVENT  : a fresh fast/slow MA cross (the cross is the trigger; the
//                  relationship is the state). If flat and the signal flips into
//                  a non-zero direction, open in that direction.
//   Dynamic vol  : daily_vol = StdDev(close-to-close price changes, 25), measured
//                  on closed bars. StopGap = stop_vol_mult * current_daily_vol
//                  (Carver 8x daily vol ~= 0.5 annual std). The vol term scales
//                  RISK_FIXED position size via the framework lot sizer (smaller
//                  stop => larger lots), NOT a lot martingale.
//   Stop loss    : broker SL placed at StopGap from entry (sizes lots, hard floor).
//   Exit (mgmt)  : trailing high/low-water. Track highest close since long entry
//                  (lowest since short). Close LONG when close < hwm - StopGap;
//                  close SHORT when close > lwm + StopGap. StopGap recomputed each
//                  closed bar from CURRENT daily_vol (dynamic).
//   Exit (conserv): optional MA-flip — close if raw_signal flips opposite.
//   Whipsaw guard: after a stop-out / trail-out, do not reopen the SAME direction
//                  until an opposite signal appears OR cooldown_bars elapse.
//   Filters      : require >= min_bars closed D1 bars; spread cap (fail-open on
//                  .DWX zero modeled spread); closed-bar cadence only.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1230;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fast_ma_period    = 16;     // fast EMA (Carver 16)
input int    strategy_slow_ma_period    = 64;     // slow EMA (Carver 64)
input int    strategy_vol_lookback      = 25;     // close-to-close changes for daily vol StdDev
input double strategy_stop_vol_mult     = 8.0;    // StopGap = mult * daily_vol (Carver 8x ~ 0.5 annual std)
input int    strategy_cooldown_bars     = 20;     // same-direction reentry cooldown after a stop-out
input bool   strategy_ma_flip_exit      = true;   // conservative exit: close when raw_signal flips opposite
input int    strategy_min_bars          = 100;    // require this many closed bars before trading
input double strategy_spread_pct_of_stop = 25.0;  // skip new entries if spread > this % of StopGap

// -----------------------------------------------------------------------------
// File-scope trade state (advanced on the closed-bar gate). Carver's trailing
// high/low-water mark and the same-direction whipsaw guard need a small amount
// of deterministic state — this is plain trade bookkeeping, NOT ML / adaptive
// parameters (nothing here mutates a strategy parameter from running PnL).
// -----------------------------------------------------------------------------
bool     g_in_position      = false;   // mirror of "we hold a position for our magic"
int      g_pos_dir          = 0;       // +1 long / -1 short while in position
double   g_extreme_close    = 0.0;     // highest close since long entry / lowest since short
datetime g_state_bar_time   = 0;       // last closed-bar timestamp the state advanced on

int      g_cooldown_dir     = 0;       // direction we are cooling down on (+1/-1/0)
int      g_cooldown_left    = 0;       // closed bars remaining in cooldown

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Raw MA-relationship state on closed bars at `shift`: +1 fast>slow, -1 fast<slow,
// 0 equal / unavailable.
int CarverRawSignal(const int shift)
  {
   const double fast_ma = QM_EMA(_Symbol, _Period, strategy_fast_ma_period, shift);
   const double slow_ma = QM_EMA(_Symbol, _Period, strategy_slow_ma_period, shift);
   if(fast_ma <= 0.0 || slow_ma <= 0.0)
      return 0;
   if(fast_ma > slow_ma)
      return 1;
   if(fast_ma < slow_ma)
      return -1;
   return 0;
  }

// Sample standard deviation of close-to-close price changes over the last
// `strategy_vol_lookback` changes (closed bars). Bounded loop (<= ~26 reads),
// runs only on the closed-bar path. iClose is a documented per-bar read here —
// the daily-vol estimate is bespoke structural math the QM readers don't cover.
double CarverDailyVol()
  {
   const int n = strategy_vol_lookback;
   if(n < 2)
      return 0.0;

   // Need closes at shifts 1 .. n+1 to form n changes (close[s] - close[s+1]).
   double sum = 0.0;
   double diffs[];
   ArrayResize(diffs, n);
   for(int i = 0; i < n; ++i)
     {
      const int s = i + 1;
      const double c0 = iClose(_Symbol, _Period, s);     // perf-allowed: bespoke vol math, closed-bar gated
      const double c1 = iClose(_Symbol, _Period, s + 1); // perf-allowed: bespoke vol math, closed-bar gated
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;
      const double d = c0 - c1;
      diffs[i] = d;
      sum += d;
     }
   const double mean = sum / n;
   double var = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double e = diffs[i] - mean;
      var += e * e;
     }
   var /= (n - 1); // sample variance
   if(var <= 0.0)
      return 0.0;
   return MathSqrt(var);
  }

// Current open-position direction for our magic (+1 long / -1 short / 0 flat),
// and entry price by reference. Reads MT5 position state directly.
int CarverPositionDir(double &entry_price)
  {
   entry_price = 0.0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         return 1;
      if(ptype == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
  }

// Advance the file-scope trade/cooldown state ONCE per closed bar. Called from
// the closed-bar path only (never adds its own timestamp gate beyond the dedupe).
void CarverAdvanceState()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: closed-bar dedupe key
   if(bar_time == g_state_bar_time)
      return;
   g_state_bar_time = bar_time;

   double entry_price = 0.0;
   const int dir = CarverPositionDir(entry_price);

   if(dir == 0)
     {
      // Flat: tick down any active cooldown by one closed bar.
      g_in_position   = false;
      g_pos_dir       = 0;
      g_extreme_close = 0.0;
      if(g_cooldown_left > 0)
        {
         g_cooldown_left -= 1;
         if(g_cooldown_left <= 0)
            g_cooldown_dir = 0;
        }
      return;
     }

   // In position: maintain the high/low-water mark from the last closed close.
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   if(!g_in_position || g_pos_dir != dir)
     {
      // Just entered (or direction flipped) — seed the extreme from entry & close.
      g_in_position   = true;
      g_pos_dir       = dir;
      g_extreme_close = (close1 > 0.0 ? close1 : entry_price);
      if(entry_price > 0.0)
        {
         if(dir > 0)
            g_extreme_close = MathMax(g_extreme_close, entry_price);
         else
            g_extreme_close = MathMin(g_extreme_close, entry_price);
        }
      return;
     }

   if(close1 > 0.0)
     {
      if(dir > 0)
         g_extreme_close = MathMax(g_extreme_close, close1);
      else
         g_extreme_close = MathMin(g_extreme_close, close1);
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (fail-open on .DWX zero spread).
// Regime/signal/vol work is on the closed-bar path in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // .DWX models zero spread — never fail-closed on it

   // Reference distance = current StopGap. If vol unavailable, defer (don't block).
   const double daily_vol = CarverDailyVol();
   if(daily_vol <= 0.0)
      return false;
   const double stop_gap = strategy_stop_vol_mult * daily_vol;
   if(stop_gap <= 0.0)
      return false;

   if(spread > (strategy_spread_pct_of_stop / 100.0) * stop_gap)
      return true; // genuinely wide spread — block new entry this tick

   return false;
  }

// Entry on a fresh MA cross. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Require enough history for the slow EMA + vol window to be meaningful.
   if(Bars(_Symbol, _Period) < strategy_min_bars) // perf-allowed: history-length guard
      return false;

   // --- Trend STATE now vs previous closed bar (the cross is the EVENT) ---
   const int sig_now  = CarverRawSignal(1);
   const int sig_prev = CarverRawSignal(2);
   if(sig_now == 0)
      return false;

   // Fresh cross into a non-zero direction: prev was opposite-or-flat, now decided.
   const bool crossed = (sig_prev != sig_now);
   if(!crossed)
      return false;

   // --- Whipsaw guard: block same-direction reentry during cooldown unless the
   //     signal has flipped opposite (an opposite cross always clears it). ---
   if(g_cooldown_left > 0 && g_cooldown_dir == sig_now)
      return false;

   // --- Dynamic vol -> StopGap. Smaller vol => tighter stop => larger lots via
   //     QM_LotsForRisk against RISK_FIXED (Carver dynamic-vol position scaling). ---
   const double daily_vol = CarverDailyVol();
   if(daily_vol <= 0.0)
      return false;

   const double entry = (sig_now > 0 ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   const QM_OrderType otype = (sig_now > 0 ? QM_BUY : QM_SELL);
   // Stop distance = stop_vol_mult * daily_vol (price units). QM_StopATRFromValue
   // treats daily_vol as the per-unit distance and applies the multiplier.
   const double sl = QM_StopATRFromValue(_Symbol, otype, entry, daily_vol, strategy_stop_vol_mult);
   if(sl <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;  // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;  // trend system rides the trailing high/low-water exit, no fixed TP
   req.reason = (sig_now > 0 ? "carver_dynvol_long" : "carver_dynvol_short");
   return true;
  }

// Trailing high/low-water management is evaluated in Strategy_ExitSignal (it must
// decide a full close). No SL/TP nudging here — the broker SL is the hard floor.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: dynamic trailing high/low-water OR optional MA-flip.
bool Strategy_ExitSignal()
  {
   double entry_price = 0.0;
   const int dir = CarverPositionDir(entry_price);
   if(dir == 0)
      return false;

   // Conservative MA-flip exit: raw signal turned opposite to the position.
   if(strategy_ma_flip_exit)
     {
      const int sig_now = CarverRawSignal(1);
      if(sig_now != 0 && sig_now != dir)
         return true;
     }

   // Dynamic trailing high/low-water. StopGap recomputed from CURRENT daily vol.
   const double daily_vol = CarverDailyVol();
   if(daily_vol <= 0.0)
      return false;
   const double stop_gap = strategy_stop_vol_mult * daily_vol;
   if(stop_gap <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar read
   if(close1 <= 0.0)
      return false;

   // g_extreme_close is advanced once per closed bar in CarverAdvanceState().
   if(!g_in_position || g_extreme_close <= 0.0)
      return false;

   if(dir > 0)
     {
      if(close1 < g_extreme_close - stop_gap)
         return true; // long trail-out
     }
   else
     {
      if(close1 > g_extreme_close + stop_gap)
         return true; // short trail-out
     }

   return false;
  }

// Defer to the central news filter.
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   g_in_position    = false;
   g_pos_dir        = 0;
   g_extreme_close  = 0.0;
   g_state_bar_time = 0;
   g_cooldown_dir   = 0;
   g_cooldown_left  = 0;

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

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      // Trail-out / MA-flip close: start the same-direction whipsaw cooldown.
      if(g_pos_dir != 0)
        {
         g_cooldown_dir  = g_pos_dir;
         g_cooldown_left = strategy_cooldown_bars;
        }
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

   // Advance trailing/cooldown state once per new closed bar before evaluating entry.
   CarverAdvanceState();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
        {
         // Seed state immediately so the trail has a mark on the entry bar.
         double entry_price = 0.0;
         const int dir = CarverPositionDir(entry_price);
         if(dir != 0)
           {
            g_in_position   = true;
            g_pos_dir       = dir;
            const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: seed extreme
            g_extreme_close = (c1 > 0.0 ? c1 : entry_price);
            if(entry_price > 0.0)
               g_extreme_close = (dir > 0 ? MathMax(g_extreme_close, entry_price)
                                          : MathMin(g_extreme_close, entry_price));
           }
        }
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
