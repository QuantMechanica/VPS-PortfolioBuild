#property strict
#property version   "5.0"
#property description "QM5_1213 Lucca-Moench Pre-FOMC Announcement Drift"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1213;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_hold_hours         = 24;
input int    strategy_atr_period_h1      = 20;
input double strategy_atr_sl_mult        = 1.5;
input int    strategy_session_start_hour = 0;
input int    strategy_session_end_hour   = 24;
input int    strategy_max_spread_points  = 0;

datetime g_fomc_events[] =
  {
   D'2018.01.31 21:00', D'2018.03.21 21:00', D'2018.05.02 21:00', D'2018.06.13 21:00',
   D'2018.08.01 21:00', D'2018.09.26 21:00', D'2018.11.08 21:00', D'2018.12.19 21:00',
   D'2019.01.30 21:00', D'2019.03.20 21:00', D'2019.05.01 21:00', D'2019.06.19 21:00',
   D'2019.07.31 21:00', D'2019.09.18 21:00', D'2019.10.30 21:00', D'2019.12.11 21:00',
   D'2020.01.29 21:00', D'2020.03.18 21:00', D'2020.04.29 21:00', D'2020.06.10 21:00',
   D'2020.07.29 21:00', D'2020.09.16 21:00', D'2020.11.05 21:00', D'2020.12.16 21:00',
   D'2021.01.27 21:00', D'2021.03.17 21:00', D'2021.04.28 21:00', D'2021.06.16 21:00',
   D'2021.07.28 21:00', D'2021.09.22 21:00', D'2021.11.03 21:00', D'2021.12.15 21:00',
   D'2022.01.26 21:00', D'2022.03.16 21:00', D'2022.05.04 21:00', D'2022.06.15 21:00',
   D'2022.07.27 21:00', D'2022.09.21 21:00', D'2022.11.02 21:00', D'2022.12.14 21:00',
   D'2023.02.01 21:00', D'2023.03.22 21:00', D'2023.05.03 21:00', D'2023.06.14 21:00',
   D'2023.07.26 21:00', D'2023.09.20 21:00', D'2023.11.01 21:00', D'2023.12.13 21:00',
   D'2024.01.31 21:00', D'2024.03.20 21:00', D'2024.05.01 21:00', D'2024.06.12 21:00',
   D'2024.07.31 21:00', D'2024.09.18 21:00', D'2024.11.07 21:00', D'2024.12.18 21:00',
   D'2025.01.29 21:00', D'2025.03.19 21:00', D'2025.05.07 21:00', D'2025.06.18 21:00',
   D'2025.07.30 21:00', D'2025.09.17 21:00', D'2025.10.29 21:00', D'2025.12.10 21:00',
   D'2026.01.28 21:00', D'2026.03.18 21:00', D'2026.04.29 21:00', D'2026.06.17 21:00',
   D'2026.07.29 21:00', D'2026.09.16 21:00', D'2026.10.28 21:00', D'2026.12.09 21:00'
  };

datetime g_last_event_entered = 0;
datetime g_active_event_time  = 0;

int Strategy_ClampInt(const int value, const int min_value, const int max_value)
  {
   if(value < min_value)
      return min_value;
   if(value > max_value)
      return max_value;
   return value;
  }

bool Strategy_IsSupportedSymbol()
  {
   return (_Symbol == "SP500.DWX" || _Symbol == "NDX.DWX" || _Symbol == "WS30.DWX");
  }

bool Strategy_IsSessionOpen(const datetime broker_time)
  {
   if(strategy_session_start_hour == strategy_session_end_hour)
      return true;

   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;

   const int start_h = Strategy_ClampInt(strategy_session_start_hour, 0, 23);
   const int end_h = Strategy_ClampInt(strategy_session_end_hour, 0, 24);
   if(end_h <= start_h)
      return (dt.hour >= start_h || dt.hour < end_h);
   return (dt.hour >= start_h && dt.hour < end_h);
  }

datetime Strategy_NextFomcEvent(const datetime broker_time)
  {
   const int count = ArraySize(g_fomc_events);
   for(int i = 0; i < count; ++i)
      if(g_fomc_events[i] > broker_time)
         return g_fomc_events[i];
   return 0;
  }

datetime Strategy_CurrentOrRecentFomcEvent(const datetime broker_time)
  {
   const int count = ArraySize(g_fomc_events);
   for(int i = count - 1; i >= 0; --i)
      if(g_fomc_events[i] <= broker_time)
         return g_fomc_events[i];
   return 0;
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

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsSupportedSymbol())
      return true;

   const datetime broker_now = TimeCurrent();
   if(!Strategy_IsSessionOpen(broker_now))
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_hold_hours <= 0 || strategy_atr_period_h1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   const datetime event_time = Strategy_NextFomcEvent(broker_now);
   if(event_time <= 0 || event_time == g_last_event_entered)
      return false;

   const datetime entry_start = event_time - strategy_hold_hours * 3600;
   if(broker_now < entry_start || broker_now >= event_time)
      return false;
   if(!Strategy_IsSessionOpen(broker_now))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period_h1, 1);
   if(ask <= 0.0 || atr <= 0.0)
      return false;

   req.type = QM_BUY;
   req.price = ask;
   req.sl = NormalizeDouble(ask - atr * strategy_atr_sl_mult, _Digits);
   req.tp = 0.0;
   req.reason = "LUCCA_PREFOMC_DRIFT_LONG";
   req.symbol_slot = qm_magic_slot_offset;

   g_last_event_entered = event_time;
   g_active_event_time = event_time;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, partial close, or break-even rule.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   if(g_active_event_time > 0 && broker_now >= g_active_event_time)
      return true;

   const datetime recent_event = Strategy_CurrentOrRecentFomcEvent(broker_now);
   if(recent_event > 0 && broker_now >= recent_event && broker_now <= recent_event + 6 * 3600)
      return true;

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1213\",\"ea\":\"lucca_prefomc_drift\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
