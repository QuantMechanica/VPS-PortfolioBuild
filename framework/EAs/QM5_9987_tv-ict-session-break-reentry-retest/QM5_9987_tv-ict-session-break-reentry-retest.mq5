#property strict
#property version   "5.0"
#property description "QM5_9987 TradingView ICT Session Break-Reentry-Retest"

#include <QM/QM_Common.mqh>

enum StrategySessionState
  {
   ST_WAITING = 0,
   ST_BREAK_HIGH = 1,
   ST_BREAK_LOW = 2,
   ST_REENTRY_HIGH = 3,
   ST_REENTRY_LOW = 4,
   ST_ARMED_SHORT = 5,
   ST_ARMED_LONG = 6
  };

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
input int    qm_ea_id                   = 9999;
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
input bool   strategy_trade_asia        = true;
input bool   strategy_trade_london      = true;
input bool   strategy_trade_nyam        = true;
input int    strategy_asia_start_min    = 0;
input int    strategy_asia_end_min      = 420;
input int    strategy_london_start_min  = 480;
input int    strategy_london_end_min    = 720;
input int    strategy_nyam_start_min    = 810;
input int    strategy_nyam_end_min      = 1020;
input int    strategy_wait_bars         = 2;
input int    strategy_sl_pips           = 15;
input int    strategy_tp_pips           = 30;
input int    strategy_session_end_buffer_bars = 2;
input double strategy_spread_filter_mult = 0.30;

StrategySessionState g_state = ST_WAITING;
int      g_session_key = -1;
int      g_reentry_bars = 0;
bool     g_range_ready = false;
bool     g_range_frozen = false;
bool     g_trade_taken_this_session = false;
double   g_session_high = 0.0;
double   g_session_low = 0.0;
datetime g_position_session_exit_at = 0;

int MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int ClampMinute(const int minute_value)
  {
   if(minute_value < 0)
      return 0;
   if(minute_value > 1439)
      return 1439;
   return minute_value;
  }

bool InMinuteWindow(const int minute_of_day, const int start_min, const int end_min)
  {
   const int start = ClampMinute(start_min);
   const int finish = ClampMinute(end_min);
   if(start == finish)
      return false;
   if(start < finish)
      return minute_of_day >= start && minute_of_day < finish;
   return minute_of_day >= start || minute_of_day < finish;
  }

int ActiveSessionIndex(const datetime t)
  {
   const int minute_of_day = MinutesOfDay(t);
   if(strategy_trade_asia && InMinuteWindow(minute_of_day, strategy_asia_start_min, strategy_asia_end_min))
      return 0;
   if(strategy_trade_london && InMinuteWindow(minute_of_day, strategy_london_start_min, strategy_london_end_min))
      return 1;
   if(strategy_trade_nyam && InMinuteWindow(minute_of_day, strategy_nyam_start_min, strategy_nyam_end_min))
      return 2;
   return -1;
  }

int SessionStartMin(const int session_index)
  {
   if(session_index == 0)
      return strategy_asia_start_min;
   if(session_index == 1)
      return strategy_london_start_min;
   return strategy_nyam_start_min;
  }

int SessionEndMin(const int session_index)
  {
   if(session_index == 0)
      return strategy_asia_end_min;
   if(session_index == 1)
      return strategy_london_end_min;
   return strategy_nyam_end_min;
  }

datetime DateAtMinute(const datetime t, const int minute_of_day)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   const int minute = ClampMinute(minute_of_day);
   dt.hour = minute / 60;
   dt.min = minute % 60;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime SessionEndTime(const datetime bar_time, const int session_index)
  {
   datetime end_time = DateAtMinute(bar_time, SessionEndMin(session_index));
   if(SessionEndMin(session_index) <= SessionStartMin(session_index) &&
      MinutesOfDay(bar_time) >= SessionStartMin(session_index))
      end_time += 86400;
   return end_time;
  }

void ResetSessionState(const int session_key)
  {
   g_state = ST_WAITING;
   g_session_key = session_key;
   g_reentry_bars = 0;
   g_range_ready = false;
   g_range_frozen = false;
   g_trade_taken_this_session = false;
   g_session_high = 0.0;
   g_session_low = 0.0;
   g_position_session_exit_at = 0;
  }

bool HasOpenPosition()
  {
   return QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0;
  }

bool LoadLastClosedBar(MqlRates &bar)
  {
   MqlRates rates[];
   ArrayResize(rates, 1);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, 1, rates); // perf-allowed: one closed bar inside framework QM_IsNewBar gate.
   if(copied != 1)
      return false;
   bar = rates[0];
   return bar.time > 0 && bar.high > 0.0 && bar.low > 0.0 && bar.close > 0.0;
  }

void PrepareMarketRequest(QM_EntryRequest &req, const QM_OrderType side, const double entry_price, const int session_index)
  {
   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopFixedPips(_Symbol, side, entry_price, strategy_sl_pips);
   req.tp = QM_TakeFixedPips(_Symbol, side, entry_price, strategy_tp_pips);
   req.reason = StringFormat("ICT_SESSION_RETEST_%d", session_index);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return true;

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips) * strategy_spread_filter_mult;
   if(cap > 0.0 && ask > bid && (ask - bid) > cap)
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

   if(strategy_wait_bars < 0 || strategy_sl_pips <= 0 || strategy_tp_pips <= 0)
      return false;
   if(HasOpenPosition() || g_trade_taken_this_session)
      return false;

   MqlRates bar;
   if(!LoadLastClosedBar(bar))
      return false;

   const int session_index = ActiveSessionIndex(bar.time);
   if(session_index < 0)
      return false;

   const int session_key = DayKey(bar.time) * 10 + session_index;
   if(session_key != g_session_key)
      ResetSessionState(session_key);

   if(!g_range_ready)
     {
      g_session_high = bar.high;
      g_session_low = bar.low;
      g_range_ready = true;
      return false;
     }

   if(g_state == ST_WAITING && !g_range_frozen)
     {
      const double prior_high = g_session_high;
      const double prior_low = g_session_low;

      if(bar.close > prior_high)
        {
         g_state = ST_BREAK_HIGH;
         g_range_frozen = true;
         return false;
        }
      if(bar.close < prior_low)
        {
         g_state = ST_BREAK_LOW;
         g_range_frozen = true;
         return false;
        }

      g_session_high = MathMax(g_session_high, bar.high);
      g_session_low = MathMin(g_session_low, bar.low);
      return false;
     }

   if(g_state == ST_BREAK_HIGH)
     {
      if(bar.close < g_session_high)
        {
         g_state = ST_REENTRY_HIGH;
         g_reentry_bars = 0;
        }
      return false;
     }

   if(g_state == ST_BREAK_LOW)
     {
      if(bar.close > g_session_low)
        {
         g_state = ST_REENTRY_LOW;
         g_reentry_bars = 0;
        }
      return false;
     }

   if(g_state == ST_REENTRY_HIGH)
     {
      if(bar.close >= g_session_high)
        {
         g_state = ST_BREAK_HIGH;
         g_reentry_bars = 0;
         return false;
        }
      g_reentry_bars++;
      if(g_reentry_bars >= strategy_wait_bars)
         g_state = ST_ARMED_SHORT;
      return false;
     }

   if(g_state == ST_REENTRY_LOW)
     {
      if(bar.close <= g_session_low)
        {
         g_state = ST_BREAK_LOW;
         g_reentry_bars = 0;
         return false;
        }
      g_reentry_bars++;
      if(g_reentry_bars >= strategy_wait_bars)
         g_state = ST_ARMED_LONG;
      return false;
     }

   if(g_state == ST_ARMED_SHORT && bar.high >= g_session_high)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;
      PrepareMarketRequest(req, QM_SELL, bid, session_index);
      if(req.sl <= 0.0 || req.tp <= 0.0)
         return false;
      g_trade_taken_this_session = true;
      g_position_session_exit_at = SessionEndTime(bar.time, session_index) +
                                   strategy_session_end_buffer_bars * PeriodSeconds(PERIOD_CURRENT);
      return true;
     }

   if(g_state == ST_ARMED_LONG && bar.low <= g_session_low)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;
      PrepareMarketRequest(req, QM_BUY, ask, session_index);
      if(req.sl <= 0.0 || req.tp <= 0.0)
         return false;
      g_trade_taken_this_session = true;
      g_position_session_exit_at = SessionEndTime(bar.time, session_index) +
                                   strategy_session_end_buffer_bars * PeriodSeconds(PERIOD_CURRENT);
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial-close, or scale-in logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(g_position_session_exit_at <= 0)
      return false;
   if(!HasOpenPosition())
      return false;
   if(TimeCurrent() >= g_position_session_exit_at)
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
