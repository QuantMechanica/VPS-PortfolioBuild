#property strict
#property version   "5.0"
#property description "QM5_36007 NNFX VIDYA & TRIX Momentum System"
// Strategy Card: QM5_36007 (nnfx-vidya-trix-fisher-momentum), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_36007
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 36007;
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
input int    strategy_vidya_period        = 9;      // VIDYA base smoothing period
input int    strategy_cmo_period          = 12;     // Chande Momentum volatility period
input int    strategy_trix_period         = 14;     // TRIX triple EMA smoothing period
input int    strategy_trix_signal         = 9;      // TRIX signal line averaging period
input int    strategy_fisher_period       = 10;     // Fisher Transform lookback period
input int    strategy_mfi_period          = 14;     // Money Flow Index period
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

double Strategy_CMO(const string sym, const int period, const int shift)
{
   if(period <= 0 || shift < 1) return 0.0;
   double su = 0.0;
   double sd = 0.0;
   for(int i = 0; i < period; ++i)
   {
      const int s = shift + i;
      const double c_curr = iClose(sym, PERIOD_D1, s); // perf-allowed: closed-bar read behind QM_IsNewBar()
      const double c_prev = iClose(sym, PERIOD_D1, s + 1);
      if(c_curr <= 0.0 || c_prev <= 0.0) return 0.0;
      const double diff = c_curr - c_prev;
      if(diff > 0.0) su += diff;
      else if(diff < 0.0) sd -= diff;
   }
   const double denom = su + sd;
   if(denom <= 0.0) return 0.0;
   return (100.0 * (su - sd) / denom);
}

double Strategy_VIDYA(const string sym, const int vidya_p, const int cmo_p, const int shift)
{
   if(vidya_p <= 1 || cmo_p <= 0 || shift < 1) return 0.0;
   const int warmup = 50;
   const int seed_shift = shift + warmup;

   double sum_c = 0.0;
   for(int i = 0; i < vidya_p; ++i)
   {
      const double c = iClose(sym, PERIOD_D1, seed_shift + i); // perf-allowed: closed-bar read behind QM_IsNewBar()
      if(c <= 0.0) return 0.0;
      sum_c += c;
   }
   double vidya = sum_c / (double)vidya_p;
   const double k = 2.0 / ((double)vidya_p + 1.0);

   for(int s = seed_shift - 1; s >= shift; --s)
   {
      const double c = iClose(sym, PERIOD_D1, s);
      if(c <= 0.0) return 0.0;
      const double cmo = MathAbs(Strategy_CMO(sym, cmo_p, s)) / 100.0;
      vidya = (k * cmo * c) + (1.0 - k * cmo) * vidya;
   }
   return vidya;
}

bool Strategy_TRIX(const string sym, const int trix_p, const int sig_p, const int shift, double &trix_val, double &sig_val)
{
   trix_val = 0.0;
   sig_val = 0.0;
   if(trix_p <= 1 || sig_p <= 0 || shift < 1) return false;

   const int need = trix_p * 3 + sig_p + 20;
   const double alpha = 2.0 / ((double)trix_p + 1.0);
   const int start_shift = shift + need;

   const double c_start = iClose(sym, PERIOD_D1, start_shift);
   if(c_start <= 0.0) return false;

   double e1 = c_start, e2 = c_start, e3 = c_start;
   double trix_series[];
   ArrayResize(trix_series, sig_p + 2);

   double prev_e3 = 0.0;
   for(int s = start_shift; s >= shift; --s)
   {
      const double c = iClose(sym, PERIOD_D1, s);
      if(c <= 0.0) return false;
      e1 = alpha * c + (1.0 - alpha) * e1;
      e2 = alpha * e1 + (1.0 - alpha) * e2;
      e3 = alpha * e2 + (1.0 - alpha) * e3;

      const int offset = s - shift;
      if(offset < sig_p + 2)
      {
         if(prev_e3 > 0.0)
            trix_series[offset] = (e3 - prev_e3) / prev_e3 * 10000.0;
         else
            trix_series[offset] = 0.0;
      }
      prev_e3 = e3;
   }

   trix_val = trix_series[0];
   double sum_sig = 0.0;
   for(int k = 0; k < sig_p; ++k)
      sum_sig += trix_series[k];
   sig_val = sum_sig / (double)sig_p;
   return true;
}

double Strategy_Fisher(const string sym, const int fisher_p, const int shift)
{
   if(fisher_p < 2 || shift < 1) return 0.0;
   double highest = iHigh(sym, PERIOD_D1, shift); // perf-allowed: closed-bar read behind QM_IsNewBar()
   double lowest = iLow(sym, PERIOD_D1, shift);
   if(highest <= 0.0 || lowest <= 0.0) return 0.0;

   for(int i = 1; i < fisher_p; ++i)
   {
      const int s = shift + i;
      const double h = iHigh(sym, PERIOD_D1, s);
      const double l = iLow(sym, PERIOD_D1, s);
      if(h <= 0.0 || l <= 0.0) return 0.0;
      highest = MathMax(highest, h);
      lowest = MathMin(lowest, l);
   }

   const double median = (iHigh(sym, PERIOD_D1, shift) + iLow(sym, PERIOD_D1, shift)) / 2.0;
   const double range = highest - lowest;
   if(range <= 0.0 || median <= 0.0) return 0.0;

   double x = 2.0 * ((median - lowest) / range - 0.5);
   x = MathMax(-0.999, MathMin(0.999, x));
   return (0.5 * MathLog((1.0 + x) / (1.0 - x)));
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

   const double vidya_1 = Strategy_VIDYA(_Symbol, strategy_vidya_period, strategy_cmo_period, 1);
   if(vidya_1 <= 0.0)
      return false;

   double trix_1 = 0.0, trix_sig_1 = 0.0;
   if(!Strategy_TRIX(_Symbol, strategy_trix_period, strategy_trix_signal, 1, trix_1, trix_sig_1))
      return false;

   const double fisher_1 = Strategy_Fisher(_Symbol, strategy_fisher_period, 1);
   const double mfi_1 = QM_MFI(_Symbol, PERIOD_D1, strategy_mfi_period, 1);

   const double atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_1 <= 0.0)
      return false;

   const double pip_size = QM_StopRulesPipsToPriceDistance(_Symbol, 1.0);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pip_size <= 0.0 || point <= 0.0)
      return false;

   const double sl_dist = MathMax(strategy_sl_atr_mult * atr_1, 10.0 * pip_size);
   const double tp_dist = MathMax(strategy_tp_atr_mult * atr_1, 10.0 * pip_size);

   // Long: Close[1] > VIDYA[1] AND TRIX[1] > TRIX_Signal[1] AND Fisher[1] > 0.0 AND MFI(14)[1] >= 50.0
   if(close_1 > vidya_1 && trix_1 > trix_sig_1 && fisher_1 > 0.0 && mfi_1 >= 50.0)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double exec_price = (ask > 0.0) ? ask : close_1;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, exec_price - sl_dist);
      req.tp = QM_TM_NormalizePrice(_Symbol, exec_price + tp_dist);
      req.reason = "nnfx_vidya_trix_long";
      return true;
   }

   // Short: Close[1] < VIDYA[1] AND TRIX[1] < TRIX_Signal[1] AND Fisher[1] < 0.0 AND MFI(14)[1] <= 50.0
   if(close_1 < vidya_1 && trix_1 < trix_sig_1 && fisher_1 < 0.0 && mfi_1 <= 50.0)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double exec_price = (bid > 0.0) ? bid : close_1;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_TM_NormalizePrice(_Symbol, exec_price + sl_dist);
      req.tp = QM_TM_NormalizePrice(_Symbol, exec_price - tp_dist);
      req.reason = "nnfx_vidya_trix_short";
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

   double trix_1 = 0.0, trix_sig_1 = 0.0;
   if(!Strategy_TRIX(_Symbol, strategy_trix_period, strategy_trix_signal, 1, trix_1, trix_sig_1))
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Long exit: TRIX recross below Signal line
      if(pos_type == POSITION_TYPE_BUY)
      {
         if(trix_1 < trix_sig_1)
            return true;
      }
      // Short exit: TRIX recross above Signal line
      else if(pos_type == POSITION_TYPE_SELL)
      {
         if(trix_1 > trix_sig_1)
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
