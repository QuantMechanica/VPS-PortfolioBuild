#property strict
#property version   "5.0"
#property description "QM5_11447 burke-parabolic-short-squeeze-m5 — Burke Parabolic Short Squeeze, M5 EMA20 continuation (M5+D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11447 burke-parabolic-short-squeeze-m5
// -----------------------------------------------------------------------------
// Source: Stacey Burke Trading Playbook (Part 2). Parabolic Short Squeeze.
// Card: artifacts/cards_approved/QM5_11447_burke-parabolic-short-squeeze-m5.md
//       (g0_status APPROVED).
//
// Mechanics (M5 execution, D1 pattern; all reads on CLOSED bars):
//   D1 PATTERN (gapless-safe — uses prior CLOSE vs prior LOW/HIGH, never gaps):
//     Short-squeeze setup (LONG) — three consecutive D1 lower closes, a false
//       breakdown on Day 3 (new lower low), and a bullish reversal close:
//         Close[D1,1] < Close[D1,2] AND Close[D1,2] < Close[D1,3] AND
//         Close[D1,3] < Close[D1,4]                       (3 lower closes)
//         Low[D1,1]   < Low[D1,2]                         (Day-3 false breakdown)
//         Close[D1,1] > Open[D1,1]                        (Day-3 bullish reversal)
//     Mirror setup (SHORT) — three consecutive higher closes, a false breakout
//       on Day 3 (new higher high), and a bearish reversal close:
//         Close[D1,1] > Close[D1,2] AND Close[D1,2] > Close[D1,3] AND
//         Close[D1,3] > Close[D1,4]                       (3 higher closes)
//         High[D1,1]  > High[D1,2]                        (Day-3 false breakout)
//         Close[D1,1] < Open[D1,1]                        (Day-3 bearish reversal)
//     The two cannot both be true. The pattern is a STATE read each M5 closed
//     bar from the last fully-closed D1 bars (shift >= 1), so it is stable
//     through the trade day.
//
//   M5 TRIGGER (the single EVENT): the first EMA20 cross in the squeeze
//     direction during the trade day.
//     LONG : Close[M5,1] > EMA20[M5,1] AND Close[M5,2] <= EMA20[M5,2]
//            (the just-closed bar closed above the EMA; the prior was at/below)
//     SHORT: Close[M5,1] < EMA20[M5,1] AND Close[M5,2] >= EMA20[M5,2]
//     One cross event per bar; the squeeze setup is the STATE, the cross is the
//     trigger. (Card states Close[M5,0] vs EMA20[M5,0]; on the closed-bar gate
//     the just-closed bar is shift 1 — gapless-safe equivalent.)
//
//   SESSION FILTER (broker time): only inside the London or NY window. Card
//     states London + NY. Windows are evaluated by converting the bar's broker
//     time to UTC via QM_BrokerToUTC and comparing against UTC hour windows
//     (no raw broker-hour windows — Invariant #5).
//
//   STOP / TAKE (pips, scale-correct via QM_StopFixedPips / QM_TakeFixedPips):
//     SL = 20 pips (card LONG -20 pips; P2 cap 25), TP = 50 pips (card minimum).
//
//   Spread guard: fail-OPEN on .DWX zero modeled spread — only a genuinely wide
//     spread blocks (Invariant #1).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11447;
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
input int    strategy_pattern_bars       = 3;      // consecutive D1 closes in the decline/advance
input int    strategy_ema_period         = 20;     // M5 EMA for the cross trigger
input int    strategy_sl_pips            = 20;     // stop-loss distance (pips), card SL cap 25
input int    strategy_tp_pips            = 50;     // take-profit distance (pips), card minimum
// Session windows in UTC (card: London + NY). London 07:00-12:00, NY 13:00-17:00.
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

// D1 parabolic-squeeze pattern read from CLOSED daily bars (shift >= 1).
// Returns +1 short-squeeze setup (LONG), -1 mirror setup (SHORT), 0 = none.
// Uses prior CLOSE/LOW/HIGH/OPEN of fully-closed bars (gapless-safe).
int SqueezeDirection()
  {
   const int n = strategy_pattern_bars;     // consecutive lower/higher closes
   if(n < 1)
      return 0;

   // --- Short-squeeze (LONG): n consecutive lower D1 closes ---
   bool decline = true;
   for(int k = 1; k <= n; ++k)
     {
      const double c     = iClose(_Symbol, PERIOD_D1, k);     // perf-allowed: fixed closed-bar reads
      const double c_prev = iClose(_Symbol, PERIOD_D1, k + 1);
      if(c <= 0.0 || c_prev <= 0.0 || !(c < c_prev))
        {
         decline = false;
         break;
        }
     }
   if(decline)
     {
      // Day-3 false breakdown (new lower low) + bullish reversal close.
      const double low1  = iLow(_Symbol, PERIOD_D1, 1);
      const double low2  = iLow(_Symbol, PERIOD_D1, 2);
      const double open1 = iOpen(_Symbol, PERIOD_D1, 1);
      const double close1 = iClose(_Symbol, PERIOD_D1, 1);
      if(low1 > 0.0 && low2 > 0.0 && open1 > 0.0 && close1 > 0.0 &&
         low1 < low2 && close1 > open1)
         return +1;   // short squeeze -> BUY the continuation
     }

   // --- Mirror (SHORT): n consecutive higher D1 closes ---
   bool advance = true;
   for(int k = 1; k <= n; ++k)
     {
      const double c     = iClose(_Symbol, PERIOD_D1, k);     // perf-allowed: fixed closed-bar reads
      const double c_prev = iClose(_Symbol, PERIOD_D1, k + 1);
      if(c <= 0.0 || c_prev <= 0.0 || !(c > c_prev))
        {
         advance = false;
         break;
        }
     }
   if(advance)
     {
      // Day-3 false breakout (new higher high) + bearish reversal close.
      const double high1 = iHigh(_Symbol, PERIOD_D1, 1);
      const double high2 = iHigh(_Symbol, PERIOD_D1, 2);
      const double open1 = iOpen(_Symbol, PERIOD_D1, 1);
      const double close1 = iClose(_Symbol, PERIOD_D1, 1);
      if(high1 > 0.0 && high2 > 0.0 && open1 > 0.0 && close1 > 0.0 &&
         high1 > high2 && close1 < open1)
         return -1;   // false breakout -> SELL the reversal
     }

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

// Entry: D1 squeeze STATE + M5 EMA20 cross EVENT in the squeeze direction,
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

   // --- D1 squeeze STATE ---
   const int dir = SqueezeDirection();
   if(dir == 0)
      return false;

   // --- M5 EMA20 cross EVENT (single event on the just-closed bar) ---
   const double ema1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema2 = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   const double close1 = iClose(_Symbol, _Period, 1);   // perf-allowed: closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2);   // perf-allowed: closed-bar read
   if(ema1 <= 0.0 || ema2 <= 0.0 || close1 <= 0.0 || close2 <= 0.0)
      return false;

   QM_OrderType side;
   if(dir > 0)
     {
      // Short squeeze -> BUY on a first close ABOVE the EMA (was at/below).
      const bool crossed_up = (close1 > ema1 && close2 <= ema2);
      if(!crossed_up)
         return false;
      side = QM_BUY;
     }
   else
     {
      // False-breakout reversal -> SELL on a first close BELOW the EMA (was at/above).
      const bool crossed_down = (close1 < ema1 && close2 >= ema2);
      if(!crossed_down)
         return false;
      side = QM_SELL;
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
   req.reason = (side == QM_BUY) ? "burke_squeeze_long" : "burke_squeeze_short";
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
