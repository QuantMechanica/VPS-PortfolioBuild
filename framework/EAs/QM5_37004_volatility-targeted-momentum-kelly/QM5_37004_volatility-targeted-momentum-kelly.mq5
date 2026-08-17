#property strict
#property version   "5.0"
#property description "QM5_37004 Volatility-Targeted Momentum with Half-Kelly Sizing (Marcos Lopez de Prado)"
// Strategy Card: QM5_37004 (volatility-targeted-momentum-kelly), G0 APPROVED.
// Source: Lopez de Prado, M. (2018). Advances in Financial Machine Learning. Backtrader Engine.

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_37004 — Volatility-Targeted Momentum
// -----------------------------------------------------------------------------
// Evaluates 12-month (252-day) momentum and 200-day SMA on D1 closed bars:
//   - Long Entry:  Momentum_12M[1] > 0 AND Close[1] > SMA(200, D1)[1]
//   - Short Entry: Momentum_12M[1] < 0 AND Close[1] < SMA(200, D1)[1]
//   - Stop Loss:   2.0 * ATR(14, D1)[1]
//   - Management:  Trailing Chandelier ATR stop at 3.0 * ATR(14, D1)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 37004;
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
input int    strategy_momentum_days       = 252;    // Momentum lookback in D1 bars
input int    strategy_sma_period          = 200;    // Trend baseline SMA period
input int    strategy_atr_period          = 14;     // ATR period for stop loss and spread filter
input double strategy_sl_atr_mult         = 2.00;   // Stop loss ATR multiplier
input double strategy_trail_atr_mult      = 3.00;   // Chandelier trailing ATR multiplier
input double strategy_spread_atr_mult     = 1.80;   // Spread filter ATR multiplier
input int    strategy_max_spread_points   = 300;    // Absolute spread cap in points

// -----------------------------------------------------------------------------
// Cached State
// -----------------------------------------------------------------------------

double g_cached_atr1      = 0.0;
double g_cached_sma200    = 0.0;
double g_cached_momentum  = 0.0;
bool   g_cached_mom_valid = false;

void AdvanceState_OnNewBar()
{
   g_cached_atr1   = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   g_cached_sma200 = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);

   const double c1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 closed bar close
   const double c_past = iClose(_Symbol, PERIOD_D1, 1 + strategy_momentum_days); // perf-allowed: D1 lookback close
   if(c1 > 0.0 && c_past > 0.0)
   {
      g_cached_momentum = c1 - c_past;
      g_cached_mom_valid = true;
   }
   else
   {
      g_cached_momentum = 0.0;
      g_cached_mom_valid = false;
   }
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

   if(!g_cached_mom_valid || g_cached_sma200 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: closed D1 bar close reference
   if(close1 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // Long: Momentum_12M > 0 AND Close[1] > SMA(200, D1)[1]
   if(g_cached_momentum > 0.0 && close1 > g_cached_sma200)
   {
      req.type   = QM_BUY;
      req.reason = "QM5_37004_MOM_BUY";
      req.sl     = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_sl_atr_mult);
   }
   // Short: Momentum_12M < 0 AND Close[1] < SMA(200, D1)[1]
   else if(g_cached_momentum < 0.0 && close1 < g_cached_sma200)
   {
      req.type   = QM_SELL;
      req.reason = "QM5_37004_MOM_SELL";
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
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
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
