#property strict
#property version   "5.0"
#property description "QM5_13137 Breadth-Confirmed Turnaround Tuesday"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 13137;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_signal_sp           = "SP500.DWX";
input string strategy_signal_ws           = "WS30.DWX";
input int    strategy_entry_hour          = 23;
input int    strategy_exit_hour           = 23;
input int    strategy_cash_open_hour      = 16;
input int    strategy_cash_open_minute    = 30;
input int    strategy_cash_close_hour     = 22;
input int    strategy_cash_close_minute   = 30;
input int    strategy_atr_period_d1       = 14;
input double strategy_stop_atr_mult       = 1.0;

bool g_strategy_new_bar = false;

int Strategy_ExpectedSlot()
  {
   if(_Symbol == "SP500.DWX")
      return 0;
   if(_Symbol == "WS30.DWX")
      return 1;
   if(_Symbol == "XAUUSD.DWX")
      return 2;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   const int expected_slot = Strategy_ExpectedSlot();
   return (expected_slot >= 0 &&
           qm_magic_slot_offset == expected_slot &&
           _Period == PERIOD_M30);
  }

bool Strategy_IsManagedPosition()
  {
   return (PositionGetString(POSITION_SYMBOL) == _Symbol &&
           (int)PositionGetInteger(POSITION_MAGIC) == QM_FrameworkMagic());
  }

int Strategy_ManagedPositionCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsManagedPosition())
         ++count;
     }
   return count;
  }

void Strategy_CloseManagedPositions(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) || !Strategy_IsManagedPosition())
         continue;
      QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_ReadExactM30Bar(const string symbol,
                              const datetime stamp,
                              MqlRates &bar)
  {
   MqlRates bars[];
   ArraySetAsSeries(bars, false);
   const int copied = CopyRates(symbol, PERIOD_M30, stamp, stamp, bars); // perf-allowed: one exact historical bar, called only at the Monday 23:00 new-bar gate.
   if(copied != 1 || ArraySize(bars) != 1)
      return false;
   bar = bars[0];
   return (bar.time == stamp &&
           bar.open > 0.0 &&
           bar.close > 0.0 &&
           MathIsValidNumber(bar.open) &&
           MathIsValidNumber(bar.close));
  }

bool Strategy_MondayBreadthSignal(const datetime current)
  {
   MqlDateTime now;
   ZeroMemory(now);
   if(!TimeToStruct(current, now) || now.day_of_week != 1)
      return false;

   MqlDateTime base = now;
   base.hour = 0;
   base.min = 0;
   base.sec = 0;
   const datetime midnight = StructToTime(base);
   if(midnight <= 0)
      return false;

   const datetime cash_open = midnight + strategy_cash_open_hour * 3600 +
                              strategy_cash_open_minute * 60;
   const datetime cash_close = midnight + strategy_cash_close_hour * 3600 +
                               strategy_cash_close_minute * 60;
   MqlRates sp_open_bar;
   MqlRates sp_close_bar;
   MqlRates ws_open_bar;
   MqlRates ws_close_bar;
   if(!Strategy_ReadExactM30Bar(strategy_signal_sp, cash_open, sp_open_bar) ||
      !Strategy_ReadExactM30Bar(strategy_signal_sp, cash_close, sp_close_bar) ||
      !Strategy_ReadExactM30Bar(strategy_signal_ws, cash_open, ws_open_bar) ||
      !Strategy_ReadExactM30Bar(strategy_signal_ws, cash_close, ws_close_bar))
      return false;

   return (sp_close_bar.close < sp_open_bar.open &&
           ws_close_bar.close < ws_open_bar.open);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(strategy_signal_sp != "SP500.DWX" || strategy_signal_ws != "WS30.DWX")
      return true;
   if(strategy_entry_hour != 23 || strategy_exit_hour != 23)
      return true;
   if(strategy_cash_open_hour != 16 || strategy_cash_open_minute != 30 ||
      strategy_cash_close_hour != 22 || strategy_cash_close_minute != 30)
      return true;
   if(strategy_atr_period_d1 != 14 || strategy_stop_atr_mult != 1.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "BREADTH_TURNAROUND_TUESDAY";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   MqlDateTime now;
   ZeroMemory(now);
   const datetime current = TimeCurrent();
   if(!TimeToStruct(current, now) ||
      now.day_of_week != 1 ||
      now.hour != strategy_entry_hour ||
      now.min != 0)
      return false;
   if(Strategy_ManagedPositionCount() > 0 || !Strategy_MondayBreadthSignal(current))
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double entry = QM_EntryMarketPrice(QM_BUY);
   if(atr_value <= 0.0 || entry <= 0.0 ||
      !MathIsValidNumber(atr_value) || !MathIsValidNumber(entry))
      return false;

   req.sl = QM_StopATRFromValue(_Symbol,
                                QM_BUY,
                                entry,
                                atr_value,
                                strategy_stop_atr_mult);
   return (req.sl > 0.0 && req.sl < entry && MathIsValidNumber(req.sl));
  }

void Strategy_ManageOpenPosition()
  {
   if(Strategy_ManagedPositionCount() > 1)
      Strategy_CloseManagedPositions(QM_EXIT_STRATEGY);
  }

bool Strategy_ExitSignal()
  {
   if(!g_strategy_new_bar || Strategy_ManagedPositionCount() <= 0)
      return false;
   MqlDateTime now;
   ZeroMemory(now);
   if(!TimeToStruct(TimeCurrent(), now))
      return false;
   return (now.day_of_week == 2 &&
           now.hour == strategy_exit_hour &&
           now.min == 0);
  }

bool Strategy_NewsAllowsEntry(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return QM_NewsAllowsTrade2(_Symbol,
                                 broker_time,
                                 qm_news_temporal,
                                 qm_news_compliance);
   return QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);
  }

int OnInit()
  {
   if(!SymbolSelect(strategy_signal_sp, true) || !SymbolSelect(strategy_signal_ws, true))
      return INIT_FAILED;

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

   string signal_symbols[2] = {strategy_signal_sp, strategy_signal_ws};
   QM_BasketWarmupHistory(signal_symbols, PERIOD_M30, 512);
   string host_symbol[1] = {_Symbol};
   QM_BasketWarmupHistory(host_symbol, PERIOD_D1, 50);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13137\",\"ea\":\"breadth-tue\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   g_strategy_new_bar = QM_IsNewBar();
   if(g_strategy_new_bar)
      QM_EquityStreamOnNewBar();

   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      Strategy_CloseManagedPositions(QM_EXIT_TIME_STOP);
      return;
     }

   if(!g_strategy_new_bar || !Strategy_NewsAllowsEntry(TimeCurrent()))
      return;

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
