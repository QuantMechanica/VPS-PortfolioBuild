#property strict
#property version   "5.0"
#property description "QM5_11509 Carter-T EMA(5/10) + Stoch + RSI Trend H1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11509;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal     = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance   = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours                = 336;
input string qm_news_min_impact                     = "high";
input QM_NewsMode qm_news_mode_legacy               = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_fast_period    = 5;
input int    strategy_ema_slow_period    = 10;
input int    strategy_cross_lookback     = 3;
input int    strategy_stoch_k            = 14;
input int    strategy_stoch_d            = 3;
input int    strategy_stoch_slowing      = 3;
input double strategy_stoch_overbought   = 80.0;
input double strategy_stoch_oversold     = 20.0;
input int    strategy_rsi_period         = 14;
input double strategy_rsi_midline        = 50.0;
input int    strategy_sl_pips            = 30;
input int    strategy_spread_cap_pips    = 15;
input bool   strategy_no_friday_entry    = true;

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   const double max_spread = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread > 0.0 && max_spread > 0.0 && spread > max_spread)
      return true;

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

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_no_friday_entry)
     {
      MqlDateTime now_parts;
      TimeToStruct(TimeCurrent(), now_parts);
      if(now_parts.day_of_week == 5)
         return false;
     }

   const double stoch_1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stoch_2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   const double rsi_1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(stoch_1 <= 0.0 || stoch_2 <= 0.0 || rsi_1 <= 0.0)
      return false;

   bool crossed_up = false;
   bool crossed_down = false;
   const int lookback = MathMax(1, strategy_cross_lookback);
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double fast_now = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, shift);
      const double slow_now = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, shift);
      const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, shift + 1);
      const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, shift + 1);
      if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
         continue;
      if(fast_now > slow_now && fast_prev <= slow_prev)
         crossed_up = true;
      if(fast_now < slow_now && fast_prev >= slow_prev)
         crossed_down = true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(crossed_up && stoch_1 > stoch_2 && stoch_1 < strategy_stoch_overbought && rsi_1 > strategy_rsi_midline)
     {
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, ask, strategy_sl_pips);
      if(sl <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.reason = "ema5_10_stoch_rsi_long";
      return true;
     }

   if(crossed_down && stoch_1 < stoch_2 && stoch_1 > strategy_stoch_oversold && rsi_1 < strategy_rsi_midline)
     {
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, bid, strategy_sl_pips);
      if(sl <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = sl;
      req.reason = "ema5_10_stoch_rsi_short";
      return true;
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
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   int direction = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      direction = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;
      break;
     }
   if(direction == 0)
      return false;

   const double fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   const double rsi_1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(fast_1 <= 0.0 || slow_1 <= 0.0 || fast_2 <= 0.0 || slow_2 <= 0.0 || rsi_1 <= 0.0 || rsi_2 <= 0.0)
      return false;

   if(direction > 0)
      return (fast_2 >= slow_2 && fast_1 < slow_1) || (rsi_2 >= strategy_rsi_midline && rsi_1 < strategy_rsi_midline);

   return (fast_2 <= slow_2 && fast_1 > slow_1) || (rsi_2 <= strategy_rsi_midline && rsi_1 > strategy_rsi_midline);
  }

// News Filter Hook
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
