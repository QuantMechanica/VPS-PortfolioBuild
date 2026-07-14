#property strict
#property version   "5.0"
#property description "QM5_13109 XNG February-June trading-time seasonal long"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13109 - Natural-Gas February-to-June Trading-Time Seasonal Long
// -----------------------------------------------------------------------------
// Peer-reviewed structural energy seasonality translated to a continuous CFD:
//   - source natural-gas futures prices bottom when traded in February
//   - first tradable D1 bar of each week from February through May: long
//   - framework Friday close creates non-overlapping weekly risk tranches
//   - ATR hard stop plus seven-day stale guard
// Runtime is Darwinex-native: MT5 calendar, OHLC, ATR, spread, framework state.
// Card: EWALD-XNG-TRDTIME-2022_S02 (artifacts/cards_approved/QM5_13109_xng-febjun-long.md)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 13109;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours       = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_start_month          = 2;    // Card Rule 4: window start, code-locked to 2.
input int    strategy_end_month            = 5;    // Card Rule 4: window end, code-locked to 5.
input int    strategy_atr_period           = 20;   // Card Parameters To Test: sweep [14,20,30].
input double strategy_atr_sl_mult          = 3.0;  // Card Parameters To Test: sweep [2.5,3.0,4.0].
input int    strategy_max_hold_days        = 7;    // Card Parameters To Test: sweep [5,7].
input int    strategy_max_spread_points    = 2500; // Card Parameters To Test: sweep [1500,2500,3500].

// g_last_entry_week_key survives a restart mid-week: QM_IsNewCalendarPeriod's
// in-memory tracker resets on reload and would otherwise re-fire "new week"
// even if this EA already opened and closed the week's tranche earlier.
int g_last_entry_week_key = 0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

bool Strategy_ValidWindow()
  {
   // Card Rule 6: "The month endpoints are code-locked to 2 and 5."
   return strategy_start_month == 2 && strategy_end_month == 5;
  }

int Strategy_BrokerMonth()
  {
   // yyyymmdd of the current D1 bar via the framework calendar-key reader
   // (never a hand-rolled iTime/TimeToStruct read) - month = digits 3-4.
   const int cal_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
   if(cal_key <= 0)
      return 0;
   return (cal_key / 100) % 100;
  }

bool Strategy_InSeason()
  {
   if(!Strategy_ValidWindow())
      return false;
   const int mon = Strategy_BrokerMonth();
   if(mon <= 0)
      return false;
   return (mon >= strategy_start_month && mon <= strategy_end_month);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXngD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(!Strategy_ValidWindow())
      return true;
   if(strategy_atr_period <= 1 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0 || strategy_max_hold_days > 14)
      return true;
   if(strategy_max_spread_points < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "XNG_TRADING_TIME_WEEKLY_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Card Rule 4: evaluate only on the first tradable D1 bar of a new broker
   // week (a Monday holiday naturally moves this to Tuesday, since the
   // tracker only observes bars that actually exist in the feed). Framework
   // calendar-cadence latch - never a hand-rolled iTime week key.
   if(!QM_IsNewCalendarPeriod(PERIOD_W1))
      return false;

   if(!Strategy_InSeason())
      return false;

   const int week_key = QM_CalendarPeriodKey(PERIOD_W1, _Symbol, 0);
   if(week_key <= 0 || week_key == g_last_entry_week_key)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   const double atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || req.sl >= entry_price)
      return false;

   g_last_entry_week_key = week_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card Rule 7: close outside-window, wrong-side, or stale (beyond
   // strategy_max_hold_days) positions. Runs every tick per the canonical
   // OnTick order so this never suspends intraday (2026-07-02 audit rule).
   if(!Strategy_IsXngD1())
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const bool in_season = Strategy_InSeason();
   const datetime now = TimeCurrent();
   const long max_hold_seconds = (long)MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long position_type = PositionGetInteger(POSITION_TYPE);
      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      const bool wrong_side = (position_type != POSITION_TYPE_BUY);

      if(!in_season || wrong_side)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }

      const bool stale = opened_at > 0 && (now - opened_at) >= max_hold_seconds;
      if(stale)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

bool Strategy_ExitSignal()
  {
   // Card Rule 5: no discretionary exit beyond the ATR stop, the management
   // closes above, and the framework Friday flatten.
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13109\",\"ea\":\"xng-febjun-long\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows - the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // per-tick recompute mistakes - EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 - 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only -
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 - emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
