#property strict
#property version   "5.0"
#property description "QM5_10927 Grimes PowerPush Opening Rejection"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10927;
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
input int    strategy_atr_period              = 20;
input double strategy_level_near_atr_mult     = 0.50;
input double strategy_or_violation_atr_mult   = 0.20;
input int    strategy_opening_range_bars      = 4;
input int    strategy_session_minutes         = 90;
input double strategy_breakout_atr_mult       = 0.10;
input double strategy_stop_buffer_atr_mult    = 0.20;
input double strategy_max_or_atr_mult         = 2.50;
input double strategy_tp_rr                   = 2.00;
input double strategy_be_trigger_rr           = 1.00;
input double strategy_early_exit_rr           = 0.50;
input double strategy_spread_stop_fraction    = 0.10;
input int    strategy_h1_pivot_lookback       = 96;
input int    strategy_close_before_day_bars   = 2;

bool g_strategy_reached_half_r = false;
bool g_strategy_exit_due = false;
int  g_strategy_last_trade_ymd = 0;

int StrategyYmd(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime StrategyDayStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

double StrategyNormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return QM_StopRulesNormalizePrice(_Symbol, price);
  }

void StrategyInitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool StrategySelectPosition(ENUM_POSITION_TYPE &ptype,
                            double &open_price,
                            double &sl,
                            double &tp,
                            ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   tp = 0.0;
   ticket = 0;

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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      ticket = t;
      return true;
     }

   return false;
  }

double StrategyInitialRisk(const double open_price, const double sl, const double tp)
  {
   if(open_price <= 0.0)
      return 0.0;
   if(tp > 0.0)
      return MathAbs(tp - open_price) / MathMax(strategy_tp_rr, 1.0);
   if(sl > 0.0)
      return MathAbs(open_price - sl);
   return 0.0;
  }

bool StrategyLoadOpeningRange(const datetime day_start,
                              const double atr,
                              double &session_open,
                              double &or_high,
                              double &or_low,
                              bool &long_or_valid,
                              bool &short_or_valid,
                              const double support,
                              const double resistance,
                              double &last_closed_m15_close)
  {
   session_open = 0.0;
   or_high = -DBL_MAX;
   or_low = DBL_MAX;
   long_or_valid = true;
   short_or_valid = true;
   last_closed_m15_close = 0.0;

   if(atr <= 0.0 || strategy_opening_range_bars < 1)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int period_seconds = PeriodSeconds(PERIOD_M15);
   const int elapsed_bars = (period_seconds > 0) ? (int)((TimeCurrent() - day_start) / period_seconds) + 2 : 12;
   const int need_bars = MathMax(strategy_opening_range_bars + 8, MathMin(elapsed_bars + 4, 120));
   const int copied = CopyRates(_Symbol, PERIOD_M15, 0, need_bars, rates); // perf-allowed: bounded closed-bar opening-range scan.
   if(copied < strategy_opening_range_bars + 1)
      return false;

   if(rates[1].tick_volume <= 0)
      return false;
   last_closed_m15_close = rates[1].close;

   const datetime range_end = day_start + strategy_opening_range_bars * PeriodSeconds(PERIOD_M15);
   int range_count = 0;
   datetime first_time = LONG_MAX;

   for(int i = 1; i < copied; ++i)
     {
      if(rates[i].time < day_start || rates[i].time >= range_end)
         continue;
      if(rates[i].tick_volume <= 0)
         return false;

      if(rates[i].time < first_time)
        {
         first_time = rates[i].time;
         session_open = rates[i].open;
        }

      or_high = MathMax(or_high, rates[i].high);
      or_low = MathMin(or_low, rates[i].low);

      if(support > 0.0 && rates[i].close < support - strategy_or_violation_atr_mult * atr)
         long_or_valid = false;
      if(resistance > 0.0 && rates[i].close > resistance + strategy_or_violation_atr_mult * atr)
         short_or_valid = false;

      range_count++;
     }

   if(range_count != strategy_opening_range_bars)
      return false;
   if(session_open <= 0.0 || or_high <= 0.0 || or_low <= 0.0 || or_high <= or_low)
      return false;

   return true;
  }

double StrategyPreviousDayLow()
  {
   return iLow(_Symbol, PERIOD_D1, 1); // perf-allowed: single previous-D1 support read for card level definition.
  }

double StrategyPreviousDayHigh()
  {
   return iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: single previous-D1 resistance read for card level definition.
  }

bool StrategyFindNearestH1Pivots(const double reference_price,
                                 double &pivot_low,
                                 double &pivot_high)
  {
   pivot_low = 0.0;
   pivot_high = 0.0;
   if(reference_price <= 0.0 || strategy_h1_pivot_lookback < 8)
      return false;

   MqlRates h1[];
   ArraySetAsSeries(h1, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 0, strategy_h1_pivot_lookback, h1); // perf-allowed: bounded closed-bar H1 pivot scan.
   if(copied < 8)
      return false;

   double low_dist = DBL_MAX;
   double high_dist = DBL_MAX;

   for(int s = 3; s <= copied - 3; ++s)
     {
      const double lo = h1[s].low;
      const double hi = h1[s].high;
      if(lo <= 0.0 || hi <= 0.0 || h1[s].tick_volume <= 0)
         continue;

      const bool is_pivot_low =
         lo <= h1[s - 1].low && lo <= h1[s - 2].low &&
         lo <= h1[s + 1].low && lo <= h1[s + 2].low;
      if(is_pivot_low)
        {
         const double d = MathAbs(reference_price - lo);
         if(d < low_dist)
           {
            low_dist = d;
            pivot_low = lo;
           }
        }

      const bool is_pivot_high =
         hi >= h1[s - 1].high && hi >= h1[s - 2].high &&
         hi >= h1[s + 1].high && hi >= h1[s + 2].high;
      if(is_pivot_high)
        {
         const double d = MathAbs(reference_price - hi);
         if(d < high_dist)
           {
            high_dist = d;
            pivot_high = hi;
           }
        }
     }

   return (pivot_low > 0.0 || pivot_high > 0.0);
  }

double StrategyNearestLevel(const double reference_price,
                            const double level_a,
                            const double level_b)
  {
   if(level_a <= 0.0)
      return level_b;
   if(level_b <= 0.0)
      return level_a;
   return (MathAbs(reference_price - level_a) <= MathAbs(reference_price - level_b)) ? level_a : level_b;
  }

bool StrategyBuildEntry(const bool want_long,
                        const double atr,
                        const double or_high,
                        const double or_low,
                        QM_EntryRequest &req)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || atr <= 0.0)
      return false;

   const QM_OrderType side = want_long ? QM_BUY : QM_SELL;
   const double entry = want_long ? ask : bid;
   const double raw_sl = want_long ? (or_low - strategy_stop_buffer_atr_mult * atr)
                                   : (or_high + strategy_stop_buffer_atr_mult * atr);
   const double sl = StrategyNormalizePrice(raw_sl);
   if(sl <= 0.0)
      return false;
   if(want_long && sl >= entry)
      return false;
   if(!want_long && sl <= entry)
      return false;

   const double stop_distance = MathAbs(entry - sl);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(strategy_spread_stop_fraction > 0.0 && spread > strategy_spread_stop_fraction * stop_distance)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = want_long ? "GRIMES_POWERPUSH_LONG" : "GRIMES_POWERPUSH_SHORT";
   return true;
  }

void StrategyUpdateExitState()
  {
   g_strategy_exit_due = false;

   ENUM_POSITION_TYPE ptype;
   double open_price;
   double sl;
   double tp;
   ulong ticket;
   if(!StrategySelectPosition(ptype, open_price, sl, tp, ticket))
     {
      g_strategy_reached_half_r = false;
      return;
     }

   const datetime now = TimeCurrent();
   const datetime day_start = StrategyDayStart(now);
   const int day_seconds = 24 * 60 * 60;
   const int close_seconds = strategy_close_before_day_bars * PeriodSeconds(PERIOD_M15);
   if(strategy_close_before_day_bars > 0 && now >= day_start + day_seconds - close_seconds)
     {
      g_strategy_exit_due = true;
      return;
     }

   if(!g_strategy_reached_half_r)
      return;

   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   const double prev_low = StrategyPreviousDayLow();
   const double prev_high = StrategyPreviousDayHigh();
   double pivot_low = 0.0;
   double pivot_high = 0.0;
   StrategyFindNearestH1Pivots(open_price, pivot_low, pivot_high);

   const double support = StrategyNearestLevel(open_price, prev_low, pivot_low);
   const double resistance = StrategyNearestLevel(open_price, prev_high, pivot_high);

   double session_open = 0.0;
   double or_high = 0.0;
   double or_low = 0.0;
   bool long_or_valid = true;
   bool short_or_valid = true;
   double last_close = 0.0;
   if(!StrategyLoadOpeningRange(day_start, atr, session_open, or_high, or_low,
                                long_or_valid, short_or_valid, support, resistance, last_close))
      return;

   if(last_close > or_low && last_close < or_high)
      g_strategy_exit_due = true;
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask <= 0.0 || bid <= 0.0 || ask < bid);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   StrategyInitRequest(req);
   StrategyUpdateExitState();

   ENUM_POSITION_TYPE ptype;
   double open_price;
   double sl;
   double tp;
   ulong ticket;
   if(StrategySelectPosition(ptype, open_price, sl, tp, ticket))
      return false;

   if(strategy_atr_period < 2 || strategy_level_near_atr_mult <= 0.0 ||
      strategy_or_violation_atr_mult < 0.0 || strategy_opening_range_bars != 4 ||
      strategy_session_minutes < 60 || strategy_breakout_atr_mult < 0.0 ||
      strategy_stop_buffer_atr_mult < 0.0 || strategy_max_or_atr_mult <= 0.0 ||
      strategy_tp_rr <= 0.0 || strategy_spread_stop_fraction < 0.0)
      return false;

   const datetime now = TimeCurrent();
   const datetime day_start = StrategyDayStart(now);
   const int seconds_since_open = (int)(now - day_start);
   const int min_ready_seconds = strategy_opening_range_bars * PeriodSeconds(PERIOD_M15);
   if(seconds_since_open < min_ready_seconds || seconds_since_open > strategy_session_minutes * 60)
      return false;

   const int today = StrategyYmd(now);
   if(g_strategy_last_trade_ymd == today)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double prev_low = StrategyPreviousDayLow();
   const double prev_high = StrategyPreviousDayHigh();
   double pivot_low = 0.0;
   double pivot_high = 0.0;
   StrategyFindNearestH1Pivots(SymbolInfoDouble(_Symbol, SYMBOL_BID), pivot_low, pivot_high);

   double session_open = 0.0;
   double or_high = 0.0;
   double or_low = 0.0;
   bool long_or_valid = true;
   bool short_or_valid = true;
   double last_close = 0.0;

   const double preliminary_support = StrategyNearestLevel(SymbolInfoDouble(_Symbol, SYMBOL_BID), prev_low, pivot_low);
   const double preliminary_resistance = StrategyNearestLevel(SymbolInfoDouble(_Symbol, SYMBOL_BID), prev_high, pivot_high);
   if(!StrategyLoadOpeningRange(day_start, atr, session_open, or_high, or_low,
                                long_or_valid, short_or_valid,
                                preliminary_support, preliminary_resistance, last_close))
      return false;

   const double support = StrategyNearestLevel(session_open, prev_low, pivot_low);
   const double resistance = StrategyNearestLevel(session_open, prev_high, pivot_high);
   if(support <= 0.0 || resistance <= 0.0)
      return false;

   const double or_height = or_high - or_low;
   if(or_height <= 0.0 || or_height > strategy_max_or_atr_mult * atr)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   const bool long_near_support = (MathAbs(session_open - support) <= strategy_level_near_atr_mult * atr);
   const bool short_near_resistance = (MathAbs(session_open - resistance) <= strategy_level_near_atr_mult * atr);
   const bool long_break = (ask > or_high + strategy_breakout_atr_mult * atr);
   const bool short_break = (bid < or_low - strategy_breakout_atr_mult * atr);

   if(long_near_support && long_or_valid && long_break)
     {
      if(StrategyBuildEntry(true, atr, or_high, or_low, req))
        {
         g_strategy_last_trade_ymd = today;
         return true;
        }
     }

   if(short_near_resistance && short_or_valid && short_break)
     {
      if(StrategyBuildEntry(false, atr, or_high, or_low, req))
        {
         g_strategy_last_trade_ymd = today;
         return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   double open_price;
   double sl;
   double tp;
   ulong ticket;
   if(!StrategySelectPosition(ptype, open_price, sl, tp, ticket))
     {
      g_strategy_reached_half_r = false;
      return;
     }

   const double risk = StrategyInitialRisk(open_price, sl, tp);
   if(risk <= 0.0 || open_price <= 0.0)
      return;

   const bool is_long = (ptype == POSITION_TYPE_BUY);
   const double market = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                 : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const double moved = is_long ? (market - open_price) : (open_price - market);
   if(moved >= strategy_early_exit_rr * risk)
      g_strategy_reached_half_r = true;

   if(strategy_be_trigger_rr <= 0.0 || moved < strategy_be_trigger_rr * risk)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   const bool improves = is_long ? (sl < open_price - point * 0.5)
                                 : (sl > open_price + point * 0.5);
   if(improves)
      QM_TM_MoveSL(ticket, StrategyNormalizePrice(open_price), "grimes_powerpush_be_1r");
  }

bool Strategy_ExitSignal()
  {
   if(!g_strategy_exit_due)
      return false;

   ENUM_POSITION_TYPE ptype;
   double open_price;
   double sl;
   double tp;
   ulong ticket;
   if(!StrategySelectPosition(ptype, open_price, sl, tp, ticket))
     {
      g_strategy_exit_due = false;
      g_strategy_reached_half_r = false;
      return false;
     }

   return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10927_grimes_powerpush\"}");
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
