#property strict
#property version   "5.0"
#property description "QM5_13128 Pre-FOMC Drift NDX — faithful port of PRE_FOMC_FLAT_IDX.mq5"

// PORT NOTES
// ---------
// Source: .private/secret_strategy_lab/pre_fomc_flat/PRE_FOMC_FLAT_IDX.mq5
// Strategy: one market LONG per FOMC meeting cycle.
//   Entry  — new H1 bar, broker hour == 21, TOMORROW is an FOMC event date, FLAT.
//   Exit   — new H1 bar, broker hour == 20, TODAY is an FOMC event date, IN position.
//   Stop   — entry minus 2.0 × prior closed D1 ATR(14) (shift=1).
//   Sizing — framework RISK_FIXED (lot sizing delegated to QM_TM_OpenPosition via req.sl).
//   One position at a time; no TP, no scale, no trail, no grid.
//
// NEWS GATE DELIBERATELY DISABLED (QM_NEWS_TEMPORAL_OFF / QM_NEWS_COMPLIANCE_NONE):
//   The framework OnTick news gate sits BEFORE Strategy_ExitSignal. The scheduled exit
//   at broker hour 20 on event day coincides with the FOMC high-impact blackout window.
//   If news filtering were active, QM_NewsAllowsTrade2 would return false and OnTick
//   would return before reaching the exit logic, silently trapping the position through
//   the FOMC statement — breaking the core invariant of the strategy ("flat before
//   statement"). The strategy is event-flat BY DESIGN: it handles the news risk
//   itself via the timed exit, so no additional news gate is needed or wanted.

#include <QM/QM_Common.mqh>

// ── Framework Inputs ──────────────────────────────────────────────────────────
input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13128;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// NEWS OFF — see port notes above: the timed 20:00 exit IS the news-risk management.
// Any active news gate would fire at the exact hour the position needs to be closed.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe   = PERIOD_H1;
input int    strategy_entry_hour           = 21;   // broker hour to open the long the day before FOMC
input int    strategy_exit_hour            = 20;   // broker hour to close on the decision day (before the statement)
input int    strategy_atr_period           = 14;
input double strategy_stop_atr_mult        = 2.0;

// ── FOMC Event Date Table (verbatim from PRE_FOMC_FLAT_IDX.mq5) ──────────────
// Integer keys: YYYYMMDD. One entry per FOMC meeting / announcement date.
// Entry is placed the EVENING BEFORE (hour 21 when tomorrow == event_date).
// Exit is placed the MORNING OF (hour 20 when today == event_date).
const int g_event_dates[] = {
   20180926, 20181219,
   20190130, 20190320, 20190501, 20190619, 20190731, 20190918, 20191030, 20191211,
   20200129, 20200429, 20200610, 20200729, 20200916, 20201105, 20201216,
   20210127, 20210317, 20210428, 20210616, 20210728, 20210922, 20211103, 20211215,
   20220126, 20220316, 20220504, 20220615, 20220727, 20220921, 20221102, 20221214,
   20230201, 20230322, 20230503, 20230614, 20230726, 20230920, 20231101, 20231213,
   20240131, 20240320, 20240501, 20240612, 20240731, 20240918, 20241107, 20241218,
   20250129, 20250319, 20250507, 20250618, 20250730, 20250917, 20251029, 20251210
};

// ── Strategy State ────────────────────────────────────────────────────────────
// (no persistent state needed beyond what the framework tracks via magic)

// ── Helper: YYYYMMDD integer from a datetime ─────────────────────────────────
int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

// ── Helper: broker hour from a datetime ──────────────────────────────────────
int Strategy_HourOf(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
  }

// ── Helper: is the given YYYYMMDD key an FOMC event date? ────────────────────
bool Strategy_IsEventDateKey(const int key)
  {
   const int n = ArraySize(g_event_dates);
   for(int i = 0; i < n; ++i)
      if(g_event_dates[i] == key)
         return true;
   return false;
  }

// ── Helper: does the framework own a position on this symbol? ────────────────
bool Strategy_HasOurOpenPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// ── Strategy_NoTradeFilter ────────────────────────────────────────────────────
// Returns true to BLOCK trading.
// Blocks if: wrong chart timeframe, or insufficient D1 history for ATR(14)+1 bar.
bool Strategy_NoTradeFilter()
  {
   // Chart must be attached on H1
   if(_Period != strategy_timeframe)
      return true;
   // Need at least ATR period + 2 bars of D1 history (shift=1 means we need bar[1])
   if(Bars(_Symbol, PERIOD_D1) < strategy_atr_period + 2)
      return true;
   return false;
  }

// ── Strategy_EntrySignal ──────────────────────────────────────────────────────
// Called once per new H1 bar (after the new-bar gate in OnTick).
// Conditions for a LONG entry:
//   1. Broker hour of the NEW bar's open == 21
//   2. The calendar day 24h from now (= tomorrow) is an FOMC event date
//   3. Not currently in a position
// Fills req: type=QM_BUY (market order), price=0 (market), sl=entry−2×D1_ATR14[1], tp=0.
// symbol_slot = qm_magic_slot_offset (per framework audit 9e4cfedb1 — must always be set).
// Framework QM_TM_OpenPosition handles lot sizing from RISK_FIXED + stop distance.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Zero-init via constructor (fields: type, price, sl, tp, reason, symbol_slot, expiration_seconds)
   req = QM_EntryRequest();
   req.symbol_slot = qm_magic_slot_offset;

   const datetime broker_now = TimeCurrent();
   const int hour = Strategy_HourOf(broker_now);

   // Entry window: broker hour == strategy_entry_hour only
   if(hour != strategy_entry_hour)
      return false;

   // Already in a position — one position at a time
   if(Strategy_HasOurOpenPosition())
      return false;

   // Check if TOMORROW is an FOMC event date (now + 24 hours)
   const int tomorrow_key = Strategy_DateKey(broker_now + 24 * 60 * 60);
   if(!Strategy_IsEventDateKey(tomorrow_key))
      return false;

   // Fetch prior closed D1 ATR(14): QM_ATR(sym, tf, period, shift=1) — shift=1 is the default
   const double daily_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(daily_atr <= 0.0)
      return false;

   // Market BUY — price=0 means market order in QM_TM_OpenPosition
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double stop_price = NormalizeDouble(ask - strategy_stop_atr_mult * daily_atr, digits);

   // Sanity: stop must be positive and below entry
   const double min_stop_dist = SymbolInfoDouble(_Symbol, SYMBOL_POINT) *
                                (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stop_price <= 0.0 || ask - stop_price < min_stop_dist)
      return false;

   req.type   = QM_BUY;      // market buy (QM_BUY = 0, maps to ORDER_TYPE_BUY)
   req.price  = 0.0;         // market — QM_TM_OpenPosition reads SYMBOL_ASK
   req.sl     = stop_price;  // hard stop; framework sizes lots from RISK_FIXED / stop_dist
   req.tp     = 0.0;         // no take-profit
   req.reason = "PRE_FOMC_LONG";

   return true;
  }

// ── Strategy_ExitSignal ───────────────────────────────────────────────────────
// Returns true to trigger position close.
// Condition: we are IN a position AND today is an FOMC event date AND broker hour == 20.
// This implements the "flat before statement" rule: exit at 20:00 broker time,
// before the FOMC statement (typically 20:00–20:30 broker time / 14:00 ET).
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   const int today_key = Strategy_DateKey(broker_now);
   const int hour = Strategy_HourOf(broker_now);

   return (Strategy_IsEventDateKey(today_key) && hour == strategy_exit_hour);
  }

// ── Strategy_ManageOpenPosition ───────────────────────────────────────────────
// No intra-trade management needed: no trailing, no averaging, no scaling.
// Hard stop is placed at entry via req.sl; the broker manages it from there.
void Strategy_ManageOpenPosition()
  {
   // No-op: hard stop is set at entry; no management needed.
   QM_FrameworkTrackOpenPositionMae();
  }

// ── Strategy_NewsFilterHook ───────────────────────────────────────────────────
// Not used — news gate is fully disabled (see port notes at top of file).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ── Lifecycle ─────────────────────────────────────────────────────────────────
int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK",
               StringFormat("{\"ea_id\":%d,\"symbol\":\"%s\",\"events\":%d,\"atr_period\":%d,\"stop_atr_mult\":%.1f}",
                            qm_ea_id, _Symbol, ArraySize(g_event_dates),
                            strategy_atr_period, strategy_stop_atr_mult));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

// ── OnTick — standard framework corset ───────────────────────────────────────
// Structure must match the template (QM5_10715) exactly so the framework
// corset check (new-bar gating order) passes.
void OnTick()
  {
   // 1. Kill-switch: halt if flagged
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();

   // 2. Strategy-level news hook (no-op here)
   if(Strategy_NewsFilterHook(broker_now))
      return;

   // 3. Framework news gate — deliberately skipped when both axes are OFF.
   //    NEWS IS OFF: see port notes. The exit at hour 20 on event day falls
   //    inside the FOMC blackout; an active gate would block it.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   // 4. Friday close
   if(QM_FrameworkHandleFridayClose())
      return;

   // 5. No-trade filter (wrong TF, insufficient D1 history)
   if(Strategy_NoTradeFilter())
      return;

   // 6. Intra-trade management (no-op / MAE tracking)
   Strategy_ManageOpenPosition();

   // 7. Exit signal — close position before FOMC statement at broker hour 20
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

   // 8. New-bar gate — entry logic runs once per H1 bar open
   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
      return;

   QM_EquityStreamOnNewBar();

   // 9. Entry signal — market long the evening before each FOMC date
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
                        const MqlTradeRequest     &request,
                        const MqlTradeResult      &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
