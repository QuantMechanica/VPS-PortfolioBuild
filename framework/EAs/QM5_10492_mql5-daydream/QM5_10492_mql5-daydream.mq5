#property strict
#property version   "5.0"
#property description "MQL5 Daydream rebuild"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10492;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_PAUSE;
input int    qm_news_pause_before_minutes = 30;
input int    qm_news_pause_after_minutes  = 30;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_H1;
input int    strategy_model             = 1;
input int    strategy_fast_period       = 14;
input int    strategy_mid_period        = 21;
input int    strategy_slow_period       = 50;
input int    strategy_adx_period        = 14;
input int    strategy_rsi_period        = 14;
input int    strategy_atr_period        = 14;
input int    strategy_channel_bars      = 20;
input int    strategy_momentum_period   = 14;
input int    strategy_time_stop_bars    = 48;
input int    strategy_volume_lookback   = 20;
input double strategy_atr_sl_mult       = 1.00;
input double strategy_tp_r_mult         = 1.50;
input double strategy_delta             = 0.0;
input double strategy_min_distance_points = 5.0;
input double strategy_max_spread_points = 250.0;
input double strategy_min_atr_points    = 0.0;
input double strategy_breakout_buffer_points = 10.0;
input double strategy_volume_mult       = 1.0;

string strategy_symbols[] = {"EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "XAUUSD.DWX"};
string strategy_reason = "DAYDREAM";
datetime g_strategy_exit_eval_bar = 0;
bool g_strategy_exit_signal_cached = false;

#include "..\\_mql5_codebase_rebuild_common.mqh"

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        qm_news_pause_before_minutes,
                        qm_news_pause_after_minutes,
                        qm_news_stale_max_hours,
                        qm_news_min_impact))
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
