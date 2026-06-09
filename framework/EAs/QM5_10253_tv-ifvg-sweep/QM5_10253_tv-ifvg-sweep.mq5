#property strict
#property version   "5.0"
#property description "QM5_10253 TradingView EMA Sweep IFVG Retest"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10253;
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
input int    strategy_h4_fast_ema        = 13;
input int    strategy_h4_mid_ema         = 21;
input int    strategy_h4_slow_ema        = 34;
input int    strategy_h1_fast_ema        = 13;
input int    strategy_h1_mid_ema         = 21;
input int    strategy_sweep_lookback     = 20;
input int    strategy_atr_period         = 14;
input double strategy_displacement_atr   = 1.0;
input double strategy_sl_atr_buffer      = 0.25;
input double strategy_reward_risk        = 2.0;
input int    strategy_time_stop_m15_bars = 32;
input int    strategy_pending_bars       = 8;
input int    strategy_max_spread_points  = 500;
input int    strategy_london_start_hour  = 8;
input int    strategy_london_end_hour    = 11;
input int    strategy_ny_start_hour      = 13;
input int    strategy_ny_end_hour        = 16;
input bool   strategy_enforce_m15        = true;

int BrokerHour(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
  }

bool HourInWindow(const int hour, const int start_hour, const int end_hour)
  {
   if(start_hour == end_hour)
      return true;
   if(start_hour < end_hour)
      return (hour >= start_hour && hour < end_hour);
   return (hour >= start_hour || hour < end_hour);
  }

bool InVolatilityWindow(const datetime broker_time)
  {
   const int hour = BrokerHour(broker_time);
   return HourInWindow(hour, strategy_london_start_hour, strategy_london_end_hour) ||
          HourInWindow(hour, strategy_ny_start_hour, strategy_ny_end_hour);
  }

bool ReadClosedBar(const ENUM_TIMEFRAMES tf, MqlRates &bar)
  {
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   if(CopyRates(_Symbol, tf, 1, 1, bars) != 1) // perf-allowed: bounded closed-bar OHLC read inside framework QM_IsNewBar-gated entry path.
      return false;
   bar = bars[0];
   return true;
  }

bool ReadM15Window(MqlRates &bars[], const int bars_needed)
  {
   ArraySetAsSeries(bars, true);
   const int copied = CopyRates(_Symbol, PERIOD_M15, 1, bars_needed, bars); // perf-allowed: bounded M15 structural sweep/IFVG window, called only from framework closed-bar entry path.
   return (copied >= bars_needed);
  }

double PriorLow(const MqlRates &bars[], const int start_index, const int count)
  {
   double value = DBL_MAX;
   for(int i = start_index; i < start_index + count; ++i)
      value = MathMin(value, bars[i].low);
   return value;
  }

double PriorHigh(const MqlRates &bars[], const int start_index, const int count)
  {
   double value = -DBL_MAX;
   for(int i = start_index; i < start_index + count; ++i)
      value = MathMax(value, bars[i].high);
   return value;
  }

int HigherTimeframeBias()
  {
   const double fast = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_fast_ema, 1);
   const double mid  = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_mid_ema, 1);
   const double slow = QM_EMA(_Symbol, PERIOD_H4, strategy_h4_slow_ema, 1);
   if(fast <= 0.0 || mid <= 0.0 || slow <= 0.0)
      return 0;
   if(fast > mid && mid > slow)
      return 1;
   if(fast < mid && mid < slow)
      return -1;
   return 0;
  }

int H1Continuation()
  {
   MqlRates h1;
   if(!ReadClosedBar(PERIOD_H1, h1))
      return 0;

   const double fast = QM_EMA(_Symbol, PERIOD_H1, strategy_h1_fast_ema, 1);
   const double mid  = QM_EMA(_Symbol, PERIOD_H1, strategy_h1_mid_ema, 1);
   if(fast <= 0.0 || mid <= 0.0 || h1.close <= 0.0)
      return 0;
   if(h1.close > mid && fast > mid)
      return 1;
   if(h1.close < mid && fast < mid)
      return -1;
   return 0;
  }

bool HasOurOpenPositionOrPending()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT ||
         type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_enforce_m15 && _Period != PERIOD_M15)
      return true;
   if(strategy_max_spread_points > 0 &&
      (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return true;
   if(!InVolatilityWindow(TimeCurrent()))
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
   req.expiration_seconds = MathMax(1, strategy_pending_bars) * PeriodSeconds(PERIOD_M15);

   if(HasOurOpenPositionOrPending())
      return false;
   if(strategy_sweep_lookback < 5 || strategy_atr_period < 2 ||
      strategy_reward_risk <= 0.0 || strategy_sl_atr_buffer < 0.0)
      return false;

   const int bias = HigherTimeframeBias();
   const int cont = H1Continuation();
   if(bias == 0 || cont == 0 || bias != cont)
      return false;

   const int bars_needed = strategy_sweep_lookback + 3;
   MqlRates bars[];
   if(!ReadM15Window(bars, bars_needed))
      return false;

   const MqlRates latest = bars[0];
   const MqlRates middle = bars[1];
   const MqlRates sweep  = bars[2];
   const double prior_low = PriorLow(bars, 3, strategy_sweep_lookback);
   const double prior_high = PriorHigh(bars, 3, strategy_sweep_lookback);
   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(prior_low == DBL_MAX || prior_high == -DBL_MAX || atr <= 0.0)
      return false;

   const double body = MathAbs(middle.close - middle.open);
   if(body < strategy_displacement_atr * atr)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const bool sell_side_sweep = (sweep.low < prior_low && sweep.close > prior_low);
   const bool buy_side_sweep = (sweep.high > prior_high && sweep.close < prior_high);
   const bool bullish_ifvg = (latest.low > sweep.high && middle.close > middle.open);
   const bool bearish_ifvg = (latest.high < sweep.low && middle.close < middle.open);

   if(bias > 0 && sell_side_sweep && bullish_ifvg)
     {
      const double zone_bottom = sweep.high;
      const double zone_top = latest.low;
      double entry = zone_top;
      bool market = false;
      if(ask <= zone_top && ask >= zone_bottom)
        {
         entry = ask;
         market = true;
        }
      else if(ask <= zone_bottom)
         return false;

      const double sl = sweep.low - strategy_sl_atr_buffer * atr;
      if(entry <= sl)
         return false;
      req.type = market ? QM_BUY : QM_BUY_LIMIT;
      req.price = market ? 0.0 : entry;
      req.sl = sl;
      req.tp = entry + strategy_reward_risk * (entry - sl);
      req.reason = "H4_H1_BULL_SWEEP_IFVG_RETEST";
      return true;
     }

   if(bias < 0 && buy_side_sweep && bearish_ifvg)
     {
      const double zone_bottom = latest.high;
      const double zone_top = sweep.low;
      double entry = zone_bottom;
      bool market = false;
      if(bid >= zone_bottom && bid <= zone_top)
        {
         entry = bid;
         market = true;
        }
      else if(bid >= zone_top)
         return false;

      const double sl = sweep.high + strategy_sl_atr_buffer * atr;
      if(entry >= sl)
         return false;
      req.type = market ? QM_SELL : QM_SELL_LIMIT;
      req.price = market ? 0.0 : entry;
      req.sl = sl;
      req.tp = entry - strategy_reward_risk * (sl - entry);
      req.reason = "H4_H1_BEAR_SWEEP_IFVG_RETEST";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(strategy_time_stop_m15_bars <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int hold_seconds = strategy_time_stop_m15_bars * PeriodSeconds(PERIOD_M15);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && TimeCurrent() - open_time >= hold_seconds)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      return !QM_NewsAllowsTrade2(_Symbol, broker_time, qm_news_temporal, qm_news_compliance);
   return !QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10253\",\"slug\":\"tv-ifvg-sweep\"}");
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
