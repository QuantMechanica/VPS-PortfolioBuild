#property strict
#property version   "5.0"
#property description "QM5_10759 TradingView SCP SMC Confluence Score"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10759;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_min_score           = 3;
input int    strategy_pivot_length        = 8;
input int    strategy_scan_bars           = 120;
input int    strategy_atr_period          = 14;
input double strategy_atr_buffer_mult     = 0.20;
input double strategy_atr_max_stop_mult   = 4.00;
input double strategy_target_rr           = 2.00;
input int    strategy_expiry_bars         = 20;
input int    strategy_equal_level_lookback = 24;
input double strategy_equal_atr_tolerance = 0.15;
input double strategy_cluster_atr_tolerance = 0.25;
input int    strategy_session_mode        = 3;    // 0 all, 1 London, 2 New York, 3 London/NY overlap
input int    strategy_london_start_hour   = 8;
input int    strategy_london_end_hour     = 17;
input int    strategy_newyork_start_hour  = 13;
input int    strategy_newyork_end_hour    = 22;
input bool   strategy_allow_long          = true;
input bool   strategy_allow_short         = true;
input int    strategy_max_spread_points   = 0;

struct StrategyLevels
  {
   bool   valid;
   double swing_high;
   double swing_low;
   double prev_swing_high;
   double prev_swing_low;
   double equal_high;
   double equal_low;
  };

int  g_last_signal_dir = 0;
int  g_last_signal_score = 0;
bool g_block_next_entry = false;

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

bool Strategy_HourInSession(const int hour, const int start_hour, const int end_hour)
  {
   if(start_hour == end_hour)
      return true;
   if(start_hour < end_hour)
      return (hour >= start_hour && hour < end_hour);
   return (hour >= start_hour || hour < end_hour);
  }

bool Strategy_IsPivotHigh(MqlRates &rates[], const int index, const int width, const int copied)
  {
   if(index < width || index + width >= copied)
      return false;

   const double value = rates[index].high;
   for(int offset = 1; offset <= width; ++offset)
     {
      if(rates[index - offset].high >= value)
         return false;
      if(rates[index + offset].high >= value)
         return false;
     }
   return true;
  }

bool Strategy_IsPivotLow(MqlRates &rates[], const int index, const int width, const int copied)
  {
   if(index < width || index + width >= copied)
      return false;

   const double value = rates[index].low;
   for(int offset = 1; offset <= width; ++offset)
     {
      if(rates[index - offset].low <= value)
         return false;
      if(rates[index + offset].low <= value)
         return false;
     }
   return true;
  }

bool Strategy_LoadLevels(MqlRates &rates[], const int copied, const double atr, StrategyLevels &levels)
  {
   levels.valid = false;
   levels.swing_high = 0.0;
   levels.swing_low = 0.0;
   levels.prev_swing_high = 0.0;
   levels.prev_swing_low = 0.0;
   levels.equal_high = 0.0;
   levels.equal_low = 0.0;

   const int width = MathMax(2, strategy_pivot_length);
   if(copied <= width * 2 + 8 || atr <= 0.0)
      return false;

   for(int i = width; i < copied - width; ++i)
     {
      if(Strategy_IsPivotHigh(rates, i, width, copied))
        {
         if(levels.swing_high <= 0.0)
            levels.swing_high = rates[i].high;
         else if(levels.prev_swing_high <= 0.0)
            levels.prev_swing_high = rates[i].high;
        }

      if(Strategy_IsPivotLow(rates, i, width, copied))
        {
         if(levels.swing_low <= 0.0)
            levels.swing_low = rates[i].low;
         else if(levels.prev_swing_low <= 0.0)
            levels.prev_swing_low = rates[i].low;
        }

      if(levels.swing_high > 0.0 && levels.swing_low > 0.0 &&
         levels.prev_swing_high > 0.0 && levels.prev_swing_low > 0.0)
         break;
     }

   const int eq_lookback = MathMin(MathMax(6, strategy_equal_level_lookback), copied - 2);
   double high_a = 0.0;
   double high_b = 0.0;
   double low_a = 0.0;
   double low_b = 0.0;
   for(int i = 1; i <= eq_lookback; ++i)
     {
      const double h = rates[i].high;
      const double l = rates[i].low;
      if(high_a <= 0.0 || h > high_a)
        {
         high_b = high_a;
         high_a = h;
        }
      else if(high_b <= 0.0 || h > high_b)
         high_b = h;

      if(low_a <= 0.0 || l < low_a)
        {
         low_b = low_a;
         low_a = l;
        }
      else if(low_b <= 0.0 || l < low_b)
         low_b = l;
     }

   const double eq_tol = atr * MathMax(0.01, strategy_equal_atr_tolerance);
   if(high_a > 0.0 && high_b > 0.0 && MathAbs(high_a - high_b) <= eq_tol)
      levels.equal_high = MathMax(high_a, high_b);
   if(low_a > 0.0 && low_b > 0.0 && MathAbs(low_a - low_b) <= eq_tol)
      levels.equal_low = MathMin(low_a, low_b);

   levels.valid = (levels.swing_high > levels.swing_low && levels.swing_low > 0.0);
   return levels.valid;
  }

bool Strategy_TouchesCluster(const double close_price,
                             const StrategyLevels &levels,
                             const double atr)
  {
   const double tol = atr * MathMax(0.01, strategy_cluster_atr_tolerance);
   if(tol <= 0.0)
      return false;

   if(levels.swing_high > 0.0 && MathAbs(close_price - levels.swing_high) <= tol)
      return true;
   if(levels.swing_low > 0.0 && MathAbs(close_price - levels.swing_low) <= tol)
      return true;
   if(levels.equal_high > 0.0 && MathAbs(close_price - levels.equal_high) <= tol)
      return true;
   if(levels.equal_low > 0.0 && MathAbs(close_price - levels.equal_low) <= tol)
      return true;
   return false;
  }

int Strategy_ComputeSignal(MqlRates &rates[],
                           const int copied,
                           const double atr,
                           const StrategyLevels &levels,
                           int &out_score)
  {
   out_score = 0;
   if(copied < 4 || !levels.valid || atr <= 0.0)
      return 0;

   const double close1 = rates[0].close;
   const double close2 = rates[1].close;
   const double range = levels.swing_high - levels.swing_low;
   if(close1 <= 0.0 || close2 <= 0.0 || range <= 0.0)
      return 0;

   const bool bullish_choch = (levels.swing_high > 0.0 &&
                               close1 > levels.swing_high &&
                               close2 <= levels.swing_high);
   const bool bearish_choch = (levels.swing_low > 0.0 &&
                               close1 < levels.swing_low &&
                               close2 >= levels.swing_low);

   const bool bullish_fvg = (rates[0].low > rates[2].high);
   const bool bearish_fvg = (rates[0].high < rates[2].low);
   const bool bullish_ob = (rates[1].close < rates[1].open && close1 > rates[1].high);
   const bool bearish_ob = (rates[1].close > rates[1].open && close1 < rates[1].low);

   const double eq_tol = atr * MathMax(0.01, strategy_equal_atr_tolerance);
   const bool bullish_sweep = (levels.equal_low > 0.0 &&
                               rates[0].low < levels.equal_low - eq_tol * 0.25 &&
                               close1 > levels.equal_low);
   const bool bearish_sweep = (levels.equal_high > 0.0 &&
                               rates[0].high > levels.equal_high + eq_tol * 0.25 &&
                               close1 < levels.equal_high);

   const double mid = (levels.swing_high + levels.swing_low) * 0.5;
   const double long_ote_low = levels.swing_low + range * 0.21;
   const double long_ote_high = levels.swing_low + range * 0.38;
   const double short_ote_low = levels.swing_low + range * 0.62;
   const double short_ote_high = levels.swing_low + range * 0.79;
   const bool bullish_value = (close1 <= mid ||
                               (close1 >= long_ote_low && close1 <= long_ote_high) ||
                               bullish_fvg);
   const bool bearish_value = (close1 >= mid ||
                               (close1 >= short_ote_low && close1 <= short_ote_high) ||
                               bearish_fvg);

   const bool clustered = Strategy_TouchesCluster(close1, levels, atr);

   int long_score = 0;
   int short_score = 0;
   if(bullish_choch) long_score += 2;
   if(bearish_choch) short_score += 2;
   if(bullish_ob || bullish_fvg) long_score += 1;
   if(bearish_ob || bearish_fvg) short_score += 1;
   if(bullish_sweep) long_score += 3;
   if(bearish_sweep) short_score += 3;
   if(bullish_value) long_score += 1;
   if(bearish_value) short_score += 1;
   if(clustered && close1 >= mid) short_score += 1;
   if(clustered && close1 <= mid) long_score += 1;

   const int min_score = MathMax(2, strategy_min_score);
   const bool long_trigger = (bullish_choch || bullish_sweep);
   const bool short_trigger = (bearish_choch || bearish_sweep);

   if(strategy_allow_long && long_trigger && bullish_value &&
      long_score >= min_score && long_score > short_score)
     {
      out_score = long_score;
      return 1;
     }

   if(strategy_allow_short && short_trigger && bearish_value &&
      short_score >= min_score && short_score > long_score)
     {
      out_score = short_score;
      return -1;
     }

   return 0;
  }

bool Strategy_OurPosition(int &direction, int &bars_held)
  {
   direction = 0;
   bars_held = 0;
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      direction = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(opened > 0 && seconds > 0)
         bars_held = (int)MathFloor((double)(TimeCurrent() - opened) / (double)seconds);
      return true;
     }
   return false;
  }

bool Strategy_BuildRequest(const int direction,
                           const int score,
                           const double atr,
                           const StrategyLevels &levels,
                           QM_EntryRequest &req)
  {
   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double buffer = atr * MathMax(0.0, strategy_atr_buffer_mult);
   const double max_stop = atr * MathMax(0.5, strategy_atr_max_stop_mult);
   if(direction > 0)
     {
      double sl = levels.swing_low - buffer;
      if(sl <= 0.0 || entry - sl > max_stop)
         sl = entry - max_stop;
      if(sl <= 0.0 || sl >= entry)
         return false;
      req.sl = Strategy_NormalizePrice(sl);
      req.tp = QM_TakeRR(_Symbol, QM_BUY, entry, req.sl, strategy_target_rr);
      req.reason = StringFormat("SCP_LONG_SCORE_%d", score);
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   double sl = levels.swing_high + buffer;
   if(sl <= 0.0 || sl - entry > max_stop)
      sl = entry + max_stop;
   if(sl <= entry)
      return false;
   req.sl = Strategy_NormalizePrice(sl);
   req.tp = QM_TakeRR(_Symbol, QM_SELL, entry, req.sl, strategy_target_rr);
   req.reason = StringFormat("SCP_SHORT_SCORE_%d", score);
   return (req.sl > 0.0 && req.tp > 0.0);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15 && _Period != PERIOD_H1)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   if(strategy_session_mode <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const bool london = Strategy_HourInSession(dt.hour,
                                              strategy_london_start_hour,
                                              strategy_london_end_hour);
   const bool newyork = Strategy_HourInSession(dt.hour,
                                               strategy_newyork_start_hour,
                                               strategy_newyork_end_hour);

   if(strategy_session_mode == 1)
      return !london;
   if(strategy_session_mode == 2)
      return !newyork;
   return !(london && newyork);
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

   const int scan_bars = MathMax(strategy_scan_bars, strategy_pivot_length * 4 + 40);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, scan_bars, rates); // perf-allowed: bounded SMC structural scan, called only after the framework QM_IsNewBar gate.
   if(copied < strategy_pivot_length * 2 + 12)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_target_rr <= 0.0)
      return false;

   StrategyLevels levels;
   if(!Strategy_LoadLevels(rates, copied, atr, levels))
      return false;

   int score = 0;
   const int signal_dir = Strategy_ComputeSignal(rates, copied, atr, levels, score);
   g_last_signal_dir = signal_dir;
   g_last_signal_score = score;

   int pos_dir = 0;
   int bars_held = 0;
   if(Strategy_OurPosition(pos_dir, bars_held))
      return false;

   if(g_block_next_entry)
     {
      g_block_next_entry = false;
      return false;
     }

   if(signal_dir == 0)
      return false;

   return Strategy_BuildRequest(signal_dir, score, atr, levels, req);
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline uses one full-size position with fixed SL/TP. No BE, trailing,
   // partial close, or pyramiding is added.
  }

bool Strategy_ExitSignal()
  {
   int pos_dir = 0;
   int bars_held = 0;
   if(!Strategy_OurPosition(pos_dir, bars_held))
      return false;

   if(strategy_expiry_bars > 0 && bars_held >= strategy_expiry_bars)
     {
      g_block_next_entry = true;
      return true;
     }

   if(g_last_signal_dir != 0 && g_last_signal_dir == -pos_dir)
     {
      g_block_next_entry = true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10759_tv-scp-score\"}");
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
