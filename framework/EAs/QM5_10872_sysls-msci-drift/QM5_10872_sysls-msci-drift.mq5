#property strict
#property version   "5.0"
#property description "QM5_10872 SystematicLS MSCI Rebalance Drift"

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
input int    qm_ea_id                   = 10872;
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
input string strategy_event_csv_path       = "QM5_10872_msci_rebalance_events.csv";
input double strategy_net_pressure_pct     = 0.20;
input int    strategy_min_trading_days     = 5;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_stop_mult        = 1.5;
input double strategy_max_spread_stop_frac = 0.10;

#define QM5_10872_SYMBOL_COUNT 4
#define QM5_10872_MAX_EVENTS_PER_BAR 16

string g_strategy_symbols[QM5_10872_SYMBOL_COUNT] =
  {
   "GDAXI.DWX", "NDX.DWX", "WS30.DWX", "SP500.DWX"
  };

int Strategy_DayKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime Strategy_ParseDate(string raw)
  {
   StringTrimLeft(raw);
   StringTrimRight(raw);
   if(StringLen(raw) < 10)
      return 0;
   StringReplace(raw, "-", ".");
   return StringToTime(StringSubstr(raw, 0, 10) + " 00:00");
  }

bool Strategy_IsWeekday(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
  }

datetime Strategy_NextTradingDay(datetime value)
  {
   datetime candidate = value + 86400;
   for(int i = 0; i < 10; ++i)
     {
      if(Strategy_IsWeekday(candidate))
         return candidate;
      candidate += 86400;
     }
   return 0;
  }

int Strategy_TradingDaysBetween(const datetime announcement_date,
                                const datetime effective_date)
  {
   if(announcement_date <= 0 || effective_date <= announcement_date)
      return 0;

   int days = 0;
   datetime cursor = announcement_date + 86400;
   for(int i = 0; i < 80 && cursor <= effective_date; ++i)
     {
      if(Strategy_IsWeekday(cursor))
         ++days;
      cursor += 86400;
     }
   return days;
  }

int Strategy_CurrentSymbolSlot()
  {
   for(int i = 0; i < QM5_10872_SYMBOL_COUNT; ++i)
      if(g_strategy_symbols[i] == _Symbol)
         return i;
   return -1;
  }

bool Strategy_EventMapsToSymbol(string index_name, string region)
  {
   StringToUpper(index_name);
   StringToUpper(region);
   const string tag = index_name + "|" + region;

   if(_Symbol == "GDAXI.DWX")
      return (StringFind(tag, "EUROPE") >= 0 ||
              StringFind(tag, "GER") >= 0 ||
              StringFind(tag, "DAX") >= 0);

   if(_Symbol == "SP500.DWX")
      return (StringFind(tag, "US") >= 0 ||
              StringFind(tag, "USA") >= 0 ||
              StringFind(tag, "SPX") >= 0 ||
              StringFind(tag, "SP500") >= 0 ||
              StringFind(tag, "S&P") >= 0);

   if(_Symbol == "NDX.DWX")
      return (StringFind(tag, "US") >= 0 ||
              StringFind(tag, "USA") >= 0 ||
              StringFind(tag, "NASDAQ") >= 0 ||
              StringFind(tag, "NDX") >= 0 ||
              StringFind(tag, "DEVELOPED") >= 0 ||
              StringFind(tag, "WORLD") >= 0);

   if(_Symbol == "WS30.DWX")
      return (StringFind(tag, "US") >= 0 ||
              StringFind(tag, "USA") >= 0 ||
              StringFind(tag, "DOW") >= 0 ||
              StringFind(tag, "WS30") >= 0);

   return false;
  }

int Strategy_OpenCsv()
  {
   if(strategy_event_csv_path == "")
      return INVALID_HANDLE;

   int handle = FileOpen(strategy_event_csv_path,
                         FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ,
                         ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(strategy_event_csv_path,
                        FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON,
                        ',');
   return handle;
  }

bool Strategy_ReadAnnouncementEvent(const int announcement_day_key,
                                    double &out_pressure,
                                    string &out_reason)
  {
   out_pressure = 0.0;
   out_reason = "";

   const int handle = Strategy_OpenCsv();
   if(handle == INVALID_HANDLE)
      return false;

   int found = 0;
   while(!FileIsEnding(handle))
     {
      const string index_name = FileReadString(handle);
      const string announcement_raw = FileReadString(handle);
      const string effective_raw = FileReadString(handle);
      const string add_raw = FileReadString(handle);
      const string delete_raw = FileReadString(handle);
      const string region = FileReadString(handle);

      if(index_name == "index_name" || announcement_raw == "__QM_UNUSED__")
         continue;
      if(index_name == "" && announcement_raw == "" && effective_raw == "")
         continue;

      const datetime announcement_date = Strategy_ParseDate(announcement_raw);
      const datetime effective_date = Strategy_ParseDate(effective_raw);
      if(announcement_date <= 0 || effective_date <= 0)
         continue;
      if(Strategy_DayKey(announcement_date) != announcement_day_key)
         continue;
      if(Strategy_TradingDaysBetween(announcement_date, effective_date) < strategy_min_trading_days)
         continue;
      if(!Strategy_EventMapsToSymbol(index_name, region))
         continue;

      const double pressure = StringToDouble(add_raw) - StringToDouble(delete_raw);
      if(MathAbs(pressure) < strategy_net_pressure_pct)
         continue;

      out_pressure += pressure;
      ++found;
      if(found >= QM5_10872_MAX_EVENTS_PER_BAR)
         break;
     }

   FileClose(handle);

   if(found <= 0 || MathAbs(out_pressure) < strategy_net_pressure_pct)
      return false;

   out_reason = StringFormat("SYSLS_MSCI_DRIFT_EVENTS_%d", found);
   return true;
  }

bool Strategy_ReadD1Bars(MqlRates &current_bar, MqlRates &closed_bar)
  {
   MqlRates rates[];
   ArrayResize(rates, 2);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 0, 2, rates); // perf-allowed: bounded D1 announcement-date lookup inside framework new-bar entry path.
   if(copied != 2)
      return false;

   current_bar = rates[0];
   closed_bar = rates[1];
   return (current_bar.time > 0 && closed_bar.time > 0);
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

bool Strategy_EventMatchesPosition(const datetime opened,
                                   const int direction,
                                   const int current_day_key)
  {
   const int opened_day_key = Strategy_DayKey(opened);
   if(opened_day_key <= 0 || current_day_key <= 0)
      return false;

   const int handle = Strategy_OpenCsv();
   if(handle == INVALID_HANDLE)
      return false;

   bool found_match = false;
   while(!FileIsEnding(handle))
     {
      const string index_name = FileReadString(handle);
      const string announcement_raw = FileReadString(handle);
      const string effective_raw = FileReadString(handle);
      const string add_raw = FileReadString(handle);
      const string delete_raw = FileReadString(handle);
      const string region = FileReadString(handle);

      if(index_name == "index_name" || announcement_raw == "__QM_UNUSED__")
         continue;

      const datetime announcement_date = Strategy_ParseDate(announcement_raw);
      const datetime effective_date = Strategy_ParseDate(effective_raw);
      if(announcement_date <= 0 || effective_date <= 0)
         continue;
      if(!Strategy_EventMapsToSymbol(index_name, region))
         continue;

      const double pressure = StringToDouble(add_raw) - StringToDouble(delete_raw);
      if(MathAbs(pressure) < strategy_net_pressure_pct)
         continue;
      if((pressure > 0.0 && direction <= 0) || (pressure < 0.0 && direction >= 0))
         continue;

      const datetime expected_entry_day = Strategy_NextTradingDay(announcement_date);
      if(expected_entry_day <= 0 || Strategy_DayKey(expected_entry_day) != opened_day_key)
         continue;

      found_match = true;
      if(current_day_key >= Strategy_DayKey(effective_date))
        {
         FileClose(handle);
         return true;
        }
     }

   FileClose(handle);
   return !found_match;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolSlot() < 0)
      return true;
   if(strategy_net_pressure_pct <= 0.0 ||
      strategy_min_trading_days < 1 ||
      strategy_atr_period_d1 <= 0 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_max_spread_stop_frac <= 0.0)
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
   req.reason = "SYSLS_MSCI_DRIFT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   MqlRates current_bar;
   MqlRates closed_bar;
   if(!Strategy_ReadD1Bars(current_bar, closed_bar))
      return false;

   double pressure = 0.0;
   string event_reason = "";
   if(!Strategy_ReadAnnouncementEvent(Strategy_DayKey(closed_bar.time), pressure, event_reason))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.type = (pressure > 0.0) ? QM_BUY : QM_SELL;
   req.price = (req.type == QM_BUY) ? ask : bid;

   const double stop_distance = atr * strategy_atr_stop_mult;
   if((ask - bid) > stop_distance * strategy_max_spread_stop_frac)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr, strategy_atr_stop_mult);
   req.tp = 0.0;
   req.reason = (req.type == QM_BUY) ? event_reason + "_LONG_PRESSURE" : event_reason + "_SHORT_PRESSURE";

   return (req.sl > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, or partial-close management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int current_day_key = Strategy_DayKey(TimeCurrent());
   if(current_day_key <= 0)
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const int direction = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_EventMatchesPosition(opened, direction, current_day_key))
         return true;
     }

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
