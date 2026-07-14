#property strict
#property version   "5.0"
#property description "QM5_13078 XTI Post-Holiday Gasoline Pull-Forward Fade"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13078;
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
input int    strategy_rally_lookback_days  = 5;     // completed bars before pre-holiday close used as rally reference
input int    strategy_trend_period         = 20;    // SMA period for the trend filter
input int    strategy_atr_period           = 20;    // ATR period for rally/drop/stop/target sizing
input double strategy_min_rally_atr        = 0.70;  // min pre-holiday rally size, in ATR, vs rally_lookback close
input double strategy_max_post_drop_atr    = 1.25;  // max allowed drop from holiday close to prior completed close, in ATR
input double strategy_mean_reclaim_atr     = 0.20;  // early-exit trigger: prior close this far below trend SMA, in ATR
input double strategy_atr_sl_mult          = 2.60;  // hard SL distance above short entry, in ATR
input double strategy_atr_tp_mult          = 2.20;  // TP distance below short entry, in ATR
input int    strategy_max_hold_days        = 7;     // time-stop, in calendar days since entry
input int    strategy_max_spread_points    = 1000;  // entry spread cap, in points

// -----------------------------------------------------------------------------
// Calendar / date helpers (bespoke structural logic — no QM_* equivalent exists
// for US-holiday date arithmetic). Pure MqlDateTime/StructToTime math, no
// iTime/bar-series access, so none of these need a perf-allowed tag.
// day_of_week convention: 0=Sunday .. 6=Saturday (MqlDateTime), so Monday=1.
// -----------------------------------------------------------------------------

datetime DateFloor(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime MakeDate(const int year, const int month, const int day)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   return StructToTime(dt);
  }

int DayOfWeekOf(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.day_of_week;
  }

int YearOf(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year;
  }

bool SameDate(const datetime a, const datetime b)
  {
   return (DateFloor(a) == DateFloor(b));
  }

bool IsWeekdayDate(const datetime value)
  {
   const int dow = DayOfWeekOf(value);
   return (dow >= 1 && dow <= 5);
  }

datetime NthWeekdayOfMonth(const int year, const int month, const int weekday, const int ordinal)
  {
   const datetime month_start = MakeDate(year, month, 1);
   int seen = 0;
   for(int i = 0; i < 31; ++i)
     {
      const datetime candidate = month_start + i * 86400;
      MqlDateTime dt;
      TimeToStruct(candidate, dt);
      if(dt.mon != month)
         break;
      if(dt.day_of_week == weekday)
        {
         seen++;
         if(seen == ordinal)
            return DateFloor(candidate);
        }
     }
   return 0;
  }

datetime LastWeekdayOfMonth(const int year, const int month, const int weekday)
  {
   datetime found = 0;
   const datetime month_start = MakeDate(year, month, 1);
   for(int i = 0; i < 31; ++i)
     {
      const datetime candidate = month_start + i * 86400;
      MqlDateTime dt;
      TimeToStruct(candidate, dt);
      if(dt.mon != month)
         break;
      if(dt.day_of_week == weekday)
         found = DateFloor(candidate);
     }
   return found;
  }

datetime ObservedFixedHoliday(const int year, const int month, const int day)
  {
   const datetime actual = MakeDate(year, month, day);
   const int dow = DayOfWeekOf(actual);
   if(dow == 0)
      return actual + 86400;   // Sunday -> observed Monday
   if(dow == 6)
      return actual - 86400;   // Saturday -> observed Friday
   return actual;
  }

datetime NextWeekdayAfter(const datetime value)
  {
   datetime candidate = DateFloor(value) + 86400;
   for(int i = 0; i < 10; ++i)
     {
      if(IsWeekdayDate(candidate))
         return candidate;
      candidate += 86400;
     }
   return 0;
  }

datetime PrevWeekdayBefore(const datetime value)
  {
   datetime candidate = DateFloor(value) - 86400;
   for(int i = 0; i < 10; ++i)
     {
      if(IsWeekdayDate(candidate))
         return candidate;
      candidate -= 86400;
     }
   return 0;
  }

// Locates the D1 bar shift index whose bar-open date equals date_value.
// Returns -1 if no such bar exists (e.g. broker has no quote for that date) —
// callers must treat -1 as "state unavailable" per the card's Filters section.
int BarShiftForDate(const string sym, const datetime date_value)
  {
   if(date_value <= 0)
      return -1;
   return iBarShift(sym, PERIOD_D1, date_value, true);
  }

// One open position per magic (card: no pyramiding); used by both the entry
// gate and the exit hook.
bool FindOpenPosition(const int magic, ulong &out_ticket, datetime &out_open_time)
  {
   out_ticket = 0;
   out_open_time = 0;
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
      out_ticket = ticket;
      out_open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// Restart-safe "already traded this holiday" guard (card Filters: "Skip if the
// configured holiday date has already been traded for this year"). Holidays
// only ever increase through a chronological run, so a single high-water mark
// suffices instead of a 3-slot set.
datetime g_last_traded_holiday_date = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implemented against QM5_13078_xti-holiday-gas-fade.md.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   // Card is single-symbol XTIUSD.DWX only. Blocking here also suspends
   // management/exit for the tick (skeleton ordering), so keep this to the
   // one defensive check that should never legitimately fire in production —
   // period/holiday/spread gating all belongs in Strategy_EntrySignal, which
   // only skips the entry path.
   return (_Symbol != "XTIUSD.DWX");
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_D1)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const datetime today = DateFloor(TimeCurrent());
   if(today <= 0)
      return false;

   const int year = YearOf(today);
   datetime holidays[3];
   holidays[0] = LastWeekdayOfMonth(year, 5, 1);        // Memorial Day (last Monday of May)
   holidays[1] = ObservedFixedHoliday(year, 7, 4);       // Independence Day (observed)
   holidays[2] = NthWeekdayOfMonth(year, 9, 1, 1);       // Labor Day (first Monday of September)

   for(int h = 0; h < 3; ++h)
     {
      const datetime holiday = holidays[h];
      if(holiday <= 0)
         continue;
      if(holiday <= g_last_traded_holiday_date)
         continue; // already traded this holiday date

      const datetime entry_day = NextWeekdayAfter(holiday);
      if(entry_day <= 0 || !SameDate(today, entry_day))
         continue;

      // Holiday close: skip (state unavailable) if the broker has no D1 bar
      // dated exactly on the holiday.
      const int holiday_shift = BarShiftForDate(_Symbol, holiday);
      if(holiday_shift < 0)
         continue;
      const double holiday_close = iClose(_Symbol, PERIOD_D1, holiday_shift); // perf-allowed: holiday-anchor close, once per D1 bar behind QM_IsNewBar
      if(holiday_close <= 0.0)
         continue;

      // Pre-holiday close + rally-lookback reference close.
      const datetime pre_holiday_day = PrevWeekdayBefore(holiday);
      const int pre_holiday_shift = BarShiftForDate(_Symbol, pre_holiday_day);
      if(pre_holiday_shift < 0)
         continue;
      const double pre_holiday_close = iClose(_Symbol, PERIOD_D1, pre_holiday_shift); // perf-allowed: pre-holiday rally anchor
      if(pre_holiday_close <= 0.0)
         continue;

      const int rally_ref_shift = pre_holiday_shift + MathMax(1, strategy_rally_lookback_days);
      const double rally_ref_close = iClose(_Symbol, PERIOD_D1, rally_ref_shift); // perf-allowed: rally lookback reference close
      if(rally_ref_close <= 0.0)
         continue;

      // Prior completed close (shift 1 relative to this entry bar).
      const double prior_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: prior completed D1 close for trend/drop filters
      if(prior_close <= 0.0)
         continue;

      const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
      if(atr <= 0.0)
         continue;

      const double sma = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1);
      if(sma <= 0.0)
         continue;

      // Filter 1: prior completed close above trend SMA.
      if(prior_close <= sma)
         continue;

      // Filter 2: pre-holiday rally >= min_rally_atr ATR above the lookback close.
      if((pre_holiday_close - rally_ref_close) < strategy_min_rally_atr * atr)
         continue;

      // Filter 3: prior completed close not below the holiday close by more
      // than max_post_drop_atr ATR.
      if((holiday_close - prior_close) > strategy_max_post_drop_atr * atr)
         continue;

      // Filter 4: spread cap (never block on zero spread — only a genuinely
      // wide spread; .DWX quotes ask==bid in the tester).
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         continue;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         continue;

      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, bid, atr, strategy_atr_sl_mult);
      if(sl <= 0.0 || sl <= bid)
         continue;
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, bid, atr, strategy_atr_tp_mult);
      if(tp <= 0.0 || tp >= bid)
         continue;

      req.price = bid;
      req.sl = sl;
      req.tp = tp;
      req.reason = "XTI_HOLIDAY_GAS_FADE_SHORT";
      g_last_traded_holiday_date = holiday;
      return true;
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no pyramiding, grid, martingale, partial close, or
   // trailing stop — management is limited to the deterministic time and
   // mean-reclaim close handled in Strategy_ExitSignal below.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   ulong ticket = 0;
   datetime open_time = 0;
   if(!FindOpenPosition(magic, ticket, open_time))
      return false;

   if(open_time > 0 && (TimeCurrent() - open_time) >= (long)MathMax(1, strategy_max_hold_days) * 86400)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double sma = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1);
   const double prior_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: mean-reclaim close reference, single per-tick read while a position is open
   if(atr > 0.0 && sma > 0.0 && prior_close > 0.0)
     {
      if((sma - prior_close) >= strategy_mean_reclaim_atr * atr)
         return true;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
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
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
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

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
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
