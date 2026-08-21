#property strict
#property version   "5.0"
#property description "QM5_34004 Nikolay Kositsin Step-Trend Parabolic Envelope"
// Strategy Card: QM5_34004 (kositsin-step-trend-parabolic-envelope), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_34004
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 34004;
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
input int    strategy_atr_period          = 14;     // ATR volatility lookback period
input double strategy_step_mult           = 0.80;   // ATR multiplier for discrete step size
input double strategy_sar_step            = 0.02;   // Parabolic SAR acceleration step
input double strategy_sar_max             = 0.20;   // Parabolic SAR maximum acceleration
input double strategy_tp_rr_mult          = 2.0;    // 1:2.0 Risk:Reward multiplier for TP
input int    strategy_spread_atr_period   = 14;     // Spread filter ATR period
input double strategy_spread_atr_mult     = 1.8;    // Spread filter threshold
input int    strategy_step_lookback       = 50;     // Lookback bars for Step-MA path reconstruction

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

int GetBarHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
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

   const double atr_1 = QM_ATR(_Symbol, PERIOD_H1, strategy_spread_atr_period, 1);
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

   const double atr_1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr_1 <= 0.0)
      return false;

   const double step_size = strategy_step_mult * atr_1;
   if(step_size <= 0.0)
      return false;

   const int lookback = MathMax(20, strategy_step_lookback);
   double step_ma = iClose(_Symbol, PERIOD_H1, lookback); // perf-allowed: closed-bar lookback behind QM_IsNewBar()
   if(step_ma <= 0.0)
      return false;

   double step_ma_1 = step_ma;
   double step_ma_2 = step_ma;

   for(int i = lookback - 1; i >= 1; --i)
   {
      const double price = iClose(_Symbol, PERIOD_H1, i); // perf-allowed: closed-bar reference behind QM_IsNewBar()
      if(price <= 0.0)
         return false;

      while(price >= step_ma + step_size)
         step_ma += step_size;
      while(price <= step_ma - step_size)
         step_ma -= step_size;

      if(i == 2)
         step_ma_2 = step_ma;
      if(i == 1)
         step_ma_1 = step_ma;
   }

   const double c1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: closed-bar reference behind QM_IsNewBar()
   const double low_1 = iLow(_Symbol, PERIOD_H1, 1); // perf-allowed: closed-bar reference behind QM_IsNewBar()
   const double high_1 = iHigh(_Symbol, PERIOD_H1, 1); // perf-allowed: closed-bar reference behind QM_IsNewBar()
   const double sar_1 = QM_SAR(_Symbol, PERIOD_H1, strategy_sar_step, strategy_sar_max, 1);

   if(c1 <= 0.0 || low_1 <= 0.0 || high_1 <= 0.0 || sar_1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // Long: Close[1] > Step_MA[1] AND Step_MA[1] > Step_MA[2] AND Parabolic_SAR[1] < Low[1]
   if(c1 > step_ma_1 && step_ma_1 > step_ma_2 && sar_1 < low_1)
   {
      double sl_price = step_ma_1 - 0.5 * step_size;
      double sl_dist = ask - sl_price;
      if(sl_dist <= 0.0)
      {
         sl_dist = 1.5 * atr_1;
         sl_price = ask - sl_dist;
      }
      const double tp_dist = strategy_tp_rr_mult * sl_dist;

      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, sl_price);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, ask + tp_dist);
      req.reason = "QMU_34004_BUY";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
   }

   // Short: Close[1] < Step_MA[1] AND Step_MA[1] < Step_MA[2] AND Parabolic_SAR[1] > High[1]
   if(c1 < step_ma_1 && step_ma_1 < step_ma_2 && sar_1 > high_1)
   {
      double sl_price = step_ma_1 + 0.5 * step_size;
      double sl_dist = sl_price - bid;
      if(sl_dist <= 0.0)
      {
         sl_dist = 1.5 * atr_1;
         sl_price = bid + sl_dist;
      }
      const double tp_dist = strategy_tp_rr_mult * sl_dist;

      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, sl_price);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, bid - tp_dist);
      req.reason = "QMU_34004_SELL";
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_34004\",\"ea\":\"QM5_34004_kositsin-step-trend-parabolic-envelope\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_H1))
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
