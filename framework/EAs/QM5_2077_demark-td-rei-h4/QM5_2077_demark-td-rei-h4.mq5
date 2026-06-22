#property strict
#property version   "5.0"
#property description "QM5_2077 DeMark TD REI H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2077;
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
input int    strategy_rei_window          = 8;
input double strategy_zone_level          = 45.0;
input int    strategy_max_zone_duration   = 5;
input int    strategy_recent_lookback     = 5;
input int    strategy_d1_sma_period       = 100;
input bool   strategy_use_d1_sma_gate     = true;
input int    strategy_atr_period          = 14;
input double strategy_stop_atr_buffer     = 0.50;
input double strategy_mid_target_atr_mult = 1.50;
input double strategy_trail_atr_mult      = 2.00;
input int    strategy_time_stop_bars      = 18;
input double strategy_spread_atr_mult     = 0.30;
input int    strategy_min_qualified_bars  = 4;
input int    strategy_min_traversal_bars  = 8;

bool   g_rei_cache_valid = false;
double g_rei_shift1 = 0.0;
double g_rei_shift2 = 0.0;
int    g_rei_qualified_shift1 = 0;

int Strategy_MaxInt(const int a, const int b)
  {
   return (a > b) ? a : b;
  }

bool Strategy_GetOurPosition(ulong &ticket,
                             ENUM_POSITION_TYPE &position_type,
                             double &open_price,
                             datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_ComputeRei(const MqlRates &rates[],
                         const int rates_count,
                         const int shift,
                         double &out_rei,
                         int &out_qualified)
  {
   out_rei = 0.0;
   out_qualified = 0;
   if(strategy_rei_window <= 0 || shift < 1)
      return false;

   const int max_index = shift + strategy_rei_window + 7;
   if(rates_count <= max_index)
      return false;

   double numerator = 0.0;
   double denominator = 0.0;
   for(int i = 0; i < strategy_rei_window; ++i)
     {
      const int k = shift + i;
      const double num_i = (rates[k].high - rates[k + 2].high) +
                           (rates[k].low - rates[k + 2].low);
      const double den_i = MathAbs(rates[k].high - rates[k + 2].low) +
                           MathAbs(rates[k].low - rates[k + 2].high);

      const bool cond1 = ((rates[k].high >= rates[k + 5].low &&
                           rates[k].high >= rates[k + 6].low) ||
                          (rates[k + 2].high >= rates[k + 7].close &&
                           rates[k + 2].high >= rates[k + 8].close));
      const bool cond2 = ((rates[k].low <= rates[k + 5].high &&
                           rates[k].low <= rates[k + 6].high) ||
                          (rates[k + 2].low <= rates[k + 7].close &&
                           rates[k + 2].low <= rates[k + 8].close));

      if(cond1 && cond2)
        {
         numerator += num_i;
         out_qualified++;
        }
      denominator += den_i;
     }

   if(denominator <= 0.0)
      return false;

   out_rei = 100.0 * numerator / denominator;
   if(out_rei > 100.0)
      out_rei = 100.0;
   if(out_rei < -100.0)
      out_rei = -100.0;
   return true;
  }

int Strategy_ConsecutiveZoneBars(const MqlRates &rates[],
                                 const int rates_count,
                                 const bool oversold,
                                 const int start_shift)
  {
   int count = 0;
   const int scan_limit = Strategy_MaxInt(strategy_max_zone_duration + 2,
                                          strategy_recent_lookback + 2);
   for(int shift = start_shift; shift < start_shift + scan_limit; ++shift)
     {
      double rei = 0.0;
      int qualified = 0;
      if(!Strategy_ComputeRei(rates, rates_count, shift, rei, qualified))
         break;

      if(oversold)
        {
         if(rei <= -strategy_zone_level)
            count++;
         else
            break;
        }
      else
        {
         if(rei >= strategy_zone_level)
            count++;
         else
            break;
        }
     }
   return count;
  }

bool Strategy_RecentZoneSeen(const MqlRates &rates[],
                             const int rates_count,
                             const bool oversold)
  {
   for(int shift = 2; shift <= strategy_recent_lookback + 1; ++shift)
     {
      double rei = 0.0;
      int qualified = 0;
      if(!Strategy_ComputeRei(rates, rates_count, shift, rei, qualified))
         return false;
      if(oversold && rei <= -strategy_zone_level)
         return true;
      if(!oversold && rei >= strategy_zone_level)
         return true;
     }
   return false;
  }

bool Strategy_FastOppositeTraversal(const MqlRates &rates[],
                                    const int rates_count)
  {
   if(strategy_min_traversal_bars <= 1)
      return false;

   bool saw_overbought = false;
   bool saw_oversold = false;
   for(int shift = 1; shift <= strategy_min_traversal_bars; ++shift)
     {
      double rei = 0.0;
      int qualified = 0;
      if(!Strategy_ComputeRei(rates, rates_count, shift, rei, qualified))
         return false;
      if(rei >= strategy_zone_level)
         saw_overbought = true;
      if(rei <= -strategy_zone_level)
         saw_oversold = true;
     }

   return (saw_overbought && saw_oversold);
  }

bool Strategy_LoadAndCacheRei(MqlRates &rates[], int &rates_count)
  {
   g_rei_cache_valid = false;
   g_rei_shift1 = 0.0;
   g_rei_shift2 = 0.0;
   g_rei_qualified_shift1 = 0;

   if(strategy_rei_window <= 0 || strategy_zone_level <= 0.0 ||
      strategy_max_zone_duration <= 0 || strategy_recent_lookback <= 0 ||
      strategy_atr_period <= 0 || strategy_min_qualified_bars < 0 ||
      strategy_min_traversal_bars < 0)
      return false;

   const int max_shift = Strategy_MaxInt(strategy_recent_lookback + 2,
                         Strategy_MaxInt(strategy_max_zone_duration + 3,
                                         strategy_min_traversal_bars + 1));
   const int bars_required = max_shift + strategy_rei_window + 8;
   ArraySetAsSeries(rates, true);
   rates_count = CopyRates(_Symbol, PERIOD_H4, 0, bars_required, rates); // perf-allowed: closed-bar TD-REI window, called only from EntrySignal after QM_IsNewBar.
   if(rates_count < bars_required)
      return false;

   int qualified2 = 0;
   if(!Strategy_ComputeRei(rates, rates_count, 1, g_rei_shift1, g_rei_qualified_shift1))
      return false;
   if(!Strategy_ComputeRei(rates, rates_count, 2, g_rei_shift2, qualified2))
      return false;

   g_rei_cache_valid = true;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr > 0.0 && ask > 0.0 && bid > 0.0 && ask > bid &&
      (ask - bid) > atr * strategy_spread_atr_mult)
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

   MqlRates rates[];
   int rates_count = 0;
   if(!Strategy_LoadAndCacheRei(rates, rates_count))
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(Strategy_GetOurPosition(ticket, position_type, open_price, open_time))
      return false;

   if(g_rei_qualified_shift1 < strategy_min_qualified_bars)
      return false;
   if(Strategy_FastOppositeTraversal(rates, rates_count))
      return false;

   const double open1 = rates[1].open;
   const double close1 = rates[1].close;
   if(open1 <= 0.0 || close1 <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1);
   if(strategy_use_d1_sma_gate && d1_sma <= 0.0)
      return false;

   const bool long_cross = (g_rei_shift2 <= -strategy_zone_level &&
                            g_rei_shift1 > -strategy_zone_level);
   const bool short_cross = (g_rei_shift2 >= strategy_zone_level &&
                             g_rei_shift1 < strategy_zone_level);

   if(long_cross)
     {
      const int stay = Strategy_ConsecutiveZoneBars(rates, rates_count, true, 2);
      if(stay < 1 || stay > strategy_max_zone_duration)
         return false;
      if(!Strategy_RecentZoneSeen(rates, rates_count, true))
         return false;
      if(close1 <= open1)
         return false;
      if(strategy_use_d1_sma_gate && close1 <= d1_sma)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      double low_min = rates[1].low;
      for(int i = 2; i <= 4; ++i)
         if(rates[i].low > 0.0 && rates[i].low < low_min)
            low_min = rates[i].low;

      const double sl = QM_StopRulesNormalizePrice(_Symbol, low_min - strategy_stop_atr_buffer * atr);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "TD_REI_OVERSOLD_EXIT";
      return true;
     }

   if(short_cross)
     {
      const int stay = Strategy_ConsecutiveZoneBars(rates, rates_count, false, 2);
      if(stay < 1 || stay > strategy_max_zone_duration)
         return false;
      if(!Strategy_RecentZoneSeen(rates, rates_count, false))
         return false;
      if(close1 >= open1)
         return false;
      if(strategy_use_d1_sma_gate && close1 >= d1_sma)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      double high_max = rates[1].high;
      for(int i = 2; i <= 4; ++i)
         if(rates[i].high > high_max)
            high_max = rates[i].high;

      const double sl = QM_StopRulesNormalizePrice(_Symbol, high_max + strategy_stop_atr_buffer * atr);
      if(sl <= 0.0 || sl <= entry)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "TD_REI_OVERBOUGHT_EXIT";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!Strategy_GetOurPosition(ticket, position_type, open_price, open_time))
      return;

   QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE position_type;
   double open_price;
   datetime open_time;
   if(!Strategy_GetOurPosition(ticket, position_type, open_price, open_time))
      return false;

   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(h4_seconds > 0 && strategy_time_stop_bars > 0 &&
      (TimeCurrent() - open_time) >= h4_seconds * strategy_time_stop_bars)
      return true;

   if(!g_rei_cache_valid)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(g_rei_shift2 < strategy_zone_level && g_rei_shift1 >= strategy_zone_level)
         return true;
      if(g_rei_shift2 <= 0.0 && g_rei_shift1 > 0.0 &&
         bid > 0.0 && (bid - open_price) >= strategy_mid_target_atr_mult * atr)
         return true;
     }

   if(position_type == POSITION_TYPE_SELL)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(g_rei_shift2 > -strategy_zone_level && g_rei_shift1 <= -strategy_zone_level)
         return true;
      if(g_rei_shift2 >= 0.0 && g_rei_shift1 < 0.0 &&
         ask > 0.0 && (open_price - ask) >= strategy_mid_target_atr_mult * atr)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_2077\",\"strategy\":\"demark_td_rei_h4\"}");
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
