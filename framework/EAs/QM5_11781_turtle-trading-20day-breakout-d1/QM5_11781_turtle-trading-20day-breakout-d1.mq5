#property strict
#property version   "5.0"
#property description "QM5_11781 turtle-trading-20day-breakout-d1 — Turtle 20-day Donchian breakout (long+short, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11781 turtle-trading-20day-breakout-d1
// -----------------------------------------------------------------------------
// Source: 'The Legendary Turtle Trading Strategy', Top 10 Best Forex Trading
//         Strategies PDF Report (~2018), p.9-10.
// Card: artifacts/cards_approved/QM5_11781_turtle-trading-20day-breakout-d1.md
//       (g0_status APPROVED).
//
// Mechanics (classic Turtle "System 1", evaluated on closed bars at shift 1):
//   Entry channel STATE : N-day high / low over the entry_channel bars that
//                         PRECEDE the trigger bar (shifts 2 .. entry_channel+1),
//                         EXCLUDING the just-closed trigger bar and the forming
//                         bar. Computed in-EA from bounded closed-bar iHigh/iLow.
//   Breakout EVENT (long): the just-closed bar's HIGH (shift 1) exceeds the
//                         N-day highest high -> a fresh 20-day breakout up.
//   Breakout EVENT (short): the just-closed bar's LOW (shift 1) falls below the
//                         N-day lowest low -> a fresh 20-day breakout down.
//   Long and short reference OPPOSITE extremes, so they can never both trigger
//   on the same bar (avoids the two-cross-same-bar zero-trade trap). One
//   position per magic; no re-entry while in a position.
//   Stop : 2 x ATR(atr_period) on D1 via QM_StopATR (RISK_FIXED stop distance).
//   Take : none (trend-following; ride until the opposite channel exit fires).
//   Exit (Turtle System 1): close LONG when the just-closed LOW breaks the
//         exit_channel-day low; close SHORT when the just-closed HIGH breaks the
//         exit_channel-day high. Exit channel measured over the bars that
//         precede the just-closed bar (shifts 2 .. exit_channel+1).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11781;
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
input int    strategy_entry_channel     = 20;    // Donchian entry lookback (20-day high/low)
input int    strategy_exit_channel      = 10;    // Donchian exit lookback (Turtle System 1, 10-day)
input int    strategy_atr_period        = 14;    // ATR period for the protective stop
input double strategy_sl_atr_mult       = 2.0;   // stop distance = mult * ATR (Turtle 2N proxy)

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

// Highest HIGH over `count` closed bars starting at `start_shift` (inclusive).
// perf-allowed: bounded closed-bar reads for bespoke Donchian-channel logic.
double Channel_HighestHigh(const int start_shift, const int count)
  {
   double hi = -1.0;
   const int last_shift = start_shift + count - 1;
   for(int s = start_shift; s <= last_shift; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s); // perf-allowed: bounded closed-bar read
      if(h <= 0.0)
         continue;
      if(hi < 0.0 || h > hi)
         hi = h;
     }
   return hi;
  }

// Lowest LOW over `count` closed bars starting at `start_shift` (inclusive).
// perf-allowed: bounded closed-bar reads for bespoke Donchian-channel logic.
double Channel_LowestLow(const int start_shift, const int count)
  {
   double lo = -1.0;
   const int last_shift = start_shift + count - 1;
   for(int s = start_shift; s <= last_shift; ++s)
     {
      const double l = iLow(_Symbol, _Period, s); // perf-allowed: bounded closed-bar read
      if(l <= 0.0)
         continue;
      if(lo < 0.0 || l < lo)
         lo = l;
     }
   return lo;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No per-tick no-trade filter. .DWX models zero spread, so a spread guard would
// fail-closed (block every trade). Regime/channel work is on the closed-bar
// entry path. Return FALSE = do not block.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Turtle 20-day breakout entry (long AND short). Caller guarantees
// QM_IsNewBar() == true (closed-bar gate). Channel = STATE (shifts 2..N+1),
// breakout = EVENT on the just-closed bar (shift 1).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic; no pyramiding in this baseline.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Entry channel STATE: N-day extremes BEFORE the just-closed bar. ---
   // start_shift = 2 excludes the forming bar (0) AND the trigger bar (1).
   const double chan_high = Channel_HighestHigh(2, strategy_entry_channel);
   const double chan_low  = Channel_LowestLow(2, strategy_entry_channel);
   if(chan_high <= 0.0 || chan_low <= 0.0)
      return false;

   // --- Breakout EVENT on the just-closed bar (shift 1). ---
   const double bar_high = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double bar_low  = iLow(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   if(bar_high <= 0.0 || bar_low <= 0.0)
      return false;

   const bool breakout_up   = (bar_high > chan_high);
   const bool breakout_down = (bar_low  < chan_low);

   // Long and short reference opposite extremes — they cannot coincide. Guard
   // defensively anyway: if both somehow fire, take neither (ambiguous bar).
   if(breakout_up == breakout_down)
      return false; // either no breakout, or the (impossible) both-sides case

   const double entry = (breakout_up ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   const QM_OrderType side = (breakout_up ? QM_BUY : QM_SELL);
   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // trend-following: no fixed target, exit via channel
   req.reason = (breakout_up ? "turtle_breakout_long" : "turtle_breakout_short");
   return true;
  }

// No active trailing beyond the fixed ATR stop. The Turtle 10-day opposite
// channel exit lives in Strategy_ExitSignal (evaluated once per closed bar).
void Strategy_ManageOpenPosition()
  {
  }

// Turtle System 1 exit: close LONG on a break of the exit_channel-day low,
// close SHORT on a break of the exit_channel-day high. Evaluated on the
// just-closed bar (shift 1); channel measured over shifts 2..exit_channel+1.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the open position's direction for this magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         is_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         is_short = true;
      break;
     }
   if(!is_long && !is_short)
      return false;

   if(is_long)
     {
      const double exit_low = Channel_LowestLow(2, strategy_exit_channel);
      if(exit_low <= 0.0)
         return false;
      const double bar_low = iLow(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
      if(bar_low <= 0.0)
         return false;
      return (bar_low < exit_low);
     }

   // is_short
   const double exit_high = Channel_HighestHigh(2, strategy_exit_channel);
   if(exit_high <= 0.0)
      return false;
   const double bar_high = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(bar_high <= 0.0)
      return false;
   return (bar_high > exit_high);
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
