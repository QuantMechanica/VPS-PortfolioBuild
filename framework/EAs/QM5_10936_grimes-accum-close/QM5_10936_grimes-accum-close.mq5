#property strict
#property version   "5.0"
#property description "QM5_10936 Grimes accumulation close breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10936;
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
input ENUM_TIMEFRAMES strategy_timeframe            = PERIOD_M15;
input int    strategy_session_start_hhmm            = 1400;
input int    strategy_session_end_hhmm              = 2200;
input int    strategy_opening_range_bars            = 8;
input int    strategy_consolidation_start_bar       = 9;
input int    strategy_consolidation_end_bar         = 22;
input int    strategy_atr_period                    = 20;
input int    strategy_ema_period                    = 20;
input int    strategy_adx_period                    = 14;
input double strategy_midpoint_atr_mult             = 1.50;
input double strategy_probe_atr_mult                = 0.10;
input double strategy_vwap_proxy_atr_mult           = 0.75;
input double strategy_adx_max_before_breakout       = 30.0;
input double strategy_breakout_bar_atr_max          = 2.0;
input double strategy_stop_atr_mult                 = 0.25;
input double strategy_target_r_mult                 = 1.50;
input double strategy_breakeven_r_mult              = 0.80;
input double strategy_min_width_r_mult              = 0.75;
input int    strategy_max_spread_points             = 500;
input int    strategy_history_bars                  = 96;

double g_active_cons_high = 0.0;
double g_active_cons_low = 0.0;
int    g_active_direction = 0;
int    g_inside_close_count = 0;

int Strategy_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

datetime Strategy_DateWithHhmm(const datetime t, const int hhmm)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = MathMax(0, MathMin(23, hhmm / 100));
   dt.min = MathMax(0, MathMin(59, hhmm % 100));
   dt.sec = 0;
   return StructToTime(dt);
  }

datetime Strategy_SessionStartFor(const datetime t)
  {
   datetime start = Strategy_DateWithHhmm(t, strategy_session_start_hhmm);
   datetime end = Strategy_DateWithHhmm(t, strategy_session_end_hhmm);
   if(end <= start)
      end += 86400;
   if(t < start && strategy_session_end_hhmm <= strategy_session_start_hhmm)
      start -= 86400;
   return start;
  }

datetime Strategy_SessionEndFor(const datetime t)
  {
   datetime start = Strategy_SessionStartFor(t);
   datetime end = Strategy_DateWithHhmm(start, strategy_session_end_hhmm);
   if(end <= start)
      end += 86400;
   return end;
  }

bool Strategy_TimeInSession(const datetime t)
  {
   const datetime start = Strategy_SessionStartFor(t);
   const datetime end = Strategy_SessionEndFor(t);
   return (t >= start && t < end);
  }

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, double &open_price, double &sl, double &tp)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_price = 0.0;
   sl = 0.0;
   tp = 0.0;

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
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      return true;
     }

   return false;
  }

void Strategy_ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

void Strategy_UpdateInsideCountFromClosedBar(const MqlRates &bar)
  {
   if(g_active_direction == 0 || g_active_cons_high <= 0.0 || g_active_cons_low <= 0.0)
      return;

   const bool inside = (bar.close >= g_active_cons_low && bar.close <= g_active_cons_high);
   if(inside)
      g_inside_close_count++;
   else
      g_inside_close_count = 0;
  }

bool Strategy_BuildSetupFromClosedBars(QM_EntryRequest &req)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int bars_to_read = MathMax(strategy_history_bars, strategy_consolidation_end_bar + 12);
   const int got = CopyRates(_Symbol, strategy_timeframe, 0, bars_to_read, rates); // perf-allowed: bounded M15 structural read inside framework new-bar entry hook.
   if(got < strategy_consolidation_end_bar + 3)
      return false;

   ulong pos_ticket = 0;
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   double pos_open = 0.0, pos_sl = 0.0, pos_tp = 0.0;
   if(Strategy_SelectOurPosition(pos_ticket, pos_type, pos_open, pos_sl, pos_tp))
     {
      Strategy_UpdateInsideCountFromClosedBar(rates[1]);
      return false;
     }

   g_active_direction = 0;
   g_inside_close_count = 0;

   const datetime last_closed_time = rates[1].time;
   if(!Strategy_TimeInSession(last_closed_time))
      return false;

   const datetime session_start = Strategy_SessionStartFor(last_closed_time);
   const datetime session_end = Strategy_SessionEndFor(last_closed_time);
   int session_idx[128];
   int session_count = 0;

   for(int i = got - 1; i >= 1 && session_count < 128; --i)
     {
      if(rates[i].time >= session_start && rates[i].time < session_end)
        {
         session_idx[session_count] = i;
         session_count++;
        }
     }

   if(session_count <= strategy_consolidation_end_bar)
      return false;

   const int session_seconds = (int)(session_end - session_start);
   const int session_bars_full = MathMax(1, session_seconds / PeriodSeconds(strategy_timeframe));
   const int min_elapsed_bar = MathMax(strategy_consolidation_end_bar + 1,
                                      (int)MathCeil((double)session_bars_full * 0.60));
   if(session_count < min_elapsed_bar)
      return false;

   const int or_bars = MathMax(1, strategy_opening_range_bars);
   if(session_count < or_bars || strategy_consolidation_start_bar <= or_bars)
      return false;

   double opening_high = -DBL_MAX;
   double opening_low = DBL_MAX;
   for(int j = 0; j < or_bars; ++j)
     {
      const int idx = session_idx[j];
      opening_high = MathMax(opening_high, rates[idx].high);
      opening_low = MathMin(opening_low, rates[idx].low);
     }
   if(opening_high <= 0.0 || opening_low <= 0.0 || opening_high <= opening_low)
      return false;

   const double midpoint = (opening_high + opening_low) * 0.5;
   double cons_high = -DBL_MAX;
   double cons_low = DBL_MAX;
   int downside_probes = 0;
   int upside_probes = 0;
   bool long_cons_ok = true;
   bool short_cons_ok = true;

   for(int bar_num = strategy_consolidation_start_bar; bar_num <= strategy_consolidation_end_bar; ++bar_num)
     {
      const int j = bar_num - 1;
      const int idx = session_idx[j];
      const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, idx);
      const double ema = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, idx);
      if(atr <= 0.0 || ema <= 0.0)
         return false;

      cons_high = MathMax(cons_high, rates[idx].high);
      cons_low = MathMin(cons_low, rates[idx].low);

      if(rates[idx].high > midpoint + strategy_midpoint_atr_mult * atr ||
         rates[idx].low < midpoint - strategy_midpoint_atr_mult * atr)
        {
         long_cons_ok = false;
         short_cons_ok = false;
        }

      if(rates[idx].close < ema - strategy_vwap_proxy_atr_mult * atr)
         long_cons_ok = false;
      if(rates[idx].close > ema + strategy_vwap_proxy_atr_mult * atr)
         short_cons_ok = false;

      double prior_low = DBL_MAX;
      double prior_high = -DBL_MAX;
      for(int p = j - 8; p < j; ++p)
        {
         if(p < 0)
            continue;
         const int pidx = session_idx[p];
         prior_low = MathMin(prior_low, rates[pidx].low);
         prior_high = MathMax(prior_high, rates[pidx].high);
        }

      if(prior_low < DBL_MAX &&
         rates[idx].low < prior_low - strategy_probe_atr_mult * atr &&
         rates[idx].close >= opening_low && rates[idx].close <= opening_high)
         downside_probes++;

      if(prior_high > 0.0 &&
         rates[idx].high > prior_high + strategy_probe_atr_mult * atr &&
         rates[idx].close >= opening_low && rates[idx].close <= opening_high)
         upside_probes++;
     }

   if(cons_high <= 0.0 || cons_low <= 0.0 || cons_high <= cons_low)
      return false;

   const MqlRates breakout = rates[1];
   const double breakout_atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(breakout_atr <= 0.0)
      return false;

   const double adx_before = QM_ADX(_Symbol, strategy_timeframe, strategy_adx_period, 2);
   if(adx_before > strategy_adx_max_before_breakout)
      return false;
   if((breakout.high - breakout.low) > strategy_breakout_bar_atr_max * breakout_atr)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   const double spread_cost = (point > 0.0) ? spread_points * point : 0.0;
   const double width = cons_high - cons_low;

   if(long_cons_ok && downside_probes >= 2 && breakout.close > cons_high)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = cons_low - strategy_stop_atr_mult * breakout_atr;
      const double risk = entry - sl;
      if(entry <= 0.0 || sl <= 0.0 || risk <= 0.0)
         return false;
      if(width < strategy_min_width_r_mult * (risk + spread_cost))
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(entry + strategy_target_r_mult * risk, _Digits);
      req.reason = "grimes_accum_close_long";
      req.symbol_slot = qm_magic_slot_offset;
      g_active_cons_high = cons_high;
      g_active_cons_low = cons_low;
      g_active_direction = 1;
      return true;
     }

   if(short_cons_ok && upside_probes >= 2 && breakout.close < cons_low)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = cons_high + strategy_stop_atr_mult * breakout_atr;
      const double risk = sl - entry;
      if(entry <= 0.0 || sl <= 0.0 || risk <= 0.0)
         return false;
      if(width < strategy_min_width_r_mult * (risk + spread_cost))
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(sl, _Digits);
      req.tp = NormalizeDouble(entry - strategy_target_r_mult * risk, _Digits);
      req.reason = "grimes_accum_close_short";
      req.symbol_slot = qm_magic_slot_offset;
      g_active_cons_high = cons_high;
      g_active_cons_low = cons_low;
      g_active_direction = -1;
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double open_price = 0.0, sl = 0.0, tp = 0.0;
   if(Strategy_SelectOurPosition(ticket, ptype, open_price, sl, tp))
      return false;

   if(!Strategy_TimeInSession(TimeCurrent()))
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetEntryRequest(req);
   return Strategy_BuildSetupFromClosedBars(req);
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double open_price = 0.0, sl = 0.0, tp = 0.0;
   if(!Strategy_SelectOurPosition(ticket, ptype, open_price, sl, tp))
      return;

   const double risk = MathAbs(open_price - sl);
   if(risk <= 0.0)
      return;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market <= 0.0)
      return;

   const double moved = is_buy ? (market - open_price) : (open_price - market);
   if(moved < strategy_breakeven_r_mult * risk)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const bool improves = (sl <= 0.0) ||
                         (is_buy ? (open_price > sl + point * 0.5)
                                 : (open_price < sl - point * 0.5));
   if(improves)
      QM_TM_MoveSL(ticket, NormalizeDouble(open_price, _Digits), "grimes_0_8r_breakeven");
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   double open_price = 0.0, sl = 0.0, tp = 0.0;
   if(!Strategy_SelectOurPosition(ticket, ptype, open_price, sl, tp))
      return false;

   if(TimeCurrent() >= Strategy_SessionEndFor(TimeCurrent()))
      return true;

   if(g_inside_close_count >= 2)
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
