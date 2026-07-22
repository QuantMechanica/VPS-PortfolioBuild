#property strict
#property version   "5.0"
#property description "QM5_20037 LBMA PM gold-auction breakout"

#include <QM/QM_Common.mqh>

// Strategy Card: QM5_20037_lbma-pm-brk, G0 APPROVED 2026-07-22.
// Auction membership, timezone provenance and commission are governed runtime
// dependencies. Missing or stale inputs fail closed; no date or cost is guessed.

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
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 20037;
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
input string strategy_variant_id        = "LBMA_PM_BRK_BASELINE";
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M5;
input double strategy_max_cost_r        = 0.10;
input double strategy_round_turn_commission_usd_per_lot = 0.0;
input string strategy_auction_ledger_file = "QM5_20037_lbma_pm_auction_calendar.csv";
input string strategy_calendar_valid_through = "2025.12.31";
input string strategy_tzdb_version      = "";

int      g_auction_date_key[];
datetime g_pre_bar_utc[];
datetime g_confirmation1_utc[];
datetime g_confirmation2_utc[];
datetime g_exit_utc[];
bool     g_auction_scheduled[];
bool     g_calendar_attempted = false;
bool     g_calendar_ready = false;
int      g_last_attempt_date_key = 0;
datetime g_active_exit_broker = 0;

string Strategy_Trimmed(string value)
  {
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
  }

bool Strategy_IsSha256(const string value)
  {
   if(StringLen(value) != 64)
      return false;
   const string hex = "0123456789abcdefABCDEF";
   for(int i = 0; i < 64; ++i)
     {
      if(StringFind(hex, StringSubstr(value, i, 1)) < 0)
         return false;
     }
   return true;
  }

bool Strategy_ParseBoolean(const string value, bool &parsed)
  {
   if(value == "1" || value == "true" || value == "TRUE")
     {
      parsed = true;
      return true;
     }
   if(value == "0" || value == "false" || value == "FALSE")
     {
      parsed = false;
      return true;
     }
   return false;
  }

datetime Strategy_ParseUtcTimestamp(string value)
  {
   value = Strategy_Trimmed(value);
   const int n = StringLen(value);
   if(n < 2 || StringSubstr(value, n - 1, 1) != "Z")
      return 0;
   value = StringSubstr(value, 0, n - 1);
   StringReplace(value, "-", ".");
   StringReplace(value, "T", " ");
   return StringToTime(value);
  }

datetime Strategy_UtcDateTime(const int year,
                              const int month,
                              const int day,
                              const int hour,
                              const int minute)
  {
   MqlDateTime parts;
   ZeroMemory(parts);
   parts.year = year;
   parts.mon = month;
   parts.day = day;
   parts.hour = hour;
   parts.min = minute;
   return StructToTime(parts);
  }

datetime Strategy_LastSundayUtc(const int year, const int month, const int hour)
  {
   const int next_year = (month == 12) ? year + 1 : year;
   const int next_month = (month == 12) ? 1 : month + 1;
   const datetime last_day = Strategy_UtcDateTime(next_year, next_month, 1, 0, 0) - 24 * 60 * 60;
   MqlDateTime parts;
   if(!TimeToStruct(last_day, parts))
      return 0;
   return last_day - parts.day_of_week * 24 * 60 * 60 + hour * 60 * 60;
  }

bool Strategy_IsUKDSTUtc(const datetime utc)
  {
   MqlDateTime parts;
   if(utc <= 0 || !TimeToStruct(utc, parts))
      return false;
   const datetime starts = Strategy_LastSundayUtc(parts.year, 3, 1);
   const datetime ends = Strategy_LastSundayUtc(parts.year, 10, 1);
   return (starts > 0 && ends > starts && utc >= starts && utc < ends);
  }

datetime Strategy_LondonLocal(const datetime utc)
  {
   return utc + (Strategy_IsUKDSTUtc(utc) ? 60 * 60 : 0);
  }

int Strategy_DateKey(const datetime value)
  {
   MqlDateTime parts;
   if(value <= 0 || !TimeToStruct(value, parts))
      return 0;
   return parts.year * 10000 + parts.mon * 100 + parts.day;
  }

int Strategy_ParseDateKey(string value)
  {
   value = Strategy_Trimmed(value);
   StringReplace(value, "-", ".");
   return Strategy_DateKey(StringToTime(value + " 00:00"));
  }

bool Strategy_LondonClockMatches(const datetime utc,
                                 const int date_key,
                                 const int hour,
                                 const int minute)
  {
   const datetime local = Strategy_LondonLocal(utc);
   MqlDateTime parts;
   if(!TimeToStruct(local, parts))
      return false;
   return (Strategy_DateKey(local) == date_key && parts.hour == hour &&
           parts.min == minute && parts.sec == 0);
  }

datetime Strategy_LondonLocalToUtc(const int date_key,
                                   const int hour,
                                   const int minute)
  {
   const int year = date_key / 10000;
   const int month = (date_key / 100) % 100;
   const int day = date_key % 100;
   datetime utc = Strategy_UtcDateTime(year, month, day, hour, minute);
   if(Strategy_IsUKDSTUtc(utc))
      utc -= 60 * 60;
   return utc;
  }

bool Strategy_ValidAuctionSource(const string url)
  {
   return (StringFind(url, "https") == 0 && StringFind(url, "://") > 0 &&
           StringFind(url, "lbma.org.uk") > 0);
  }

bool Strategy_AppendAuctionDate(const int date_key,
                                const datetime pre_bar_utc,
                                const datetime confirmation1_utc,
                                const datetime confirmation2_utc,
                                const datetime exit_utc,
                                const bool auction_scheduled)
  {
   const int n = ArraySize(g_auction_date_key);
   if(ArrayResize(g_auction_date_key, n + 1) != n + 1 ||
      ArrayResize(g_pre_bar_utc, n + 1) != n + 1 ||
      ArrayResize(g_confirmation1_utc, n + 1) != n + 1 ||
      ArrayResize(g_confirmation2_utc, n + 1) != n + 1 ||
      ArrayResize(g_exit_utc, n + 1) != n + 1 ||
      ArrayResize(g_auction_scheduled, n + 1) != n + 1)
      return false;
   g_auction_date_key[n] = date_key;
   g_pre_bar_utc[n] = pre_bar_utc;
   g_confirmation1_utc[n] = confirmation1_utc;
   g_confirmation2_utc[n] = confirmation2_utc;
   g_exit_utc[n] = exit_utc;
   g_auction_scheduled[n] = auction_scheduled;
   return true;
  }

bool Strategy_LoadAuctionCalendar()
  {
   ArrayResize(g_auction_date_key, 0);
   ArrayResize(g_pre_bar_utc, 0);
   ArrayResize(g_confirmation1_utc, 0);
   ArrayResize(g_confirmation2_utc, 0);
   ArrayResize(g_exit_utc, 0);
   ArrayResize(g_auction_scheduled, 0);

   const int required_valid_through = Strategy_ParseDateKey(strategy_calendar_valid_through);
   if(strategy_variant_id != "LBMA_PM_BRK_BASELINE" ||
      strategy_signal_tf != PERIOD_M5 || strategy_max_cost_r != 0.10 ||
      required_valid_through != 20251231 || StringLen(strategy_tzdb_version) == 0)
      return false;

   const int handle = FileOpen(strategy_auction_ledger_file,
                               FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON,
                               ',');
   if(handle == INVALID_HANDLE)
      return false;

   int rows = 0;
   int previous_date_key = 0;
   bool valid = true;
   while(!FileIsEnding(handle))
     {
      const string date_text = Strategy_Trimmed(FileReadString(handle));
      const string pre_text = Strategy_Trimmed(FileReadString(handle));
      const string confirmation1_text = Strategy_Trimmed(FileReadString(handle));
      const string confirmation2_text = Strategy_Trimmed(FileReadString(handle));
      const string exit_text = Strategy_Trimmed(FileReadString(handle));
      const string scheduled_text = Strategy_Trimmed(FileReadString(handle));
      const string valid_through_text = Strategy_Trimmed(FileReadString(handle));
      const string source_url = Strategy_Trimmed(FileReadString(handle));
      string retrieved_date = Strategy_Trimmed(FileReadString(handle));
      const string source_sha256 = Strategy_Trimmed(FileReadString(handle));
      const string tzdb_version = Strategy_Trimmed(FileReadString(handle));

      if(rows == 0 && date_text == "london_date" && pre_text == "pre_bar_utc")
         continue;
      if(date_text == "" && pre_text == "" && exit_text == "")
         continue;

      const int date_key = Strategy_ParseDateKey(date_text);
      const datetime pre_bar_utc = Strategy_ParseUtcTimestamp(pre_text);
      const datetime confirmation1_utc = Strategy_ParseUtcTimestamp(confirmation1_text);
      const datetime confirmation2_utc = Strategy_ParseUtcTimestamp(confirmation2_text);
      const datetime exit_utc = Strategy_ParseUtcTimestamp(exit_text);
      bool auction_scheduled = false;
      StringReplace(retrieved_date, "-", ".");

      if(date_key <= 0 || date_key <= previous_date_key || pre_bar_utc <= 0 ||
         confirmation1_utc <= 0 || confirmation2_utc <= 0 || exit_utc <= 0 ||
         !Strategy_LondonClockMatches(pre_bar_utc, date_key, 14, 55) ||
         !Strategy_LondonClockMatches(confirmation1_utc, date_key, 15, 0) ||
         !Strategy_LondonClockMatches(confirmation2_utc, date_key, 15, 5) ||
         !Strategy_LondonClockMatches(exit_utc, date_key, 15, 15) ||
         confirmation1_utc - pre_bar_utc != 5 * 60 ||
         confirmation2_utc - confirmation1_utc != 5 * 60 ||
         exit_utc - confirmation2_utc != 10 * 60 ||
         !Strategy_ParseBoolean(scheduled_text, auction_scheduled) ||
         Strategy_ParseDateKey(valid_through_text) != required_valid_through ||
         !Strategy_ValidAuctionSource(source_url) || StringToTime(retrieved_date) <= 0 ||
         !Strategy_IsSha256(source_sha256) || tzdb_version != strategy_tzdb_version ||
         !Strategy_AppendAuctionDate(date_key, pre_bar_utc, confirmation1_utc,
                                     confirmation2_utc, exit_utc, auction_scheduled))
        {
         valid = false;
         break;
        }
      previous_date_key = date_key;
      ++rows;
     }
   FileClose(handle);

   return (valid && rows > 0 && g_auction_date_key[0] / 10000 <= 2018 &&
           g_auction_date_key[rows - 1] / 10000 >= 2025);
  }

bool Strategy_EnsureCalendarLoaded()
  {
   if(g_calendar_attempted)
      return g_calendar_ready;
   g_calendar_attempted = true;
   g_calendar_ready = Strategy_LoadAuctionCalendar();
   if(!g_calendar_ready)
      QM_LogEvent(QM_ERROR,
                  "SETUP_DATA_MISSING",
                  StringFormat("{\"auction_ledger\":\"%s\",\"tzdb_version\":\"%s\"}",
                               strategy_auction_ledger_file, strategy_tzdb_version));
   return g_calendar_ready;
  }

int Strategy_FindAuctionDate(const int date_key)
  {
   int lo = 0;
   int hi = ArraySize(g_auction_date_key);
   while(lo < hi)
     {
      const int mid = lo + (hi - lo) / 2;
      if(g_auction_date_key[mid] < date_key)
         lo = mid + 1;
      else
         hi = mid;
     }
   if(lo < ArraySize(g_auction_date_key) && g_auction_date_key[lo] == date_key)
      return lo;
   return -1;
  }

bool Strategy_FindOurPosition(datetime &open_time)
  {
   open_time = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool Strategy_AttemptAlreadyMade(const int date_key, const int calendar_index)
  {
   if(g_last_attempt_date_key == date_key)
      return true;
   const datetime from_broker = QM_UTCToBroker(g_pre_bar_utc[calendar_index] - 60 * 60);
   if(from_broker <= 0 || !HistorySelect(from_broker, TimeCurrent()))
      return true;
   const int magic = QM_FrameworkMagic();
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 || (int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN && entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const datetime deal_utc = QM_BrokerToUTC((datetime)HistoryDealGetInteger(deal, DEAL_TIME));
      if(Strategy_DateKey(Strategy_LondonLocal(deal_utc)) == date_key)
         return true;
     }
   return false;
  }

double Strategy_TickNormalizedPrice(const double price)
  {
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(price <= 0.0 || tick_size <= 0.0)
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, MathRound(price / tick_size) * tick_size);
  }

int Strategy_ConfirmationOutcome(const bool armed_long,
                                 const double close_price,
                                 const double pre_high,
                                 const double pre_low)
  {
   if(close_price <= 0.0 || pre_high <= pre_low)
      return 0;
   if(armed_long)
     {
      if(close_price < pre_low)
         return -1;
      if(close_price > pre_high)
         return 1;
      return 0;
     }
   if(close_price > pre_high)
      return -1;
   if(close_price < pre_low)
      return 1;
   return 0;
  }

bool Strategy_CostAndVolumeAllow(const double entry_price, const double stop_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(AccountInfoString(ACCOUNT_CURRENCY) != "USD" || RISK_FIXED != 1000.0 ||
      RISK_PERCENT != 0.0 || point <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0 ||
      ask <= 0.0 || bid <= 0.0 || ask < bid || entry_price <= 0.0 || stop_price <= 0.0 ||
      strategy_round_turn_commission_usd_per_lot <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double risk_per_lot = (stop_distance / tick_size) * tick_value;
   const double spread_per_lot = ((ask - bid) / tick_size) * tick_value;
   if(risk_per_lot <= 0.0 ||
      (strategy_round_turn_commission_usd_per_lot + spread_per_lot) / risk_per_lot > strategy_max_cost_r)
      return false;

   const double sl_points = stop_distance / point;
   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(sl_points <= 0.0 || sl_points < (double)stop_level)
      return false;

   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   const double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || volume_min <= 0.0 || volume_max <= 0.0 || volume_step <= 0.0 ||
      lots < volume_min || lots > volume_max)
      return false;
   const double aligned = volume_min + MathRound((lots - volume_min) / volume_step) * volume_step;
   return (MathAbs(aligned - lots) <= volume_step * 1.0e-6 &&
           lots * risk_per_lot > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // TODO: e.g. "only trade London session" or "skip if ADX<20"
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // TODO: build req.type / req.price / req.sl / req.tp / req.reason /
   //       req.symbol_slot / req.expiration_seconds — set ALL fields (the
   //       caller ZeroMemory's req; symbol_slot stays 0 for single-symbol
   //       EAs). Lots are NOT part of QM_EntryRequest: sizing happens inside
   //       QM_Entry via QM_LotsForRisk from req.sl.
   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // TODO: e.g.
   //   const int magic = QM_FrameworkMagic();
   //   for(int i = PositionsTotal() - 1; i >= 0; --i) {
   //       const ulong ticket = PositionGetTicket(i);
   //       if(!PositionSelectByTicket(ticket)) continue;
   //       if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
   //       QM_TM_MoveToBreakEven(ticket, /*trigger_pips=*/30, /*buffer=*/2);
   //       QM_TM_TrailATR(ticket, /*atr_period=*/14, /*atr_mult=*/2.0);
   //   }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // TODO: when to close manually (separate from SL/TP and trade management)
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
