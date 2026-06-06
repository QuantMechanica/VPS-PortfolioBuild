#property strict
#property version   "5.0"
#property description "QM5_10956 FTMO VWAP Pullback"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10956;
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
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_M15;
input int             strategy_atr_period         = 14;
input double          strategy_band_atr_mult      = 1.0;
input int             strategy_setup_expiry_bars  = 12;
input double          strategy_min_body_atr_mult   = 0.80;
input int             strategy_slope_bars         = 6;
input double          strategy_flat_slope_atr_mult = 0.10;
input double          strategy_stop_atr_mult      = 0.35;
input double          strategy_stop_band_mult     = 0.15;
input double          strategy_trail_trigger_r    = 1.50;
input double          strategy_trail_atr_mult     = 1.0;
input int             strategy_session_start_hour = 7;
input int             strategy_session_end_hour   = 22;
input int             strategy_vwap_bootstrap_bars = 96;

double   g_session_vwap = 0.0;
double   g_upper_band = 0.0;
double   g_lower_band = 0.0;
double   g_vwap_slope = 0.0;
bool     g_state_ready = false;
int      g_setup_side = 0;
int      g_setup_age = 0;
datetime g_state_bar_time = 0;

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;

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
      return true;
     }

   return false;
  }

bool Strategy_SameBrokerDay(const datetime a, const datetime b)
  {
   MqlDateTime da;
   MqlDateTime db;
   TimeToStruct(a, da);
   TimeToStruct(b, db);
   return (da.year == db.year && da.mon == db.mon && da.day == db.day);
  }

bool Strategy_HourInRange(const int hour, const int start_hour, const int end_hour)
  {
   if(start_hour == end_hour)
      return true;
   if(start_hour < end_hour)
      return (hour >= start_hour && hour < end_hour);
   return (hour >= start_hour || hour < end_hour);
  }

bool Strategy_InSession(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;
   return Strategy_HourInRange(dt.hour, strategy_session_start_hour, strategy_session_end_hour);
  }

bool Strategy_AfterSessionEnd(const datetime broker_time)
  {
   if(strategy_session_start_hour == strategy_session_end_hour)
      return false;

   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return true;

   if(strategy_session_start_hour < strategy_session_end_hour)
      return (dt.hour >= strategy_session_end_hour);

   return (dt.hour >= strategy_session_end_hour && dt.hour < strategy_session_start_hour);
  }

bool Strategy_AdvanceVwapState(MqlRates &last_bar)
  {
   g_state_ready = false;
   ZeroMemory(last_bar);

   const int copy_count = MathMax(strategy_slope_bars + 2, MathMin(strategy_vwap_bootstrap_bars, 192));
   MqlRates rates[];
   const int copied = CopyRates(_Symbol, strategy_timeframe, 1, copy_count, rates); // perf-allowed: closed-bar VWAP cache refresh inside framework QM_IsNewBar gate.
   if(copied < strategy_slope_bars + 1)
      return false;

   const int newest = (rates[0].time > rates[copied - 1].time) ? 0 : copied - 1;
   const int oldest = (newest == 0) ? copied - 1 : 0;
   const int step = (newest == 0) ? -1 : 1;

   last_bar = rates[newest];
   if(last_bar.time <= 0 || last_bar.close <= 0.0 || last_bar.high <= 0.0 || last_bar.low <= 0.0)
      return false;

   double pv_sum = 0.0;
   double vol_sum = 0.0;
   double local_vwaps[256];
   int vwap_count = 0;

   for(int i = oldest; ; i += step)
     {
      if(!Strategy_SameBrokerDay(rates[i].time, last_bar.time))
        {
         if(i == newest)
            break;
         continue;
        }
      if(rates[i].high > 0.0 && rates[i].low > 0.0 && rates[i].close > 0.0)
        {
         const double volume = (rates[i].tick_volume > 0) ? (double)rates[i].tick_volume : 1.0;
         const double typical = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
         pv_sum += typical * volume;
         vol_sum += volume;
         if(vol_sum > 0.0 && vwap_count < 256)
           {
            local_vwaps[vwap_count] = pv_sum / vol_sum;
            vwap_count++;
           }
        }

      if(i == newest)
         break;
     }

   if(vol_sum <= 0.0 || vwap_count <= 0)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_band_atr_mult <= 0.0)
      return false;

   g_session_vwap = pv_sum / vol_sum;
   g_upper_band = g_session_vwap + strategy_band_atr_mult * atr;
   g_lower_band = g_session_vwap - strategy_band_atr_mult * atr;
   g_vwap_slope = (vwap_count > strategy_slope_bars) ? (local_vwaps[vwap_count - 1] - local_vwaps[vwap_count - 1 - strategy_slope_bars]) : 0.0;
   g_state_bar_time = last_bar.time;
   g_state_ready = (g_session_vwap > 0.0 && g_upper_band > g_session_vwap && g_lower_band < g_session_vwap);
   return g_state_ready;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_timeframe != PERIOD_M15)
      return true;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(Strategy_SelectOurPosition(ticket, ptype))
      return false;

   return !Strategy_InSession(TimeCurrent());
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

   MqlRates bar;
   if(!Strategy_AdvanceVwapState(bar))
      return false;
   if(!Strategy_InSession(bar.time))
      return false;

   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(Strategy_SelectOurPosition(ticket, ptype))
      return false;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const bool flat_slope = (MathAbs(g_vwap_slope) < strategy_flat_slope_atr_mult * atr);
   const double body = MathAbs(bar.close - bar.open);
   const bool large_body = (body >= strategy_min_body_atr_mult * atr);
   bool expansion_now = false;

   if(!flat_slope && large_body && bar.close > g_upper_band)
     {
      g_setup_side = 1;
      g_setup_age = 0;
      expansion_now = true;
     }
   else if(!flat_slope && large_body && bar.close < g_lower_band)
     {
      g_setup_side = -1;
      g_setup_age = 0;
      expansion_now = true;
     }
   else if(g_setup_side != 0)
     {
      g_setup_age++;
      if(g_setup_age > strategy_setup_expiry_bars)
        {
         g_setup_side = 0;
         g_setup_age = 0;
        }
     }

   if(expansion_now || g_setup_side == 0 || flat_slope)
      return false;

   const double long_stop_distance = MathMax(strategy_stop_atr_mult * atr,
                                             strategy_stop_band_mult * MathAbs(g_session_vwap - g_lower_band));
   const double short_stop_distance = MathMax(strategy_stop_atr_mult * atr,
                                              strategy_stop_band_mult * MathAbs(g_upper_band - g_session_vwap));
   const double spread_price = ask - bid;

   if(g_setup_side > 0 &&
      bar.low <= g_session_vwap &&
      bar.close > g_session_vwap &&
      bar.close > bar.open)
     {
      const double sl = NormalizeDouble(g_session_vwap - long_stop_distance, _Digits);
      const double tp = NormalizeDouble(g_upper_band, _Digits);
      if(sl <= 0.0 || sl >= ask - point || tp <= ask + point)
         return false;
      if(spread_price > 0.10 * MathAbs(ask - sl))
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "ftmo_vwap_pullback_long";
      g_setup_side = 0;
      g_setup_age = 0;
      return true;
     }

   if(g_setup_side < 0 &&
      bar.high >= g_session_vwap &&
      bar.close < g_session_vwap &&
      bar.close < bar.open)
     {
      const double sl = NormalizeDouble(g_session_vwap + short_stop_distance, _Digits);
      const double tp = NormalizeDouble(g_lower_band, _Digits);
      if(sl <= bid + point || tp >= bid - point)
         return false;
      if(spread_price > 0.10 * MathAbs(sl - bid))
         return false;
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "ftmo_vwap_pullback_short";
      g_setup_side = 0;
      g_setup_age = 0;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(!Strategy_SelectOurPosition(ticket, ptype))
      return;

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double current_tp = PositionGetDouble(POSITION_TP);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(open_price <= 0.0 || current_sl <= 0.0 || bid <= 0.0 || ask <= 0.0 || point <= 0.0)
      return;

   if(ptype == POSITION_TYPE_BUY)
     {
      const double risk = open_price - current_sl;
      if(risk > point && (bid - open_price) >= strategy_trail_trigger_r * risk &&
         (current_tp <= 0.0 || bid < current_tp - point))
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
   else if(ptype == POSITION_TYPE_SELL)
     {
      const double risk = current_sl - open_price;
      if(risk > point && (open_price - ask) >= strategy_trail_trigger_r * risk &&
         (current_tp <= 0.0 || ask > current_tp + point))
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE ptype;
   if(!Strategy_SelectOurPosition(ticket, ptype))
      return false;

   return Strategy_AfterSessionEnd(TimeCurrent());
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10956\",\"ea\":\"QM5_10956_ftmo_vwap_pb\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
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
