#property strict
#property version   "5.0"
#property description "QM5_10131 TradingView Nifty Range Short Reversal"

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
input int    qm_ea_id                   = 10131;
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
input int    strategy_atr_period           = 14;
input int    strategy_open_range_minutes   = 60;
input double strategy_min_range_atr_mult   = 0.5;
input double strategy_max_range_atr_mult   = 2.5;
input double strategy_range_sl_atr_mult    = 0.5;
input double strategy_entry_sl_atr_mult    = 1.5;
input double strategy_max_spread_stop_frac = 0.10;
input int    strategy_dax_start_hour       = 9;
input int    strategy_dax_start_minute     = 0;
input int    strategy_dax_end_hour         = 17;
input int    strategy_dax_end_minute       = 30;
input int    strategy_us_start_hour        = 15;
input int    strategy_us_start_minute      = 30;
input int    strategy_us_end_hour          = 22;
input int    strategy_us_end_minute        = 0;

int      g_strategy_day_key        = -1;
bool     g_strategy_range_ready    = false;
bool     g_strategy_range_valid    = false;
bool     g_strategy_swept_high     = false;
bool     g_strategy_trade_taken    = false;
double   g_strategy_range_high     = 0.0;
double   g_strategy_range_low      = 0.0;
double   g_strategy_last_high      = 0.0;
double   g_strategy_last_low       = 0.0;
double   g_strategy_last_close     = 0.0;
datetime g_strategy_session_start  = 0;
datetime g_strategy_range_end      = 0;
datetime g_strategy_session_end    = 0;

int Strategy_HhmmToMinutes(const int hour_value, const int minute_value)
  {
   return hour_value * 60 + minute_value;
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime Strategy_DayTime(const datetime t, const int hour_value, const int minute_value)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = hour_value;
   dt.min = minute_value;
   dt.sec = 0;
   return StructToTime(dt);
  }

void Strategy_SessionTimes(const datetime t,
                           datetime &session_start,
                           datetime &range_end,
                           datetime &session_end)
  {
   int start_h = strategy_us_start_hour;
   int start_m = strategy_us_start_minute;
   int end_h = strategy_us_end_hour;
   int end_m = strategy_us_end_minute;

   if(_Symbol == "GDAXI.DWX" || _Symbol == "DAX.DWX" || _Symbol == "DE30.DWX")
     {
      start_h = strategy_dax_start_hour;
      start_m = strategy_dax_start_minute;
      end_h = strategy_dax_end_hour;
      end_m = strategy_dax_end_minute;
     }

   session_start = Strategy_DayTime(t, start_h, start_m);
   range_end = session_start + strategy_open_range_minutes * 60;
   session_end = Strategy_DayTime(t, end_h, end_m);
   if(session_end <= session_start)
      session_end += 24 * 60 * 60;
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

void Strategy_ResetSession(const datetime broker_time)
  {
   g_strategy_day_key = Strategy_DayKey(broker_time);
   g_strategy_range_ready = false;
   g_strategy_range_valid = false;
   g_strategy_swept_high = false;
   g_strategy_trade_taken = false;
   g_strategy_range_high = 0.0;
   g_strategy_range_low = 0.0;
   g_strategy_last_high = 0.0;
   g_strategy_last_low = 0.0;
   g_strategy_last_close = 0.0;
   Strategy_SessionTimes(broker_time,
                         g_strategy_session_start,
                         g_strategy_range_end,
                         g_strategy_session_end);
  }

void Strategy_UpdateOpeningRange()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
      return;

   if(g_strategy_day_key != Strategy_DayKey(bar_time))
      Strategy_ResetSession(bar_time);

   if(bar_time < g_strategy_session_start || bar_time >= g_strategy_session_end)
      return;

   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return;

   g_strategy_last_high = high1;
   g_strategy_last_low = low1;
   g_strategy_last_close = close1;

   if(bar_time < g_strategy_range_end)
     {
      if(g_strategy_range_high <= 0.0 || high1 > g_strategy_range_high)
         g_strategy_range_high = high1;
      if(g_strategy_range_low <= 0.0 || low1 < g_strategy_range_low)
         g_strategy_range_low = low1;
      return;
     }

   if(!g_strategy_range_ready)
     {
      const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      const double range_height = g_strategy_range_high - g_strategy_range_low;
      g_strategy_range_valid = (atr > 0.0 &&
                                range_height >= strategy_min_range_atr_mult * atr &&
                                range_height <= strategy_max_range_atr_mult * atr);
      g_strategy_range_ready = true;
     }

   if(g_strategy_range_ready && g_strategy_range_valid && high1 > g_strategy_range_high)
      g_strategy_swept_high = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   if(g_strategy_day_key != Strategy_DayKey(broker_now))
      Strategy_ResetSession(broker_now);

   return (broker_now < g_strategy_session_start || broker_now >= g_strategy_session_end);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_10131_OR_SWEEP_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_UpdateOpeningRange();

   if(g_strategy_trade_taken || Strategy_HasOpenPosition())
      return false;
   if(!g_strategy_range_ready || !g_strategy_range_valid || !g_strategy_swept_high)
      return false;

   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time < g_strategy_range_end || bar_time >= g_strategy_session_end)
      return false;

   const double close1 = g_strategy_last_close;
   if(close1 <= 0.0 || close1 >= g_strategy_range_high)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(bid <= 0.0 || ask <= 0.0 || point <= 0.0 || atr <= 0.0)
      return false;

   const double sl_from_range = g_strategy_range_high + strategy_range_sl_atr_mult * atr;
   const double sl_from_entry = bid + strategy_entry_sl_atr_mult * atr;
   const double sl = MathMax(sl_from_range, sl_from_entry);
   const double stop_distance = sl - bid;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > strategy_max_spread_stop_frac * stop_distance)
      return false;

   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(g_strategy_range_low, _Digits);
   if(req.tp <= 0.0 || req.tp >= bid)
      req.tp = 0.0;

   g_strategy_trade_taken = true;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed exits only: opening-range low TP, session-end, and close back above range high.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   if(g_strategy_day_key != Strategy_DayKey(broker_now))
      Strategy_ResetSession(broker_now);

   if(broker_now >= g_strategy_session_end)
      return true;

   if(!g_strategy_range_ready || g_strategy_range_high <= 0.0)
      return false;

   const double close1 = g_strategy_last_close;
   if(close1 > g_strategy_range_high)
      return true;

   return false;
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
