#property strict
#property version   "5.0"
#property description "QM5_11442 burke-frd-fgd-daily-pump-m5 — Burke FRD/FGD daily pump -> M5 EMA20 fade"

#include <QM/QM_Common.mqh>
#include <QM/QM_DSTAware.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11442 burke-frd-fgd-daily-pump-m5
// -----------------------------------------------------------------------------
// Source: Stacey Burke, "The Stacey Burke Trading Playbook" (self-published).
// Card: artifacts/cards_approved/QM5_11442_burke-frd-fgd-daily-pump-m5.md
//       (g0_status APPROVED).
//
// Mechanics (M5 execution, D1 pattern detection on prior CLOSED daily bars):
//
//   D1 pattern (read on closed daily bars: shift 1 = yesterday "Day 2",
//               shift 2 = "Day 1" the pump, shift 3 = the reference day):
//     FRD (SHORT setup):
//       1. Close[D1,2] > High[D1,3]                 (Day 1 pump above prior High)
//       2. Close[D1,1] < Open[D1,1]                 (Day 2 closed below its open)
//          AND Open[D1,1] >= Close[D1,2]            (Day 2 opened at/above Day1 close)
//       3. Close[D1,1] < Close[D1,2]                (Day 2 close below Day 1 close)
//     FGD (LONG setup, mirror):
//       1. Close[D1,2] < Low[D1,3]
//       2. Close[D1,1] > Open[D1,1] AND Open[D1,1] <= Close[D1,2]
//       3. Close[D1,1] > Close[D1,2]
//
//   M5 trigger EVENT (Day 3 execution, one trade per broker day per symbol):
//     SHORT: inside the London/NY session, the first M5 bar that closes back
//            below EMA20 (close[1] < EMA20[1]) -> SELL.
//     LONG : mirror, close[1] > EMA20[1] -> BUY.
//
//   Stops/targets are fixed pips (scale-correct via QM_StopRules pip distance):
//     SL = stop_pips, capped at sl_cap_pips (P2 cap = 25).
//     TP = tp_pips (~50, Burke target).
//   Time stop: close any open position at/after session-end broker hour.
//
//   Sessions are evaluated in UTC (London 07:00-12:00, NY 13:00-17:00 GMT) by
//   converting the M5 bar-open broker time via QM_BrokerToUTC. .DWX symbols are
//   gapless and quote zero modeled spread; the spread guard fails OPEN.
//
//   News caveat (documented card limitation): Burke requires "no major red
//   news" on Day 3. Not mechanizable here beyond the central QM news filter;
//   Strategy_NewsFilterHook defers to the framework filter.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11442;
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
input int    strategy_ema_period         = 20;      // M5 EMA period (execution trigger)
input bool   strategy_session_london     = true;    // allow London session entries
input bool   strategy_session_ny         = true;    // allow NY session entries
input int    strategy_london_start_utc   = 7;       // London window start hour (UTC)
input int    strategy_london_end_utc     = 12;      // London window end hour (UTC, exclusive)
input int    strategy_ny_start_utc       = 13;      // NY window start hour (UTC)
input int    strategy_ny_end_utc         = 17;      // NY window end hour (UTC, exclusive)
input double strategy_tp_pips            = 50.0;     // take-profit distance (pips)
input double strategy_sl_pips            = 20.0;     // stop-loss distance (pips)
input double strategy_sl_cap_pips        = 25.0;     // P2 stop cap (pips)
input double strategy_spread_pct_of_stop = 15.0;     // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope state: latch one entry per broker day per symbol (Day-3 guard).
// Keyed off the M5 bar-open broker time's day-of-year, NOT a new-bar gate
// (the framework owns the new-bar gate). This is a per-day trade latch only.
// -----------------------------------------------------------------------------
int g_last_trade_yday  = -1;   // broker day-of-year that already produced a trade
int g_last_trade_year  = -1;

// Returns the effective stop distance in pips (capped).
double EffectiveStopPips()
  {
   double sp = strategy_sl_pips;
   if(strategy_sl_cap_pips > 0.0 && sp > strategy_sl_cap_pips)
      sp = strategy_sl_cap_pips;
   return sp;
  }

// True if the given UTC datetime falls inside an enabled session window.
bool InSessionUTC(const datetime utc)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   const int h = dt.hour;

   if(strategy_session_london &&
      h >= strategy_london_start_utc && h < strategy_london_end_utc)
      return true;
   if(strategy_session_ny &&
      h >= strategy_ny_start_utc && h < strategy_ny_end_utc)
      return true;
   return false;
  }

// True once both session windows have ended for the current UTC time (time stop).
bool PastSessionEndUTC(const datetime utc)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   const int h = dt.hour;

   int last_end = -1;
   if(strategy_session_london && strategy_london_end_utc > last_end)
      last_end = strategy_london_end_utc;
   if(strategy_session_ny && strategy_ny_end_utc > last_end)
      last_end = strategy_ny_end_utc;
   if(last_end < 0)
      return false;       // no session enabled -> never force-close on time
   return (h >= last_end);
  }

// -----------------------------------------------------------------------------
// D1 pattern detection on prior CLOSED daily bars. +1 = FGD (long), -1 = FRD
// (short), 0 = no pattern. Uses single closed-bar OHLC reads (structural
// geometry; perf-allowed, gated by the framework new-bar path in EntrySignal).
// -----------------------------------------------------------------------------
int DetectDailyPattern()
  {
   // Day 1 = D1 shift 2 (the pump), Day 2 = D1 shift 1 (the reversal),
   // reference day = D1 shift 3.
   const double close_d1 = iClose(_Symbol, PERIOD_D1, 2); // perf-allowed: Day 1 close
   const double high_d3  = iHigh(_Symbol, PERIOD_D1, 3);  // perf-allowed: reference High
   const double low_d3   = iLow(_Symbol, PERIOD_D1, 3);   // perf-allowed: reference Low
   const double open_d2  = iOpen(_Symbol, PERIOD_D1, 1);  // perf-allowed: Day 2 open
   const double close_d2 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: Day 2 close

   if(close_d1 <= 0.0 || high_d3 <= 0.0 || low_d3 <= 0.0 ||
      open_d2 <= 0.0 || close_d2 <= 0.0)
      return 0;

   // FRD (SHORT): pump above prior High, then bearish reversal bar below Day1 close.
   const bool frd = (close_d1 > high_d3) &&
                    (close_d2 < open_d2) &&
                    (open_d2 >= close_d1) &&
                    (close_d2 < close_d1);
   if(frd)
      return -1;

   // FGD (LONG, mirror): dump below prior Low, then bullish reversal bar above Day1 close.
   const bool fgd = (close_d1 < low_d3) &&
                    (close_d2 > open_d2) &&
                    (open_d2 <= close_d1) &&
                    (close_d2 > close_d1);
   if(fgd)
      return 1;

   return 0;
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

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)EffectiveStopPips());
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// M5 entry. Caller guarantees QM_IsNewBar() == true (closed M5 bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Session window (broker -> UTC) on the just-closed M5 bar's open time ---
   const datetime bar_broker = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar time
   if(bar_broker <= 0)
      return false;
   const datetime bar_utc = QM_BrokerToUTC(bar_broker);
   if(!InSessionUTC(bar_utc))
      return false;

   // --- One trade per broker day per symbol (Day-3 guard) ---
   MqlDateTime bdt;
   ZeroMemory(bdt);
   TimeToStruct(bar_broker, bdt);
   if(g_last_trade_year == bdt.year && g_last_trade_yday == bdt.day_of_year)
      return false;

   // --- D1 pattern (FRD short / FGD long) ---
   const int pattern = DetectDailyPattern();
   if(pattern == 0)
      return false;

   // --- M5 EMA20 trigger: first closed bar that closes back across EMA20 ---
   const double ema_now  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_prev = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar close
   const double close2   = iClose(_Symbol, _Period, 2); // perf-allowed: prior closed close
   if(ema_now <= 0.0 || ema_prev <= 0.0 || close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double entry = (pattern < 0)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_BID)   // SELL fills at bid
                        : SymbolInfoDouble(_Symbol, SYMBOL_ASK);  // BUY fills at ask
   if(entry <= 0.0)
      return false;

   const double sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)EffectiveStopPips());
   const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_tp_pips);
   if(sl_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   if(pattern < 0)
     {
      // SHORT: trigger EVENT = first M5 bar that closes back below EMA20.
      // close2 >= ema_prev (was at/above) AND close1 < ema_now (closed below now).
      const bool crossed_below = (close2 >= ema_prev) && (close1 < ema_now);
      if(!crossed_below)
         return false;

      req.type  = QM_SELL;
      req.price = 0.0;
      req.sl    = QM_StopRulesNormalizePrice(_Symbol, entry + sl_dist);
      req.tp    = QM_StopRulesNormalizePrice(_Symbol, entry - tp_dist);
      req.reason = "burke_frd_short";
     }
   else
     {
      // LONG: trigger EVENT = first M5 bar that closes back above EMA20.
      const bool crossed_above = (close2 <= ema_prev) && (close1 > ema_now);
      if(!crossed_above)
         return false;

      req.type  = QM_BUY;
      req.price = 0.0;
      req.sl    = QM_StopRulesNormalizePrice(_Symbol, entry - sl_dist);
      req.tp    = QM_StopRulesNormalizePrice(_Symbol, entry + tp_dist);
      req.reason = "burke_fgd_long";
     }

   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   // Latch the day so only one entry fires per broker day per symbol.
   g_last_trade_year = bdt.year;
   g_last_trade_yday = bdt.day_of_year;
   return true;
  }

// No active trade management beyond the fixed SL/TP. Time stop is in ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Time stop: close the open position once both session windows have ended.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const datetime now_broker = TimeCurrent();
   if(now_broker <= 0)
      return false;
   const datetime now_utc = QM_BrokerToUTC(now_broker);
   return PastSessionEndUTC(now_utc);
  }

// Defer to the central news filter (Burke "no red news" is a documented,
// non-mechanizable limitation beyond the central QM news gate).
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
