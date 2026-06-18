#property strict
#property version   "5.0"
#property description "QM5_12521 ftse-month-long — FTSE first-trading-day-of-month LONG bias (D1-native)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12521 ftse-month-long
// -----------------------------------------------------------------------------
// Source: Backtest Rookies/Rookie1, "Statistical Analysis: FTSE 100 Period
//         Trends", 2017-09-11.
//         https://backtest-rookies.com/2017/09/11/statistical-analysis-ftse-100-period-trends/
// Card: artifacts/cards_approved/QM5_12521_ftse-month-long.md  (g0_status: APPROVED)
//
// CARD RULE (calendar seasonality, monthly cadence ~12 trades/yr):
//   ENTRY: go LONG at the open of the FIRST tradable session of each calendar
//          month.
//   EXIT:  close at the same session's end of day; do NOT hold overnight.
//   STOP:  card defines none; V5 default intraday catastrophic stop at
//          1.0 * ATR(14) on D1 bars, capped by fixed-risk sizing.
//   FILTER: calendar rule only, no indicator filter.
//
// D1-NATIVE REALIZATION (this EA):
//   The card's "first tradable session of the month" is the month-change EVENT.
//   On the FIRST closed D1 bar of a genuinely NEW broker-time month, we open a
//   LONG (months are the only trigger — no indicator two-cross trap, no zero-
//   trade two-event coincidence). On a DWX D1 chart one D1 bar = one trading
//   session, so the card's "enter at this session's open, exit at this session's
//   close, no overnight hold" maps to a SINGLE-D1-BAR hold: enter on the new-month
//   bar, exit on the NEXT closed D1 bar. The hold is one session and never spans a
//   weekend, so qm_friday_close_enabled can stay true (flagged below).
//
// BROKER TIME: the month boundary is read from the newly-closed D1 bar's open
//   time (iTime(_Symbol, PERIOD_D1, 0), the first session of the new day) in
//   BROKER time. The calendar month of a DWX D1 bar is unambiguous in broker
//   time (NY-Close), so the month-of-year/year keys come straight from it.
//   QM_BrokerToUTC is available for finer boundary work but a whole-month bucket
//   does not need it.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
//
// FLAGS / open questions:
//   - Symbol port: card names "FTSE 100"; the matrix-confirmed DWX index CFD is
//     UK100.DWX (FTSE100 -> UK100). Registered UK100.DWX (single symbol; the card
//     is FTSE-specific and forbids porting to unrelated FX/index symbols).
//   - qm_friday_close_enabled left at its default (true): the single-session hold
//     never spans a weekend, so the Friday flat-close cannot truncate the edge.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12521;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
// Single-session hold never spans a weekend; default Friday flat-close is safe.
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Number of closed D1 bars (sessions) to hold after the first-of-month entry.
// 1 = the card's same-session, no-overnight hold (enter on new-month bar, exit
// on the next closed D1 bar). Kept as an input so a reviewer can extend the hold.
input int    strategy_hold_bars         = 1;
// Optional protective intraday catastrophic stop, ATR(period) * mult on D1.
// Card defines no stop; V5 default mult = 1.0 (0.0 disables it entirely).
input int    strategy_atr_period        = 14;
input double strategy_sl_atr_mult       = 1.0;

// -----------------------------------------------------------------------------
// File-scope calendar state. Month-keyed (not bar-keyed): this is structural
// seasonal logic and entry already runs behind QM_IsNewBar(). Mirrors the
// QM5_1276 monthly-seasonal idiom.
// -----------------------------------------------------------------------------
int g_last_entry_month_key  = -1;   // year*12+month of the last entry (de-dupe per month)
int g_bars_held             = -1;   // closed D1 bars elapsed since entry (-1 = flat)

// Month key (year*12 + month, 1..12) from a broker-time datetime.
int MonthKey(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.year * 12 + dt.mon;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No intraday gate — the calendar rule is the entire filter, on the closed-bar
// path. Cheap O(1).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// First-of-month LONG entry. Caller guarantees QM_IsNewBar() == true (closed D1
// bar). Trigger = broker-time MONTH change of the newly-closed D1 bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // iTime(D1,0) on a fresh D1 bar is the first session of the new day; its
   // month identifies the (possibly new) calendar month in broker time.
   const datetime cur_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 month-change detection (structural seasonal logic)
   if(cur_bar_time <= 0)
      return false;
   const int cur_month_key = MonthKey(cur_bar_time);

   // Act only on the FIRST closed D1 bar of a genuinely new month (month-change
   // EVENT). One entry per calendar month.
   if(cur_month_key == g_last_entry_month_key)
      return false;
   g_last_entry_month_key = cur_month_key;

   // Build the LONG entry. Framework sizes lots (no lots field).
   const QM_OrderType otype = QM_BUY;
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   double sl = 0.0; // default: no protective stop unless mult > 0
   if(strategy_sl_atr_mult > 0.0)
     {
      const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
      if(atr_value > 0.0)
         sl = QM_StopATRFromValue(_Symbol, otype, entry, atr_value, strategy_sl_atr_mult);
     }

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;    // 0.0 = none
   req.tp     = 0.0;   // no TP; the same-session calendar exit is the exit
   req.reason = "ftse_first_of_month_long";

   // Latch the hold counter so Strategy_ExitSignal can time the session exit.
   g_bars_held = 0;
   return true;
  }

// No intraday management — the position runs untouched until the calendar exit
// or the protective ATR stop.
void Strategy_ManageOpenPosition()
  {
  }

// Same-session calendar exit: close once strategy_hold_bars closed D1 bars have
// elapsed since entry (default 1 = the next closed D1 bar -> no overnight hold).
// The closed-bar cadence is provided by the framework new-bar gate in OnTick;
// this counter only advances when a position is actually open.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
     {
      g_bars_held = -1; // position gone (TP/SL/closed) — reset
      return false;
     }
   if(g_bars_held < 0)
      return false;

   // OnTick calls this every tick; only advance the hold counter once per closed
   // D1 bar. QM_IsNewBar() is consumed by the entry gate later in OnTick, so we
   // detect the bar roll here via the newly-closed bar's open time instead of
   // re-consuming the single-shot new-bar event.
   const datetime cur_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 bar-roll detection for the session-hold counter
   static datetime s_last_counted_bar = 0;
   if(cur_bar_time > 0 && cur_bar_time != s_last_counted_bar)
     {
      s_last_counted_bar = cur_bar_time;
      g_bars_held++;
     }

   if(g_bars_held >= strategy_hold_bars)
     {
      g_bars_held = -1; // reset; flat again
      return true;
     }
   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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

   Strategy_ManageOpenPosition();

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

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
