#property strict
#property version   "5.0"
#property description "QM5_11443 burke-day3-breakout-trap-m5 — Burke 3-Day Breakout Trap, M5 EMA20 fade (M5+D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11443 burke-day3-breakout-trap-m5
// -----------------------------------------------------------------------------
// Source: Stacey Burke Trading Playbook (Part 2). 3-Day Breakout Trap.
// Card: artifacts/cards_approved/QM5_11443_burke-day3-breakout-trap-m5.md
//       (g0_status APPROVED).
//
// Mechanics (M5 execution, D1 pattern; all reads on CLOSED bars):
//   D1 PATTERN (gapless-safe — uses prior CLOSE vs prior HIGH/LOW, never gaps):
//     Bearish trap (fade DOWN on the current day) — three consecutive D1 closes
//       each above the prior day's high:
//         Close[D1,1] > High[D1,2] AND
//         Close[D1,2] > High[D1,3] AND
//         Close[D1,3] > High[D1,4]
//       (literal Implementation-Notes form from the card.)
//     Bullish trap (fade UP) — mirror with closes below prior day's low:
//         Close[D1,1] < Low[D1,2] AND
//         Close[D1,2] < Low[D1,3] AND
//         Close[D1,3] < Low[D1,4]
//     The two cannot both be true. Pattern is a STATE read each M5 closed bar
//     from the last fully-closed D1 bars (shift >= 1), so it is stable through
//     the trade day.
//
//   M5 TRIGGER (the single EVENT): EMA20 cross-back in the fade direction.
//     SHORT: Close[M5,1] < EMA20[M5,1] AND Close[M5,2] >= EMA20[M5,2]
//            (the just-closed bar closed back below the EMA; the prior was above)
//     LONG : Close[M5,1] > EMA20[M5,1] AND Close[M5,2] <= EMA20[M5,2]
//     One cross event per bar; the trap is the STATE, the cross is the trigger.
//
//   SESSION FILTER (broker time): only inside London or NY window. The card
//     states London 07:00-12:00 GMT and NY 13:00-17:00 GMT (UTC). DXZ broker
//     clock is UTC+2 / UTC+3 (US-DST aware), so windows are evaluated by
//     converting the bar's broker time to UTC via QM_BrokerToUTC and comparing
//     against the UTC hour windows. No raw broker-hour windows (Invariant #5).
//
//   STOP / TAKE (pips, scale-correct via QM_StopFixedPips/QM_TakeFixedPips):
//     SL = 20 pips, TP = 50 pips (card P2 SL cap 25; 20 is within cap).
//
//   Spread guard: fail-OPEN on .DWX zero modeled spread — only a genuinely wide
//     spread blocks (Invariant #1).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11443;
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
input int    strategy_pattern_bars       = 3;      // consecutive D1 closes beyond prior extreme
input int    strategy_ema_period         = 20;     // M5 EMA for the cross-back trigger
input int    strategy_sl_pips            = 20;     // stop-loss distance (pips), card SL cap 25
input int    strategy_tp_pips            = 50;     // take-profit distance (pips)
// Session windows in UTC (card: London 07:00-12:00 GMT, NY 13:00-17:00 GMT).
input int    strategy_london_start_utc   = 7;      // London window start hour (UTC, inclusive)
input int    strategy_london_end_utc     = 12;     // London window end hour (UTC, exclusive)
input int    strategy_ny_start_utc       = 13;     // NY window start hour (UTC, inclusive)
input int    strategy_ny_end_utc         = 17;     // NY window end hour (UTC, exclusive)
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (file-scope, cheap)
// -----------------------------------------------------------------------------

// True when the bar's broker time falls inside the London or NY UTC window.
bool InSessionWindow(const datetime broker_now)
  {
   const datetime utc = QM_BrokerToUTC(broker_now);
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   const int h = dt.hour;

   const bool in_london = (h >= strategy_london_start_utc && h < strategy_london_end_utc);
   const bool in_ny     = (h >= strategy_ny_start_utc     && h < strategy_ny_end_utc);
   return (in_london || in_ny);
  }

// D1 three-bar trap pattern read from CLOSED daily bars (shift >= 1).
// Returns +1 bullish trap (fade UP / BUY), -1 bearish trap (fade DOWN / SELL),
// 0 = no pattern. Uses prior CLOSE vs prior HIGH/LOW (gapless-safe).
int TrapDirection()
  {
   const int n = strategy_pattern_bars;     // consecutive bars to confirm
   if(n < 1)
      return 0;

   // Bearish trap: each of the last n D1 closes is above the prior day's high.
   bool bear = true;
   for(int k = 1; k <= n; ++k)
     {
      const double c = iClose(_Symbol, PERIOD_D1, k);     // perf-allowed: fixed closed-bar reads
      const double hi_prev = iHigh(_Symbol, PERIOD_D1, k + 1);
      if(c <= 0.0 || hi_prev <= 0.0 || !(c > hi_prev))
        {
         bear = false;
         break;
        }
     }
   if(bear)
      return -1;   // fade the up-extension -> SELL

   // Bullish trap: each of the last n D1 closes is below the prior day's low.
   bool bull = true;
   for(int k = 1; k <= n; ++k)
     {
      const double c = iClose(_Symbol, PERIOD_D1, k);     // perf-allowed: fixed closed-bar reads
      const double lo_prev = iLow(_Symbol, PERIOD_D1, k + 1);
      if(c <= 0.0 || lo_prev <= 0.0 || !(c < lo_prev))
        {
         bull = false;
         break;
        }
     }
   if(bull)
      return +1;   // fade the down-extension -> BUY

   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: spread guard only. Fail-OPEN on .DWX zero spread.
// Session/pattern work is on the closed-bar path in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry: D1 trap STATE + M5 EMA20 cross-back EVENT in the fade direction,
// inside the London/NY session window. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Session window (broker -> UTC), evaluated on the just-closed M5 bar ---
   const datetime bar_open = iTime(_Symbol, _Period, 1);   // perf-allowed: closed-bar time
   if(bar_open <= 0)
      return false;
   if(!InSessionWindow(bar_open))
      return false;

   // --- D1 trap STATE ---
   const int dir = TrapDirection();
   if(dir == 0)
      return false;

   // --- M5 EMA20 cross-back EVENT (single event on the just-closed bar) ---
   const double ema1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema2 = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   const double close1 = iClose(_Symbol, _Period, 1);   // perf-allowed: closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2);   // perf-allowed: closed-bar read
   if(ema1 <= 0.0 || ema2 <= 0.0 || close1 <= 0.0 || close2 <= 0.0)
      return false;

   QM_OrderType side;
   if(dir < 0)
     {
      // Bearish trap -> SELL on a close-back BELOW the EMA (was above, now below).
      const bool crossed_back_down = (close1 < ema1 && close2 >= ema2);
      if(!crossed_back_down)
         return false;
      side = QM_SELL;
     }
   else
     {
      // Bullish trap -> BUY on a close-back ABOVE the EMA (was below, now above).
      const bool crossed_back_up = (close1 > ema1 && close2 <= ema2);
      if(!crossed_back_up)
         return false;
      side = QM_BUY;
     }

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "burke_day3_trap_long" : "burke_day3_trap_short";
   return true;
  }

// Fixed SL/TP only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// SL/TP handle the exit; no discretionary close.
bool Strategy_ExitSignal()
  {
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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
