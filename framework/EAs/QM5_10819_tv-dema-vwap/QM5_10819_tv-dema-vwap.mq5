#property strict
#property version   "5.0"
#property description "QM5_10819 TradingView dEMA VWAP Slope Filter"

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
input int    qm_ea_id                   = 10819;
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
input int    strategy_ema_period              = 21;
input int    strategy_slope_confirm_bars      = 1;
input int    strategy_atr_period              = 14;
input double strategy_atr_stop_mult           = 1.8;
input int    strategy_min_session_bars        = 8;
input double strategy_max_spread_stop_fraction = 0.15;
input int    strategy_vwap_anchor             = 0;   // 0 broker day, 1 London, 2 New York
input int    strategy_london_start_hour       = 7;
input int    strategy_ny_start_hour           = 13;
input int    strategy_max_session_scan_bars   = 160;

double g_strategy_vwap = 0.0;
double g_strategy_close = 0.0;
double g_strategy_atr = 0.0;
int    g_strategy_session_bars = 0;
bool   g_strategy_state_ready = false;
bool   g_strategy_long_setup = false;
bool   g_strategy_short_setup = false;
bool   g_strategy_long_exit = false;
bool   g_strategy_short_exit = false;

datetime Strategy_SessionStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);

   int start_hour = 0;
   if(strategy_vwap_anchor == 1)
      start_hour = strategy_london_start_hour;
   else if(strategy_vwap_anchor == 2)
      start_hour = strategy_ny_start_hour;

   if(start_hour < 0)
      start_hour = 0;
   if(start_hour > 23)
      start_hour = 23;

   dt.hour = start_hour;
   dt.min = 0;
   dt.sec = 0;
   datetime session_start = StructToTime(dt);
   if(strategy_vwap_anchor != 0 && t < session_start)
      session_start -= 86400;
   return session_start;
  }

bool Strategy_SameSession(const datetime a, const datetime b)
  {
   return (Strategy_SessionStart(a) == Strategy_SessionStart(b));
  }

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_RefreshClosedBarState()
  {
   g_strategy_vwap = 0.0;
   g_strategy_close = 0.0;
   g_strategy_atr = 0.0;
   g_strategy_session_bars = 0;
   g_strategy_state_ready = false;
   g_strategy_long_setup = false;
   g_strategy_short_setup = false;
   g_strategy_long_exit = false;
   g_strategy_short_exit = false;

   if(strategy_ema_period < 2 ||
      strategy_atr_period < 1 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_min_session_bars < 1 ||
      strategy_max_session_scan_bars < strategy_min_session_bars)
      return false;

   const datetime anchor_time = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar session anchor.
   if(anchor_time <= 0)
      return false;

   const datetime session_start = Strategy_SessionStart(anchor_time);
   double pv_sum = 0.0;
   double vol_sum = 0.0;

   const int max_scan = MathMin(strategy_max_session_scan_bars, 240);
   for(int shift = 1; shift <= max_scan; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, _Period, shift); // perf-allowed: bounded session VWAP scan, called after framework new-bar gate.
      if(bar_time <= 0 || bar_time < session_start || !Strategy_SameSession(bar_time, anchor_time))
         break;

      const double high = iHigh(_Symbol, _Period, shift);       // perf-allowed: bespoke VWAP needs OHLCV.
      const double low = iLow(_Symbol, _Period, shift);
      const double close = iClose(_Symbol, _Period, shift);
      const long tick_volume = iVolume(_Symbol, _Period, shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0)
         continue;

      const double volume = (tick_volume > 0) ? (double)tick_volume : 1.0;
      pv_sum += ((high + low + close) / 3.0) * volume;
      vol_sum += volume;
      g_strategy_session_bars++;

      if(shift == 1)
         g_strategy_close = close;
     }

   if(vol_sum <= 0.0 || g_strategy_session_bars < strategy_min_session_bars)
      return false;

   g_strategy_vwap = pv_sum / vol_sum;
   g_strategy_atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double ema1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   const double ema2 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1 + strategy_slope_confirm_bars);
   const double ema3 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1 + 2 * strategy_slope_confirm_bars);
   if(g_strategy_vwap <= 0.0 || g_strategy_atr <= 0.0 || ema1 <= 0.0 || ema2 <= 0.0 || ema3 <= 0.0 || g_strategy_close <= 0.0)
      return false;

   const bool slope_up_now = (ema1 > ema2);
   const bool slope_up_prev = (ema2 > ema3);
   const bool slope_down_now = (ema1 < ema2);
   const bool slope_down_prev = (ema2 < ema3);

   g_strategy_long_setup = (ema1 < g_strategy_vwap && slope_up_now && !slope_up_prev);
   g_strategy_short_setup = (ema1 > g_strategy_vwap && slope_down_now && !slope_down_prev);
   g_strategy_long_exit = ((ema1 > g_strategy_vwap && slope_down_now && !slope_down_prev) ||
                           g_strategy_close < g_strategy_vwap);
   g_strategy_short_exit = ((ema1 < g_strategy_vwap && slope_up_now && !slope_up_prev) ||
                            g_strategy_close > g_strategy_vwap);
   g_strategy_state_ready = true;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
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

   if(!Strategy_RefreshClosedBarState())
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(Strategy_SelectOurPosition(ticket, ptype, open_time))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double stop_distance = strategy_atr_stop_mult * g_strategy_atr;
   const double spread = ask - bid;
   if(stop_distance <= point || spread <= 0.0 || spread > strategy_max_spread_stop_fraction * stop_distance)
      return false;

   if(g_strategy_long_setup)
     {
      req.type = QM_BUY;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, ask, g_strategy_atr, strategy_atr_stop_mult);
      req.reason = "dema_vwap_slope_long";
      return (req.sl > 0.0 && req.sl < ask - point);
     }

   if(g_strategy_short_setup)
     {
      req.type = QM_SELL;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, bid, g_strategy_atr, strategy_atr_stop_mult);
      req.reason = "dema_vwap_slope_short";
      return (req.sl > bid + point);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or scale logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, ptype, open_time))
      return false;

   if(!Strategy_SameSession(open_time, TimeCurrent()))
      return true;

   if(!g_strategy_state_ready)
      return false;

   if(ptype == POSITION_TYPE_BUY)
      return g_strategy_long_exit;
   if(ptype == POSITION_TYPE_SELL)
      return g_strategy_short_exit;

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
