#property strict
#property version   "5.0"
#property description "QM5_10240 TradingView VWAP ORB Pullback"

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
input int    qm_ea_id                   = 10240;
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
input int    strategy_or_start_hhmm_ny          = 930;
input int    strategy_or_minutes                = 15;
input int    strategy_session_end_hhmm_ny       = 1600;
input int    strategy_ema_period                = 9;
input int    strategy_atr_period                = 14;
input double strategy_atr_sl_mult               = 1.0;
input double strategy_take_profit_rr            = 1.5;
input double strategy_vwap_pullback_atr_tolerance = 0.25;

int    g_session_day_key       = 0;
double g_or_high               = 0.0;
double g_or_low                = 0.0;
bool   g_or_ready              = false;
int    g_breakout_dir          = 0;
double g_vwap_pv_sum           = 0.0;
double g_vwap_volume_sum       = 0.0;
double g_session_vwap          = 0.0;

datetime BrokerToNewYork(const datetime broker_time)
  {
   const datetime utc = QM_BrokerToUTC(broker_time);
   return utc + (QM_IsUSDSTUTC(utc) ? -4 * 3600 : -5 * 3600);
  }

int DayKeyNY(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(BrokerToNewYork(broker_time), dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int HhmmNY(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(BrokerToNewYork(broker_time), dt);
   return dt.hour * 100 + dt.min;
  }

int HhmmAddMinutes(const int hhmm, const int minutes)
  {
   const int hh = hhmm / 100;
   const int mm = hhmm % 100;
   const int total = hh * 60 + mm + minutes;
   return (total / 60) * 100 + (total % 60);
  }

void ResetSessionState(const int day_key)
  {
   g_session_day_key = day_key;
   g_or_high = 0.0;
   g_or_low = 0.0;
   g_or_ready = false;
   g_breakout_dir = 0;
   g_vwap_pv_sum = 0.0;
   g_vwap_volume_sum = 0.0;
   g_session_vwap = 0.0;
  }

bool HasOpenStrategyPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool ReadClosedSignalBar(MqlRates &bar)
  {
   MqlRates rates[1];
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, rates); // perf-allowed: one closed chart-period bar for bespoke ORB/VWAP state inside framework new-bar gate.
   if(copied != 1)
      return false;

   bar = rates[0];
   return (bar.time > 0 && bar.high > 0.0 && bar.low > 0.0 && bar.close > 0.0);
  }

void AdvanceVwapAndOpeningRange(const datetime bar_time,
                                const double high1,
                                const double low1,
                                const double close1,
                                const long tick_volume1)
  {
   const int day_key = DayKeyNY(bar_time);
   if(day_key != g_session_day_key)
      ResetSessionState(day_key);

   const int hhmm = HhmmNY(bar_time);
   if(hhmm < strategy_or_start_hhmm_ny || hhmm >= strategy_session_end_hhmm_ny)
      return;

   const double volume = (double)MathMax((long)1, tick_volume1);
   const double typical = (high1 + low1 + close1) / 3.0;
   g_vwap_pv_sum += typical * volume;
   g_vwap_volume_sum += volume;
   if(g_vwap_volume_sum > 0.0)
      g_session_vwap = NormalizeDouble(g_vwap_pv_sum / g_vwap_volume_sum, _Digits);

   const int or_end = HhmmAddMinutes(strategy_or_start_hhmm_ny, MathMax(1, strategy_or_minutes));
   if(hhmm >= strategy_or_start_hhmm_ny && hhmm < or_end)
     {
      g_or_high = (g_or_high <= 0.0) ? high1 : MathMax(g_or_high, high1);
      g_or_low = (g_or_low <= 0.0) ? low1 : MathMin(g_or_low, low1);
      g_or_ready = false;
      return;
     }

   if(!g_or_ready && hhmm >= or_end && g_or_high > g_or_low)
      g_or_ready = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   const int hhmm = HhmmNY(broker_now);
   if(hhmm >= strategy_session_end_hhmm_ny && !HasOpenStrategyPosition())
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

   if(HasOpenStrategyPosition())
      return false;

   MqlRates bar;
   if(!ReadClosedSignalBar(bar))
      return false;

   AdvanceVwapAndOpeningRange(bar.time, bar.high, bar.low, bar.close, bar.tick_volume);

   const int hhmm = HhmmNY(bar.time);
   const int or_end = HhmmAddMinutes(strategy_or_start_hhmm_ny, MathMax(1, strategy_or_minutes));
   if(!g_or_ready || hhmm < or_end || hhmm >= strategy_session_end_hhmm_ny)
      return false;

   const ENUM_TIMEFRAMES signal_tf = (ENUM_TIMEFRAMES)_Period;
   const double ema9 = QM_EMA(_Symbol, signal_tf, strategy_ema_period, 1);
   const double atr = QM_ATR(_Symbol, signal_tf, strategy_atr_period, 1);
   if(ema9 <= 0.0 || atr <= 0.0 || g_session_vwap <= 0.0)
      return false;

   if(g_breakout_dir == 0)
     {
      if(bar.close > g_or_high && bar.close > g_session_vwap && bar.close > ema9)
         g_breakout_dir = 1;
      else if(bar.close < g_or_low && bar.close < g_session_vwap && bar.close < ema9)
         g_breakout_dir = -1;
      return false;
     }

   const double tolerance = MathMax(0.0, strategy_vwap_pullback_atr_tolerance) * atr;
   QM_OrderType side;
   bool entry_ok = false;

   if(g_breakout_dir > 0)
     {
      side = QM_BUY;
      entry_ok = (bar.close > g_session_vwap &&
                  bar.close > ema9 &&
                  bar.low <= g_session_vwap + tolerance);
     }
   else
     {
      side = QM_SELL;
      entry_ok = (bar.close < g_session_vwap &&
                  bar.close < ema9 &&
                  bar.high >= g_session_vwap - tolerance);
     }

   if(!entry_ok)
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = QM_TakeRR(_Symbol, side, entry, req.sl, strategy_take_profit_rr);
   req.reason = (side == QM_BUY) ? "TV_VWAP_ORB_PULL_LONG" : "TV_VWAP_ORB_PULL_SHORT";
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline has static ATR SL and RR TP only.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!HasOpenStrategyPosition())
      return false;
   if(HhmmNY(TimeCurrent()) >= strategy_session_end_hhmm_ny)
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
