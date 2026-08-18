#property strict
#property version   "5.0"
#property description "QM5_40008 AQR Value and Momentum Everywhere Multi-Asset Engine (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_40008 aqr-value-and-momentum-everywhere
// -----------------------------------------------------------------------------
// Source: Asness, C. S., Moskowitz, T. J., & Pedersen, L. H. (2013).
//         Value and Momentum Everywhere. Journal of Finance.
// Card: artifacts/cards_approved/QM5_40008_aqr-value-and-momentum-everywhere.md (APPROVED)
//
// Mechanics (closed-bar, D1):
//   - Momentum Factor (Mt): 12-month return = (P[1] - P[253]) / P[253]
//   - Value Factor (Vt): 5-year mean reversion Z-score = -(P[1] - SMA(1260)) / StdDev(1260)
//   - Combined Score: 0.50 * Score(Mt) + 0.50 * Score(Vt)
//   - Macro Trend Gate: D1 Close[1] vs SMA(200)[1]
//   - Long Entry: CombinedScore >= 0.70 AND Close[1] > SMA(200)[1]
//   - Short Entry: CombinedScore <= 0.30 AND Close[1] < SMA(200)[1]
//   - SL: Entry ± 2.5 * ATR(14, D1)[1] (clamped between 0.5*ATR and 5.0*ATR)
//   - TP: 2.0 * SL_Distance (1:2.0 Risk:Reward)
//   - Management: Move to Break-Even at +1.0R
//   - Exit: Factor score decay / reversal against trade direction
//   - No-Trade Filter: Spread > 1.8 * ATR(14, D1)[1], Rollover blackout 23:55-00:05
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 40008;
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
input int    InpMomDays                 = 252;    // 1-year momentum lookback trading days
input int    InpValDays                 = 1260;   // 5-year valuation mean lookback trading days
input int    InpSMAPeriod               = 200;    // Macro trend baseline SMA period
input double InpScoreThresholdLong      = 0.70;   // Combined score threshold for long entry
input double InpScoreThresholdShort     = 0.30;   // Combined score threshold for short entry
input double InpScoreDecayLong          = 0.40;   // Combined score decay exit for long
input double InpScoreDecayShort         = 0.60;   // Combined score decay exit for short
input int    InpATRPeriod               = 14;     // Stop Loss ATR period
input double InpATRMultiplier           = 2.5;    // Stop Loss ATR multiplier
input double InpTakeProfitRR            = 2.0;    // Take Profit risk:reward ratio
input double InpSpreadATRMult           = 1.8;    // Max spread multiplier vs ATR(14, D1)
input double InpBreakEvenTriggerR       = 1.0;    // Break-even trigger in R multiples

// -----------------------------------------------------------------------------
// Mathematical Helper: Sigmoid Normalization
// -----------------------------------------------------------------------------
double Sigmoid(const double x)
{
   if(x > 20.0) return 1.0;
   if(x < -20.0) return 0.0;
   return (1.0 / (1.0 + MathExp(-x)));
}

// -----------------------------------------------------------------------------
// Factor Calculation
// -----------------------------------------------------------------------------
double CalculateCombinedScore(const string sym, const int shift)
{
   const double p1 = iClose(sym, PERIOD_D1, shift);
   const double p_mom = iClose(sym, PERIOD_D1, shift + InpMomDays);
   if(p1 <= 0.0 || p_mom <= 0.0)
      return 0.5;

   // 1. Momentum 12-month return
   const double mom_ret = (p1 - p_mom) / p_mom;
   const double mom_score = Sigmoid(mom_ret * 5.0);

   // 2. 5-Year Valuation Mean & StdDev
   const int max_val_bars = MathMin(InpValDays, iBars(sym, PERIOD_D1) - shift - 1);
   if(max_val_bars < 100)
      return mom_score;

   double sum = 0.0;
   for(int i = 0; i < max_val_bars; ++i)
   {
      sum += iClose(sym, PERIOD_D1, shift + i);
   }
   const double mean_val = sum / (double)max_val_bars;

   double var_sum = 0.0;
   for(int i = 0; i < max_val_bars; ++i)
   {
      const double diff = iClose(sym, PERIOD_D1, shift + i) - mean_val;
      var_sum += diff * diff;
   }
   const double std_val = MathSqrt(var_sum / (double)max_val_bars);

   double val_score = 0.5;
   if(std_val > 0.0)
   {
      const double val_z = -(p1 - mean_val) / std_val; // Cheaper than average = positive value
      val_score = Sigmoid(val_z);
   }

   // 3. Equal-weighted Combination
   return (0.50 * mom_score + 0.50 * val_score);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const double atr_14 = QM_ATR(_Symbol, PERIOD_D1, InpATRPeriod, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid && atr_14 > 0.0)
   {
      if((ask - bid) > InpSpreadATRMult * atr_14)
         return true;
   }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int minute_of_day = dt.hour * 60 + dt.min;
   if(minute_of_day >= 1435 || minute_of_day < 5) // 23:55 - 00:05 blackout
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double score_1 = CalculateCombinedScore(_Symbol, 1);
   const double sma_200 = QM_SMA(_Symbol, PERIOD_D1, InpSMAPeriod, 1);
   const double c1      = iClose(_Symbol, PERIOD_D1, 1);
   const double atr_1   = QM_ATR(_Symbol, PERIOD_D1, InpATRPeriod, 1);

   if(c1 <= 0.0 || sma_200 <= 0.0 || atr_1 <= 0.0)
      return false;

   const double sl_dist_raw = InpATRMultiplier * atr_1;

   // Long Entry: High Combined Value+Momentum Score in uptrend above SMA200
   if(score_1 >= InpScoreThresholdLong && c1 > sma_200)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;

      double sl = ask - sl_dist_raw;
      if(ask - sl < 0.5 * atr_1) sl = ask - 0.5 * atr_1;
      if(ask - sl > 5.0 * atr_1) sl = ask - 5.0 * atr_1;
      if(sl <= 0.0 || sl >= ask) return false;

      const double sl_dist = ask - sl;
      const double tp = ask + InpTakeProfitRR * sl_dist;

      req.type               = QM_BUY;
      req.price              = 0.0;
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason             = "AQR_VALMOM_D1_BUY";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   // Short Entry: Low Combined Value+Momentum Score in downtrend below SMA200
   if(score_1 <= InpScoreThresholdShort && c1 < sma_200)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;

      double sl = bid + sl_dist_raw;
      if(sl - bid < 0.5 * atr_1) sl = bid + 0.5 * atr_1;
      if(sl - bid > 5.0 * atr_1) sl = bid + 5.0 * atr_1;
      if(sl <= 0.0 || sl <= bid) return false;

      const double sl_dist = sl - bid;
      const double tp = bid - InpTakeProfitRR * sl_dist;

      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason             = "AQR_VALMOM_D1_SELL";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double buf = (point > 0.0) ? (point * 10.0) : 0.0001;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);

      if(ptype == POSITION_TYPE_BUY)
      {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double initial_risk = open_price - current_sl;
         if(initial_risk > 0.0 && (bid - open_price) >= (InpBreakEvenTriggerR * initial_risk))
         {
            const double be_sl = QM_StopRulesNormalizePrice(_Symbol, open_price + buf);
            if(be_sl > current_sl && be_sl < bid)
            {
               QM_TM_MoveSL(ticket, be_sl, "AQR_VALMOM_BE_PROTECT");
            }
         }
      }
      else if(ptype == POSITION_TYPE_SELL)
      {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double initial_risk = current_sl - open_price;
         if(initial_risk > 0.0 && (open_price - ask) >= (InpBreakEvenTriggerR * initial_risk))
         {
            const double be_sl = QM_StopRulesNormalizePrice(_Symbol, open_price - buf);
            if((current_sl <= 0.0 || be_sl < current_sl) && be_sl > ask)
            {
               QM_TM_MoveSL(ticket, be_sl, "AQR_VALMOM_BE_PROTECT");
            }
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   const double score_1 = CalculateCombinedScore(_Symbol, 1);
   const double sma_200 = QM_SMA(_Symbol, PERIOD_D1, InpSMAPeriod, 1);
   const double c1      = iClose(_Symbol, PERIOD_D1, 1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && (score_1 <= InpScoreDecayLong || (sma_200 > 0.0 && c1 < sma_200)))
         return true;
      if(ptype == POSITION_TYPE_SELL && (score_1 >= InpScoreDecayShort || (sma_200 > 0.0 && c1 > sma_200)))
         return true;
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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_D1,
                                            QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                            "V5_WEEKEND_RISK_POLICY"))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_40008_aqr-value-and-momentum-everywhere\"}");
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
