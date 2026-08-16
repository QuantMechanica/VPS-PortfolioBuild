#property strict
#property version   "5.0"
#property description "NQ Micro Momentum Apex Scalper"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 32001;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    InpFastEMA  = 9;
input int    InpSlowEMA  = 21;
input double InpTPPoints = 20.0;
input double InpSLPoints = 15.0;
input double InpBEPoints = 10.0;

double g_strategy_initial_equity = 0.0;

bool Strategy_RolloverBlackout()
  {
   MqlDateTime utc;
   if(!TimeToStruct(QM_BrokerToUTC(TimeCurrent()), utc))
      return true;
   const int minute_of_day = utc.hour * 60 + utc.min;
   return minute_of_day >= 1435 || minute_of_day <= 5;
  }

bool Strategy_EntryCircuitBreaker()
  {
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_strategy_initial_equity <= 0.0 && equity > 0.0)
      g_strategy_initial_equity = equity;
   if(g_qm_ks_day_start_equity > 0.0 &&
      balance <= g_qm_ks_day_start_equity * 0.98)
      return true;
   return g_strategy_initial_equity > 0.0 &&
          equity <= g_strategy_initial_equity * 0.95;
  }

bool Strategy_EquityExitRequired()
  {
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_strategy_initial_equity <= 0.0 && equity > 0.0)
      g_strategy_initial_equity = equity;
   if(g_qm_ks_day_start_equity > 0.0 &&
      equity <= g_qm_ks_day_start_equity * 0.975)
      return true;
   return g_strategy_initial_equity > 0.0 &&
          equity <= g_strategy_initial_equity * 0.95;
  }

bool Strategy_WideSpread(const ENUM_TIMEFRAMES tf)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, tf, 14, 1);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return true;
   return ask > bid && (ask - bid) > 1.8 * atr;
  }

void Strategy_InitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_NoTradeFilter()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(Strategy_RolloverBlackout())
      return true;
   return Strategy_EntryCircuitBreaker();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_InitRequest(req);
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) >= 1 ||
      Strategy_WideSpread(PERIOD_M1) ||
      InpFastEMA < 5 || InpFastEMA > 15 ||
      InpSlowEMA < 15 || InpSlowEMA > 35 ||
      InpFastEMA >= InpSlowEMA ||
      InpTPPoints < 15.0 || InpTPPoints > 30.0 ||
      InpSLPoints < 10.0 || InpSLPoints > 20.0 ||
      InpBEPoints < 6.0 || InpBEPoints > 12.0)
      return false;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int requested = 20;
   if(CopyRates(_Symbol, PERIOD_M1, 1, requested, bars) != requested) // perf-allowed: bounded 20-bar signal-volume average.
      return false;

   double average_volume = 0.0;
   for(int i = 0; i < requested; ++i)
      average_volume += (double)bars[i].tick_volume;
   average_volume /= (double)requested;
   if(average_volume <= 0.0 ||
      (double)bars[0].tick_volume < 2.0 * average_volume)
      return false;

   const double ema_fast = QM_EMA(_Symbol, PERIOD_M1, InpFastEMA, 1);
   const double ema_slow = QM_EMA(_Symbol, PERIOD_M1, InpSlowEMA, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(ema_fast > ema_slow && bars[0].close > bars[1].high)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = NormalizeDouble(ask - InpSLPoints, digits);
      req.tp = NormalizeDouble(ask + InpTPPoints, digits);
      req.reason = "nq_m1_high_volume_up_break";
      return req.sl > 0.0;
     }

   if(ema_fast < ema_slow && bars[0].close < bars[1].low)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = NormalizeDouble(bid + InpSLPoints, digits);
      req.tp = NormalizeDouble(bid - InpTPPoints, digits);
      req.reason = "nq_m1_high_volume_down_break";
      return req.tp > 0.0;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      if(open_price <= 0.0 || bid <= 0.0 || ask <= 0.0 || point <= 0.0)
         continue;

      if(type == POSITION_TYPE_BUY && bid - open_price >= InpBEPoints)
        {
         const double target_sl = NormalizeDouble(open_price + 1.0, digits);
         if(target_sl < bid &&
            (current_sl <= 0.0 || target_sl > current_sl + point * 0.5))
            QM_TM_MoveSL(ticket, target_sl, "apex_lock_be_plus_1_long");
        }
      else if(type == POSITION_TYPE_SELL && open_price - ask >= InpBEPoints)
        {
         const double target_sl = NormalizeDouble(open_price - 1.0, digits);
         if(target_sl > ask &&
            (current_sl <= 0.0 || target_sl < current_sl - point * 0.5))
            QM_TM_MoveSL(ticket, target_sl, "apex_lock_be_plus_1_short");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   return Strategy_EquityExitRequired();
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
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || !QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
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
