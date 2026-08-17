#property strict
#property version   "5.0"
#property description "QM5_34001 Kalman Filter Dynamic State Estimation Scalper"
// Strategy Card: QM5_34001 (kalman-filter-state-estimation-scalper), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_34001
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 34001;
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
input double strategy_process_noise_q     = 0.0001; // Process noise covariance parameter Q
input double strategy_measurement_noise_r = 0.01;   // Measurement noise variance parameter R
input double strategy_z_threshold         = 2.00;   // Innovation Z-Score threshold
input int    strategy_atr_period          = 14;     // ATR period for stop loss sizing
input double strategy_sl_atr_mult         = 1.5;    // Initial SL in ATR multiples
input int    strategy_spread_atr_period   = 14;     // Spread filter ATR period
input double strategy_spread_atr_mult     = 1.8;    // Spread filter threshold

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

int GetBarHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
}

bool ComputeKalmanState(const string sym, const ENUM_TIMEFRAMES tf,
                        const double q, const double r,
                        double &out_x, double &out_z)
{
   const int lookback = 100;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(sym, tf, 1, lookback, rates) < lookback)
      return false;

   double x = rates[lookback - 1].close;
   double p = 1.0;

   double y = 0.0;
   double s = 0.0;
   double k = 0.0;
   double z = 0.0;

   for(int i = lookback - 2; i >= 0; --i)
   {
      p = p + q;
      y = rates[i].close - x;
      s = p + r;
      if(s <= 0.0) s = 1e-6;

      k = p / s;
      z = y / MathSqrt(s);

      x = x + k * y;
      p = (1.0 - k) * p;
   }

   out_x = x;
   out_z = z;
   return true;
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

   const double atr_1 = QM_ATR(_Symbol, PERIOD_M15, strategy_spread_atr_period, 1);
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

   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   double kalman_x = 0.0;
   double kalman_z = 0.0;
   if(!ComputeKalmanState(_Symbol, PERIOD_M15, strategy_process_noise_q, strategy_measurement_noise_r, kalman_x, kalman_z))
      return false;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   const double close_1 = iClose(_Symbol, PERIOD_M15, 1);
   const double open_1  = iOpen(_Symbol, PERIOD_M15, 1);

   if(atr_1 <= 0.0 || close_1 <= 0.0 || open_1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double sl_dist = strategy_sl_atr_mult * atr_1;

   // Long entry: Z <= -2.00 AND Close[1] > Open[1]
   if(kalman_z <= -strategy_z_threshold && close_1 > open_1)
   {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, ask - sl_dist);
      double tp_target = kalman_x;
      if(tp_target <= ask + point)
         tp_target = ask + 1.5 * sl_dist;
      req.tp = QM_StopRulesNormalizePrice(_Symbol, tp_target);
      req.reason = "QM5_34001_BUY";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
   }

   // Short entry: Z >= +2.00 AND Close[1] < Open[1]
   if(kalman_z >= strategy_z_threshold && close_1 < open_1)
   {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, bid + sl_dist);
      double tp_target = kalman_x;
      if(tp_target >= bid - point)
         tp_target = bid - 1.5 * sl_dist;
      req.tp = QM_StopRulesNormalizePrice(_Symbol, tp_target);
      req.reason = "QM5_34001_SELL";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
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

   if(!QM_IsNewBar(_Symbol, PERIOD_M15)) return;
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
