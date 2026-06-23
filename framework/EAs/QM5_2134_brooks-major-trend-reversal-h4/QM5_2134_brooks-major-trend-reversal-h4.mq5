#property strict
#property version   "5.0"
#property description "QM5_2134 Brooks Major Trend Reversal H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2134;
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
input int    strategy_lookback_h4_bars       = 200;
input int    strategy_pivot_wing_bars        = 2;
input int    strategy_leg_max_h4_bars        = 30;
input int    strategy_atr_period             = 20;
input int    strategy_leg_atr_period         = 50;
input int    strategy_d1_ema_period          = 50;
input double strategy_min_leg1_atr_mult      = 2.0;
input double strategy_leg2_retrace_min       = 0.50;
input double strategy_leg2_retrace_max       = 0.78;
input double strategy_breakout_body_atr_mult = 0.80;
input double strategy_initial_stop_atr_mult  = 0.50;
input double strategy_spread_atr_mult        = 0.30;
input double strategy_trail_atr_mult         = 2.0;
input int    strategy_time_stop_h4_bars      = 100;

struct MtrSetup
  {
   bool     valid;
   int      side;
   double   hh;
   double   ll;
   double   h2;
   double   l2;
   double   l3;
   double   h3;
   double   target1;
   double   target2;
   double   stop;
   datetime pattern_time;
   bool     d1_aligned;
  };

int      g_active_side = 0;
double   g_active_target1 = 0.0;
double   g_active_l3 = 0.0;
double   g_active_h3 = 0.0;
datetime g_active_pattern_time = 0;
datetime g_consumed_pattern_time = 0;
bool     g_target1_done = false;
bool     g_half_size_requested = false;
bool     g_half_size_done = false;

void ClearSetup(MtrSetup &setup)
  {
   setup.valid = false;
   setup.side = 0;
   setup.hh = 0.0;
   setup.ll = 0.0;
   setup.h2 = 0.0;
   setup.l2 = 0.0;
   setup.l3 = 0.0;
   setup.h3 = 0.0;
   setup.target1 = 0.0;
   setup.target2 = 0.0;
   setup.stop = 0.0;
   setup.pattern_time = 0;
   setup.d1_aligned = false;
  }

bool ParamsValid()
  {
   return strategy_lookback_h4_bars >= 50 &&
          strategy_pivot_wing_bars >= 1 &&
          strategy_leg_max_h4_bars > 0 &&
          strategy_atr_period > 0 &&
          strategy_leg_atr_period > 0 &&
          strategy_d1_ema_period > 0 &&
          strategy_min_leg1_atr_mult > 0.0 &&
          strategy_leg2_retrace_min > 0.0 &&
          strategy_leg2_retrace_max > strategy_leg2_retrace_min &&
          strategy_leg2_retrace_max < 1.0 &&
          strategy_breakout_body_atr_mult > 0.0 &&
          strategy_initial_stop_atr_mult > 0.0 &&
          strategy_spread_atr_mult >= 0.0 &&
          strategy_trail_atr_mult > 0.0 &&
          strategy_time_stop_h4_bars > 0;
  }

bool IsPivotHigh(const MqlRates &rates[], const int idx, const int wing, const int copied)
  {
   if(idx < wing || idx + wing >= copied)
      return false;

   const double v = rates[idx].high;
   if(v <= 0.0)
      return false;

   for(int j = 1; j <= wing; ++j)
     {
      if(v <= rates[idx - j].high || v < rates[idx + j].high)
         return false;
     }
   return true;
  }

bool IsPivotLow(const MqlRates &rates[], const int idx, const int wing, const int copied)
  {
   if(idx < wing || idx + wing >= copied)
      return false;

   const double v = rates[idx].low;
   if(v <= 0.0)
      return false;

   for(int j = 1; j <= wing; ++j)
     {
      if(v >= rates[idx - j].low || v > rates[idx + j].low)
         return false;
     }
   return true;
  }

bool FindStrongestDownLeg(const MqlRates &rates[],
                          const int copied,
                          const int wing,
                          double &hh,
                          double &ll,
                          int &hh_idx,
                          int &ll_idx)
  {
   hh = 0.0;
   ll = 0.0;
   hh_idx = -1;
   ll_idx = -1;

   double best_high = 0.0;
   int best_high_idx = -1;
   double best_move = 0.0;

   for(int idx = copied - wing - 1; idx >= wing; --idx)
     {
      if(IsPivotHigh(rates, idx, wing, copied))
        {
         if(rates[idx].high > best_high)
           {
            best_high = rates[idx].high;
            best_high_idx = idx;
           }
        }

      if(best_high_idx >= 0 && IsPivotLow(rates, idx, wing, copied))
        {
         const double move = best_high - rates[idx].low;
         if(move > best_move)
           {
            best_move = move;
            hh = best_high;
            ll = rates[idx].low;
            hh_idx = best_high_idx;
            ll_idx = idx;
           }
        }
     }

   return (hh_idx >= 0 && ll_idx >= 0 && hh > ll);
  }

bool FindStrongestUpLeg(const MqlRates &rates[],
                        const int copied,
                        const int wing,
                        double &hh,
                        double &ll,
                        int &hh_idx,
                        int &ll_idx)
  {
   hh = 0.0;
   ll = 0.0;
   hh_idx = -1;
   ll_idx = -1;

   double best_low = 0.0;
   int best_low_idx = -1;
   double best_move = 0.0;

   for(int idx = copied - wing - 1; idx >= wing; --idx)
     {
      if(IsPivotLow(rates, idx, wing, copied))
        {
         if(best_low_idx < 0 || rates[idx].low < best_low)
           {
            best_low = rates[idx].low;
            best_low_idx = idx;
           }
        }

      if(best_low_idx >= 0 && IsPivotHigh(rates, idx, wing, copied))
        {
         const double move = rates[idx].high - best_low;
         if(move > best_move)
           {
            best_move = move;
            hh = rates[idx].high;
            ll = best_low;
            hh_idx = idx;
            ll_idx = best_low_idx;
           }
        }
     }

   return (hh_idx >= 0 && ll_idx >= 0 && hh > ll);
  }

bool FindLongSetup(const MqlRates &rates[],
                   const int copied,
                   const double atr20,
                   const double atr50,
                   const double d1_ema,
                   MtrSetup &setup)
  {
   ClearSetup(setup);

   int hh_idx = -1;
   int ll_idx = -1;
   double hh = 0.0;
   double ll = 0.0;
   const int wing = strategy_pivot_wing_bars;
   if(!FindStrongestDownLeg(rates, copied, wing, hh, ll, hh_idx, ll_idx))
      return false;

   const double leg_range = hh - ll;
   if(leg_range < strategy_min_leg1_atr_mult * atr50)
      return false;

   int h2_idx = -1;
   double h2 = 0.0;
   const int h2_floor = (ll_idx - strategy_leg_max_h4_bars > wing) ? (ll_idx - strategy_leg_max_h4_bars) : wing;
   for(int idx = ll_idx - 1; idx >= h2_floor; --idx)
     {
      if(!IsPivotHigh(rates, idx, wing, copied))
         continue;
      const double retrace = (rates[idx].high - ll) / leg_range;
      if(retrace < strategy_leg2_retrace_min || retrace > strategy_leg2_retrace_max)
         continue;
      if(rates[idx].high > h2)
        {
         h2 = rates[idx].high;
         h2_idx = idx;
        }
     }
   if(h2_idx < 0)
      return false;

   int l3_idx = -1;
   double l3 = 0.0;
   const int l3_floor = (h2_idx - strategy_leg_max_h4_bars > wing) ? (h2_idx - strategy_leg_max_h4_bars) : wing;
   for(int idx = h2_idx - 1; idx >= l3_floor; --idx)
     {
      if(!IsPivotLow(rates, idx, wing, copied))
         continue;
      if(rates[idx].low <= ll || rates[idx].low >= h2)
         continue;
      if(l3_idx < 0 || rates[idx].low < l3)
        {
         l3 = rates[idx].low;
         l3_idx = idx;
        }
     }
   if(l3_idx < 0)
      return false;

   const MqlRates breakout = rates[0];
   if(breakout.high <= h2 || breakout.close <= h2 || breakout.close <= breakout.open)
      return false;
   if((breakout.close - breakout.open) < strategy_breakout_body_atr_mult * atr20)
      return false;
   if(rates[l3_idx].time == g_consumed_pattern_time)
      return false;

   setup.valid = true;
   setup.side = 1;
   setup.hh = hh;
   setup.ll = ll;
   setup.h2 = h2;
   setup.l3 = l3;
   setup.target1 = hh;
   setup.target2 = hh + leg_range;
   setup.stop = l3 - strategy_initial_stop_atr_mult * atr20;
   setup.pattern_time = rates[l3_idx].time;
   setup.d1_aligned = (breakout.close > d1_ema);
   return (setup.stop > 0.0 && setup.stop < SymbolInfoDouble(_Symbol, SYMBOL_ASK));
  }

bool FindShortSetup(const MqlRates &rates[],
                    const int copied,
                    const double atr20,
                    const double atr50,
                    const double d1_ema,
                    MtrSetup &setup)
  {
   ClearSetup(setup);

   int hh_idx = -1;
   int ll_idx = -1;
   double hh = 0.0;
   double ll = 0.0;
   const int wing = strategy_pivot_wing_bars;
   if(!FindStrongestUpLeg(rates, copied, wing, hh, ll, hh_idx, ll_idx))
      return false;

   const double leg_range = hh - ll;
   if(leg_range < strategy_min_leg1_atr_mult * atr50)
      return false;

   int l2_idx = -1;
   double l2 = 0.0;
   const int l2_floor = (hh_idx - strategy_leg_max_h4_bars > wing) ? (hh_idx - strategy_leg_max_h4_bars) : wing;
   for(int idx = hh_idx - 1; idx >= l2_floor; --idx)
     {
      if(!IsPivotLow(rates, idx, wing, copied))
         continue;
      const double retrace = (hh - rates[idx].low) / leg_range;
      if(retrace < strategy_leg2_retrace_min || retrace > strategy_leg2_retrace_max)
         continue;
      if(l2_idx < 0 || rates[idx].low < l2)
        {
         l2 = rates[idx].low;
         l2_idx = idx;
        }
     }
   if(l2_idx < 0)
      return false;

   int h3_idx = -1;
   double h3 = 0.0;
   const int h3_floor = (l2_idx - strategy_leg_max_h4_bars > wing) ? (l2_idx - strategy_leg_max_h4_bars) : wing;
   for(int idx = l2_idx - 1; idx >= h3_floor; --idx)
     {
      if(!IsPivotHigh(rates, idx, wing, copied))
         continue;
      if(rates[idx].high >= hh || rates[idx].high <= l2)
         continue;
      if(rates[idx].high > h3)
        {
         h3 = rates[idx].high;
         h3_idx = idx;
        }
     }
   if(h3_idx < 0)
      return false;

   const MqlRates breakout = rates[0];
   if(breakout.low >= l2 || breakout.close >= l2 || breakout.close >= breakout.open)
      return false;
   if((breakout.open - breakout.close) < strategy_breakout_body_atr_mult * atr20)
      return false;
   if(rates[h3_idx].time == g_consumed_pattern_time)
      return false;

   setup.valid = true;
   setup.side = -1;
   setup.hh = hh;
   setup.ll = ll;
   setup.l2 = l2;
   setup.h3 = h3;
   setup.target1 = ll;
   setup.target2 = ll - leg_range;
   setup.stop = h3 + strategy_initial_stop_atr_mult * atr20;
   setup.pattern_time = rates[h3_idx].time;
   setup.d1_aligned = (breakout.close < d1_ema);
   return (setup.stop > SymbolInfoDouble(_Symbol, SYMBOL_BID));
  }

bool FindOurPosition(ulong &ticket,
                     ENUM_POSITION_TYPE &position_type,
                     double &volume,
                     datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   volume = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      volume = PositionGetDouble(POSITION_VOLUME);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

int H4BarsHeld(const datetime open_time)
  {
   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(open_time <= 0 || h4_seconds <= 0)
      return 0;
   const int bars = (int)((TimeCurrent() - open_time) / h4_seconds);
   return (bars > 0) ? bars : 0;
  }

void ActivateSetup(const MtrSetup &setup)
  {
   g_active_side = setup.side;
   g_active_target1 = setup.target1;
   g_active_l3 = setup.l3;
   g_active_h3 = setup.h3;
   g_active_pattern_time = setup.pattern_time;
   g_consumed_pattern_time = setup.pattern_time;
   g_target1_done = false;
   g_half_size_requested = !setup.d1_aligned;
   g_half_size_done = setup.d1_aligned;
  }

// Return TRUE to BLOCK trading this tick. Framework time/news/Friday guards run
// before this hook; this strategy adds the card's spread filter.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H4)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   if(ask > bid && (ask - bid) > strategy_spread_atr_mult * atr)
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

   if(!ParamsValid())
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr20 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double atr50 = QM_ATR(_Symbol, PERIOD_H4, strategy_leg_atr_period, 1);
   const double d1_ema = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_ema_period, 1, PRICE_CLOSE);
   if(atr20 <= 0.0 || atr50 <= 0.0 || d1_ema <= 0.0)
      return false;

   const int needed = strategy_lookback_h4_bars + strategy_pivot_wing_bars + 8;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, needed, rates); // perf-allowed: bounded Brooks MTR swing-leg OHLC scan; Strategy_EntrySignal is called only after the framework QM_IsNewBar gate.
   if(copied < strategy_lookback_h4_bars)
      return false;

   MtrSetup long_setup;
   MtrSetup short_setup;
   ClearSetup(long_setup);
   ClearSetup(short_setup);
   const bool have_long = FindLongSetup(rates, copied, atr20, atr50, d1_ema, long_setup);
   const bool have_short = FindShortSetup(rates, copied, atr20, atr50, d1_ema, short_setup);
   if(!have_long && !have_short)
      return false;

   MtrSetup selected;
   ClearSetup(selected);
   if(have_long && have_short)
     {
      if(long_setup.pattern_time >= short_setup.pattern_time)
         selected = long_setup;
      else
         selected = short_setup;
     }
   else if(have_long)
      selected = long_setup;
   else
      selected = short_setup;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(selected.side > 0)
     {
      req.type = QM_BUY;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, selected.stop);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, selected.target2);
      req.reason = selected.d1_aligned ? "BROOKS_MTR_LONG_D1_ALIGNED" : "BROOKS_MTR_LONG_D1_COUNTER_HALF";
      if(req.sl <= 0.0 || req.sl >= ask || req.tp <= ask)
         return false;
     }
   else
     {
      req.type = QM_SELL;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, selected.stop);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, selected.target2);
      req.reason = selected.d1_aligned ? "BROOKS_MTR_SHORT_D1_ALIGNED" : "BROOKS_MTR_SHORT_D1_COUNTER_HALF";
      if(req.sl <= bid || req.tp <= 0.0 || req.tp >= bid)
         return false;
     }

   ActivateSetup(selected);
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double volume;
   datetime open_time;
   if(!FindOurPosition(ticket, position_type, volume, open_time))
      return;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0 || volume <= 0.0)
      return;

   if(g_half_size_requested && !g_half_size_done)
     {
      const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(volume * 0.5 >= min_lot)
         QM_TM_PartialClose(ticket, volume * 0.5, QM_EXIT_PARTIAL);
      g_half_size_done = true;
      return;
     }

   if(!g_target1_done && g_active_target1 > 0.0)
     {
      const bool target_hit = (is_buy && market >= g_active_target1) ||
                              (!is_buy && market <= g_active_target1);
      if(target_hit)
        {
         const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         if(volume * 0.5 >= min_lot)
            QM_TM_PartialClose(ticket, volume * 0.5, QM_EXIT_PARTIAL);
         g_target1_done = true;
        }
     }

   if(g_target1_done)
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double volume;
   datetime open_time;
   if(!FindOurPosition(ticket, position_type, volume, open_time))
      return false;

   if(H4BarsHeld(open_time) >= strategy_time_stop_h4_bars)
      return true;

   MqlRates bar[];
   ArraySetAsSeries(bar, true);
   if(CopyRates(_Symbol, PERIOD_H4, 1, 1, bar) != 1) // perf-allowed: single closed-bar read for Brooks L3/H3 death-signal exit.
      return false;

   if(position_type == POSITION_TYPE_BUY && g_active_l3 > 0.0 && bar[0].close < g_active_l3)
      return true;
   if(position_type == POSITION_TYPE_SELL && g_active_h3 > 0.0 && bar[0].close > g_active_h3)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_2134\",\"strategy\":\"brooks_major_trend_reversal_h4\"}");
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
