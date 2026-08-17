#property strict
#property version   "5.0"
#property description "QM5_36003 NNFX Hull MA & ZeroLag MACD Fast Trend Engine"
// Strategy Card: QM5_36003 (nnfx-hull-ma-zerolag-macd-stc), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_36003
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 36003;
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
input int    strategy_hma_period          = 20;     // Hull Moving Average baseline period
input int    strategy_zl_macd_fast        = 12;     // ZeroLag MACD fast EMA
input int    strategy_zl_macd_slow        = 26;     // ZeroLag MACD slow EMA
input int    strategy_zl_macd_signal      = 9;      // ZeroLag MACD signal period
input int    strategy_stc_fast            = 23;     // Schaff Trend Cycle fast MACD period
input int    strategy_stc_slow            = 50;     // Schaff Trend Cycle slow MACD period
input int    strategy_stc_length          = 10;     // Schaff Trend Cycle stochastic lookback
input double strategy_stc_long_thresh     = 75.0;   // STC long confirmation threshold
input double strategy_stc_short_thresh    = 25.0;   // STC short confirmation threshold
input int    strategy_vol_avg_period      = 20;     // Better Volume lookback period
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

double Strategy_WMA(const string sym, const int period, const int shift)
{
   if(period <= 0 || shift < 1) return 0.0;
   double sum_w = 0.0;
   double sum_weight = 0.0;
   for(int k = 0; k < period; ++k)
   {
      const int s = shift + k;
      const double c = iClose(sym, PERIOD_D1, s); // perf-allowed: closed-bar WMA behind QM_IsNewBar()
      if(c <= 0.0) return 0.0;
      const double weight = (double)(period - k);
      sum_w += c * weight;
      sum_weight += weight;
   }
   if(sum_weight <= 0.0) return 0.0;
   return sum_w / sum_weight;
}

double Strategy_HMA(const string sym, const int period, const int shift)
{
   if(period < 4 || shift < 1) return 0.0;
   const int half_period = period / 2;
   const int sqrt_period = (int)MathRound(MathSqrt((double)period));
   if(sqrt_period < 1) return 0.0;

   // WMA(2 * WMA(half) - WMA(full), sqrt(period))
   double sum_w = 0.0;
   double sum_weight = 0.0;
   for(int k = 0; k < sqrt_period; ++k)
   {
      const int s = shift + k;
      const double w_half = Strategy_WMA(sym, half_period, s);
      const double w_full = Strategy_WMA(sym, period, s);
      if(w_half <= 0.0 || w_full <= 0.0) return 0.0;
      const double diff = 2.0 * w_half - w_full;
      const double weight = (double)(sqrt_period - k);
      sum_w += diff * weight;
      sum_weight += weight;
   }
   if(sum_weight <= 0.0) return 0.0;
   return sum_w / sum_weight;
}

double Strategy_ZeroLagEMA(const string sym, const int period, const int shift)
{
   if(period <= 0 || shift < 1) return 0.0;
   const double ema1 = QM_EMA(sym, PERIOD_D1, period, shift);
   const double close_val = iClose(sym, PERIOD_D1, shift);
   if(ema1 <= 0.0 || close_val <= 0.0) return 0.0;
   const double adj_price = 2.0 * close_val - ema1;
   const double alpha = 2.0 / ((double)period + 1.0);
   return (alpha * adj_price + (1.0 - alpha) * ema1);
}

bool Strategy_ZeroLagMACD(const string sym, const int fast_p, const int slow_p, const int sig_p, const int shift, double &zl_macd, double &zl_sig)
{
   zl_macd = 0.0;
   zl_sig = 0.0;
   if(fast_p <= 0 || slow_p <= 0 || sig_p <= 0 || shift < 1) return false;

   double macd_buf[16];
   for(int k = 0; k < sig_p; ++k)
   {
      const int s = shift + k;
      const double fast_z = Strategy_ZeroLagEMA(sym, fast_p, s);
      const double slow_z = Strategy_ZeroLagEMA(sym, slow_p, s);
      macd_buf[k] = fast_z - slow_z;
   }
   zl_macd = macd_buf[0];
   double sum_sig = 0.0;
   for(int k = 0; k < sig_p; ++k)
      sum_sig += macd_buf[k];
   zl_sig = sum_sig / (double)sig_p;
   return true;
}

double Strategy_STC(const string sym, const int fast_p, const int slow_p, const int stc_len, const int shift)
{
   if(shift < 1 || fast_p <= 0 || slow_p <= 0 || stc_len <= 0) return 50.0;

   const int total_pts = stc_len * 2 + 10;
   double macd_vals[];
   ArrayResize(macd_vals, total_pts);
   for(int i = 0; i < total_pts; ++i)
   {
      const int s = shift + i;
      const double fast_e = QM_EMA(sym, PERIOD_D1, fast_p, s);
      const double slow_e = QM_EMA(sym, PERIOD_D1, slow_p, s);
      macd_vals[i] = fast_e - slow_e;
   }

   // First Stochastic Cycle
   double d1_vals[];
   ArrayResize(d1_vals, stc_len + 10);
   for(int i = 0; i < stc_len + 10; ++i)
   {
      double min_m = macd_vals[i];
      double max_m = macd_vals[i];
      for(int j = 1; j < stc_len; ++j)
      {
         min_m = MathMin(min_m, macd_vals[i + j]);
         max_m = MathMax(max_m, macd_vals[i + j]);
      }
      const double range = max_m - min_m;
      const double k1 = (range > 0.0) ? ((macd_vals[i] - min_m) / range * 100.0) : 50.0;
      d1_vals[i] = k1;
   }

   // Second Stochastic Cycle
   double min_d = d1_vals[0];
   double max_d = d1_vals[0];
   for(int j = 1; j < stc_len; ++j)
   {
      min_d = MathMin(min_d, d1_vals[j]);
      max_d = MathMax(max_d, d1_vals[j]);
   }
   const double range_d = max_d - min_d;
   const double stc = (range_d > 0.0) ? ((d1_vals[0] - min_d) / range_d * 100.0) : 50.0;
   return MathMax(0.0, MathMin(100.0, stc));
}

bool Strategy_BetterVolumeHigh(const string sym, const int period, const int shift)
{
   if(period <= 0 || shift < 1) return false;
   const long vol_1 = iTickVolume(sym, PERIOD_D1, shift); // perf-allowed: closed-bar tick volume behind QM_IsNewBar()
   if(vol_1 <= 0) return false;
   long sum_vol = 0;
   for(int k = 0; k < period; ++k)
   {
      const long v = iTickVolume(sym, PERIOD_D1, shift + k);
      sum_vol += v;
   }
   const double avg_vol = (double)sum_vol / (double)period;
   return ((double)vol_1 >= avg_vol * 1.02);
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

   const double close_1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: closed-bar reference behind QM_IsNewBar()
   if(close_1 <= 0.0)
      return false;

   const double hma_1 = Strategy_HMA(_Symbol, strategy_hma_period, 1);
   if(hma_1 <= 0.0)
      return false;

   double zl_macd_1 = 0.0, zl_sig_1 = 0.0;
   if(!Strategy_ZeroLagMACD(_Symbol, strategy_zl_macd_fast, strategy_zl_macd_slow, strategy_zl_macd_signal, 1, zl_macd_1, zl_sig_1))
      return false;

   const double stc_1 = Strategy_STC(_Symbol, strategy_stc_fast, strategy_stc_slow, strategy_stc_length, 1);

   if(!Strategy_BetterVolumeHigh(_Symbol, strategy_vol_avg_period, 1))
      return false;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_1 <= 0.0)
      return false;

   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0)
      return false;

   const double sl_dist = MathMax(strategy_sl_atr_mult * atr_1, 10.0 * pip_size);
   const double tp_dist = MathMax(strategy_tp_atr_mult * atr_1, 10.0 * pip_size);

   // Long: Close[1] > HMA[1] AND ZL_MACD[1] > ZL_Signal[1] AND STC[1] >= 75.0 AND BetterVol == HIGH
   if(close_1 > hma_1 && zl_macd_1 > zl_sig_1 && stc_1 >= strategy_stc_long_thresh)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : close_1;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, exec_price - sl_dist);
      req.tp = QM_TM_NormalizePrice(_Symbol, exec_price + tp_dist);
      req.reason = "nnfx_hma_zlmacd_long";
      return true;
   }

   // Short: Close[1] < HMA[1] AND ZL_MACD[1] < ZL_Signal[1] AND STC[1] <= 25.0 AND BetterVol == HIGH
   if(close_1 < hma_1 && zl_macd_1 < zl_sig_1 && stc_1 <= strategy_stc_short_thresh)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : close_1;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, exec_price + sl_dist);
      req.tp = QM_TM_NormalizePrice(_Symbol, exec_price - tp_dist);
      req.reason = "nnfx_hma_zlmacd_short";
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

   double zl_macd_1 = 0.0, zl_sig_1 = 0.0;
   if(!Strategy_ZeroLagMACD(_Symbol, strategy_zl_macd_fast, strategy_zl_macd_slow, strategy_zl_macd_signal, 1, zl_macd_1, zl_sig_1))
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Long exit: ZeroLag MACD crosses below signal line
      if(pos_type == POSITION_TYPE_BUY)
      {
         if(zl_macd_1 < zl_sig_1)
            return true;
      }
      // Short exit: ZeroLag MACD crosses above signal line
      else if(pos_type == POSITION_TYPE_SELL)
      {
         if(zl_macd_1 > zl_sig_1)
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
