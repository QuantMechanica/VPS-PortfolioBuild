#property strict
#property version   "5.0"
#property description "QM5_1178 Quantpedia Oil Lag Equity Timing Sign Rule"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1178;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal    = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance  = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_equity_slot          = 0;       // 0 SP500, 1 NDX, 2 WS30
input string strategy_oil_signal_symbol    = "XTIUSD.DWX";
input string strategy_oil_signal_csv       = "QM5_1178_oil_monthly_returns.csv";
input double strategy_oil_return_threshold = 0.0;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 2.5;
input double strategy_safety_stop_pct      = 10.0;
input int    strategy_min_monthly_bars     = 24;
input int    strategy_max_spread_points    = 0;

#define QM5_1178_SYMBOL_COUNT 3

string g_equity_symbols[QM5_1178_SYMBOL_COUNT] = {"SP500.DWX", "NDX.DWX", "WS30.DWX"};
int    g_last_entry_month_key = 0;
int    g_last_exit_month_key = 0;

int Strategy_MonthKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

datetime Strategy_ParseDate(const string raw)
  {
   string s = raw;
   StringTrimLeft(s);
   StringTrimRight(s);
   if(StringLen(s) < 10)
      return 0;
   StringReplace(s, "-", ".");
   return StringToTime(StringSubstr(s, 0, 10) + " 00:00");
  }

bool Strategy_ResolveEquity(const int slot, string &symbol)
  {
   if(slot < 0 || slot >= QM5_1178_SYMBOL_COUNT)
      return false;
   symbol = g_equity_symbols[slot];
   return true;
  }

bool Strategy_SelectSymbols()
  {
   string equity_symbol = "";
   if(!Strategy_ResolveEquity(strategy_equity_slot, equity_symbol))
      return false;
   if(!SymbolSelect(equity_symbol, true))
      return false;
   return SymbolSelect(strategy_oil_signal_symbol, true);
  }

bool Strategy_IsFirstTradableDayOfMonth(datetime &signal_day, int &month_key)
  {
   signal_day = iTime(_Symbol, PERIOD_D1, 1);
   const datetime current_day = iTime(_Symbol, PERIOD_D1, 0);
   month_key = Strategy_MonthKey(current_day);
   if(signal_day <= 0 || current_day <= 0 || month_key <= 0)
      return false;
   return (Strategy_MonthKey(signal_day) != month_key);
  }

bool Strategy_OilReturnFromSymbol(double &oil_return)
  {
   oil_return = 0.0;
   if(strategy_oil_signal_symbol == "")
      return false;
   if(!SymbolSelect(strategy_oil_signal_symbol, true))
      return false;
   if(iBars(strategy_oil_signal_symbol, PERIOD_MN1) < MathMax(strategy_min_monthly_bars, 3))
      return false;

   const double last_month_close = iClose(strategy_oil_signal_symbol, PERIOD_MN1, 1);
   const double prior_month_close = iClose(strategy_oil_signal_symbol, PERIOD_MN1, 2);
   if(last_month_close <= 0.0 || prior_month_close <= 0.0)
      return false;

   oil_return = (last_month_close / prior_month_close) - 1.0;
   return MathIsValidNumber(oil_return);
  }

bool Strategy_OilReturnFromCsv(const datetime signal_day, double &oil_return)
  {
   oil_return = 0.0;
   if(strategy_oil_signal_csv == "")
      return false;

   int handle = FileOpen(strategy_oil_signal_csv, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(strategy_oil_signal_csv, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
      return false;

   datetime best_date = 0;
   double best_return = 0.0;
   while(!FileIsEnding(handle))
     {
      const string date_field = FileReadString(handle);
      const string return_field = FileReadString(handle);
      if(date_field == "" && return_field == "")
         continue;

      const datetime row_date = Strategy_ParseDate(date_field);
      if(row_date <= 0 || row_date > signal_day)
         continue;

      if(row_date >= best_date)
        {
         best_date = row_date;
         best_return = StringToDouble(return_field);
        }
     }
   FileClose(handle);

   if(best_date <= 0 || !MathIsValidNumber(best_return))
      return false;
   oil_return = best_return;
   return true;
  }

bool Strategy_EquitySignalOn(const datetime signal_day, double &oil_return)
  {
   oil_return = 0.0;
   if(!Strategy_OilReturnFromSymbol(oil_return))
     {
      if(!Strategy_OilReturnFromCsv(signal_day, oil_return))
         return false;
     }
   return (oil_return < strategy_oil_return_threshold);
  }

bool Strategy_HasOpenPosition(ulong &ticket, datetime &opened_at, double &entry_price)
  {
   ticket = 0;
   opened_at = 0;
   entry_price = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      return true;
     }

   return false;
  }

bool Strategy_StopDistanceAllowed(const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0 || sl >= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   string equity_symbol = "";
   if(!Strategy_ResolveEquity(strategy_equity_slot, equity_symbol))
      return true;
   if(_Symbol != equity_symbol)
      return true;
   if(_Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset != strategy_equity_slot)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_safety_stop_pct <= 0.0 || strategy_safety_stop_pct >= 100.0)
      return true;
   if(strategy_max_spread_points > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return true;
   return !Strategy_SelectSymbols();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1178_OIL_LAG_EQUITY_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime signal_day = 0;
   int month_key = 0;
   if(!Strategy_IsFirstTradableDayOfMonth(signal_day, month_key) || g_last_entry_month_key == month_key)
      return false;
   g_last_entry_month_key = month_key;

   ulong ticket = 0;
   datetime opened_at = 0;
   double entry_price = 0.0;
   if(Strategy_HasOpenPosition(ticket, opened_at, entry_price))
      return false;

   double oil_return = 0.0;
   if(!Strategy_EquitySignalOn(signal_day, oil_return))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   return Strategy_StopDistanceAllowed(entry, req.sl);
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed ATR stop plus monthly signal/safety exits only.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   double entry_price = 0.0;
   if(!Strategy_HasOpenPosition(ticket, opened_at, entry_price))
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid > 0.0 && entry_price > 0.0 && bid <= entry_price * (1.0 - strategy_safety_stop_pct / 100.0))
      return true;

   datetime signal_day = 0;
   int month_key = 0;
   if(!Strategy_IsFirstTradableDayOfMonth(signal_day, month_key) || g_last_exit_month_key == month_key)
      return false;
   if(opened_at >= signal_day)
      return false;

   g_last_exit_month_key = month_key;
   double oil_return = 0.0;
   return !Strategy_EquitySignalOn(signal_day, oil_return);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   Strategy_SelectSymbols();

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1178\",\"strategy\":\"qp-oil-equity-lag-sign\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
