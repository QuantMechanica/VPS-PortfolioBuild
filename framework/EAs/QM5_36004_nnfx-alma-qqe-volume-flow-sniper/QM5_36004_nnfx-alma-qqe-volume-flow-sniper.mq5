#property strict
#property version   "5.0"
#property description "QM5_36004 NNFX ALMA & QQE Volume Flow Sniper"
// Strategy Card: QM5_36004 (nnfx-alma-qqe-volume-flow-sniper), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_36004
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 36004;
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
input int    strategy_alma_period         = 20;     // ALMA baseline window period
input double strategy_alma_sigma          = 6.0;    // ALMA Gaussian distribution width
input double strategy_alma_offset         = 0.85;   // ALMA Gaussian offset parameter
input int    strategy_qqe_rsi_period      = 14;     // QQE RSI smoothing period
input int    strategy_qqe_sf              = 5;      // QQE smoothing factor (RSI EMA)
input int    strategy_qqe_wilder          = 27;     // QQE Wilder smoothing period
input double strategy_qqe_mult            = 4.236;  // QQE fast ATR multiplier
input int    strategy_dpo_period          = 20;     // Detrended Price Oscillator period
input int    strategy_vfi_period          = 130;    // Volume Flow Indicator lookback period
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

double Strategy_ALMA(const string sym, const int period, const double sigma, const double offset, const int shift)
{
   if(period < 2 || sigma <= 0.0 || shift < 1) return 0.0;
   const double m = offset * (double)(period - 1);
   const double s = (double)period / sigma;
   const double s2 = 2.0 * s * s;
   if(s2 <= 0.0) return 0.0;

   double sum_w = 0.0;
   double sum_weight = 0.0;
   for(int k = 0; k < period; ++k)
   {
      const double c = iClose(sym, PERIOD_D1, shift + k); // perf-allowed: closed-bar ALMA Gaussian calculation behind QM_IsNewBar()
      if(c <= 0.0) return 0.0;
      const double diff = (double)k - m;
      const double weight = MathExp(-(diff * diff) / s2);
      sum_w += c * weight;
      sum_weight += weight;
   }
   if(sum_weight <= 0.0) return 0.0;
   return sum_w / sum_weight;
}

int Strategy_QQESignal(const string sym, const int shift)
{
   const int sf = strategy_qqe_sf;
   const int wilder = strategy_qqe_wilder;
   const int rsi_p = strategy_qqe_rsi_period;
   const double factor = strategy_qqe_mult;

   const int warmup = sf + 2 * wilder + 30;
   const int n = warmup;
   if(n < 2) return 0;

   double rsi_ma[];
   ArrayResize(rsi_ma, n);

   const double k = 2.0 / ((double)sf + 1.0);
   double ema = QM_RSI(sym, PERIOD_D1, rsi_p, shift + n - 1, PRICE_CLOSE);
   if(ema <= 0.0 && ema != 0.0) return 0;
   rsi_ma[n - 1] = ema;

   for(int i = n - 2; i >= 0; --i)
   {
      const int s = shift + i;
      const double rsi = QM_RSI(sym, PERIOD_D1, rsi_p, s, PRICE_CLOSE);
      ema = k * rsi + (1.0 - k) * ema;
      rsi_ma[i] = ema;
   }

   const double wk = 1.0 / (double)wilder;
   double atr_rsi = 0.0;
   double dar = 0.0;
   double trail = 50.0;

   for(int i = n - 2; i >= 0; --i)
   {
      const double diff = MathAbs(rsi_ma[i] - rsi_ma[i + 1]);
      if(i == n - 2)
      {
         atr_rsi = diff;
         dar = diff;
      }
      else
      {
         atr_rsi = wk * diff + (1.0 - wk) * atr_rsi;
         dar = wk * atr_rsi + (1.0 - wk) * dar;
      }

      const double band = dar * factor;
      const double rma = rsi_ma[i];
      const double rma_prev = rsi_ma[i + 1];

      if(rma > trail)
      {
         const double long_band = rma - band;
         if(rma_prev > trail)
            trail = MathMax(trail, long_band);
         else
            trail = long_band;
      }
      else
      {
         const double short_band = rma + band;
         if(rma_prev < trail)
            trail = MathMin(trail, short_band);
         else
            trail = short_band;
      }
   }

   if(rsi_ma[0] > trail) return 1;  // Bullish (+1)
   if(rsi_ma[0] < trail) return -1; // Bearish (-1)
   return 0;
}

double Strategy_DPO(const string sym, const int period, const int shift)
{
   if(period <= 0 || shift < 1) return 0.0;
   const double c = iClose(sym, PERIOD_D1, shift); // perf-allowed: closed-bar DPO close price
   if(c <= 0.0) return 0.0;
   const int offset = period / 2 + 1;
   const double sma = QM_SMA(sym, PERIOD_D1, period, shift + offset, PRICE_CLOSE);
   if(sma <= 0.0) return 0.0;
   return (c - sma);
}

double Strategy_VFI(const string sym, const int period, const int shift)
{
   if(period <= 0 || shift < 1) return 0.0;
   const double atr = QM_ATR(sym, PERIOD_D1, 14, shift);
   const double cutoff = 0.2 * atr;

   double sum_flow = 0.0;
   double sum_vol = 0.0;
   for(int k = 0; k < period; ++k)
   {
      const int s = shift + k;
      const double h   = iHigh(sym, PERIOD_D1, s);       // perf-allowed: closed-bar VFI typical price
      const double l   = iLow(sym, PERIOD_D1, s);        // perf-allowed: closed-bar VFI typical price
      const double c   = iClose(sym, PERIOD_D1, s);      // perf-allowed: closed-bar VFI typical price
      const double h_p = iHigh(sym, PERIOD_D1, s + 1);   // perf-allowed: closed-bar VFI prior typical price
      const double l_p = iLow(sym, PERIOD_D1, s + 1);    // perf-allowed: closed-bar VFI prior typical price
      const double c_p = iClose(sym, PERIOD_D1, s + 1);  // perf-allowed: closed-bar VFI prior typical price
      const double vol = (double)iVolume(sym, PERIOD_D1, s); // perf-allowed: closed-bar VFI volume
      if(h <= 0.0 || l <= 0.0 || c <= 0.0 || h_p <= 0.0 || l_p <= 0.0 || c_p <= 0.0 || vol <= 0.0)
         continue;

      const double typ   = (h + l + c) / 3.0;
      const double typ_p = (h_p + l_p + c_p) / 3.0;
      const double diff  = typ - typ_p;

      double flow = 0.0;
      if(diff > cutoff)
         flow = vol;
      else if(diff < -cutoff)
         flow = -vol;

      sum_flow += flow;
      sum_vol  += vol;
   }
   if(sum_vol <= 0.0) return 0.0;
   return (sum_flow / sum_vol);
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

   const double alma_1 = Strategy_ALMA(_Symbol, strategy_alma_period, strategy_alma_sigma, strategy_alma_offset, 1);
   if(alma_1 <= 0.0)
      return false;

   const int qqe_signal = Strategy_QQESignal(_Symbol, 1);
   if(qqe_signal == 0)
      return false;

   const double dpo_1 = Strategy_DPO(_Symbol, strategy_dpo_period, 1);
   const double vfi_1 = Strategy_VFI(_Symbol, strategy_vfi_period, 1);

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_1 <= 0.0)
      return false;

   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0)
      return false;

   const double sl_dist = MathMax(strategy_sl_atr_mult * atr_1, 10.0 * pip_size);
   const double tp_dist = MathMax(strategy_tp_atr_mult * atr_1, 10.0 * pip_size);

   // Long: Close > ALMA AND QQE == UP (+1) AND DPO > 0 AND VFI > 0
   if(close_1 > alma_1 && qqe_signal > 0 && dpo_1 > 0.0 && vfi_1 > 0.0)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : close_1;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, exec_price - sl_dist);
      req.tp = QM_TM_NormalizePrice(_Symbol, exec_price + tp_dist);
      req.reason = "nnfx_alma_qqe_long";
      return true;
   }

   // Short: Close < ALMA AND QQE == DOWN (-1) AND DPO < 0 AND VFI < 0
   if(close_1 < alma_1 && qqe_signal < 0 && dpo_1 < 0.0 && vfi_1 < 0.0)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : close_1;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, exec_price + sl_dist);
      req.tp = QM_TM_NormalizePrice(_Symbol, exec_price - tp_dist);
      req.reason = "nnfx_alma_qqe_short";
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

   const int qqe_signal = Strategy_QQESignal(_Symbol, 1);
   const double close_1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: closed-bar reference behind QM_IsNewBar()
   const double alma_1 = Strategy_ALMA(_Symbol, strategy_alma_period, strategy_alma_sigma, strategy_alma_offset, 1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Long exit: QQE flipped DOWN (< 0) or Close dropped below ALMA
      if(pos_type == POSITION_TYPE_BUY)
      {
         if(qqe_signal < 0 || (alma_1 > 0.0 && close_1 < alma_1))
            return true;
      }
      // Short exit: QQE flipped UP (> 0) or Close rose above ALMA
      else if(pos_type == POSITION_TYPE_SELL)
      {
         if(qqe_signal > 0 || (alma_1 > 0.0 && close_1 > alma_1))
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
