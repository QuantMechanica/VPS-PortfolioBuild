#property strict
#property version   "5.0"
#property description "QM5_12488 myh-turtle60 — myhhub Turtle60 closing-price Donchian breakout (long-only, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12488 myh-turtle60
// -----------------------------------------------------------------------------
// Source: myhhub/stock, turtle_trade.py, check_enter(..., threshold=60).
//         https://github.com/myhhub/stock/blob/master/instock/core/strategy/turtle_trade.py
// Card: artifacts/cards_approved/QM5_12488_myh-turtle60.md (g0_status APPROVED).
//
// Mechanics (long-only, CLOSING-PRICE Turtle breakout on closed bars, D1):
//   Entry channel STATE : HighestClose60 = max(Close) over the entry_channel
//                         closed bars that PRECEDE the just-closed trigger bar
//                         (shifts 2 .. entry_channel+1). Computed in-EA from
//                         bounded closed-bar iClose reads, EXCLUDING the forming
//                         bar (0) AND the trigger bar (1).
//   Breakout EVENT      : the just-closed bar's CLOSE (shift 1) is >= the
//                         HighestClose60 state -> a fresh 60-bar closing breakout
//                         up. Long-only (the source defines a long entry only).
//                         No pyramiding: repeated true signals while long are
//                         holds (one position per magic guards this).
//   Stop  : 2.5 x ATR(atr_period) below entry, via QM_StopATR (RISK_FIXED dist).
//   Take  : none (trend-following; ride until channel / time exit fires).
//   Exit  : (a) channel exit — close LONG when the just-closed CLOSE (shift 1)
//               falls below LowestClose20 = min(Close) over the exit_channel
//               closed bars preceding the just-closed bar (shifts 2..exit+1).
//           (b) time exit — close after time_exit_bars closed D1 bars in trade.
//
// Long entry and the channel exit reference OPPOSITE sides (close >= high-chan
// vs close < low-chan) so the EVENT cannot self-cancel on one bar. The two-cross
// trap does not apply: there is a single entry trigger and a single exit trigger,
// each its own bar event against a STATE channel.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12488;
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
input int    strategy_entry_channel     = 60;    // Donchian entry lookback (60-bar highest CLOSE)
input int    strategy_exit_channel      = 20;    // Donchian exit lookback (20-bar lowest CLOSE)
input int    strategy_atr_period        = 20;    // ATR period for the protective stop
input double strategy_sl_atr_mult       = 2.5;   // stop distance = mult * ATR below entry
input int    strategy_time_exit_bars    = 80;    // time exit: close after N closed D1 bars in trade

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

// Highest CLOSE over `count` closed bars starting at `start_shift` (inclusive).
// perf-allowed: bounded closed-bar reads for bespoke closing-Donchian logic.
double Channel_HighestClose(const int start_shift, const int count)
  {
   double hi = -1.0;
   const int last_shift = start_shift + count - 1;
   for(int s = start_shift; s <= last_shift; ++s)
     {
      const double c = iClose(_Symbol, _Period, s); // perf-allowed: bounded closed-bar read
      if(c <= 0.0)
         continue;
      if(hi < 0.0 || c > hi)
         hi = c;
     }
   return hi;
  }

// Lowest CLOSE over `count` closed bars starting at `start_shift` (inclusive).
// perf-allowed: bounded closed-bar reads for bespoke closing-Donchian logic.
double Channel_LowestClose(const int start_shift, const int count)
  {
   double lo = -1.0;
   const int last_shift = start_shift + count - 1;
   for(int s = start_shift; s <= last_shift; ++s)
     {
      const double c = iClose(_Symbol, _Period, s); // perf-allowed: bounded closed-bar read
      if(c <= 0.0)
         continue;
      if(lo < 0.0 || c < lo)
         lo = c;
     }
   return lo;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No per-tick no-trade filter. .DWX models zero spread, so a spread guard would
// fail-closed (block every trade). Channel/breakout work is on the closed-bar
// entry path. Return FALSE = do not block.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Turtle 60-bar CLOSING-price breakout entry (LONG only). Caller guarantees
// QM_IsNewBar() == true (closed-bar gate). Channel = STATE (shifts 2..N+1),
// breakout = EVENT on the just-closed bar (shift 1).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic; no pyramiding in this baseline.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Entry channel STATE: 60-bar highest CLOSE BEFORE the just-closed bar. ---
   // start_shift = 2 excludes the forming bar (0) AND the trigger bar (1).
   const double chan_high = Channel_HighestClose(2, strategy_entry_channel);
   if(chan_high <= 0.0)
      return false;

   // --- Breakout EVENT: the just-closed CLOSE (shift 1) tags/exceeds the chan. ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   if(!(close1 >= chan_high))
      return false; // no fresh 60-bar closing breakout

   // --- Build the long entry. Framework sizes lots (no lots field). ---
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // trend-following: no fixed target, exit via channel/time
   req.reason = "turtle60_close_breakout_long";
   return true;
  }

// No active trailing beyond the fixed ATR stop. The 20-bar closing channel exit
// and the time exit both live in Strategy_ExitSignal (once per closed bar).
void Strategy_ManageOpenPosition()
  {
  }

// Exit the long when EITHER:
//   (a) channel exit — the just-closed CLOSE (shift 1) falls below the 20-bar
//       lowest CLOSE measured over shifts 2..exit_channel+1, OR
//   (b) time exit — the position has been open for >= time_exit_bars closed
//       D1 bars. Evaluated once per closed bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find the open long for this magic and capture its open time.
   datetime pos_open_time = 0;
   bool     have_long     = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue; // long-only EA; ignore anything else defensively
      pos_open_time = (datetime)PositionGetInteger(POSITION_TIME);
      have_long     = true;
      break;
     }
   if(!have_long)
      return false;

   // --- (b) Time exit: count closed bars since the position opened. ---
   if(strategy_time_exit_bars > 0 && pos_open_time > 0)
     {
      const datetime bar_open_1 = iTime(_Symbol, _Period, 1); // just-closed bar open
      if(bar_open_1 > 0)
        {
         // Bars elapsed between entry bar and the just-closed bar (inclusive of
         // the just-closed one). iBarShift gives the shift of the entry bar.
         const int entry_shift = iBarShift(_Symbol, _Period, pos_open_time, false);
         if(entry_shift >= 0)
           {
            // bars held = entry_shift - 1 + 1 = entry_shift (entry bar at shift
            // entry_shift, just-closed bar at shift 1 -> held entry_shift bars).
            const int bars_held = entry_shift; // shift 1 == 1 bar held, etc.
            if(bars_held >= strategy_time_exit_bars)
               return true;
           }
        }
     }

   // --- (a) Channel exit: just-closed CLOSE below the 20-bar lowest close. ---
   const double exit_low = Channel_LowestClose(2, strategy_exit_channel);
   if(exit_low <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   return (close1 < exit_low);
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

   // Closed-bar gate: consume the new-bar event ONCE and reuse for exit+entry.
   if(!QM_IsNewBar())
      return;

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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
