#property strict
#property version   "5.0"
#property description "QM5_10951 Renaissance-style short horizon reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10951;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_rsi_period                  = 2;
input int    strategy_atr_period                  = 14;
input int    strategy_ema_filter_period           = 100;
input int    strategy_ema_exit_period             = 20;
input double strategy_exhaustion_atr_mult         = 1.25;
input double strategy_ema_distance_atr_mult       = 2.0;
input double strategy_stop_atr_mult               = 1.2;
input double strategy_take_profit_r               = 1.2;
input int    strategy_time_exit_bars              = 8;
input int    strategy_atr_percentile_lookback     = 252;
input double strategy_atr_percentile              = 90.0;
input int    strategy_weekend_skip_hours          = 4;
input double strategy_spread_stop_fraction        = 0.10;
input int    strategy_warmup_bars                 = 300;

bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int skip_start_hour = MathMax(0, qm_friday_close_hour_broker - strategy_weekend_skip_hours);
   if(dt.day_of_week == 5 && dt.hour >= skip_start_hour)
      return true;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double stop_distance = atr * strategy_stop_atr_mult;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(stop_distance <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;
   if((ask - bid) > stop_distance * strategy_spread_stop_fraction)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_rsi_period <= 0 || strategy_atr_period <= 0 ||
      strategy_ema_filter_period <= 0 || strategy_atr_percentile_lookback <= 0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const int need_bars = MathMax(strategy_warmup_bars, strategy_atr_percentile_lookback + 2);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, 1, need_bars, rates); // perf-allowed: closed-bar return and ATR percentile are card-specific raw OHLC math, called only after the framework new-bar gate.
   if(copied < need_bars)
      return false;

   const double close1 = rates[0].close;
   const double close2 = rates[1].close;
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
   const double ema_filter = QM_EMA(_Symbol, tf, strategy_ema_filter_period, 1);
   if(atr <= 0.0 || rsi <= 0.0 || ema_filter <= 0.0)
      return false;

   double atr_ratios[];
   ArrayResize(atr_ratios, strategy_atr_percentile_lookback);
   int ratio_count = 0;
   for(int i = 0; i < strategy_atr_percentile_lookback; ++i)
     {
      const double c = rates[i].close;
      const double a = QM_ATR(_Symbol, tf, strategy_atr_period, i + 1);
      if(c <= 0.0 || a <= 0.0)
         continue;
      atr_ratios[ratio_count] = a / c;
      ratio_count++;
     }
   if(ratio_count < strategy_atr_percentile_lookback)
      return false;

   ArrayResize(atr_ratios, ratio_count);
   ArraySort(atr_ratios);
   int percentile_idx = (int)MathFloor((ratio_count - 1) * (strategy_atr_percentile / 100.0));
   if(percentile_idx < 0)
      percentile_idx = 0;
   if(percentile_idx >= ratio_count)
      percentile_idx = ratio_count - 1;
   const double current_atr_ratio = atr / close1;
   if(current_atr_ratio > atr_ratios[percentile_idx])
      return false;

   const double ret = (close1 - close2) / close2;
   const double exhaustion = strategy_exhaustion_atr_mult * atr / close1;
   const double ema_band = strategy_ema_distance_atr_mult * atr;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double stop_distance = atr * strategy_stop_atr_mult;
   if(stop_distance <= 0.0 || (ask - bid) > stop_distance * strategy_spread_stop_fraction)
      return false;

   if(ret <= -exhaustion && rsi < 10.0 && close1 >= ema_filter - ema_band)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, req.price, atr, strategy_stop_atr_mult);
      req.tp = QM_TakeRR(_Symbol, QM_BUY, req.price, req.sl, strategy_take_profit_r);
      req.reason = "RENTECH_SHORT_REVERT_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(ret >= exhaustion && rsi > 90.0 && close1 <= ema_filter + ema_band)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopATRFromValue(_Symbol, QM_SELL, req.price, atr, strategy_stop_atr_mult);
      req.tp = QM_TakeRR(_Symbol, QM_SELL, req.price, req.sl, strategy_take_profit_r);
      req.reason = "RENTECH_SHORT_REVERT_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even move, partial close, or add-on entry.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int price_vs_exit_ema = QM_Sig_Price_Above_MA(_Symbol, (ENUM_TIMEFRAMES)_Period,
                                                       strategy_ema_exit_period, 0.0, 1);
   const double ema_exit = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_exit_period, 1);
   const double rsi = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, 1);
   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(ema_exit <= 0.0 || rsi <= 0.0 || period_seconds <= 0)
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
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const bool time_exit = ((TimeCurrent() - open_time) >= strategy_time_exit_bars * period_seconds);
      if(type == POSITION_TYPE_BUY && (price_vs_exit_ema >= 0 || rsi > 60.0 || time_exit))
         return true;
      if(type == POSITION_TYPE_SELL && (price_vs_exit_ema <= 0 || rsi < 40.0 || time_exit))
         return true;
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
