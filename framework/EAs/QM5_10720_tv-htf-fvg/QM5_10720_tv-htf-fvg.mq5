#property strict
#property version   "5.0"
#property description "QM5_10720 TradingView HTF Liquidity Sweep FVG"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10720;
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
input int    strategy_atr_period             = 14;
input int    strategy_limit_timeout_bars     = 20;
input int    strategy_sweep_stop_window      = 5;
input double strategy_stop_atr_buffer_mult   = 0.20;
input double strategy_stop_max_atr_mult      = 4.00;
input double strategy_min_fvg_atr_mult       = 0.10;
input double strategy_min_fvg_points         = 2.00;
input double strategy_tp_fallback_rr         = 2.00;
input int    strategy_ny_session_start_hour  = 2;
input int    strategy_ny_session_end_hour    = 15;
input double strategy_max_spread_points      = 0.0;

struct HTFLevelState
  {
   ENUM_TIMEFRAMES tf;
   double          high;
   double          low;
   bool            high_swept;
   bool            low_swept;
  };

HTFLevelState g_htf[3];
bool          g_htf_ready = false;
int           g_sweep_bias = 0;
int           g_sweep_age_bars = 0;
bool          g_entry_attempted_for_sweep = false;

void InitHtfLevels()
  {
   if(g_htf_ready)
      return;
   g_htf[0].tf = PERIOD_D1;
   g_htf[1].tf = PERIOD_W1;
   g_htf[2].tf = PERIOD_MN1;
   for(int i = 0; i < 3; ++i)
     {
      g_htf[i].high = 0.0;
      g_htf[i].low = 0.0;
      g_htf[i].high_swept = false;
      g_htf[i].low_swept = false;
     }
   g_htf_ready = true;
  }

bool RefreshHtfLevels()
  {
   InitHtfLevels();
   bool have_all = true;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double eps = (point > 0.0 ? point * 0.5 : 0.0);

   for(int i = 0; i < 3; ++i)
     {
      const ENUM_TIMEFRAMES tf = g_htf[i].tf;
      const double h = iHigh(_Symbol, tf, 1); // perf-allowed: bespoke HTF liquidity level, closed-bar entry hook only
      const double l = iLow(_Symbol, tf, 1);  // perf-allowed: bespoke HTF liquidity level, closed-bar entry hook only
      if(h <= 0.0 || l <= 0.0 || h <= l)
        {
         have_all = false;
         continue;
        }

      if(g_htf[i].high <= 0.0 || MathAbs(h - g_htf[i].high) > eps)
        {
         g_htf[i].high = h;
         g_htf[i].high_swept = false;
        }
      if(g_htf[i].low <= 0.0 || MathAbs(l - g_htf[i].low) > eps)
        {
         g_htf[i].low = l;
         g_htf[i].low_swept = false;
        }
     }

   return have_all;
  }

bool IsInNySession(const datetime broker_time)
  {
   if(strategy_ny_session_start_hour == strategy_ny_session_end_hour)
      return true;

   const datetime utc = QM_BrokerToUTC(broker_time);
   const int ny_offset_hours = QM_IsUSDSTUTC(utc) ? -4 : -5;
   const datetime ny_time = utc + ny_offset_hours * 3600;
   MqlDateTime dt;
   TimeToStruct(ny_time, dt);

   const int start_h = MathMax(0, MathMin(23, strategy_ny_session_start_hour));
   const int end_h = MathMax(0, MathMin(23, strategy_ny_session_end_hour));
   if(start_h < end_h)
      return (dt.hour >= start_h && dt.hour < end_h);
   return (dt.hour >= start_h || dt.hour < end_h);
  }

bool SpreadAllowed()
  {
   if(strategy_max_spread_points <= 0.0)
      return true;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;
   return ((ask - bid) / point <= strategy_max_spread_points);
  }

bool HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT)
         return true;
     }

   return false;
  }

void RemoveTimedOutPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   const int timeout_seconds = MathMax(1, strategy_limit_timeout_bars) * PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(magic <= 0 || timeout_seconds <= 0)
      return;

   const datetime now = TimeCurrent();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_LIMIT && type != ORDER_TYPE_SELL_LIMIT)
         continue;
      const datetime setup_time = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0 && now - setup_time >= timeout_seconds)
         QM_TM_RemovePendingOrder(ticket, "limit_timeout_bars");
     }
  }

void UpdateSweepBias(const MqlRates &bar)
  {
   bool swept_low = false;
   bool swept_high = false;

   for(int i = 0; i < 3; ++i)
     {
      if(!g_htf[i].low_swept && g_htf[i].low > 0.0 && bar.low <= g_htf[i].low)
        {
         g_htf[i].low_swept = true;
         swept_low = true;
        }
      if(!g_htf[i].high_swept && g_htf[i].high > 0.0 && bar.high >= g_htf[i].high)
        {
         g_htf[i].high_swept = true;
         swept_high = true;
        }
     }

   if(swept_low && swept_high)
     {
      g_sweep_bias = 0;
      g_sweep_age_bars = 0;
      g_entry_attempted_for_sweep = true;
      return;
     }

   if(swept_low)
     {
      g_sweep_bias = 1;
      g_sweep_age_bars = 0;
      g_entry_attempted_for_sweep = false;
      return;
     }

   if(swept_high)
     {
      g_sweep_bias = -1;
      g_sweep_age_bars = 0;
      g_entry_attempted_for_sweep = false;
      return;
     }

   if(g_sweep_bias != 0)
      g_sweep_age_bars++;
  }

bool LoadRecentRates(MqlRates &rates[], const int requested)
  {
   ArraySetAsSeries(rates, true);
   const int bars = MathMax(10, requested);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, bars, rates); // perf-allowed: bounded structural FVG scan, closed-bar entry hook only
   return (copied >= 5);
  }

double RecentLowestLow(const MqlRates &rates[], const int count)
  {
   double lo = DBL_MAX;
   const int n = MathMin(count, ArraySize(rates));
   for(int i = 0; i < n; ++i)
      lo = MathMin(lo, rates[i].low);
   return (lo < DBL_MAX ? lo : 0.0);
  }

double RecentHighestHigh(const MqlRates &rates[], const int count)
  {
   double hi = -DBL_MAX;
   const int n = MathMin(count, ArraySize(rates));
   for(int i = 0; i < n; ++i)
      hi = MathMax(hi, rates[i].high);
   return (hi > 0.0 ? hi : 0.0);
  }

double NearestLongTarget(const double entry)
  {
   double target = 0.0;
   for(int i = 0; i < 3; ++i)
     {
      if(g_htf[i].high <= entry)
         continue;
      if(target <= 0.0 || g_htf[i].high < target)
         target = g_htf[i].high;
     }
   return target;
  }

double NearestShortTarget(const double entry)
  {
   double target = 0.0;
   for(int i = 0; i < 3; ++i)
     {
      if(g_htf[i].low <= 0.0 || g_htf[i].low >= entry)
         continue;
      if(target <= 0.0 || g_htf[i].low > target)
         target = g_htf[i].low;
     }
   return target;
  }

bool FindBullishFvg(const MqlRates &rates[], const double min_gap, double &entry)
  {
   entry = 0.0;
   const int max_i = MathMin(MathMin(g_sweep_age_bars, strategy_limit_timeout_bars), ArraySize(rates) - 3);
   if(max_i < 0)
      return false;

   const double current_close = rates[0].close;
   for(int i = 0; i <= max_i; ++i)
     {
      const double bottom = rates[i + 2].high;
      const double top = rates[i].low;
      if(bottom <= 0.0 || top <= 0.0 || top <= bottom)
         continue;
      if(top - bottom < min_gap || top >= current_close)
         continue;
      if(entry <= 0.0 || top > entry)
         entry = top;
     }

   return (entry > 0.0);
  }

bool FindBearishFvg(const MqlRates &rates[], const double min_gap, double &entry)
  {
   entry = 0.0;
   const int max_i = MathMin(MathMin(g_sweep_age_bars, strategy_limit_timeout_bars), ArraySize(rates) - 3);
   if(max_i < 0)
      return false;

   const double current_close = rates[0].close;
   for(int i = 0; i <= max_i; ++i)
     {
      const double top = rates[i + 2].low;
      const double bottom = rates[i].high;
      if(bottom <= 0.0 || top <= 0.0 || top <= bottom)
         continue;
      if(top - bottom < min_gap || bottom <= current_close)
         continue;
      if(entry <= 0.0 || bottom < entry)
         entry = bottom;
     }

   return (entry > 0.0);
  }

bool Strategy_NoTradeFilter()
  {
   if(!IsInNySession(TimeCurrent()))
      return true;
   if(!SpreadAllowed())
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(1, strategy_limit_timeout_bars) * PeriodSeconds((ENUM_TIMEFRAMES)_Period);

   if(HasOurPendingOrder())
      return false;
   if(strategy_atr_period <= 0 || strategy_limit_timeout_bars <= 0 || strategy_sweep_stop_window <= 0)
      return false;
   if(!RefreshHtfLevels())
      return false;

   MqlRates rates[];
   if(!LoadRecentRates(rates, strategy_limit_timeout_bars + 5))
      return false;

   UpdateSweepBias(rates[0]);
   if(g_sweep_bias == 0 || g_entry_attempted_for_sweep || g_sweep_age_bars > strategy_limit_timeout_bars)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(point <= 0.0 || atr <= 0.0)
      return false;

   const double min_gap = MathMax(strategy_min_fvg_atr_mult * atr, strategy_min_fvg_points * point);
   double entry = 0.0;

   if(g_sweep_bias > 0)
     {
      if(!FindBullishFvg(rates, min_gap, entry))
         return false;

      const double structure_low = RecentLowestLow(rates, strategy_sweep_stop_window);
      if(structure_low <= 0.0)
         return false;
      const double sl = NormalizeDouble(structure_low - strategy_stop_atr_buffer_mult * atr, _Digits);
      if(sl <= 0.0 || sl >= entry || rates[0].low <= sl)
         return false;
      const double risk = entry - sl;
      if(risk <= 0.0 || risk > strategy_stop_max_atr_mult * atr)
         return false;

      double tp = NearestLongTarget(entry);
      if(tp <= entry + point)
         tp = entry + risk * strategy_tp_fallback_rr;

      req.type = QM_BUY_LIMIT;
      req.price = NormalizeDouble(entry, _Digits);
      req.sl = sl;
      req.tp = NormalizeDouble(tp, _Digits);
      req.reason = "HTF_LOW_SWEEP_BULL_FVG";
      g_entry_attempted_for_sweep = true;
      return true;
     }

   if(!FindBearishFvg(rates, min_gap, entry))
      return false;

   const double structure_high = RecentHighestHigh(rates, strategy_sweep_stop_window);
   if(structure_high <= 0.0)
      return false;
   const double sl = NormalizeDouble(structure_high + strategy_stop_atr_buffer_mult * atr, _Digits);
   if(sl <= 0.0 || sl <= entry || rates[0].high >= sl)
      return false;
   const double risk = sl - entry;
   if(risk <= 0.0 || risk > strategy_stop_max_atr_mult * atr)
      return false;

   double tp = NearestShortTarget(entry);
   if(tp <= 0.0 || tp >= entry - point)
      tp = entry - risk * strategy_tp_fallback_rr;

   req.type = QM_SELL_LIMIT;
   req.price = NormalizeDouble(entry, _Digits);
   req.sl = sl;
   req.tp = NormalizeDouble(tp, _Digits);
   req.reason = "HTF_HIGH_SWEEP_BEAR_FVG";
   g_entry_attempted_for_sweep = true;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   RemoveTimedOutPendingOrders();
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10720_tv_htf_fvg\"}");
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
