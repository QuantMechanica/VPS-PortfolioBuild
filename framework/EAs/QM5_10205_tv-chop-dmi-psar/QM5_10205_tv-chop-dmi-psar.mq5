#property strict
#property version   "5.0"
#property description "QM5_10205 TradingView CHOP DMI PSAR trend entry"

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
input int    strategy_chop_period          = 14;
input int    strategy_chop_smooth          = 4;
input double strategy_chop_bull_threshold  = 61.8;
input double strategy_chop_bear_threshold  = 38.2;
input int    strategy_dmi_period           = 14;
input double strategy_adx_key_level        = 25.0;
input bool   strategy_follow_trend         = true;
input bool   strategy_use_dmi_exit         = true;
input bool   strategy_use_psar_exit        = true;
input double strategy_psar_start           = 0.015;
input double strategy_psar_increment       = 0.001;
input double strategy_psar_maximum         = 0.2;
input int    strategy_psar_warmup_bars     = 120;
input int    strategy_atr_period           = 14;
input double strategy_emergency_atr_mult   = 3.0;
input double strategy_spread_stop_fraction = 0.15;

bool LoadRates(const int count, MqlRates &rates[])
  {
   if(count <= 0)
      return false;
   ArrayResize(rates, count);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, count, rates); // perf-allowed
   return (copied >= count);
  }

bool ComputeRawChop(const int shift, const int period, double &out_chop)
  {
   out_chop = 0.0;
   if(shift < 1 || period < 2)
      return false;

   MqlRates rates[];
   const int count = shift + period + 2;
   if(!LoadRates(count, rates))
      return false;

   double highest_high = -DBL_MAX;
   double lowest_low = DBL_MAX;
   double true_range_sum = 0.0;

   for(int i = shift; i < shift + period; ++i)
     {
      const double high = rates[i].high;
      const double low = rates[i].low;
      const double prev_close = rates[i + 1].close;
      if(high <= 0.0 || low <= 0.0 || prev_close <= 0.0 || high < low)
         return false;

      highest_high = MathMax(highest_high, high);
      lowest_low = MathMin(lowest_low, low);

      const double tr1 = high - low;
      const double tr2 = MathAbs(high - prev_close);
      const double tr3 = MathAbs(low - prev_close);
      true_range_sum += MathMax(tr1, MathMax(tr2, tr3));
     }

   const double range = highest_high - lowest_low;
   if(range <= 0.0 || true_range_sum <= 0.0)
      return false;

   out_chop = 100.0 * (MathLog(true_range_sum / range) / MathLog((double)period));
   return (out_chop > 0.0);
  }

bool ComputeChop(const int shift, double &out_chop)
  {
   out_chop = 0.0;
   const int smooth = MathMax(1, strategy_chop_smooth);
   double sum = 0.0;
   int samples = 0;

   for(int i = 0; i < smooth; ++i)
     {
      double raw = 0.0;
      if(!ComputeRawChop(shift + i, strategy_chop_period, raw))
         return false;
      sum += raw;
      samples++;
     }

   if(samples <= 0)
      return false;
   out_chop = sum / (double)samples;
   return true;
  }

bool ComputePSAR(const int shift, double &out_psar, int &out_trend)
  {
   out_psar = 0.0;
   out_trend = 0;
   if(shift < 1 || strategy_psar_start <= 0.0 || strategy_psar_increment <= 0.0 || strategy_psar_maximum <= 0.0)
      return false;

   MqlRates rates[];
   const int count = MathMax(strategy_psar_warmup_bars, shift + 20);
   if(!LoadRates(count, rates))
      return false;

   int oldest = count - 1;
   int next = oldest - 1;
   if(next <= shift)
      return false;

   bool uptrend = (rates[next].close >= rates[oldest].close);
   double sar = uptrend ? rates[oldest].low : rates[oldest].high;
   double ep = uptrend ? MathMax(rates[oldest].high, rates[next].high)
                       : MathMin(rates[oldest].low, rates[next].low);
   double af = strategy_psar_start;

   for(int i = oldest - 2; i >= shift; --i)
     {
      double next_sar = sar + af * (ep - sar);

      if(uptrend)
        {
         next_sar = MathMin(next_sar, rates[i + 1].low);
         next_sar = MathMin(next_sar, rates[i + 2].low);

         if(rates[i].low < next_sar)
           {
            uptrend = false;
            next_sar = ep;
            ep = rates[i].low;
            af = strategy_psar_start;
           }
         else if(rates[i].high > ep)
           {
            ep = rates[i].high;
            af = MathMin(af + strategy_psar_increment, strategy_psar_maximum);
           }
        }
      else
        {
         next_sar = MathMax(next_sar, rates[i + 1].high);
         next_sar = MathMax(next_sar, rates[i + 2].high);

         if(rates[i].high > next_sar)
           {
            uptrend = true;
            next_sar = ep;
            ep = rates[i].high;
            af = strategy_psar_start;
           }
         else if(rates[i].low < ep)
           {
            ep = rates[i].low;
            af = MathMin(af + strategy_psar_increment, strategy_psar_maximum);
           }
        }

      sar = next_sar;
     }

   out_psar = QM_TM_NormalizePrice(_Symbol, sar);
   out_trend = uptrend ? 1 : -1;
   return (out_psar > 0.0);
  }

bool SelectOurPosition(ENUM_POSITION_TYPE &position_type, ulong &ticket)
  {
   position_type = POSITION_TYPE_BUY;
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
      ticket = candidate;
      return true;
     }

   return false;
  }

bool BuildDirectionalSignal(bool &long_signal, bool &short_signal)
  {
   long_signal = false;
   short_signal = false;

   double chop = 0.0;
   if(!ComputeChop(1, chop))
      return false;

   const double adx = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_dmi_period, 1);
   if(adx <= strategy_adx_key_level)
      return true;

   int psar_trend = 0;
   double psar = 0.0;
   const bool have_psar = ComputePSAR(1, psar, psar_trend);

   const bool trend_allows_long = (!strategy_follow_trend || (have_psar && psar_trend > 0));
   const bool trend_allows_short = (!strategy_follow_trend || (have_psar && psar_trend < 0));

   long_signal = (chop > strategy_chop_bull_threshold && trend_allows_long);
   short_signal = (chop < strategy_chop_bear_threshold && trend_allows_short);
   return true;
  }

bool SpreadWithinStopDistance(const double stop_distance)
  {
   if(stop_distance <= 0.0 || strategy_spread_stop_fraction <= 0.0)
      return false;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;
   return ((ask - bid) <= stop_distance * strategy_spread_stop_fraction);
  }

double ResolveInitialStop(const QM_OrderType side, const double entry_price)
  {
   if(entry_price <= 0.0)
      return 0.0;

   const double atr_stop = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_emergency_atr_mult);
   double psar = 0.0;
   int psar_trend = 0;
   const bool have_psar = ComputePSAR(1, psar, psar_trend);

   const bool buy_side = QM_OrderTypeIsBuy(side);
   bool psar_valid = have_psar && (buy_side ? (psar < entry_price) : (psar > entry_price));
   if(!psar_valid)
      return atr_stop;

   if(atr_stop <= 0.0)
      return psar;

   const double psar_distance = MathAbs(entry_price - psar);
   const double atr_distance = MathAbs(entry_price - atr_stop);
   if(psar_distance <= 0.0 || psar_distance > atr_distance)
      return atr_stop;

   return psar;
  }

bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double stop_distance = atr * strategy_emergency_atr_mult;
   return !SpreadWithinStopDistance(stop_distance);
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

   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   ulong ticket = 0;
   if(SelectOurPosition(position_type, ticket))
      return false;

   bool long_signal = false;
   bool short_signal = false;
   if(!BuildDirectionalSignal(long_signal, short_signal))
      return false;

   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(side);
   const double stop = ResolveInitialStop(side, entry_price);
   if(entry_price <= 0.0 || stop <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - stop);
   if(!SpreadWithinStopDistance(stop_distance))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = stop;
   req.tp = 0.0;
   req.reason = long_signal ? "CHOP_DMI_PSAR_LONG" : "CHOP_DMI_PSAR_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   double psar = 0.0;
   int psar_trend = 0;
   const bool have_psar = ComputePSAR(1, psar, psar_trend);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(!have_psar)
        {
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_emergency_atr_mult);
         continue;
        }

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(position_type == POSITION_TYPE_BUY && psar_trend > 0 && psar < bid &&
         (current_sl <= 0.0 || psar > current_sl))
         QM_TM_MoveSL(ticket, psar, "psar_trailing_stop");

      if(position_type == POSITION_TYPE_SELL && psar_trend < 0 && psar > ask &&
         (current_sl <= 0.0 || psar < current_sl))
         QM_TM_MoveSL(ticket, psar, "psar_trailing_stop");
     }
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   ulong ticket = 0;
   if(!SelectOurPosition(position_type, ticket))
      return false;

   const double adx = QM_ADX(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_dmi_period, 1);
   const double plus_di = QM_ADX_PlusDI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_dmi_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_dmi_period, 1);
   const double plus_di_prev = QM_ADX_PlusDI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_dmi_period, 2);
   const double minus_di_prev = QM_ADX_MinusDI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_dmi_period, 2);

   if(strategy_use_dmi_exit && adx < strategy_adx_key_level)
     {
      if(position_type == POSITION_TYPE_BUY && minus_di > plus_di && minus_di_prev <= plus_di_prev)
         return true;
      if(position_type == POSITION_TYPE_SELL && plus_di > minus_di && plus_di_prev <= minus_di_prev)
         return true;
     }

   double psar = 0.0;
   int psar_trend = 0;
   if(strategy_use_psar_exit && ComputePSAR(1, psar, psar_trend))
     {
      if(position_type == POSITION_TYPE_BUY && psar_trend < 0)
         return true;
      if(position_type == POSITION_TYPE_SELL && psar_trend > 0)
         return true;
     }

   bool long_signal = false;
   bool short_signal = false;
   if(BuildDirectionalSignal(long_signal, short_signal))
     {
      if(position_type == POSITION_TYPE_BUY && short_signal)
         return true;
      if(position_type == POSITION_TYPE_SELL && long_signal)
         return true;
     }

   if(!strategy_use_dmi_exit && !strategy_use_psar_exit)
     {
      double chop = 0.0;
      if(ComputeChop(1, chop))
        {
         if(position_type == POSITION_TYPE_BUY && chop < strategy_chop_bear_threshold)
            return true;
         if(position_type == POSITION_TYPE_SELL && chop > strategy_chop_bull_threshold)
            return true;
        }
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
