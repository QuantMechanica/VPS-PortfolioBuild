#property strict
#property version   "5.0"
#property description "QM5_9502 Chande CMO VR divergence H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_9502 - Chande CMO divergence with volatility-ratio trend gate
// -----------------------------------------------------------------------------
// H4 price-only reversal:
//   1. Require VR = ATR(7) / ATR(28) above the trending threshold.
//   2. Detect a just-confirmed 3-bar pivot with a 5-bar left-side extreme.
//   3. Compare that pivot with a prior pivot 6..30 H4 bars back.
//   4. Trade regular CMO divergence and exit on CMO zero-cross or time stop.
//
// Runtime uses MT5 OHLC only; no external feed, optimizer state, or ML.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 9502;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input int    strategy_cmo_period          = 14;
input int    strategy_vr_fast_atr         = 7;
input int    strategy_vr_slow_atr         = 28;
input double strategy_vr_min              = 1.30;
input int    strategy_pivot_left_bars     = 5;
input int    strategy_pivot_sep_min       = 6;
input int    strategy_pivot_sep_max       = 30;
input double strategy_cmo_extreme_level   = 35.0;
input int    strategy_atr_period          = 14;
input double strategy_sl_atr_mult         = 0.50;
input int    strategy_time_stop_bars      = 20;
input double strategy_spread_atr_frac_max = 0.20;
input bool   strategy_shorts_enabled      = true;

bool Strategy_CMO(const int shift, double &out_cmo)
  {
   out_cmo = 0.0;
   if(strategy_cmo_period <= 0 || shift < 1)
      return false;

   double sum_up = 0.0;
   double sum_down = 0.0;
   for(int i = shift; i < shift + strategy_cmo_period; ++i)
     {
      const double c0 = iClose(_Symbol, PERIOD_H4, i);     // perf-allowed: bounded CMO close-to-close sum.
      const double c1 = iClose(_Symbol, PERIOD_H4, i + 1); // perf-allowed: bounded CMO close-to-close sum.
      if(c0 <= 0.0 || c1 <= 0.0)
         return false;

      const double diff = c0 - c1;
      if(diff > 0.0)
         sum_up += diff;
      else
         sum_down -= diff;
     }

   const double denom = sum_up + sum_down;
   if(denom <= 0.0)
      return false;

   out_cmo = 100.0 * (sum_up - sum_down) / denom;
   return MathIsValidNumber(out_cmo);
  }

bool Strategy_PivotHigh(const int shift)
  {
   const int left = MathMax(1, strategy_pivot_left_bars);
   const double h = iHigh(_Symbol, PERIOD_H4, shift); // perf-allowed: bounded pivot high read for bespoke divergence geometry.
   if(h <= 0.0)
      return false;

   const double newer = iHigh(_Symbol, PERIOD_H4, shift - 1); // perf-allowed: adjacent confirmation bar for pivot geometry.
   const double older = iHigh(_Symbol, PERIOD_H4, shift + 1); // perf-allowed: adjacent historical bar for pivot geometry.
   if(newer <= 0.0 || older <= 0.0 || h <= newer || h <= older)
      return false;

   for(int k = shift + 1; k <= shift + left; ++k)
     {
      const double hk = iHigh(_Symbol, PERIOD_H4, k); // perf-allowed: bounded five-bar pivot-high confirmation window.
      if(hk <= 0.0 || h < hk)
         return false;
     }
   return true;
  }

bool Strategy_PivotLow(const int shift)
  {
   const int left = MathMax(1, strategy_pivot_left_bars);
   const double l = iLow(_Symbol, PERIOD_H4, shift); // perf-allowed: bounded pivot low read for bespoke divergence geometry.
   if(l <= 0.0)
      return false;

   const double newer = iLow(_Symbol, PERIOD_H4, shift - 1); // perf-allowed: adjacent confirmation bar for pivot geometry.
   const double older = iLow(_Symbol, PERIOD_H4, shift + 1); // perf-allowed: adjacent historical bar for pivot geometry.
   if(newer <= 0.0 || older <= 0.0 || l >= newer || l >= older)
      return false;

   for(int k = shift + 1; k <= shift + left; ++k)
     {
      const double lk = iLow(_Symbol, PERIOD_H4, k); // perf-allowed: bounded five-bar pivot-low confirmation window.
      if(lk <= 0.0 || l > lk)
         return false;
     }
   return true;
  }

bool Strategy_HasOpenPosition()
  {
   return (QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
  }

bool Strategy_FindPosition(ulong &ticket,
                           ENUM_POSITION_TYPE &position_type,
                           datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      ticket = pos_ticket;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_SpreadAllowed(const double atr)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || atr <= 0.0)
      return false;

   if(ask > bid && strategy_spread_atr_frac_max > 0.0)
     {
      const double spread_price = ask - bid;
      if(spread_price > strategy_spread_atr_frac_max * atr)
         return false;
     }
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H4)
      return true;

   if(strategy_cmo_period <= 1 ||
      strategy_vr_fast_atr <= 0 ||
      strategy_vr_slow_atr <= strategy_vr_fast_atr ||
      strategy_vr_min <= 0.0 ||
      strategy_pivot_left_bars <= 0 ||
      strategy_pivot_sep_min <= 0 ||
      strategy_pivot_sep_max < strategy_pivot_sep_min ||
      strategy_cmo_extreme_level <= 0.0 ||
      strategy_atr_period <= 0 ||
      strategy_sl_atr_mult <= 0.0 ||
      strategy_time_stop_bars <= 0 ||
      strategy_spread_atr_frac_max < 0.0)
      return true;

   const int warmup = strategy_pivot_sep_max + strategy_pivot_left_bars + strategy_cmo_period + 5;
   if(Bars(_Symbol, PERIOD_H4) < warmup) // perf-allowed: O(1) warm-up availability check.
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

   if(Strategy_HasOpenPosition())
      return false;

   const double atr_fast = QM_ATR(_Symbol, PERIOD_H4, strategy_vr_fast_atr, 1);
   const double atr_slow = QM_ATR(_Symbol, PERIOD_H4, strategy_vr_slow_atr, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr_fast <= 0.0 || atr_slow <= 0.0 || atr <= 0.0)
      return false;

   const double vr = atr_fast / atr_slow;
   if(vr <= strategy_vr_min)
      return false;
   if(!Strategy_SpreadAllowed(atr))
      return false;

   double cmo_signal = 0.0;
   double cmo_pivot = 0.0;
   if(!Strategy_CMO(1, cmo_signal) || !Strategy_CMO(2, cmo_pivot))
      return false;

   const double close_signal = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: fixed closed signal bar.
   const double close_pivot = iClose(_Symbol, PERIOD_H4, 2);  // perf-allowed: fixed closed pivot bar.
   if(close_signal <= 0.0 || close_pivot <= 0.0)
      return false;

   // Bearish regular CMO divergence: price higher-high, CMO lower-high.
   if(strategy_shorts_enabled && Strategy_PivotHigh(2))
     {
      const double high_pivot = iHigh(_Symbol, PERIOD_H4, 2); // perf-allowed: fixed confirmed pivot high for SL and divergence test.
      for(int prior = 2 + strategy_pivot_sep_min;
          prior <= 2 + strategy_pivot_sep_max;
          ++prior)
        {
         if(!Strategy_PivotHigh(prior))
            continue;

         double cmo_prior = 0.0;
         if(!Strategy_CMO(prior, cmo_prior))
            return false;

         const double high_prior = iHigh(_Symbol, PERIOD_H4, prior); // perf-allowed: bounded prior pivot high comparison.
         if(high_prior <= 0.0)
            return false;

         const bool price_hh = (high_pivot > high_prior);
         const bool cmo_lh = (cmo_pivot < cmo_prior);
         const bool prior_extreme = (cmo_prior > strategy_cmo_extreme_level);
         const bool cmo_turn = (cmo_signal < cmo_pivot);
         const bool price_confirm = (close_signal < close_pivot);
         if(price_hh && cmo_lh && prior_extreme && cmo_turn && price_confirm)
           {
            const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(bid <= 0.0)
               return false;

            const double sl = QM_StopRulesNormalizePrice(_Symbol,
                              high_pivot + strategy_sl_atr_mult * atr);
            if(sl <= bid)
               return false;

            req.type = QM_SELL;
            req.price = 0.0;
            req.sl = sl;
            req.tp = 0.0;
            req.reason = "cmo_vr_bearish_divergence";
            req.symbol_slot = qm_magic_slot_offset;
            return true;
           }
        }
     }

   // Bullish regular CMO divergence: price lower-low, CMO higher-low.
   if(Strategy_PivotLow(2))
     {
      const double low_pivot = iLow(_Symbol, PERIOD_H4, 2); // perf-allowed: fixed confirmed pivot low for SL and divergence test.
      for(int prior = 2 + strategy_pivot_sep_min;
          prior <= 2 + strategy_pivot_sep_max;
          ++prior)
        {
         if(!Strategy_PivotLow(prior))
            continue;

         double cmo_prior = 0.0;
         if(!Strategy_CMO(prior, cmo_prior))
            return false;

         const double low_prior = iLow(_Symbol, PERIOD_H4, prior); // perf-allowed: bounded prior pivot low comparison.
         if(low_prior <= 0.0)
            return false;

         const bool price_ll = (low_pivot < low_prior);
         const bool cmo_hl = (cmo_pivot > cmo_prior);
         const bool prior_extreme = (cmo_prior < -strategy_cmo_extreme_level);
         const bool cmo_turn = (cmo_signal > cmo_pivot);
         const bool price_confirm = (close_signal > close_pivot);
         if(price_ll && cmo_hl && prior_extreme && cmo_turn && price_confirm)
           {
            const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(ask <= 0.0)
               return false;

            const double sl = QM_StopRulesNormalizePrice(_Symbol,
                              low_pivot - strategy_sl_atr_mult * atr);
            if(sl <= 0.0 || sl >= ask)
               return false;

            req.type = QM_BUY;
            req.price = 0.0;
            req.sl = sl;
            req.tp = 0.0;
            req.reason = "cmo_vr_bullish_divergence";
            req.symbol_slot = qm_magic_slot_offset;
            return true;
           }
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime open_time = 0;
   if(!Strategy_FindPosition(ticket, position_type, open_time))
      return false;

   const int h4_seconds = PeriodSeconds(PERIOD_H4);
   if(h4_seconds > 0 && open_time > 0 &&
      TimeCurrent() - open_time >= strategy_time_stop_bars * h4_seconds)
      return true;

   double cmo_now = 0.0;
   double cmo_prev = 0.0;
   if(!Strategy_CMO(1, cmo_now) || !Strategy_CMO(2, cmo_prev))
      return false;

   if(position_type == POSITION_TYPE_BUY && cmo_prev <= 0.0 && cmo_now > 0.0)
      return true;
   if(position_type == POSITION_TYPE_SELL && cmo_prev >= 0.0 && cmo_now < 0.0)
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
                        60,
                        60,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_9502\",\"ea\":\"chande-cmo-vr-divergence-h4\"}");
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
