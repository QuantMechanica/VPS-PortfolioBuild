#property strict
#property version   "5.0"
#property description "QM5_1239 Raposa EMA Crossover ATR"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1239;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe       = PERIOD_H1;
input int             strategy_ema_fast        = 20;
input int             strategy_ema_slow        = 80;
input int             strategy_ema_trend       = 200;
input int             strategy_atr_period      = 14;
input int             strategy_atr_median_bars = 240;
input double          strategy_min_atr_ratio   = 0.50;
input double          strategy_stop_atr_mult   = 2.0;
input double          strategy_tp_r_mult       = 2.0;
input double          strategy_trail_trigger_r = 1.5;
input double          strategy_trail_atr_mult  = 2.5;
input int             strategy_max_hold_bars   = 120;
input int             strategy_min_history_bars = 260;
input int             strategy_spread_days     = 20;
input double          strategy_spread_mult     = 2.0;

datetime g_last_exit_bar = 0;
bool     g_exit_now      = false;

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double Strategy_MedianAtr()
  {
   const int bars = MathMax(1, strategy_atr_median_bars);
   double values[];
   ArrayResize(values, bars);
   int count = 0;

   for(int shift = 1; shift <= bars; ++shift)
     {
      const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, shift);
      if(atr > 0.0)
        {
         values[count] = atr;
         count++;
        }
     }

   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);

   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return (values[mid - 1] + values[mid]) * 0.5;
  }

double Strategy_MedianSpreadForEntryHour()
  {
   if(strategy_spread_days <= 0)
      return 0.0;

   const datetime signal_bar_time = iTime(_Symbol, strategy_timeframe, 1);
   if(signal_bar_time <= 0)
      return 0.0;

   MqlDateTime signal_dt;
   TimeToStruct(signal_bar_time, signal_dt);

   const int max_shift = MathMax(1, strategy_spread_days * 24);
   double values[];
   ArrayResize(values, max_shift);
   int count = 0;

   for(int shift = 1; shift <= max_shift; ++shift)
     {
      const datetime t = iTime(_Symbol, strategy_timeframe, shift);
      if(t <= 0)
         continue;

      MqlDateTime dt;
      TimeToStruct(t, dt);
      if(dt.hour != signal_dt.hour)
         continue;

      const double spread = (double)iSpread(_Symbol, strategy_timeframe, shift);
      if(spread > 0.0)
        {
         values[count] = spread;
         count++;
        }
     }

   if(count <= 0)
      return 0.0;

   ArrayResize(values, count);
   ArraySort(values);

   const int mid = count / 2;
   if((count % 2) == 1)
      return values[mid];
   return (values[mid - 1] + values[mid]) * 0.5;
  }

bool Strategy_SpreadOk()
  {
   const double median_spread = Strategy_MedianSpreadForEntryHour();
   if(median_spread <= 0.0)
      return true;

   const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0.0)
      return false;

   return (current_spread <= median_spread * strategy_spread_mult);
  }

int Strategy_BarsHeld(const datetime open_time)
  {
   if(open_time <= 0)
      return 0;

   const int shift = iBarShift(_Symbol, strategy_timeframe, open_time, false);
   if(shift < 0)
      return 0;
   return shift;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_timeframe != PERIOD_H1)
      return true;
   if(_Period != strategy_timeframe)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "RAPOSA_MA_ATR";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int warmup = MathMax(strategy_min_history_bars,
                              strategy_ema_trend + strategy_atr_median_bars + strategy_atr_period + 5);
   if(Bars(_Symbol, strategy_timeframe) < warmup)
      return false;

   if(g_exit_now && g_last_exit_bar == iTime(_Symbol, strategy_timeframe, 0))
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(Strategy_SelectOurPosition(ticket, ptype, open_time))
      return false;

   if(!Strategy_SpreadOk())
      return false;

   const double ema_fast_1 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_fast, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_fast, 2);
   const double ema_slow_1 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_slow, 1);
   const double ema_slow_2 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_slow, 2);
   const double ema_trend_1 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_trend, 1);
   const double close_1 = iClose(_Symbol, strategy_timeframe, 1);
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double median_atr = Strategy_MedianAtr();
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ema_fast_1 <= 0.0 || ema_fast_2 <= 0.0 ||
      ema_slow_1 <= 0.0 || ema_slow_2 <= 0.0 ||
      ema_trend_1 <= 0.0 || close_1 <= 0.0 ||
      atr <= 0.0 || median_atr <= 0.0 ||
      ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   if(atr <= median_atr * strategy_min_atr_ratio)
      return false;

   const bool cross_up = (ema_fast_1 > ema_slow_1 && ema_fast_2 <= ema_slow_2);
   const bool cross_down = (ema_fast_1 < ema_slow_1 && ema_fast_2 >= ema_slow_2);
   const double stop_distance = atr * strategy_stop_atr_mult;
   if(stop_distance <= point)
      return false;

   if(cross_up && close_1 > ema_trend_1)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, QM_BUY, ask, stop_distance);
      req.tp = QM_StopRulesTakeFromDistance(_Symbol, QM_BUY, ask, stop_distance * strategy_tp_r_mult);
      req.reason = "RAPOSA_MA_ATR_LONG";
      return (req.sl > 0.0 && req.sl < ask - point && req.tp > ask + point);
     }

   if(cross_down && close_1 < ema_trend_1)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, QM_SELL, bid, stop_distance);
      req.tp = QM_StopRulesTakeFromDistance(_Symbol, QM_SELL, bid, stop_distance * strategy_tp_r_mult);
      req.reason = "RAPOSA_MA_ATR_SHORT";
      return (req.sl > bid + point && req.tp > 0.0 && req.tp < bid - point);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, ptype, open_time))
      return;

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double market = (ptype == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(open_price <= 0.0 || current_sl <= 0.0 || market <= 0.0)
      return;

   const double initial_r = MathAbs(open_price - current_sl);
   const double favorable = (ptype == POSITION_TYPE_BUY) ? (market - open_price)
                                                        : (open_price - market);
   if(initial_r > 0.0 && favorable >= initial_r * strategy_trail_trigger_r)
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
  }

bool Strategy_ExitSignal()
  {
   const datetime bar_time = iTime(_Symbol, strategy_timeframe, 0);
   if(bar_time <= 0)
      return false;
   if(bar_time == g_last_exit_bar)
      return g_exit_now;

   g_last_exit_bar = bar_time;
   g_exit_now = false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!Strategy_SelectOurPosition(ticket, ptype, open_time))
      return false;

   if(Strategy_BarsHeld(open_time) >= strategy_max_hold_bars)
     {
      g_exit_now = true;
      return true;
     }

   const double ema_fast_1 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_fast, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_fast, 2);
   const double ema_slow_1 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_slow, 1);
   const double ema_slow_2 = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_slow, 2);
   if(ema_fast_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_1 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY && ema_fast_1 < ema_slow_1 && ema_fast_2 >= ema_slow_2)
      g_exit_now = true;
   else if(ptype == POSITION_TYPE_SELL && ema_fast_1 > ema_slow_1 && ema_fast_2 <= ema_slow_2)
      g_exit_now = true;

   return g_exit_now;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1239\",\"ea\":\"QM5_1239_raposa-ma-atr\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
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
