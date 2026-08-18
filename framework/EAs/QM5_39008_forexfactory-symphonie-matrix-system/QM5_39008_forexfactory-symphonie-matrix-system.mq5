#property strict
#property version   "5.0"
#property description "QM5_39008 ForexFactory Symphonie Matrix System (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_39008 forexfactory-symphonie-matrix-system
// -----------------------------------------------------------------------------
// Source: Symphonie (2011-2024). Symphonie Trader System. Forex Factory.
// Card: artifacts/cards_approved/QM5_39008_forexfactory-symphonie-matrix-system.md (APPROVED)
//
// Mechanics (closed-bar, H1):
//   - Multi-system 4-module consensus:
//       1. Trendline: Close > EMA(20) (Bull) / Close < EMA(20) (Bear)
//       2. Extreme: RSI(14) > 50.0 (Bull) / RSI(14) < 50.0 (Bear)
//       3. Emotion: MACD(12,26,9) Main > Signal (Bull) / Main < Signal (Bear)
//       4. Sentiment: Stochastic(5,3,3) %K > %D (Bull) / %K < %D (Bear)
//   - Long Entry: All 4 Bull on bar [1] AND NOT all 4 Bull on bar [2]
//   - Short Entry: All 4 Bear on bar [1] AND NOT all 4 Bear on bar [2]
//   - SL: Entry ± 1.5 * ATR(14, H1)[1] (clamped between 0.5*ATR and 3.5*ATR)
//   - TP: 2.0 * SL_Distance (1:2.0 Risk:Reward)
//   - Management: Move to Break-Even at +1.0R
//   - Exit: Symphonie reverse consensus against trade direction
//   - No-Trade Filter: Spread > 1.8 * ATR(14, H1)[1], Rollover blackout 23:55-00:05
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 39008;
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
input int    InpTrendPeriod             = 20;     // Symphonie Trendline EMA period
input int    InpExtremePeriod           = 14;     // Symphonie Extreme RSI period
input double InpExtremeMidline          = 50.0;   // Symphonie Extreme RSI baseline
input int    InpEmotionFast             = 12;     // Symphonie Emotion MACD fast EMA
input int    InpEmotionSlow             = 26;     // Symphonie Emotion MACD slow EMA
input int    InpEmotionSignal           = 9;      // Symphonie Emotion MACD signal SMA
input int    InpSentimentK              = 5;      // Symphonie Sentiment Stochastic %K
input int    InpSentimentD              = 3;      // Symphonie Sentiment Stochastic %D
input int    InpSentimentSlow           = 3;      // Symphonie Sentiment Stochastic slowing
input int    InpATRPeriod               = 14;     // Stop Loss ATR period
input double InpATRMultiplier           = 1.5;    // Stop Loss ATR multiplier
input double InpTakeProfitRR            = 2.0;    // Take Profit risk:reward ratio
input double InpSpreadATRMult           = 1.8;    // Max spread multiplier vs ATR(14, H1)
input double InpBreakEvenTriggerR       = 1.0;    // Break-even trigger in R multiples

// -----------------------------------------------------------------------------
// Symphonie 4-Light Indicator Proxies
// -----------------------------------------------------------------------------

bool Light_Trendline(const int shift)
{
   const double ema = QM_EMA(_Symbol, PERIOD_H1, InpTrendPeriod, shift);
   const double c   = iClose(_Symbol, PERIOD_H1, shift); // perf-allowed: closed-bar trendline comparison
   return (ema > 0.0 && c > ema);
}

bool Light_Extreme(const int shift)
{
   const double rsi = QM_RSI(_Symbol, PERIOD_H1, InpExtremePeriod, shift);
   return (rsi > InpExtremeMidline);
}

bool Light_Emotion(const int shift)
{
   const double main = QM_MACD_Main(_Symbol, PERIOD_H1, InpEmotionFast, InpEmotionSlow, InpEmotionSignal, shift);
   const double sig  = QM_MACD_Signal(_Symbol, PERIOD_H1, InpEmotionFast, InpEmotionSlow, InpEmotionSignal, shift);
   return (main > sig);
}

bool Light_Sentiment(const int shift)
{
   const double k = QM_Stoch_K(_Symbol, PERIOD_H1, InpSentimentK, InpSentimentD, InpSentimentSlow, shift);
   const double d = QM_Stoch_D(_Symbol, PERIOD_H1, InpSentimentK, InpSentimentD, InpSentimentSlow, shift);
   return (k > d);
}

bool Symphonie_AllBull(const int shift)
{
   return (Light_Trendline(shift) &&
           Light_Extreme(shift) &&
           Light_Emotion(shift) &&
           Light_Sentiment(shift));
}

bool Symphonie_AllBear(const int shift)
{
   return (!Light_Trendline(shift) &&
           !Light_Extreme(shift) &&
           !Light_Emotion(shift) &&
           !Light_Sentiment(shift));
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const double atr_14 = QM_ATR(_Symbol, PERIOD_H1, InpATRPeriod, 1);
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

   const bool bull_1 = Symphonie_AllBull(1);
   const bool bull_2 = Symphonie_AllBull(2);
   const bool bear_1 = Symphonie_AllBear(1);
   const bool bear_2 = Symphonie_AllBear(2);

   const double atr_1 = QM_ATR(_Symbol, PERIOD_H1, InpATRPeriod, 1);
   if(atr_1 <= 0.0)
      return false;

   const double sl_dist_raw = InpATRMultiplier * atr_1;

   // Long Entry: Unanimous 4-light Bull consensus newly formed on bar 1
   if(bull_1 && !bull_2)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;

      double sl = ask - sl_dist_raw;
      if(ask - sl < 0.5 * atr_1) sl = ask - 0.5 * atr_1;
      if(ask - sl > 3.5 * atr_1) sl = ask - 3.5 * atr_1;
      if(sl <= 0.0 || sl >= ask) return false;

      const double sl_dist = ask - sl;
      const double tp = ask + InpTakeProfitRR * sl_dist;

      req.type               = QM_BUY;
      req.price              = 0.0;
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason             = "SYMPHONIE_MATRIX_H1_BUY";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   // Short Entry: Unanimous 4-light Bear consensus newly formed on bar 1
   if(bear_1 && !bear_2)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;

      double sl = bid + sl_dist_raw;
      if(sl - bid < 0.5 * atr_1) sl = bid + 0.5 * atr_1;
      if(sl - bid > 3.5 * atr_1) sl = bid + 3.5 * atr_1;
      if(sl <= 0.0 || sl <= bid) return false;

      const double sl_dist = sl - bid;
      const double tp = bid - InpTakeProfitRR * sl_dist;

      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason             = "SYMPHONIE_MATRIX_H1_SELL";
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
   const double buf = (point > 0.0) ? (point * 10.0) : 0.0001; // 1 pip buffer

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
               QM_TM_MoveSL(ticket, be_sl, "SYMPHONIE_BE_PROTECT");
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
               QM_TM_MoveSL(ticket, be_sl, "SYMPHONIE_BE_PROTECT");
            }
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   const bool bull_1 = Symphonie_AllBull(1);
   const bool bear_1 = Symphonie_AllBear(1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && bear_1)
         return true;
      if(ptype == POSITION_TYPE_SELL && bull_1)
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

   if(!QM_FrameworkDeclareExecutionContract(PERIOD_H1,
                                            QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
                                            "V5_WEEKEND_RISK_POLICY"))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_39008_forexfactory-symphonie-matrix-system\"}");
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
