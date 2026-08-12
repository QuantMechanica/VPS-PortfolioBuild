#property strict
#property version   "5.0"
#property description "QM5_20026 Turn-of-Month Settlement-Trough Index Long (Dash-for-Cash variant)"
// Strategy Card: QM5_20026_tom-settlement-trough.md, G0 APPROVED 2026-07-21.
// Source: Etula, Rinne, Suominen & Vaittinen (2020), "Dash for Cash: Monthly
// Market Impact of Institutional Liquidity Needs," RFS 33(1), 75-111,
// DOI 10.1093/rfs/hhz054.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20026;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Card §8 locked parameters. Every offset is a published small integer
// (settlement-derived, not fitted); Q08 perturbs +/-1 lattice step only.
input int    strategy_trough_offset_current_de = 3;    // Card §4 era table: GDAXI current era (EU T+2, from 2014-10-06) -> T-3.
input int    strategy_trough_offset_current_us = 2;    // Card §4 era table: US current era (SEC T+1, from 2024-05-28) -> T-2.
input int    strategy_flat_band_from           = 8;    // Card §6: pre-turn decline flat-filter band start (T-8).
input int    strategy_flat_band_to             = 4;    // Card §6: pre-turn decline flat-filter band end (T-4).
input int    strategy_exit_newmonth_tradingday = 3;    // Card §5: exit at close of the 3rd trading day of the new month (T+3 new).
input int    strategy_atr_period               = 20;   // Card §4/§8: ATR(20,D1) for the frozen stop.
input double strategy_atr_sl_mult              = 2.75; // Card §4/§8: frozen 2.75*ATR(20) stop, no take-profit.
input int    strategy_max_spread_points        = 2500; // Card §8: locked max spread guard.

// -----------------------------------------------------------------------------
// Strategy state
// -----------------------------------------------------------------------------
// Deliberately NO persisted counters for the exit/flat-filter logic: both are
// recomputed on demand from calendar arithmetic (era table + trading-day
// counting) or from the open position's own POSITION_TIME. This makes an EA
// restart mid-hold restart-safe by construction (card §5/§7 "stale guard"),
// instead of relying on an in-memory day-elapsed counter that a reload would
// reset. The one-package-per-month guard (card §4) is likewise derived from
// deal history, not an in-memory latch, for the same restart-safety reason.

//+------------------------------------------------------------------+
//| Calendar helpers (pure date arithmetic — no iTime/bar reads;      |
//| QM_CalendarPeriodKey already supplies the closed-bar day key).    |
//+------------------------------------------------------------------+

int DaysInMonth(const int year, const int month)
  {
   const int dim[] = {31,28,31,30,31,30,31,31,30,31,30,31};
   int d = dim[month - 1];
   if(month == 2 && ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0))
      d = 29;
   return d;
  }

datetime MonthStartDate(const int year, const int month)
  {
   MqlDateTime dt;
   dt.year = year; dt.mon = month; dt.day = 1; dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
  }

datetime StepBackOneWeekday(datetime d)
  {
   d -= 86400;
   MqlDateTime dt;
   TimeToStruct(d, dt);
   if(dt.day_of_week == 0)
      d -= 2 * 86400; // Sunday -> Friday
   else if(dt.day_of_week == 6)
      d -= 86400;      // Saturday -> Friday
   return d;
  }

// Card §4: T-n trading day, counted backward from the last weekday on/before
// the last calendar day of the month (weekend-skipped calendar arithmetic;
// per §4/§6 a holiday on the exact target date means "skip the month", never
// a shift to an adjacent day).
int TroughDateKey(const int year, const int month, const int n)
  {
   MqlDateTime dt;
   dt.year = year; dt.mon = month; dt.day = DaysInMonth(year, month);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime d = StructToTime(dt);

   MqlDateTime chk;
   TimeToStruct(d, chk);
   if(chk.day_of_week == 0)
      d -= 2 * 86400;
   else if(chk.day_of_week == 6)
      d -= 86400;

   for(int s = 0; s < n - 1; ++s)
      d = StepBackOneWeekday(d);

   MqlDateTime res;
   TimeToStruct(d, res);
   return res.year * 10000 + res.mon * 100 + res.day;
  }

bool IsGDAXIVenue(const string sym)
  {
   return (StringFind(sym, "GDAXI") >= 0);
  }

// Card §4 era table — fixed regulatory settlement-convention dates, never
// swept. DAX migrated to EU CSDR T+2 on 2014-10-06; US migrated T+3->T+2 on
// 2017-09-05 and T+2->T+1 on 2024-05-28 (SEC). Legacy T+3-era offset is T-4
// on both venues.
int TroughOffsetTradingDays(const string sym, const int closed_key)
  {
   if(IsGDAXIVenue(sym))
     {
      if(closed_key >= 20141006)
         return strategy_trough_offset_current_de; // T-3, EU T+2 era
      return 4;                                    // T-4, legacy T+3 era
     }
   if(closed_key >= 20240528)
      return strategy_trough_offset_current_us;    // T-2, US T+1 era
   if(closed_key >= 20170905)
      return 3;                                    // T-3, US T+2 era
   return 4;                                        // T-4, legacy T+3 era
  }

// Card §4: one long package per symbol per calendar month, at most, "incl.
// after rejection, stop-out or restart (persisted attempt state + deal
// history)". Deal history (not an in-memory flag) survives an EA restart on
// the same trough day after an earlier stop-out this month.
bool HasTradedThisMonth(const int magic, const datetime month_start)
  {
   if(!HistorySelect(month_start, TimeCurrent()))
      return true; // Card §6: history state unavailable -> fail closed.

   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal_ticket = HistoryDealGetTicket(i);
      if(deal_ticket == 0)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY) == DEAL_ENTRY_IN)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   // Card §6: fail closed on invalid price or a genuinely wide spread only.
   // .DWX symbols quote ask==bid (zero modeled spread) in the tester — never
   // fail-close on zero spread (DWX invariant #1).
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || ask < bid)
      return true;
   if(ask > bid)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > (double)strategy_max_spread_points)
         return true;
     }

   // Card §6: invalid calendar/ATR/stop parameters fail closed. These are
   // user-visible for governed lattice tests, so validate ranges rather than
   // silently clamping them back to defaults.
   if(strategy_trough_offset_current_de < 1 ||
      strategy_trough_offset_current_us < 1 ||
      strategy_flat_band_from < strategy_flat_band_to ||
      strategy_flat_band_to < 1 ||
      strategy_exit_newmonth_tradingday < 1 ||
      strategy_atr_period < 2 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_max_spread_points < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false; // Card §4: no managed open position on the slot.

   // Card §4: entry evaluated at the CLOSE of the trough bar. The framework's
   // new-bar gate fires the tick after a D1 bar closes, so the bar that just
   // closed is shift=1 -- read its calendar key (never iTime directly; the
   // corset requires QM_CalendarPeriodKey for all calendar-period math).
   const int closed_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 1);
   if(closed_key == 0)
      return false; // Card §6: calendar state unknown -> fail closed, no trade.

   const int year  = closed_key / 10000;
   const int month = (closed_key / 100) % 100;
   if(year <= 0 || month < 1 || month > 12)
      return false;

   const int month_key = year * 100 + month;
   const string attempt_key = StringFormat("QM5_20026_ATTEMPT_%d_%s", magic, _Symbol);
   if(GlobalVariableCheck(attempt_key) &&
      (int)GlobalVariableGet(attempt_key) == month_key)
      return false; // Card §4: rejection/stop/restart cannot create a second monthly attempt.

   const int trough_n   = TroughOffsetTradingDays(_Symbol, closed_key);
   const int trough_key = TroughDateKey(year, month, trough_n);

   // Card §4/§6: the trough date is a pure calendar (weekday) computation,
   // independent of whether a real bar exists there. Any other day in the
   // T-8..T-4 flat-band simply fails this equality -- this equality check IS
   // the mechanical flat-filter (§6), with the trough bar as its sole
   // exception. If the computed trough date falls on a holiday (no bar),
   // this closed bar's key will never equal it that month -> the month is
   // skipped, never shifted to an adjacent day.
   if(closed_key != trough_key)
      return false;

   if(HasTradedThisMonth(magic, MonthStartDate(year, month)))
      return false; // Card §4: one long package per symbol per month, incl. after rejection/stop-out/restart.

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false; // Card §4/§6: requires a completed D1 ATR(20) -- fail closed if unavailable.

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   req.type   = QM_BUY; // Card §4/§5: long-only, no short leg.
   req.price  = 0.0;
   req.sl     = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr, strategy_atr_sl_mult); // Card §4: frozen 2.75*ATR(20) stop.
   req.tp     = 0.0; // Card §4: no take-profit -- the edge is the calendar window.
   req.reason = "tom_settlement_trough_long";

   if(req.sl <= 0.0)
      return false;

   // Consume the monthly attempt BEFORE handing the request to the framework.
   // The terminal global survives an EA reload even when the broker rejects
   // the request and therefore no entry deal exists in history.
   if(GlobalVariableSet(attempt_key, (double)month_key) == 0)
      return false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card §7: "never modify the frozen stop; never open a second package in
   // the same symbol-month" -- no trailing/break-even/partial/scale here by
   // design. The timed exit + stale guard live in Strategy_ExitSignal below.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Card §5/§7: exit after the 3rd trading day of the NEW calendar month
   // has CLOSED. QM_ReadBar reads the last three completed D1 bars from the
   // symbol's actual stream, so weekends and exchange holidays are skipped.
   // Once three completed bars belong to the target month, the first tick of
   // the following bar is the mechanically available close-decision fill.
   // A later target-month or later-month restart also fires immediately.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      MqlDateTime edt;
      TimeToStruct(entry_time, edt);
      int next_month = edt.mon + 1;
      int next_year  = edt.year;
      if(next_month > 12)
        {
         next_month = 1;
         ++next_year;
        }

      const int target_month_key = next_year * 100 + next_month;

      MqlRates closed_1;
      if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, closed_1))
         return false;
      MqlDateTime d1;
      TimeToStruct(closed_1.time, d1);
      const int closed_month_key = d1.year * 100 + d1.mon;

      if(closed_month_key > target_month_key)
         return true;
      if(closed_month_key < target_month_key)
         continue;

      int completed_target_month_days = 1;
      for(int shift = 2; shift <= strategy_exit_newmonth_tradingday; ++shift)
        {
         MqlRates prior_closed;
         if(!QM_ReadBar(_Symbol, PERIOD_D1, shift, prior_closed))
            return false;
         MqlDateTime prior_dt;
         TimeToStruct(prior_closed.time, prior_dt);
         if(prior_dt.year * 100 + prior_dt.mon != target_month_key)
            break;
         ++completed_target_month_days;
        }
      if(completed_target_month_days >= strategy_exit_newmonth_tradingday)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // Card §7: framework news filter stays ON (default ordering), no override requested.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_20026\",\"ea\":\"tom-settlement-trough\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
