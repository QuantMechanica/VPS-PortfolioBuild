#property strict
#property version   "5.0"
#property description "QM5_10302 Narang Price Deviation Reversion"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10302;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input int    strategy_mean_lookback       = 48;
input int    strategy_atr_period          = 24;
input double strategy_deviation_threshold = 1.5;
input double strategy_long_reject_frac    = 0.35;
input double strategy_short_reject_frac   = 0.65;
input int    strategy_slope_lookback      = 96;
input int    strategy_slope_bars          = 24;
input double strategy_slope_atr_mult      = 0.75;
input double strategy_stop_atr_mult       = 1.25;
input int    strategy_time_stop_bars      = 24;
input double strategy_emergency_atr_mult  = 2.5;
input int    strategy_atr_percentile_lookback = 500;
input double strategy_atr_percentile_rank = 20.0;
input int    strategy_max_spread_points   = 0;

bool Strategy_ReadClosedH1Bar(MqlRates &bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, 1, rates); // perf-allowed: one closed H1 OHLC bar only; entry is called after the framework new-bar gate.
   if(copied != 1)
      return false;
   bar = rates[0];
   return true;
  }

bool Strategy_IsWeekendOpenBar(const datetime bar_time)
  {
   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   if(dt.day_of_week == 0)
      return true;
   if(dt.day_of_week == 1 && dt.hour == 0)
      return true;
   return false;
  }

bool Strategy_GetOurPosition(int &direction, ulong &ticket, datetime &open_time)
  {
   direction = 0;
   ticket = 0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      direction = (type == POSITION_TYPE_BUY) ? 1 : -1;
      ticket = pos_ticket;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_ATRPercentileAllows(const double current_atr)
  {
   if(current_atr <= 0.0)
      return false;
   if(strategy_atr_percentile_lookback <= 0 || strategy_atr_percentile_rank <= 0.0)
      return true;

   const int lookback = MathMin(strategy_atr_percentile_lookback, 1000);
   double samples[];
   ArrayResize(samples, lookback);

   int count = 0;
   for(int shift = 2; shift < 2 + lookback; ++shift)
     {
      const double value = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, shift);
      if(value <= 0.0)
         continue;
      samples[count] = value;
      count++;
     }

   if(count < MathMin(50, lookback))
      return false;

   ArrayResize(samples, count);
   ArraySort(samples);
   int rank_index = (int)MathFloor((strategy_atr_percentile_rank / 100.0) * (double)(count - 1));
   if(rank_index < 0)
      rank_index = 0;
   if(rank_index >= count)
      rank_index = count - 1;

   return (current_atr >= samples[rank_index]);
  }

bool Strategy_SlopeAllows(const double current_atr)
  {
   if(strategy_slope_lookback <= 1 || strategy_slope_bars <= 0 || strategy_slope_atr_mult < 0.0)
      return false;
   const double sma_now = QM_SMA(_Symbol, PERIOD_H1, strategy_slope_lookback, 1);
   const double sma_then = QM_SMA(_Symbol, PERIOD_H1, strategy_slope_lookback, 1 + strategy_slope_bars);
   if(sma_now <= 0.0 || sma_then <= 0.0 || current_atr <= 0.0)
      return false;
   return (MathAbs(sma_now - sma_then) < strategy_slope_atr_mult * current_atr);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
      return true;
   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }
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

   if(strategy_mean_lookback <= 1 || strategy_atr_period <= 0 ||
      strategy_deviation_threshold <= 0.0 || strategy_stop_atr_mult <= 0.0)
      return false;

   int position_direction = 0;
   ulong ticket = 0;
   datetime open_time = 0;
   if(Strategy_GetOurPosition(position_direction, ticket, open_time))
      return false;

   MqlRates bar;
   if(!Strategy_ReadClosedH1Bar(bar))
      return false;
   if(Strategy_IsWeekendOpenBar(bar.time))
      return false;

   const double range = bar.high - bar.low;
   if(bar.close <= 0.0 || bar.high <= 0.0 || bar.low <= 0.0 || range <= 0.0)
      return false;

   const double sma = QM_SMA(_Symbol, PERIOD_H1, strategy_mean_lookback, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(sma <= 0.0 || atr <= 0.0)
      return false;
   if(!Strategy_ATRPercentileAllows(atr))
      return false;
   if(!Strategy_SlopeAllows(atr))
      return false;

   const double deviation = (bar.close - sma) / atr;
   const bool long_rejection = (bar.close > bar.low + strategy_long_reject_frac * range);
   const bool short_rejection = (bar.close < bar.low + strategy_short_reject_frac * range);

   if(deviation <= -strategy_deviation_threshold && long_rejection)
     {
      req.type = QM_BUY;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.reason = "NARANG_PRICE_REVERT_LONG";
     }
   else if(deviation >= strategy_deviation_threshold && short_rejection)
     {
      req.type = QM_SELL;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.reason = "NARANG_PRICE_REVERT_SHORT";
     }
   else
      return false;

   if(req.price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr, strategy_stop_atr_mult);
   req.tp = 0.0;
   if(req.sl <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double sl_points = MathAbs(req.price - req.sl) / point;
   const int min_stop_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(min_stop_points > 0 && sl_points < (double)min_stop_points)
      return false;
   if(QM_LotsForRisk(_Symbol, sl_points) <= 0.0)
      return false;

   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even rule.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   int direction = 0;
   ulong ticket = 0;
   datetime open_time = 0;
   if(!Strategy_GetOurPosition(direction, ticket, open_time))
      return false;

   const int h1_seconds = PeriodSeconds(PERIOD_H1);
   if(strategy_time_stop_bars > 0 && h1_seconds > 0 && open_time > 0)
     {
      const int bars_held = (int)((TimeCurrent() - open_time) / h1_seconds);
      if(bars_held >= strategy_time_stop_bars)
         return true;
     }

   MqlRates bar;
   if(!Strategy_ReadClosedH1Bar(bar))
      return false;

   const double sma = QM_SMA(_Symbol, PERIOD_H1, strategy_mean_lookback, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(sma <= 0.0 || atr <= 0.0 || bar.close <= 0.0)
      return false;

   if(direction > 0)
     {
      if(bar.close >= sma)
         return true;
      if(bar.close <= sma - strategy_emergency_atr_mult * atr)
         return true;
     }
   else if(direction < 0)
     {
      if(bar.close <= sma)
         return true;
      if(bar.close >= sma + strategy_emergency_atr_mult * atr)
         return true;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
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
                        60,
                        60,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10302_narang-price-revert\"}");
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
