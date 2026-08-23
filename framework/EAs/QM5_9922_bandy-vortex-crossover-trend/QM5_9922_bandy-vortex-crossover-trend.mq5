#property strict
#property version   "5.0"
#property description "QM5_9922 Bandy Vortex Crossover Trend"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9922
// Strategy Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_9922_bandy-vortex-crossover-trend.md
// Source: Howard Bandy, Quantitative Technical Analysis 2015 (9ef19e06-5ca6-5b35-aa06-b8187aa0e016)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9922;
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
input int    strategy_vortex_period        = 14;
input double strategy_vortex_min_diff      = 0.05;
input int    strategy_adx_period           = 14;
input double strategy_adx_min              = 20.0;
input int    strategy_regime_sma_period    = 200;
input int    strategy_chandelier_lookback  = 22;
input int    strategy_atr_period           = 14;
input double strategy_chandelier_atr_mult  = 2.5;
input int    strategy_time_stop_days       = 60;
input int    strategy_warmup_bars          = 250;

// -----------------------------------------------------------------------------
// Strategy calculation helpers
// -----------------------------------------------------------------------------

bool CalculateVortex(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const int shift, double &vi_plus, double &vi_minus)
{
   vi_plus = 0.0;
   vi_minus = 0.0;
   if(period <= 1 || shift < 1)
      return false;

   double sum_vm_plus = 0.0;
   double sum_vm_minus = 0.0;
   double sum_tr = 0.0;

   for(int i = shift; i < shift + period; ++i)
   {
      const double high_now   = iHigh(symbol, tf, i);
      const double low_now    = iLow(symbol, tf, i);
      const double close_prev = iClose(symbol, tf, i + 1);
      const double high_prev  = iHigh(symbol, tf, i + 1);
      const double low_prev   = iLow(symbol, tf, i + 1);

      if(high_now <= 0.0 || low_now <= 0.0 || high_prev <= 0.0 || low_prev <= 0.0 || close_prev <= 0.0)
         return false;

      const double vm_plus  = MathAbs(high_now - low_prev);
      const double vm_minus = MathAbs(low_now - high_prev);

      const double tr1 = high_now - low_now;
      const double tr2 = MathAbs(high_now - close_prev);
      const double tr3 = MathAbs(low_now - close_prev);
      const double tr  = MathMax(tr1, MathMax(tr2, tr3));

      sum_vm_plus  += vm_plus;
      sum_vm_minus += vm_minus;
      sum_tr       += tr;
   }

   if(sum_tr <= 0.0)
      return false;

   vi_plus  = sum_vm_plus / sum_tr;
   vi_minus = sum_vm_minus / sum_tr;
   return true;
}

double CalculateChandelierStop(const string symbol, const ENUM_TIMEFRAMES tf, const QM_OrderType side, const int lookback, const int atr_period, const double atr_mult)
{
   const double atr = QM_ATR(symbol, tf, atr_period, 1);
   if(atr <= 0.0 || lookback < 1 || atr_mult <= 0.0)
      return 0.0;

   if(side == QM_BUY)
   {
      double hhv = -DBL_MAX;
      for(int i = 1; i <= lookback; ++i)
      {
         const double h = iHigh(symbol, tf, i);
         if(h <= 0.0) return 0.0;
         hhv = MathMax(hhv, h);
      }
      return hhv - (atr_mult * atr);
   }
   else if(side == QM_SELL)
   {
      double llv = DBL_MAX;
      for(int i = 1; i <= lookback; ++i)
      {
         const double l = iLow(symbol, tf, i);
         if(l <= 0.0) return 0.0;
         llv = MathMin(llv, l);
      }
      return llv + (atr_mult * atr);
   }

   return 0.0;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(iBars(_Symbol, PERIOD_D1) < strategy_warmup_bars)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
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

   if(iBars(_Symbol, PERIOD_D1) < strategy_warmup_bars)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) > 0)
      return false;

   double vi_plus_1 = 0.0, vi_minus_1 = 0.0;
   double vi_plus_2 = 0.0, vi_minus_2 = 0.0;
   if(!CalculateVortex(_Symbol, PERIOD_D1, strategy_vortex_period, 1, vi_plus_1, vi_minus_1))
      return false;
   if(!CalculateVortex(_Symbol, PERIOD_D1, strategy_vortex_period, 2, vi_plus_2, vi_minus_2))
      return false;

   const double adx14  = QM_ADX(_Symbol, PERIOD_D1, strategy_adx_period, 1);
   const double regime = QM_SMA(_Symbol, PERIOD_D1, strategy_regime_sma_period, 1, PRICE_CLOSE);
   const double close1 = iClose(_Symbol, PERIOD_D1, 1);

   if(adx14 < strategy_adx_min || regime <= 0.0 || close1 <= 0.0)
      return false;

   const double vi_diff = MathAbs(vi_plus_1 - vi_minus_1);
   if(vi_diff < strategy_vortex_min_diff)
      return false;

   // Long: VI+ crosses above VI-, adx >= 20, close > regime
   if(vi_plus_1 > vi_minus_1 && vi_plus_2 <= vi_minus_2 && close1 > regime)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;

      const double sl = CalculateChandelierStop(_Symbol, PERIOD_D1, QM_BUY, strategy_chandelier_lookback, strategy_atr_period, strategy_chandelier_atr_mult);
      if(sl <= 0.0 || sl >= ask)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "BANDY_VORTEX_CROSSOVER_BUY";
      return true;
   }

   // Short: VI- crosses above VI+, adx >= 20, close < regime
   if(vi_minus_1 > vi_plus_1 && vi_minus_2 <= vi_plus_2 && close1 < regime)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;

      const double sl = CalculateChandelierStop(_Symbol, PERIOD_D1, QM_SELL, strategy_chandelier_lookback, strategy_atr_period, strategy_chandelier_atr_mult);
      if(sl <= 0.0 || sl <= bid)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = 0.0;
      req.reason = "BANDY_VORTEX_CROSSOVER_SELL";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   double vi_plus_1 = 0.0, vi_minus_1 = 0.0;
   double vi_plus_2 = 0.0, vi_minus_2 = 0.0;
   const bool vortex_ok = CalculateVortex(_Symbol, PERIOD_D1, strategy_vortex_period, 1, vi_plus_1, vi_minus_1) &&
                          CalculateVortex(_Symbol, PERIOD_D1, strategy_vortex_period, 2, vi_plus_2, vi_minus_2);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = iBarShift(_Symbol, PERIOD_D1, open_time, false);

      if(bars_held >= strategy_time_stop_days)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
         continue;
      }

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Exit on opposite Vortex cross
      if(vortex_ok)
      {
         if(pos_type == POSITION_TYPE_BUY && vi_minus_1 > vi_plus_1 && vi_minus_2 <= vi_plus_2)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
            continue;
         }
         else if(pos_type == POSITION_TYPE_SELL && vi_plus_1 > vi_minus_1 && vi_plus_2 <= vi_minus_2)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
            continue;
         }
      }

      // Ratchet Chandelier Trailing Stop
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(pos_type == POSITION_TYPE_BUY)
      {
         const double new_sl = CalculateChandelierStop(_Symbol, PERIOD_D1, QM_BUY, strategy_chandelier_lookback, strategy_atr_period, strategy_chandelier_atr_mult);
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(new_sl > 0.0 && new_sl > current_sl && (bid <= 0.0 || new_sl < bid))
         {
            QM_TM_SendSLTPModify(ticket, new_sl, PositionGetDouble(POSITION_TP), "CHANDELIER_TRAIL_BUY");
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double new_sl = CalculateChandelierStop(_Symbol, PERIOD_D1, QM_SELL, strategy_chandelier_lookback, strategy_atr_period, strategy_chandelier_atr_mult);
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(new_sl > 0.0 && (current_sl == 0.0 || new_sl < current_sl) && (ask <= 0.0 || new_sl > ask))
         {
            QM_TM_SendSLTPModify(ticket, new_sl, PositionGetDouble(POSITION_TP), "CHANDELIER_TRAIL_SELL");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
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

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
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

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
