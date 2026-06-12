#property strict
#property version   "5.0"
#property description "QM5_12535 ICT Killzone Sweep IDX"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12535;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input int    strategy_atr_period          = 14;
input double strategy_atr_buffer_mult     = 0.30;
input double strategy_max_risk_atr_mult   = 2.50;
input int    strategy_mss_max_bars        = 8;
input int    strategy_order_valid_bars    = 8;
input int    strategy_h1_pivot_lookback   = 24;
input int    strategy_m15_pivot_lookback  = 32;
input int    strategy_max_spread_points   = 120;

int      g_last_entry_day_key = -1;
double   g_tp1_price          = 0.0;
double   g_initial_volume     = 0.0;
bool     g_partial_done       = false;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int Strategy_HHMM(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

bool Strategy_IsGdaxi()
  {
   return (StringFind(_Symbol, "GDAXI") >= 0);
  }

bool Strategy_InKillzone(const datetime t)
  {
   const int hhmm = Strategy_HHMM(t);
   if(Strategy_IsGdaxi())
      return (hhmm >= 900 && hhmm < 1200);
   return (hhmm >= 1400 && hhmm < 1700);
  }

int Strategy_TimeExitHHMM()
  {
   return Strategy_IsGdaxi() ? 1600 : 2100;
  }

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool Strategy_HasOpenPosition()
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

bool Strategy_HasPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
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

bool Strategy_SpreadOK()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread > 0 && spread <= strategy_max_spread_points);
  }

bool Strategy_LoadRates(const ENUM_TIMEFRAMES tf, const int start_shift, const int count, MqlRates &rates[])
  {
   ArrayResize(rates, 0);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, start_shift, count, rates); // perf-allowed: bounded structural sweep/FVG scan, called only from closed-bar strategy hooks.
   return (copied == count);
  }

bool Strategy_PreviousDayLevels(double &pdh, double &pdl)
  {
   pdh = 0.0;
   pdl = 0.0;
   MqlRates d1[];
   if(!Strategy_LoadRates(PERIOD_D1, 1, 1, d1))
      return false;
   pdh = d1[0].high;
   pdl = d1[0].low;
   return (pdh > 0.0 && pdl > 0.0);
  }

bool Strategy_AsiaRange(const int day_key, double &asia_high, double &asia_low)
  {
   asia_high = 0.0;
   asia_low = DBL_MAX;
   MqlRates m15[];
   if(!Strategy_LoadRates(PERIOD_M15, 1, 128, m15))
      return false;

   for(int i = 0; i < ArraySize(m15); ++i)
     {
      if(Strategy_DayKey(m15[i].time) != day_key)
         continue;
      const int hhmm = Strategy_HHMM(m15[i].time);
      if(hhmm < 100 || hhmm >= 900)
         continue;
      asia_high = MathMax(asia_high, m15[i].high);
      asia_low = MathMin(asia_low, m15[i].low);
     }
   return (asia_high > 0.0 && asia_low < DBL_MAX);
  }

bool Strategy_H1PivotPools(const double reference_price,
                           double &nearest_high_above,
                           double &nearest_low_below)
  {
   nearest_high_above = DBL_MAX;
   nearest_low_below = 0.0;
   MqlRates h1[];
   const int needed = MathMax(8, strategy_h1_pivot_lookback + 4);
   if(!Strategy_LoadRates(PERIOD_H1, 1, needed, h1))
      return false;

   for(int i = 1; i < ArraySize(h1) - 1; ++i)
     {
      const bool pivot_high = (h1[i].high > h1[i - 1].high && h1[i].high > h1[i + 1].high);
      const bool pivot_low = (h1[i].low < h1[i - 1].low && h1[i].low < h1[i + 1].low);
      if(pivot_high && h1[i].high > reference_price && h1[i].high < nearest_high_above)
         nearest_high_above = h1[i].high;
      if(pivot_low && h1[i].low < reference_price && h1[i].low > nearest_low_below)
         nearest_low_below = h1[i].low;
     }
   return true;
  }

bool Strategy_LiquidityPools(const double reference_price,
                             const int day_key,
                             double &pool_below,
                             double &pool_above)
  {
   pool_below = 0.0;
   pool_above = DBL_MAX;

   double pdh, pdl;
   if(Strategy_PreviousDayLevels(pdh, pdl))
     {
      if(pdl < reference_price)
         pool_below = MathMax(pool_below, pdl);
      if(pdh > reference_price)
         pool_above = MathMin(pool_above, pdh);
     }

   double asia_high, asia_low;
   if(Strategy_AsiaRange(day_key, asia_high, asia_low))
     {
      if(asia_low < reference_price)
         pool_below = MathMax(pool_below, asia_low);
      if(asia_high > reference_price)
         pool_above = MathMin(pool_above, asia_high);
     }

   double h1_high, h1_low;
   if(Strategy_H1PivotPools(reference_price, h1_high, h1_low))
     {
      if(h1_low > 0.0)
         pool_below = MathMax(pool_below, h1_low);
      if(h1_high < DBL_MAX)
         pool_above = MathMin(pool_above, h1_high);
     }

   return (pool_below > 0.0 || pool_above < DBL_MAX);
  }

double Strategy_M15PivotHigh(const MqlRates &rates[])
  {
   const int max_i = MathMin(ArraySize(rates) - 2, strategy_m15_pivot_lookback);
   for(int i = 2; i <= max_i; ++i)
     {
      if(rates[i].high > rates[i - 1].high && rates[i].high > rates[i + 1].high)
         return rates[i].high;
     }
   return 0.0;
  }

double Strategy_M15PivotLow(const MqlRates &rates[])
  {
   const int max_i = MathMin(ArraySize(rates) - 2, strategy_m15_pivot_lookback);
   for(int i = 2; i <= max_i; ++i)
     {
      if(rates[i].low < rates[i - 1].low && rates[i].low < rates[i + 1].low)
         return rates[i].low;
     }
   return 0.0;
  }

bool Strategy_FindBullishSetup(const MqlRates &m15[],
                               const double pool_below,
                               int &sweep_shift,
                               double &sweep_extreme,
                               double &fvg_mid)
  {
   sweep_shift = -1;
   sweep_extreme = 0.0;
   fvg_mid = 0.0;
   if(pool_below <= 0.0)
      return false;

   for(int s = 2; s <= strategy_mss_max_bars + 1 && s < ArraySize(m15); ++s)
     {
      if(!Strategy_InKillzone(m15[s].time))
         continue;
      if(m15[s].low < pool_below && m15[s].close > pool_below)
        {
         sweep_shift = s;
         sweep_extreme = m15[s].low;
         break;
        }
     }
   if(sweep_shift < 0)
      return false;

   const double pivot_high = Strategy_M15PivotHigh(m15);
   if(pivot_high <= 0.0 || m15[0].close <= pivot_high)
      return false;

   for(int newer = 0; newer <= sweep_shift - 2; ++newer)
     {
      const int older = newer + 2;
      if(older >= ArraySize(m15))
         continue;
      if(m15[older].high < m15[newer].low)
        {
         fvg_mid = (m15[older].high + m15[newer].low) * 0.5;
         return true;
        }
     }
   return false;
  }

bool Strategy_FindBearishSetup(const MqlRates &m15[],
                               const double pool_above,
                               int &sweep_shift,
                               double &sweep_extreme,
                               double &fvg_mid)
  {
   sweep_shift = -1;
   sweep_extreme = 0.0;
   fvg_mid = 0.0;
   if(pool_above >= DBL_MAX)
      return false;

   for(int s = 2; s <= strategy_mss_max_bars + 1 && s < ArraySize(m15); ++s)
     {
      if(!Strategy_InKillzone(m15[s].time))
         continue;
      if(m15[s].high > pool_above && m15[s].close < pool_above)
        {
         sweep_shift = s;
         sweep_extreme = m15[s].high;
         break;
        }
     }
   if(sweep_shift < 0)
      return false;

   const double pivot_low = Strategy_M15PivotLow(m15);
   if(pivot_low <= 0.0 || m15[0].close >= pivot_low)
      return false;

   for(int newer = 0; newer <= sweep_shift - 2; ++newer)
     {
      const int older = newer + 2;
      if(older >= ArraySize(m15))
         continue;
      if(m15[older].low > m15[newer].high)
        {
         fvg_mid = (m15[older].low + m15[newer].high) * 0.5;
         return true;
        }
     }
   return false;
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

   if(_Period != PERIOD_M15)
      return false;
   if(!Strategy_SpreadOK())
      return false;
   if(Strategy_HasOpenPosition() || Strategy_HasPendingOrder())
      return false;

   MqlRates m15[];
   if(!Strategy_LoadRates(PERIOD_M15, 1, MathMax(48, strategy_m15_pivot_lookback + 8), m15))
      return false;

   if(!Strategy_InKillzone(m15[0].time))
      return false;
   const int day_key = Strategy_DayKey(m15[0].time);
   if(g_last_entry_day_key == day_key)
      return false;

   double pool_below, pool_above;
   if(!Strategy_LiquidityPools(m15[0].close, day_key, pool_below, pool_above))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0)
      return false;

   int sweep_shift = -1;
   double sweep_extreme = 0.0;
   double entry = 0.0;
   bool is_long = false;

   if(Strategy_FindBullishSetup(m15, pool_below, sweep_shift, sweep_extreme, entry))
      is_long = true;
   else if(!Strategy_FindBearishSetup(m15, pool_above, sweep_shift, sweep_extreme, entry))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   entry = Strategy_NormalizePrice(entry);
   if(is_long && entry >= ask)
      return false;
   if(!is_long && entry <= bid)
      return false;

   const double sl = is_long
                     ? Strategy_NormalizePrice(sweep_extreme - atr * strategy_atr_buffer_mult)
                     : Strategy_NormalizePrice(sweep_extreme + atr * strategy_atr_buffer_mult);
   if(sl <= 0.0)
      return false;
   const double risk = MathAbs(entry - sl);
   if(risk <= 0.0 || risk > atr * strategy_max_risk_atr_mult)
      return false;

   const double rr2 = is_long ? (entry + 2.0 * risk) : (entry - 2.0 * risk);
   const double rr3 = is_long ? (entry + 3.0 * risk) : (entry - 3.0 * risk);
   double tp1 = rr2;
   if(is_long && pool_above < DBL_MAX)
      tp1 = MathMin(pool_above, rr2);
   if(!is_long && pool_below > 0.0)
      tp1 = MathMax(pool_below, rr2);
   if(is_long && tp1 <= entry)
      tp1 = rr2;
   if(!is_long && tp1 >= entry)
      tp1 = rr2;

   req.type = is_long ? QM_BUY_LIMIT : QM_SELL_LIMIT;
   req.price = entry;
   req.sl = sl;
   req.tp = Strategy_NormalizePrice(rr3);
   req.reason = is_long ? "ICT_KZ_SWEEP_FVG_LONG" : "ICT_KZ_SWEEP_FVG_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = strategy_order_valid_bars * PeriodSeconds(PERIOD_M15);

   g_last_entry_day_key = day_key;
   g_tp1_price = Strategy_NormalizePrice(tp1);
   g_initial_volume = 0.0;
   g_partial_done = false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      if(g_initial_volume <= 0.0)
         g_initial_volume = volume;
      if(volume < g_initial_volume * 0.75)
         g_partial_done = true;
      if(g_partial_done || sl <= 0.0 || open_price <= 0.0)
         continue;

      const bool is_long = (type == POSITION_TYPE_BUY);
      const double risk = MathAbs(open_price - sl);
      if(risk <= 0.0)
         continue;
      double target = g_tp1_price;
      if(target <= 0.0)
         target = is_long ? (open_price + 2.0 * risk) : (open_price - 2.0 * risk);

      const double px = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(px <= 0.0)
         continue;
      if((is_long && px >= target) || (!is_long && px <= target))
        {
         if(QM_TM_PartialClose(ticket, volume * 0.5, QM_EXIT_PARTIAL))
            g_partial_done = true;
        }
     }
  }

bool Strategy_ExitSignal()
  {
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
      if(Strategy_HHMM(TimeCurrent()) >= Strategy_TimeExitHHMM())
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
                        60,
                        60,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12535_ict-killzone-sweep-idx\"}");
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
