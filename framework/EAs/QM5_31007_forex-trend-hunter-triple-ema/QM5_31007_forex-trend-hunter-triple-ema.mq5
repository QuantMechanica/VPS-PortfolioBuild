#property strict
#property version   "5.0"
#property description "Forex Trend Hunter Triple EMA"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 31007;
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
input int InpFastEMA = 21;
input int InpMidEMA  = 55;
input int InpSlowEMA = 200;

double g_strategy_initial_equity = 0.0;
ulong  g_trail_ticket = 0;
double g_trail_high = 0.0;
double g_trail_low = 0.0;

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
      Strategy_WideSpread(PERIOD_H1) ||
      InpFastEMA < 10 || InpFastEMA > 30 ||
      InpMidEMA < 35 || InpMidEMA > 75 ||
      InpSlowEMA < 100 || InpSlowEMA > 300 ||
      InpFastEMA >= InpMidEMA || InpMidEMA >= InpSlowEMA)
      return false;

   MqlRates signal_bar[];
   ArraySetAsSeries(signal_bar, true);
   if(CopyRates(_Symbol, PERIOD_H1, 1, 1, signal_bar) != 1) // perf-allowed: one closed pullback bar.
      return false;

   const double ema_fast = QM_EMA(_Symbol, PERIOD_H1, InpFastEMA, 1);
   const double ema_mid = QM_EMA(_Symbol, PERIOD_H1, InpMidEMA, 1);
   const double ema_slow = QM_EMA(_Symbol, PERIOD_H1, InpSlowEMA, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0 ||
      ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   if(ema_fast > ema_mid && ema_mid > ema_slow &&
      signal_bar[0].low <= ema_mid && signal_bar[0].close > ema_fast)
     {
      const double sl = ema_slow - point;
      const double risk = ask - sl;
      if(sl <= 0.0 || risk <= 0.0)
         return false;
      req.type = QM_BUY;
      req.price = ask;
      req.sl = NormalizeDouble(sl, digits);
      req.tp = NormalizeDouble(ask + 3.8 * risk, digits);
      req.reason = "triple_ema_uptrend_pullback";
      return true;
     }

   if(ema_fast < ema_mid && ema_mid < ema_slow &&
      signal_bar[0].high >= ema_mid && signal_bar[0].close < ema_fast)
     {
      const double sl = ema_slow + point;
      const double risk = sl - bid;
      if(risk <= 0.0)
         return false;
      req.type = QM_SELL;
      req.price = bid;
      req.sl = NormalizeDouble(sl, digits);
      req.tp = NormalizeDouble(bid - 3.8 * risk, digits);
      req.reason = "triple_ema_downtrend_pullback";
      return req.tp > 0.0;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      found = true;
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double atr = QM_ATR(_Symbol, PERIOD_H1, 14, 1);
      const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      if(open_price <= 0.0 || bid <= 0.0 || ask <= 0.0 || point <= 0.0 || atr <= 0.0)
         continue;

      if(g_trail_ticket != ticket)
        {
         g_trail_ticket = ticket;
         g_trail_high = MathMax(open_price, bid);
         g_trail_low = MathMin(open_price, ask);
        }

      if(type == POSITION_TYPE_BUY)
        {
         g_trail_high = MathMax(g_trail_high, bid);
         const double target_sl = NormalizeDouble(g_trail_high - 3.0 * atr, digits);
         if(target_sl > 0.0 && target_sl < bid &&
            (current_sl <= 0.0 || target_sl > current_sl + point * 0.5))
            QM_TM_MoveSL(ticket, target_sl, "triple_ema_chandelier_long");
        }
      else if(type == POSITION_TYPE_SELL)
        {
         g_trail_low = MathMin(g_trail_low, ask);
         const double target_sl = NormalizeDouble(g_trail_low + 3.0 * atr, digits);
         if(target_sl > ask &&
            (current_sl <= 0.0 || target_sl < current_sl - point * 0.5))
            QM_TM_MoveSL(ticket, target_sl, "triple_ema_chandelier_short");
        }
     }

   if(!found)
     {
      g_trail_ticket = 0;
      g_trail_high = 0.0;
      g_trail_low = 0.0;
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
