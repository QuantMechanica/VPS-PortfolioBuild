#property strict
#property version   "5.0"
#property description "QM5_11084 tlb-flip — Three Line Break reversal flip (long+short, H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11084 tlb-flip
// -----------------------------------------------------------------------------
// Source: EarnForex "Three-Line Break" indicator (GitHub + MQL5 source).
// Card: artifacts/cards_approved/QM5_11084_tlb-flip.md (g0_status APPROVED).
//
// Mechanics — bounded, deterministic, closed-bar Three-Line-Break (TLB)
// reconstruction. The TLB chart is rebuilt ONCE per new closed H4 bar from a
// bounded window of CONFIRMED bar closes (shift >= 1). It never reads the
// forming bar (shift 0), so there is no repaint.
//
//   TLB block series (close-based EarnForex convention):
//     - Each TLB "line"/block has a direction (+1 up / -1 down) and a
//       price level (its close). The block high/low pair is the running
//       max/min of the close at the time the block printed.
//     - Continuation: in an UP series, a confirmed close ABOVE the highest
//       block-high prints a new UP block. In a DOWN series, a confirmed
//       close BELOW the lowest block-low prints a new DOWN block.
//     - Reversal (color flip) with LinesToBreak = N (default 3): in a DOWN
//       series, a confirmed close ABOVE the highest high of the last N
//       DOWN blocks flips the series to UP (bullish flip). Inverse for a
//       bullish->bearish flip.
//
//   Entry  (one event per closed bar):
//     LONG  : the latest reconstruction produced a fresh BULLISH flip
//             (down-series -> up) on the most recent confirmed bar.
//     SHORT : the latest reconstruction produced a fresh BEARISH flip
//             (up-series -> down) on the most recent confirmed bar.
//     Optional EMA(14)-of-TLB-closes filter: longs only above the EMA,
//             shorts only below (mirrors EarnForex EnableMA / MA_Period).
//
//   Exit   : opposite TLB flip closes the position (handled by the flip that
//            also opens the reverse trade — one position per magic, so the
//            existing position is closed on the opposite-flip bar before the
//            new entry). A catastrophic ATR stop can close first.
//
//   Stop   : entry -/+ sl_atr_mult * ATR(atr_period) (catastrophic only).
//   TP     : none — the strategy exits on the opposite TLB flip.
//   Spread : skip only a genuinely wide spread (fail-open on .DWX zero spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs + the cached TLB rebuild are
// EA-specific. Everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11084;
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
input int    strategy_lines_to_break    = 3;      // TLB reversal threshold (EarnForex LinesToBreak)
input int    strategy_tlb_window_bars   = 240;    // confirmed-close window used to rebuild the TLB series
input int    strategy_min_block_pts     = 0;      // min close-move (points) to print a new block; 0 = any move
input bool   strategy_use_ema_filter    = true;   // EarnForex EnableMA — gate flips by EMA of TLB closes
input int    strategy_ema_period        = 14;     // EarnForex MA_Period — EMA of TLB block closes
input int    strategy_atr_period        = 14;     // ATR period for the catastrophic stop
input double strategy_sl_atr_mult       = 2.5;    // catastrophic stop distance = mult * ATR (card P2 baseline)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Cached TLB state (rebuilt once per new closed bar in AdvanceState_OnNewBar)
// -----------------------------------------------------------------------------
// g_tlb_dir       : current TLB series direction (+1 up / -1 down / 0 none)
// g_tlb_flip      : flip event produced by the LATEST confirmed bar
//                   (+1 fresh bullish flip / -1 fresh bearish flip / 0 none)
// g_tlb_ema       : EMA of TLB block closes (filter), 0 if unavailable
// g_tlb_ready     : true once a series has been successfully reconstructed
int    g_tlb_dir   = 0;
int    g_tlb_flip  = 0;
double g_tlb_ema   = 0.0;
bool   g_tlb_ready = false;

// -----------------------------------------------------------------------------
// Reconstruct the Three-Line-Break series from confirmed closes. Walks the
// close window OLDEST -> NEWEST, maintaining the last N block highs/lows so a
// reversal can be detected against the last `lines_to_break` opposite blocks.
// Sets g_tlb_dir, g_tlb_flip (event on the newest confirmed bar) and g_tlb_ema.
// Bounded: O(window) per new bar, no per-tick work. Reads shift >= 1 only.
// -----------------------------------------------------------------------------
void AdvanceState_OnNewBar()
  {
   g_tlb_flip  = 0;             // default: no flip this bar
   const int N = strategy_lines_to_break;
   if(N < 1)
      return;

   int window = strategy_tlb_window_bars;
   if(window < (N + 5))
      window = N + 5;

   // Available confirmed bars (exclude forming bar 0).
   const int avail = Bars(_Symbol, _Period) - 1;   // perf-allowed: bar count, once/bar
   if(avail < (N + 2))
      return;
   if(window > avail)
      window = avail;

   const double min_move = (strategy_min_block_pts > 0)
                           ? strategy_min_block_pts * SymbolInfoDouble(_Symbol, SYMBOL_POINT)
                           : 0.0;

   // Pull the confirmed closes oldest->newest into a local array.
   // shift = window .. 1  ==>  index 0 .. window-1 (oldest first).
   double closes[];
   ArrayResize(closes, window);
   for(int i = 0; i < window; i++)
     {
      const int shift = window - i;                 // window (oldest) .. 1 (newest confirmed)
      const double c = iClose(_Symbol, _Period, shift); // perf-allowed: closed-bar read, once/bar
      if(c <= 0.0)
         return;                                    // incomplete history — defer
      closes[i] = c;
     }

   // Block ring of the last N blocks: direction + the close level of each block.
   double block_close[];
   ArrayResize(block_close, N);
   int    block_count = 0;     // total blocks printed
   int    series_dir  = 0;     // current series direction (+1/-1/0)

   // EMA of block closes (EarnForex applies the MA to the TLB line series).
   const double ema_k = 2.0 / (strategy_ema_period + 1.0);
   double ema_val = 0.0;
   bool   ema_seeded = false;

   // Seed the first block from the first two closes that move enough.
   int idx = 0;
   double last_block_close = 0.0;
   // Initialise with the first close as the reference block.
   last_block_close = closes[0];
   series_dir = 0;
   // Record first block.
   block_close[0] = last_block_close;
   block_count = 1;
   ema_val = last_block_close;
   ema_seeded = true;

   // Helper accessors implemented inline (MQL5 has no nested funcs):
   // highest/lowest of the last min(block_count, N) opposite blocks are derived
   // from block_close[] over the ring window.

   for(idx = 1; idx < window; idx++)
     {
      const double c = closes[idx];
      const double move = c - last_block_close;

      // Determine the breakout reference levels from the recorded blocks.
      // Highest / lowest close among the last min(block_count, N) blocks.
      int take = (block_count < N) ? block_count : N;
      double hi = -DBL_MAX;
      double lo =  DBL_MAX;
      for(int b = 0; b < take; b++)
        {
         // ring index of the b-th most-recent block
         int ringpos = (block_count - 1 - b) % N;
         if(ringpos < 0)
            ringpos += N;
         const double bc = block_close[ringpos];
         if(bc > hi) hi = bc;
         if(bc < lo) lo = bc;
        }

      int new_block_dir = 0;

      if(series_dir >= 0)
        {
         // Currently up (or undecided): continuation if close makes a new high
         // beyond the up reference; reversal if it breaks below the lowest of
         // the last N blocks by more than min_move.
         if(c > last_block_close && (move >= min_move))
           {
            new_block_dir = +1;            // up continuation
           }
         else if(c < lo && (last_block_close - c) >= min_move)
           {
            new_block_dir = -1;            // bearish reversal flip
           }
        }
      else
        {
         // Currently down: continuation on a new low; reversal up if close
         // breaks above the highest of the last N blocks.
         if(c < last_block_close && ((last_block_close - c) >= min_move))
           {
            new_block_dir = -1;            // down continuation
           }
         else if(c > hi && (c - last_block_close) >= min_move)
           {
            new_block_dir = +1;            // bullish reversal flip
           }
        }

      if(new_block_dir == 0)
         continue;                          // no new block this bar (inside range)

      const bool is_flip = (series_dir != 0 && new_block_dir != series_dir);

      // Print the new block.
      last_block_close = c;
      series_dir = new_block_dir;
      const int ring = block_count % N;
      block_close[ring] = c;
      block_count++;

      // Advance EMA on each printed block close.
      if(!ema_seeded)
        {
         ema_val = c;
         ema_seeded = true;
        }
      else
        {
         ema_val = ema_val + ema_k * (c - ema_val);
        }

      // The flip EVENT is meaningful only when it occurs on the NEWEST
      // confirmed bar (idx == window-1); older flips are historical state.
      if(idx == (window - 1) && is_flip)
         g_tlb_flip = new_block_dir;
     }

   g_tlb_dir   = series_dir;
   g_tlb_ema   = ema_seeded ? ema_val : 0.0;
   g_tlb_ready = (block_count >= 2);
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

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry on a fresh TLB flip. Caller guarantees QM_IsNewBar() == true; the TLB
// series has already been rebuilt this bar by AdvanceState_OnNewBar().
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_tlb_ready || g_tlb_flip == 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(g_tlb_flip > 0)
     {
      // Bullish flip -> LONG. Optional EMA filter: only above the TLB EMA.
      if(strategy_use_ema_filter && g_tlb_ema > 0.0)
        {
         const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
         if(close1 <= 0.0 || close1 < g_tlb_ema)
            return false;
        }
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no TP — exit on the opposite TLB flip
      req.reason = "tlb_bullish_flip";
      return true;
     }

   // Bearish flip -> SHORT. Optional EMA filter: only below the TLB EMA.
   if(strategy_use_ema_filter && g_tlb_ema > 0.0)
     {
      const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
      if(close1 <= 0.0 || close1 > g_tlb_ema)
         return false;
     }
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
   req.reason = "tlb_bearish_flip";
   return true;
  }

// No active trade management beyond the catastrophic ATR stop. Exit is the
// opposite TLB flip (Strategy_ExitSignal).
void Strategy_ManageOpenPosition()
  {
  }

// Exit on the opposite TLB flip. A long is closed by a fresh bearish flip; a
// short by a fresh bullish flip. The same flip bar then opens the reverse
// trade via Strategy_EntrySignal (one position per magic, so the existing
// position is closed first by the framework OnTick exit loop).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(!g_tlb_ready || g_tlb_flip == 0)
      return false;

   // Find the side of the open position and exit if the flip is opposite.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && g_tlb_flip < 0)
         return true;   // bearish flip closes the long
      if(ptype == POSITION_TYPE_SELL && g_tlb_flip > 0)
         return true;   // bullish flip closes the short
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

   // FIRST: advance the cached TLB state once per closed bar. Latch the
   // new-bar event so the entry gate below reuses it (single-consume).
   const bool new_bar = QM_IsNewBar();
   if(new_bar)
      AdvanceState_OnNewBar();

   // Per-tick: trade management (no-op beyond the ATR stop).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (opposite TLB flip). Reads cached state only.
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

   // Per-closed-bar: entry-signal evaluation. Reuse the latched new-bar event.
   if(!new_bar)
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
