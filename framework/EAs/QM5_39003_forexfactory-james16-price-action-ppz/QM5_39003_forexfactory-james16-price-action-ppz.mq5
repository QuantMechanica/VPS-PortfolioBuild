#property strict
#property version   "5.0"
#property description "QM5_39003 forexfactory-james16-price-action-ppz — James16 Price Action & PPZ Rejection (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_39003 forexfactory-james16-price-action-ppz
// -----------------------------------------------------------------------------
// Source: James16 (2005-2024). All Things Price Action. Forex Factory (>30M Views).
// Card: artifacts/cards_approved/QM5_39003_forexfactory-james16-price-action-ppz.md (g0_status APPROVED).
//
// Mechanics (closed-bar, D1):
//   - PPZ Level: Swing high/low detection over InpPPZLookback bars.
//   - Pin Bar: range within [0.5, 3.5]*ATR(14), body <= 0.25*range.
//   - Long: Lower wick >= 0.65*range, low near PPZ support, close > EMA(21).
//   - Short: Upper wick >= 0.65*range, high near PPZ resistance, close < EMA(21).
//   - SL: 2 pips beyond pin tail.
//   - TP: 1:2.5 R:R target.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 39003;
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
input int    InpPPZLookback             = 20;     // PPZ detection lookback bars (D1)
input int    InpTrendEMA                = 21;     // Baseline trend EMA period
input int    strategy_atr_period        = 14;     // ATR period (D1)
input double strategy_zone_atr_mult     = 0.50;   // PPZ zone tolerance in ATR
input double strategy_min_pin_atr_mult  = 0.50;   // Min candle range as ATR multiple
input double strategy_max_pin_atr_mult  = 3.50;   // Max candle range as ATR multiple
input double strategy_wick_frac         = 0.65;   // Dominant wick >= this fraction of range
input double strategy_body_frac         = 0.25;   // Body <= this fraction of range
input double strategy_sl_buffer_pips    = 2.0;    // SL buffer beyond pin extreme (pips)
input double strategy_tp_rr             = 2.5;    // Take profit R:R multiple

// -----------------------------------------------------------------------------
// Helper functions (evaluated on closed-bar cadence)
// -----------------------------------------------------------------------------

bool IsSwingLow(const int k, const int strength)
{
   const double lk = iLow(_Symbol, PERIOD_D1, k); // perf-allowed: bounded new-bar scan
   if(lk <= 0.0) return false;
   for(int j = 1; j <= strength; ++j)
   {
      if(iLow(_Symbol, PERIOD_D1, k - j) <= lk) return false; // perf-allowed: bounded structural scan
      if(iLow(_Symbol, PERIOD_D1, k + j) <= lk) return false; // perf-allowed: bounded structural scan
   }
   return true;
}

bool IsSwingHigh(const int k, const int strength)
{
   const double hk = iHigh(_Symbol, PERIOD_D1, k); // perf-allowed: bounded new-bar scan
   if(hk <= 0.0) return false;
   for(int j = 1; j <= strength; ++j)
   {
      if(iHigh(_Symbol, PERIOD_D1, k - j) >= hk) return false; // perf-allowed: bounded structural scan
      if(iHigh(_Symbol, PERIOD_D1, k + j) >= hk) return false; // perf-allowed: bounded structural scan
   }
   return true;
}

bool HasPPZSupportNear(const double price, const double tol, const int lookback)
{
   const int strength = 2;
   for(int k = strength + 1; k <= lookback; ++k)
   {
      if(IsSwingLow(k, strength))
      {
         const double lvl = iLow(_Symbol, PERIOD_D1, k); // perf-allowed: bounded structural scan
         if(lvl > 0.0 && MathAbs(price - lvl) <= tol)
            return true;
      }
   }
   return false;
}

bool HasPPZResistanceNear(const double price, const double tol, const int lookback)
{
   const int strength = 2;
   for(int k = strength + 1; k <= lookback; ++k)
   {
      if(IsSwingHigh(k, strength))
      {
         const double lvl = iHigh(_Symbol, PERIOD_D1, k); // perf-allowed: bounded structural scan
         if(lvl > 0.0 && MathAbs(price - lvl) <= tol)
            return true;
      }
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
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double ema = QM_EMA(_Symbol, PERIOD_D1, InpTrendEMA, 1);
   if(ema <= 0.0)
      return false;

   const double o1 = iOpen(_Symbol, PERIOD_D1, 1);   // perf-allowed: single closed bar
   const double h1 = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed: single closed bar
   const double l1 = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed: single closed bar
   const double c1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed bar
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0)
      return false;

   const double range = h1 - l1;
   if(range < strategy_min_pin_atr_mult * atr || range > strategy_max_pin_atr_mult * atr)
      return false;

   const double body = MathAbs(c1 - o1);
   if(body > strategy_body_frac * range)
      return false;

   const double upper_wick = h1 - MathMax(o1, c1);
   const double lower_wick = MathMin(o1, c1) - l1;
   const double tol = strategy_zone_atr_mult * atr;
   const double buf = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_sl_buffer_pips * 10.0));

   // Bullish Pinbar at PPZ Support
   if(lower_wick >= strategy_wick_frac * range && c1 > ema)
   {
      if(HasPPZSupportNear(l1, tol, InpPPZLookback))
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0) return false;
         const double sl = l1 - buf;
         if(sl <= 0.0 || sl >= ask) return false;
         const double tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_tp_rr);
         if(tp <= 0.0) return false;

         req.type               = QM_BUY;
         req.price              = 0.0;
         req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
         req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
         req.reason             = "JAMES16_PINBAR_PPZ_LONG";
         req.symbol_slot        = qm_magic_slot_offset;
         req.expiration_seconds = 0;
         return true;
      }
   }

   // Bearish Pinbar at PPZ Resistance
   if(upper_wick >= strategy_wick_frac * range && c1 < ema)
   {
      if(HasPPZResistanceNear(h1, tol, InpPPZLookback))
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0) return false;
         const double sl = h1 + buf;
         if(sl <= 0.0 || sl <= bid) return false;
         const double tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_tp_rr);
         if(tp <= 0.0) return false;

         req.type               = QM_SELL;
         req.price              = 0.0;
         req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
         req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
         req.reason             = "JAMES16_PINBAR_PPZ_SHORT";
         req.symbol_slot        = qm_magic_slot_offset;
         req.expiration_seconds = 0;
         return true;
      }
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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_D1,
                                            QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                            "V5_WEEKEND_RISK_POLICY"))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_39003_forexfactory-james16-price-action-ppz\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
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
