#property strict
#property version   "5.0"
#property description "QM5_10195 TradingView Supertrend MACD EMA"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10195;
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
input ENUM_TIMEFRAMES strategy_timeframe = PERIOD_H1;
input int    strategy_supertrend_period  = 10;
input double strategy_supertrend_mult    = 3.0;
input int    strategy_supertrend_warmup  = 120;
input int    strategy_macd_fast          = 12;
input int    strategy_macd_slow          = 26;
input int    strategy_macd_signal        = 9;
input int    strategy_ema_period         = 200;
input int    strategy_swing_lookback     = 10;
input int    strategy_atr_period         = 14;
input double strategy_atr_fallback_mult  = 1.5;

void Strategy_ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;

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
      return true;
     }

   return false;
  }

int Strategy_SupertrendDirection(double &closed_bar_close)
  {
   closed_bar_close = 0.0;

   const int period = MathMax(1, strategy_supertrend_period);
   if(strategy_supertrend_mult <= 0.0)
      return 0;

   const int min_warmup = MathMax(period + 20, 80);
   const int warmup = MathMax(strategy_supertrend_warmup, min_warmup);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 1, warmup + 2, rates); // perf-allowed: bounded Supertrend OHLC read inside framework closed-bar entry hook.
   if(copied < period + 5)
      return 0;

   closed_bar_close = rates[0].close;

   int trend = 0;
   double final_upper = 0.0;
   double final_lower = 0.0;

   for(int idx = copied - 2; idx >= 0; --idx)
     {
      const int shift = idx + 1;
      const double high = rates[idx].high;
      const double low = rates[idx].low;
      const double close = rates[idx].close;
      const double prev_close = rates[idx + 1].close;
      const double atr = QM_ATR(_Symbol, strategy_timeframe, period, shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || prev_close <= 0.0 || atr <= 0.0)
         continue;

      const double midpoint = (high + low) * 0.5;
      const double basic_upper = midpoint + strategy_supertrend_mult * atr;
      const double basic_lower = midpoint - strategy_supertrend_mult * atr;

      if(trend == 0)
        {
         final_upper = basic_upper;
         final_lower = basic_lower;
         trend = (close >= midpoint) ? 1 : -1;
         continue;
        }

      final_upper = (basic_upper < final_upper || prev_close > final_upper) ? basic_upper : final_upper;
      final_lower = (basic_lower > final_lower || prev_close < final_lower) ? basic_lower : final_lower;

      if(trend < 0 && close > final_upper)
         trend = 1;
      else if(trend > 0 && close < final_lower)
         trend = -1;
     }

   return trend;
  }

bool Strategy_StopMeetsBrokerDistance(const QM_OrderType side,
                                      const double entry,
                                      const double stop)
  {
   if(entry <= 0.0 || stop <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(point <= 0.0)
      return false;

   if(QM_OrderTypeIsBuy(side) && stop >= entry)
      return false;
   if(!QM_OrderTypeIsBuy(side) && stop <= entry)
      return false;

   const double min_distance = (stops_level > 0) ? point * stops_level : 0.0;
   return (min_distance <= 0.0 || MathAbs(entry - stop) >= min_distance);
  }

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   return (_Period != strategy_timeframe);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetEntryRequest(req);

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(Strategy_SelectOurPosition(ticket, ptype))
      return false;

   double close_1 = 0.0;
   const int st_dir = Strategy_SupertrendDirection(close_1);
   if(st_dir == 0 || close_1 <= 0.0)
      return false;

   const double ema_1 = QM_EMA(_Symbol, strategy_timeframe, MathMax(1, strategy_ema_period), 1);
   const double macd_main_1 = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_signal_1 = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   if(ema_1 <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   string reason = "";
   if(st_dir > 0 && macd_main_1 > macd_signal_1 && close_1 > ema_1)
     {
      side = QM_BUY;
      reason = "ST_MACD_EMA_LONG";
     }
   else if(st_dir < 0 && macd_main_1 < macd_signal_1 && close_1 < ema_1)
     {
      side = QM_SELL;
      reason = "ST_MACD_EMA_SHORT";
     }
   else
      return false;

   const double entry = QM_EntryMarketPrice(side);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(entry <= 0.0 || tick_size <= 0.0)
      return false;

   double stop = QM_StopStructure(_Symbol, side, entry, MathMax(1, strategy_swing_lookback));
   if(stop > 0.0)
      stop = QM_OrderTypeIsBuy(side) ? (stop - tick_size) : (stop + tick_size);

   if(!Strategy_StopMeetsBrokerDistance(side, entry, stop))
      stop = QM_StopATR(_Symbol, side, entry, MathMax(1, strategy_atr_period), strategy_atr_fallback_mult);

   if(!Strategy_StopMeetsBrokerDistance(side, entry, stop))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, stop);
   req.tp = 0.0;
   req.reason = reason;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

// Return TRUE to close the open position now.
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(!Strategy_SelectOurPosition(ticket, ptype))
      return false;

   const double macd_main_1 = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_signal_1 = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_main_2 = QM_MACD_Main(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_signal_2 = QM_MACD_Signal(_Symbol, strategy_timeframe, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);

   if(ptype == POSITION_TYPE_BUY)
      return (macd_main_2 >= macd_signal_2 && macd_main_1 < macd_signal_1);
   if(ptype == POSITION_TYPE_SELL)
      return (macd_main_2 <= macd_signal_2 && macd_main_1 > macd_signal_1);

   return false;
  }

// Optional news-filter override.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line.
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
