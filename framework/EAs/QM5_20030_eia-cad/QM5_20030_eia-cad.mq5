#property strict
#property version   "5.0"
#property description "QM5_20030 EIA CAD event response"

#include <QM/QM_Common.mqh>

// Strategy Card: QM5_20030_eia-cad, G0 APPROVED 2026-07-22.
// The event ledgers are deliberately fail-closed. Missing or malformed ledger
// data blocks new entries, but never prevents management of an open position.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20030;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
// This EA trades the scheduled release itself. The provenance-locked strategy
// ledger below is the entry gate, so the generic blackout axes stay disabled.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M5;
input int    strategy_atr_period          = 14;
input double strategy_impulse_atr_mult    = 0.60;
input int    strategy_time_exit_minutes   = 30;
input double strategy_max_cost_r          = 0.10;
input string strategy_eia_ledger_file     = "QM5_20030_eia_schedule.csv";
input string strategy_api_ledger_file     = "QM5_20030_api_schedule.csv";
input string strategy_calendar_valid_through = "2025.12.31";

datetime g_event_times_utc[];
bool     g_calendar_ready = false;
datetime g_last_attempt_event_utc = 0;

string Trimmed(string value)
  {
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
  }

bool IsSha256(const string value)
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

datetime ParseUtcTimestamp(string value)
  {
   value = Trimmed(value);
   const int n = StringLen(value);
   if(n < 2 || StringSubstr(value, n - 1, 1) != "Z")
      return 0;
   value = StringSubstr(value, 0, n - 1);
   StringReplace(value, "-", ".");
   StringReplace(value, "T", " ");
   return StringToTime(value);
  }

bool ValidIssuerUrl(const string url, const string issuer_domain)
  {
   return (StringFind(url, "https") == 0 &&
           StringFind(url, "://") > 0 &&
           StringFind(url, issuer_domain) > 0);
  }

bool AppendEvent(const datetime event_utc)
  {
   const int n = ArraySize(g_event_times_utc);
   if(ArrayResize(g_event_times_utc, n + 1) != n + 1)
      return false;
   g_event_times_utc[n] = event_utc;
   return true;
  }

bool LoadEventLedger(const string file_name,
                     const string required_type,
                     const string issuer_domain,
                     int &earliest_year,
                     int &latest_year)
  {
   earliest_year = 9999;
   latest_year = 0;
   const int handle = FileOpen(file_name,
                               FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON,
                               ',');
   if(handle == INVALID_HANDLE)
      return false;

   int rows = 0;
   bool valid = true;
   while(!FileIsEnding(handle))
     {
      const string event_type = Trimmed(FileReadString(handle));
      const string event_utc_text = Trimmed(FileReadString(handle));
      const string issuer_url = Trimmed(FileReadString(handle));
      string retrieved_date = Trimmed(FileReadString(handle));
      const string source_sha256 = Trimmed(FileReadString(handle));

      if(rows == 0 && event_type == "event_type" && event_utc_text == "event_utc")
         continue;
      if(event_type == "" && event_utc_text == "" && issuer_url == "" &&
         retrieved_date == "" && source_sha256 == "")
         continue;

      if(event_type != required_type ||
         !ValidIssuerUrl(issuer_url, issuer_domain) ||
         !IsSha256(source_sha256))
        {
         valid = false;
         break;
        }

      StringReplace(retrieved_date, "-", ".");
      if(StringToTime(retrieved_date) <= 0)
        {
         valid = false;
         break;
        }

      const datetime event_utc = ParseUtcTimestamp(event_utc_text);
      MqlDateTime event_parts;
      if(event_utc <= 0 || !TimeToStruct(event_utc, event_parts) ||
         event_parts.sec != 0 || (event_parts.min % 5) != 0)
        {
         valid = false;
         break;
        }

      earliest_year = MathMin(earliest_year, event_parts.year);
      latest_year = MathMax(latest_year, event_parts.year);
      if(!AppendEvent(event_utc))
        {
         valid = false;
         break;
        }
      ++rows;
     }

   FileClose(handle);
   return (valid && rows > 0 && earliest_year <= 2018 && latest_year >= 2025);
  }

bool LoadEventCalendars()
  {
   ArrayResize(g_event_times_utc, 0);
   if(strategy_calendar_valid_through != "2025.12.31")
      return false;

   int eia_first = 0;
   int eia_last = 0;
   int api_first = 0;
   int api_last = 0;
   if(!LoadEventLedger(strategy_eia_ledger_file, "EIA", "eia.gov", eia_first, eia_last))
      return false;
   if(!LoadEventLedger(strategy_api_ledger_file, "API", "api.org", api_first, api_last))
      return false;

   ArraySort(g_event_times_utc);
   const int total = ArraySize(g_event_times_utc);
   for(int i = 1; i < total; ++i)
     {
      if(g_event_times_utc[i] == g_event_times_utc[i - 1])
         return false;
     }
   return (total > 0);
  }

int FindEventIndex(const datetime event_utc)
  {
   int lo = 0;
   int hi = ArraySize(g_event_times_utc) - 1;
   while(lo <= hi)
     {
      const int mid = lo + (hi - lo) / 2;
      if(g_event_times_utc[mid] == event_utc)
         return mid;
      if(g_event_times_utc[mid] < event_utc)
         lo = mid + 1;
      else
         hi = mid - 1;
     }
   return -1;
  }

bool FindOurPosition(datetime &open_time)
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

datetime ExitDeadlineForPosition(const datetime open_time)
  {
   const datetime open_utc = QM_BrokerToUTC(open_time);
   int lo = 0;
   int hi = ArraySize(g_event_times_utc) - 1;
   int latest = -1;
   while(lo <= hi)
     {
      const int mid = lo + (hi - lo) / 2;
      if(g_event_times_utc[mid] <= open_utc)
        {
         latest = mid;
         lo = mid + 1;
        }
      else
         hi = mid - 1;
     }

   if(latest >= 0 && open_utc - g_event_times_utc[latest] <= 10 * 60)
      return QM_UTCToBroker(g_event_times_utc[latest] + strategy_time_exit_minutes * 60);

   // Restart safety if a ledger becomes unavailable after entry. The card fill
   // is event+5m, so open+25m preserves the event+30m safety close.
   return open_time + MathMax(1, strategy_time_exit_minutes - 5) * 60;
  }

bool CostAndVolumeAllow(const double entry_price, const double stop_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   const double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(AccountInfoString(ACCOUNT_CURRENCY) != "USD" ||
      point <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0 ||
      contract_size <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double risk_per_lot = (stop_distance / tick_size) * tick_value;
   const double spread_per_lot = ((ask - bid) / tick_size) * tick_value;
   const double commission_per_lot = MathMax(0.00005 * contract_size, 5.0);
   if(risk_per_lot <= 0.0 ||
      (commission_per_lot + spread_per_lot) / risk_per_lot > strategy_max_cost_r)
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
   return (MathAbs(aligned - lots) <= volume_step * 1.0e-6);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   datetime open_time = 0;
   if(FindOurPosition(open_time))
      return false;
   if(_Symbol != "USDCAD.DWX" || _Period != strategy_signal_tf)
      return true;
   return !g_calendar_ready;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_calendar_ready || _Symbol != "USDCAD.DWX" || _Period != strategy_signal_tf)
      return false;

   const datetime release_bar_broker = iTime(_Symbol, strategy_signal_tf, 1); // perf-allowed: fixed closed release bar behind QM_IsNewBar.
   if(release_bar_broker <= 0)
      return false;
   const datetime event_utc = QM_BrokerToUTC(release_bar_broker);
   if(event_utc == g_last_attempt_event_utc || FindEventIndex(event_utc) < 0)
      return false;

   const double oil_open = iOpen("XTIUSD.DWX", strategy_signal_tf, 1); // perf-allowed: synchronized fixed release bar behind QM_IsNewBar.
   const double oil_close = iClose("XTIUSD.DWX", strategy_signal_tf, 1); // perf-allowed: synchronized fixed release bar behind QM_IsNewBar.
   const double oil_atr = QM_ATR("XTIUSD.DWX", strategy_signal_tf, strategy_atr_period, 2);
   if(oil_open <= 0.0 || oil_close <= 0.0 || oil_atr <= 0.0)
      return false;

   const double oil_move = oil_close - oil_open;
   if(oil_move == 0.0 || MathAbs(oil_move) < strategy_impulse_atr_mult * oil_atr)
      return false;

   const bool buy = (oil_move < 0.0);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   const double release_low = iLow(_Symbol, strategy_signal_tf, 1); // perf-allowed: synchronized fixed release-bar stop behind QM_IsNewBar.
   const double release_high = iHigh(_Symbol, strategy_signal_tf, 1); // perf-allowed: synchronized fixed release-bar stop behind QM_IsNewBar.
   const double entry_price = buy ? ask : bid;
   const double stop_price = QM_StopRulesNormalizePrice(_Symbol, buy ? release_low : release_high);
   if(stop_price <= 0.0 || (buy && entry_price <= stop_price) || (!buy && entry_price >= stop_price))
      return false;
   if(!CostAndVolumeAllow(entry_price, stop_price))
      return false;

   req.type = buy ? QM_BUY : QM_SELL;
   req.sl = stop_price;
   req.reason = buy ? "EIA_CAD_OIL_DOWN_LONG" : "EIA_CAD_OIL_UP_SHORT";
   g_last_attempt_event_utc = event_utc;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card forbids trailing, break-even, partial close, averaging, and scaling.
  }

bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   if(!FindOurPosition(open_time))
      return false;
   return (TimeCurrent() >= ExitDeadlineForPosition(open_time));
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // The immutable event ledger gates entries; management and time exits must
   // remain live through the release window.
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — retained from framework/templates/EA_Skeleton.mq5.
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

   string allowed_symbols[2] = {"USDCAD.DWX", "XTIUSD.DWX"};
   QM_SymbolGuardInit(allowed_symbols);
   QM_BasketWarmupHistory(allowed_symbols, strategy_signal_tf, 64);

   g_calendar_ready = LoadEventCalendars();
   if(!g_calendar_ready)
      QM_LogEvent(QM_ERROR,
                  "SETUP_DATA_MISSING",
                  StringFormat("{\"eia\":\"%s\",\"api\":\"%s\"}",
                               strategy_eia_ledger_file,
                               strategy_api_ledger_file));

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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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

