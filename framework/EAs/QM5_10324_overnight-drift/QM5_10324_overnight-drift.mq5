#property strict
#property version   "5.0"
#property description "QM5_10324 Overnight Drift European Open"

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
input int    qm_ea_id                   = 10324;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_M15;
input ENUM_TIMEFRAMES strategy_prior_return_tf    = PERIOD_H1;
input int    strategy_atr_period                  = 14;
input double strategy_prior_return_atr_mult       = 0.50;
input double strategy_stop_atr_mult               = 0.60;
input double strategy_take_atr_mult               = 1.00;
input int    strategy_entry_start_hhmm_ny         = 200;
input int    strategy_entry_end_hhmm_ny           = 300;
input int    strategy_spread_percentile_lookback  = 80;
input double strategy_spread_max_rank             = 0.80;

datetime Strategy_BrokerToNY(const datetime broker_time)
  {
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   const int ny_offset_hours = QM_IsUSDSTUTC(utc_time) ? -4 : -5;
   return utc_time + ny_offset_hours * 3600;
  }

int Strategy_HHMM(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_NthWeekdayOfMonth(const int year, const int month, const int weekday, const int nth)
  {
   int hits = 0;
   const int days = QM_DSTAware_DaysInMonth(year, month);
   for(int day = 1; day <= days; ++day)
     {
      MqlDateTime dt;
      ZeroMemory(dt);
      dt.year = year;
      dt.mon = month;
      dt.day = day;
      const datetime t = StructToTime(dt);
      MqlDateTime checked;
      TimeToStruct(t, checked);
      if(checked.day_of_week != weekday)
         continue;
      ++hits;
      if(hits == nth)
         return day;
     }
   return -1;
  }

int Strategy_LastWeekdayOfMonth(const int year, const int month, const int weekday)
  {
   for(int day = QM_DSTAware_DaysInMonth(year, month); day >= 1; --day)
     {
      MqlDateTime dt;
      ZeroMemory(dt);
      dt.year = year;
      dt.mon = month;
      dt.day = day;
      const datetime t = StructToTime(dt);
      MqlDateTime checked;
      TimeToStruct(t, checked);
      if(checked.day_of_week == weekday)
         return day;
     }
   return -1;
  }

bool Strategy_IsUSHolidayOrEarlyCloseNY(const datetime ny_time)
  {
   MqlDateTime dt;
   TimeToStruct(ny_time, dt);

   if((dt.mon == 1 && dt.day == 1) ||
      (dt.mon == 6 && dt.day == 19) ||
      (dt.mon == 7 && dt.day == 4) ||
      (dt.mon == 12 && dt.day == 25))
      return true;

   if(dt.mon == 1 && dt.day == Strategy_NthWeekdayOfMonth(dt.year, 1, 1, 3))
      return true;
   if(dt.mon == 2 && dt.day == Strategy_NthWeekdayOfMonth(dt.year, 2, 1, 3))
      return true;
   if(dt.mon == 5 && dt.day == Strategy_LastWeekdayOfMonth(dt.year, 5, 1))
      return true;
   if(dt.mon == 9 && dt.day == Strategy_NthWeekdayOfMonth(dt.year, 9, 1, 1))
      return true;
   if(dt.mon == 11 && dt.day == Strategy_NthWeekdayOfMonth(dt.year, 11, 4, 4))
      return true;

   const int thanksgiving = Strategy_NthWeekdayOfMonth(dt.year, 11, 4, 4);
   if(dt.mon == 11 && dt.day == thanksgiving + 1)
      return true;

   return false;
  }

bool Strategy_IsFirstWindowBarNY(const datetime broker_bar_open)
  {
   const datetime ny_bar_open = Strategy_BrokerToNY(broker_bar_open);
   if(Strategy_IsUSHolidayOrEarlyCloseNY(ny_bar_open))
      return false;

   MqlDateTime ny;
   TimeToStruct(ny_bar_open, ny);
   if(ny.day_of_week == 0 || ny.day_of_week == 6)
      return false;

   return (Strategy_HHMM(ny_bar_open) == strategy_entry_start_hhmm_ny);
  }

bool Strategy_MissingRecentM15Bars()
  {
   const int period_seconds = PeriodSeconds(strategy_signal_tf);
   if(period_seconds <= 0)
      return true;

   for(int shift = 1; shift <= 4; ++shift)
     {
      const datetime newer_bar = iTime(_Symbol, strategy_signal_tf, shift);
      const datetime older_bar = iTime(_Symbol, strategy_signal_tf, shift + 1);
      if(newer_bar <= 0 || older_bar <= 0)
         return true;
      if((int)(newer_bar - older_bar) != period_seconds)
         return true;
     }
   return false;
  }

double Strategy_CurrentSpreadPoints()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return 0.0;
   return (ask - bid) / point;
  }

bool Strategy_SpreadWithinRollingPercentile()
  {
   const double current_spread = Strategy_CurrentSpreadPoints();
   if(current_spread <= 0.0 || strategy_spread_percentile_lookback <= 0)
      return false;

   int usable = 0;
   int less_or_equal = 0;
   for(int shift = 1; shift <= strategy_spread_percentile_lookback; ++shift)
     {
      const long hist_spread = iSpread(_Symbol, strategy_signal_tf, shift);
      if(hist_spread <= 0)
         continue;
      ++usable;
      if((double)hist_spread <= current_spread)
         ++less_or_equal;
     }

   if(usable <= 0)
      return false;

   const double rank = (double)less_or_equal / (double)usable;
   return (rank <= strategy_spread_max_rank);
  }

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &position_type)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool Strategy_StoppedOutTodayNY()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const datetime now = TimeCurrent();
   const int today_key = Strategy_DateKey(Strategy_BrokerToNY(now));
   if(!HistorySelect(now - 3 * 86400, now))
      return false;

   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;
      if((ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON) != DEAL_REASON_SL)
         continue;
      const datetime close_time = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      if(Strategy_DateKey(Strategy_BrokerToNY(close_time)) == today_key)
         return true;
     }
   return false;
  }

bool Strategy_PriorUSCashReturnNegativeEnough()
  {
   const datetime current_ny = Strategy_BrokerToNY(TimeCurrent());
   const int current_key = Strategy_DateKey(current_ny);
   int session_key = 0;
   double cash_open = 0.0;
   double cash_close = 0.0;
   datetime session_time = 0;

   for(int shift = 1; shift <= 700; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, strategy_signal_tf, shift);
      if(bar_time <= 0)
         break;

      const datetime ny_bar_time = Strategy_BrokerToNY(bar_time);
      const int key = Strategy_DateKey(ny_bar_time);
      if(key >= current_key)
         continue;

      if(session_key == 0)
        {
         session_key = key;
         session_time = ny_bar_time;
        }
      else if(key != session_key)
        {
         break;
        }

      const int hhmm = Strategy_HHMM(ny_bar_time);
      if(hhmm == 930)
         cash_open = iOpen(_Symbol, strategy_signal_tf, shift);
      if(hhmm == 1545)
         cash_close = iClose(_Symbol, strategy_signal_tf, shift);
     }

   if(session_key == 0 || cash_open <= 0.0 || cash_close <= 0.0)
      return false;
   if(Strategy_IsUSHolidayOrEarlyCloseNY(session_time))
      return false;

   const double atr_h1 = QM_ATR(_Symbol, strategy_prior_return_tf, strategy_atr_period, 1);
   if(atr_h1 <= 0.0)
      return false;

   return ((cash_close - cash_open) <= -(strategy_prior_return_atr_mult * atr_h1));
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
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

   if(strategy_signal_tf != PERIOD_M15 || strategy_atr_period <= 0)
      return false;

   const datetime current_bar = iTime(_Symbol, strategy_signal_tf, 0);
   if(current_bar <= 0 || !Strategy_IsFirstWindowBarNY(current_bar))
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   if(Strategy_SelectOurPosition(ticket, position_type))
      return false;
   if(Strategy_StoppedOutTodayNY())
      return false;
   if(Strategy_MissingRecentM15Bars())
      return false;
   if(!Strategy_SpreadWithinRollingPercentile())
      return false;
   if(!Strategy_PriorUSCashReturnNegativeEnough())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr_m15 = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(ask <= 0.0 || atr_m15 <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = ask;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, atr_m15, strategy_stop_atr_mult);
   req.tp = QM_TakeATRFromValue(_Symbol, QM_BUY, ask, atr_m15, strategy_take_atr_mult);
   req.reason = "OVERNIGHT_DRIFT_LONG";
   return (req.sl > 0.0 && req.tp > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_SelectOurPosition(ticket, position_type))
      return false;

   const datetime ny_now = Strategy_BrokerToNY(TimeCurrent());
   const int hhmm = Strategy_HHMM(ny_now);
   return (hhmm >= strategy_entry_end_hhmm_ny || hhmm < strategy_entry_start_hhmm_ny);
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
