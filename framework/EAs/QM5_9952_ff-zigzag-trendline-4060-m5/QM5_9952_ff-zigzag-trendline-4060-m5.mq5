#property strict
#property version   "5.0"
#property description "QM5_9952 ForexFactory ZigZag Trendline 40-60 M5"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9952;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_M5;
input int    strategy_zigzag_depth                = 12;
input int    strategy_zigzag_deviation_pips       = 5;
input int    strategy_zigzag_backstep             = 3;
input int    strategy_zigzag_scan_bars            = 240;
input int    strategy_trendline_lookback          = 14;
input int    strategy_trendline_projection_bars   = 10;
input int    strategy_atr_period                  = 14;
input double strategy_breach_atr_mult             = 0.10;
input int    strategy_xau_swing_min_pips          = 100;
input double strategy_fx_swing_atr_mult           = 2.50;
input int    strategy_sl_pips                     = 40;
input int    strategy_tp_pips                     = 60;
input double strategy_sl_atr_fallback_mult        = 1.25;
input int    strategy_be_trigger_pips             = 40;
input int    strategy_be_buffer_pips              = 0;
input int    strategy_time_stop_bars              = 36;
input int    strategy_session_start_hour          = 7;
input int    strategy_session_end_hour            = 18;
input int    strategy_max_spread_points           = 0;

struct ZZPivot
  {
   int      type;       // 1 high, -1 low
   int      index;      // CopyRates series index, 0 = last closed bar
   datetime time;
   double   price;
  };

datetime g_consumed_swing_start_time = 0;
datetime g_consumed_swing_end_time = 0;
int      g_consumed_swing_direction = 0;

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

double Strategy_PipDistance(const string symbol)
  {
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return point * pip_factor;
  }

double Strategy_NormalizePrice(const string symbol, const double price)
  {
   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

bool Strategy_IsXau(const string symbol)
  {
   return (StringFind(symbol, "XAUUSD") == 0);
  }

bool Strategy_HasOpenPosition()
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
      return true;
     }

   return false;
  }

bool Strategy_IsPivotHigh(MqlRates &rates[], const int index, const int depth)
  {
   const double v = rates[index].high;
   if(v <= 0.0)
      return false;
   for(int j = index - depth; j <= index + depth; ++j)
     {
      if(j == index)
         continue;
      if(rates[j].high > v)
         return false;
     }
   return true;
  }

bool Strategy_IsPivotLow(MqlRates &rates[], const int index, const int depth)
  {
   const double v = rates[index].low;
   if(v <= 0.0)
      return false;
   for(int j = index - depth; j <= index + depth; ++j)
     {
      if(j == index)
         continue;
      if(rates[j].low < v)
         return false;
     }
   return true;
  }

void Strategy_AddPivot(ZZPivot &pivots[],
                       int &count,
                       const int type,
                       const int index,
                       const datetime time,
                       const double price,
                       const double min_deviation,
                       const int backstep)
  {
   if(count <= 0)
     {
      pivots[0].type = type;
      pivots[0].index = index;
      pivots[0].time = time;
      pivots[0].price = price;
      count = 1;
      return;
     }

   ZZPivot prev = pivots[count - 1];
   if(prev.type == type)
     {
      const bool replace_high = (type == 1 && price > prev.price);
      const bool replace_low = (type == -1 && price < prev.price);
      if((MathAbs(index - prev.index) <= backstep && (replace_high || replace_low)) ||
         (MathAbs(index - prev.index) > backstep && (replace_high || replace_low)))
        {
         pivots[count - 1].index = index;
         pivots[count - 1].time = time;
         pivots[count - 1].price = price;
        }
      return;
     }

   if(MathAbs(price - prev.price) < min_deviation)
      return;
   if(count >= 128)
      return;

   pivots[count].type = type;
   pivots[count].index = index;
   pivots[count].time = time;
   pivots[count].price = price;
   count++;
  }

bool Strategy_FindRecentSwing(MqlRates &rates[],
                              const int copied,
                              ZZPivot &p1,
                              ZZPivot &p2)
  {
   const int depth = MathMax(2, strategy_zigzag_depth);
   const int backstep = MathMax(1, strategy_zigzag_backstep);
   const double min_deviation = Strategy_PipDistance(_Symbol) * MathMax(1, strategy_zigzag_deviation_pips);
   if(copied < (depth * 2 + strategy_trendline_lookback + 5) || min_deviation <= 0.0)
      return false;

   ZZPivot pivots[128];
   int count = 0;
   for(int i = copied - depth - 1; i >= depth; --i)
     {
      const bool is_high = Strategy_IsPivotHigh(rates, i, depth);
      const bool is_low = Strategy_IsPivotLow(rates, i, depth);
      if(is_high && is_low)
         continue;
      if(is_high)
         Strategy_AddPivot(pivots, count, 1, i, rates[i].time, rates[i].high, min_deviation, backstep);
      else if(is_low)
         Strategy_AddPivot(pivots, count, -1, i, rates[i].time, rates[i].low, min_deviation, backstep);
     }

   if(count < 2)
      return false;

   p1 = pivots[count - 2];
   p2 = pivots[count - 1];
   return (p1.type != p2.type && p1.index > p2.index);
  }

bool Strategy_LineFromRecentCloses(MqlRates &rates[],
                                   const int p2_index,
                                   double &line_now,
                                   double &slope)
  {
   line_now = 0.0;
   slope = 0.0;

   const int n = MathMax(3, strategy_trendline_lookback);
   if(p2_index < n)
      return false;

   double sx = 0.0;
   double sy = 0.0;
   double sxx = 0.0;
   double sxy = 0.0;
   for(int k = 0; k < n; ++k)
     {
      const int rate_index = n - 1 - k;
      const double x = (double)k;
      const double y = rates[rate_index].close;
      sx += x;
      sy += y;
      sxx += x * x;
      sxy += x * y;
     }

   const double denom = (n * sxx) - (sx * sx);
   if(MathAbs(denom) <= DBL_EPSILON)
      return false;

   slope = ((n * sxy) - (sx * sy)) / denom;
   const double intercept = (sy - slope * sx) / n;
   line_now = intercept + slope * (double)(n - 1);
   return (line_now > 0.0);
  }

double Strategy_SwingThreshold(const double atr_value)
  {
   if(Strategy_IsXau(_Symbol))
      return Strategy_PipDistance(_Symbol) * strategy_xau_swing_min_pips;
   return atr_value * strategy_fx_swing_atr_mult;
  }

bool Strategy_BuildMarketRequest(QM_EntryRequest &req,
                                 const QM_OrderType side,
                                 const double entry,
                                 const double atr_value,
                                 const string reason)
  {
   const double pip = Strategy_PipDistance(_Symbol);
   if(entry <= 0.0 || atr_value <= 0.0 || pip <= 0.0)
      return false;

   double stop_dist = pip * strategy_sl_pips;
   if(stop_dist <= 0.0)
      stop_dist = atr_value * strategy_sl_atr_fallback_mult;
   const double take_dist = pip * strategy_tp_pips;
   if(stop_dist <= 0.0 || take_dist <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   if(QM_OrderTypeIsBuy(side))
     {
      req.sl = Strategy_NormalizePrice(_Symbol, entry - stop_dist);
      req.tp = Strategy_NormalizePrice(_Symbol, entry + take_dist);
     }
   else
     {
      req.sl = Strategy_NormalizePrice(_Symbol, entry + stop_dist);
      req.tp = Strategy_NormalizePrice(_Symbol, entry - take_dist);
     }
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return (req.sl > 0.0 && req.tp > 0.0);
  }

bool Strategy_NoTradeFilter()
  {
   const int hhmm = Strategy_Hhmm(TimeCurrent());
   const int start_hhmm = strategy_session_start_hour * 100;
   const int end_hhmm = strategy_session_end_hour * 100;
   if(hhmm < start_hhmm || hhmm >= end_hhmm)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

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

   if(Strategy_HasOpenPosition())
      return false;

   const int lookback = MathMax(strategy_zigzag_scan_bars,
                                strategy_zigzag_depth * 2 + strategy_trendline_lookback + 10);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, lookback, rates); // perf-allowed: bespoke ZigZag/trendline structure; Strategy_EntrySignal is called only after QM_IsNewBar().
   if(copied < lookback / 2)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   ZZPivot p1;
   ZZPivot p2;
   if(!Strategy_FindRecentSwing(rates, copied, p1, p2))
      return false;

   const int direction = (p1.type == 1 && p2.type == -1) ? 1 : ((p1.type == -1 && p2.type == 1) ? -1 : 0);
   if(direction == 0)
      return false;
   if(g_consumed_swing_direction == direction &&
      g_consumed_swing_start_time == p1.time &&
      g_consumed_swing_end_time == p2.time)
      return false;

   const double swing_length = MathAbs(p1.price - p2.price);
   const double threshold = Strategy_SwingThreshold(atr);
   if(threshold <= 0.0 || swing_length < threshold)
      return false;

   double line_now = 0.0;
   double slope = 0.0;
   if(!Strategy_LineFromRecentCloses(rates, p2.index, line_now, slope))
      return false;

   const double breach = atr * strategy_breach_atr_mult;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || breach <= 0.0)
      return false;

   if(direction == 1 && slope < 0.0 && rates[0].high >= line_now + breach)
     {
      if(!Strategy_BuildMarketRequest(req, QM_BUY, ask, atr, "ZZ_TRENDLINE_LONG"))
         return false;
      g_consumed_swing_start_time = p1.time;
      g_consumed_swing_end_time = p2.time;
      g_consumed_swing_direction = direction;
      return true;
     }

   if(direction == -1 && slope > 0.0 && rates[0].low <= line_now - breach)
     {
      if(!Strategy_BuildMarketRequest(req, QM_SELL, bid, atr, "ZZ_TRENDLINE_SHORT"))
         return false;
      g_consumed_swing_start_time = p1.time;
      g_consumed_swing_end_time = p2.time;
      g_consumed_swing_direction = direction;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_MoveToBreakEven(ticket, strategy_be_trigger_pips, strategy_be_buffer_pips);
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int seconds = PeriodSeconds(strategy_signal_tf);
   if(seconds <= 0 || strategy_time_stop_bars <= 0)
      return false;

   const datetime now = TimeCurrent();
   const int max_hold_seconds = seconds * strategy_time_stop_bars;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= max_hold_seconds)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9952\",\"ea\":\"ff-zigzag-trendline-4060-m5\"}");
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

   if(!QM_IsNewBar(_Symbol, strategy_signal_tf))
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
