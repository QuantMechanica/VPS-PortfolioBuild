#property strict
#property version   "5.0"
#property description "QM5_10787 TradingView EMA RSI ADX"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10787;
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
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_fast          = 9;
input int    strategy_ema_slow          = 21;
input int    strategy_rsi_period        = 14;
input double strategy_rsi_long_thresh   = 55.0;
input double strategy_rsi_short_thresh  = 45.0;
input bool   strategy_adx_filter_on     = true;
input int    strategy_adx_period        = 14;
input double strategy_adx_threshold     = 20.0;
input int    strategy_stop_mode         = 0;     // 0 = ATR stop, 1 = fixed-percent stop
input int    strategy_stop_atr_period   = 14;
input double strategy_stop_atr_mult     = 2.0;
input double strategy_stop_fixed_pct    = 2.0;

bool g_suppress_entry_after_exit = false;

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(g_suppress_entry_after_exit)
     {
      g_suppress_entry_after_exit = false;
      return false;
     }

   if(strategy_ema_fast <= 0 || strategy_ema_slow <= 0 ||
      strategy_rsi_period <= 0 || strategy_adx_period <= 0 ||
      strategy_stop_atr_period <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const int cross = QM_Sig_MA_Cross(_Symbol, PERIOD_CURRENT,
                                     strategy_ema_fast,
                                     strategy_ema_slow,
                                     1);
   if(cross == 0)
      return false;

   if(strategy_adx_filter_on)
     {
      const double adx = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
      if(adx <= strategy_adx_threshold)
         return false;
     }

   const double rsi = QM_RSI(_Symbol, PERIOD_CURRENT, strategy_rsi_period, 1);
   req.price = 0.0;
   req.tp = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(cross > 0 && rsi > strategy_rsi_long_thresh)
     {
      req.type = QM_BUY;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(strategy_stop_mode == 1)
         req.sl = NormalizeDouble(entry * (1.0 - strategy_stop_fixed_pct / 100.0), _Digits);
      else
         req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_stop_atr_period, strategy_stop_atr_mult);
      req.reason = "tv_ema_rsi_adx_long";
      return (entry > 0.0 && req.sl > 0.0 && req.sl < entry);
     }

   if(cross < 0 && rsi < strategy_rsi_short_thresh)
     {
      req.type = QM_SELL;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(strategy_stop_mode == 1)
         req.sl = NormalizeDouble(entry * (1.0 + strategy_stop_fixed_pct / 100.0), _Digits);
      else
         req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_stop_atr_period, strategy_stop_atr_mult);
      req.reason = "tv_ema_rsi_adx_short";
      return (entry > 0.0 && req.sl > 0.0 && req.sl > entry);
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   ENUM_POSITION_TYPE open_type = POSITION_TYPE_BUY;
   bool have_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      open_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      have_position = true;
      break;
     }

   if(!have_position)
      return false;

   const int cross = QM_Sig_MA_Cross(_Symbol, PERIOD_CURRENT,
                                     strategy_ema_fast,
                                     strategy_ema_slow,
                                     1);
   if((open_type == POSITION_TYPE_BUY && cross < 0) ||
      (open_type == POSITION_TYPE_SELL && cross > 0))
     {
      g_suppress_entry_after_exit = true;
      return true;
     }

   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10787_tv-ema-rsi-adx\"}");
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
