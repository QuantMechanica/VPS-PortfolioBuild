#property strict
#property version   "5.0"
#property description "QM5_11504 goodwin-kangaroo-tail-d1 — Kangaroo Tail 3-Bar Reversal (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11504 goodwin-kangaroo-tail-d1
// -----------------------------------------------------------------------------
// Source: Jarrod Goodwin, "Beat the Markets — Strategy Guidebook" (~2014).
// Card: artifacts/cards_approved/QM5_11504_goodwin-kangaroo-tail-d1.md
//       (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads at shift 1..3; one EVENT per new daily bar):
//   The "Kangaroo Tail" is a 3-bar swing STATE confirmed once the bar at shift 1
//   closes (Williams-fractal idiom, shared with sibling QM5_11462):
//     LONG  (tail low) : Low[2] < Low[3]  AND  Low[2] < Low[1]   (shift-2 = local min)
//     SHORT (tail high): High[2] > High[3] AND High[2] > High[1] (shift-2 = local max)
//   The single EVENT is the BREAK of bar[1]'s extreme on the new bar: we place a
//   STOP pending order so price must resume in the reversal direction to fill.
//     LONG  : BUY_STOP  at High[1] ; SL = Low[1]  ; TP = High[1] + rr*(High[1]-Low[1])
//     SHORT : SELL_STOP at Low[1]  ; SL = High[1] ; TP = Low[1]  - rr*(High[1]-Low[1])
//   The pending order auto-expires at the end of the current D1 bar (EOD), so an
//   un-filled setup never carries to the next day. A FILLED position runs to its
//   fixed 2:1 TP / structural SL, or is time-exited after a max hold of
//   strategy_max_hold_bars D1 bars (card: "max hold 3 D1 bars").
//
// Filters (card):
//   - Continuation skip : LONG  skip if Close[1] < Close[2] * (1 - filter_pct/100)
//                         SHORT skip if Close[1] > Close[2] * (1 + filter_pct/100)
//                         (card: "skip if Bar3 close beyond Bar2 close by >0.5%").
//   - No-Friday entry   : the most-recent completed (signal) bar[1] must not be a
//                         Friday (card line 52: "skip if Day(Bar[1]) == Friday").
//   - SL distance cap   : skip if the structural stop distance exceeds
//                         strategy_sl_cap_pips (card P2 cap: SL capped at 100 pips).
//   - Spread cap        : block only a genuinely wide spread (card: 30 pips);
//                         fail-OPEN on .DWX zero modeled spread.
//
// .DWX invariants honoured:
//   - Gapless CFDs (open[0]==close[1]): a STOP above High[1] / below Low[1] is a
//     valid pending placement requiring fresh continuation — no gap rule (#6).
//   - Spread guard fails OPEN on zero modeled spread (#1); no swap gate (#2).
//   - All pip thresholds via QM_StopRulesPipsToPriceDistance (pip_factor) so the
//     SL cap and spread cap are scale-correct on 5-digit / JPY symbols (#14).
//   - QM_IsNewBar() consumed once by the framework; the tail STATE + the break
//     EVENT are never required on the same bar — the fractal is read on closed
//     bars 1..3 and the break is a STOP order, so no two-cross trap (#4).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11504;
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
input double strategy_rr                 = 2.0;   // TP = rr * stop distance (card: 2:1)
input double strategy_filter_pct         = 0.5;   // continuation skip threshold (% of tail close)
input int    strategy_sl_cap_pips        = 100;   // skip if structural stop distance > this (pips)
input int    strategy_spread_cap_pips    = 30;    // block only a genuinely wide spread (pips)
input int    strategy_max_hold_bars      = 3;     // time exit after this many D1 bars held
input bool   strategy_block_friday       = true;  // no entry when the signal bar[1] is a Friday

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
// Detects the kangaroo-tail 3-bar swing and places a STOP pending order whose
// break of bar[1]'s extreme is the trigger. Fixed 2:1 TP + structural SL.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   // One working order per magic: no new pending while a position OR pending exists.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(CountPendingForMagic(magic) > 0)
      return false;

   // No-Friday entry: the most-recent completed (signal) bar[1] must not be Friday.
   if(strategy_block_friday)
     {
      MqlDateTime dt;
      TimeToStruct(iTime(_Symbol, _Period, 1), dt); // perf-allowed: single bar-open read
      if(dt.day_of_week == FRIDAY)
         return false;
     }

   // Closed-bar OHLC for the 3-bar swing (shifts 1,2,3). perf-allowed: bespoke
   // structural pattern, fixed single-shift reads (no loops, no warmup window).
   const double low1   = iLow(_Symbol, _Period, 1);
   const double low2   = iLow(_Symbol, _Period, 2);
   const double low3   = iLow(_Symbol, _Period, 3);
   const double high1  = iHigh(_Symbol, _Period, 1);
   const double high2  = iHigh(_Symbol, _Period, 2);
   const double high3  = iHigh(_Symbol, _Period, 3);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   if(low1 <= 0.0 || low2 <= 0.0 || low3 <= 0.0 ||
      high1 <= 0.0 || high2 <= 0.0 || high3 <= 0.0 ||
      close1 <= 0.0 || close2 <= 0.0)
      return false;

   // --- LONG: kangaroo tail LOW (shift-2 = local minimum of the 3 bars) ---
   const bool tail_low  = (low2 < low3 && low2 < low1);
   // --- SHORT: kangaroo tail HIGH (shift-2 = local maximum of the 3 bars) ---
   const bool tail_high = (high2 > high3 && high2 > high1);

   // Swings are mutually exclusive in practice; if both/none, take none.
   if(tail_low == tail_high)
      return false;

   const double filter_frac = strategy_filter_pct / 100.0;
   const double sl_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);

   if(tail_low)
     {
      // Continuation skip: signal bar closed too far BELOW the tail bar close.
      if(close1 < close2 * (1.0 - filter_frac))
         return false;

      const double entry_price = QM_StopRulesNormalizePrice(_Symbol, high1);
      const double sl_price    = QM_StopRulesNormalizePrice(_Symbol, low1);
      if(entry_price <= 0.0 || sl_price <= 0.0 || entry_price <= sl_price)
         return false;

      const double stop_dist = entry_price - sl_price;
      if(sl_cap > 0.0 && stop_dist > sl_cap)
         return false; // structural stop too wide (P2 100-pip cap)

      const double tp_price = QM_StopRulesNormalizePrice(_Symbol, entry_price + strategy_rr * stop_dist);
      if(tp_price <= entry_price)
         return false;

      req.type    = QM_BUY_STOP;
      req.price   = entry_price;
      req.sl      = sl_price;
      req.tp      = tp_price;
      req.reason  = "kangaroo_tail_long";
      req.expiration_seconds = SecondsToEndOfDay(); // cancel un-filled by EOD
      return true;
     }

   // tail_high -> SHORT
   // Continuation skip: signal bar closed too far ABOVE the tail bar close.
   if(close1 > close2 * (1.0 + filter_frac))
      return false;

   const double entry_price = QM_StopRulesNormalizePrice(_Symbol, low1);
   const double sl_price    = QM_StopRulesNormalizePrice(_Symbol, high1);
   if(entry_price <= 0.0 || sl_price <= 0.0 || sl_price <= entry_price)
      return false;

   const double stop_dist = sl_price - entry_price;
   if(sl_cap > 0.0 && stop_dist > sl_cap)
      return false;

   const double tp_price = QM_StopRulesNormalizePrice(_Symbol, entry_price - strategy_rr * stop_dist);
   if(tp_price <= 0.0 || tp_price >= entry_price)
      return false;

   req.type    = QM_SELL_STOP;
   req.price   = entry_price;
   req.sl      = sl_price;
   req.tp      = tp_price;
   req.reason  = "kangaroo_tail_short";
   req.expiration_seconds = SecondsToEndOfDay();
   return true;
  }

// No active management beyond the protective stop + fixed TP; the max-hold time
// exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Max-hold time exit: close any position held for >= strategy_max_hold_bars D1
// bars. POSITION_TIME is the fill time; count the D1 bars elapsed since then.
// Reads position metadata + one bar-open read only.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(strategy_max_hold_bars <= 0)
      return false;

   const int    period_secs  = PeriodSeconds(_Period);
   const datetime cur_bar_open = iTime(_Symbol, _Period, 0); // perf-allowed: single read
   if(period_secs <= 0 || cur_bar_open <= 0)
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
      if(opened <= 0)
         continue;
      // Number of D1 bars elapsed since the fill bar opened.
      const int bars_held = (int)((cur_bar_open - opened) / period_secs) + 1;
      if(bars_held >= strategy_max_hold_bars)
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
