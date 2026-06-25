#property strict
#property version   "5.0"
#property description "QM5_9257 MQL5 geometric asymmetry breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9257;
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
input int    strategy_fractal_strength        = 2;
input int    strategy_lookback_bars           = 160;
input int    strategy_min_structure_bars      = 8;
input int    strategy_atr_period              = 14;
input double strategy_min_range_atr           = 0.60;
input double strategy_max_range_atr           = 3.00;
input double strategy_distance_ratio          = 1.20;
input double strategy_slope_ratio             = 1.20;
input double strategy_time_compression_ratio  = 0.80;
input int    strategy_min_geometry_votes      = 2;
input double strategy_boundary_atr_mult       = 0.25;
input int    strategy_boundary_touch_bars     = 6;
input int    strategy_max_lock_bars           = 12;
input int    strategy_min_bars_between_signals = 6;
input double strategy_stop_atr_mult           = 0.50;
input double strategy_take_profit_rr          = 2.50;

struct Strategy_Swing
{
   int    type;   // +1 swing high, -1 swing low
   int    idx;    // series index in rates[]; 0 is latest closed bar
   double price;
};

bool   g_lock_active        = false;
int    g_lock_dir           = 0;
int    g_lock_age_bars      = 0;
double g_lock_high          = 0.0;
double g_lock_low           = 0.0;
double g_lock_atr           = 0.0;
bool   g_pending_exit       = false;
int    g_entry_dir          = 0;
double g_entry_range_high   = 0.0;
double g_entry_range_low    = 0.0;
int    g_bars_since_signal  = 1000000;

void Strategy_ResetLock()
  {
   g_lock_active = false;
   g_lock_dir = 0;
   g_lock_age_bars = 0;
   g_lock_high = 0.0;
   g_lock_low = 0.0;
   g_lock_atr = 0.0;
  }

void Strategy_ResetEntryState()
  {
   g_pending_exit = false;
   g_entry_dir = 0;
   g_entry_range_high = 0.0;
   g_entry_range_low = 0.0;
  }

bool Strategy_ReadRates(MqlRates &rates[], const int count)
  {
   if(count <= 0)
      return false;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, count, rates); // perf-allowed: bounded closed-bar fractal/range scan; Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
   return (copied == count);
  }

bool Strategy_IsFractalHigh(const MqlRates &rates[], const int count, const int idx, const int strength)
  {
   if(idx < strength || idx >= count - strength)
      return false;
   const double p = rates[idx].high;
   if(p <= 0.0)
      return false;
   for(int k = 1; k <= strength; ++k)
     {
      if(rates[idx - k].high >= p || rates[idx + k].high > p)
         return false;
     }
   return true;
  }

bool Strategy_IsFractalLow(const MqlRates &rates[], const int count, const int idx, const int strength)
  {
   if(idx < strength || idx >= count - strength)
      return false;
   const double p = rates[idx].low;
   if(p <= 0.0)
      return false;
   for(int k = 1; k <= strength; ++k)
     {
      if(rates[idx - k].low <= p || rates[idx + k].low < p)
         return false;
     }
   return true;
  }

void Strategy_AddSwing(Strategy_Swing &swings[], int &count, const int max_count, const int type, const int idx, const double price)
  {
   if(count >= max_count || price <= 0.0)
      return;
   swings[count].type = type;
   swings[count].idx = idx;
   swings[count].price = price;
   ++count;
  }

bool Strategy_RecentAlternatingSwings(const MqlRates &rates[],
                                      const int count,
                                      const int strength,
                                      Strategy_Swing &latest,
                                      Strategy_Swing &middle,
                                      Strategy_Swing &older)
  {
   Strategy_Swing raw[];
   const int max_raw = 48;
   ArrayResize(raw, max_raw);
   int raw_count = 0;

   for(int idx = strength; idx < count - strength && raw_count < max_raw; ++idx)
     {
      if(Strategy_IsFractalHigh(rates, count, idx, strength))
         Strategy_AddSwing(raw, raw_count, max_raw, 1, idx, rates[idx].high);
      if(Strategy_IsFractalLow(rates, count, idx, strength))
         Strategy_AddSwing(raw, raw_count, max_raw, -1, idx, rates[idx].low);
     }

   for(int i = 0; i <= raw_count - 3; ++i)
     {
      if(raw[i].type == raw[i + 1].type || raw[i + 1].type == raw[i + 2].type)
         continue;
      latest = raw[i];
      middle = raw[i + 1];
      older = raw[i + 2];
      return true;
     }

   return false;
  }

bool Strategy_TouchedBoundary(const MqlRates &rates[],
                              const int count,
                              const int dir,
                              const double range_high,
                              const double range_low,
                              const double proximity)
  {
   const int bars = MathMax(1, MathMin(strategy_boundary_touch_bars, count));
   for(int i = 0; i < bars; ++i)
     {
      if(dir > 0 && rates[i].high >= range_high - proximity)
         return true;
      if(dir < 0 && rates[i].low <= range_low + proximity)
         return true;
     }
   return false;
  }

bool Strategy_BuildLockedSetup(const MqlRates &rates[], const int count)
  {
   const int strength = MathMax(1, strategy_fractal_strength);
   Strategy_Swing latest;
   Strategy_Swing middle;
   Strategy_Swing older;
   if(!Strategy_RecentAlternatingSwings(rates, count, strength, latest, middle, older))
      return false;

   const int duration = older.idx - latest.idx;
   if(duration < MathMax(1, strategy_min_structure_bars))
      return false;

   double range_high = -DBL_MAX;
   double range_low = DBL_MAX;
   if(latest.type > 0) range_high = MathMax(range_high, latest.price); else range_low = MathMin(range_low, latest.price);
   if(middle.type > 0) range_high = MathMax(range_high, middle.price); else range_low = MathMin(range_low, middle.price);
   if(older.type > 0) range_high = MathMax(range_high, older.price); else range_low = MathMin(range_low, older.price);
   if(range_high <= 0.0 || range_low <= 0.0 || range_high <= range_low)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double range_height = range_high - range_low;
   if(range_height < strategy_min_range_atr * atr || range_height > strategy_max_range_atr * atr)
      return false;

   const int dir = (latest.type > 0 && middle.type < 0) ? 1 : ((latest.type < 0 && middle.type > 0) ? -1 : 0);
   if(dir == 0)
      return false;

   const double proximity = MathMax(atr * strategy_boundary_atr_mult, SymbolInfoDouble(_Symbol, SYMBOL_POINT));
   if(proximity <= 0.0)
      return false;
   if(dir > 0 && latest.price < range_high - proximity)
      return false;
   if(dir < 0 && latest.price > range_low + proximity)
      return false;
   if(!Strategy_TouchedBoundary(rates, count, dir, range_high, range_low, proximity))
      return false;

   const double latest_leg = MathAbs(latest.price - middle.price);
   const double prior_leg = MathAbs(middle.price - older.price);
   if(prior_leg <= 0.0 || latest_leg <= 0.0)
      return false;

   const int latest_time = MathMax(1, middle.idx - latest.idx);
   const int prior_time = MathMax(1, older.idx - middle.idx);
   const double latest_slope = latest_leg / (double)latest_time;
   const double prior_slope = prior_leg / (double)prior_time;

   int votes = 0;
   if(latest_leg >= prior_leg * strategy_distance_ratio)
      ++votes;
   if(prior_slope > 0.0 && latest_slope >= prior_slope * strategy_slope_ratio)
      ++votes;
   if((double)latest_time <= (double)prior_time * strategy_time_compression_ratio)
      ++votes;
   if(votes < MathMax(1, strategy_min_geometry_votes))
      return false;

   g_lock_active = true;
   g_lock_dir = dir;
   g_lock_age_bars = 0;
   g_lock_high = range_high;
   g_lock_low = range_low;
   g_lock_atr = atr;
   return true;
  }

bool Strategy_GetOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   return (QM_TM_OpenPositionCount(magic) > 0);
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

   if(g_bars_since_signal < 1000000)
      ++g_bars_since_signal;

   const int strength = MathMax(1, strategy_fractal_strength);
   const int lookback = MathMax(strategy_lookback_bars, 2 * strength + 20);
   MqlRates rates[];
   if(!Strategy_ReadRates(rates, lookback))
      return false;
   const double close1 = rates[0].close;
   if(close1 <= 0.0)
      return false;

   if(Strategy_GetOurPosition())
     {
      if(g_entry_dir != 0 && g_entry_range_high > g_entry_range_low)
        {
         const bool inside_range = (close1 <= g_entry_range_high && close1 >= g_entry_range_low);
         if(inside_range)
            g_pending_exit = true;
        }
      return false;
     }

   Strategy_ResetEntryState();

   if(g_lock_active)
     {
      ++g_lock_age_bars;
      if(g_lock_age_bars > MathMax(1, strategy_max_lock_bars))
         Strategy_ResetLock();
     }

   if(!g_lock_active)
     {
      if(g_bars_since_signal < MathMax(0, strategy_min_bars_between_signals))
         return false;
      Strategy_BuildLockedSetup(rates, lookback);
     }

   if(!g_lock_active)
      return false;

   const bool long_break = (g_lock_dir > 0 && close1 > g_lock_high);
   const bool short_break = (g_lock_dir < 0 && close1 < g_lock_low);
   if(!long_break && !short_break)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double atr = (g_lock_atr > 0.0) ? g_lock_atr : QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0 || g_lock_high <= g_lock_low)
      return false;
   const double range_height = g_lock_high - g_lock_low;

   if(long_break)
     {
      const double entry = ask;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_lock_low - strategy_stop_atr_mult * atr);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double rr_tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_take_profit_rr);
      const double range_tp = QM_StopRulesNormalizePrice(_Symbol, entry + range_height);
      if(rr_tp <= entry || range_tp <= entry)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = MathMin(rr_tp, range_tp);
      req.reason = "ga_breakout_long";
      g_entry_dir = 1;
     }
   else
     {
      const double entry = bid;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_lock_high + strategy_stop_atr_mult * atr);
      if(sl <= 0.0 || sl <= entry)
         return false;
      const double rr_tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_take_profit_rr);
      const double range_tp = QM_StopRulesNormalizePrice(_Symbol, entry - range_height);
      if(rr_tp <= 0.0 || range_tp <= 0.0 || rr_tp >= entry || range_tp >= entry)
         return false;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = MathMax(rr_tp, range_tp);
      req.reason = "ga_breakout_short";
      g_entry_dir = -1;
     }

   g_entry_range_high = g_lock_high;
   g_entry_range_low = g_lock_low;
   g_pending_exit = false;
   g_bars_since_signal = 0;
   Strategy_ResetLock();
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_GetOurPosition())
     {
      Strategy_ResetEntryState();
      return false;
     }
   return g_pending_exit;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9257_mql5-ga-breakout\"}");
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
