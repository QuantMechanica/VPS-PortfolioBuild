#property strict
#property version   "5.0"
#property description "QM5_37005 Dr. Ernest P. Chan Bollinger & ADX Mean Reversion"
// Strategy Card: QM5_37005 (chan-bollinger-adx-mean-reversion), G0 APPROVED.
// Source: Chan, E. P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business.

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_37005 — Bollinger & ADX Mean Reversion
// -----------------------------------------------------------------------------
// Evaluates Bollinger Bands (20, 2.0) and ADX (14) on H1 closed bars:
//   - ADX < 20.0 (Stationary non-trending regime filter)
//   - Long Entry:  ADX[1] < 20.0 AND Low[1] <= LowerBB[1] AND Close[1] > Open[1]
//                  -> BUY,  SL = 1.5*ATR(14), TP = SMA(20) Midline
//   - Short Entry: ADX[1] < 20.0 AND High[1] >= UpperBB[1] AND Close[1] < Open[1]
//                  -> SELL, SL = 1.5*ATR(14), TP = SMA(20) Midline
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 37005;
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
input int    strategy_bb_period           = 20;     // Bollinger Bands period
input double strategy_bb_dev              = 2.00;   // Bollinger Bands standard deviation multiplier
input int    strategy_adx_period          = 14;     // ADX period
input double strategy_max_adx             = 20.0;   // Maximum ADX ranging filter ceiling
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 1.50;   // Stop loss ATR multiplier
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input int    strategy_max_spread_points   = 100;    // Absolute spread cap in points

// -----------------------------------------------------------------------------
// Cached State
// -----------------------------------------------------------------------------

double g_cached_adx       = 0.0;
double g_cached_bb_upper  = 0.0;
double g_cached_bb_lower  = 0.0;
double g_cached_bb_middle = 0.0;
double g_cached_atr1      = 0.0;
bool   g_cached_valid     = false;

void AdvanceState_OnNewBar()
{
   g_cached_adx       = QM_ADX(_Symbol, PERIOD_H1, strategy_adx_period, 1);
   g_cached_bb_upper  = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   g_cached_bb_lower  = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   g_cached_bb_middle = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   g_cached_atr1      = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);

   g_cached_valid = (g_cached_adx > 0.0 && g_cached_bb_upper > 0.0 && g_cached_bb_lower > 0.0 && g_cached_bb_middle > 0.0 && g_cached_atr1 > 0.0);
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

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
   {
      if(g_cached_atr1 > 0.0 && (ask - bid) > (strategy_spread_atr_mult * g_cached_atr1))
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

   if(!g_cached_valid)
      return false;

   // Ranging regime check: ADX < 20.0
   if(g_cached_adx >= strategy_max_adx)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, 1, 1, rates) < 1)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   double sl_dist = strategy_sl_atr_mult * g_cached_atr1;
   if(sl_dist <= 0.0)
      return false;

   // Long: ADX[1] < 20.0 AND Low[1] <= LowerBB[1] AND Close[1] > Open[1]
   if(rates[0].low <= g_cached_bb_lower && rates[0].close > rates[0].open)
   {
      req.type   = QM_BUY;
      req.reason = "QM5_37005_BB_ADX_BUY";
      req.sl     = ask - sl_dist;
      req.tp     = (g_cached_bb_middle > ask) ? g_cached_bb_middle : (ask + sl_dist);
      return true;
   }
   // Short: ADX[1] < 20.0 AND High[1] >= UpperBB[1] AND Close[1] < Open[1]
   else if(rates[0].high >= g_cached_bb_upper && rates[0].close < rates[0].open)
   {
      req.type   = QM_SELL;
      req.reason = "QM5_37005_BB_ADX_SELL";
      req.sl     = bid + sl_dist;
      req.tp     = (g_cached_bb_middle < bid) ? g_cached_bb_middle : (bid - sl_dist);
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

   AdvanceState_OnNewBar();

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

   AdvanceState_OnNewBar();

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
