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

const string strategy_variant_id = "EIA_CAD_BASELINE";

const string STRATEGY_CALENDAR_PATH =
   "QM5_20030_eia_calendar_20180110_20251231.csv";
const string STRATEGY_CALENDAR_SHA256 =
   "B273DD88D27E38FE78EC85E426E0F1C8C8EF07DAE2F7E1E102BA96F492C33E04";
const string STRATEGY_PROVENANCE_SHA256 =
   "834540437F24E9818F8A1FC1B596F211C9D22154A20A9E3527E99FF9532F58C7";
const int STRATEGY_CALENDAR_EXPECTED_ROWS = 352;

datetime g_event_times_utc[];
bool     g_calendar_ready = false;
datetime g_last_attempt_event_utc = 0;

bool AppendEvent(const datetime event_utc)
  {
   const int n = ArraySize(g_event_times_utc);
   if(n > 0 && g_event_times_utc[n - 1] >= event_utc)
      return false;
   if(ArrayResize(g_event_times_utc, n + 1) != n + 1)
      return false;
   g_event_times_utc[n] = event_utc;
   return true;
  }

bool CalendarHashMatches()
  {
   uchar bytes[];
   datetime modified_utc = 0;
   if(!QM_NewsReadFileBytes(STRATEGY_CALENDAR_PATH, bytes, modified_utc))
      return false;
   string actual_hash = "";
   if(!QM_NewsHashBytes(bytes, actual_hash))
      return false;
   StringToUpper(actual_hash);
   return (actual_hash == STRATEGY_CALENDAR_SHA256);
  }

bool LoadEventCalendar()
  {
   ArrayResize(g_event_times_utc, 0);
   if(!CalendarHashMatches())
      return false;

   // Keep the load order identical to QM_NewsReadFileBytes so the bytes that
   // passed the SHA-256 check are also the bytes parsed below.
   int handle = FileOpen(STRATEGY_CALENDAR_PATH,
                         FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ,
                         ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(STRATEGY_CALENDAR_PATH,
                        FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON,
                        ',');
   if(handle == INVALID_HANDLE)
      return false;

   int rows = 0;
   bool valid = true;
   while(!FileIsEnding(handle))
     {
      const string event_text = FileReadString(handle);
      if(FileIsEnding(handle) && StringLen(event_text) == 0)
         break;
      const string currency = FileReadString(handle);
      const string event_name = FileReadString(handle);
      const string impact = FileReadString(handle);
      while(!FileIsEnding(handle) && !FileIsLineEnding(handle))
         FileReadString(handle);

      if(QM_NewsUpper(QM_NewsStripQuotes(event_text)) == "DATETIME")
         continue;
      if(StringLen(QM_NewsTrim(event_text)) == 0)
         continue;

      datetime event_utc = 0;
      MqlDateTime event_parts;
      ZeroMemory(event_parts);
      if(QM_NewsUpper(QM_NewsStripQuotes(currency)) != "USD" ||
         QM_NewsUpper(QM_NewsStripQuotes(event_name)) != "CRUDE OIL INVENTORIES" ||
         QM_NewsUpper(QM_NewsStripQuotes(impact)) != "HIGH" ||
         !QM_NewsParseDateTimeUTC(event_text, event_utc) ||
         !TimeToStruct(event_utc, event_parts) ||
         event_parts.year < 2018 || event_parts.year > 2025 ||
         event_parts.sec != 0 || (event_parts.min % 5) != 0 ||
         !AppendEvent(event_utc))
        {
         valid = false;
         break;
        }
      ++rows;
     }

   FileClose(handle);
   if(!valid || rows != STRATEGY_CALENDAR_EXPECTED_ROWS ||
      ArraySize(g_event_times_utc) != STRATEGY_CALENDAR_EXPECTED_ROWS)
      return false;

   QM_LogEvent(QM_INFO,
               "STRATEGY_CALENDAR_LOADED",
               StringFormat("{\"file\":\"%s\",\"sha256\":\"%s\",\"provenance_sha256\":\"%s\",\"eia_rows\":%d,\"api_rows\":0}",
                            STRATEGY_CALENDAR_PATH,
                            STRATEGY_CALENDAR_SHA256,
                            STRATEGY_PROVENANCE_SHA256,
                            rows));
   QM_LogEvent(QM_WARN,
               "STRATEGY_CALENDAR_COVERAGE_GAP",
               "{\"event_type\":\"API\",\"reason\":\"exact_historical_timestamp_provenance_unavailable\"}");
   return true;
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

bool CostAndVolumeAllow(const double entry_price,
                        const double stop_price,
                        string &reject_detail,
                        string &diagnostics)
  {
   reject_detail = "";
   diagnostics = "";
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   const double contract_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(AccountInfoString(ACCOUNT_CURRENCY) != "USD" ||
      point <= 0.0 || tick_size <= 0.0 || tick_value <= 0.0 ||
      contract_size <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
     {
      reject_detail = "market_metadata_invalid";
      diagnostics = StringFormat("account=%s;point=%.8f;tick_size=%.8f;tick_value=%.8f;contract_size=%.8f;ask=%.8f;bid=%.8f",
                                 AccountInfoString(ACCOUNT_CURRENCY), point, tick_size,
                                 tick_value, contract_size, ask, bid);
      return false;
     }

   const double stop_distance = MathAbs(entry_price - stop_price);
   const double risk_per_lot = (stop_distance / tick_size) * tick_value;
   const double spread_per_lot = ((ask - bid) / tick_size) * tick_value;
   const double commission_per_lot = MathMax(0.00005 * contract_size, 5.0);
   const double cost_r = risk_per_lot > 0.0
                         ? (commission_per_lot + spread_per_lot) / risk_per_lot
                         : 0.0;
   if(risk_per_lot <= 0.0)
     {
      reject_detail = "risk_per_lot_invalid";
      diagnostics = StringFormat("stop_distance=%.8f;tick_size=%.8f;tick_value=%.8f",
                                 stop_distance, tick_size, tick_value);
      return false;
     }
   if(cost_r > strategy_max_cost_r)
     {
      reject_detail = "estimated_cost_above_limit";
      diagnostics = StringFormat("cost_r=%.8f;max_cost_r=%.8f;risk_per_lot=%.8f;spread_per_lot=%.8f;commission_per_lot=%.8f",
                                 cost_r, strategy_max_cost_r, risk_per_lot,
                                 spread_per_lot, commission_per_lot);
      return false;
     }

   const double sl_points = stop_distance / point;
   const long stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(sl_points <= 0.0 || sl_points < (double)stop_level)
     {
      reject_detail = "broker_stop_level";
      diagnostics = StringFormat("sl_points=%.8f;stop_level=%I64d", sl_points, stop_level);
      return false;
     }

   const double lots = QM_LotsForRisk(_Symbol,
                                      sl_points,
                                      QM_RISK_MODE_FIXED,
                                      RISK_FIXED);
   const double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || volume_min <= 0.0 || volume_max <= 0.0 || volume_step <= 0.0 ||
      lots < volume_min || lots > volume_max)
     {
      reject_detail = "risk_sizing_or_volume_metadata_invalid";
      diagnostics = StringFormat("lots=%.8f;volume_min=%.8f;volume_max=%.8f;volume_step=%.8f;sl_points=%.8f",
                                 lots, volume_min, volume_max, volume_step, sl_points);
      return false;
     }
   const double aligned = volume_min + MathRound((lots - volume_min) / volume_step) * volume_step;
   if(MathAbs(aligned - lots) > volume_step * 1.0e-6)
     {
      reject_detail = "risk_volume_not_step_aligned";
      diagnostics = StringFormat("lots=%.8f;aligned=%.8f;volume_step=%.8f",
                                 lots, aligned, volume_step);
      return false;
     }
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

void LogEntryRejected(const datetime event_utc,
                      const string reason,
                      const string context = "")
  {
   QM_LogEvent(QM_INFO,
               "ENTRY_REJECTED",
               StringFormat("{\"event_type\":\"EIA\",\"event_utc\":\"%s\",\"reason\":\"%s\",\"context\":\"%s\"}",
                            TimeToString(event_utc, TIME_DATE | TIME_MINUTES),
                            QM_LoggerEscapeJson(reason),
                            QM_LoggerEscapeJson(context)));
  }

bool Strategy_NoTradeFilter()
  {
   datetime open_time = 0;
   if(FindOurPosition(open_time))
      return false;
   if(_Symbol != "USDCAD.DWX" || qm_magic_slot_offset != 0 ||
      _Period != strategy_signal_tf)
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

   if(!g_calendar_ready || _Symbol != "USDCAD.DWX" || qm_magic_slot_offset != 0 ||
      _Period != strategy_signal_tf)
      return false;

   const datetime release_bar_broker = iTime(_Symbol, strategy_signal_tf, 1); // perf-allowed: fixed closed release bar behind QM_IsNewBar.
   if(release_bar_broker <= 0)
      return false;
   const datetime event_utc = QM_BrokerToUTC(release_bar_broker);
   if(event_utc == g_last_attempt_event_utc || FindEventIndex(event_utc) < 0)
      return false;

   // Consume the exact candidate before market-data, geometry, cost or order
   // checks. One failed prerequisite must never re-arm the same release.
   g_last_attempt_event_utc = event_utc;

   const double oil_open = iOpen("XTIUSD.DWX", strategy_signal_tf, 1); // perf-allowed: synchronized fixed release bar behind QM_IsNewBar.
   const double oil_close = iClose("XTIUSD.DWX", strategy_signal_tf, 1); // perf-allowed: synchronized fixed release bar behind QM_IsNewBar.
   const double oil_atr = QM_ATR("XTIUSD.DWX", strategy_signal_tf, strategy_atr_period, 2);
   if(oil_open <= 0.0 || oil_close <= 0.0 || oil_atr <= 0.0)
     {
      LogEntryRejected(event_utc, "oil_release_data_or_atr_missing");
      return false;
     }

   const double oil_move = oil_close - oil_open;
   if(oil_move == 0.0 || MathAbs(oil_move) < strategy_impulse_atr_mult * oil_atr)
     {
      LogEntryRejected(event_utc,
                       "oil_impulse_below_threshold",
                       StringFormat("move=%.8f;atr=%.8f;threshold=%.8f",
                                    oil_move,
                                    oil_atr,
                                    strategy_impulse_atr_mult * oil_atr));
      return false;
     }

   const bool buy = (oil_move < 0.0);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
     {
      LogEntryRejected(event_utc, "tradable_quote_unavailable");
      return false;
     }

   const double release_low = iLow(_Symbol, strategy_signal_tf, 1); // perf-allowed: synchronized fixed release-bar stop behind QM_IsNewBar.
   const double release_high = iHigh(_Symbol, strategy_signal_tf, 1); // perf-allowed: synchronized fixed release-bar stop behind QM_IsNewBar.
   const double entry_price = buy ? ask : bid;
   const double stop_price = QM_StopRulesNormalizePrice(_Symbol, buy ? release_low : release_high);
   if(stop_price <= 0.0 || (buy && entry_price <= stop_price) || (!buy && entry_price >= stop_price))
     {
      LogEntryRejected(event_utc,
                       "release_bar_stop_invalid",
                       StringFormat("entry=%.8f;stop=%.8f;low=%.8f;high=%.8f",
                                    entry_price, stop_price, release_low, release_high));
      return false;
     }
   string cost_reject = "";
   string cost_diagnostics = "";
   if(!CostAndVolumeAllow(entry_price,
                          stop_price,
                          cost_reject,
                          cost_diagnostics))
     {
      LogEntryRejected(event_utc,
                       cost_reject,
                       cost_diagnostics);
      return false;
     }

   req.type = buy ? QM_BUY : QM_SELL;
   req.sl = stop_price;
   req.reason = buy ? "EIA_CAD_OIL_DOWN_LONG" : "EIA_CAD_OIL_UP_SHORT";
   QM_LogEvent(QM_INFO,
               "ENTRY_SIGNAL_FIRE",
               StringFormat("{\"event_type\":\"EIA\",\"event_utc\":\"%s\",\"direction\":\"%s\",\"oil_open\":%.8f,\"oil_close\":%.8f,\"oil_atr\":%.8f,\"stop\":%.8f}",
                            TimeToString(event_utc, TIME_DATE | TIME_MINUTES),
                            buy ? "LONG" : "SHORT",
                            oil_open,
                            oil_close,
                            oil_atr,
                            stop_price));
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

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_M5,
         QM_FRIDAY_CLOSE_CARD_RULE,
         "CARD_V2_FRIDAY_21_SAFETY_FLATTEN"))
      return INIT_FAILED;

   string allowed_symbols[2] = {"USDCAD.DWX", "XTIUSD.DWX"};
   QM_SymbolGuardInit(allowed_symbols);
   QM_BasketWarmupHistory(allowed_symbols, strategy_signal_tf, 64);

   g_calendar_ready = LoadEventCalendar();
   if(!g_calendar_ready)
      QM_LogEvent(QM_ERROR,
                  "SETUP_DATA_MISSING",
                  StringFormat("{\"component\":\"eia_strategy_calendar\",\"file\":\"%s\",\"expected_sha256\":\"%s\"}",
                               STRATEGY_CALENDAR_PATH,
                               STRATEGY_CALENDAR_SHA256));

   QM_LogEvent(QM_INFO,
               "INIT_OK",
               StringFormat("{\"calendar_ready\":%s,\"eia_rows\":%d,\"api_data_gap\":true,\"order_symbol\":\"USDCAD.DWX\",\"signal_symbol\":\"XTIUSD.DWX\"}",
                            g_calendar_ready ? "true" : "false",
                            ArraySize(g_event_times_utc)));
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

   if(!QM_IsNewBar(_Symbol, PERIOD_M5))
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
