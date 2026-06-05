#property strict
#property version   "5.0"
#property description "QM5_10786 TradingView Daily Bias 5-Min Pro"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10786 - TradingView Daily Bias 5-Min Pro
// -----------------------------------------------------------------------------
// Mechanical port of the approved card: M5 execution aligned to a D1 EMA/ADX
// directional bias. The source card names a 9-point confluence engine but does
// not provide the TradingView formulas for Q-Trend, UT Bot, supply/demand, or
// delta. This implementation keeps those as fixed transparent proxies:
// DEMA fast/slow cross, EMA structure, ATR trailing-stop confirmation, session
// VWAP/opening-range context, and tick-volume/zone strength.
//
// INTRADAY PERFORMANCE: session VWAP and opening range are advanced once per
// closed M5 bar through AdvanceState_OnNewBar(). EntrySignal is reached only
// after the framework QM_IsNewBar() gate. Bounded CopyRates/CopyClose calls are
// tagged perf-allowed and never run on the per-tick path.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10786;
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
input int    strategy_daily_ema_period       = 200;
input int    strategy_daily_adx_period       = 14;
input double strategy_daily_adx_threshold    = 20.0;
input int    strategy_dema_fast_period       = 21;
input int    strategy_dema_slow_period       = 55;
input int    strategy_qtrend_ema_period      = 50;
input int    strategy_ut_atr_period          = 10;
input double strategy_ut_atr_mult            = 1.5;
input int    strategy_or_start_hhmm          = 800;
input int    strategy_or_end_hhmm            = 830;
input int    strategy_trade_start_hhmm       = 800;
input int    strategy_trade_end_hhmm         = 2100;
input int    strategy_max_bars_in_trade      = 72;
input bool   strategy_vwap_chop_filter       = true;
input bool   strategy_opening_range_filter   = true;
input int    strategy_zone_lookback          = 48;
input double strategy_zone_edge_pct          = 0.25;
input int    strategy_volume_lookback        = 20;
input double strategy_volume_strength_mult   = 1.0;
input int    strategy_score_threshold        = 6;
input int    strategy_cooldown_bars          = 10;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 1.5;
input double strategy_rr_target              = 2.0;
input int    strategy_max_spread_points      = 0;

int      g_session_ymd       = -1;
int      g_bars_today        = 0;
double   g_or_high           = 0.0;
double   g_or_low            = 0.0;
bool     g_or_active         = false;
bool     g_or_complete       = false;
double   g_vwap_num          = 0.0;
double   g_vwap_den          = 0.0;
double   g_vwap              = 0.0;
int      g_cooldown_remaining = 0;
int      g_last_exec_dir     = 0;
int      g_last_score        = 0;

int BrokerHHMM(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int BrokerYMD(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool InHHMMWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   if(start_hhmm <= end_hhmm)
      return (hhmm >= start_hhmm && hhmm < end_hhmm);
   return (hhmm >= start_hhmm || hhmm < end_hhmm);
  }

void ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

double ClosedClose(const ENUM_TIMEFRAMES tf, const int shift)
  {
   double values[];
   ArraySetAsSeries(values, true);
   if(CopyClose(_Symbol, tf, shift, 1, values) != 1) // perf-allowed: single closed-bar close read.
      return 0.0;
   return values[0];
  }

double DEMAValue(const ENUM_TIMEFRAMES tf, const int period, const int shift)
  {
   if(period <= 1 || shift < 0)
      return 0.0;

   const int bars_needed = MathMax(period * 4, period + 40);
   double close_values[];
   ArraySetAsSeries(close_values, true);
   const int copied = CopyClose(_Symbol, tf, shift, bars_needed, close_values); // perf-allowed: bounded DEMA calculation on new-bar path.
   if(copied < period + 2)
      return 0.0;

   const double alpha = 2.0 / (period + 1.0);
   double ema1 = close_values[copied - 1];
   double ema2 = ema1;
   for(int i = copied - 2; i >= 0; --i)
     {
      ema1 = alpha * close_values[i] + (1.0 - alpha) * ema1;
      ema2 = alpha * ema1 + (1.0 - alpha) * ema2;
     }
   return 2.0 * ema1 - ema2;
  }

void AdvanceState_OnNewBar()
  {
   MqlRates bar[];
   ArraySetAsSeries(bar, true);
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, bar) != 1) // perf-allowed: single closed-bar session-state advance.
      return;

   const int ymd = BrokerYMD(bar[0].time);
   const int hhmm = BrokerHHMM(bar[0].time);
   if(ymd != g_session_ymd)
     {
      g_session_ymd = ymd;
      g_bars_today = 0;
      g_or_high = 0.0;
      g_or_low = 0.0;
      g_or_active = false;
      g_or_complete = false;
      g_vwap_num = 0.0;
      g_vwap_den = 0.0;
      g_vwap = 0.0;
      g_cooldown_remaining = 0;
     }

   g_bars_today++;
   if(g_cooldown_remaining > 0)
      g_cooldown_remaining--;

   if(InHHMMWindow(hhmm, strategy_or_start_hhmm, strategy_or_end_hhmm))
     {
      if(!g_or_active)
        {
         g_or_high = bar[0].high;
         g_or_low = bar[0].low;
         g_or_active = true;
        }
      else
        {
         g_or_high = MathMax(g_or_high, bar[0].high);
         g_or_low = MathMin(g_or_low, bar[0].low);
        }
     }
   else if(g_or_active && !g_or_complete && !InHHMMWindow(hhmm, strategy_or_start_hhmm, strategy_or_end_hhmm))
     {
      g_or_complete = true;
     }

   if(hhmm >= strategy_trade_start_hhmm)
     {
      const double vol = (bar[0].tick_volume > 0) ? (double)bar[0].tick_volume : 1.0;
      const double typical = (bar[0].high + bar[0].low + bar[0].close) / 3.0;
      g_vwap_num += typical * vol;
      g_vwap_den += vol;
      if(g_vwap_den > 0.0)
         g_vwap = g_vwap_num / g_vwap_den;
     }
  }

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, datetime &opened)
  {
   ptype = POSITION_TYPE_BUY;
   opened = 0;

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
      opened = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

int DailyBias()
  {
   const double d_close = ClosedClose(PERIOD_D1, 1);
   const double d_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_daily_ema_period, 1);
   const double adx = QM_ADX(_Symbol, PERIOD_D1, strategy_daily_adx_period, 1);
   const double plus_di = QM_ADX_PlusDI(_Symbol, PERIOD_D1, strategy_daily_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, PERIOD_D1, strategy_daily_adx_period, 1);
   if(d_close <= 0.0 || d_ema <= 0.0 || adx <= 0.0)
      return 0;
   if(d_close > d_ema && adx >= strategy_daily_adx_threshold && plus_di >= minus_di)
      return 1;
   if(d_close < d_ema && adx >= strategy_daily_adx_threshold && minus_di >= plus_di)
      return -1;
   return 0;
  }

int ExecutionDirection()
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double fast_1 = DEMAValue(tf, strategy_dema_fast_period, 1);
   const double slow_1 = DEMAValue(tf, strategy_dema_slow_period, 1);
   const double fast_2 = DEMAValue(tf, strategy_dema_fast_period, 2);
   const double slow_2 = DEMAValue(tf, strategy_dema_slow_period, 2);
   const double close_1 = ClosedClose(tf, 1);
   const double q_ema = QM_EMA(_Symbol, tf, strategy_qtrend_ema_period, 1);
   const double atr = QM_ATR(_Symbol, tf, strategy_ut_atr_period, 1);
   if(fast_1 <= 0.0 || slow_1 <= 0.0 || fast_2 <= 0.0 || slow_2 <= 0.0 ||
      close_1 <= 0.0 || q_ema <= 0.0 || atr <= 0.0)
      return 0;

   const bool dema_long = (fast_1 > slow_1 && fast_2 <= slow_2);
   const bool dema_short = (fast_1 < slow_1 && fast_2 >= slow_2);
   const bool qtrend_long = (close_1 > q_ema);
   const bool qtrend_short = (close_1 < q_ema);
   const bool ut_long = (close_1 > q_ema + atr * strategy_ut_atr_mult);
   const bool ut_short = (close_1 < q_ema - atr * strategy_ut_atr_mult);

   if(dema_long && qtrend_long && ut_long)
      return 1;
   if(dema_short && qtrend_short && ut_short)
      return -1;

   if(fast_1 > slow_1 && qtrend_long && ut_long)
      return 1;
   if(fast_1 < slow_1 && qtrend_short && ut_short)
      return -1;
   return 0;
  }

bool ZoneAndVolumeStrength(const int dir)
  {
   const int lookback = MathMax(strategy_zone_lookback, strategy_volume_lookback) + 2;
   if(lookback <= 4)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, lookback, rates); // perf-allowed: bounded zone/volume proxy on new-bar path.
   if(copied < lookback)
      return false;

   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   for(int i = 0; i < strategy_zone_lookback && i < copied; ++i)
     {
      hi = MathMax(hi, rates[i].high);
      lo = MathMin(lo, rates[i].low);
     }
   if(hi <= lo || rates[0].close <= 0.0)
      return false;

   double vol_sum = 0.0;
   int vol_n = 0;
   for(int i = 1; i <= strategy_volume_lookback && i < copied; ++i)
     {
      vol_sum += (double)rates[i].tick_volume;
      vol_n++;
     }
   if(vol_n <= 0)
      return false;
   const double avg_vol = vol_sum / (double)vol_n;
   const bool volume_ok = ((double)rates[0].tick_volume >= avg_vol * strategy_volume_strength_mult);

   const double zone = (hi - lo) * strategy_zone_edge_pct;
   const bool zone_ok = (dir > 0) ? (rates[0].close <= lo + zone || rates[0].close > g_or_high)
                                  : (rates[0].close >= hi - zone || rates[0].close < g_or_low);
   return (zone_ok && volume_ok);
  }

bool ContextAllows(const int dir)
  {
   const double close_1 = ClosedClose((ENUM_TIMEFRAMES)_Period, 1);
   if(close_1 <= 0.0)
      return false;

   if(strategy_vwap_chop_filter)
     {
      if(g_vwap <= 0.0)
         return false;
      if(dir > 0 && close_1 <= g_vwap)
         return false;
      if(dir < 0 && close_1 >= g_vwap)
         return false;
     }

   if(strategy_opening_range_filter)
     {
      if(!g_or_complete || g_or_high <= g_or_low)
         return false;
      if(dir > 0 && close_1 <= g_or_high)
         return false;
      if(dir < 0 && close_1 >= g_or_low)
         return false;
     }
   return true;
  }

int ConfluenceScore(const int dir, const int bias, const int exec_dir)
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double d_close = ClosedClose(PERIOD_D1, 1);
   const double d_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_daily_ema_period, 1);
   const double adx = QM_ADX(_Symbol, PERIOD_D1, strategy_daily_adx_period, 1);
   const double plus_di = QM_ADX_PlusDI(_Symbol, PERIOD_D1, strategy_daily_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, PERIOD_D1, strategy_daily_adx_period, 1);
   const double fast = DEMAValue(tf, strategy_dema_fast_period, 1);
   const double slow = DEMAValue(tf, strategy_dema_slow_period, 1);
   const double fast_prev = DEMAValue(tf, strategy_dema_fast_period, 2);
   const double slow_prev = DEMAValue(tf, strategy_dema_slow_period, 2);
   const double close_1 = ClosedClose(tf, 1);
   const double q_ema = QM_EMA(_Symbol, tf, strategy_qtrend_ema_period, 1);
   const double atr = QM_ATR(_Symbol, tf, strategy_ut_atr_period, 1);

   int score = 0;
   if(bias == dir)
      score++;
   if(adx >= strategy_daily_adx_threshold)
      score++;
   if((dir > 0 && plus_di >= minus_di) || (dir < 0 && minus_di >= plus_di))
      score++;
   if((dir > 0 && fast > slow) || (dir < 0 && fast < slow))
      score++;
   if((dir > 0 && fast > slow && fast_prev <= slow_prev) ||
      (dir < 0 && fast < slow && fast_prev >= slow_prev))
      score++;
   if((dir > 0 && close_1 > q_ema) || (dir < 0 && close_1 < q_ema))
      score++;
   if((dir > 0 && close_1 > q_ema + atr * strategy_ut_atr_mult) ||
      (dir < 0 && close_1 < q_ema - atr * strategy_ut_atr_mult))
      score++;
   if(ContextAllows(dir))
      score++;
   if(ZoneAndVolumeStrength(dir))
      score++;

   if(d_close <= 0.0 || d_ema <= 0.0 || exec_dir != dir)
      return 0;
   return score;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   const int hhmm = BrokerHHMM(TimeCurrent());
   if(!InHHMMWindow(hhmm, strategy_trade_start_hhmm, strategy_trade_end_hhmm))
     {
      ENUM_POSITION_TYPE ptype;
      datetime opened = 0;
      if(!GetOurPosition(ptype, opened))
         return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ResetEntryRequest(req);
   AdvanceState_OnNewBar();

   if(strategy_daily_ema_period <= 1 || strategy_daily_adx_period <= 1 ||
      strategy_dema_fast_period <= 1 || strategy_dema_slow_period <= strategy_dema_fast_period ||
      strategy_qtrend_ema_period <= 1 || strategy_ut_atr_period <= 1 ||
      strategy_atr_period <= 1 || strategy_atr_sl_mult <= 0.0 ||
      strategy_rr_target <= 0.0 || strategy_score_threshold < 1)
      return false;

   const int bias = DailyBias();
   const int exec_dir = ExecutionDirection();
   g_last_exec_dir = exec_dir;
   if(!InHHMMWindow(BrokerHHMM(TimeCurrent()), strategy_trade_start_hhmm, strategy_trade_end_hhmm))
      return false;
   if(bias == 0 || exec_dir == 0 || bias != exec_dir)
      return false;

   g_last_score = ConfluenceScore(exec_dir, bias, exec_dir);
   if(g_last_score < strategy_score_threshold)
      return false;
   if(!ContextAllows(exec_dir))
      return false;
   if(g_cooldown_remaining > 0)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const QM_OrderType side = (exec_dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_rr_target);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (exec_dir > 0) ? "DAILY_BIAS_LONG" : "DAILY_BIAS_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_cooldown_remaining = strategy_cooldown_bars;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline keeps optional breakeven disabled for P2.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime opened = 0;
   if(!GetOurPosition(ptype, opened))
      return false;

   if(!InHHMMWindow(BrokerHHMM(TimeCurrent()), strategy_trade_start_hhmm, strategy_trade_end_hhmm))
      return true;

   if(strategy_max_bars_in_trade > 0 && opened > 0)
     {
      const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(seconds_per_bar > 0 &&
         TimeCurrent() - opened >= (long)seconds_per_bar * strategy_max_bars_in_trade)
         return true;
     }

   if(ptype == POSITION_TYPE_BUY && g_last_exec_dir < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && g_last_exec_dir > 0)
      return true;

   return false;
  }

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
