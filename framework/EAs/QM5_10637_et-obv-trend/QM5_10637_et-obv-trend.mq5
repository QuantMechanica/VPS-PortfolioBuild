#property strict
#property version   "5.0"
#property description "QM5_10637 Elite Trader OBV Trend Continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10637;
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
input int    strategy_pullback_sma_period = 20;
input int    strategy_trend_mid_sma       = 50;
input int    strategy_trend_long_sma      = 100;
input int    strategy_atr_period          = 14;
input double strategy_pullback_atr_mult   = 1.0;
input int    strategy_macd_fast           = 12;
input int    strategy_macd_slow           = 26;
input int    strategy_macd_signal         = 9;
input int    strategy_divergence_lookback = 20;
input int    strategy_roc_period          = 6;
input int    strategy_obv_slope_window    = 25;
input int    strategy_swing_lookback      = 10;
input double strategy_swing_atr_buffer    = 0.50;
input int    strategy_atr_percentile_bars = 252;
input double strategy_atr_percentile_max  = 0.90;
input double strategy_max_spread_stop_pct = 0.10;
input int    strategy_time_exit_bars      = 20;

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

   if(strategy_pullback_sma_period < 2 ||
      strategy_trend_mid_sma < 2 ||
      strategy_trend_long_sma < 2 ||
      strategy_atr_period < 2 ||
      strategy_pullback_atr_mult <= 0.0 ||
      strategy_macd_fast < 1 ||
      strategy_macd_slow <= strategy_macd_fast ||
      strategy_macd_signal < 1 ||
      strategy_divergence_lookback < 6 ||
      strategy_roc_period < 1 ||
      strategy_obv_slope_window < 2 ||
      strategy_swing_lookback < 2 ||
      strategy_swing_atr_buffer < 0.0 ||
      strategy_atr_percentile_bars < 20 ||
      strategy_atr_percentile_max <= 0.0 ||
      strategy_atr_percentile_max >= 1.0 ||
      strategy_max_spread_stop_pct <= 0.0 ||
      strategy_time_exit_bars < 1)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const ENUM_TIMEFRAMES tf = PERIOD_D1;
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   int atr_valid = 0;
   int atr_rank = 0;
   for(int shift = 2; shift < 2 + strategy_atr_percentile_bars; ++shift)
     {
      const double atr_prior = QM_ATR(_Symbol, tf, strategy_atr_period, shift);
      if(atr_prior <= 0.0)
         continue;
      atr_valid++;
      if(atr >= atr_prior)
         atr_rank++;
     }
   if(atr_valid < (strategy_atr_percentile_bars / 2))
      return false;
   if(((double)atr_rank / (double)atr_valid) > strategy_atr_percentile_max)
      return false;

   const double close1 = iClose(_Symbol, tf, 1); // perf-allowed: fixed D1 close read for card ROC/pullback logic behind framework QM_IsNewBar gate.
   const double close2 = iClose(_Symbol, tf, 2); // perf-allowed: fixed D1 close read for ROC cross behind framework QM_IsNewBar gate.
   const double close_roc_ref = iClose(_Symbol, tf, 1 + strategy_roc_period); // perf-allowed: bounded D1 ROC proxy for proprietary Hausse Index.
   const double close_roc_prev_ref = iClose(_Symbol, tf, 2 + strategy_roc_period); // perf-allowed: bounded D1 ROC proxy for zero-cross confirmation.
   if(close1 <= 0.0 || close2 <= 0.0 || close_roc_ref <= 0.0 || close_roc_prev_ref <= 0.0)
      return false;

   const double pullback_sma = QM_SMA(_Symbol, tf, strategy_pullback_sma_period, 1);
   const double trend_mid_sma = QM_SMA(_Symbol, tf, strategy_trend_mid_sma, 1);
   const double trend_long_sma = QM_SMA(_Symbol, tf, strategy_trend_long_sma, 1);
   if(pullback_sma <= 0.0 || trend_mid_sma <= 0.0 || trend_long_sma <= 0.0)
      return false;

   const double roc_now = close1 - close_roc_ref;
   const double roc_prev = close2 - close_roc_prev_ref;
   const bool roc_cross_up = (roc_now > 0.0 && roc_prev <= 0.0);
   const bool roc_cross_down = (roc_now < 0.0 && roc_prev >= 0.0);

   double obv_delta = 0.0;
   for(int shift = 1; shift <= strategy_obv_slope_window; ++shift)
     {
      const double c_now = iClose(_Symbol, tf, shift); // perf-allowed: bounded OBV(25) slope, EntrySignal is framework new-bar gated.
      const double c_prev = iClose(_Symbol, tf, shift + 1); // perf-allowed: bounded OBV(25) slope, EntrySignal is framework new-bar gated.
      const long vol = iVolume(_Symbol, tf, shift); // perf-allowed: MT5 tick volume is the card's OBV input, bounded to OBV window.
      if(c_now <= 0.0 || c_prev <= 0.0 || vol <= 0)
         continue;
      if(c_now > c_prev)
         obv_delta += (double)vol;
      else if(c_now < c_prev)
         obv_delta -= (double)vol;
     }

   bool newest_high_found = false;
   bool older_high_found = false;
   double newest_high = 0.0;
   double older_high = 0.0;
   double newest_high_hist = 0.0;
   double older_high_hist = 0.0;
   bool newest_low_found = false;
   bool older_low_found = false;
   double newest_low = 0.0;
   double older_low = 0.0;
   double newest_low_hist = 0.0;
   double older_low_hist = 0.0;

   for(int shift = 2; shift <= strategy_divergence_lookback; ++shift)
     {
      const double hi = iHigh(_Symbol, tf, shift); // perf-allowed: bounded 20-bar swing scan for card MACD-divergence veto.
      const double hi_newer = iHigh(_Symbol, tf, shift - 1); // perf-allowed: bounded swing-high neighbor read.
      const double hi_older = iHigh(_Symbol, tf, shift + 1); // perf-allowed: bounded swing-high neighbor read.
      const double lo = iLow(_Symbol, tf, shift); // perf-allowed: bounded 20-bar swing scan for mirrored MACD-divergence veto.
      const double lo_newer = iLow(_Symbol, tf, shift - 1); // perf-allowed: bounded swing-low neighbor read.
      const double lo_older = iLow(_Symbol, tf, shift + 1); // perf-allowed: bounded swing-low neighbor read.
      const double hist = QM_MACD_Main(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift) -
                          QM_MACD_Signal(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);

      if(hi > 0.0 && hi > hi_newer && hi > hi_older)
        {
         if(!newest_high_found)
           {
            newest_high_found = true;
            newest_high = hi;
            newest_high_hist = hist;
           }
         else if(!older_high_found)
           {
            older_high_found = true;
            older_high = hi;
            older_high_hist = hist;
           }
        }

      if(lo > 0.0 && lo < lo_newer && lo < lo_older)
        {
         if(!newest_low_found)
           {
            newest_low_found = true;
            newest_low = lo;
            newest_low_hist = hist;
           }
         else if(!older_low_found)
           {
            older_low_found = true;
            older_low = lo;
            older_low_hist = hist;
           }
        }
     }

   const bool bearish_divergence = (newest_high_found && older_high_found &&
                                    newest_high > older_high &&
                                    newest_high_hist < older_high_hist);
   const bool bullish_divergence = (newest_low_found && older_low_found &&
                                    newest_low < older_low &&
                                    newest_low_hist > older_low_hist);

   double swing_low = DBL_MAX;
   double swing_high = -DBL_MAX;
   for(int shift = 1; shift <= strategy_swing_lookback; ++shift)
     {
      const double lo = iLow(_Symbol, tf, shift); // perf-allowed: bounded 10-bar structural stop from card.
      const double hi = iHigh(_Symbol, tf, shift); // perf-allowed: bounded 10-bar structural stop from card.
      if(lo > 0.0)
         swing_low = MathMin(swing_low, lo);
      if(hi > 0.0)
         swing_high = MathMax(swing_high, hi);
     }
   if(swing_low == DBL_MAX || swing_high == -DBL_MAX)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;
   const double spread = ask - bid;

   if(close1 > trend_long_sma &&
      pullback_sma > trend_mid_sma &&
      MathAbs(close1 - pullback_sma) <= strategy_pullback_atr_mult * atr &&
      close1 > trend_mid_sma &&
      !bearish_divergence &&
      roc_cross_up &&
      obv_delta > 0.0)
     {
      const double sl = swing_low - strategy_swing_atr_buffer * atr;
      const double stop_distance = ask - sl;
      if(sl <= 0.0 || stop_distance <= 0.0 || spread > strategy_max_spread_stop_pct * stop_distance)
         return false;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "ET_OBV_TREND_LONG";
      return true;
     }

   if(close1 < trend_long_sma &&
      pullback_sma < trend_mid_sma &&
      MathAbs(close1 - pullback_sma) <= strategy_pullback_atr_mult * atr &&
      close1 < trend_mid_sma &&
      !bullish_divergence &&
      roc_cross_down &&
      obv_delta < 0.0)
     {
      const double sl = swing_high + strategy_swing_atr_buffer * atr;
      const double stop_distance = sl - bid;
      if(sl <= 0.0 || stop_distance <= 0.0 || spread > strategy_max_spread_stop_pct * stop_distance)
         return false;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "ET_OBV_TREND_SHORT";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing stop, or partial close.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const ENUM_TIMEFRAMES tf = PERIOD_D1;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at > 0 && (TimeCurrent() - opened_at) >= (strategy_time_exit_bars * PeriodSeconds(tf)))
         return true;

      const double hist1 = QM_MACD_Main(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1) -
                           QM_MACD_Signal(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
      const double hist2 = QM_MACD_Main(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2) -
                           QM_MACD_Signal(_Symbol, tf, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);

      const double close1 = iClose(_Symbol, tf, 1); // perf-allowed: fixed D1 close read for card ROC exit behind framework exit hook.
      const double close2 = iClose(_Symbol, tf, 2); // perf-allowed: fixed D1 close read for card ROC exit behind framework exit hook.
      const double close_roc_ref = iClose(_Symbol, tf, 1 + strategy_roc_period); // perf-allowed: fixed D1 ROC exit proxy.
      const double close_roc_prev_ref = iClose(_Symbol, tf, 2 + strategy_roc_period); // perf-allowed: fixed D1 ROC exit proxy.
      if(close1 <= 0.0 || close2 <= 0.0 || close_roc_ref <= 0.0 || close_roc_prev_ref <= 0.0)
         return false;

      const double roc_now = close1 - close_roc_ref;
      const double roc_prev = close2 - close_roc_prev_ref;

      if(ptype == POSITION_TYPE_BUY)
        {
         if(hist2 >= 0.0 && hist1 < 0.0)
            return true;
         if(roc_now < 0.0 && roc_prev >= 0.0)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(hist2 <= 0.0 && hist1 > 0.0)
            return true;
         if(roc_now > 0.0 && roc_prev <= 0.0)
            return true;
        }
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line.
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
