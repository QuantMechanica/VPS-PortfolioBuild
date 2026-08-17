#property strict
#property version   "5.0"
#property description "QM5_21515 Acceleration Bands Breakout on XTIUSD D1"
// Strategy Card: QM5_21515 (qs-acceleration-bands-xti), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_21515
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 21515;
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
input double strategy_accel_factor        = 0.001;
input int    strategy_band_sma_period     = 20;
input int    strategy_slope_lookback      = 5;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 2.5;
input int    strategy_max_hold_bars       = 60;
input int    strategy_warmup_buffer       = 20;
input int    strategy_max_spread_points   = 600;

// -----------------------------------------------------------------------------
// File-scope cached strategy state (advanced on new D1 bar)
// -----------------------------------------------------------------------------
double g_upper_1          = 0.0;
double g_upper_2          = 0.0;
double g_upper_slope_ref  = 0.0;

double g_lower_1          = 0.0;
double g_lower_2          = 0.0;
double g_lower_slope_ref  = 0.0;

double g_mid_1            = 0.0;
double g_close_1          = 0.0;
double g_close_2          = 0.0;
double g_atr_1            = 0.0;
bool   g_state_valid      = false;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
double ComputeSMA(const double &arr[], const int start_shift, const int period)
{
   if(period <= 0) return 0.0;
   double sum = 0.0;
   for(int k = 0; k < period; ++k)
      sum += arr[start_shift + k];
   return (sum / (double)period);
}

void AdvanceState_OnNewBar()
{
   g_state_valid = false;
   if(strategy_band_sma_period <= 0 || strategy_slope_lookback <= 0 || strategy_atr_period <= 0)
      return;

   const int total_bars = iBars(_Symbol, PERIOD_D1);
   const int needed_bars = strategy_band_sma_period + strategy_slope_lookback + strategy_warmup_buffer + 5;
   if(total_bars < needed_bars)
      return;

   const int max_raw_shift = 2 + strategy_slope_lookback + strategy_band_sma_period;
   double raw_upper[];
   double raw_lower[];
   if(ArrayResize(raw_upper, max_raw_shift + 1) < 0 || ArrayResize(raw_lower, max_raw_shift + 1) < 0)
      return;

   for(int i = 1; i <= max_raw_shift; ++i)
   {
      const double h = iHigh(_Symbol, PERIOD_D1, i); // perf-allowed: closed-D1 raw band construction behind QM_IsNewBar()
      const double l = iLow(_Symbol, PERIOD_D1, i);  // perf-allowed: closed-D1 raw band construction behind QM_IsNewBar()
      if(h <= 0.0 || l <= 0.0)
         return;
      const double mid_hl = h + l;
      if(mid_hl <= 0.0)
         return;
      const double mult = 4.0 * 1000.0 * strategy_accel_factor * ((h - l) / mid_hl);
      raw_upper[i] = h * (1.0 + mult);
      raw_lower[i] = l * (1.0 - mult);
   }

   g_upper_1 = ComputeSMA(raw_upper, 1, strategy_band_sma_period);
   g_upper_2 = ComputeSMA(raw_upper, 2, strategy_band_sma_period);
   g_upper_slope_ref = ComputeSMA(raw_upper, 1 + strategy_slope_lookback, strategy_band_sma_period);

   g_lower_1 = ComputeSMA(raw_lower, 1, strategy_band_sma_period);
   g_lower_2 = ComputeSMA(raw_lower, 2, strategy_band_sma_period);
   g_lower_slope_ref = ComputeSMA(raw_lower, 1 + strategy_slope_lookback, strategy_band_sma_period);

   double sum_close = 0.0;
   for(int k = 0; k < strategy_band_sma_period; ++k)
   {
      const double c = iClose(_Symbol, PERIOD_D1, 1 + k); // perf-allowed: closed-D1 SMA midline behind QM_IsNewBar()
      if(c <= 0.0) return;
      sum_close += c;
   }
   g_mid_1 = sum_close / (double)strategy_band_sma_period;

   g_close_1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: closed-D1 trigger price behind QM_IsNewBar()
   g_close_2 = iClose(_Symbol, PERIOD_D1, 2); // perf-allowed: closed-D1 trigger price behind QM_IsNewBar()
   if(g_close_1 <= 0.0 || g_close_2 <= 0.0)
      return;

   g_atr_1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(g_atr_1 <= 0.0)
      return;

   g_state_valid = true;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(_Symbol != "XTIUSD.DWX" && _Symbol != "XTIUSD")
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid && point > 0.0)
   {
      const double spread_pts = (ask - bid) / point;
      if(spread_pts > (double)strategy_max_spread_points)
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

   if(!g_state_valid)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // Long: Close crosses above Upper and Upper is sloping up
   if(g_close_2 <= g_upper_2 && g_close_1 > g_upper_1 && g_upper_1 > g_upper_slope_ref)
   {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, ask, g_atr_1, strategy_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "QM5_21515_BUY_BREAKOUT";
      return true;
   }

   // Short: Close crosses below Lower and Lower is sloping down
   if(g_close_2 >= g_lower_2 && g_close_1 < g_lower_1 && g_lower_1 < g_lower_slope_ref)
   {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATRFromValue(_Symbol, QM_SELL, bid, g_atr_1, strategy_atr_sl_mult);
      req.tp = 0.0;
      req.reason = "QM5_21515_SELL_BREAKDOWN";
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || !g_state_valid)
      return;

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
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);

      // Max hold bars exit (D1 bars)
      if(strategy_max_hold_bars > 0 && open_time > 0)
      {
         const int bars_held = iBarShift(_Symbol, PERIOD_D1, open_time, false);
         if(bars_held >= strategy_max_hold_bars)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
            continue;
         }
      }

      // Signal-reversal exit: Close recrosses Mid
      if(ptype == POSITION_TYPE_BUY)
      {
         if(g_close_1 < g_mid_1)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
            continue;
         }
      }
      else if(ptype == POSITION_TYPE_SELL)
      {
         if(g_close_1 > g_mid_1)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
            continue;
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

   AdvanceState_OnNewBar();
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

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
   {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
   }

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

   if(!is_new_bar) return;

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
