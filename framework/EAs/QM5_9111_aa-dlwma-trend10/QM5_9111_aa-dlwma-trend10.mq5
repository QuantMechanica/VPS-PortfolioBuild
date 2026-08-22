#property strict
#property version   "5.0"
#property description "QM5_9111 Alpha Architect DLWMA N10 Trend Filter"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_9111
// -----------------------------------------------------------------------------
// Card: aa-dlwma-trend10 (source ede348b4-0fa7-5be1-baa8-09e9089b67b7)
// Henry Stern, "Trend-Following Filters: Part 1/2", Alpha Architect (2020-12-29).
//
// Strategy logic:
//   Double Linear Weighted Moving Average (DLWMA) trend filter on D1 close.
//   LWMA1 = LWMA(Close, N=10), LWMA2 = LWMA(LWMA1, N=10).
//   Trend = LWMA1 - LWMA2 (or 6/(N*(N-1)) * (LWMA1 - LWMA2)).
//   Long : Trend(1) > 0.0 && Trend(2) <= 0.0
//   Exit : Trend(1) <= 0.0
//   Stop Loss: 3.0 * ATR(20, D1).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9111;
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
input int    strategy_period            = 10;
input int    strategy_min_daily_bars    = 80;
input int    strategy_atr_period        = 20;
input double strategy_sl_atr_mult       = 3.0;
input double strategy_spread_atr_mult   = 0.3;
input bool   strategy_allow_short       = false;

// -----------------------------------------------------------------------------
// State tracking
// -----------------------------------------------------------------------------
QM_ExitReason g_strategy_exit_reason    = QM_EXIT_STRATEGY;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
bool SpreadAllows(const double atr_val)
{
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return false;
   const double spread = ask - bid;
   if(spread < DBL_EPSILON)
      return true;
   if(atr_val <= 0.0)
      return true;
   return (spread <= strategy_spread_atr_mult * atr_val);
}

bool SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype, datetime &open_time, double &open_price, double &sl_price)
{
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   open_time = 0;
   open_price = 0.0;
   sl_price = 0.0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong cand = PositionGetTicket(i);
      if(cand == 0 || !PositionSelectByTicket(cand))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = cand;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl_price = PositionGetDouble(POSITION_SL);
      return true;
   }
   return false;
}

double ComputeDLWMATrend(const int shift)
{
   const int n = MathMax(2, strategy_period);
   const int sum_weights = n * (n + 1) / 2;

   const double lwma1 = QM_LWMA(_Symbol, PERIOD_D1, n, shift, PRICE_CLOSE);

   double sum_lwma2 = 0.0;
   for(int k = 0; k < n; ++k)
   {
      const double l1_val = QM_LWMA(_Symbol, PERIOD_D1, n, shift + k, PRICE_CLOSE);
      sum_lwma2 += (double)(n - k) * l1_val;
   }
   const double lwma2 = sum_lwma2 / (double)sum_weights;

   return (lwma1 - lwma2);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(Bars(_Symbol, PERIOD_D1) < strategy_min_daily_bars)
      return true;

   const double atr_val = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(!SpreadAllows(atr_val))
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   ZeroMemory(req);

   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime open_time = 0;
   double open_price = 0.0;
   double sl_price = 0.0;
   if(SelectOurPosition(ticket, ptype, open_time, open_price, sl_price))
      return false;

   if(Bars(_Symbol, PERIOD_D1) < strategy_min_daily_bars)
      return false;

   const double trend1 = ComputeDLWMATrend(1);
   const double trend2 = ComputeDLWMATrend(2);

   const bool cross_up = (trend1 > 0.0 && trend2 <= 0.0);
   const bool cross_down = (trend1 < 0.0 && trend2 >= 0.0);

   const double atr_val = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_val <= 0.0)
      return false;

   if(cross_up)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;

      const double sl_dist = strategy_sl_atr_mult * atr_val;
      const double sl_target = QM_StopRulesNormalizePrice(_Symbol, ask - sl_dist);

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl_target;
      req.tp = 0.0;
      req.reason = "Alpha Architect DLWMA N10 Long";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }
   else if(cross_down && strategy_allow_short)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;

      const double sl_dist = strategy_sl_atr_mult * atr_val;
      const double sl_target = QM_StopRulesNormalizePrice(_Symbol, bid + sl_dist);

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl_target;
      req.tp = 0.0;
      req.reason = "Alpha Architect DLWMA N10 Short";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   datetime open_time = 0;
   double open_price = 0.0;
   double sl_price = 0.0;
   if(!SelectOurPosition(ticket, ptype, open_time, open_price, sl_price))
      return false;

   const double trend1 = ComputeDLWMATrend(1);

   if(ptype == POSITION_TYPE_BUY && trend1 <= 0.0)
   {
      g_strategy_exit_reason = QM_EXIT_STRATEGY;
      return true;
   }
   else if(ptype == POSITION_TYPE_SELL && trend1 >= 0.0)
   {
      g_strategy_exit_reason = QM_EXIT_STRATEGY;
      return true;
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
         QM_TM_ClosePosition(ticket, g_strategy_exit_reason);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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

