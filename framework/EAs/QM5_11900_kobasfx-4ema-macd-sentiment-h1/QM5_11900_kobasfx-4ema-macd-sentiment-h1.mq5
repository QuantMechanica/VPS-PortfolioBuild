#property strict
#property version   "5.0"
#property description "QM5_11900 KobasFX 4-EMA Stack MACD Sentiment (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11900
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11900;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input int    strategy_ema_fast1         = 5;
input int    strategy_ema_fast2         = 10;
input int    strategy_ema_fast3         = 15;
input int    strategy_ema_slow          = 65;
input int    strategy_slope_bars        = 5;
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
input int    strategy_atr_period        = 14;
input double strategy_ema_sep_atr_mult  = 0.25;
input double strategy_tp_risk_mult      = 3.0;
input int    strategy_time_stop_bars    = 240;

// -----------------------------------------------------------------------------
// Helper Functions
// -----------------------------------------------------------------------------

bool IsMacdSignalInCloud(int shift, bool is_long)
{
   double signal = QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift);
   double hist_min = 999999.0;
   double hist_max = -999999.0;
   
   for(int i = 0; i < 5; i++)
   {
      double h = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, shift + i);
      if(h < hist_min) hist_min = h;
      if(h > hist_max) hist_max = h;
   }
   
   if (is_long)
   {
      // MACD signal inside histogram cloud below zero: wait, long rules say:
      // "MACD above zero (long): MACD_signal[t] > 0."
      // "MACD signal inside histogram cloud (long): the MACD signal line value at t is within the [min, max] envelope over the last 5 bars"
      if(signal > 0 && signal >= hist_min && signal <= hist_max) return true;
   }
   else
   {
      if(signal < 0 && signal >= hist_min && signal <= hist_max) return true;
   }
   return false;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(PositionsTotal() > 0) return false;

   const double close1 = iClose(_Symbol, PERIOD_H1, 1);
   const double atr1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   
   const double ema5 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast1, 1);
   const double ema10 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast2, 1);
   const double ema15 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast3, 1);
   const double ema65_current = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_slow, 1);
   const double ema65_past = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_slow, 1 + strategy_slope_bars);
   
   if(close1 <= 0.0 || atr1 <= 0.0 || ema5 <= 0.0 || ema10 <= 0.0 || ema15 <= 0.0 || ema65_current <= 0.0 || ema65_past <= 0.0) return false;

   bool signal_long = false;
   bool signal_short = false;

   // Long condition
   if(ema5 > ema10 && ema10 > ema15 && (ema5 - ema15) >= (strategy_ema_sep_atr_mult * atr1))
   {
      if(close1 > ema65_current && ema65_current > ema65_past)
      {
         if(IsMacdSignalInCloud(1, true)) signal_long = true;
      }
   }
   
   // Short condition
   if(ema5 < ema10 && ema10 < ema15 && (ema15 - ema5) >= (strategy_ema_sep_atr_mult * atr1))
   {
      if(close1 < ema65_current && ema65_current < ema65_past)
      {
         if(IsMacdSignalInCloud(1, false)) signal_short = true;
      }
   }

   if(!signal_long && !signal_short) return false;

   QM_OrderType side = signal_long ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double sl = 0.0;
   
   if(side == QM_BUY)
   {
      sl = iLow(_Symbol, PERIOD_H1, iLowest(_Symbol, PERIOD_H1, MODE_LOW, 10, 1)) - (2.0 * 10 * point);
   }
   else
   {
      sl = iHigh(_Symbol, PERIOD_H1, iHighest(_Symbol, PERIOD_H1, MODE_HIGH, 10, 1)) + (2.0 * 10 * point);
   }

   double risk_dist = MathAbs(entry - sl);
   double tp = (side == QM_BUY) ? entry + (risk_dist * strategy_tp_risk_mult) : entry - (risk_dist * strategy_tp_risk_mult);

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "KOBASFX_LONG" : "KOBASFX_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      if(strategy_time_stop_bars > 0)
      {
         datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         int bars = iBarShift(_Symbol, PERIOD_H1, opened);
         if(bars >= strategy_time_stop_bars) return true;
      }
      
      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      double signal = QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
      
      // MACD signal crosses zero against trade direction
      if(ptype == POSITION_TYPE_BUY && signal < 0) return true;
      if(ptype == POSITION_TYPE_SELL && signal > 0) return true;
      
      // MACD signal line exits the histogram cloud against trade direction
      // Cloud envelope min/max over last 5 bars
      double hist_min = 999999.0;
      double hist_max = -999999.0;
      for(int j = 0; j < 5; j++)
      {
         double h = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1 + j);
         if(h < hist_min) hist_min = h;
         if(h > hist_max) hist_max = h;
      }
      
      if(ptype == POSITION_TYPE_BUY && signal < hist_min) return true;
      if(ptype == POSITION_TYPE_SELL && signal > hist_max) return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

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
