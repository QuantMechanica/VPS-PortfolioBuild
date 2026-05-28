#property strict
#property version   "5.0"
#property description "QM5_1192 Quantpedia Stress Oil Rebound"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1192;
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
input string strategy_equity_signal_symbol = "SP500.DWX";
input string strategy_gold_signal_symbol   = "XAUUSD.DWX";
input string strategy_oil_primary_symbol   = "XTIUSD.DWX";
input string strategy_oil_fallback_symbol  = "XBRUSD.DWX";
input double strategy_stress_threshold_pct = 0.0;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 1.5;
input int    strategy_safety_hold_days     = 2;
input int    strategy_min_d1_bars          = 30;
input int    strategy_max_spread_points    = 0;

datetime g_last_entry_signal_day = 0;

int Strategy_DayKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

string Strategy_ExpectedTradeSymbol()
  {
   if(qm_magic_slot_offset == 0)
      return strategy_oil_primary_symbol;
   if(qm_magic_slot_offset == 1)
      return strategy_oil_fallback_symbol;
   return "";
  }

bool Strategy_SelectSymbols()
  {
   bool ok = true;
   const string trade_symbol = Strategy_ExpectedTradeSymbol();
   if(trade_symbol != "")
      ok = (SymbolSelect(trade_symbol, true) && ok);
   if(strategy_equity_signal_symbol != "")
      ok = (SymbolSelect(strategy_equity_signal_symbol, true) && ok);
   if(strategy_gold_signal_symbol != "")
      ok = (SymbolSelect(strategy_gold_signal_symbol, true) && ok);
   if(strategy_oil_primary_symbol != "")
      SymbolSelect(strategy_oil_primary_symbol, true);
   if(strategy_oil_fallback_symbol != "")
      SymbolSelect(strategy_oil_fallback_symbol, true);
   return ok;
  }

bool Strategy_DailyReturn(const string symbol, const int shift, double &ret)
  {
   ret = 0.0;
   if(symbol == "")
      return false;
   if(!SymbolSelect(symbol, true))
      return false;
   if(Bars(symbol, PERIOD_D1) < MathMax(strategy_min_d1_bars, shift + 3))
      return false;

   const double close_now = iClose(symbol, PERIOD_D1, shift);
   const double close_prev = iClose(symbol, PERIOD_D1, shift + 1);
   if(close_now <= 0.0 || close_prev <= 0.0)
      return false;

   ret = (close_now / close_prev) - 1.0;
   return MathIsValidNumber(ret);
  }

bool Strategy_StressSignal(const datetime signal_day, double &equity_ret, double &gold_ret)
  {
   equity_ret = 0.0;
   gold_ret = 0.0;

   if(signal_day <= 0)
      return false;
   if(iTime(_Symbol, PERIOD_D1, 1) != signal_day)
      return false;
   if(!Strategy_DailyReturn(strategy_equity_signal_symbol, 1, equity_ret))
      return false;
   if(!Strategy_DailyReturn(strategy_gold_signal_symbol, 1, gold_ret))
      return false;

   const double threshold = strategy_stress_threshold_pct / 100.0;
   return (equity_ret < threshold && gold_ret < threshold);
  }

bool Strategy_HasOpenPosition(ulong &ticket, datetime &opened_at)
  {
   ticket = 0;
   opened_at = 0;

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
   const string trade_symbol = Strategy_ExpectedTradeSymbol();
   if(trade_symbol == "" || _Symbol != trade_symbol)
      return true;
   if(_Period != PERIOD_D1)
      return true;
   if(qm_magic_slot_offset < 0 || qm_magic_slot_offset > 1)
      return true;
   if(strategy_equity_signal_symbol == "" || strategy_gold_signal_symbol == "")
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_safety_hold_days < 1)
      return true;
   if(strategy_min_d1_bars < MathMax(strategy_atr_period_d1 + 5, 10))
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
   req.reason = "QM5_1192_STRESS_OIL_REBOUND";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime signal_day = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_day <= 0 || g_last_entry_signal_day == signal_day)
      return false;
   g_last_entry_signal_day = signal_day;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(Strategy_HasOpenPosition(ticket, opened_at))
      return false;

   double equity_ret = 0.0;
   double gold_ret = 0.0;
   if(!Strategy_StressSignal(signal_day, equity_ret, gold_ret))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   if(!Strategy_StopDistanceAllowed(entry, req.sl))
      return false;

   QM_LogEvent(QM_INFO, "STRESS_SIGNAL_ON",
               StringFormat("{\"signal_day\":%I64d,\"equity_ret\":%.6f,\"gold_ret\":%.6f,\"trade_symbol\":\"%s\"}",
                            (long)signal_day, equity_ret, gold_ret, _Symbol));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // The card specifies fixed ATR stop and scheduled next-D1-close exit only.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   if(!Strategy_HasOpenPosition(ticket, opened_at))
      return false;

   const datetime current_day = iTime(_Symbol, PERIOD_D1, 0);
   if(current_day <= 0)
      return false;

   const int open_day_key = Strategy_DayKey(opened_at);
   const int current_day_key = Strategy_DayKey(current_day);
   if(open_day_key > 0 && current_day_key > open_day_key)
      return true;

   const int shift = iBarShift(_Symbol, PERIOD_D1, opened_at, false);
   return (shift >= MathMax(2, strategy_safety_hold_days));
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1192\",\"strategy\":\"qp-stress-oil-rebound\"}");
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
