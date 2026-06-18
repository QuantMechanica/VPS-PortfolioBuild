#property strict
#property version   "5.0"
#property description "QM5_1276 chan-monthly-stock-seasonal — Heston-Sadka monthly seasonal (D1-native)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1276 chan-monthly-stock-seasonal
// -----------------------------------------------------------------------------
// Source: Ernest Chan blog "Seasonal trades in stocks" (epchan.blogspot.com,
//         2007-11-23), citing Heston & Sadka monthly stock seasonality.
// Card: artifacts/cards_approved/QM5_1276_chan-monthly-stock-seasonal.md
//       (g0_status: APPROVED).
//
// CARD RULE (cross-sectional, MN1): at each month-end, rank a universe by the
// same-calendar-month return one year earlier; go long the top bucket, short
// the bottom bucket; hold one month; rebalance.
//
// D1-NATIVE SINGLE-SYMBOL REDUCTION (this EA):
//   MN1 is UNTESTABLE in the .DWX tester (0 bars/ticks). One position per magic
//   forbids a cross-sectional long/short book inside a single EA instance. The
//   faithful per-symbol reduction of the Heston-Sadka signal is the symbol's OWN
//   same-calendar-month return one year ago:
//     - On the FIRST closed D1 bar of a NEW broker-time month (the month-change
//       EVENT — months are the trigger, no indicator two-cross), look back to
//       the SAME calendar month one year earlier and measure that month's total
//       return (close at its month-end vs. close at the prior month-end).
//     - prior_same_month_return > +threshold  -> go LONG  (seasonal tailwind).
//     - prior_same_month_return < -threshold  -> go SHORT (seasonal headwind),
//       if shorts are enabled; otherwise stay flat.
//     - |return| <= threshold                 -> stay flat (no edge).
//   Hold strategy_hold_months calendar months, then exit on the first session of
//   the exit month and re-evaluate. Months are the only trigger.
//
// BROKER TIME: the month boundary is read from the newly-closed D1 bar's open
//   time (iTime(_Symbol, PERIOD_D1, 0), which on a new D1 bar is the first
//   session of the day) in BROKER time. The month-of-year and year keys come
//   straight from that broker-time bar — no UTC re-projection is needed because
//   the calendar month of a DWX D1 bar is unambiguous in broker time (NY-Close).
//   QM_BrokerToUTC is available for finer boundary work but a whole-month bucket
//   does not need it.
//
// Stop: optional ATR stop (card has no explicit stop; V5 fixed-risk control).
//   The seasonal exit is the calendar rotation, not the stop.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
//
// FLAGS:
//   - qm_friday_close_enabled MUST be false: the seasonal hold spans weekends
//     and whole months; a Friday flat-close would destroy the seasonal edge.
//   - Symbol port: card universe (SP500/NDX/GDAXI/WS30 + FX/metal). Registered
//     the index basket SP500.DWX (backtest-only), NDX.DWX, WS30.DWX, GDAXI.DWX.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1276;
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
// Seasonal hold spans weekends/months — Friday flat-close would break the edge.
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Trading days per calendar year on D1 (used to step back ~one year of bars).
input int    strategy_bars_per_year     = 252;
// Trading days per calendar month on D1 (used to bound the prior-month window).
input int    strategy_bars_per_month    = 21;
// Number of calendar months to hold after entry before the rotation exit.
input int    strategy_hold_months       = 1;
// Dead-band on the prior-same-month-one-year-ago return (fraction, e.g. 0.0 =
// any nonzero sign trades; 0.01 = require >1% prior-month move to act).
input double strategy_signal_threshold  = 0.0;
// Allow short entries when the prior-same-month return was negative. If false,
// negative seasonality stays flat (long/flat seasonal calendar).
input bool   strategy_allow_short       = true;
// Optional ATR protective stop. 0.0 disables it (rotation is the real exit).
input int    strategy_atr_period        = 14;
input double strategy_sl_atr_mult       = 0.0;     // 0 = no protective stop

// -----------------------------------------------------------------------------
// File-scope seasonal state. These latch the CALENDAR rotation, not a per-tick
// new-bar event (entry runs behind QM_IsNewBar() already). Month-keyed, not
// bar-keyed: this is structural seasonal logic, mirroring QM5_1463.
// -----------------------------------------------------------------------------
int g_last_eval_month_key   = -1;   // year*12+month of the last evaluation
int g_entry_month_key       = -1;   // year*12+month when the current hold opened
int g_pending_dir           = 0;    // +1 long / -1 short to open on the new-month bar

// Month key (year*12 + month, 1..12) from a broker-time datetime.
int SeasonalMonthKey(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.year * 12 + dt.mon;
  }

// Same-calendar-month return one year earlier, measured on closed D1 bars.
// Returns a fraction (e.g. 0.034 = +3.4%); returns 0.0 on insufficient/invalid
// history so the caller stays flat rather than acting on garbage.
double PriorSameMonthReturn()
  {
   // End of the same month one year ago ~ one year of bars back from the last
   // closed bar (shift 1). Start ~ one month earlier than that.
   const int end_shift   = 1 + strategy_bars_per_year;
   const int start_shift = end_shift + strategy_bars_per_month;

   const double end_close   = iClose(_Symbol, PERIOD_D1, end_shift);   // perf-allowed: single deep D1 read for seasonal lookback
   const double start_close = iClose(_Symbol, PERIOD_D1, start_shift); // perf-allowed: single deep D1 read for seasonal lookback
   if(end_close <= 0.0 || start_close <= 0.0)
      return 0.0;

   return (end_close - start_close) / start_close;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No additional intraday gate — the seasonal calendar is the entire filter and
// runs on the closed-bar path. Cheap O(1).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Seasonal entry. Caller guarantees QM_IsNewBar() == true (closed D1 bar).
// Trigger = broker-time MONTH change of the newly-closed D1 bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Month-change EVENT detection in broker time. iTime(D1,0) on a fresh D1 bar
   // is the first session of the new day; its month identifies the new month.
   const datetime cur_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 month-change detection (structural seasonal logic)
   if(cur_bar_time <= 0)
      return false;
   const int cur_month_key = SeasonalMonthKey(cur_bar_time);

   // Act only on the FIRST closed D1 bar of a genuinely new month.
   if(cur_month_key == g_last_eval_month_key)
      return false;
   g_last_eval_month_key = cur_month_key;

   // Heston-Sadka signal: this symbol's own same-calendar-month return one year
   // ago. Positive seasonality -> long; negative -> short (if enabled).
   const double prior_ret = PriorSameMonthReturn();
   int dir = 0;
   if(prior_ret > strategy_signal_threshold)
      dir = +1;
   else if(prior_ret < -strategy_signal_threshold && strategy_allow_short)
      dir = -1;

   if(dir == 0)
      return false; // no seasonal edge this month — stay flat

   // Build the seasonal entry. Framework sizes lots (no lots field).
   const QM_OrderType otype = (dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl = 0.0; // default: no protective stop — calendar rotation is the exit
   if(strategy_sl_atr_mult > 0.0)
     {
      const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
      if(atr_value > 0.0)
         sl = QM_StopATRFromValue(_Symbol, otype, entry, atr_value, strategy_sl_atr_mult);
     }

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;    // 0.0 = none
   req.tp     = 0.0;   // no TP; the monthly rotation is the exit
   req.reason = (dir > 0) ? "chan_seasonal_long" : "chan_seasonal_short";

   // Latch the entry month so Strategy_ExitSignal can time the rotation exit.
   g_entry_month_key = cur_month_key;
   return true;
  }

// No intraday management — seasonal holds run untouched until the rotation exit.
void Strategy_ManageOpenPosition()
  {
  }

// Calendar rotation exit: close once strategy_hold_months calendar months have
// elapsed since entry, on the first session of the exit month. Months are the
// trigger — no indicator exit.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   if(g_entry_month_key < 0)
      return false;

   const datetime cur_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 month-change detection (structural seasonal logic)
   if(cur_bar_time <= 0)
      return false;
   const int cur_month_key = SeasonalMonthKey(cur_bar_time);

   const int months_held = cur_month_key - g_entry_month_key;
   if(months_held >= strategy_hold_months)
     {
      g_entry_month_key = -1; // reset; Strategy_EntrySignal may re-enter this month
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
