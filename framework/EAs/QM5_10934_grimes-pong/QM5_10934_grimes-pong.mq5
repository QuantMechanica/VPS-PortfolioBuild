#property strict
#property version   "5.0"
#property description "QM5_10934 Grimes Pong Two-Level Range"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10934;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period          = 20;
input int    strategy_adx_period          = 14;
input double strategy_adx_max             = 28.0;
input int    strategy_touch_lookback_bars = 32;
input int    strategy_h1_pivot_lookback   = 48;
input double strategy_min_range_atr       = 1.0;
input double strategy_max_range_atr       = 3.0;
input double strategy_touch_atr_mult      = 0.15;
input double strategy_wick_min_fraction   = 0.35;
input double strategy_stop_atr_mult       = 0.35;
input double strategy_breakout_atr_mult   = 0.50;
input int    strategy_max_hold_bars       = 12;
input int    strategy_session_start_hour  = 8;
input int    strategy_session_end_hour    = 22;

double   g_pong_lower        = 0.0;
double   g_pong_upper        = 0.0;
double   g_pong_mid          = 0.0;
double   g_pong_entry_atr    = 0.0;
datetime g_pong_signal_time  = 0;
int      g_pong_signal_day   = 0;
bool     g_pong_day_disabled = false;
int      g_pong_day_key      = 0;

int BrokerDayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime BrokerDayStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

int BrokerHhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

void RefreshDayState()
  {
   const int today = BrokerDayKey(TimeCurrent());
   if(today == g_pong_day_key)
      return;
   g_pong_day_key = today;
   g_pong_day_disabled = false;
  }

bool InConfiguredSession()
  {
   const datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour));
   const int end_h = MathMax(0, MathMin(24, strategy_session_end_hour));
   if(start_h == end_h)
      return true;
   if(start_h < end_h)
      return (dt.hour >= start_h && dt.hour < end_h);
   return (dt.hour >= start_h || dt.hour < end_h);
  }

bool AddLevel(double &levels[], const double level, const double min_gap)
  {
   if(level <= 0.0)
      return false;
   for(int i = 0; i < ArraySize(levels); ++i)
      if(MathAbs(levels[i] - level) <= min_gap)
         return false;
   const int n = ArraySize(levels);
   ArrayResize(levels, n + 1);
   levels[n] = level;
   return true;
  }

bool LoadRates(const ENUM_TIMEFRAMES tf, const int start_pos, const int count, MqlRates &rates[])
  {
   if(count <= 0)
      return false;
   ArrayResize(rates, count);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, start_pos, count, rates); // perf-allowed
   return (copied == count);
  }

int CountTouches(const MqlRates &rates[], const int bars, const double level, const double tolerance)
  {
   int touches = 0;
   const int n = MathMin(bars, ArraySize(rates));
   for(int i = 0; i < n; ++i)
     {
      if(rates[i].high >= level - tolerance && rates[i].low <= level + tolerance)
         ++touches;
     }
   return touches;
  }

int CompletedTradesToday()
  {
   const datetime now = TimeCurrent();
   if(!HistorySelect(BrokerDayStart(now), now))
      return 0;

   const int magic = QM_FrameworkMagic();
   int count = 0;
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if((long)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
         ++count;
     }
   return count;
  }

bool HasOpenPositionForMagic()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool BuildPongLevels(const double atr, double &levels[])
  {
   ArrayResize(levels, 0);
   if(atr <= 0.0)
      return false;

   MqlRates d1[];
   if(!LoadRates(PERIOD_D1, 1, 1, d1))
      return false;

   const double min_gap = atr * 0.05;
   AddLevel(levels, d1[0].high, min_gap);
   AddLevel(levels, d1[0].low, min_gap);
   AddLevel(levels, d1[0].close, min_gap);

   MqlRates h1[];
   const int h1_count = MathMax(strategy_h1_pivot_lookback + 2, 8);
   if(!LoadRates(PERIOD_H1, 1, h1_count, h1))
      return (ArraySize(levels) >= 2);

   for(int i = 1; i < h1_count - 1; ++i)
     {
      if(h1[i].high > h1[i - 1].high && h1[i].high > h1[i + 1].high)
         AddLevel(levels, h1[i].high, min_gap);
      if(h1[i].low < h1[i - 1].low && h1[i].low < h1[i + 1].low)
         AddLevel(levels, h1[i].low, min_gap);
     }

   return (ArraySize(levels) >= 2);
  }

bool FindPongRange(const MqlRates &m15[], const double atr, double &lower, double &upper)
  {
   lower = 0.0;
   upper = 0.0;

   double levels[];
   if(!BuildPongLevels(atr, levels))
      return false;

   const double min_width = strategy_min_range_atr * atr;
   const double max_width = strategy_max_range_atr * atr;
   const double touch_tol = strategy_touch_atr_mult * atr;
   const double last_close = m15[0].close;
   double best_score = DBL_MAX;

   const int n = ArraySize(levels);
   for(int i = 0; i < n; ++i)
     {
      for(int j = i + 1; j < n; ++j)
        {
         const double lo = MathMin(levels[i], levels[j]);
         const double hi = MathMax(levels[i], levels[j]);
         const double width = hi - lo;
         if(width < min_width || width > max_width)
            continue;
         if(CountTouches(m15, strategy_touch_lookback_bars, lo, touch_tol) < 1)
            continue;
         if(CountTouches(m15, strategy_touch_lookback_bars, hi, touch_tol) < 1)
            continue;

         const double near_edge = MathMin(MathAbs(last_close - lo), MathAbs(last_close - hi));
         const double width_score = MathAbs(width - (2.0 * atr));
         const double score = near_edge + width_score * 0.25;
         if(score < best_score)
           {
            best_score = score;
            lower = lo;
            upper = hi;
           }
        }
     }

   return (lower > 0.0 && upper > lower);
  }

bool RangeHasOneRAfterCosts(const bool is_long,
                            const double entry_price,
                            const double sl,
                            const double tp)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry_price <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;

   const double spread_cost = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;
   const double risk = is_long ? (entry_price - sl + spread_cost)
                               : (sl - entry_price + spread_cost);
   const double reward = is_long ? (tp - entry_price - spread_cost)
                                 : (entry_price - tp - spread_cost);
   return (risk > 0.0 && reward >= risk);
  }

bool Strategy_NoTradeFilter()
  {
   RefreshDayState();

   if(g_pong_day_disabled)
      return true;
   if(!InConfiguredSession())
      return true;

   const double adx = QM_ADX(_Symbol, PERIOD_M15, strategy_adx_period, 1);
   if(adx > strategy_adx_max)
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

   if(HasOpenPositionForMagic())
      return false;
   if(CompletedTradesToday() >= 2)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   MqlRates m15[];
   const int needed = MathMax(strategy_touch_lookback_bars + 2, 40);
   if(!LoadRates(PERIOD_M15, 1, needed, m15))
      return false;

   double lower = 0.0;
   double upper = 0.0;
   if(!FindPongRange(m15, atr, lower, upper))
      return false;

   const double breakout_pad = strategy_breakout_atr_mult * atr;
   if(m15[0].close > upper + breakout_pad || m15[0].close < lower - breakout_pad)
     {
      g_pong_day_disabled = true;
      return false;
     }

   const double touch_pad = strategy_touch_atr_mult * atr;
   const double range = m15[0].high - m15[0].low;
   if(range <= 0.0)
      return false;

   const double lower_wick = MathMin(m15[0].open, m15[0].close) - m15[0].low;
   const double upper_wick = m15[0].high - MathMax(m15[0].open, m15[0].close);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const bool long_setup = (m15[0].low <= lower + touch_pad &&
                            m15[0].close > lower &&
                            lower_wick / range >= strategy_wick_min_fraction);
   const bool short_setup = (m15[0].high >= upper - touch_pad &&
                             m15[0].close < upper &&
                             upper_wick / range >= strategy_wick_min_fraction);

   if(long_setup)
     {
      const double sl = lower - strategy_stop_atr_mult * atr;
      const double tp = upper - touch_pad;
      if(!RangeHasOneRAfterCosts(true, ask, sl, tp))
         return false;
      req.type = QM_BUY;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(tp, _Digits);
      req.reason = "GRIMES_PONG_LONG";
     }
   else if(short_setup)
     {
      const double sl = upper + strategy_stop_atr_mult * atr;
      const double tp = lower + touch_pad;
      if(!RangeHasOneRAfterCosts(false, bid, sl, tp))
         return false;
      req.type = QM_SELL;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(tp, _Digits);
      req.reason = "GRIMES_PONG_SHORT";
     }
   else
      return false;

   g_pong_lower = lower;
   g_pong_upper = upper;
   g_pong_mid = (lower + upper) * 0.5;
   g_pong_entry_atr = atr;
   g_pong_signal_time = TimeCurrent();
   g_pong_signal_day = BrokerDayKey(g_pong_signal_time);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(g_pong_mid <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price <= 0.0 || point <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid >= g_pong_mid && (current_sl <= 0.0 || current_sl < open_price - point * 0.5))
            QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "pong_midpoint_breakeven");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= g_pong_mid && (current_sl <= 0.0 || current_sl > open_price + point * 0.5))
            QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "pong_midpoint_breakeven");
        }
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int max_hold_seconds = strategy_max_hold_bars * PeriodSeconds(PERIOD_M15);
   const bool near_day_end = (BrokerHhmm(now) >= 2330);

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
      if(max_hold_seconds > 0 && now - opened >= max_hold_seconds)
         return true;
      if(near_day_end)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10934_grimes_pong\"}");
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
