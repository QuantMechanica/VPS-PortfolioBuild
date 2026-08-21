#property strict
#property version   "5.0"
#property description "QM5_34005 Vasiliy Sokolov CStrategy Donchian & ATR Breakout"
// Strategy Card: QM5_34005 (sokolov-cstrategy-donchian-atr-breakout), G0 APPROVED 2026-08-15.

#include <QM/QM_Common.mqh>
#include <Trade/Trade.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_34005
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 34005;
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
input int    strategy_donchian_period     = 20;     // Donchian Channel breakout lookback
input int    strategy_atr_period          = 14;     // ATR volatility filter period
input int    strategy_atr_ma_period       = 20;     // ATR SMA baseline period
input double strategy_sl_atr_mult         = 1.5;    // Initial SL in ATR multiples
input double strategy_tp_rr_mult          = 2.0;    // 1:2.0 Risk:Reward multiplier for TP
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

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const datetime now = TimeCurrent();
   const int hhmm = GetBarHhmm(now);
   if(hhmm >= 2355 || hhmm < 5)
      return true;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_H4, strategy_spread_atr_period, 1);
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

   const double atr_1 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr_1 <= 0.0)
      return false;

   double atr_sum = 0.0;
   for(int i = 1; i <= strategy_atr_ma_period; ++i)
   {
      atr_sum += QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, i);
   }
   const double atr_sma = atr_sum / (double)strategy_atr_ma_period;

   if(atr_1 <= atr_sma)
      return false;

   double upper_dc = -DBL_MAX;
   double lower_dc = DBL_MAX;
   for(int i = 2; i <= 1 + strategy_donchian_period; ++i)
   {
      const double h = iHigh(_Symbol, PERIOD_H4, i); // perf-allowed: closed-bar lookback behind QM_IsNewBar()
      const double l = iLow(_Symbol, PERIOD_H4, i);  // perf-allowed: closed-bar lookback behind QM_IsNewBar()
      if(h > upper_dc) upper_dc = h;
      if(l < lower_dc) lower_dc = l;
   }

   const double c1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: closed-bar reference behind QM_IsNewBar()
   if(c1 <= 0.0 || upper_dc <= 0.0 || lower_dc <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double sl_dist = strategy_sl_atr_mult * atr_1;
   const double tp_dist = strategy_tp_rr_mult * sl_dist;

   // Long: Close[1] > UpperDC[1] AND ATR(14)[1] > SMA(ATR, 20)[1]
   if(c1 > upper_dc)
   {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, ask - sl_dist);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, ask + tp_dist);
      req.reason = "QMU_34005_BUY";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
   }

   // Short: Close[1] < LowerDC[1] AND ATR(14)[1] > SMA(ATR, 20)[1]
   if(c1 < lower_dc)
   {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, bid + sl_dist);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, bid - tp_dist);
      req.reason = "QMU_34005_SELL";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_sl_atr_mult);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_34005\",\"ea\":\"QM5_34005_sokolov-cstrategy-donchian-atr-breakout\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_H4))
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
