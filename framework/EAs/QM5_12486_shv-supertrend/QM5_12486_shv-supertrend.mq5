#property strict
#property version   "5.0"
#property description "QM5_12486 shv-supertrend — SuperTrend flip trend-following (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12486 shv-supertrend
// -----------------------------------------------------------------------------
// Source: shashankvemuri, Finance super_trend.py
//   https://github.com/shashankvemuri/Finance/blob/master/technical_indicators/super_trend.py
// Card: artifacts/cards_approved/QM5_12486_shv-supertrend.md (g0_status APPROVED).
//
// Mechanics (long+short, closed-bar reads, D1):
//   SuperTrend (ATR period 7, multiplier 3.0) reconstructed in-EA from QM_ATR:
//     hl2          = (high + low) / 2
//     basic_upper  = hl2 + mult * ATR
//     basic_lower  = hl2 - mult * ATR
//     final_lower  = (basic_lower > final_lower_prev || close_prev <= final_lower_prev)
//                    ? basic_lower : final_lower_prev
//     final_upper  = (basic_upper < final_upper_prev || close_prev >= final_upper_prev)
//                    ? basic_upper : final_upper_prev
//     direction flips: dir=+1 (up) when close crosses ABOVE final_upper_prev;
//                      dir=-1 (down) when close crosses BELOW final_lower_prev;
//                      else carries forward.
//   ONE forward reconstruction over a bounded closed-bar seed yields the
//   direction series; we read dir@2 (older) and dir@1 (last closed) from the
//   SAME pass (invariant #8 — no two convergent reconstructions). A flip from
//   dir@2 to dir@1 is the single TRIGGER EVENT:
//     dir@2 <= 0 && dir@1 > 0  -> go LONG  (close opposite first)
//     dir@2 >= 0 && dir@1 < 0  -> go SHORT (close opposite first)
//   Stop : catastrophic ATR stop = entry -/+ sl_atr_mult * ATR (the SuperTrend
//          band is the regime/soft stop; flip exits via Strategy_ExitSignal).
//          Card emergency stop = 3.0 * ATR(20); modeled here via sl_atr_period /
//          sl_atr_mult inputs so the stop ATR is independent of the signal ATR.
//   Exit : opposite SuperTrend flip closes the open position.
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX 0 spread).
//
// Symbols: EURUSD/GBPUSD/USDJPY/AUDUSD/XAUUSD/NDX/WS30 .DWX — all present in
// dwx_symbol_matrix.csv (no porting required).
//
// One position per magic. Only the 5 Strategy_* hooks + Strategy inputs are
// EA-specific; everything below the wiring line is framework boilerplate.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12486;
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
input int    strategy_st_atr_period      = 7;      // SuperTrend ATR period (card n=7)
input double strategy_st_multiplier      = 3.0;    // SuperTrend ATR band multiplier (card f=3)
input int    strategy_st_seed_bars       = 200;    // bounded closed-bar seed for the recursion
input int    strategy_sl_atr_period      = 20;     // emergency-stop ATR period (card ATR(20))
input double strategy_sl_atr_mult        = 3.0;    // catastrophic stop = mult * ATR(sl_atr_period)
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// SuperTrend reconstruction
// -----------------------------------------------------------------------------
// Forward-reconstruct the SuperTrend direction series ONCE over a bounded
// closed-bar window and report dir at the requested newest shift plus the bar
// before it. older_shift = newest_shift + 1, derived from the SAME pass.
//
// Returns false if there is not enough history / ATR yet.
bool ST_Direction(const int newest_shift, int &dir_newest, int &dir_older)
  {
   const int period = strategy_st_atr_period;
   const double mult = strategy_st_multiplier;
   if(period < 1 || mult <= 0.0)
      return false;

   // Seed window: oldest seed bar .. newest_shift. Bound it for perf.
   int seed = strategy_st_seed_bars;
   if(seed < period + 5)
      seed = period + 5;
   const int start_shift = newest_shift + seed; // oldest bar processed

   // Need ATR + OHLC available across the whole window.
   if(Bars(_Symbol, _Period) <= start_shift + 2)
      return false;

   double final_upper_prev = 0.0;
   double final_lower_prev = 0.0;
   double close_prev       = 0.0;
   int    dir_prev         = 0;       // 0 = uninitialised
   bool   have_prev        = false;

   int dn = 0; // captured dir at newest_shift
   int dolder = 0; // captured dir at newest_shift+1
   bool got_newest = false;
   bool got_older  = false;

   // Walk from oldest (large shift) to newest (small shift).
   for(int s = start_shift; s >= newest_shift; --s)
     {
      const double atr_v = QM_ATR(_Symbol, _Period, period, s);
      if(atr_v <= 0.0)
        {
         // ATR not ready this deep — reset and keep walking forward.
         have_prev = false;
         dir_prev  = 0;
         continue;
        }

      const double hi = iHigh(_Symbol, _Period, s);  // perf-allowed: bounded once-per-bar seed
      const double lo = iLow(_Symbol, _Period, s);   // perf-allowed
      const double cl = iClose(_Symbol, _Period, s); // perf-allowed
      if(hi <= 0.0 || lo <= 0.0 || cl <= 0.0)
        {
         have_prev = false;
         dir_prev  = 0;
         continue;
        }

      const double hl2         = (hi + lo) / 2.0;
      const double basic_upper = hl2 + mult * atr_v;
      const double basic_lower = hl2 - mult * atr_v;

      double final_upper = basic_upper;
      double final_lower = basic_lower;
      int    dir         = dir_prev;

      if(!have_prev)
        {
         // Seed direction from price-vs-band on the first usable bar.
         dir = (cl > hl2) ? 1 : -1;
        }
      else
        {
         // Carry the final bands forward (standard SuperTrend locking).
         if(basic_lower > final_lower_prev || close_prev <= final_lower_prev)
            final_lower = basic_lower;
         else
            final_lower = final_lower_prev;

         if(basic_upper < final_upper_prev || close_prev >= final_upper_prev)
            final_upper = basic_upper;
         else
            final_upper = final_upper_prev;

         // Direction flip on close crossing the active locked band.
         if(dir_prev <= 0 && cl > final_upper_prev)
            dir = 1;
         else if(dir_prev >= 0 && cl < final_lower_prev)
            dir = -1;
         else
            dir = (dir_prev == 0) ? ((cl > hl2) ? 1 : -1) : dir_prev;
        }

      // Capture the two shifts we care about from this single pass.
      if(s == newest_shift + 1)
        {
         dolder    = dir;
         got_older = true;
        }
      if(s == newest_shift)
        {
         dn         = dir;
         got_newest = true;
        }

      final_upper_prev = final_upper;
      final_lower_prev = final_lower;
      close_prev       = cl;
      dir_prev         = dir;
      have_prev        = true;
     }

   if(!got_newest || !got_older)
      return false;

   dir_newest = dn;
   dir_older  = dolder;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_sl_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // defer to entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry on a SuperTrend flip EVENT (one direction change between dir@2 and
// dir@1). Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // dir@1 = last closed bar, dir@2 = the bar before — from ONE reconstruction.
   int dir1 = 0, dir2 = 0;
   if(!ST_Direction(1, dir1, dir2))
      return false;
   if(dir1 == 0)
      return false;

   const bool flip_up   = (dir2 <= 0 && dir1 > 0);
   const bool flip_down = (dir2 >= 0 && dir1 < 0);
   if(!flip_up && !flip_down)
      return false;

   // Emergency stop ATR (card: 3.0 * ATR(20)), independent of the signal ATR.
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_sl_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(flip_up)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — exit on opposite SuperTrend flip
      req.reason = "supertrend_flip_long";
      return true;
     }

   // flip_down
   const double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      return false;
   const double sl_s = QM_StopATRFromValue(_Symbol, QM_SELL, entry_s, atr_value, strategy_sl_atr_mult);
   if(sl_s <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl_s;
   req.tp     = 0.0;
   req.reason = "supertrend_flip_short";
   return true;
  }

// No active trade management beyond the catastrophic ATR stop. Regime exit
// lives in Strategy_ExitSignal (opposite SuperTrend flip).
void Strategy_ManageOpenPosition()
  {
  }

// Defensive/regime exit: close when SuperTrend direction now opposes the open
// position's side. dir@1 = last closed bar (current regime).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   int dir1 = 0, dir2 = 0;
   if(!ST_Direction(1, dir1, dir2))
      return false;
   if(dir1 == 0)
      return false;

   // Determine the side of our open position for this magic.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   if(have_long && dir1 < 0)
      return true;   // regime turned down — exit long
   if(have_short && dir1 > 0)
      return true;   // regime turned up — exit short
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
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
