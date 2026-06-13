#property strict
#property version   "5.0"
#property description "QM5_10633 Elite Trader 5m Opening Range Direction Break"

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
input int    qm_ea_id                   = 10633;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input int    strategy_session_start_hour        = 16;
input int    strategy_session_start_minute      = 30;
input int    strategy_session_end_hour          = 23;
input int    strategy_session_end_minute        = 0;
input int    strategy_opening_minutes           = 5;
input int    strategy_atr_period                = 14;
input double strategy_doji_atr_fraction         = 0.10;
input double strategy_stop_buffer_atr_fraction  = 0.10;
input double strategy_min_range_atr_fraction    = 0.20;
input double strategy_max_range_atr_fraction    = 2.00;
input double strategy_max_spread_range_fraction = 0.15;
input double strategy_take_profit_rr            = 1.50;
input int    strategy_time_exit_bars            = 24;

int    g_session_day_key       = -1;
bool   g_session_processed     = false;
bool   g_position_state_active = false;
int    g_position_day_key      = -1;
int    g_position_side         = 0;
int    g_bars_since_entry      = 0;
double g_first_bar_midpoint    = 0.0;
double g_first_bar_range       = 0.0;
bool   g_exit_due              = false;

int MinutesOfDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.hour * 60 + dt.min;
  }

int DayKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int SessionStartMinute()
  {
   return strategy_session_start_hour * 60 + strategy_session_start_minute;
  }

int SessionEndMinute()
  {
   return strategy_session_end_hour * 60 + strategy_session_end_minute;
  }

int EntryMinute()
  {
   return SessionStartMinute() + strategy_opening_minutes;
  }

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

void ResetDailyStateIfNeeded(const datetime broker_time)
  {
   const int day_key = DayKey(broker_time);
   if(day_key == g_session_day_key)
      return;

   g_session_day_key = day_key;
   g_session_processed = false;
   if(!HasOpenPosition())
     {
      g_position_state_active = false;
      g_position_day_key = -1;
      g_position_side = 0;
      g_bars_since_entry = 0;
      g_first_bar_midpoint = 0.0;
      g_first_bar_range = 0.0;
      g_exit_due = false;
     }
  }

bool CurrentSpreadTooWide()
  {
   if(g_first_bar_range <= 0.0 || strategy_max_spread_range_fraction <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask <= bid)
      return true;

   return ((ask - bid) > g_first_bar_range * strategy_max_spread_range_fraction);
  }

void AdvanceExitStateOnClosedBar(const MqlRates &closed_bar, const MqlRates &current_bar)
  {
   if(!g_position_state_active || !HasOpenPosition())
     {
      g_position_state_active = false;
      g_exit_due = false;
      return;
     }

   g_bars_since_entry++;
   const int current_minute = MinutesOfDay(current_bar.time);
   const int current_day = DayKey(current_bar.time);
   if(current_day != g_position_day_key || current_minute >= SessionEndMinute())
     {
      g_exit_due = true;
      return;
     }

   if(strategy_time_exit_bars > 0 && g_bars_since_entry >= strategy_time_exit_bars)
     {
      g_exit_due = true;
      return;
     }

   if(g_first_bar_midpoint > 0.0)
     {
      if(g_position_side > 0 && closed_bar.close < g_first_bar_midpoint)
         g_exit_due = true;
      if(g_position_side < 0 && closed_bar.close > g_first_bar_midpoint)
         g_exit_due = true;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   ResetDailyStateIfNeeded(broker_now);

   if(HasOpenPosition())
      return false;

   const int minute_now = MinutesOfDay(broker_now);
   if(minute_now < EntryMinute() || minute_now >= SessionEndMinute())
      return true;

   if(g_session_processed)
      return true;

   if(CurrentSpreadTooWide())
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

   MqlRates current_bar[1];
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, current_bar) != 1) // perf-allowed: closed-bar-gated ORB structural read.
      return false;

   MqlRates first_bar[1];
   if(CopyRates(_Symbol, PERIOD_CURRENT, 1, 1, first_bar) != 1) // perf-allowed: closed-bar-gated ORB structural read.
      return false;

   ResetDailyStateIfNeeded(current_bar[0].time);
   AdvanceExitStateOnClosedBar(first_bar[0], current_bar[0]);

   if(HasOpenPosition())
      return false;

   if(g_session_processed)
      return false;

   if(MinutesOfDay(current_bar[0].time) != EntryMinute())
      return false;
   if(MinutesOfDay(first_bar[0].time) != SessionStartMinute())
      return false;

   g_session_processed = true;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double first_open = first_bar[0].open;
   const double first_close = first_bar[0].close;
   const double first_high = first_bar[0].high;
   const double first_low = first_bar[0].low;
   const double body = MathAbs(first_close - first_open);
   const double range = first_high - first_low;
   if(first_open <= 0.0 || first_close <= 0.0 || range <= 0.0)
      return false;

   g_first_bar_midpoint = (first_high + first_low) * 0.5;
   g_first_bar_range = range;

   if(body <= strategy_doji_atr_fraction * atr)
      return false;
   if(range < strategy_min_range_atr_fraction * atr || range > strategy_max_range_atr_fraction * atr)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask <= bid)
      return false;
   if((ask - bid) > range * strategy_max_spread_range_fraction)
      return false;

   const double buffer = strategy_stop_buffer_atr_fraction * atr;
   if(first_close > first_open)
     {
      const double entry = ask;
      const double sl = first_low - buffer;
      const double risk = entry - sl;
      if(sl <= 0.0 || risk <= 0.0)
         return false;

      req.type = QM_BUY;
      req.sl = NormalizeStrategyPrice(sl);
      req.tp = NormalizeStrategyPrice(entry + risk * strategy_take_profit_rr);
      req.reason = "ET_ORB_5M_LONG";
      g_position_state_active = true;
      g_position_day_key = DayKey(current_bar[0].time);
      g_position_side = 1;
      g_bars_since_entry = 0;
      g_exit_due = false;
      return true;
     }

   if(first_close < first_open)
     {
      const double entry = bid;
      const double sl = first_high + buffer;
      const double risk = sl - entry;
      if(sl <= 0.0 || risk <= 0.0)
         return false;

      req.type = QM_SELL;
      req.sl = NormalizeStrategyPrice(sl);
      req.tp = NormalizeStrategyPrice(entry - risk * strategy_take_profit_rr);
      req.reason = "ET_ORB_5M_SHORT";
      g_position_state_active = true;
      g_position_day_key = DayKey(current_bar[0].time);
      g_position_side = -1;
      g_bars_since_entry = 0;
      g_exit_due = false;
      return true;
     }

   return false;
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
   if(!HasOpenPosition())
     {
      g_position_state_active = false;
      g_exit_due = false;
      return false;
     }

   return g_exit_due;
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
