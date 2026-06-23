#property strict
#property version   "5.0"
#property description "QM5_11378 Big Ben London Open Fade M5"

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
input int    qm_ea_id                   = 11378;
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
input int    strategy_range_start_hhmm_utc = 0;
input int    strategy_range_end_hhmm_utc   = 700;
input int    strategy_spike_start_hhmm_utc = 700;
input int    strategy_spike_end_hhmm_utc   = 800;
input int    strategy_entry_end_hhmm_utc   = 830;
input int    strategy_time_stop_hhmm_utc   = 900;
input int    strategy_min_range_pips       = 15;
input int    strategy_tp_min_pips          = 20;
input int    strategy_tp_max_pips          = 60;
input int    strategy_sl_buffer_pips       = 1;
input int    strategy_sl_max_pips          = 25;
input int    strategy_spread_cap_pips      = 20;
input int    strategy_lookback_bars        = 220;

int    g_session_day_key          = -1;
bool   g_trade_taken_for_day      = false;
bool   g_bear_spike_seen          = false;
bool   g_bull_spike_seen          = false;
double g_bear_spike_low           = 0.0;
double g_bull_spike_high          = 0.0;
double g_session_body_high        = 0.0;
double g_session_body_low         = 0.0;
double g_session_range_pips       = 0.0;

int HHMMToMinutes(const int hhmm)
  {
   const int hh = hhmm / 100;
   const int mm = hhmm % 100;
   return (hh * 60) + mm;
  }

int UtcMinuteOfDay(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(QM_BrokerToUTC(broker_time), dt);
   return (dt.hour * 60) + dt.min;
  }

int UtcDayKey(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(QM_BrokerToUTC(broker_time), dt);
   return (dt.year * 1000) + dt.day_of_year;
  }

bool IsMinuteInWindow(const int minute_of_day, const int start_hhmm, const int end_hhmm)
  {
   const int start_min = HHMMToMinutes(start_hhmm);
   const int end_min = HHMMToMinutes(end_hhmm);
   if(start_min <= end_min)
      return (minute_of_day >= start_min && minute_of_day < end_min);
   return (minute_of_day >= start_min || minute_of_day < end_min);
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return true;
     }

   return false;
  }

int SymbolSlotForCurrentInput()
  {
   return qm_magic_slot_offset;
  }

double PipDistance()
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

bool SpreadWithinCap()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double max_spread = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(max_spread <= 0.0)
      return false;

   if(ask > bid && (ask - bid) > max_spread)
      return false;
   return true;
  }

void ResetSessionState(const int day_key)
  {
   g_session_day_key = day_key;
   g_trade_taken_for_day = false;
   g_bear_spike_seen = false;
   g_bull_spike_seen = false;
   g_bear_spike_low = 0.0;
   g_bull_spike_high = 0.0;
   g_session_body_high = 0.0;
   g_session_body_low = 0.0;
   g_session_range_pips = 0.0;
  }

bool BuildSessionStateBeforeCurrent(const MqlRates &rates[], const int copied, const int current_day_key)
  {
   double body_high = -DBL_MAX;
   double body_low = DBL_MAX;
   bool have_range = false;
   bool bear_seen = false;
   bool bull_seen = false;
   double bear_low = 0.0;
   double bull_high = 0.0;

   for(int i = copied - 1; i >= 1; --i)
     {
      if(UtcDayKey(rates[i].time) != current_day_key)
         continue;

      const int minute_of_day = UtcMinuteOfDay(rates[i].time);
      const double bar_body_high = MathMax(rates[i].open, rates[i].close);
      const double bar_body_low = MathMin(rates[i].open, rates[i].close);

      if(IsMinuteInWindow(minute_of_day, strategy_range_start_hhmm_utc, strategy_range_end_hhmm_utc))
        {
         body_high = MathMax(body_high, bar_body_high);
         body_low = MathMin(body_low, bar_body_low);
         have_range = true;
         continue;
        }

      if(!have_range)
         continue;

      if(IsMinuteInWindow(minute_of_day, strategy_spike_start_hhmm_utc, strategy_spike_end_hhmm_utc))
        {
         if(rates[i].close < body_low)
           {
            bear_seen = true;
            bear_low = rates[i].low;
           }
         if(rates[i].close > body_high)
           {
            bull_seen = true;
            bull_high = rates[i].high;
           }
        }
     }

   if(!have_range || body_high <= body_low)
      return false;

   const double pip = PipDistance();
   if(pip <= 0.0)
      return false;

   g_session_body_high = body_high;
   g_session_body_low = body_low;
   g_session_range_pips = (body_high - body_low) / pip;
   g_bear_spike_seen = bear_seen;
   g_bull_spike_seen = bull_seen;
   g_bear_spike_low = bear_low;
   g_bull_spike_high = bull_high;
   return true;
  }

double ClippedTakeProfitDistance()
  {
   const double pip = PipDistance();
   if(pip <= 0.0)
      return 0.0;

   double tp_pips = g_session_range_pips;
   tp_pips = MathMax((double)strategy_tp_min_pips, MathMin((double)strategy_tp_max_pips, tp_pips));
   return tp_pips * pip;
  }

double CappedStopPrice(const QM_OrderType type, const double entry_price, const double raw_stop)
  {
   const double max_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);
   if(entry_price <= 0.0 || raw_stop <= 0.0 || max_dist <= 0.0)
      return 0.0;

   double stop = raw_stop;
   if(type == QM_BUY && (entry_price - stop) > max_dist)
      stop = entry_price - max_dist;
   if(type == QM_SELL && (stop - entry_price) > max_dist)
      stop = entry_price + max_dist;
   return QM_StopRulesNormalizePrice(_Symbol, stop);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(HasOurOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   const int minute_of_day = UtcMinuteOfDay(broker_now);
   if(!IsMinuteInWindow(minute_of_day, strategy_spike_start_hhmm_utc, strategy_entry_end_hhmm_utc))
      return true;

   if(!SpreadWithinCap())
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
   req.symbol_slot = SymbolSlotForCurrentInput();
   req.expiration_seconds = 0;

   if(_Period != PERIOD_M5)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M5, 1, strategy_lookback_bars, rates); // perf-allowed: bespoke session body range, called only after framework QM_IsNewBar gate.
   if(copied < 2)
      return false;

   const int current_day_key = UtcDayKey(rates[0].time);
   if(current_day_key != g_session_day_key)
      ResetSessionState(current_day_key);

   if(g_trade_taken_for_day)
      return false;

   const int minute_of_day = UtcMinuteOfDay(rates[0].time);
   if(!IsMinuteInWindow(minute_of_day, strategy_spike_start_hhmm_utc, strategy_entry_end_hhmm_utc))
      return false;

   if(!BuildSessionStateBeforeCurrent(rates, copied, current_day_key))
      return false;
   if(g_session_range_pips < (double)strategy_min_range_pips)
      return false;

   const double pip = PipDistance();
   const double tp_dist = ClippedTakeProfitDistance();
   if(pip <= 0.0 || tp_dist <= 0.0)
      return false;

   if(g_bear_spike_seen &&
      rates[0].close > g_session_body_low &&
      rates[0].close > rates[0].open &&
      g_bear_spike_low > 0.0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double entry_price = (entry > 0.0) ? entry : rates[0].close;
      const double raw_sl = g_bear_spike_low - (strategy_sl_buffer_pips * pip);
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = CappedStopPrice(req.type, entry_price, raw_sl);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, entry_price + tp_dist);
      req.reason = "BIG_BEN_FADE_LONG";
      g_trade_taken_for_day = true;
      return (req.sl > 0.0 && req.tp > 0.0 && req.sl < entry_price && req.tp > entry_price);
     }

   if(g_bull_spike_seen &&
      rates[0].close < g_session_body_high &&
      rates[0].close < rates[0].open &&
      g_bull_spike_high > 0.0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double entry_price = (entry > 0.0) ? entry : rates[0].close;
      const double raw_sl = g_bull_spike_high + (strategy_sl_buffer_pips * pip);
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = CappedStopPrice(req.type, entry_price, raw_sl);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, entry_price - tp_dist);
      req.reason = "BIG_BEN_FADE_SHORT";
      g_trade_taken_for_day = true;
      return (req.sl > 0.0 && req.tp > 0.0 && req.sl > entry_price && req.tp < entry_price);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card has no trailing, break-even, partial close, or scale-in rule.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!HasOurOpenPosition())
      return false;

   const int minute_of_day = UtcMinuteOfDay(TimeCurrent());
   return (minute_of_day >= HHMMToMinutes(strategy_time_stop_hhmm_utc));
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
