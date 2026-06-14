#property strict
#property version   "5.0"
#property description "QM5_1066 Carver EWMAC Vol-Normalised Trend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1066;
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
input int    strategy_ewmac_fast          = 16;
input int    strategy_ewmac_slow          = 64;
input int    strategy_vol_span            = 25;
input double strategy_entry_forecast      = 2.0;
input double strategy_exit_long_forecast  = 0.0;
input double strategy_exit_short_forecast = 0.0;
input double strategy_forecast_cap        = 20.0;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 2.5;
input bool   strategy_spread_filter       = true;
input int    strategy_spread_days         = 20;
input double strategy_spread_mult         = 2.0;
input int    strategy_index_start_hour    = 8;
input int    strategy_index_end_hour      = 22;

double EWMACScalar(const int fast, const int slow)
  {
   if(fast == 2 && slow == 8)
      return 10.6;
   if(fast == 4 && slow == 16)
      return 7.5;
   if(fast == 8 && slow == 32)
      return 5.3;
   if(fast == 16 && slow == 64)
      return 3.75;
   if(fast == 32 && slow == 128)
      return 2.65;
   if(fast == 64 && slow == 256)
      return 1.87;
   return 1.0;
  }

bool IsIndexSymbol()
  {
   return (StringFind(_Symbol, "GDAXI") >= 0 ||
           StringFind(_Symbol, "GER40") >= 0 ||
           StringFind(_Symbol, "NDX") >= 0 ||
           StringFind(_Symbol, "WS30") >= 0 ||
           StringFind(_Symbol, "SP500") >= 0);
  }

bool InsideIndexSession()
  {
   if(!IsIndexSymbol())
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int hour = dt.hour;
   if(strategy_index_start_hour == strategy_index_end_hour)
      return true;
   if(strategy_index_start_hour < strategy_index_end_hour)
      return (hour >= strategy_index_start_hour && hour < strategy_index_end_hour);
   return (hour >= strategy_index_start_hour || hour < strategy_index_end_hour);
  }

double CurrentSpreadPoints()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return 0.0;
   return (ask - bid) / point;
  }

double MedianSpreadPoints(const int days)
  {
   if(days <= 0)
      return 0.0;

   int spreads[];
   ArraySetAsSeries(spreads, true);
   const int copied = CopySpread(_Symbol, PERIOD_D1, 1, days, spreads); // perf-allowed: closed-bar spread sample for card spread filter.
   if(copied <= 0)
      return 0.0;

   for(int i = 0; i < copied - 1; ++i)
     {
      for(int j = i + 1; j < copied; ++j)
        {
         if(spreads[j] < spreads[i])
           {
            const int tmp = spreads[i];
            spreads[i] = spreads[j];
            spreads[j] = tmp;
           }
        }
     }

   const int mid = copied / 2;
   if((copied % 2) == 1)
      return (double)spreads[mid];
   return ((double)spreads[mid - 1] + (double)spreads[mid]) * 0.5;
  }

bool SpreadAllowsEntry()
  {
   if(!strategy_spread_filter)
      return true;

   const double current = CurrentSpreadPoints();
   const double median = MedianSpreadPoints(strategy_spread_days);
   if(current <= 0.0 || median <= 0.0)
      return true;
   return (current <= median * strategy_spread_mult);
  }

double EWMAVolatility(const int span, const int shift)
  {
   if(span <= 1 || shift < 1)
      return 0.0;

   const int lookback = MathMax(span * 6, span + 5);
   const double alpha = 2.0 / ((double)span + 1.0);
   double mean = 0.0;
   double variance = 0.0;
   bool seeded = false;

   for(int k = lookback; k >= 0; --k)
     {
      const int bar_shift = shift + k;
      const double c0 = iClose(_Symbol, PERIOD_D1, bar_shift);     // perf-allowed: bounded EWMA return-volatility sample, called only by strategy forecast.
      const double c1 = iClose(_Symbol, PERIOD_D1, bar_shift + 1); // perf-allowed: bounded EWMA return-volatility sample, called only by strategy forecast.
      if(c0 <= 0.0 || c1 <= 0.0)
         continue;

      const double ret = c0 - c1;
      if(!seeded)
        {
         mean = ret;
         variance = 0.0;
         seeded = true;
         continue;
        }

      const double delta = ret - mean;
      mean += alpha * delta;
      variance = (1.0 - alpha) * (variance + alpha * delta * delta);
     }

   if(!seeded || variance <= 0.0)
      return 0.0;
   return MathSqrt(variance);
  }

double ForecastAtShift(const int shift)
  {
   if(strategy_ewmac_fast <= 0 ||
      strategy_ewmac_slow <= strategy_ewmac_fast ||
      strategy_vol_span <= 1 ||
      strategy_forecast_cap <= 0.0)
      return 0.0;

   const double fast = QM_EMA(_Symbol, PERIOD_D1, strategy_ewmac_fast, shift);
   const double slow = QM_EMA(_Symbol, PERIOD_D1, strategy_ewmac_slow, shift);
   const double vol = EWMAVolatility(strategy_vol_span, shift);
   if(fast <= 0.0 || slow <= 0.0 || vol <= 0.0)
      return 0.0;

   double forecast = EWMACScalar(strategy_ewmac_fast, strategy_ewmac_slow) * (fast - slow) / vol;
   if(forecast > strategy_forecast_cap)
      forecast = strategy_forecast_cap;
   if(forecast < -strategy_forecast_cap)
      forecast = -strategy_forecast_cap;
   return forecast;
  }

bool SelectOurPosition(ENUM_POSITION_TYPE &ptype)
  {
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
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

   if(!InsideIndexSession() || !SpreadAllowsEntry())
      return false;

   ENUM_POSITION_TYPE existing_type;
   if(SelectOurPosition(existing_type))
      return false;

   const double forecast = ForecastAtShift(1);
   if(forecast > strategy_entry_forecast)
      req.type = QM_BUY;
   else if(forecast < -strategy_entry_forecast)
      req.type = QM_SELL;
   else
      return false;

   req.price = 0.0;
   const double entry = (req.type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.tp = 0.0;
   req.reason = StringFormat("EWMAC forecast=%.4f fast=%d slow=%d", forecast, strategy_ewmac_fast, strategy_ewmac_slow);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!SelectOurPosition(ptype))
      return false;

   const double forecast = ForecastAtShift(1);
   if(ptype == POSITION_TYPE_BUY && forecast < strategy_exit_long_forecast)
      return true;
   if(ptype == POSITION_TYPE_SELL && forecast > strategy_exit_short_forecast)
      return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1066_carver-ewmac-trend\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

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
