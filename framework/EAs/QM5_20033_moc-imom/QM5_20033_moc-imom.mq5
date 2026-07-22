#property strict
#property version   "5.0"
#property description "QM5_20033 market-on-close intraday momentum"

#include <QM/QM_Common.mqh>

// Strategy Card: QM5_20033_moc-imom, G0 APPROVED 2026-07-22.
// Exact session times come from a provenance-bearing UTC session ledger.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 20033;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
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
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M30;
input double strategy_max_cost_r          = 0.10;
input string strategy_session_ledger_file = "QM5_20033_cash_sessions.csv";
input string strategy_calendar_valid_through = "2025.12.31";

string   g_session_symbol[];
datetime g_session_open_utc[];
datetime g_session_first30_utc[];
datetime g_session_entry_utc[];
datetime g_session_exit_utc[];
bool     g_session_entry_allowed[];
bool     g_calendar_ready = false;
datetime g_last_attempt_entry_utc = 0;
datetime g_active_exit_broker = 0;

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

int RouteIndex(const string symbol)
  {
   if(symbol == "SP500.DWX") return 0;
   if(symbol == "NDX.DWX") return 1;
   if(symbol == "WS30.DWX") return 2;
   if(symbol == "GDAXI.DWX") return 3;
   return -1;
  }

bool IsRoutedSymbol(const string symbol)
  {
   return (RouteIndex(symbol) >= 0);
  }

bool ValidIssuerUrl(const string symbol, const string url)
  {
   if(StringFind(url, "https") != 0 || StringFind(url, "://") <= 0)
      return false;
   if(symbol == "GDAXI.DWX")
      return (StringFind(url, "xetra.com") > 0 || StringFind(url, "deutsche-boerse.com") > 0);
   if(symbol == "NDX.DWX")
      return (StringFind(url, "nasdaqtrader.com") > 0 || StringFind(url, "nasdaq.com") > 0);
   return (StringFind(url, "nyse.com") > 0);
  }

bool ParseBoolean(const string value, bool &parsed)
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

bool AppendSession(const string symbol,
                   const datetime open_utc,
                   const datetime first30_utc,
                   const datetime entry_utc,
                   const datetime exit_utc,
                   const bool entry_allowed)
  {
   const int n = ArraySize(g_session_entry_utc);
   if(ArrayResize(g_session_symbol, n + 1) != n + 1 ||
      ArrayResize(g_session_open_utc, n + 1) != n + 1 ||
      ArrayResize(g_session_first30_utc, n + 1) != n + 1 ||
      ArrayResize(g_session_entry_utc, n + 1) != n + 1 ||
      ArrayResize(g_session_exit_utc, n + 1) != n + 1 ||
      ArrayResize(g_session_entry_allowed, n + 1) != n + 1)
      return false;
   g_session_symbol[n] = symbol;
   g_session_open_utc[n] = open_utc;
   g_session_first30_utc[n] = first30_utc;
   g_session_entry_utc[n] = entry_utc;
   g_session_exit_utc[n] = exit_utc;
   g_session_entry_allowed[n] = entry_allowed;
   return true;
  }

bool LoadSessionCalendar()
  {
   ArrayResize(g_session_symbol, 0);
   ArrayResize(g_session_open_utc, 0);
   ArrayResize(g_session_first30_utc, 0);
   ArrayResize(g_session_entry_utc, 0);
   ArrayResize(g_session_exit_utc, 0);
   ArrayResize(g_session_entry_allowed, 0);
   if(strategy_calendar_valid_through != "2025.12.31")
      return false;

   const int handle = FileOpen(strategy_session_ledger_file,
                               FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON,
                               ',');
   if(handle == INVALID_HANDLE)
      return false;

   int earliest_year[4] = {9999, 9999, 9999, 9999};
   int latest_year[4] = {0, 0, 0, 0};
   datetime previous_entry_utc = 0;
   int rows = 0;
   bool valid = true;
   while(!FileIsEnding(handle))
     {
      const string symbol = Trimmed(FileReadString(handle));
      const string open_text = Trimmed(FileReadString(handle));
      const string first30_text = Trimmed(FileReadString(handle));
      const string entry_text = Trimmed(FileReadString(handle));
      const string exit_text = Trimmed(FileReadString(handle));
      const string allowed_text = Trimmed(FileReadString(handle));
      const string issuer_url = Trimmed(FileReadString(handle));
      string retrieved_date = Trimmed(FileReadString(handle));
      const string source_sha256 = Trimmed(FileReadString(handle));

      if(rows == 0 && symbol == "symbol" && open_text == "open_utc")
         continue;
      if(symbol == "" && open_text == "" && entry_text == "" && exit_text == "")
         continue;

      const int route = RouteIndex(symbol);
      bool entry_allowed = false;
      if(route < 0 || !ParseBoolean(allowed_text, entry_allowed) ||
         !ValidIssuerUrl(symbol, issuer_url) || !IsSha256(source_sha256))
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

      const datetime open_utc = ParseUtcTimestamp(open_text);
      const datetime first30_utc = ParseUtcTimestamp(first30_text);
      const datetime entry_utc = ParseUtcTimestamp(entry_text);
      const datetime exit_utc = ParseUtcTimestamp(exit_text);
      if(open_utc <= 0 || first30_utc - open_utc != 30 * 60 ||
         entry_utc < first30_utc || exit_utc - entry_utc != 30 * 60 ||
         (previous_entry_utc > 0 && entry_utc < previous_entry_utc))
        {
         valid = false;
         break;
        }

      MqlDateTime session_parts;
      if(!TimeToStruct(open_utc, session_parts))
        {
         valid = false;
         break;
        }
      earliest_year[route] = MathMin(earliest_year[route], session_parts.year);
      latest_year[route] = MathMax(latest_year[route], session_parts.year);
      if(!AppendSession(symbol, open_utc, first30_utc, entry_utc, exit_utc, entry_allowed))
        {
         valid = false;
         break;
        }
      previous_entry_utc = entry_utc;
      ++rows;
     }
   FileClose(handle);

   if(!valid || rows <= 0)
      return false;
   for(int i = 0; i < 4; ++i)
     {
      if(earliest_year[i] > 2018 || latest_year[i] < 2025)
         return false;
     }
   return true;
  }

int LowerBoundEntry(const datetime target_utc)
  {
   int lo = 0;
   int hi = ArraySize(g_session_entry_utc);
   while(lo < hi)
     {
      const int mid = lo + (hi - lo) / 2;
      if(g_session_entry_utc[mid] < target_utc)
         lo = mid + 1;
      else
         hi = mid;
     }
   return lo;
  }

int FindSessionAtEntry(const string symbol, const datetime entry_utc)
  {
   int i = LowerBoundEntry(entry_utc);
   const int total = ArraySize(g_session_entry_utc);
   while(i < total && g_session_entry_utc[i] == entry_utc)
     {
      if(g_session_symbol[i] == symbol)
         return i;
      ++i;
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

int FindSessionForOpenPosition(const string symbol, const datetime open_utc)
  {
   int i = LowerBoundEntry(open_utc + 1) - 1;
   while(i >= 0 && open_utc - g_session_entry_utc[i] <= 10 * 60)
     {
      if(g_session_symbol[i] == symbol && open_utc >= g_session_entry_utc[i])
         return i;
      --i;
     }
   return -1;
  }

bool TickMid(const MqlTick &tick, double &mid)
  {
   mid = 0.0;
   if(tick.bid <= 0.0 || tick.ask <= 0.0 || tick.ask < tick.bid)
      return false;
   mid = 0.5 * (tick.bid + tick.ask);
   return (mid > 0.0);
  }

bool OpeningIntervalMove(const datetime open_utc,
                         const datetime first30_utc,
                         double &open_move_signed)
  {
   open_move_signed = 0.0;
   MqlTick ticks[];
   const ulong from_msc = (ulong)open_utc * 1000;
   const ulong to_msc = (ulong)first30_utc * 1000 - 1;
   const int copied = CopyTicksRange(_Symbol, ticks, COPY_TICKS_INFO, from_msc, to_msc);
   if(copied <= 0)
      return false;

   double open_mid = 0.0;
   double close_mid = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      if(TickMid(ticks[i], open_mid))
         break;
     }
   for(int i = copied - 1; i >= 0; --i)
     {
      if(TickMid(ticks[i], close_mid))
         break;
     }
   if(open_mid <= 0.0 || close_mid <= 0.0)
      return false;

   open_mid = QM_TM_NormalizePrice(_Symbol, open_mid);
   close_mid = QM_TM_NormalizePrice(_Symbol, close_mid);
   open_move_signed = close_mid - open_mid;
   return (MathIsValidNumber(open_move_signed));
  }

double CommissionPerLotUsd(const string symbol)
  {
   if(symbol == "SP500.DWX" || symbol == "NDX.DWX")
      return 5.50;
   if(symbol == "WS30.DWX")
      return 0.70;
   if(symbol == "GDAXI.DWX")
     {
      const double eurusd_bid = SymbolInfoDouble("EURUSD.DWX", SYMBOL_BID);
      const double eurusd_ask = SymbolInfoDouble("EURUSD.DWX", SYMBOL_ASK);
      if(eurusd_bid <= 0.0 || eurusd_ask <= 0.0 || eurusd_ask < eurusd_bid)
         return 0.0;
      return 5.50 * 0.5 * (eurusd_bid + eurusd_ask);
     }
   return 0.0;
  }

bool CostAndVolumeAllow(const double entry_price, const double stop_price)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double commission_per_lot = CommissionPerLotUsd(_Symbol);
   if(AccountInfoString(ACCOUNT_CURRENCY) != "USD" ||
      point <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0 ||
      ask <= 0.0 || bid <= 0.0 || ask < bid || commission_per_lot <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double risk_per_lot = (stop_distance / tick_size) * tick_value;
   const double spread_per_lot = ((ask - bid) / tick_size) * tick_value;
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
   if(!IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf)
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

   if(!g_calendar_ready || !IsRoutedSymbol(_Symbol) || _Period != strategy_signal_tf)
      return false;
   const datetime current_bar_broker = iTime(_Symbol, strategy_signal_tf, 0); // perf-allowed: exact ledger-matched entry bar behind QM_IsNewBar.
   if(current_bar_broker <= 0)
      return false;
   const datetime entry_utc = QM_BrokerToUTC(current_bar_broker);
   if(entry_utc == g_last_attempt_entry_utc)
      return false;

   const int session = FindSessionAtEntry(_Symbol, entry_utc);
   if(session < 0 || !g_session_entry_allowed[session])
      return false;

   double open_move_signed = 0.0;
   if(!OpeningIntervalMove(g_session_open_utc[session],
                           g_session_first30_utc[session],
                           open_move_signed) || open_move_signed == 0.0)
      return false;

   const bool buy = (open_move_signed > 0.0);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   const double entry_price = buy ? ask : bid;
   const double open_move = MathAbs(open_move_signed);
   const double stop_price = QM_StopRulesNormalizePrice(_Symbol,
                                                        buy ? entry_price - open_move
                                                            : entry_price + open_move);
   if(stop_price <= 0.0 || stop_price == entry_price || !CostAndVolumeAllow(entry_price, stop_price))
      return false;

   req.type = buy ? QM_BUY : QM_SELL;
   req.sl = stop_price;
   req.reason = buy ? "MOC_IMOM_FIRST30_LONG" : "MOC_IMOM_FIRST30_SHORT";
   g_last_attempt_entry_utc = entry_utc;
   g_active_exit_broker = QM_UTCToBroker(g_session_exit_utc[session]);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   datetime open_time = 0;
   if(!FindOurPosition(open_time))
      g_active_exit_broker = 0;
  }

bool Strategy_ExitSignal()
  {
   datetime open_time = 0;
   if(!FindOurPosition(open_time))
      return false;
   if(g_active_exit_broker <= 0)
     {
      const int session = g_calendar_ready
                          ? FindSessionForOpenPosition(_Symbol, QM_BrokerToUTC(open_time))
                          : -1;
      if(session >= 0)
         g_active_exit_broker = QM_UTCToBroker(g_session_exit_utc[session]);
      else
         g_active_exit_broker = open_time + 30 * 60;
     }
   return (TimeCurrent() >= g_active_exit_broker);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // Baseline card explicitly applies no generic news filter.
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

   string allowed_symbols[5] = {"SP500.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "EURUSD.DWX"};
   QM_SymbolGuardInit(allowed_symbols);
   QM_BasketWarmupHistory(allowed_symbols, strategy_signal_tf, 64);

   g_calendar_ready = LoadSessionCalendar();
   if(!g_calendar_ready)
      QM_LogEvent(QM_ERROR,
                  "SETUP_DATA_MISSING",
                  StringFormat("{\"session_ledger\":\"%s\"}", strategy_session_ledger_file));

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

