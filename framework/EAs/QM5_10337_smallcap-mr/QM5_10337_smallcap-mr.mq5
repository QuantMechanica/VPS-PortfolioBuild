#property strict
#property version   "5.0"
#property description "QM5_10337 smallcap-mr"

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
input int    qm_ea_id                   = 10337;
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
input double strategy_extreme_mult              = 1.25;
input int    strategy_realized_vol_lookback     = 20;
input int    strategy_volume_sessions           = 60;
input int    strategy_spread_lookback           = 80;
input double strategy_spread_percentile         = 80.0;
input int    strategy_atr_period                = 14;
input double strategy_atr_sl_mult               = 1.00;
input double strategy_min_stop_spreads          = 4.00;
input int    strategy_max_hold_bars             = 4;
input int    strategy_cash_session_start_hhmm   = 1530;
input int    strategy_cash_session_end_hhmm     = 2200;
input int    strategy_session_exclude_minutes   = 15;

#define STRATEGY_M15_SLOTS 96
#define STRATEGY_MAX_VOLUME_SESSIONS 60
#define STRATEGY_MAX_SPREAD_LOOKBACK 128
#define STRATEGY_MAX_RV_LOOKBACK 200
#define STRATEGY_MAX_M5_SESSION_BARS 288

double   g_volume_history[STRATEGY_M15_SLOTS][STRATEGY_MAX_VOLUME_SESSIONS];
int      g_volume_count[STRATEGY_M15_SLOTS];
int      g_volume_next[STRATEGY_M15_SLOTS];
double   g_spread_history[STRATEGY_MAX_SPREAD_LOOKBACK];
int      g_spread_count = 0;
int      g_spread_next = 0;

bool     g_state_ready = false;
bool     g_volume_ok = false;
bool     g_spread_ok = false;
bool     g_trade_taken_session = false;
int      g_session_date_key = 0;
datetime g_closed_bar_time = 0;
double   g_last_close = 0.0;
double   g_prev_close = 0.0;
double   g_session_vwap = 0.0;
double   g_realized_vol_price = 0.0;

int Strategy_ClampInt(const int value, const int lo, const int hi)
  {
   if(value < lo)
      return lo;
   if(value > hi)
      return hi;
   return value;
  }

double Strategy_ClampDouble(const double value, const double lo, const double hi)
  {
   if(value < lo)
      return lo;
   if(value > hi)
      return hi;
   return value;
  }

int Strategy_HHMM(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_HHMMToMinutes(const int hhmm)
  {
   const int bounded = Strategy_ClampInt(hhmm, 0, 2359);
   const int h = Strategy_ClampInt(bounded / 100, 0, 23);
   const int m = Strategy_ClampInt(bounded % 100, 0, 59);
   return h * 60 + m;
  }

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

void Strategy_ResetSessionIfNeeded(const datetime t)
  {
   const int key = Strategy_DateKey(t);
   if(key <= 0 || key == g_session_date_key)
      return;
   g_session_date_key = key;
   g_trade_taken_session = false;
  }

bool Strategy_InLiquidSession(const datetime t)
  {
   const int start_min = Strategy_HHMMToMinutes(strategy_cash_session_start_hhmm);
   const int end_min = Strategy_HHMMToMinutes(strategy_cash_session_end_hhmm);
   const int pad = Strategy_ClampInt(strategy_session_exclude_minutes, 0, 120);
   const int now_min = Strategy_MinutesOfDay(t);

   int active_start = start_min + pad;
   int active_end = end_min - pad;
   if(active_start < 0)
      active_start = 0;
   if(active_end > 24 * 60)
      active_end = 24 * 60;
   if(active_start >= active_end)
      return false;
   return (now_min >= active_start && now_min < active_end);
  }

int Strategy_M15Slot(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return Strategy_ClampInt(dt.hour * 4 + (dt.min / 15), 0, STRATEGY_M15_SLOTS - 1);
  }

void Strategy_SortAscending(double &values[], const int count)
  {
   for(int i = 1; i < count; ++i)
     {
      const double key = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > key)
        {
         values[j + 1] = values[j];
         --j;
        }
      values[j + 1] = key;
     }
  }

double Strategy_Median(double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;
   Strategy_SortAscending(values, count);
   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return 0.5 * (values[mid - 1] + values[mid]);
  }

double Strategy_Percentile(double &values[], const int count, const double percentile)
  {
   if(count <= 0)
      return 0.0;
   Strategy_SortAscending(values, count);
   const double p = Strategy_ClampDouble(percentile, 0.0, 100.0);
   int idx = (int)MathCeil((p / 100.0) * count) - 1;
   idx = Strategy_ClampInt(idx, 0, count - 1);
   return values[idx];
  }

double Strategy_CurrentSpreadPoints()
  {
   const long spread_raw = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_raw > 0)
      return (double)spread_raw;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(point <= 0.0 || bid <= 0.0 || ask <= 0.0 || ask <= bid)
      return 0.0;
   return (ask - bid) / point;
  }

void Strategy_StoreVolumeSample(const int slot, const double volume, const int max_sessions)
  {
   if(slot < 0 || slot >= STRATEGY_M15_SLOTS || volume <= 0.0)
      return;
   const int cap = Strategy_ClampInt(max_sessions, 1, STRATEGY_MAX_VOLUME_SESSIONS);
   g_volume_history[slot][g_volume_next[slot]] = volume;
   g_volume_next[slot] = (g_volume_next[slot] + 1) % cap;
   if(g_volume_count[slot] < cap)
      g_volume_count[slot]++;
  }

void Strategy_StoreSpreadSample(const double spread_points, const int max_samples)
  {
   if(spread_points <= 0.0)
      return;
   const int cap = Strategy_ClampInt(max_samples, 1, STRATEGY_MAX_SPREAD_LOOKBACK);
   g_spread_history[g_spread_next] = spread_points;
   g_spread_next = (g_spread_next + 1) % cap;
   if(g_spread_count < cap)
      g_spread_count++;
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ptype = POSITION_TYPE_BUY;
   open_time = 0;
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
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_HasOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   return Strategy_HasOpenPosition(ptype, open_time);
  }

bool Strategy_ComputeSessionVwap(const datetime bar_time, double &vwap)
  {
   vwap = 0.0;
   MqlRates m5[];
   ArraySetAsSeries(m5, true);
   const int copied = CopyRates(_Symbol, PERIOD_M5, 1, STRATEGY_MAX_M5_SESSION_BARS, m5); // perf-allowed: closed-bar session VWAP state refresh only.
   if(copied <= 0)
      return false;

   const int date_key = Strategy_DateKey(bar_time);
   const int start_min = Strategy_HHMMToMinutes(strategy_cash_session_start_hhmm);
   double pv_sum = 0.0;
   double vol_sum = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      if(m5[i].time > bar_time)
         continue;
      if(Strategy_DateKey(m5[i].time) != date_key)
         continue;
      if(Strategy_MinutesOfDay(m5[i].time) < start_min)
         continue;

      const double volume = (double)m5[i].tick_volume;
      if(volume <= 0.0 || m5[i].high <= 0.0 || m5[i].low <= 0.0 || m5[i].close <= 0.0)
         continue;
      const double typical = (m5[i].high + m5[i].low + m5[i].close) / 3.0;
      pv_sum += typical * volume;
      vol_sum += volume;
     }

   if(vol_sum <= 0.0)
      return false;
   vwap = pv_sum / vol_sum;
   return (vwap > 0.0);
  }

bool Strategy_ReadClosedBarState()
  {
   g_state_ready = false;
   g_volume_ok = false;
   g_spread_ok = false;
   g_last_close = 0.0;
   g_prev_close = 0.0;
   g_session_vwap = 0.0;
   g_realized_vol_price = 0.0;

   const int rv_lookback = Strategy_ClampInt(strategy_realized_vol_lookback, 2, STRATEGY_MAX_RV_LOOKBACK);
   const int rates_needed = rv_lookback + 1;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M15, 1, rates_needed, rates); // perf-allowed: closed-bar M15 realized-vol and volume state refresh only.
   if(copied < rates_needed)
      return false;

   g_closed_bar_time = rates[0].time;
   g_last_close = rates[0].close;
   g_prev_close = rates[1].close;
   if(g_closed_bar_time <= 0 || g_last_close <= 0.0 || g_prev_close <= 0.0)
      return false;
   Strategy_ResetSessionIfNeeded(g_closed_bar_time);

   double diffs[STRATEGY_MAX_RV_LOOKBACK];
   double mean = 0.0;
   for(int i = 0; i < rv_lookback; ++i)
     {
      if(rates[i].close <= 0.0 || rates[i + 1].close <= 0.0)
         return false;
      diffs[i] = rates[i].close - rates[i + 1].close;
      mean += diffs[i];
     }
   mean /= rv_lookback;

   double variance = 0.0;
   for(int i = 0; i < rv_lookback; ++i)
     {
      const double d = diffs[i] - mean;
      variance += d * d;
     }
   variance /= rv_lookback;
   g_realized_vol_price = MathSqrt(variance);
   if(g_realized_vol_price <= 0.0)
      return false;

   if(!Strategy_ComputeSessionVwap(g_closed_bar_time, g_session_vwap))
      return false;

   const int slot = Strategy_M15Slot(g_closed_bar_time);
   const int volume_sessions = Strategy_ClampInt(strategy_volume_sessions, 1, STRATEGY_MAX_VOLUME_SESSIONS);
   const double current_volume = (double)rates[0].tick_volume;
   if(g_volume_count[slot] >= volume_sessions && current_volume > 0.0)
     {
      double samples[];
      ArrayResize(samples, volume_sessions);
      for(int i = 0; i < volume_sessions; ++i)
         samples[i] = g_volume_history[slot][i];
      const double median = Strategy_Median(samples, volume_sessions);
      g_volume_ok = (median > 0.0 && current_volume > median);
     }
   Strategy_StoreVolumeSample(slot, current_volume, volume_sessions);

   const int spread_lookback = Strategy_ClampInt(strategy_spread_lookback, 1, STRATEGY_MAX_SPREAD_LOOKBACK);
   const double current_spread = Strategy_CurrentSpreadPoints();
   if(g_spread_count >= spread_lookback && current_spread > 0.0)
     {
      double spread_samples[];
      ArrayResize(spread_samples, spread_lookback);
      for(int i = 0; i < spread_lookback; ++i)
         spread_samples[i] = g_spread_history[i];
      const double spread_limit = Strategy_Percentile(spread_samples, spread_lookback, strategy_spread_percentile);
      g_spread_ok = (spread_limit > 0.0 && current_spread < spread_limit);
     }
   Strategy_StoreSpreadSample(current_spread, spread_lookback);

   g_state_ready = true;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOpenPosition())
      return false;
   return !Strategy_InLiquidSession(TimeCurrent());
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

   Strategy_ReadClosedBarState();

   if(Strategy_HasOpenPosition())
      return false;
   if(g_trade_taken_session)
      return false;
   if(!g_state_ready || !g_volume_ok || !g_spread_ok)
      return false;
   if(!Strategy_InLiquidSession(g_closed_bar_time))
      return false;

   const double threshold = strategy_extreme_mult * g_realized_vol_price;
   const double last_return = g_last_close - g_prev_close;
   const bool go_long = (g_last_close <= g_session_vwap - threshold && last_return < 0.0);
   const bool go_short = (g_last_close >= g_session_vwap + threshold && last_return > 0.0);
   if(!go_long && !go_short)
      return false;

   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;
   const double entry_price = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double spread_points = Strategy_CurrentSpreadPoints();
   if(sl <= 0.0 || point <= 0.0 || spread_points <= 0.0)
      return false;

   const double sl_points = MathAbs(entry_price - sl) / point;
   if(sl_points < strategy_min_stop_spreads * spread_points)
      return false;

   req.type = side;
   req.price = entry_price;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = go_long ? "SMALLCAP_MR_LONG_VWAP_FADE" : "SMALLCAP_MR_SHORT_VWAP_FADE";
   req.symbol_slot = qm_magic_slot_offset;
   g_trade_taken_session = true;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!Strategy_HasOpenPosition(ptype, open_time))
      return false;

   if(!Strategy_InLiquidSession(TimeCurrent()))
      return true;

   const int hold_seconds = strategy_max_hold_bars * PeriodSeconds(PERIOD_M15);
   if(hold_seconds > 0 && open_time > 0 && (TimeCurrent() - open_time) >= hold_seconds)
      return true;

   if(g_session_vwap <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid > 0.0 && bid >= g_session_vwap);
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (ask > 0.0 && ask <= g_session_vwap);
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
