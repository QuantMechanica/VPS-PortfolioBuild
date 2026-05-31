#property strict
#property version   "5.0"
#property description "QM5_10743 TradingView NQ Opening Range Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10743;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ny_session_start_hhmm  = 930;
input int    strategy_ny_session_end_hhmm    = 1600;
input int    strategy_opening_range_minutes  = 15;
input int    strategy_atr_period             = 14;
input double strategy_min_range_atr_mult     = 0.25;
input double strategy_max_range_atr_mult     = 2.50;
input double strategy_tp_rr                  = 2.00;
input int    strategy_max_spread_points      = 1000;
input int    strategy_or_scan_bars           = 128;

int    g_strategy_session_key = -1;
bool   g_strategy_trade_taken = false;
bool   g_strategy_range_ready = false;
bool   g_strategy_range_valid = false;
double g_strategy_or_high     = 0.0;
double g_strategy_or_low      = 0.0;

int Strategy_HhmmToMinutes(const int hhmm)
  {
   const int hh = hhmm / 100;
   const int mm = hhmm % 100;
   if(hh < 0 || hh > 23 || mm < 0 || mm > 59)
      return -1;
   return hh * 60 + mm;
  }

datetime Strategy_BrokerToNY(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc - (QM_IsUSDSTUTC(utc) ? 4 * 3600 : 5 * 3600);
  }

int Strategy_MinutesOfDayNY(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(Strategy_BrokerToNY(broker_time), dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_DateKeyNY(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(Strategy_BrokerToNY(broker_time), dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_ElapsedFromStart(const int minute, const int start_min)
  {
   if(minute >= start_min)
      return minute - start_min;
   return minute + 1440 - start_min;
  }

bool Strategy_TimeInSession(const int minute, const int start_min, const int end_min)
  {
   if(start_min < 0 || end_min < 0 || start_min == end_min)
      return false;
   if(start_min < end_min)
      return (minute >= start_min && minute < end_min);
   return (minute >= start_min || minute < end_min);
  }

void Strategy_ResetSessionIfNeeded(const datetime broker_time)
  {
   const int key = Strategy_DateKeyNY(broker_time);
   if(key == g_strategy_session_key)
      return;

   g_strategy_session_key = key;
   g_strategy_trade_taken = false;
   g_strategy_range_ready = false;
   g_strategy_range_valid = false;
   g_strategy_or_high = 0.0;
   g_strategy_or_low = 0.0;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_SpreadAllowed()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || bid <= 0.0 || ask <= 0.0 || ask < bid)
      return false;

   return ((ask - bid) / point) <= strategy_max_spread_points;
  }

bool Strategy_ReadLastClosedClose(double &close1)
  {
   close1 = 0.0;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, rates); // perf-allowed: one closed bar read; caller is inside framework QM_IsNewBar gate.
   if(copied != 1)
      return false;
   close1 = rates[0].close;
   return (close1 > 0.0);
  }

void Strategy_BuildOpeningRange()
  {
   if(g_strategy_range_ready)
      return;

   const int start_min = Strategy_HhmmToMinutes(strategy_ny_session_start_hhmm);
   const int end_min = Strategy_HhmmToMinutes(strategy_ny_session_end_hhmm);
   const int now_min = Strategy_MinutesOfDayNY(TimeCurrent());
   if(start_min < 0 || end_min < 0 || strategy_opening_range_minutes <= 0)
      return;
   if(!Strategy_TimeInSession(now_min, start_min, end_min))
      return;
   if(Strategy_ElapsedFromStart(now_min, start_min) < strategy_opening_range_minutes)
      return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int bars = MathMax(4, MathMin(strategy_or_scan_bars, 512));
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, bars, rates); // perf-allowed: bounded opening-range scan; runs only from Strategy_EntrySignal after QM_IsNewBar().
   if(copied <= 0)
      return;

   const int today_key = Strategy_DateKeyNY(TimeCurrent());
   double high = -DBL_MAX;
   double low = DBL_MAX;
   bool found = false;

   for(int i = 0; i < copied; ++i)
     {
      if(Strategy_DateKeyNY(rates[i].time) != today_key)
         continue;

      const int bar_min = Strategy_MinutesOfDayNY(rates[i].time);
      const int elapsed = Strategy_ElapsedFromStart(bar_min, start_min);
      if(elapsed < 0 || elapsed >= strategy_opening_range_minutes)
         continue;
      if(!Strategy_TimeInSession(bar_min, start_min, end_min))
         continue;
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0 || rates[i].high < rates[i].low)
         continue;

      high = MathMax(high, rates[i].high);
      low = MathMin(low, rates[i].low);
      found = true;
     }

   g_strategy_range_ready = true;
   g_strategy_range_valid = false;
   if(!found || high <= low || low <= 0.0)
      return;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double range = high - low;
   if(atr <= 0.0 || range < strategy_min_range_atr_mult * atr || range > strategy_max_range_atr_mult * atr)
      return;

   g_strategy_or_high = high;
   g_strategy_or_low = low;
   g_strategy_range_valid = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   Strategy_ResetSessionIfNeeded(TimeCurrent());

   if(Strategy_HasOpenPosition())
      return false;
   if(g_strategy_trade_taken)
      return true;
   if(!Strategy_SpreadAllowed())
      return true;

   const int start_min = Strategy_HhmmToMinutes(strategy_ny_session_start_hhmm);
   const int end_min = Strategy_HhmmToMinutes(strategy_ny_session_end_hhmm);
   const int now_min = Strategy_MinutesOfDayNY(TimeCurrent());
   if(start_min < 0 || end_min < 0 || strategy_opening_range_minutes <= 0)
      return true;
   if(!Strategy_TimeInSession(now_min, start_min, end_min))
      return true;
   if(Strategy_ElapsedFromStart(now_min, start_min) < strategy_opening_range_minutes)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_ResetSessionIfNeeded(TimeCurrent());

   if(g_strategy_trade_taken || Strategy_HasOpenPosition())
      return false;
   if(strategy_atr_period <= 0 || strategy_min_range_atr_mult <= 0.0 ||
      strategy_max_range_atr_mult <= 0.0 || strategy_tp_rr <= 0.0)
      return false;

   Strategy_BuildOpeningRange();
   if(!g_strategy_range_ready || !g_strategy_range_valid)
      return false;

   double close1 = 0.0;
   if(!Strategy_ReadLastClosedClose(close1))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(close1 > g_strategy_or_high)
     {
      const double entry = ask;
      const double sl = g_strategy_or_low;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(sl > 0.0 && sl < entry && tp > entry)
        {
         req.type = QM_BUY;
         req.price = QM_StopRulesNormalizePrice(_Symbol, entry);
         req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
         req.tp = tp;
         req.reason = "TV_NQ_ORB_LONG";
         g_strategy_trade_taken = true;
         return true;
        }
     }

   if(close1 < g_strategy_or_low)
     {
      const double entry = bid;
      const double sl = g_strategy_or_high;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(sl > entry && tp > 0.0 && tp < entry)
        {
         req.type = QM_SELL;
         req.price = QM_StopRulesNormalizePrice(_Symbol, entry);
         req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
         req.tp = tp;
         req.reason = "TV_NQ_ORB_SHORT";
         g_strategy_trade_taken = true;
         return true;
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, partial-close, or reversal management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const int start_min = Strategy_HhmmToMinutes(strategy_ny_session_start_hhmm);
   const int end_min = Strategy_HhmmToMinutes(strategy_ny_session_end_hhmm);
   if(start_min < 0 || end_min < 0)
      return false;

   return !Strategy_TimeInSession(Strategy_MinutesOfDayNY(TimeCurrent()), start_min, end_min);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
