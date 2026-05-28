#property strict
#property version   "5.0"
#property description "QM5_10387 Elite Trader Stochastic Fixed Range Breakout"

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
input int    qm_ea_id                   = 10387;
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
input int    strategy_stoch_k_period          = 14;
input int    strategy_stoch_d_period          = 3;
input int    strategy_stoch_slowing           = 3;
input double strategy_trigger_threshold       = 90.0;
input int    strategy_atr_period              = 20;
input double strategy_atr_stop_cap_mult       = 1.0;
input double strategy_min_range_spreads       = 6.0;
input int    strategy_session_start_hour      = 0;
input int    strategy_session_end_hour        = 24;
input int    strategy_no_entry_final_minutes  = 30;

int    g_session_key = -1;
bool   g_range_frozen = false;
double g_session_high = 0.0;
double g_session_low = 0.0;
double g_buy_signal = 0.0;
double g_sell_signal = 0.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

bool Strategy_InSession(const datetime t)
  {
   const int minute = Strategy_MinutesOfDay(t);
   const int start_minute = strategy_session_start_hour * 60;
   int end_hour = strategy_session_end_hour;
   if(end_hour < 0)
      end_hour = 0;
   if(end_hour > 24)
      end_hour = 24;
   const int end_minute = end_hour * 60;

   if(start_minute == end_minute)
      return true;
   if(start_minute < end_minute)
      return (minute >= start_minute && minute < end_minute);
   return (minute >= start_minute || minute < end_minute);
  }

bool Strategy_InFinalEntryBlock(const datetime t)
  {
   int end_hour = strategy_session_end_hour;
   if(end_hour <= 0 || end_hour > 24)
      end_hour = 24;
   const int cutoff = end_hour * 60 - MathMax(strategy_no_entry_final_minutes, 0);
   return (Strategy_MinutesOfDay(t) >= cutoff);
  }

void Strategy_ResetSession(const int day_key)
  {
   g_session_key = day_key;
   g_range_frozen = false;
   g_session_high = 0.0;
   g_session_low = 0.0;
   g_buy_signal = 0.0;
   g_sell_signal = 0.0;
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &position_type)
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
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool Strategy_RangeWideEnough()
  {
   if(!g_range_frozen || g_buy_signal <= g_sell_signal)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread = ask - bid;
   if(spread <= 0.0)
      return false;

   return ((g_buy_signal - g_sell_signal) >= spread * strategy_min_range_spreads);
  }

double Strategy_StopForEntry(const QM_OrderType side, const double entry)
  {
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_stop_cap_mult <= 0.0)
      return 0.0;

   const double cap_distance = atr * strategy_atr_stop_cap_mult;
   double structure_distance = 0.0;
   if(QM_OrderTypeIsBuy(side))
      structure_distance = entry - g_sell_signal;
   else
      structure_distance = g_buy_signal - entry;

   if(structure_distance <= 0.0)
      return 0.0;

   const double stop_distance = MathMin(structure_distance, cap_distance);
   return QM_StopRulesStopFromDistance(_Symbol, side, entry, stop_distance);
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

   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
      return false;

   const int day_key = Strategy_DayKey(bar_time);
   if(day_key != g_session_key)
      Strategy_ResetSession(day_key);

   if(!Strategy_InSession(bar_time))
      return false;

   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double close2 = iClose(_Symbol, _Period, 2);
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || close2 <= 0.0)
      return false;

   if(!g_range_frozen)
     {
      if(g_session_high <= 0.0 || high1 > g_session_high)
         g_session_high = high1;
      if(g_session_low <= 0.0 || low1 < g_session_low)
         g_session_low = low1;

      const double stoch_k = QM_Stoch_K(_Symbol,
                                        (ENUM_TIMEFRAMES)_Period,
                                        strategy_stoch_k_period,
                                        strategy_stoch_d_period,
                                        strategy_stoch_slowing,
                                        1);
      if(stoch_k >= strategy_trigger_threshold)
        {
         g_buy_signal = g_session_high;
         g_sell_signal = g_session_low;
         g_range_frozen = true;
        }
     }

   ENUM_POSITION_TYPE position_type;
   if(Strategy_HasOpenPosition(position_type))
      return false;
   if(!Strategy_RangeWideEnough())
      return false;
   if(Strategy_InFinalEntryBlock(bar_time))
      return false;

   if(close1 > g_buy_signal && close2 <= g_buy_signal)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = Strategy_StopForEntry(req.type, SymbolInfoDouble(_Symbol, SYMBOL_ASK));
      req.tp = 0.0;
      req.reason = "QM5_10387_LONG_RANGE_BREAK";
      return (req.sl > 0.0);
     }

   if(close1 < g_sell_signal && close2 >= g_sell_signal)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = Strategy_StopForEntry(req.type, SymbolInfoDouble(_Symbol, SYMBOL_BID));
      req.tp = 0.0;
      req.reason = "QM5_10387_SHORT_RANGE_BREAK";
      return (req.sl > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, or partial-close management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_HasOpenPosition(position_type))
      return false;

   const datetime now = TimeCurrent();
   if(!Strategy_InSession(now) || Strategy_InFinalEntryBlock(now))
      return true;

   if(!g_range_frozen)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
      return (bid < g_sell_signal);
   if(position_type == POSITION_TYPE_SELL)
      return (ask > g_buy_signal);

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
