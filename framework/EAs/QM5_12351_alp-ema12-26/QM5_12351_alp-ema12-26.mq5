#property strict
#property version   "5.0"
#property description "QM5_12351 Alpaca EMA12/26 MACD-state trend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12351;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fast_ema_period = 12;
input int    strategy_slow_ema_period = 26;
input int    strategy_atr_period      = 14;
input double strategy_atr_stop_mult   = 2.0;
input int    strategy_warmup_bars     = 100;

double g_fast_ema = 0.0;
double g_slow_ema = 0.0;
int    g_warmup_bars_seen = 0;
bool   g_signal_ready = false;

bool Strategy_InputsValid()
  {
   if(qm_ea_id != 12351 || qm_magic_slot_offset < 0 || qm_magic_slot_offset > 6)
      return false;
   if(RISK_FIXED <= 0.0 || RISK_PERCENT != 0.0)
      return false;
   if(strategy_fast_ema_period < 2 || strategy_slow_ema_period <= strategy_fast_ema_period)
      return false;
   if(strategy_atr_period < 2 || strategy_atr_stop_mult <= 0.0)
      return false;
   if(strategy_warmup_bars < strategy_slow_ema_period)
      return false;
   if(!MathIsValidNumber(qm_stress_reject_probability) ||
      qm_stress_reject_probability < 0.0 || qm_stress_reject_probability > 1.0)
      return false;
   return true;
  }

void AdvanceState_OnNewBar()
  {
   g_signal_ready = false;
   g_fast_ema = QM_EMA(_Symbol, _Period, strategy_fast_ema_period, 1);
   g_slow_ema = QM_EMA(_Symbol, _Period, strategy_slow_ema_period, 1);
   if(g_fast_ema <= 0.0 || g_slow_ema <= 0.0)
      return;

   if(g_warmup_bars_seen < strategy_warmup_bars)
      ++g_warmup_bars_seen;
   g_signal_ready = (g_warmup_bars_seen >= strategy_warmup_bars);
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (bid <= 0.0 || ask <= 0.0 || ask < bid);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_signal_ready || g_fast_ema <= g_slow_ema || Strategy_HasOpenPosition())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;
   const double stop = QM_StopATR(_Symbol,
                                  QM_BUY,
                                  entry,
                                  strategy_atr_period,
                                  strategy_atr_stop_mult);
   if(stop <= 0.0 || stop >= entry)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = stop;
   req.tp = 0.0;
   req.reason = "ALP_EMA12_26_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // The card specifies only the server-side ATR hard stop.
  }

bool Strategy_ExitSignal()
  {
   return (g_signal_ready && g_fast_ema < g_slow_ema && Strategy_HasOpenPosition());
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!Strategy_InputsValid())
      return INIT_PARAMETERS_INCORRECT;
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

   g_fast_ema = 0.0;
   g_slow_ema = 0.0;
   g_warmup_bars_seen = 0;
   g_signal_ready = false;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"12351\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   const bool new_bar = QM_IsNewBar();
   if(new_bar)
     {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
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
     }

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !new_bar)
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
