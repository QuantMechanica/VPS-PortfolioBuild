#property strict
#property version   "5.0"
#property description "QM5_36008 NNFX Gold & Commodity Super-Trend Engine (KAMA + Vortex + WAE)"
// Strategy Card: QM5_36008 (nnfx-gold-kama-vortex-supertrend), G0 APPROVED.
// Source: VP (No Nonsense Forex), "No Nonsense Forex Metals and Commodities Adaptation Suite."

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_36008 — NNFX Gold/Commodity Super-Trend Engine
// -----------------------------------------------------------------------------
// Specialized NNFX stack for Commodities (XAUUSD, XTIUSD) on D1 timeframe:
//   - Baseline: Kaufman Adaptive Moving Average (KAMA 20, 2, 30)
//   - Confirmation 1 (C1 Trigger): Vortex Indicator (14) VI+ vs VI-
//   - Confirmation 2 (C2 Filter): True Strength Index (TSI 25, 13)
//   - Volume Filter: Waddah Attar Explosion (WAE)
//
// Long Entry:  Close[1] > KAMA[1] AND VI+[1] > VI-[1] AND TSI[1] > 0 AND WAE_Long
// Short Entry: Close[1] < KAMA[1] AND VI-[1] > VI+[1] AND TSI[1] < 0 AND WAE_Short
// Exit Signal: Long exits on Close[1] < KAMA[1] or VI-[1] > VI+[1]
//              Short exits on Close[1] > KAMA[1] or VI+[1] > VI-[1]
// Initial Stop: Fixed ATR(14) stop at 1.0 * ATR(14)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 36008;
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
input int    strategy_kama_period         = 20;     // KAMA Efficiency Ratio period
input int    strategy_kama_fast           = 2;      // KAMA fastest EMA period
input int    strategy_kama_slow           = 30;     // KAMA slowest EMA period
input int    strategy_vortex_period       = 14;     // Vortex Indicator period
input int    strategy_tsi_r               = 25;     // TSI first smoothing period
input int    strategy_tsi_s               = 13;     // TSI second smoothing period
input int    strategy_wae_fast            = 12;     // WAE MACD fast EMA period
input int    strategy_wae_slow            = 26;     // WAE MACD slow EMA period
input int    strategy_wae_signal          = 9;      // WAE MACD signal SMA period
input int    strategy_wae_bb_period       = 20;     // WAE Bollinger Bands period
input double strategy_wae_bb_deviation    = 2.0;    // WAE Bollinger Bands deviation
input int    strategy_wae_sensitivity     = 150;    // WAE sensitivity multiplier
input int    strategy_wae_deadzone_pts    = 150;    // WAE deadzone in points
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 1.00;   // Stop loss ATR multiplier
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input int    strategy_warmup_bars         = 150;    // Warmup lookback bars for indicator vectors
input int    strategy_max_spread_points   = 300;    // Absolute spread cap in points

// -----------------------------------------------------------------------------
// Indicator Calculation Helpers
// -----------------------------------------------------------------------------

double Strategy_CalculateKAMA(const string sym, const int period, const int fast_ema, const int slow_ema, const int shift)
{
   if(period <= 0 || shift < 1) return 0.0;
   const int start = shift + strategy_warmup_bars;
   double closes[];
   ArrayResize(closes, start + period + 2);
   ArraySetAsSeries(closes, true);
   if(CopyClose(sym, PERIOD_D1, 1, start + period + 2, closes) < start + period + 2) // perf-allowed: closed-bar KAMA vector
      return 0.0;

   const double fast_sc = 2.0 / (double)(fast_ema + 1);
   const double slow_sc = 2.0 / (double)(slow_ema + 1);

   double current_kama = closes[start];
   for(int s = start; s >= shift; --s)
   {
      double change = MathAbs(closes[s] - closes[s + period]);
      double volatility = 0.0;
      for(int k = 0; k < period; ++k)
         volatility += MathAbs(closes[s + k] - closes[s + k + 1]);

      double er = (volatility > 0.0) ? (change / volatility) : 0.0;
      double sc = (er * (fast_sc - slow_sc) + slow_sc);
      sc = sc * sc;
      current_kama = current_kama + sc * (closes[s] - current_kama);
   }
   return current_kama;
}

bool Strategy_Vortex(const string sym, const int period, const int shift, double &vi_plus, double &vi_minus)
{
   vi_plus = 0.0;
   vi_minus = 0.0;
   if(period <= 0 || shift < 1)
      return false;
   double sum_vmp = 0.0;
   double sum_vmm = 0.0;
   double sum_tr  = 0.0;
   for(int k = 0; k < period; ++k)
   {
      const int s = shift + k;
      const double hi   = iHigh(sym, PERIOD_D1, s);      // perf-allowed: closed-bar Vortex range
      const double lo   = iLow(sym, PERIOD_D1, s);       // perf-allowed: closed-bar Vortex range
      const double hi_p = iHigh(sym, PERIOD_D1, s + 1);  // perf-allowed: closed-bar Vortex prior range
      const double lo_p = iLow(sym, PERIOD_D1, s + 1);   // perf-allowed: closed-bar Vortex prior range
      const double cl_p = iClose(sym, PERIOD_D1, s + 1); // perf-allowed: closed-bar Vortex true range
      if(hi <= 0.0 || lo <= 0.0 || hi_p <= 0.0 || lo_p <= 0.0 || cl_p <= 0.0)
         return false;

      const double vmp = MathAbs(hi - lo_p);
      const double vmm = MathAbs(lo - hi_p);
      const double tr  = MathMax(hi - lo, MathMax(MathAbs(hi - cl_p), MathAbs(lo - cl_p)));

      sum_vmp += vmp;
      sum_vmm += vmm;
      sum_tr  += tr;
   }
   if(sum_tr <= 0.0)
      return false;
   vi_plus  = sum_vmp / sum_tr;
   vi_minus = sum_vmm / sum_tr;
   return true;
}

double Strategy_TSI(const string sym, const int r, const int s, const int shift)
{
   if(r <= 0 || s <= 0 || shift < 1) return 0.0;
   const int total_bars = shift + strategy_warmup_bars + r + s;
   double closes[];
   ArrayResize(closes, total_bars + 2);
   ArraySetAsSeries(closes, true);
   if(CopyClose(sym, PERIOD_D1, 1, total_bars + 2, closes) < total_bars + 2) // perf-allowed: closed-bar TSI vector
      return 0.0;

   const double alpha_r = 2.0 / (double)(r + 1);
   const double alpha_s = 2.0 / (double)(s + 1);

   int start = total_bars - 1;
   double e1_m = closes[start] - closes[start + 1];
   double e1_a = MathAbs(closes[start] - closes[start + 1]);
   double e2_m = e1_m;
   double e2_a = e1_a;

   for(int i = start - 1; i >= shift; --i)
   {
      double dp = closes[i] - closes[i + 1];
      double abs_dp = MathAbs(dp);

      e1_m = alpha_r * dp + (1.0 - alpha_r) * e1_m;
      e1_a = alpha_r * abs_dp + (1.0 - alpha_r) * e1_a;

      e2_m = alpha_s * e1_m + (1.0 - alpha_s) * e2_m;
      e2_a = alpha_s * e1_a + (1.0 - alpha_s) * e2_a;
   }

   if(e2_a <= 1e-12)
      return 0.0;

   return (100.0 * (e2_m / e2_a));
}

int Strategy_WAESignal()
{
   const double macd_now  = QM_MACD_Main(_Symbol, PERIOD_D1, strategy_wae_fast, strategy_wae_slow, strategy_wae_signal, 1, PRICE_CLOSE);
   const double macd_prev = QM_MACD_Main(_Symbol, PERIOD_D1, strategy_wae_fast, strategy_wae_slow, strategy_wae_signal, 2, PRICE_CLOSE);
   const double bb_upper  = QM_BB_Upper(_Symbol, PERIOD_D1, strategy_wae_bb_period, strategy_wae_bb_deviation, 1, PRICE_CLOSE);
   const double bb_lower  = QM_BB_Lower(_Symbol, PERIOD_D1, strategy_wae_bb_period, strategy_wae_bb_deviation, 1, PRICE_CLOSE);
   const double point     = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(bb_upper <= 0.0 || bb_lower <= 0.0 || point <= 0.0)
      return 0;

   const double momentum = (macd_now - macd_prev) * (double)strategy_wae_sensitivity;
   const double explosion = MathAbs(bb_upper - bb_lower);
   const double deadzone = (double)strategy_wae_deadzone_pts * point;
   const double threshold = MathMax(explosion, deadzone);

   if(momentum > threshold)
      return 1;
   if(-momentum > threshold)
      return -1;
   return 0;
}

bool IsRolloverBlackout()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   int minute_of_day = dt.hour * 60 + dt.min;
   if(minute_of_day >= 1435 || minute_of_day <= 5)
      return true;
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(IsRolloverBlackout())
      return true;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
   {
      if(atr_1 > 0.0 && (ask - bid) > (strategy_spread_atr_mult * atr_1))
         return true;
      if(point > 0.0 && strategy_max_spread_points > 0 && (ask - bid) > (strategy_max_spread_points * point))
         return true;
   }
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: closed D1 bar close reference
   if(close1 <= 0.0)
      return false;

   const double kama1 = Strategy_CalculateKAMA(_Symbol, strategy_kama_period, strategy_kama_fast, strategy_kama_slow, 1);
   if(kama1 <= 0.0)
      return false;

   double vi_plus = 0.0, vi_minus = 0.0;
   if(!Strategy_Vortex(_Symbol, strategy_vortex_period, 1, vi_plus, vi_minus))
      return false;

   const double tsi = Strategy_TSI(_Symbol, strategy_tsi_r, strategy_tsi_s, 1);
   const int wae = Strategy_WAESignal();

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const bool go_long  = (close1 > kama1) && (vi_plus > vi_minus) && (tsi > 0.0) && (wae == 1);
   const bool go_short = (close1 < kama1) && (vi_minus > vi_plus) && (tsi < 0.0) && (wae == -1);

   if(go_long)
   {
      req.type   = QM_BUY;
      req.reason = "QM5_36008_NNFX_BUY";
      req.sl     = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_sl_atr_mult);
   }
   else if(go_short)
   {
      req.type   = QM_SELL;
      req.reason = "QM5_36008_NNFX_SELL";
      req.sl     = QM_StopATR(_Symbol, QM_SELL, bid, strategy_atr_period, strategy_sl_atr_mult);
   }
   else
   {
      return false;
   }

   if(req.sl <= 0.0)
      return false;

   return true;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   int open_dir = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      open_dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      break;
   }

   if(open_dir == 0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: closed D1 bar close reference
   const double kama1 = Strategy_CalculateKAMA(_Symbol, strategy_kama_period, strategy_kama_fast, strategy_kama_slow, 1);
   if(close1 <= 0.0 || kama1 <= 0.0)
      return false;

   double vi_plus = 0.0, vi_minus = 0.0;
   if(!Strategy_Vortex(_Symbol, strategy_vortex_period, 1, vi_plus, vi_minus))
      return false;

   if(open_dir > 0)
   {
      // Long exit on KAMA breakdown or Vortex cross
      if(close1 < kama1 || vi_minus > vi_plus)
         return true;
   }
   else if(open_dir < 0)
   {
      // Short exit on KAMA breakout or Vortex cross
      if(close1 > kama1 || vi_plus > vi_minus)
         return true;
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_36008_nnfx_gold_kama_vortex_supertrend\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
}

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();

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
