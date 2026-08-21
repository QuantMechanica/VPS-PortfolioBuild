#property strict
#property version   "5.0"
#property description "QM5_36006 NNFX HalfTrend & Jurik Velocity Engine"
// Strategy Card: QM5_36006 (nnfx-halftrend-jurik-coppock-engine), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_36006
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 36006;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.5;
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
input int    strategy_halftrend_amp       = 2;      // HalfTrend amplitude setting
input int    strategy_halftrend_atr_period= 100;    // HalfTrend ATR period for hysteresis
input int    strategy_jurik_period        = 14;     // Jurik JMA smoothing period
input int    strategy_coppock_roc1        = 14;     // Coppock primary ROC period
input int    strategy_coppock_roc2        = 11;     // Coppock secondary ROC period
input int    strategy_coppock_wma         = 10;     // Coppock WMA smoothing period
input int    strategy_cmf_period          = 20;     // Chaikin Money Flow lookback
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 1.00;   // Stop loss ATR multiplier
input double strategy_tp_atr_mult         = 1.00;   // Take profit ATR multiplier
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier

// -----------------------------------------------------------------------------
// Helpers & Indicator Math
// -----------------------------------------------------------------------------

int GetBarHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
}

bool Strategy_HasOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;
   return (QM_TM_OpenPositionCount(magic) > 0);
}

bool Strategy_HalfTrend(const string sym, const int amplitude, const int atr_period, const int shift, double &ht_val, int &ht_trend)
{
   ht_val = 0.0;
   ht_trend = 0;
   if(amplitude < 1 || atr_period < 1 || shift < 1) return false;

   const int warmup = 50;
   const int start_shift = shift + warmup;

   int trend = -1;
   double max_low = iLow(sym, PERIOD_D1, start_shift);
   double min_high = iHigh(sym, PERIOD_D1, start_shift);
   if(max_low <= 0.0 || min_high <= 0.0) return false;

   for(int s = start_shift - 1; s >= shift; --s)
   {
      double h_max = 0.0, l_min = 0.0;
      for(int k = 0; k < amplitude; ++k)
      {
         const double h = iHigh(sym, PERIOD_D1, s + k); // perf-allowed: closed-bar read behind QM_IsNewBar()
         const double l = iLow(sym, PERIOD_D1, s + k);
         if(h <= 0.0 || l <= 0.0) return false;
         if(k == 0 || h > h_max) h_max = h;
         if(k == 0 || l < l_min) l_min = l;
      }

      const double high_ma = QM_SMA(sym, PERIOD_D1, amplitude, s, PRICE_HIGH);
      const double low_ma = QM_SMA(sym, PERIOD_D1, amplitude, s, PRICE_LOW);
      const double atr = QM_ATR(sym, PERIOD_D1, atr_period, s);
      const double b_high = iHigh(sym, PERIOD_D1, s);
      const double b_low = iLow(sym, PERIOD_D1, s);
      if(high_ma <= 0.0 || low_ma <= 0.0 || atr <= 0.0 || b_high <= 0.0 || b_low <= 0.0) return false;

      const double dev = 2.0 * (atr / 2.0) / 100.0;

      if(trend == -1 && high_ma < min_high && b_low > (min_high + dev))
      {
         trend = 1;
         max_low = l_min;
      }
      else if(trend == 1 && low_ma > max_low && b_high < (max_low - dev))
      {
         trend = -1;
         min_high = h_max;
      }
      else
      {
         if(trend == 1) max_low = MathMax(max_low, l_min);
         else min_high = MathMin(min_high, h_max);
      }
   }

   ht_trend = trend;
   ht_val = (trend == 1) ? max_low : min_high;
   return true;
}

double Strategy_JMA(const string sym, const int period, const int shift)
{
   if(period <= 1 || shift < 1) return 0.0;
   const int warmup = period * 4 + 20;
   const int start_shift = shift + warmup;

   const double alpha = 2.0 / ((double)period + 1.0);
   const double c_start = iClose(sym, PERIOD_D1, start_shift); // perf-allowed: closed-bar read behind QM_IsNewBar()
   if(c_start <= 0.0) return 0.0;

   double e1 = c_start, e2 = c_start, e3 = c_start;
   for(int s = start_shift; s >= shift; --s)
   {
      const double c = iClose(sym, PERIOD_D1, s);
      if(c <= 0.0) return 0.0;
      e1 = alpha * c + (1.0 - alpha) * e1;
      e2 = alpha * e1 + (1.0 - alpha) * e2;
      e3 = alpha * e2 + (1.0 - alpha) * e3;
   }
   return (3.0 * e1 - 3.0 * e2 + e3);
}

double Strategy_JurikVelocity(const string sym, const int period, const int shift)
{
   const double jma_now = Strategy_JMA(sym, period, shift);
   const double jma_prev = Strategy_JMA(sym, period, shift + 1);
   if(jma_now <= 0.0 || jma_prev <= 0.0) return 0.0;
   return (jma_now - jma_prev);
}

double Strategy_Coppock(const string sym, const int roc1, const int roc2, const int wma_len, const int shift)
{
   if(roc1 <= 0 || roc2 <= 0 || wma_len <= 0 || shift < 1) return 0.0;
   double sum_w = 0.0;
   double sum_weight = 0.0;
   for(int i = 0; i < wma_len; ++i)
   {
      const int s = shift + i;
      const double c_curr = iClose(sym, PERIOD_D1, s); // perf-allowed: closed-bar read behind QM_IsNewBar()
      const double c_roc1 = iClose(sym, PERIOD_D1, s + roc1);
      const double c_roc2 = iClose(sym, PERIOD_D1, s + roc2);
      if(c_curr <= 0.0 || c_roc1 <= 0.0 || c_roc2 <= 0.0) return 0.0;

      const double r1 = (c_curr - c_roc1) / c_roc1 * 100.0;
      const double r2 = (c_curr - c_roc2) / c_roc2 * 100.0;
      const double roc_sum = r1 + r2;

      const double weight = (double)(wma_len - i);
      sum_w += roc_sum * weight;
      sum_weight += weight;
   }
   if(sum_weight <= 0.0) return 0.0;
   return (sum_w / sum_weight);
}

double Strategy_CMF(const string sym, const int period, const int shift)
{
   if(period <= 1 || shift < 1) return 0.0;
   double mfv_sum = 0.0;
   double vol_sum = 0.0;
   for(int i = 0; i < period; ++i)
   {
      const int s = shift + i;
      const double h = iHigh(sym, PERIOD_D1, s); // perf-allowed: closed-bar read behind QM_IsNewBar()
      const double l = iLow(sym, PERIOD_D1, s);
      const double c = iClose(sym, PERIOD_D1, s);
      const long v = iTickVolume(sym, PERIOD_D1, s);
      if(h <= 0.0 || l <= 0.0 || c <= 0.0 || v <= 0) continue;
      const double range = h - l;
      if(range <= 0.0) continue;
      const double mult = ((c - l) - (h - c)) / range;
      mfv_sum += mult * (double)v;
      vol_sum += (double)v;
   }
   if(vol_sum <= 0.0) return 0.0;
   return (mfv_sum / vol_sum);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const datetime now = TimeCurrent();
   const int hhmm = GetBarHhmm(now);
   if(hhmm >= 2355 || hhmm < 5)
      return true;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0 && atr_1 > 0.0)
   {
      const double spread_pts = (ask - bid) / point;
      const double atr_pts = atr_1 / point;
      if(spread_pts > strategy_spread_atr_mult * atr_pts)
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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   const double close_1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: closed-bar read behind QM_IsNewBar()
   if(close_1 <= 0.0)
      return false;

   double ht_val_1 = 0.0;
   int ht_trend_1 = 0;
   if(!Strategy_HalfTrend(_Symbol, strategy_halftrend_amp, strategy_halftrend_atr_period, 1, ht_val_1, ht_trend_1))
      return false;

   const double jurik_vel_1 = Strategy_JurikVelocity(_Symbol, strategy_jurik_period, 1);
   const double coppock_1 = Strategy_Coppock(_Symbol, strategy_coppock_roc1, strategy_coppock_roc2, strategy_coppock_wma, 1);
   const double cmf_1 = Strategy_CMF(_Symbol, strategy_cmf_period, 1);

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_1 <= 0.0)
      return false;

   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0)
      return false;

   const double sl_dist = MathMax(strategy_sl_atr_mult * atr_1, 10.0 * pip_size);
   const double tp_dist = MathMax(strategy_tp_atr_mult * atr_1, 10.0 * pip_size);

   // Long: Close[1] > HalfTrend[1] AND JurikVel[1] > 0 AND Coppock[1] > 0 AND CMF(20)[1] > +0.05
   if(close_1 > ht_val_1 && ht_trend_1 == 1 && jurik_vel_1 > 0.0 && coppock_1 > 0.0 && cmf_1 > 0.05)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : close_1;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, exec_price - sl_dist);
      req.tp = QM_TM_NormalizePrice(_Symbol, exec_price + tp_dist);
      req.reason = "nnfx_halftrend_jurik_long";
      return true;
   }

   // Short: Close[1] < HalfTrend[1] AND JurikVel[1] < 0 AND Coppock[1] < 0 AND CMF(20)[1] < -0.05
   if(close_1 < ht_val_1 && ht_trend_1 == -1 && jurik_vel_1 < 0.0 && coppock_1 < 0.0 && cmf_1 < -0.05)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : close_1;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, exec_price + sl_dist);
      req.tp = QM_TM_NormalizePrice(_Symbol, exec_price - tp_dist);
      req.reason = "nnfx_halftrend_jurik_short";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return;
   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0) return;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double be_trigger = (atr_1 > 0.0) ? (strategy_tp_atr_mult * atr_1) : (20.0 * pip_size);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0 || open_price <= 0.0) continue;

         // Move to break-even once open profit >= 1.0 ATR
         if((bid - open_price) >= be_trigger)
         {
            const double target_sl = QM_TM_NormalizePrice(_Symbol, open_price + 1.0 * pip_size);
            if(target_sl > current_sl + point * 0.5)
               QM_TM_MoveSL(ticket, target_sl, "nnfx_be_plus_1");
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0 || open_price <= 0.0) continue;

         // Move to break-even once open profit >= 1.0 ATR
         if((open_price - ask) >= be_trigger)
         {
            const double target_sl = QM_TM_NormalizePrice(_Symbol, open_price - 1.0 * pip_size);
            if(current_sl <= 0.0 || target_sl < current_sl - point * 0.5)
               QM_TM_MoveSL(ticket, target_sl, "nnfx_be_plus_1");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;

   double ht_val_1 = 0.0;
   int ht_trend_1 = 0;
   if(!Strategy_HalfTrend(_Symbol, strategy_halftrend_amp, strategy_halftrend_atr_period, 1, ht_val_1, ht_trend_1))
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Long exit: HalfTrend direction flips to down (-1)
      if(pos_type == POSITION_TYPE_BUY)
      {
         if(ht_trend_1 == -1)
            return true;
      }
      // Short exit: HalfTrend direction flips to up (1)
      else if(pos_type == POSITION_TYPE_SELL)
      {
         if(ht_trend_1 == 1)
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
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   if(!QM_IsNewBar()) return;
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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
