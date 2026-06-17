#property strict
#property version   "5.0"
#property description "QM5_10418 Elite Trader SMA5 Intraday Trend"

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
input int    qm_ea_id                   = 10418;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_M2;
input int             strategy_sma_period         = 5;     // card: SMA length 5 (sweep 5/8/10 in P3)
input int             strategy_atr_period         = 20;    // card: ATR(20) emergency stop
input double          strategy_atr_stop_mult      = 1.0;   // card: 1.0 * ATR (sweep 0.75/1.0/1.5)
input bool            strategy_distance_gate_on   = true;  // card: distance gate baseline ON
input double          strategy_distance_min_pct   = 0.05;  // card: lower bound 0.05% of SMA
input double          strategy_distance_max_pct   = 3.0;   // card: upper bound 3.0% of SMA
// Session windows are expressed in EXCHANGE local wall-clock (ET for US index
// cash). The card trades the first two hours and the last hour of the index
// cash session. US cash open = 09:30 ET, close = 16:00 ET, so:
//   first two hours = 09:30..11:30 ET ; last hour = 15:00..16:00 ET.
// DXZ broker time = NY-close GMT+2/+3 (DST-aware). ET = UTC-5/-4. Because BOTH
// ET and broker time shift together on the US-DST boundary, the ET->broker
// offset is a CONSTANT +7 hours year-round. We add that fixed offset to the
// exchange-local window so the window stays anchored to the cash session across
// the DST boundary (invariant #5) WITHOUT per-tick DST math. For a non-US-ET
// session (e.g. DAX/CET) a setfile can override these four hhmm values and the
// offset; see open_questions.
input int             strategy_exch_to_broker_offset_h = 7;     // ET->DXZ-broker = +7h constant
input int             strategy_session1_start_hhmm     = 930;   // 09:30 ET cash open
input int             strategy_session1_end_hhmm       = 1130;  // 11:30 ET (first two hours)
input int             strategy_session2_start_hhmm     = 1500;  // 15:00 ET (last hour start)
input int             strategy_session2_end_hhmm       = 1600;  // 16:00 ET cash close

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Convert an exchange-local HHMM to a broker-time HHMM using the fixed
// exchange->broker hour offset. Returns minutes-of-day in broker time so the
// caller can compare against the current broker bar time. Wrap-safe across
// midnight (result kept in [0,1440)).
int Strategy_ExchHHMMToBrokerMinutes(const int exch_hhmm)
  {
   const int exch_min = (exch_hhmm / 100) * 60 + (exch_hhmm % 100);
   int broker_min = exch_min + strategy_exch_to_broker_offset_h * 60;
   broker_min %= 1440;
   if(broker_min < 0)
      broker_min += 1440;
   return broker_min;
  }

// TRUE if the current broker bar-open time falls inside either trade window.
// Keyed off the open time of the forming bar (iTime shift 0), per invariant #12
// (do not gate on exact tick minute).
bool Strategy_InTradeWindow()
  {
   const datetime bar_open = iTime(_Symbol, strategy_signal_tf, 0);
   if(bar_open <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(bar_open, dt);
   const int now_min = dt.hour * 60 + dt.min;

   const int s1_start = Strategy_ExchHHMMToBrokerMinutes(strategy_session1_start_hhmm);
   const int s1_end   = Strategy_ExchHHMMToBrokerMinutes(strategy_session1_end_hhmm);
   const int s2_start = Strategy_ExchHHMMToBrokerMinutes(strategy_session2_start_hhmm);
   const int s2_end   = Strategy_ExchHHMMToBrokerMinutes(strategy_session2_end_hhmm);

   const bool in_first = (now_min >= s1_start && now_min < s1_end);
   const bool in_last  = (now_min >= s2_start && now_min < s2_end);
   return (in_first || in_last);
  }

// TRUE if this EA already holds a position on the current symbol/magic.
bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != strategy_signal_tf)
      return true;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int now_hhmm = dt.hour * 100 + dt.min;
   const bool in_first = (now_hhmm >= strategy_session1_start_hhmm && now_hhmm < strategy_session1_end_hhmm);
   const bool in_last = (now_hhmm >= strategy_session2_start_hhmm && now_hhmm < strategy_session2_end_hhmm);
   return !(in_first || in_last);
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

   if((ENUM_TIMEFRAMES)_Period != strategy_signal_tf)
      return false;
   if(strategy_sma_period <= 1 || strategy_atr_period <= 0 || strategy_atr_stop_mult <= 0.0)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int now_hhmm = dt.hour * 100 + dt.min;
   const bool in_first = (now_hhmm >= strategy_session1_start_hhmm && now_hhmm < strategy_session1_end_hhmm);
   const bool in_last = (now_hhmm >= strategy_session2_start_hhmm && now_hhmm < strategy_session2_end_hhmm);
   if(!(in_first || in_last))
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const double close1 = iClose(_Symbol, strategy_signal_tf, 1);
   const double sma1 = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_period, 1);
   const double sma2 = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_period, 2);
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(close1 <= 0.0 || sma1 <= 0.0 || sma2 <= 0.0 || atr <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   const double stop_distance = strategy_atr_stop_mult * atr;
   if(stop_distance <= 0.0 || stop_distance < 4.0 * (ask - bid))
      return false;

   const double min_frac = strategy_distance_min_pct / 100.0;
   const double max_frac = strategy_distance_max_pct / 100.0;

   if(close1 > sma1 && sma1 > sma2)
     {
      const double dist_frac = (close1 - sma1) / sma1;
      if(strategy_distance_gate_on && (dist_frac < min_frac || dist_frac > max_frac))
         return false;
      req.type = QM_BUY;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, ask, atr, strategy_atr_stop_mult);
      req.tp = 0.0;
      req.reason = "QM5_10418_SMA5_TREND_LONG";
      return (req.sl > 0.0);
     }

   if(close1 < sma1 && sma1 < sma2)
     {
      const double dist_frac = (sma1 - close1) / sma1;
      if(strategy_distance_gate_on && (dist_frac < min_frac || dist_frac > max_frac))
         return false;
      req.type = QM_SELL;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, bid, atr, strategy_atr_stop_mult);
      req.tp = 0.0;
      req.reason = "QM5_10418_SMA5_TREND_SHORT";
      return (req.sl > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies only the initial ATR emergency stop; no trailing, BE, or partial management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if((ENUM_TIMEFRAMES)_Period != strategy_signal_tf)
      return false;

   const int magic = QM_FrameworkMagic();
   bool have_position = false;
   bool is_buy = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      have_position = true;
      is_buy = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      break;
     }
   if(!have_position)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int now_hhmm = dt.hour * 100 + dt.min;
   const bool in_first = (now_hhmm >= strategy_session1_start_hhmm && now_hhmm < strategy_session1_end_hhmm);
   const bool in_last = (now_hhmm >= strategy_session2_start_hhmm && now_hhmm < strategy_session2_end_hhmm);
   if(!(in_first || in_last))
      return true;

   const double close1 = iClose(_Symbol, strategy_signal_tf, 1);
   const double sma1 = QM_SMA(_Symbol, strategy_signal_tf, strategy_sma_period, 1);
   const double low_prev = iLow(_Symbol, strategy_signal_tf, 2);
   const double high_prev = iHigh(_Symbol, strategy_signal_tf, 2);
   if(close1 <= 0.0 || sma1 <= 0.0 || low_prev <= 0.0 || high_prev <= 0.0)
      return false;

   if(is_buy)
      return (close1 < sma1 || close1 < low_prev);

   return (close1 > sma1 || close1 > high_prev);
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   (void)broker_time;
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
