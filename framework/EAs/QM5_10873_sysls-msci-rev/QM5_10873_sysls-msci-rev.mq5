#property strict
#property version   "5.0"
#property description "QM5_10873 SystematicLS MSCI ED Reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10873;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_event_csv_path       = "QM5_10872_msci_rebalance_events.csv";
input double strategy_net_pressure_pct     = 0.20;
input double strategy_move_atr_frac        = 0.35;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_stop_mult        = 1.0;
input double strategy_take_profit_r        = 1.0;
input double strategy_max_spread_stop_frac = 0.10;

#define QM5_10873_SYMBOL_COUNT 4
#define QM5_10873_MAX_EVENTS_PER_BAR 16

string g_strategy_symbols[QM5_10873_SYMBOL_COUNT] =
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

int Strategy_CurrentSymbolSlot()
  {
   for(int i = 0; i < QM5_10873_SYMBOL_COUNT; ++i)
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

bool Strategy_ReadTodaysEvent(const int effective_day_key,
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

      if(announcement_raw == "__QM_UNUSED__")
         continue;
      if(index_name == "" && effective_raw == "")
         continue;

      const datetime effective_date = Strategy_ParseDate(effective_raw);
      if(effective_date <= 0 || Strategy_DayKey(effective_date) != effective_day_key)
         continue;
      if(!Strategy_EventMapsToSymbol(index_name, region))
         continue;

      const double net_add = StringToDouble(add_raw);
      const double net_delete = StringToDouble(delete_raw);
      const double pressure = net_add - net_delete;
      if(MathAbs(pressure) < strategy_net_pressure_pct)
         continue;

      out_pressure += pressure;
      ++found;
      if(found >= QM5_10873_MAX_EVENTS_PER_BAR)
         break;
     }

   FileClose(handle);

   if(found <= 0 || MathAbs(out_pressure) < strategy_net_pressure_pct)
      return false;

   out_reason = StringFormat("SYSLS_MSCI_REV_EVENTS_%d", found);
   return true;
  }

bool Strategy_ReadD1Bars(MqlRates &current_bar, MqlRates &ed_minus_one, MqlRates &prior_bar)
  {
   MqlRates rates[3];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 0, 3, rates); // perf-allowed: bounded D1 event-date lookup inside framework new-bar entry path.
   if(copied != 3)
      return false;

   current_bar = rates[0];
   ed_minus_one = rates[1];
   prior_bar = rates[2];
   return (current_bar.time > 0 && ed_minus_one.close > 0.0 && prior_bar.close > 0.0);
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
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolSlot() < 0)
      return true;
   if(strategy_net_pressure_pct <= 0.0 ||
      strategy_move_atr_frac <= 0.0 ||
      strategy_atr_period_d1 <= 0 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_take_profit_r <= 0.0 ||
      strategy_max_spread_stop_frac <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "SYSLS_MSCI_REV";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   MqlRates current_bar;
   MqlRates ed_minus_one;
   MqlRates prior_bar;
   if(!Strategy_ReadD1Bars(current_bar, ed_minus_one, prior_bar))
      return false;

   double pressure = 0.0;
   string event_reason = "";
   if(!Strategy_ReadTodaysEvent(Strategy_DayKey(current_bar.time), pressure, event_reason))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr <= 0.0 || ed_minus_one.close <= 0.0 || prior_bar.close <= 0.0)
      return false;

   const double ed_return = (ed_minus_one.close - prior_bar.close) / prior_bar.close;
   const double move_threshold = strategy_move_atr_frac * atr / ed_minus_one.close;
   if(MathAbs(ed_return) <= move_threshold)
      return false;
   if(pressure > 0.0 && ed_return <= 0.0)
      return false;
   if(pressure < 0.0 && ed_return >= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.type = (pressure > 0.0) ? QM_SELL : QM_BUY;
   req.price = (req.type == QM_BUY) ? ask : bid;

   const double stop_distance = atr * strategy_atr_stop_mult;
   if((ask - bid) > stop_distance * strategy_max_spread_stop_frac)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr, strategy_atr_stop_mult);
   req.tp = QM_TakeRR(_Symbol, req.type, req.price, req.sl, strategy_take_profit_r);
   req.reason = (req.type == QM_SELL) ? event_reason + "_SHORT_FLOW_FADE" : event_reason + "_LONG_FLOW_FADE";

   return (req.sl > 0.0 && req.tp > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed initial ATR stop, 1R target, and ED close only.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int current_day = Strategy_DayKey(TimeCurrent());
   if(current_day <= 0)
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

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(Strategy_DayKey(opened) < current_day)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
