#property strict
#property version   "5.0"
#property description "QM5_12947 MQL5 Smoothed Heiken Ashi EMA Trend Filter"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_12947 - MQL5 Smoothed Heiken Ashi EMA Trend Filter
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12947;
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
input int    strategy_pre_smooth_period       = 6;
input int    strategy_post_smooth_period      = 2;
input int    strategy_ha_seed_bars            = 120;
input int    strategy_ema_period              = 50;
input int    strategy_ema_slope_lookback      = 5;
input double strategy_ema_min_slope_atr_ratio = 0.1;
input int    strategy_atr_period              = 14;
input double strategy_atr_sl_mult             = 2.0;
input double strategy_tp_r_mult               = 2.0;
input int    strategy_max_spread_points       = 0;

// -----------------------------------------------------------------------------
// Smoothed Heiken-Ashi computation helper
// -----------------------------------------------------------------------------

bool ComputeSmoothedHA(const int shift,
                       double &sm_ha_open,
                       double &sm_ha_close,
                       double &sm_ha_high,
                       double &sm_ha_low,
                       int    &color_here,
                       int    &color_prev)
{
   const int pre  = (strategy_pre_smooth_period  < 1 ? 1 : strategy_pre_smooth_period);
   const int post = (strategy_post_smooth_period < 1 ? 1 : strategy_post_smooth_period);
   const int seed = (strategy_ha_seed_bars < 20 ? 20 : strategy_ha_seed_bars);

   const int oldest = shift + seed;
   if(Bars(_Symbol, (ENUM_TIMEFRAMES)_Period) <= oldest + pre + 2)
      return false;

   const int keep = post + 3;
   double ha_open_win[];
   double ha_close_win[];
   ArrayResize(ha_open_win, keep);
   ArrayResize(ha_close_win, keep);
   ArrayInitialize(ha_open_win, 0.0);
   ArrayInitialize(ha_close_win, 0.0);

   double sO = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, pre, oldest, PRICE_OPEN);
   double sH = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, pre, oldest, PRICE_HIGH);
   double sL = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, pre, oldest, PRICE_LOW);
   double sC = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, pre, oldest, PRICE_CLOSE);
   if(sO <= 0.0 || sC <= 0.0)
      return false;

   double prev_ha_open  = (sO + sC) / 2.0;
   double prev_ha_close = (sO + sH + sL + sC) / 4.0;

   double smo_at[3];
   double smc_at[3];
   double smh_at[3];
   double sml_at[3];
   bool   have_at[3];
   for(int k = 0; k < 3; ++k)
   {
      smo_at[k] = 0.0; smc_at[k] = 0.0; smh_at[k] = 0.0; sml_at[k] = 0.0;
      have_at[k] = false;
   }

   int win_count = 0;
   ha_open_win[win_count % keep]  = prev_ha_open;
   ha_close_win[win_count % keep] = prev_ha_close;
   win_count++;

   for(int s = oldest - 1; s >= shift; --s)
   {
      sO = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, pre, s, PRICE_OPEN);
      sH = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, pre, s, PRICE_HIGH);
      sL = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, pre, s, PRICE_LOW);
      sC = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, pre, s, PRICE_CLOSE);
      if(sO <= 0.0 || sC <= 0.0)
         return false;

      const double cur_ha_close = (sO + sH + sL + sC) / 4.0;
      const double cur_ha_open  = (prev_ha_open + prev_ha_close) / 2.0;
      const double cur_ha_high  = MathMax(sH, MathMax(cur_ha_open, cur_ha_close));
      const double cur_ha_low   = MathMin(sL, MathMin(cur_ha_open, cur_ha_close));

      prev_ha_open  = cur_ha_open;
      prev_ha_close = cur_ha_close;

      ha_open_win[win_count % keep]  = cur_ha_open;
      ha_close_win[win_count % keep] = cur_ha_close;
      win_count++;

      if(win_count >= post)
      {
         double sum_o = 0.0, sum_c = 0.0;
         for(int j = 0; j < post; ++j)
         {
            const int idx = (win_count - 1 - j) % keep;
            if(idx < 0)
               return false;
            if(idx >= ArraySize(ha_open_win))
               return false;
            if(idx >= ArraySize(ha_close_win))
               return false;
            sum_o += ha_open_win[idx];
            sum_c += ha_close_win[idx];
         }
         const double po = sum_o / post;
         const double pc = sum_c / post;

         const int rel = s - shift;
         if(rel >= 0 && rel <= 2)
         {
            smo_at[rel] = po;
            smc_at[rel] = pc;
            smh_at[rel] = cur_ha_high;
            sml_at[rel] = cur_ha_low;
            have_at[rel] = true;
         }
      }
   }

   if(!have_at[0] || !have_at[1] || !have_at[2])
      return false;

   sm_ha_open  = smo_at[0];
   sm_ha_close = smc_at[0];
   sm_ha_high  = smh_at[0];
   sm_ha_low   = sml_at[0];

   color_here = (smc_at[0] > smo_at[0]) ? +1 : -1;
   color_prev = (smc_at[1] > smo_at[1]) ? +1 : -1;
   return true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(strategy_max_spread_points <= 0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   if((ask - bid) / point > strategy_max_spread_points)
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

   double ha_o = 0.0, ha_c = 0.0, ha_h = 0.0, ha_l = 0.0;
   int color_here = 0, color_prev = 0;
   if(!ComputeSmoothedHA(1, ha_o, ha_c, ha_h, ha_l, color_here, color_prev))
      return false;

   const double close1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const double high1  = iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const double low1   = iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const double ema1   = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1, PRICE_CLOSE);
   const double atr14  = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);

   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || ema1 <= 0.0 || atr14 <= 0.0)
      return false;

   const int slope_lookback = (strategy_ema_slope_lookback < 1) ? 1 : strategy_ema_slope_lookback;
   const double ema_past = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1 + slope_lookback, PRICE_CLOSE);
   if(ema_past <= 0.0)
      return false;

   const double min_slope_delta = (strategy_ema_min_slope_atr_ratio > 0.0) ? (strategy_ema_min_slope_atr_ratio * atr14) : 0.0;
   const bool ema_slope_pos = (ema1 - ema_past >= min_slope_delta);
   const bool ema_slope_neg = (ema_past - ema1 >= min_slope_delta);

   const bool buy_signal  = (color_here == 1 && color_prev != 1 && close1 > ema1 && ema_slope_pos);
   const bool sell_signal = (color_here == -1 && color_prev != -1 && close1 < ema1 && ema_slope_neg);

   if(!buy_signal && !sell_signal)
      return false;

   const int magic = QM_FrameworkMagic();
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
      if(ptype == POSITION_TYPE_BUY && sell_signal)
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
      else if(ptype == POSITION_TYPE_SELL && buy_signal)
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
      return false;
   }

   if(buy_signal)
   {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      const double atr_stop = entry - (strategy_atr_sl_mult * atr14);
      const double structural_stop = low1;
      const double raw_sl = MathMin(atr_stop, structural_stop);
      const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
      if(sl <= 0.0 || sl >= entry)
         return false;

      const double sl_distance = entry - sl;
      const double tp = QM_StopRulesTakeFromDistance(_Symbol, QM_BUY, entry, strategy_tp_r_mult * sl_distance);

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "ha_ema_trend_long";
      return true;
   }

   if(sell_signal)
   {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      const double atr_stop = entry + (strategy_atr_sl_mult * atr14);
      const double structural_stop = high1;
      const double raw_sl = MathMax(atr_stop, structural_stop);
      const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
      if(sl <= 0.0 || sl <= entry)
         return false;

      const double sl_distance = sl - entry;
      const double tp = QM_StopRulesTakeFromDistance(_Symbol, QM_SELL, entry, strategy_tp_r_mult * sl_distance);

      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "ha_ema_trend_short";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   // Card specifies fixed hard TP at 2R and opposite/flip exits.
}

bool Strategy_ExitSignal()
{
   double ha_o = 0.0, ha_c = 0.0, ha_h = 0.0, ha_l = 0.0;
   int color_here = 0, color_prev = 0;
   if(!ComputeSmoothedHA(1, ha_o, ha_c, ha_h, ha_l, color_here, color_prev))
      return false;

   const double close1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1);
   const double ema1   = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1, PRICE_CLOSE);
   if(close1 <= 0.0 || ema1 <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
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
      if(ptype == POSITION_TYPE_BUY)
      {
         if(color_here == -1 || close1 < ema1)
            return true;
      }
      else if(ptype == POSITION_TYPE_SELL)
      {
         if(color_here == 1 || close1 > ema1)
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
   QM_FrameworkTrackOpenPositionMae();
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
         ulong ticket = PositionGetTicket(i);
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

void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
