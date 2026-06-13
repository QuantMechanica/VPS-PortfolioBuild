#property strict
#property version   "5.0"
#property description "QM5_1055 TRO Multi-TimeFrame Heiken Ashi"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1055;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_has_period         = 6;
input int    strategy_ha_lookback_bars   = 80;
input int    strategy_sl_buffer_points   = 15;
input int    strategy_spread_cap_points  = 20;
input bool   strategy_exit_on_h1_flip    = false;
input bool   strategy_use_session_filter = false;
input int    strategy_london_start_hour  = 7;
input int    strategy_ny_end_hour        = 21;

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

int Strategy_BrokerHour()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.hour;
  }

bool Strategy_SelectPosition(ENUM_POSITION_TYPE &ptype)
  {
   ptype = POSITION_TYPE_BUY;
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
      return true;
     }
   return false;
  }

bool Strategy_HeikenAshiClosed(const string symbol,
                               const ENUM_TIMEFRAMES tf,
                               const int shift,
                               const bool smoothed,
                               double &ha_open,
                               double &ha_high,
                               double &ha_low,
                               double &ha_close)
  {
   if(shift < 1)
      return false;

   const int lookback = (strategy_ha_lookback_bars > 12) ? strategy_ha_lookback_bars : 12;
   double prev_ha_open = 0.0;
   double prev_ha_close = 0.0;

   if(smoothed)
     {
      if(strategy_has_period < 1)
         return false;

      for(int bar_shift = shift + lookback - 1; bar_shift >= shift; --bar_shift)
        {
         const double open_price = QM_EMA(symbol, tf, strategy_has_period, bar_shift, PRICE_OPEN);
         const double high_price = QM_EMA(symbol, tf, strategy_has_period, bar_shift, PRICE_HIGH);
         const double low_price = QM_EMA(symbol, tf, strategy_has_period, bar_shift, PRICE_LOW);
         const double close_price = QM_EMA(symbol, tf, strategy_has_period, bar_shift, PRICE_CLOSE);
         if(open_price <= 0.0 || high_price <= 0.0 || low_price <= 0.0 || close_price <= 0.0)
            return false;

         const double cur_ha_close = (open_price + high_price + low_price + close_price) / 4.0;
         const double cur_ha_open = (bar_shift == shift + lookback - 1)
                                    ? ((open_price + close_price) / 2.0)
                                    : ((prev_ha_open + prev_ha_close) / 2.0);
         const double cur_ha_high = MathMax(high_price, MathMax(cur_ha_open, cur_ha_close));
         const double cur_ha_low = MathMin(low_price, MathMin(cur_ha_open, cur_ha_close));

         prev_ha_open = cur_ha_open;
         prev_ha_close = cur_ha_close;

         if(bar_shift == shift)
           {
            ha_open = cur_ha_open;
            ha_high = cur_ha_high;
            ha_low = cur_ha_low;
            ha_close = cur_ha_close;
            return true;
           }
        }
      return false;
     }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, tf, shift, lookback, rates); // perf-allowed: bounded HA calculation; OnTick gates strategy work by QM_IsNewBar.
   if(copied < 3)
      return false;

   for(int i = copied - 1; i >= 0; --i)
     {
      const double open_price = rates[i].open;
      const double high_price = rates[i].high;
      const double low_price = rates[i].low;
      const double close_price = rates[i].close;
      if(open_price <= 0.0 || high_price <= 0.0 || low_price <= 0.0 || close_price <= 0.0)
         return false;

      const double cur_ha_close = (open_price + high_price + low_price + close_price) / 4.0;
      const double cur_ha_open = (i == copied - 1)
                                 ? ((open_price + close_price) / 2.0)
                                 : ((prev_ha_open + prev_ha_close) / 2.0);
      const double cur_ha_high = MathMax(high_price, MathMax(cur_ha_open, cur_ha_close));
      const double cur_ha_low = MathMin(low_price, MathMin(cur_ha_open, cur_ha_close));

      prev_ha_open = cur_ha_open;
      prev_ha_close = cur_ha_close;

      if(i == 0)
        {
         ha_open = cur_ha_open;
         ha_high = cur_ha_high;
         ha_low = cur_ha_low;
         ha_close = cur_ha_close;
         return true;
        }
     }

   return false;
  }

int Strategy_HaDirection(const ENUM_TIMEFRAMES tf, const bool smoothed)
  {
   double ha_open = 0.0;
   double ha_high = 0.0;
   double ha_low = 0.0;
   double ha_close = 0.0;
   if(!Strategy_HeikenAshiClosed(_Symbol, tf, 1, smoothed, ha_open, ha_high, ha_low, ha_close))
      return 0;
   if(ha_close > ha_open)
      return 1;
   if(ha_close < ha_open)
      return -1;
   return 0;
  }

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_spread_cap_points > 0 && spread_points > strategy_spread_cap_points)
      return true;

   if(strategy_use_session_filter)
     {
      const int hour = Strategy_BrokerHour();
      if(hour < strategy_london_start_hour || hour >= strategy_ny_end_hour)
         return true;
     }

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

   const int h4_dir = Strategy_HaDirection(PERIOD_H4, false);
   const int h1_dir = Strategy_HaDirection(PERIOD_H1, false);
   const int m15_dir = Strategy_HaDirection(PERIOD_M15, false);
   const int has_dir = Strategy_HaDirection(PERIOD_M15, true);
   if(h4_dir == 0 || h1_dir == 0 || m15_dir == 0 || has_dir == 0)
      return false;
   if(!(h4_dir == h1_dir && h1_dir == m15_dir && m15_dir == has_dir))
      return false;

   double h1_ha_open = 0.0;
   double h1_ha_high = 0.0;
   double h1_ha_low = 0.0;
   double h1_ha_close = 0.0;
   if(!Strategy_HeikenAshiClosed(_Symbol, PERIOD_H1, 1, false,
                                 h1_ha_open, h1_ha_high, h1_ha_low, h1_ha_close))
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(h4_dir > 0)
     {
      const double sl = Strategy_NormalizePrice(h1_ha_low - strategy_sl_buffer_points * point);
      if(sl <= 0.0 || sl >= ask)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.reason = "TRO_MTF_HA_LONG";
      return true;
     }

   const double sl = Strategy_NormalizePrice(h1_ha_high + strategy_sl_buffer_points * point);
   if(sl <= 0.0 || sl <= bid)
      return false;
   req.type = QM_SELL;
   req.sl = sl;
   req.reason = "TRO_MTF_HA_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing-stop, or partial-close management.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!Strategy_SelectPosition(ptype))
      return false;

   const int has_dir = Strategy_HaDirection(PERIOD_M15, true);
   if(has_dir == 0)
      return false;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   if(is_buy && has_dir < 0)
      return true;
   if(!is_buy && has_dir > 0)
      return true;

   if(strategy_exit_on_h1_flip)
     {
      const int h1_dir = Strategy_HaDirection(PERIOD_H1, false);
      if(is_buy && h1_dir < 0)
         return true;
      if(!is_buy && h1_dir > 0)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1055\",\"ea\":\"QM5_1055_tro_mtf_heiken_ashi\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_M15))
      return;

   QM_EquityStreamOnNewBar();

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      return;
     }

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
