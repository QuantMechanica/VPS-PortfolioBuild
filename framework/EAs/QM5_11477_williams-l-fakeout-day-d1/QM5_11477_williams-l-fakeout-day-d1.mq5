#property strict
#property version   "5.0"
#property description "QM5_11477 williams-l-fakeout-day-d1 — Larry Williams Fake-Out Day failed-breakout reversal, market entry on close-back-inside (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11477 williams-l-fakeout-day-d1
// -----------------------------------------------------------------------------
// Source: Larry Williams, "Inner Circle Workshop Trading Method" (~2000).
// Card: artifacts/cards_approved/QM5_11477_williams-l-fakeout-day-d1.md
//       (g0_status APPROVED).
//
// Concept — the "Fake-Out Day" (Failure-Day family). A daily bar that makes a
// false break beyond the PRIOR day's extreme, then FAILS and closes back inside
// the prior day's range, trapping the breakout traders. That failed-break-then-
// close-back-inside is the reversal trigger.
//
// Implementation note (prompt KEY RULES, overrides the card's pending-stop wording):
//   We detect this as ONE closed-bar EVENT on the just-closed signal bar[1] vs
//   the prior bar[2], and enter at MARKET on the new bar[0] open. This avoids
//   the pending-order / two-cross-same-bar zero-trade trap. The sibling EA
//   QM5_11424 covers the breakout STOP-entry realisation; this EA is the
//   close-back-inside MARKET-entry realisation of the same card family.
//
// Mechanics (D1, deterministic OHLC geometry on CLOSED bars at shift 1 & 2):
//
//   Bullish Fake-Out Day (reversal BUY) — signal bar[1] vs prior bar[2]:
//       High[1]  > High[2]   STATE : broke ABOVE the prior day's high (false break up)
//       Low[1]   > Low[2]    (higher low — expanded up, the bullish-looking trap)
//       Close[1] < High[2]   EVENT : but CLOSED BACK INSIDE the prior day's range
//       Close[1] < Close[2]  confirm: weak close vs prior close (bearish surprise)
//     Entry  : MARKET BUY at bar[0] open (the squeeze/reversal).
//     Stop   : Low[1]  - buffer   (the Fake-Out Day's low).
//     Take   : entry + tp_rr * risk.
//
//   Bearish Fake-Out Day (reversal SELL) — mirror:
//       Low[1]   < Low[2]    STATE : broke BELOW the prior day's low (false break down)
//       High[1]  < High[2]   (lower high — expanded down, the bearish-looking trap)
//       Close[1] > Low[2]    EVENT : but CLOSED BACK INSIDE the prior day's range
//       Close[1] > Close[2]  confirm: strong close vs prior close (bullish surprise)
//     Entry  : MARKET SELL at bar[0] open.
//     Stop   : High[1] + buffer   (the Fake-Out Day's high).
//     Take   : entry - tp_rr * risk.
//
//   Optional close-strength filter (card "bottom/top 33% of range"): for a BUY
//   the close sits in the lower third of the signal bar's range (and vice versa).
//   Time stop: exit at market after strategy_time_stop_bars closed D1 bars.
//
//   .DWX invariants honoured:
//     - Gapless-safe: every condition references prior-bar CLOSE/HIGH/LOW only;
//       no open-vs-prior-range gap rule is required.
//     - Single CLOSE event (close-back-inside) is the trigger; the break is a
//       STATE on the same bar — no two coincident cross EVENTS.
//     - Spread guard fails OPEN on zero modelled spread.
//     - No swap gate, no session/broker-time clock, no external feed.
//     - Pip buffers / SL cap / min-range via QM_StopRulesPipsToPriceDistance
//       (scale-correct on 5-digit FX and 3-digit JPY).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11477;
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
input int    strategy_stop_buffer_pips      = 1;     // buffer beyond signal-bar L/H for the protective stop
input int    strategy_min_signal_range_pips = 10;    // min signal-bar range (High[1]-Low[1]) to filter trivial signals
input int    strategy_sl_cap_pips           = 80;    // P2 cap on stop distance (entry->SL); skip if breached and uncappable
input double strategy_tp_rr                 = 1.5;   // take-profit = tp_rr * risk distance (card 1-2x range)
input bool   strategy_require_close_third    = false; // require close in bottom(buy)/top(sell) third of signal bar range
input int    strategy_time_stop_bars        = 5;     // exit at market after this many closed D1 bars (card time-stop)
input bool   strategy_no_friday_entry        = true;  // skip new entries on Friday (card "No Friday entry")
input double strategy_spread_cap_pips        = 25.0;  // skip a genuinely wide spread (fail-open on .DWX zero spread)

// -----------------------------------------------------------------------------
// File-scope state: bar count at fill, for the time-stop. Reset on flat.
// -----------------------------------------------------------------------------
datetime g_entry_bar_time = 0;   // iTime of bar[0] at entry; 0 = flat / unknown

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — pattern work is on the
// closed-bar entry path. Fail-OPEN on .DWX zero modelled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — do not block on it

   const double spread = ask - bid;
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modelled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Williams Fake-Out Day failed-breakout reversal, MARKET entry. Caller
// guarantees QM_IsNewBar() == true (closed-bar gate) — runs once at the open of
// each new daily bar[0], evaluating the just-closed signal bar[1] vs bar[2].
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One position per magic/symbol.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Card: No Friday entry (avoid entering at week's end).
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- Closed-bar OHLC geometry (perf-allowed: bespoke structural candle
   //     pattern, bounded single-shift reads at shift 1 and 2; no framework
   //     reader covers raw OHLC candle comparison). ---
   const double high1  = iHigh(_Symbol,  _Period, 1); // perf-allowed
   const double low1   = iLow(_Symbol,   _Period, 1); // perf-allowed
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed
   const double high2  = iHigh(_Symbol,  _Period, 2); // perf-allowed
   const double low2   = iLow(_Symbol,   _Period, 2); // perf-allowed
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 ||
      high2 <= 0.0 || low2 <= 0.0 || close2 <= 0.0)
      return false;

   // --- Minimum signal-bar range filter (gapless-safe: own-bar range). ---
   const double sig_range = high1 - low1;
   const double min_range = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_min_signal_range_pips);
   if(min_range > 0.0 && sig_range < min_range)
      return false;
   if(sig_range <= 0.0)
      return false;

   // --- Bullish Fake-Out Day (reversal BUY) ---
   //   broke above prior high (STATE) + higher low, but closed back inside the
   //   prior range (EVENT) and weak vs prior close (confirm).
   const bool bullish_fakeout = (high1 > high2 &&     // false break above prior high
                                 low1  > low2 &&       // higher low (expanded up)
                                 close1 < high2 &&     // EVENT: closed back inside prior range
                                 close1 < close2);     // weak close vs prior close

   // --- Bearish Fake-Out Day (reversal SELL) — mirror ---
   const bool bearish_fakeout = (low1  < low2 &&       // false break below prior low
                                 high1 < high2 &&      // lower high (expanded down)
                                 close1 > low2 &&       // EVENT: closed back inside prior range
                                 close1 > close2);     // strong close vs prior close

   QM_OrderType otype;
   double sl_price;
   string reason;
   if(bullish_fakeout)
     {
      // Optional close-strength filter: close in the bottom third of the bar.
      if(strategy_require_close_third &&
         !((high1 - close1) > 0.67 * sig_range))
         return false;
      otype    = QM_BUY;
      reason   = "fakeout_day_buy";
     }
   else if(bearish_fakeout)
     {
      // Optional close-strength filter: close in the top third of the bar.
      if(strategy_require_close_third &&
         !((close1 - low1) > 0.67 * sig_range))
         return false;
      otype    = QM_SELL;
      reason   = "fakeout_day_sell";
     }
   else
      return false;

   // --- Stops/targets referenced to the live entry (market fill). ---
   const double stop_buf = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_stop_buffer_pips);
   const double sl_cap   = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);

   const double entry = (otype == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   if(otype == QM_BUY)
      sl_price = QM_StopRulesNormalizePrice(_Symbol, low1  - stop_buf); // Fake-Out Day low - buffer
   else
      sl_price = QM_StopRulesNormalizePrice(_Symbol, high1 + stop_buf); // Fake-Out Day high + buffer

   double risk_dist = MathAbs(entry - sl_price);
   if(risk_dist <= 0.0)
      return false;

   // P2 stop-distance cap: tighten the stop toward the entry if too wide.
   if(sl_cap > 0.0 && risk_dist > sl_cap)
     {
      if(otype == QM_BUY)
         sl_price = QM_StopRulesNormalizePrice(_Symbol, entry - sl_cap);
      else
         sl_price = QM_StopRulesNormalizePrice(_Symbol, entry + sl_cap);
      risk_dist = sl_cap;
     }

   // TP = tp_rr * risk distance from the entry.
   double tp_price;
   if(otype == QM_BUY)
      tp_price = QM_StopRulesNormalizePrice(_Symbol, entry + strategy_tp_rr * risk_dist);
   else
      tp_price = QM_StopRulesNormalizePrice(_Symbol, entry - strategy_tp_rr * risk_dist);

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl_price;
   req.tp     = tp_price;
   req.reason = reason;

   // Latch the entry bar time for the time-stop (this bar[0]).
   g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: single bar-time read
   return true;
  }

// No active SL/TP trailing — the protective stop + RR target are carried on the
// position. (Williams' optional 3-bar trail is a P3 sweep variant.)
void Strategy_ManageOpenPosition()
  {
  }

// Time-stop exit: close at market after strategy_time_stop_bars closed D1 bars
// since entry. Single bar-time comparison; no per-tick history scan.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
     {
      g_entry_bar_time = 0; // flat — reset latch
      return false;
     }
   if(strategy_time_stop_bars <= 0 || g_entry_bar_time == 0)
      return false;

   const datetime cur_bar = iTime(_Symbol, _Period, 0); // perf-allowed: single bar-time read
   if(cur_bar <= 0)
      return false;

   // Bars elapsed = whole D1 periods between entry bar and current bar.
   const long bars_elapsed = (long)((cur_bar - g_entry_bar_time) / (long)PeriodSeconds(_Period));
   if(bars_elapsed >= (long)strategy_time_stop_bars)
      return true;

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

   g_entry_bar_time = 0;
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
      g_entry_bar_time = 0; // closed — reset latch
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
