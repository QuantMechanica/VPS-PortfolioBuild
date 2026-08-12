#property strict
#property version   "5.0"
#property description "QM5_20023 US-index macro-announcement-day premium"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20023 - US-index macro-announcement-day premium
// -----------------------------------------------------------------------------
// On a broker day containing an exact whitelisted USD macro release, buy after
// the first H1 bar completes, hold a frozen 2.75 x completed-D1 ATR(20) stop,
// and flatten in the last broker-day H1 bar. The event-day attempt is consumed
// before quote/ATR/order checks and persisted by magic so restarts, rejection,
// or a same-day stop-out cannot create a second package.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20023;
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
input string strategy_event_whitelist   = "NFP,CPI,PPI,FOMC";
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 2.75;
input string strategy_entry_bar          = "first_h1_of_event_day";
input string strategy_exit_bar           = "last_h1_of_event_day";
input int    strategy_max_spread_points  = 2500;

const string STRATEGY_CALENDAR_PATH =
   "QM5_20023_announcement_calendar_20150101_20250404.csv";
const string STRATEGY_CALENDAR_SHA256 =
   "411ae4af3dbe261e373705660e28b81e7c5dfc7398f38516e07effff71cd73af";
const int STRATEGY_CALENDAR_EXPECTED_ROWS = 451;
const int STRATEGY_CALENDAR_EXPECTED_EVENT_DAYS = 439;
const int STRATEGY_LAST_H1_HOUR_BROKER = 23;

int    g_strategy_event_day_keys[];
bool   g_strategy_calendar_loaded = false;
bool   g_strategy_calendar_available = false;
int    g_strategy_calendar_first_day_key = 0;
int    g_strategy_calendar_last_day_key = 0;
bool   g_strategy_attempt_state_loaded = false;
string g_strategy_attempt_state_key = "";
int    g_strategy_last_attempt_day_key = 0;

int Strategy_DayKey(const datetime value)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

datetime Strategy_DayStart(const int day_key)
  {
   if(day_key < 19000101)
      return 0;

   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = day_key / 10000;
   parts.mon = (day_key / 100) % 100;
   parts.day = day_key % 100;
   if(parts.mon < 1 || parts.mon > 12 || parts.day < 1 || parts.day > 31)
      return 0;
   return StructToTime(parts);
  }

bool Strategy_EventNameWhitelisted(const string raw_name)
  {
   const string event_name = QM_NewsUpper(QM_NewsStripQuotes(raw_name));
   return (event_name == "NONFARM PAYROLLS" ||
           event_name == "NON-FARM EMPLOYMENT CHANGE" ||
           event_name == "CPI M/M" ||
           event_name == "PPI M/M" ||
           event_name == "FOMC STATEMENT" ||
           event_name == "FEDERAL FUNDS RATE");
  }

void Strategy_AddEventDay(const int day_key)
  {
   if(day_key <= 0)
      return;
   const int count = ArraySize(g_strategy_event_day_keys);
   if(count > 0 && g_strategy_event_day_keys[count - 1] == day_key)
      return;
   for(int index = 0; index < count; ++index)
      if(g_strategy_event_day_keys[index] == day_key)
         return;
   ArrayResize(g_strategy_event_day_keys, count + 1);
   g_strategy_event_day_keys[count] = day_key;
  }

bool Strategy_LoadTesterCalendar()
  {
   g_strategy_calendar_loaded = true;
   g_strategy_calendar_available = false;
   g_strategy_calendar_first_day_key = 0;
   g_strategy_calendar_last_day_key = 0;
   ArrayResize(g_strategy_event_day_keys, 0);

   const string calendar_base = QM_NewsBasename(STRATEGY_CALENDAR_PATH);
   int handle = INVALID_HANDLE;
   if(StringLen(calendar_base) > 0)
      handle = FileOpen(calendar_base,
                        FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON,
                        ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(STRATEGY_CALENDAR_PATH,
                        FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON,
                        ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(STRATEGY_CALENDAR_PATH,
                        FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ,
                        ',');
   if(handle == INVALID_HANDLE)
     {
      QM_LogEvent(QM_ERROR, SETUP_DATA_MISSING,
                  "{\"component\":\"announcement_calendar\",\"reason\":\"open_failed\"}");
      return false;
     }

   int parsed_rows = 0;
   while(!FileIsEnding(handle))
     {
      const string event_time = FileReadString(handle);
      if(FileIsEnding(handle) && StringLen(event_time) == 0)
         break;
      const string event_currency = FileReadString(handle);
      const string event_name = FileReadString(handle);
      const string event_impact = FileReadString(handle);
      while(!FileIsEnding(handle) && !FileIsLineEnding(handle))
         FileReadString(handle);

      if(QM_NewsUpper(QM_NewsStripQuotes(event_time)) == "DATETIME")
         continue;

      datetime event_utc = 0;
      if(!QM_NewsParseDateTimeUTC(event_time, event_utc))
         continue;
      const datetime event_broker = QM_UTCToBroker(event_utc);
      const int day_key = Strategy_DayKey(event_broker);
      if(day_key <= 0)
         continue;

      parsed_rows++;
      if(g_strategy_calendar_first_day_key == 0 ||
         day_key < g_strategy_calendar_first_day_key)
         g_strategy_calendar_first_day_key = day_key;
      if(day_key > g_strategy_calendar_last_day_key)
         g_strategy_calendar_last_day_key = day_key;

      const string currency = QM_NewsUpper(QM_NewsStripQuotes(event_currency));
      if(currency == "USD" && Strategy_EventNameWhitelisted(event_name))
         Strategy_AddEventDay(day_key);
     }

   FileClose(handle);
   g_strategy_calendar_available =
      (parsed_rows == STRATEGY_CALENDAR_EXPECTED_ROWS &&
       g_strategy_calendar_first_day_key > 0 &&
       g_strategy_calendar_last_day_key >= g_strategy_calendar_first_day_key &&
       ArraySize(g_strategy_event_day_keys) == STRATEGY_CALENDAR_EXPECTED_EVENT_DAYS);
   if(!g_strategy_calendar_available)
     {
      QM_LogEvent(QM_ERROR, SETUP_DATA_MISSING,
                  StringFormat("{\"component\":\"announcement_calendar\",\"reason\":\"calendar_contract_mismatch\",\"rows\":%d,\"expected_rows\":%d,\"event_days\":%d,\"expected_event_days\":%d}",
                               parsed_rows,
                               STRATEGY_CALENDAR_EXPECTED_ROWS,
                               ArraySize(g_strategy_event_day_keys),
                               STRATEGY_CALENDAR_EXPECTED_EVENT_DAYS));
      return false;
     }

   QM_LogEvent(QM_INFO, "ANNOUNCEMENT_CALENDAR_LOADED",
               StringFormat("{\"file\":\"%s\",\"pinned_sha256\":\"%s\",\"rows\":%d,\"event_days\":%d,\"first_day\":%d,\"last_day\":%d}",
                            calendar_base,
                            STRATEGY_CALENDAR_SHA256,
                            parsed_rows,
                            ArraySize(g_strategy_event_day_keys),
                            g_strategy_calendar_first_day_key,
                            g_strategy_calendar_last_day_key));
   return true;
  }

bool Strategy_TesterDayHasEvent(const int day_key)
  {
   if(!g_strategy_calendar_loaded && !Strategy_LoadTesterCalendar())
      return false;
   if(!g_strategy_calendar_available ||
      day_key < g_strategy_calendar_first_day_key ||
      day_key > g_strategy_calendar_last_day_key)
      return false;

   int left = 0;
   int right = ArraySize(g_strategy_event_day_keys) - 1;
   while(left <= right)
     {
      const int middle = (left + right) / 2;
      const int candidate = g_strategy_event_day_keys[middle];
      if(candidate == day_key)
         return true;
      if(candidate < day_key)
         left = middle + 1;
      else
         right = middle - 1;
     }
   return false;
  }

bool Strategy_LiveDayHasEvent(const int day_key)
  {
   const datetime day_start = Strategy_DayStart(day_key);
   if(day_start <= 0)
      return false;

   MqlCalendarValue values[];
   const int count = CalendarValueHistory(values,
                                           day_start,
                                           day_start + 86399);
   if(count < 0)
     {
      QM_LogEvent(QM_ERROR, SETUP_DATA_MISSING,
                  "{\"component\":\"native_announcement_calendar\",\"reason\":\"query_failed\"}");
      return false;
     }
   if(count == 0)
     {
      if(!QM_NewsLiveCalendarHealthy())
         QM_LogEvent(QM_ERROR, SETUP_DATA_MISSING,
                     "{\"component\":\"native_announcement_calendar\",\"reason\":\"calendar_unavailable\"}");
      return false;
     }

   for(int index = 0; index < count; ++index)
     {
      MqlCalendarEvent calendar_event;
      if(!CalendarEventById(values[index].event_id, calendar_event))
         return false;
      MqlCalendarCountry calendar_country;
      if(!CalendarCountryById(calendar_event.country_id, calendar_country))
         return false;
      if(QM_NewsUpper(calendar_country.currency) != "USD")
         continue;
      if(Strategy_EventNameWhitelisted(calendar_event.name))
         return true;
     }
   return false;
  }

bool Strategy_DayHasWhitelistedEvent(const int day_key)
  {
   if(MQLInfoInteger(MQL_TESTER))
      return Strategy_TesterDayHasEvent(day_key);
   return Strategy_LiveDayHasEvent(day_key);
  }

// QM_IsNewCalendarPeriod(PERIOD_D1) latches true exactly once, at the tick
// where the broker day's FIRST H1 bar OPENS. The card requires acting on the
// first COMPLETED H1 bar — one H1 bar later, when that bar's close reopens
// bar[0] at hour+1 — so this only arms a pending flag on the D1 rollover and
// fires on the following new-H1-bar call. Never uses raw iTime for the
// calendar-period key (framework corset: calendar-period keys go through
// QM_CalendarPeriodKey / QM_IsNewCalendarPeriod only).
bool   g_strategy_day_open_pending = false;
int    g_strategy_pending_day_key  = 0;

bool Strategy_FirstCompletedH1OfDay(int &day_key)
  {
   if(QM_IsNewCalendarPeriod(PERIOD_D1))
     {
      g_strategy_pending_day_key = QM_CalendarPeriodKey(PERIOD_D1, _Symbol, 0);
      g_strategy_day_open_pending = (g_strategy_pending_day_key > 0);
      return false; // this call is the day's first H1 bar OPENING, not yet completed
     }
   if(g_strategy_day_open_pending)
     {
      g_strategy_day_open_pending = false;
      day_key = g_strategy_pending_day_key;
      return (day_key > 0);
     }
   return false;
  }

string Strategy_AttemptStateKey()
  {
   return StringFormat("QM5_20023_ANNOUNCE_ATTEMPT_%d",
                       QM_FrameworkMagic());
  }

void Strategy_LoadAttemptState(const int current_day_key)
  {
   if(g_strategy_attempt_state_loaded)
      return;
   g_strategy_attempt_state_loaded = true;
   g_strategy_attempt_state_key = Strategy_AttemptStateKey();
   g_strategy_last_attempt_day_key = 0;
   if(!GlobalVariableCheck(g_strategy_attempt_state_key))
      return;

   const double stored = GlobalVariableGet(g_strategy_attempt_state_key);
   const int stored_day_key = (int)MathRound(stored);
   if(current_day_key > 0 &&
      MathIsValidNumber(stored) &&
      stored_day_key >= 19000101 &&
      stored_day_key <= current_day_key)
     {
      g_strategy_last_attempt_day_key = stored_day_key;
      return;
     }

   // Tester agents may retain globals between historical replays. A marker
   // from a future replay cannot belong to the current run.
   GlobalVariableDel(g_strategy_attempt_state_key);
  }

bool Strategy_RecordDayAttempt(const int day_key)
  {
   if(day_key <= 0 || g_strategy_attempt_state_key == "")
      return false;
   g_strategy_last_attempt_day_key = day_key;
   return (GlobalVariableSet(g_strategy_attempt_state_key,
                             (double)day_key) > 0);
  }

bool Strategy_HasManagedPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_DayAlreadyAttempted(const int day_key)
  {
   if(day_key <= 0 || g_strategy_last_attempt_day_key == day_key)
      return true;
   if(Strategy_HasManagedPosition())
      return true;

   const datetime day_start = Strategy_DayStart(day_key);
   if(day_start <= 0 || !HistorySelect(day_start, TimeCurrent()))
      return true;

   const int magic = QM_FrameworkMagic();
   for(int index = HistoryDealsTotal() - 1; index >= 0; --index)
     {
      const ulong deal_ticket = HistoryDealGetTicket(index);
      if(deal_ticket == 0)
         continue;
      if((int)HistoryDealGetInteger(deal_ticket, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
      if(Strategy_DayKey(deal_time) == day_key)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   int expected_slot = -1;
   if(_Symbol == "SP500.DWX")
      expected_slot = 0;
   else if(_Symbol == "NDX.DWX")
      expected_slot = 1;
   else if(_Symbol == "WS30.DWX")
      expected_slot = 2;

   if(qm_ea_id != 20023 ||
      expected_slot < 0 ||
      qm_magic_slot_offset != expected_slot ||
      _Period != PERIOD_H1)
      return true;
   if(!qm_friday_close_enabled || qm_friday_close_hour_broker != 21)
      return true;
   if(strategy_event_whitelist != "NFP,CPI,PPI,FOMC" ||
      strategy_atr_period != 20 ||
      MathAbs(strategy_atr_sl_mult - 2.75) > 1.0e-12 ||
      strategy_entry_bar != "first_h1_of_event_day" ||
      strategy_exit_bar != "last_h1_of_event_day" ||
      strategy_max_spread_points != 2500)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "IDX_MACRO_ANNOUNCE_DAY_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   int event_day_key = 0;
   if(!Strategy_FirstCompletedH1OfDay(event_day_key))
      return false;
   if(!Strategy_DayHasWhitelistedEvent(event_day_key))
      return false;

   Strategy_LoadAttemptState(event_day_key);
   if(Strategy_DayAlreadyAttempted(event_day_key))
      return false;

   // Consume the package before quote, spread, ATR, stop, risk, or broker
   // authorization checks. A rejection or invalid prerequisite cannot re-arm
   // the same event day.
   if(!Strategy_RecordDayAttempt(event_day_key))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || ask < bid)
      return false;
   if(ask > bid &&
      ((ask - bid) / point) > (double)strategy_max_spread_points)
      return false;

   const double atr_last =
      QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_last <= 0.0 || !MathIsValidNumber(atr_last))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                req.type,
                                ask,
                                atr_last,
                                strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || !MathIsValidNumber(req.sl) || req.sl >= ask)
      return false;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Frozen broker stop only: no trailing, break-even, partial close,
   // scale-in, pyramid, or stop modification is authorized by the card.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const datetime broker_now = TimeCurrent();
   const int current_day_key = Strategy_DayKey(broker_now);
   MqlDateTime current_parts;
   ZeroMemory(current_parts);
   if(current_day_key <= 0 || !TimeToStruct(broker_now, current_parts))
      return false;

   for(int index = PositionsTotal() - 1; index >= 0; --index)
     {
      const ulong ticket = PositionGetTicket(index);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened =
         (datetime)PositionGetInteger(POSITION_TIME);
      const int opened_day_key = Strategy_DayKey(opened);
      if(opened_day_key <= 0 || opened_day_key != current_day_key)
         return true;
      if(current_parts.hour >= STRATEGY_LAST_H1_HOUR_BROKER)
         return true;
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // The traded condition is the scheduled event day itself. Temporal and
   // compliance axes default OFF/NONE so the standard blackout cannot suppress
   // the opening package; the central hook remains callable for Q09/P8 tests.
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
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
