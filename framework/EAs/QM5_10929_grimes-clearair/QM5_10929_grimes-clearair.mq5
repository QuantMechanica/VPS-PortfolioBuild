#property strict
#property version   "5.0"
#property description "QM5_10929 Grimes Clear Air Session Extension"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10929;
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
input int    strategy_atr_period             = 20;
input int    strategy_pivot_lookback_days    = 5;
input double strategy_breakout_atr_mult      = 0.35;
input double strategy_daily_range_atr_mult   = 1.20;
input int    strategy_ema_period             = 20;
input double strategy_initial_stop_atr_mult  = 1.40;
input int    strategy_trail_bars             = 3;
input double strategy_trail_atr_mult         = 0.10;
input int    strategy_min_bars_to_day_end    = 3;
input double strategy_spread_stop_ratio      = 0.08;

int    g_entry_day_key = -1;
int    g_outer_day_key = -1;
double g_outer_upper = 0.0;
double g_outer_lower = 0.0;

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int MinutesSinceMidnight(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int H1BarsRemainingInBrokerDay(const datetime t)
  {
   const int minute = MinutesSinceMidnight(t);
   return (1440 - minute) / 60;
  }

double H1High(const int shift)
  {
   return iHigh(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded structural pivot scan from card.
  }

double H1Low(const int shift)
  {
   return iLow(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded structural pivot scan from card.
  }

double H1Close(const int shift)
  {
   return iClose(_Symbol, PERIOD_H1, shift); // perf-allowed: closed-bar price vs outer level.
  }

datetime H1Time(const int shift)
  {
   return iTime(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded broker-day filtering.
  }

double D1High(const int shift)
  {
   return iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: previous D1 outer level.
  }

double D1Low(const int shift)
  {
   return iLow(_Symbol, PERIOD_D1, shift); // perf-allowed: previous D1 outer level.
  }

double D1Open(const int shift)
  {
   return iOpen(_Symbol, PERIOD_D1, shift); // perf-allowed: current day range calculation.
  }

bool HasOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype)
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

bool ComputeOuterLevels(double &upper, double &lower)
  {
   upper = D1High(1);
   lower = D1Low(1);
   if(upper <= 0.0 || lower <= 0.0)
      return false;

   const datetime now = TimeCurrent();
   const int today = DayKey(now);
   const int max_scan = MathMax(24, strategy_pivot_lookback_days * 24 + 4);

   for(int shift = 2; shift <= max_scan; ++shift)
     {
      const datetime bt = H1Time(shift);
      if(bt <= 0)
         continue;
      if(DayKey(bt) == today)
         continue;
      if((now - bt) > strategy_pivot_lookback_days * 86400)
         continue;

      const double h = H1High(shift);
      const double hp = H1High(shift + 1);
      const double hn = H1High(shift - 1);
      if(h > 0.0 && h >= hp && h > hn)
         upper = MathMax(upper, h);

      const double l = H1Low(shift);
      const double lp = H1Low(shift + 1);
      const double ln = H1Low(shift - 1);
      if(l > 0.0 && l <= lp && l < ln)
         lower = MathMin(lower, l);
     }

   return (upper > lower && upper > 0.0 && lower > 0.0);
  }

bool GetOuterLevels(double &upper, double &lower)
  {
   const int today = DayKey(TimeCurrent());
   if(g_outer_day_key == today && g_outer_upper > 0.0 && g_outer_lower > 0.0)
     {
      upper = g_outer_upper;
      lower = g_outer_lower;
      return true;
     }

   if(!ComputeOuterLevels(upper, lower))
      return false;

   g_outer_day_key = today;
   g_outer_upper = upper;
   g_outer_lower = lower;
   return true;
  }

bool CurrentDayRangeSoFar(double &range_out)
  {
   range_out = 0.0;
   const int today = DayKey(TimeCurrent());
   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   for(int shift = 1; shift <= 24; ++shift)
     {
      const datetime bt = H1Time(shift);
      if(bt <= 0)
         continue;
      if(DayKey(bt) != today)
         continue;
      const double h = H1High(shift);
      const double l = H1Low(shift);
      if(h <= 0.0 || l <= 0.0)
         continue;
      hi = MathMax(hi, h);
      lo = MathMin(lo, l);
     }

   const double day_open = D1Open(0);
   if(day_open > 0.0)
     {
      hi = MathMax(hi, day_open);
      lo = MathMin(lo, day_open);
     }

   if(hi == -DBL_MAX || lo == DBL_MAX || hi <= lo)
      return false;

   range_out = hi - lo;
   return true;
  }

double LowestRecentLow(const int bars)
  {
   double lo = DBL_MAX;
   for(int shift = 1; shift <= bars; ++shift)
     {
      const double v = H1Low(shift);
      if(v <= 0.0)
         return 0.0;
      lo = MathMin(lo, v);
     }
   return lo;
  }

double HighestRecentHigh(const int bars)
  {
   double hi = -DBL_MAX;
   for(int shift = 1; shift <= bars; ++shift)
     {
      const double v = H1High(shift);
      if(v <= 0.0)
         return 0.0;
      hi = MathMax(hi, v);
     }
   return hi;
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

   if((ENUM_TIMEFRAMES)_Period != PERIOD_H1)
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(HasOurPosition(ticket, ptype))
      return false;

   const datetime now = TimeCurrent();
   const int today = DayKey(now);
   if(g_entry_day_key == today)
      return false;
   if(H1BarsRemainingInBrokerDay(now) < strategy_min_bars_to_day_end)
      return false;

   double upper = 0.0;
   double lower = 0.0;
   if(!GetOuterLevels(upper, lower))
      return false;

   const double close1 = H1Close(1);
   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double ema1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 1);
   const double ema2 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 2);
   if(close1 <= 0.0 || atr_h1 <= 0.0 || atr_d1 <= 0.0 || ema1 <= 0.0 || ema2 <= 0.0)
      return false;

   double day_range = 0.0;
   if(!CurrentDayRangeSoFar(day_range))
      return false;
   if(day_range < strategy_daily_range_atr_mult * atr_d1)
      return false;

   const double stop_dist = strategy_initial_stop_atr_mult * atr_h1;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(stop_dist <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > strategy_spread_stop_ratio * stop_dist)
      return false;

   if(close1 > upper + strategy_breakout_atr_mult * atr_h1 && ema1 > ema2)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = ask - stop_dist;
      req.tp = 0.0;
      req.reason = "CLEAR_AIR_LONG";
      g_entry_day_key = today;
      return true;
     }

   if(close1 < lower - strategy_breakout_atr_mult * atr_h1 && ema1 < ema2)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = bid + stop_dist;
      req.tp = 0.0;
      req.reason = "CLEAR_AIR_SHORT";
      g_entry_day_key = today;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(!HasOurPosition(ticket, ptype))
      return;

   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr_h1 <= 0.0 || point <= 0.0)
      return;

   if(ptype == POSITION_TYPE_BUY)
     {
      const double base = LowestRecentLow(strategy_trail_bars);
      if(base <= 0.0)
         return;
      const double new_sl = base - strategy_trail_atr_mult * atr_h1;
      const double cur_sl = PositionGetDouble(POSITION_SL);
      if(cur_sl <= 0.0 || new_sl > cur_sl + point * 0.5)
         QM_TM_MoveSL(ticket, new_sl, "clear_air_h1_trail_long");
      return;
     }

   const double base = HighestRecentHigh(strategy_trail_bars);
   if(base <= 0.0)
      return;
   const double new_sl = base + strategy_trail_atr_mult * atr_h1;
   const double cur_sl = PositionGetDouble(POSITION_SL);
   if(cur_sl <= 0.0 || new_sl < cur_sl - point * 0.5)
      QM_TM_MoveSL(ticket, new_sl, "clear_air_h1_trail_short");
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(!HasOurPosition(ticket, ptype))
      return false;

   const datetime now = TimeCurrent();
   if(H1BarsRemainingInBrokerDay(now) <= 1)
      return true;

   double upper = 0.0;
   double lower = 0.0;
   if(!GetOuterLevels(upper, lower))
      return false;

   const double close1 = H1Close(1);
   if(close1 <= 0.0)
      return false;

   if(ptype == POSITION_TYPE_BUY && close1 <= upper)
      return true;
   if(ptype == POSITION_TYPE_SELL && close1 >= lower)
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
