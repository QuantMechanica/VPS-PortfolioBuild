#property strict
#property version   "5.0"
#property description "QM5_11581 goodwin-kangaroo-tail-breakout-d1 — Kangaroo Tail 3-Bar Breakout (USDJPY D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11581 goodwin-kangaroo-tail-breakout-d1
// -----------------------------------------------------------------------------
// Source: Jarrod Goodwin, "Beat the Markets Strategy Guidebook" (~2020), Strategy 2.
// Card: artifacts/cards_approved/QM5_11581_goodwin-kangaroo-tail-breakout-d1.md
//       (g0_status APPROVED).
//
// The "Kangaroo Tail" here is Goodwin's 3-bar reversal pattern (not the single
// pin-bar variant). The MIDDLE of the last three closed bars (shift 2) must hold
// the lowest low (long setup) or the highest high (short setup) of the three —
// a long-wicked rejection extreme protruding from the prior two bars. The pattern
// is a STATE confirmed once the bar at shift 1 closes; the single EVENT is the
// BREAK of that bar's extreme, expressed as a STOP pending order so price must
// resume in the breakout direction to fill.
//
// Mechanics (D1, closed-bar reads at shift 1..3; one EVENT per new daily bar):
//   Card bar naming -> framework shifts: Bar3=shift1 (last closed), Bar2=shift2
//   (middle), Bar1=shift3 (oldest of the three).
//     LONG  (tail low) : Low[2] < Low[3]  AND  Low[2] < Low[1]   (shift-2 = local min)
//     SHORT (tail high): High[2] > High[3] AND  High[2] > High[1] (shift-2 = local max)
//   Continuation (0.5%) filter, per card Implementation Notes:
//     LONG  skip if (Close[1] - Close[2]) / Close[2] * 100 >  filter_pct
//     SHORT skip if (Close[2] - Close[1]) / Close[2] * 100 >  filter_pct
//   Entry / stop on the new bar:
//     LONG  : BUY_STOP  at High[1] + offset ; SL = Low[1]  - offset
//     SHORT : SELL_STOP at Low[1]  - offset ; SL = High[1] + offset
//   SL minimum floor (card): if the structural stop is closer than sl_floor_pips,
//   widen it to the floor so a small-range breakout bar never produces a near-zero
//   stop (JPY pip = 0.01, so 20 pips = 0.20).
//   The pending order auto-expires at the end of the current D1 bar (EOD) so an
//   un-filled setup never carries to the next day. A FILLED position is held
//   intraday and time-exited when a new D1 bar forms (same-session EOD proxy).
//   No fixed take-profit.
//
// Filters (card):
//   - 0.5% continuation filter (above).
//   - No-Friday entry: the breakout (current D1) bar must not be a Friday.
//   - Bar-range cap: skip if breakout bar[1] range exceeds range_cap_pips.
//   - Spread cap: block only a genuinely wide spread (fail-open on .DWX zero spread).
//
// .DWX invariants honoured:
//   - Gapless CFDs/FX (open[0]==close[1]): a STOP above High[1] / below Low[1]
//     requires fresh continuation — no gap rule (#6).
//   - Spread guard fails OPEN on zero modeled spread (#1).
//   - All pip thresholds via QM_StopRulesPipsToPriceDistance (pip_factor) so the
//     offset / range cap / SL floor are scale-correct on JPY (#14).
//   - QM_IsNewBar() consumed once by the framework; one entry EVENT per D1 bar (#3,#4).
//   - No swap gate (#2); no exact-minute gate (#12).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11581;
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
input double strategy_filter_pct        = 0.5;   // skip if breakout bar close ran >this% past the tail bar close
input int    strategy_offset_pips       = 1;     // pip offset added beyond High[1]/Low[1] for entry & stop
input int    strategy_sl_floor_pips     = 20;    // minimum stop distance (card floor; JPY 20 pips = 0.20)
input int    strategy_range_cap_pips    = 200;   // skip if breakout bar[1] range exceeds this (pips)
input int    strategy_spread_cap_pips   = 10;    // block only a genuinely wide spread (pips)
input bool   strategy_block_friday      = true;  // no entries on a Friday breakout bar

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

// Count pending orders for this EA's magic (structural; not indicator math).
int CountPendingForMagic(const int magic)
  {
   int count = 0;
   const int total = OrdersTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) == magic)
         count++;
     }
   return count;
  }

// Seconds remaining until the end of the current D1 bar (EOD expiry for pending).
int SecondsToEndOfDay()
  {
   const datetime bar_open = iTime(_Symbol, _Period, 0); // perf-allowed: single bar-open read
   if(bar_open <= 0)
      return 0;
   const int period_secs = PeriodSeconds(_Period);
   const int remaining = (int)((bar_open + period_secs) - TimeCurrent());
   return (remaining > 0) ? remaining : 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — defer, do not block

   const double spread = ask - bid;
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   // Block only a genuinely wide, positive spread; zero modeled spread passes.
   if(cap > 0.0 && spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (one closed-bar EVENT per day).
// Detects the kangaroo-tail 3-bar pattern and places a STOP pending order whose
// break of bar[1]'s extreme is the single trigger.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   // One working order per magic: no new pending while a position OR pending exists.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(CountPendingForMagic(magic) > 0)
      return false;

   // No-Friday entry: the breakout (current D1) bar must not be a Friday.
   if(strategy_block_friday)
     {
      MqlDateTime dt;
      TimeToStruct(iTime(_Symbol, _Period, 0), dt); // perf-allowed: single bar-open read
      if(dt.day_of_week == FRIDAY)
         return false;
     }

   // Closed-bar OHLC for the 3-bar pattern (shifts 1,2,3). perf-allowed:
   // bespoke structural pattern, fixed single-shift reads (no loops, no warmup).
   const double low1  = iLow(_Symbol, _Period, 1);
   const double low2  = iLow(_Symbol, _Period, 2);
   const double low3  = iLow(_Symbol, _Period, 3);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double high2 = iHigh(_Symbol, _Period, 2);
   const double high3 = iHigh(_Symbol, _Period, 3);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   if(low1 <= 0.0 || low2 <= 0.0 || low3 <= 0.0 ||
      high1 <= 0.0 || high2 <= 0.0 || high3 <= 0.0 ||
      close1 <= 0.0 || close2 <= 0.0)
      return false;

   // Range cap on the breakout bar[1] (stop width control).
   const double range_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_range_cap_pips);
   if(range_cap > 0.0 && (high1 - low1) > range_cap)
      return false;

   const double offset    = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_offset_pips);
   const double sl_floor  = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_floor_pips);

   // --- LONG: kangaroo tail LOW (shift-2 = local minimum of the 3 bars) ---
   const bool tail_low = (low2 < low3 && low2 < low1);
   // --- SHORT: kangaroo tail HIGH (shift-2 = local maximum of the 3 bars) ---
   const bool tail_high = (high2 > high3 && high2 > high1);

   // The two setups are mutually exclusive in practice; if both/none, take none.
   if(tail_low == tail_high)
      return false;

   const double filter_frac = strategy_filter_pct / 100.0;

   if(tail_low)
     {
      // Continuation filter: skip if bar[1] already closed >filter_pct ABOVE bar[2].
      if(close2 > 0.0 && (close1 - close2) / close2 > filter_frac)
         return false;

      double entry_price = high1 + offset;
      double sl_price    = low1  - offset;
      // SL floor: widen the stop down if it is closer than the floor to entry.
      if(sl_floor > 0.0 && (entry_price - sl_price) < sl_floor)
         sl_price = entry_price - sl_floor;

      entry_price = QM_StopRulesNormalizePrice(_Symbol, entry_price);
      sl_price    = QM_StopRulesNormalizePrice(_Symbol, sl_price);
      if(entry_price <= 0.0 || sl_price <= 0.0 || entry_price <= sl_price)
         return false;

      req.type    = QM_BUY_STOP;
      req.price   = entry_price;
      req.sl      = sl_price;
      req.tp      = 0.0;                 // time-exit only; no fixed target
      req.reason  = "kangaroo_tail_long";
      req.expiration_seconds = SecondsToEndOfDay(); // cancel un-filled by EOD
      return true;
     }

   // tail_high -> SHORT
   // Continuation filter: skip if bar[1] already closed >filter_pct BELOW bar[2].
   if(close2 > 0.0 && (close2 - close1) / close2 > filter_frac)
      return false;

   double entry_price_s = low1  - offset;
   double sl_price_s    = high1 + offset;
   // SL floor: widen the stop up if it is closer than the floor to entry.
   if(sl_floor > 0.0 && (sl_price_s - entry_price_s) < sl_floor)
      sl_price_s = entry_price_s + sl_floor;

   entry_price_s = QM_StopRulesNormalizePrice(_Symbol, entry_price_s);
   sl_price_s    = QM_StopRulesNormalizePrice(_Symbol, sl_price_s);
   if(entry_price_s <= 0.0 || sl_price_s <= 0.0 || sl_price_s <= entry_price_s)
      return false;

   req.type    = QM_SELL_STOP;
   req.price   = entry_price_s;
   req.sl      = sl_price_s;
   req.tp      = 0.0;
   req.reason  = "kangaroo_tail_short";
   req.expiration_seconds = SecondsToEndOfDay();
   return true;
  }

// No active management beyond the protective stop; time-exit lives in ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Time exit (EOD same-session proxy): close any position that was opened on a
// PRIOR D1 bar. POSITION_TIME is the fill time; if a new D1 bar has formed since
// then the same-session hold is over -> close. Reads position metadata only.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const datetime cur_bar_open = iTime(_Symbol, _Period, 0); // perf-allowed: single read
   if(cur_bar_open <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      // Filled before the current D1 bar opened -> a new session has begun.
      if(opened > 0 && opened < cur_bar_open)
         return true;
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
