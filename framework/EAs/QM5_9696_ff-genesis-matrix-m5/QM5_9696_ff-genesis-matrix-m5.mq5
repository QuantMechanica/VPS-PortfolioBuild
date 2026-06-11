#property strict
#property version   "5.0"
#property description "QM5_9696 ForexFactory Genesis Matrix M5 Session Momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9696_ff-genesis-matrix-m5
// Strategy Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_9696_ff-genesis-matrix-m5.md
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9696;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
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
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_M5;
input int    strategy_session_start_hhmm          = 800;
input int    strategy_session_end_hhmm            = 1830;
input int    strategy_max_spread_points           = 250;
input int    strategy_ema_period                  = 5;
input int    strategy_stoch_k_period              = 14;
input int    strategy_stoch_d_period              = 3;
input int    strategy_stoch_slowing               = 3;
input int    strategy_stoch_cross_lookback        = 3;
input double strategy_stoch_long_cross_level      = 35.0;
input double strategy_stoch_short_cross_level     = 65.0;
input int    strategy_atr_period                  = 14;
input int    strategy_atr_median_days             = 20;
input double strategy_min_atr_median_ratio        = 0.60;
input int    strategy_m5_bars_per_day             = 288;
input int    strategy_swing_lookback              = 8;
input double strategy_sl_atr_padding              = 0.20;
input double strategy_take_profit_r               = 1.60;
input int    strategy_time_stop_bars              = 18;
input int    strategy_tvi_lookback                = 8;
input int    strategy_cci_period                  = 20;
input double strategy_cci_neutral_band            = 0.0;
input int    strategy_t3_proxy_period             = 8;
input int    strategy_gann_hilo_period            = 10;
input int    strategy_heiken_ashi_warmup          = 20;
input bool   strategy_news_first5_enabled         = true;

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

bool InSession(const datetime broker_time)
  {
   const int now = Hhmm(broker_time);
   if(strategy_session_start_hhmm <= strategy_session_end_hhmm)
      return (now >= strategy_session_start_hhmm && now <= strategy_session_end_hhmm);
   return (now >= strategy_session_start_hhmm || now <= strategy_session_end_hhmm);
  }

bool CurrentPosition(ENUM_POSITION_TYPE &ptype, datetime &opened_at)
  {
   ptype = POSITION_TYPE_BUY;
   opened_at = 0;
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
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

bool AtrSessionMedianAllowsTrade()
  {
   if(strategy_atr_median_days <= 0 || strategy_min_atr_median_ratio <= 0.0)
      return true;

   const double current_atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(current_atr <= 0.0)
      return false;

   double samples[];
   ArrayResize(samples, 0);
   for(int day = 1; day <= strategy_atr_median_days; ++day)
     {
      const int shift = 1 + day * strategy_m5_bars_per_day;
      const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, shift);
      if(atr <= 0.0)
         continue;
      const int n = ArraySize(samples);
      ArrayResize(samples, n + 1);
      samples[n] = atr;
     }

   const int count = ArraySize(samples);
   if(count < 5)
      return true;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(samples[j] < samples[i])
           {
            const double tmp = samples[i];
            samples[i] = samples[j];
            samples[j] = tmp;
           }

   const double median = (count % 2 == 1) ? samples[count / 2]
                                         : 0.5 * (samples[count / 2 - 1] + samples[count / 2]);
   return (median > 0.0 && current_atr >= strategy_min_atr_median_ratio * median);
  }

int TviProxyDirection(const int shift)
  {
   double score = 0.0;
   for(int i = shift; i < shift + strategy_tvi_lookback; ++i)
     {
      const double close_now = iClose(_Symbol, strategy_timeframe, i);      // perf-allowed: bounded TVI proxy, called from closed-bar logic
      const double close_prev = iClose(_Symbol, strategy_timeframe, i + 1); // perf-allowed: bounded TVI proxy, called from closed-bar logic
      const long volume = iVolume(_Symbol, strategy_timeframe, i);          // perf-allowed: bounded TVI proxy, called from closed-bar logic
      if(close_now <= 0.0 || close_prev <= 0.0)
         continue;
      if(close_now > close_prev)
         score += (double)volume;
      else if(close_now < close_prev)
         score -= (double)volume;
     }
   if(score > 0.0)
      return 1;
   if(score < 0.0)
      return -1;
   return 0;
  }

int CciDirection(const int shift)
  {
   const double cci = QM_CCI(_Symbol, strategy_timeframe, strategy_cci_period, shift);
   if(cci > strategy_cci_neutral_band)
      return 1;
   if(cci < -strategy_cci_neutral_band)
      return -1;
   return 0;
  }

int T3ProxyDirection(const int shift)
  {
   const double ema_now = QM_EMA(_Symbol, strategy_timeframe, strategy_t3_proxy_period, shift);
   const double ema_prev = QM_EMA(_Symbol, strategy_timeframe, strategy_t3_proxy_period, shift + 1);
   if(ema_now > ema_prev)
      return 1;
   if(ema_now < ema_prev)
      return -1;
   return 0;
  }

int GannHiLoDirection(const int shift)
  {
   const double close = iClose(_Symbol, strategy_timeframe, shift); // perf-allowed: single close read for GannHiLo cell
   const double hi_ma = QM_SMA(_Symbol, strategy_timeframe, strategy_gann_hilo_period, shift, PRICE_HIGH);
   const double lo_ma = QM_SMA(_Symbol, strategy_timeframe, strategy_gann_hilo_period, shift, PRICE_LOW);
   if(close <= 0.0 || hi_ma <= 0.0 || lo_ma <= 0.0)
      return 0;
   if(close > hi_ma)
      return 1;
   if(close < lo_ma)
      return -1;
   return 0;
  }

int GenesisMatrixDirection(const int shift)
  {
   const int tvi = TviProxyDirection(shift);
   const int cci = CciDirection(shift);
   const int t3 = T3ProxyDirection(shift);
   const int gann = GannHiLoDirection(shift);
   if(tvi > 0 && cci > 0 && t3 > 0 && gann > 0)
      return 1;
   if(tvi < 0 && cci < 0 && t3 < 0 && gann < 0)
      return -1;
   return 0;
  }

int HeikenAshiDirection(const int shift)
  {
   const int warmup = MathMax(strategy_heiken_ashi_warmup, shift + 2);
   double ha_open = 0.0;
   double ha_close = 0.0;
   for(int i = warmup; i >= shift; --i)
     {
      const double open = iOpen(_Symbol, strategy_timeframe, i);   // perf-allowed: bounded HA calculation, closed-bar only
      const double high = iHigh(_Symbol, strategy_timeframe, i);   // perf-allowed: bounded HA calculation, closed-bar only
      const double low = iLow(_Symbol, strategy_timeframe, i);     // perf-allowed: bounded HA calculation, closed-bar only
      const double close = iClose(_Symbol, strategy_timeframe, i); // perf-allowed: bounded HA calculation, closed-bar only
      if(open <= 0.0 || high <= 0.0 || low <= 0.0 || close <= 0.0)
         continue;
      const double next_ha_close = (open + high + low + close) / 4.0;
      const double next_ha_open = (ha_open <= 0.0) ? (open + close) / 2.0
                                                   : (ha_open + ha_close) / 2.0;
      ha_open = next_ha_open;
      ha_close = next_ha_close;
     }
   if(ha_close > ha_open)
      return 1;
   if(ha_close < ha_open)
      return -1;
   return 0;
  }

bool CandleAboveEma(const int shift)
  {
   const double open = iOpen(_Symbol, strategy_timeframe, shift);   // perf-allowed: single closed-bar EMA-side confirmation
   const double close = iClose(_Symbol, strategy_timeframe, shift); // perf-allowed: single closed-bar EMA-side confirmation
   const double ema = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, shift);
   return (open > ema && close > ema);
  }

bool CandleBelowEma(const int shift)
  {
   const double open = iOpen(_Symbol, strategy_timeframe, shift);   // perf-allowed: single closed-bar EMA-side confirmation
   const double close = iClose(_Symbol, strategy_timeframe, shift); // perf-allowed: single closed-bar EMA-side confirmation
   const double ema = QM_EMA(_Symbol, strategy_timeframe, strategy_ema_period, shift);
   return (open > 0.0 && close > 0.0 && ema > 0.0 && open < ema && close < ema);
  }

bool StochCrossUpFromBelow()
  {
   const double k1 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   if(k1 <= k2)
      return false;
   for(int shift = 1; shift <= strategy_stoch_cross_lookback; ++shift)
     {
      const double k_now = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, shift);
      const double k_prev = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, shift + 1);
      if(k_now > strategy_stoch_long_cross_level && k_prev <= strategy_stoch_long_cross_level)
         return true;
     }
   return false;
  }

bool StochCrossDownFromAbove()
  {
   const double k1 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   if(k1 >= k2)
      return false;
   for(int shift = 1; shift <= strategy_stoch_cross_lookback; ++shift)
     {
      const double k_now = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, shift);
      const double k_prev = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, shift + 1);
      if(k_now < strategy_stoch_short_cross_level && k_prev >= strategy_stoch_short_cross_level)
         return true;
     }
   return false;
  }

bool LongStochExit()
  {
   const double k1 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   return (k1 < strategy_stoch_short_cross_level && k2 >= strategy_stoch_short_cross_level);
  }

bool ShortStochExit()
  {
   const double k1 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   return (k1 > strategy_stoch_long_cross_level && k2 <= strategy_stoch_long_cross_level);
  }

bool BuildMarketRequest(const QM_OrderType side, QM_EntryRequest &req)
  {
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   double sl = QM_StopStructure(_Symbol, side, entry, strategy_swing_lookback);
   if(sl <= 0.0)
      return false;
   if(side == QM_BUY)
      sl -= strategy_sl_atr_padding * atr;
   else
      sl += strategy_sl_atr_padding * atr;
   sl = NormalizeDouble(sl, _Digits);

   if((side == QM_BUY && sl >= entry) || (side == QM_SELL && sl <= entry))
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_take_profit_r);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   req.reason = (side == QM_BUY) ? "GENESIS_MATRIX_M5_LONG" : "GENESIS_MATRIX_M5_SHORT";
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(!InSession(TimeCurrent()))
      return true;

   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   if(!AtrSessionMedianAllowsTrade())
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int matrix = GenesisMatrixDirection(1);
   const int ha = HeikenAshiDirection(1);

   if(matrix > 0 && ha > 0 && CandleAboveEma(1) && StochCrossUpFromBelow())
      return BuildMarketRequest(QM_BUY, req);

   if(matrix < 0 && ha < 0 && CandleBelowEma(1) && StochCrossDownFromAbove())
      return BuildMarketRequest(QM_SELL, req);

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime opened_at;
   if(!CurrentPosition(ptype, opened_at))
      return false;

   const int seconds_per_bar = PeriodSeconds(strategy_timeframe);
   if(seconds_per_bar > 0 && opened_at > 0)
     {
      const int held_bars = (int)((TimeCurrent() - opened_at) / seconds_per_bar);
      if(held_bars >= strategy_time_stop_bars)
         return true;
     }

   const int matrix = GenesisMatrixDirection(1);
   if(ptype == POSITION_TYPE_BUY)
      return (matrix < 0 || LongStochExit());
   if(ptype == POSITION_TYPE_SELL)
      return (matrix > 0 || ShortStochExit());

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!strategy_news_first5_enabled)
      return false;
   const datetime utc_time = QM_BrokerToUTC(broker_time);
   return QM_NewsInWindow(utc_time, _Symbol, 0, 5, "high");
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9696_ff_genesis_matrix_m5\"}");
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
