#property strict
#property version   "5.0"
#property description "QM5_10286 Cinar SuperTrend stop-and-reverse"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10286;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period          = 14;
input double strategy_atr_multiplier      = 2.5;
input int    strategy_warmup_bars         = 180;
input double strategy_fallback_atr_sl_mult = 2.0;

double RateClose(const MqlRates &rates[], const int copied, const int shift)
  {
   if(shift < 1 || shift > copied)
      return 0.0;
   return rates[shift - 1].close;
  }

double RateHigh(const MqlRates &rates[], const int copied, const int shift)
  {
   if(shift < 1 || shift > copied)
      return 0.0;
   return rates[shift - 1].high;
  }

double RateLow(const MqlRates &rates[], const int copied, const int shift)
  {
   if(shift < 1 || shift > copied)
      return 0.0;
   return rates[shift - 1].low;
  }

double TrueRangeAt(const MqlRates &rates[], const int copied, const int shift)
  {
   const double high = RateHigh(rates, copied, shift);
   const double low = RateLow(rates, copied, shift);
   const double prev_close = RateClose(rates, copied, shift + 1);
   if(high <= 0.0 || low <= 0.0 || prev_close <= 0.0)
      return 0.0;

   const double range_hl = high - low;
   const double range_hc = MathAbs(high - prev_close);
   const double range_lc = MathAbs(low - prev_close);
   return MathMax(range_hl, MathMax(range_hc, range_lc));
  }

double WmaTrueRange(const MqlRates &rates[], const int copied, const int period, const int shift)
  {
   if(period <= 0)
      return 0.0;

   double weighted_sum = 0.0;
   double weight_sum = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double tr = TrueRangeAt(rates, copied, shift + i);
      if(tr <= 0.0)
         return 0.0;
      const double weight = (double)(period - i);
      weighted_sum += tr * weight;
      weight_sum += weight;
     }

   if(weight_sum <= 0.0)
      return 0.0;
   return weighted_sum / weight_sum;
  }

double HmaTrueRange(const MqlRates &rates[], const int copied, const int period, const int shift)
  {
   if(period < 2)
      return 0.0;

   const int half_period = MathMax(1, period / 2);
   const int sqrt_period = MathMax(1, (int)MathSqrt((double)period));
   double weighted_sum = 0.0;
   double weight_sum = 0.0;

   for(int i = 0; i < sqrt_period; ++i)
     {
      const double wma_half = WmaTrueRange(rates, copied, half_period, shift + i);
      const double wma_full = WmaTrueRange(rates, copied, period, shift + i);
      if(wma_half <= 0.0 || wma_full <= 0.0)
         return 0.0;

      const double diff = 2.0 * wma_half - wma_full;
      const double weight = (double)(sqrt_period - i);
      weighted_sum += diff * weight;
      weight_sum += weight;
     }

   if(weight_sum <= 0.0)
      return 0.0;
   return weighted_sum / weight_sum;
  }

bool CalculateSuperTrend(double &supertrend, int &direction)
  {
   supertrend = 0.0;
   direction = 0;
   if(strategy_atr_period < 2 || strategy_atr_multiplier <= 0.0)
      return false;

   const int sqrt_period = MathMax(1, (int)MathSqrt((double)strategy_atr_period));
   const int min_bars = strategy_atr_period + sqrt_period + 20;
   const int requested = MathMax(strategy_warmup_bars, min_bars);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, requested, rates); // perf-allowed: exact HMA(TR) SuperTrend window, called only from the skeleton's closed-bar entry path.
   if(copied < min_bars)
      return false;

   const int oldest_shift = copied - strategy_atr_period - sqrt_period - 1;
   if(oldest_shift < 2)
      return false;

   double prev_final_upper = 0.0;
   double prev_final_lower = 0.0;
   int prev_direction = 0;

   for(int shift = oldest_shift; shift >= 1; --shift)
     {
      const double high = RateHigh(rates, copied, shift);
      const double low = RateLow(rates, copied, shift);
      const double close = RateClose(rates, copied, shift);
      const double prev_close = RateClose(rates, copied, shift + 1);
      const double atr = HmaTrueRange(rates, copied, strategy_atr_period, shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || prev_close <= 0.0 || atr <= 0.0)
         return false;

      const double mid = (high + low) * 0.5;
      const double basic_upper = mid + strategy_atr_multiplier * atr;
      const double basic_lower = mid - strategy_atr_multiplier * atr;

      double final_upper = basic_upper;
      double final_lower = basic_lower;
      int bar_direction = prev_direction;

      if(prev_direction == 0)
        {
         bar_direction = (close >= mid) ? 1 : -1;
        }
      else
        {
         final_upper = (basic_upper < prev_final_upper || prev_close > prev_final_upper) ? basic_upper : prev_final_upper;
         final_lower = (basic_lower > prev_final_lower || prev_close < prev_final_lower) ? basic_lower : prev_final_lower;

         if(prev_direction < 0)
            bar_direction = (close > final_upper) ? 1 : -1;
         else
            bar_direction = (close < final_lower) ? -1 : 1;
        }

      const double bar_supertrend = (bar_direction > 0) ? final_lower : final_upper;
      prev_final_upper = final_upper;
      prev_final_lower = final_lower;
      prev_direction = bar_direction;

      if(shift == 1)
        {
         supertrend = bar_supertrend;
         direction = bar_direction;
        }
     }

   return (supertrend > 0.0 && direction != 0);
  }

bool GetOurPosition(int &position_direction, ulong &ticket)
  {
   position_direction = 0;
   ticket = 0;
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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      position_direction = (type == POSITION_TYPE_BUY) ? 1 : -1;
      ticket = pos_ticket;
      return true;
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

   double supertrend = 0.0;
   int signal_direction = 0;
   if(!CalculateSuperTrend(supertrend, signal_direction))
      return false;

   int current_direction = 0;
   ulong ticket = 0;
   if(GetOurPosition(current_direction, ticket))
     {
      if(current_direction == signal_direction)
         return false;
      if(!QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL))
         return false;
     }

   const bool go_long = (signal_direction > 0);
   req.type = go_long ? QM_BUY : QM_SELL;
   req.reason = go_long ? "CINAR_SUPERTREND_LONG" : "CINAR_SUPERTREND_SHORT";

   const double entry_price = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double fallback_sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_fallback_atr_sl_mult);
   if(go_long && supertrend > 0.0 && supertrend < entry_price)
      req.sl = supertrend;
   else if(!go_long && supertrend > entry_price)
      req.sl = supertrend;
   else
      req.sl = fallback_sl;

   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   // Source strategy uses the SuperTrend flip as the management rule; no BE,
   // partial, pyramiding, or independent trailing rule is specified.
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10286_cinar-supertrend\"}");
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
