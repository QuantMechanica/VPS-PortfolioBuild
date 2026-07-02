#property strict
#property version   "5.0"
#property description "QM5_12897 XAG Donchian-55 trend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12897;
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
input int    strategy_donchian_entry_period = 55;
input int    strategy_donchian_exit_period  = 20;
input int    strategy_adx_period            = 14;
input double strategy_adx_threshold         = 25.0;
input int    strategy_atr_period            = 20;
input double strategy_atr_stop_mult         = 2.0;
input int    strategy_max_hold_bars         = 90;
input int    strategy_max_spread_points     = 300;

bool Strategy_IsTarget()
  {
   return (_Symbol == "XAGUSD.DWX" && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_ParamsValid()
  {
   if(strategy_donchian_entry_period < 2)
      return false;
   if(strategy_donchian_exit_period < 2)
      return false;
   if(strategy_adx_period < 2 || strategy_adx_threshold <= 0.0)
      return false;
   if(strategy_atr_period < 2 || strategy_atr_stop_mult <= 0.0)
      return false;
   if(strategy_max_hold_bars <= 0 || strategy_max_spread_points < 0)
      return false;
   return true;
  }

bool Strategy_SpreadOK()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;
   if(ask > bid)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > (double)strategy_max_spread_points)
         return false;
     }
   return true;
  }

// perf-allowed: Donchian close-channel math is bespoke structural OHLC logic.
double Strategy_HighestClose(const int start_shift, const int count)
  {
   if(start_shift < 1 || count <= 0)
      return 0.0;
   double best = 0.0;
   for(int shift = start_shift; shift < start_shift + count; ++shift)
     {
      const double value = iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 Donchian close-channel math
      if(value <= 0.0)
         return 0.0;
      if(best <= 0.0 || value > best)
         best = value;
     }
   return best;
  }

// perf-allowed: Donchian close-channel math is bespoke structural OHLC logic.
double Strategy_LowestClose(const int start_shift, const int count)
  {
   if(start_shift < 1 || count <= 0)
      return 0.0;
   double best = 0.0;
   for(int shift = start_shift; shift < start_shift + count; ++shift)
     {
      const double value = iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 Donchian close-channel math
      if(value <= 0.0)
         return 0.0;
      if(best <= 0.0 || value < best)
         best = value;
     }
   return best;
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
   if(!Strategy_IsTarget())
      return true;
   if(!Strategy_ParamsValid())
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "XAG_DONCHIAN55";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadOK())
      return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 signal close for Donchian breakout
   const double entry_high = Strategy_HighestClose(2, strategy_donchian_entry_period);
   const double entry_low = Strategy_LowestClose(2, strategy_donchian_entry_period);
   const double adx = QM_ADX(_Symbol, PERIOD_D1, strategy_adx_period, 1);
   if(close1 <= 0.0 || entry_high <= 0.0 || entry_low <= 0.0 || adx <= 0.0)
      return false;
   if(adx < strategy_adx_threshold)
      return false;

   int direction = 0;
   if(close1 > entry_high)
      direction = 1;
   else if(close1 < entry_low)
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;
   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_stop_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (direction > 0) ? "XAG_DONCHIAN55_LONG" : "XAG_DONCHIAN55_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 signal close for Donchian exit
   const double exit_high = Strategy_HighestClose(2, strategy_donchian_exit_period);
   const double exit_low = Strategy_LowestClose(2, strategy_donchian_exit_period);
   if(close1 <= 0.0 || exit_high <= 0.0 || exit_low <= 0.0)
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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && close1 < exit_low)
         return true;
      if(type == POSITION_TYPE_SELL && close1 > exit_high)
         return true;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at > 0)
        {
         const long held_seconds = (long)(TimeCurrent() - opened_at);
         if(held_seconds >= (long)strategy_max_hold_bars * 86400L)
            return true;
        }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12897\",\"ea\":\"xag-donchian55-trend\"}");
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
