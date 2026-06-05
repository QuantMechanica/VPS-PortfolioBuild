#property strict
#property version   "5.0"
#property description "QM5_10806 TradingView Heiken Ashi SuperTrend ADX"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10806;
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
input int    strategy_st_atr_period     = 10;
input double strategy_st_factor         = 3.0;
input bool   strategy_use_adx_filter    = true;
input int    strategy_adx_period        = 14;
input double strategy_adx_threshold     = 25.0;
input double strategy_wick_tolerance    = 0.10;
input int    strategy_stop_atr_period   = 14;
input double strategy_stop_atr_mult     = 2.0;
input int    strategy_swing_lookback    = 10;
input double strategy_insurance_pct     = 2.0;
input int    strategy_warmup_bars       = 220;

bool   g_state_ready       = false;
int    g_st_dir_closed     = 0;
double g_st_line_closed    = 0.0;
double g_ha_open_closed    = 0.0;
double g_ha_high_closed    = 0.0;
double g_ha_low_closed     = 0.0;
double g_ha_close_closed   = 0.0;
bool   g_ha_long_full      = false;
bool   g_ha_short_full     = false;

bool QM5_HA_FullBody(const bool bullish,
                     const double ha_open,
                     const double ha_high,
                     const double ha_low,
                     const double ha_close)
  {
   const double range = ha_high - ha_low;
   if(range <= 0.0)
      return false;

   const double tol = MathMax(0.0, strategy_wick_tolerance) * range;
   if(bullish)
     {
      if(ha_close <= ha_open)
         return false;
      const double lower_wick = MathMin(ha_open, ha_close) - ha_low;
      return (lower_wick <= tol);
     }

   if(ha_close >= ha_open)
      return false;
   const double upper_wick = ha_high - MathMax(ha_open, ha_close);
   return (upper_wick <= tol);
  }

bool QM5_RefreshClosedBarState()
  {
   g_state_ready = false;
   g_st_dir_closed = 0;
   g_st_line_closed = 0.0;
   g_ha_open_closed = 0.0;
   g_ha_high_closed = 0.0;
   g_ha_low_closed = 0.0;
   g_ha_close_closed = 0.0;
   g_ha_long_full = false;
   g_ha_short_full = false;

   if(strategy_st_atr_period <= 0 || strategy_st_factor <= 0.0)
      return false;

   int bars_needed = strategy_warmup_bars;
   const int min_bars = strategy_st_atr_period + 10;
   if(bars_needed < min_bars)
      bars_needed = min_bars;
   if(bars_needed < 40)
      bars_needed = 40;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, bars_needed, rates); // perf-allowed: closed-bar SuperTrend and Heiken Ashi need OHLC transforms.
   if(copied < min_bars)
      return false;

   bool st_init = false;
   int st_dir = 1;
   double final_upper = 0.0;
   double final_lower = 0.0;

   bool ha_init = false;
   double ha_open = 0.0;
   double ha_close = 0.0;
   double ha_high = 0.0;
   double ha_low = 0.0;

   const int oldest_shift = copied - 2;
   for(int shift = oldest_shift; shift >= 1; --shift)
     {
      const double open = rates[shift].open;
      const double high = rates[shift].high;
      const double low = rates[shift].low;
      const double close = rates[shift].close;
      if(open <= 0.0 || high <= 0.0 || low <= 0.0 || close <= 0.0)
         continue;

      const double next_ha_close = (open + high + low + close) * 0.25;
      double next_ha_open = (open + close) * 0.5;
      if(ha_init)
         next_ha_open = (ha_open + ha_close) * 0.5;
      const double next_ha_high = MathMax(high, MathMax(next_ha_open, next_ha_close));
      const double next_ha_low = MathMin(low, MathMin(next_ha_open, next_ha_close));

      ha_open = next_ha_open;
      ha_close = next_ha_close;
      ha_high = next_ha_high;
      ha_low = next_ha_low;
      ha_init = true;

      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_st_atr_period, shift);
      if(atr <= 0.0)
         continue;

      const double hl2 = (high + low) * 0.5;
      const double basic_upper = hl2 + strategy_st_factor * atr;
      const double basic_lower = hl2 - strategy_st_factor * atr;

      if(!st_init)
        {
         final_upper = basic_upper;
         final_lower = basic_lower;
         st_dir = (close >= hl2) ? 1 : -1;
         st_init = true;
        }
      else
        {
         const double prev_upper = final_upper;
         const double prev_lower = final_lower;
         const double prev_close = rates[shift + 1].close;
         final_upper = (basic_upper < prev_upper || prev_close > prev_upper) ? basic_upper : prev_upper;
         final_lower = (basic_lower > prev_lower || prev_close < prev_lower) ? basic_lower : prev_lower;

         if(st_dir < 0 && close > final_upper)
            st_dir = 1;
         else if(st_dir > 0 && close < final_lower)
            st_dir = -1;
        }

      if(shift == 1)
        {
         g_st_dir_closed = st_dir;
         g_st_line_closed = (st_dir > 0) ? final_lower : final_upper;
         g_ha_open_closed = ha_open;
         g_ha_high_closed = ha_high;
         g_ha_low_closed = ha_low;
         g_ha_close_closed = ha_close;
        }
     }

   if(!st_init || !ha_init || g_st_line_closed <= 0.0)
      return false;

   g_ha_long_full = QM5_HA_FullBody(true, g_ha_open_closed, g_ha_high_closed, g_ha_low_closed, g_ha_close_closed);
   g_ha_short_full = QM5_HA_FullBody(false, g_ha_open_closed, g_ha_high_closed, g_ha_low_closed, g_ha_close_closed);
   g_state_ready = true;
   return true;
  }

int QM5_OurPositionType()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return -1;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return (int)PositionGetInteger(POSITION_TYPE);
     }

   return -1;
  }

bool QM5_StopCandidateValid(const QM_OrderType side,
                            const double reference_price,
                            const double stop_price)
  {
   if(reference_price <= 0.0 || stop_price <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double min_distance = stops_level * point;
   if(min_distance < point)
      min_distance = point;

   if(QM_OrderTypeIsBuy(side))
      return (stop_price < reference_price - min_distance);
   return (stop_price > reference_price + min_distance);
  }

double QM5_SelectNearestProtectiveStop(const QM_OrderType side,
                                       const double reference_price)
  {
   const int atr_period = MathMax(1, strategy_stop_atr_period);
   const int swing_lookback = MathMax(1, strategy_swing_lookback);
   const double atr_value = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, atr_period, 1);
   const double atr_stop = QM_StopATRFromValue(_Symbol, side, reference_price, atr_value, strategy_stop_atr_mult);
   const double swing_stop = QM_StopStructure(_Symbol, side, reference_price, swing_lookback);
   const double insurance_distance = reference_price * MathMax(0.0, strategy_insurance_pct) * 0.01;
   const double insurance_stop = QM_StopATRFromValue(_Symbol, side, reference_price, insurance_distance, 1.0);

   double selected = 0.0;

   if(QM5_StopCandidateValid(side, reference_price, atr_stop))
      selected = atr_stop;

   if(QM5_StopCandidateValid(side, reference_price, swing_stop))
     {
      if(selected <= 0.0)
         selected = swing_stop;
      else if(QM_OrderTypeIsBuy(side) && swing_stop > selected)
         selected = swing_stop;
      else if(!QM_OrderTypeIsBuy(side) && swing_stop < selected)
         selected = swing_stop;
     }

   if(QM5_StopCandidateValid(side, reference_price, insurance_stop))
     {
      if(selected <= 0.0)
         selected = insurance_stop;
      else if(QM_OrderTypeIsBuy(side) && insurance_stop > selected)
         selected = insurance_stop;
      else if(!QM_OrderTypeIsBuy(side) && insurance_stop < selected)
         selected = insurance_stop;
     }

   if(selected <= 0.0)
      return 0.0;
   return NormalizeDouble(selected, _Digits);
  }

double QM5_SelectSwingProtectiveStop(const QM_OrderType side,
                                     const double reference_price)
  {
   const double swing_stop = QM_StopStructure(_Symbol, side, reference_price, MathMax(1, strategy_swing_lookback));
   if(!QM5_StopCandidateValid(side, reference_price, swing_stop))
      return 0.0;
   return NormalizeDouble(swing_stop, _Digits);
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

   if(!QM5_RefreshClosedBarState())
      return false;

   if(QM5_OurPositionType() != -1)
      return false;

   if(strategy_use_adx_filter)
     {
      const double adx = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_adx_period, 1);
      if(adx < strategy_adx_threshold)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(g_ha_long_full && g_st_dir_closed > 0 && ask > 0.0)
     {
      const double sl = QM5_SelectNearestProtectiveStop(QM_BUY, ask);
      if(sl <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.reason = "tv-ha-st-adx long";
      return true;
     }

   if(g_ha_short_full && g_st_dir_closed < 0 && bid > 0.0)
     {
      const double sl = QM5_SelectNearestProtectiveStop(QM_SELL, bid);
      if(sl <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = sl;
      req.reason = "tv-ha-st-adx short";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const QM_OrderType side = (pos_type == POSITION_TYPE_BUY) ? QM_BUY : QM_SELL;
      const double market = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                             : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      QM_TM_TrailATR(ticket, MathMax(1, strategy_stop_atr_period), strategy_stop_atr_mult);

      const double target_sl = QM5_SelectSwingProtectiveStop(side, market);
      if(target_sl <= 0.0)
         continue;

      const double current_sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
         continue;

      const bool improves = (current_sl <= 0.0) ||
                            (side == QM_BUY ? (target_sl > current_sl + point * 0.5)
                                            : (target_sl < current_sl - point * 0.5));
      if(improves)
         QM_TM_MoveSL(ticket, target_sl, "triple_stop_nearest");
     }
  }

bool Strategy_ExitSignal()
  {
   const int ptype = QM5_OurPositionType();
   if(ptype == POSITION_TYPE_BUY && g_ha_short_full)
      return true;
   if(ptype == POSITION_TYPE_SELL && g_ha_long_full)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10806_tv-ha-st-adx\"}");
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
