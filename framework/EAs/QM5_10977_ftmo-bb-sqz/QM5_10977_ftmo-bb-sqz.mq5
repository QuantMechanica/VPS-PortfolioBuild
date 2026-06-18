#property strict
#property version   "5.0"
#property description "QM5_10977 ftmo-bb-sqz"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10977;
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
input int    strategy_bb_period             = 20;
input double strategy_bb_deviation          = 2.0;
input int    strategy_squeeze_lookback      = 120;
input double strategy_squeeze_percentile    = 20.0;
input int    strategy_squeeze_recent_bars   = 6;
input int    strategy_atr_period            = 14;
input double strategy_max_range_atr_mult    = 2.5;
input double strategy_stop_atr_buffer_mult  = 0.25;
input double strategy_take_profit_rr        = 2.5;
input double strategy_breakeven_trigger_rr  = 1.2;
input int    strategy_time_exit_bars        = 36;
input int    strategy_spread_median_bars    = 20;
input double strategy_spread_median_mult    = 1.5;

bool Strategy_SelectOwnPosition(ulong &ticket,
                                ENUM_POSITION_TYPE &position_type,
                                double &open_price,
                                double &stop_loss,
                                datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   stop_loss = 0.0;
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

      ticket = pos_ticket;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      stop_loss = PositionGetDouble(POSITION_SL);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double Strategy_BBWidth(const int shift)
  {
   const double upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period,
                                    strategy_bb_deviation, shift, PRICE_TYPICAL);
   const double lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period,
                                    strategy_bb_deviation, shift, PRICE_TYPICAL);
   if(upper <= 0.0 || lower <= 0.0 || upper <= lower)
      return 0.0;
   return upper - lower;
  }

bool Strategy_IsSqueezeAt(const int shift)
  {
   if(strategy_squeeze_lookback <= 0 || strategy_squeeze_percentile <= 0.0)
      return false;

   const double current_width = Strategy_BBWidth(shift);
   if(current_width <= 0.0)
      return false;

   int valid = 0;
   int less_or_equal = 0;
   for(int s = shift + 1; s <= shift + strategy_squeeze_lookback; ++s)
     {
      const double width = Strategy_BBWidth(s);
      if(width <= 0.0)
         continue;
      valid++;
      if(width <= current_width)
         less_or_equal++;
     }

   if(valid <= 0)
      return false;

   const double pct = 100.0 * (double)less_or_equal / (double)valid;
   return (pct <= strategy_squeeze_percentile);
  }

bool Strategy_SqueezeArmed()
  {
   const int bars = MathMax(1, strategy_squeeze_recent_bars);
   for(int s = 1; s <= bars; ++s)
      if(Strategy_IsSqueezeAt(s))
         return true;
   return false;
  }

bool Strategy_SpreadBlocks()
  {
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return false;

   const int lookback = MathMax(1, strategy_spread_median_bars);
   int spreads[];
   ArrayResize(spreads, lookback);

   int count = 0;
   for(int s = 1; s <= lookback; ++s)
     {
      const int bar_spread = (int)iSpread(_Symbol, _Period, s); // perf-allowed: card median-spread filter, bounded to 20 H1 bars.
      if(bar_spread <= 0)
         continue;
      spreads[count] = bar_spread;
      count++;
     }

   if(count <= 0)
      return false;

   for(int i = 0; i < count - 1; ++i)
     {
      for(int j = i + 1; j < count; ++j)
        {
         if(spreads[j] < spreads[i])
           {
            const int tmp = spreads[i];
            spreads[i] = spreads[j];
            spreads[j] = tmp;
           }
        }
     }

   double median = 0.0;
   if((count % 2) == 1)
      median = (double)spreads[count / 2];
   else
      median = ((double)spreads[count / 2 - 1] + (double)spreads[count / 2]) * 0.5;

   if(median <= 0.0)
      return false;
   return ((double)current_spread > strategy_spread_median_mult * median);
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy_SpreadBlocks())
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

   if(strategy_bb_period <= 1 || strategy_atr_period <= 0 ||
      strategy_take_profit_rr <= 0.0 || strategy_squeeze_lookback <= 0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!Strategy_SqueezeArmed())
      return false;

   const double upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period,
                                    strategy_bb_deviation, 1, PRICE_TYPICAL);
   const double lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period,
                                    strategy_bb_deviation, 1, PRICE_TYPICAL);
   const double middle = QM_BB_Middle(_Symbol, _Period, strategy_bb_period,
                                      strategy_bb_deviation, 1, PRICE_TYPICAL);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(upper <= 0.0 || lower <= 0.0 || middle <= 0.0 || atr <= 0.0)
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar breakout close.
   const double high_1 = iHigh(_Symbol, _Period, 1);   // perf-allowed: single closed-bar range.
   const double low_1 = iLow(_Symbol, _Period, 1);     // perf-allowed: single closed-bar range.
   if(close_1 <= 0.0 || high_1 <= 0.0 || low_1 <= 0.0)
      return false;

   if((high_1 - low_1) > strategy_max_range_atr_mult * atr)
      return false;

   const bool long_signal = (close_1 > upper && close_1 > middle);
   const bool short_signal = (close_1 < lower && close_1 < middle);
   if(!long_signal && !short_signal)
      return false;

   if(long_signal)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, lower - strategy_stop_atr_buffer_mult * atr);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_take_profit_rr);
      if(tp <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "ftmo_bb_sqz_long";
      return true;
     }

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   const double sl = QM_StopRulesNormalizePrice(_Symbol, upper + strategy_stop_atr_buffer_mult * atr);
   if(sl <= 0.0 || sl <= entry)
      return false;
   const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_take_profit_rr);
   if(tp <= 0.0)
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "ftmo_bb_sqz_short";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   double stop_loss;
   datetime open_time;
   if(!Strategy_SelectOwnPosition(ticket, position_type, open_price, stop_loss, open_time))
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || open_price <= 0.0 || stop_loss <= 0.0)
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   if(is_buy && stop_loss >= open_price - point * 0.5)
      return;
   if(!is_buy && stop_loss <= open_price + point * 0.5)
      return;

   const double risk = MathAbs(open_price - stop_loss);
   if(risk <= point)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   const double trigger = strategy_breakeven_trigger_rr * risk;
   const bool trigger_hit = is_buy ? ((bid - open_price) >= trigger)
                                   : ((open_price - ask) >= trigger);
   if(!trigger_hit)
      return;

   QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, open_price), "ftmo_bb_sqz_breakeven");
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   double stop_loss;
   datetime open_time;
   if(!Strategy_SelectOwnPosition(ticket, position_type, open_price, stop_loss, open_time))
      return false;

   const double middle = QM_BB_Middle(_Symbol, _Period, strategy_bb_period,
                                      strategy_bb_deviation, 1, PRICE_TYPICAL);
   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar SMA re-entry exit.
   if(middle > 0.0 && close_1 > 0.0)
     {
      if(position_type == POSITION_TYPE_BUY && close_1 < middle)
         return true;
      if(position_type == POSITION_TYPE_SELL && close_1 > middle)
         return true;
     }

   const int seconds_per_bar = PeriodSeconds(_Period);
   if(open_time > 0 && seconds_per_bar > 0 && strategy_time_exit_bars > 0)
     {
      const long elapsed_bars = (long)((TimeCurrent() - open_time) / seconds_per_bar);
      if(elapsed_bars >= strategy_time_exit_bars)
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
