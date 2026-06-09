#property strict
#property version   "5.0"
#property description "QM5_10205 TradingView CHOP DMI PSAR Trend Entry"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10205;
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
input ENUM_TIMEFRAMES strategy_timeframe       = PERIOD_H1;
input int    strategy_chop_period              = 14;
input int    strategy_chop_smoothing           = 4;
input double strategy_chop_long_level          = 61.8;
input double strategy_chop_short_level         = 38.2;
input int    strategy_dmi_period               = 14;
input double strategy_adx_key_level            = 25.0;
input double strategy_psar_start               = 0.015;
input double strategy_psar_increment           = 0.001;
input double strategy_psar_maximum             = 0.20;
input int    strategy_atr_period               = 14;
input double strategy_emergency_atr_mult       = 3.0;
input double strategy_max_spread_stop_fraction = 0.15;
input bool   strategy_follow_trend             = true;
input bool   strategy_enable_psar_exit         = true;
input bool   strategy_enable_dmi_exit          = true;
input int    strategy_psar_warmup_bars         = 90;

double g_chop_1 = 0.0;
double g_adx_1 = 0.0;
double g_adx_2 = 0.0;
double g_plus_di_1 = 0.0;
double g_plus_di_2 = 0.0;
double g_minus_di_1 = 0.0;
double g_minus_di_2 = 0.0;
double g_atr_1 = 0.0;
double g_psar_1 = 0.0;
bool   g_psar_uptrend_1 = true;
bool   g_has_psar_1 = false;
bool   g_state_ready = false;

double Strategy_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  }

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &position_type,
                             double &open_price,
                             ulong &ticket)
  {
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   ticket = 0;

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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      ticket = candidate;
      return true;
     }

   return false;
  }

bool Strategy_LoadClosedRates(MqlRates &rates[])
  {
   ArrayFree(rates);
   ArraySetAsSeries(rates, true);

   const int chop_need = strategy_chop_period + MathMax(strategy_chop_smoothing, 1) + 2;
   const int psar_need = MathMax(strategy_psar_warmup_bars, 20) + 3;
   const int bars_needed = MathMax(chop_need, psar_need);
   if(bars_needed <= 10)
      return false;

   const int copied = CopyRates(_Symbol, strategy_timeframe, 1, bars_needed, rates); // perf-allowed: bounded CHOP/PSAR OHLC window inside framework QM_IsNewBar-gated EntrySignal.
   return (copied >= bars_needed);
  }

double Strategy_TrueRangeAt(const MqlRates &rates[], const int index)
  {
   if(index < 0 || index + 1 >= ArraySize(rates))
      return 0.0;
   if(rates[index].high <= 0.0 || rates[index].low <= 0.0 || rates[index + 1].close <= 0.0)
      return 0.0;
   return MathMax(rates[index].high - rates[index].low,
                  MathMax(MathAbs(rates[index].high - rates[index + 1].close),
                          MathAbs(rates[index].low - rates[index + 1].close)));
  }

double Strategy_RawCHOP(const MqlRates &rates[], const int period, const int offset)
  {
   if(period <= 1 || offset < 0 || offset + period >= ArraySize(rates))
      return 0.0;

   double tr_sum = 0.0;
   double highest = -DBL_MAX;
   double lowest = DBL_MAX;
   for(int i = offset; i < offset + period; ++i)
     {
      const double tr = Strategy_TrueRangeAt(rates, i);
      if(tr <= 0.0 || rates[i].high <= 0.0 || rates[i].low <= 0.0)
         return 0.0;
      tr_sum += tr;
      highest = MathMax(highest, rates[i].high);
      lowest = MathMin(lowest, rates[i].low);
     }

   const double range = highest - lowest;
   if(range <= 0.0 || tr_sum <= 0.0)
      return 0.0;

   return 100.0 * MathLog(tr_sum / range) / MathLog((double)period);
  }

double Strategy_SmoothedCHOP(const MqlRates &rates[])
  {
   const int smooth = MathMax(strategy_chop_smoothing, 1);
   double sum = 0.0;
   for(int i = 0; i < smooth; ++i)
     {
      const double value = Strategy_RawCHOP(rates, strategy_chop_period, i);
      if(value <= 0.0)
         return 0.0;
      sum += value;
     }
   return sum / (double)smooth;
  }

bool Strategy_ComputePSAR(const MqlRates &rates[], double &sar, bool &uptrend)
  {
   sar = 0.0;
   uptrend = true;

   const int lookback = MathMax(strategy_psar_warmup_bars, 20);
   if(ArraySize(rates) < lookback || strategy_psar_start <= 0.0 ||
      strategy_psar_increment <= 0.0 || strategy_psar_maximum <= 0.0)
      return false;

   const int oldest = lookback - 1;
   const int prev = oldest - 1;
   uptrend = (rates[prev].close >= rates[oldest].close);
   double extreme = uptrend ? MathMax(rates[oldest].high, rates[prev].high)
                            : MathMin(rates[oldest].low, rates[prev].low);
   sar = uptrend ? MathMin(rates[oldest].low, rates[prev].low)
                 : MathMax(rates[oldest].high, rates[prev].high);

   double acceleration = strategy_psar_start;
   for(int bar = oldest - 2; bar >= 0; --bar)
     {
      sar = sar + acceleration * (extreme - sar);

      if(uptrend)
        {
         sar = MathMin(sar, rates[bar + 1].low);
         sar = MathMin(sar, rates[bar + 2].low);
         if(rates[bar].low < sar)
           {
            uptrend = false;
            sar = extreme;
            extreme = rates[bar].low;
            acceleration = strategy_psar_start;
           }
         else if(rates[bar].high > extreme)
           {
            extreme = rates[bar].high;
            acceleration = MathMin(acceleration + strategy_psar_increment, strategy_psar_maximum);
           }
        }
      else
        {
         sar = MathMax(sar, rates[bar + 1].high);
         sar = MathMax(sar, rates[bar + 2].high);
         if(rates[bar].high > sar)
           {
            uptrend = true;
            sar = extreme;
            extreme = rates[bar].high;
            acceleration = strategy_psar_start;
           }
         else if(rates[bar].low < extreme)
           {
            extreme = rates[bar].low;
            acceleration = MathMin(acceleration + strategy_psar_increment, strategy_psar_maximum);
           }
        }
     }

   sar = Strategy_NormalizePrice(sar);
   return (sar > 0.0);
  }

bool Strategy_AdvanceState()
  {
   g_state_ready = false;
   g_chop_1 = 0.0;
   g_adx_1 = QM_ADX(_Symbol, strategy_timeframe, strategy_dmi_period, 1);
   g_adx_2 = QM_ADX(_Symbol, strategy_timeframe, strategy_dmi_period, 2);
   g_plus_di_1 = QM_ADX_PlusDI(_Symbol, strategy_timeframe, strategy_dmi_period, 1);
   g_plus_di_2 = QM_ADX_PlusDI(_Symbol, strategy_timeframe, strategy_dmi_period, 2);
   g_minus_di_1 = QM_ADX_MinusDI(_Symbol, strategy_timeframe, strategy_dmi_period, 1);
   g_minus_di_2 = QM_ADX_MinusDI(_Symbol, strategy_timeframe, strategy_dmi_period, 2);
   g_atr_1 = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);

   MqlRates rates[];
   if(!Strategy_LoadClosedRates(rates))
      return false;

   g_chop_1 = Strategy_SmoothedCHOP(rates);
   g_has_psar_1 = Strategy_ComputePSAR(rates, g_psar_1, g_psar_uptrend_1);

   g_state_ready = (g_chop_1 > 0.0 && g_adx_1 > 0.0 && g_adx_2 > 0.0 &&
                    g_plus_di_1 > 0.0 && g_plus_di_2 > 0.0 &&
                    g_minus_di_1 > 0.0 && g_minus_di_2 > 0.0 &&
                    g_atr_1 > 0.0);
   return g_state_ready;
  }

double Strategy_StopDistance(const QM_OrderType side, const double entry_price)
  {
   if(entry_price <= 0.0 || g_atr_1 <= 0.0 || strategy_emergency_atr_mult <= 0.0)
      return 0.0;

   const double emergency_distance = strategy_emergency_atr_mult * g_atr_1;
   if(!g_has_psar_1 || g_psar_1 <= 0.0)
      return emergency_distance;

   double psar_distance = 0.0;
   if(side == QM_BUY && g_psar_1 < entry_price)
      psar_distance = entry_price - g_psar_1;
   if(side == QM_SELL && g_psar_1 > entry_price)
      psar_distance = g_psar_1 - entry_price;

   if(psar_distance <= 0.0 || psar_distance > emergency_distance)
      return emergency_distance;
   return psar_distance;
  }

double Strategy_StopPrice(const QM_OrderType side, const double entry_price)
  {
   const double distance = Strategy_StopDistance(side, entry_price);
   if(distance <= 0.0)
      return 0.0;

   const double stop = (side == QM_BUY) ? (entry_price - distance) : (entry_price + distance);
   return Strategy_NormalizePrice(stop);
  }

bool Strategy_BuildSignal(QM_OrderType &side)
  {
   side = QM_BUY;
   if(!g_state_ready || g_adx_1 <= strategy_adx_key_level)
      return false;

   if(strategy_follow_trend && !g_has_psar_1)
      return false;

   if(g_chop_1 > strategy_chop_long_level)
     {
      if(!strategy_follow_trend || (g_psar_uptrend_1 && g_plus_di_1 > g_minus_di_1))
        {
         side = QM_BUY;
         return true;
        }
     }

   if(g_chop_1 < strategy_chop_short_level)
     {
      if(!strategy_follow_trend || (!g_psar_uptrend_1 && g_minus_di_1 > g_plus_di_1))
        {
         side = QM_SELL;
         return true;
        }
     }

   return false;
  }

bool Strategy_SpreadAllowedFor(const QM_OrderType side, const double entry_price)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   double stop_distance = Strategy_StopDistance(side, entry_price);
   if(stop_distance <= 0.0)
     {
      const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
      stop_distance = atr * strategy_emergency_atr_mult;
     }

   if(stop_distance <= 0.0 || strategy_max_spread_stop_fraction <= 0.0)
      return false;
   return ((ask - bid) <= strategy_max_spread_stop_fraction * stop_distance);
  }

bool Strategy_DICrossed(const bool plus_above_minus)
  {
   if(g_plus_di_1 <= 0.0 || g_plus_di_2 <= 0.0 || g_minus_di_1 <= 0.0 || g_minus_di_2 <= 0.0)
      return false;

   if(plus_above_minus)
      return (g_plus_di_1 > g_minus_di_1 && g_plus_di_2 <= g_minus_di_2);
   return (g_minus_di_1 > g_plus_di_1 && g_minus_di_2 <= g_plus_di_2);
  }

bool Strategy_NoTradeFilter()
  {
   ENUM_POSITION_TYPE position_type;
   double open_price = 0.0;
   ulong ticket = 0;
   if(Strategy_GetOurPosition(position_type, open_price, ticket))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;

   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_emergency_atr_mult <= 0.0)
      return true;

   const double stop_distance = atr * strategy_emergency_atr_mult;
   return ((ask - bid) > strategy_max_spread_stop_fraction * stop_distance);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_AdvanceState();

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_chop_period <= 1 || strategy_dmi_period <= 1 ||
      strategy_atr_period <= 0 || strategy_chop_smoothing <= 0)
      return false;

   QM_OrderType signal_side = QM_BUY;
   if(!Strategy_BuildSignal(signal_side))
      return false;

   ENUM_POSITION_TYPE position_type;
   double open_price = 0.0;
   ulong ticket = 0;
   if(Strategy_GetOurPosition(position_type, open_price, ticket))
     {
      const bool position_is_buy = (position_type == POSITION_TYPE_BUY);
      if((position_is_buy && signal_side == QM_BUY) || (!position_is_buy && signal_side == QM_SELL))
         return false;
      if(!QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL))
         return false;
     }

   const double entry_price = (signal_side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0 || !Strategy_SpreadAllowedFor(signal_side, entry_price))
      return false;

   req.type = signal_side;
   req.sl = Strategy_StopPrice(signal_side, entry_price);
   req.reason = (signal_side == QM_BUY) ? "CHOP_DMI_PSAR_LONG" : "CHOP_DMI_PSAR_SHORT";
   return (req.sl > 0.0 &&
           ((signal_side == QM_BUY && req.sl < entry_price) ||
            (signal_side == QM_SELL && req.sl > entry_price)));
  }

void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE position_type;
   double open_price = 0.0;
   ulong ticket = 0;
   if(!Strategy_GetOurPosition(position_type, open_price, ticket))
      return;

   if(!g_state_ready || g_atr_1 <= 0.0)
      return;

   const double ref_price = (position_type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                                 : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ref_price <= 0.0)
      return;

   const QM_OrderType side = (position_type == POSITION_TYPE_BUY) ? QM_BUY : QM_SELL;
   const double stop_price = Strategy_StopPrice(side, ref_price);
   if(stop_price <= 0.0)
      return;

   const double current_sl = PositionGetDouble(POSITION_SL);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   if(position_type == POSITION_TYPE_BUY)
     {
      if(current_sl <= 0.0 || stop_price > current_sl + point * 0.5)
         QM_TM_MoveSL(ticket, stop_price, "PSAR_ATR_TRAIL_LONG");
      return;
     }

   if(current_sl <= 0.0 || stop_price < current_sl - point * 0.5)
      QM_TM_MoveSL(ticket, stop_price, "PSAR_ATR_TRAIL_SHORT");
  }

bool Strategy_ExitSignal()
  {
   if(!g_state_ready)
      return false;

   ENUM_POSITION_TYPE position_type;
   double open_price = 0.0;
   ulong ticket = 0;
   if(!Strategy_GetOurPosition(position_type, open_price, ticket))
      return false;

   if(strategy_enable_dmi_exit && g_adx_1 < strategy_adx_key_level && g_adx_2 >= strategy_adx_key_level)
     {
      if(position_type == POSITION_TYPE_BUY && Strategy_DICrossed(false))
         return true;
      if(position_type == POSITION_TYPE_SELL && Strategy_DICrossed(true))
         return true;
     }

   if(strategy_enable_psar_exit && g_has_psar_1)
     {
      if(position_type == POSITION_TYPE_BUY && !g_psar_uptrend_1)
         return true;
      if(position_type == POSITION_TYPE_SELL && g_psar_uptrend_1)
         return true;
     }

   if(!strategy_enable_dmi_exit && !strategy_enable_psar_exit)
     {
      if(position_type == POSITION_TYPE_BUY && g_chop_1 < strategy_chop_short_level)
         return true;
      if(position_type == POSITION_TYPE_SELL && g_chop_1 > strategy_chop_long_level)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10205\",\"slug\":\"tv_chop_dmi_psar\"}");
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
