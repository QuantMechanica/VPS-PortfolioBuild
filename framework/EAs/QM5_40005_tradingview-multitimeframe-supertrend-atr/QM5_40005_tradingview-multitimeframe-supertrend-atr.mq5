#property strict
#property version   "5.0"
#property description "QM5_40005 TradingView Multi-Timeframe Supertrend ATR Trend Rider (H1/H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_40005 tradingview-multitimeframe-supertrend-atr
// -----------------------------------------------------------------------------
// Source: KivancOzbilgic & LuxAlgo (2020). Multi-Timeframe Supertrend Strategy.
// Card: artifacts/cards_approved/QM5_40005_tradingview-multitimeframe-supertrend-atr.md (APPROVED)
//
// Mechanics (closed-bar, H1 primary with H4 macro filter):
//   - Macro Trend Filter: H4 Supertrend (ATR 10, Mult 3.0) direction (BULL / BEAR)
//   - Trigger: H1 Supertrend (ATR 10, Mult 3.0) direction flip into macro direction
//   - Long Entry: H4[1] == BULL && H1[1] == BULL && H1[2] == BEAR
//   - Short Entry: H4[1] == BEAR && H1[1] == BEAR && H1[2] == BULL
//   - SL: Supertrend line ± 2.0 pips buffer (clamped between 0.5*ATR and 3.5*ATR)
//   - TP: 2.0 * SL_Distance (1:2.0 Risk:Reward)
//   - Trailing: Trailed bar-by-bar to active Supertrend line ± buffer
//   - Exit: Supertrend H1 flip opposite position direction
//   - No-Trade Filter: Spread > 1.8 * ATR(14, H1)[1], Rollover blackout 23:55-00:05
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 40005;
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
input int    InpATRPeriod               = 10;     // Supertrend ATR period
input double InpATRMultiplier           = 3.0;    // Supertrend ATR multiplier
input int    InpWarmupBars              = 100;    // Closed-bar warmup depth for Supertrend
input double InpBufferPips              = 2.0;    // Stop loss buffer in pips
input double InpSpreadATRMult           = 1.8;    // Max spread multiplier vs ATR(14, H1)
input double InpTakeProfitRR            = 2.0;    // Take profit risk:reward ratio
input int    InpSpreadATRPeriod         = 14;     // Spread filter ATR period

// -----------------------------------------------------------------------------
// Helper: Supertrend Calculation over closed bars
// -----------------------------------------------------------------------------
int CalculateSupertrend(const string sym, const ENUM_TIMEFRAMES tf,
                        const int atr_period, const double factor,
                        const int target_shift, double &out_line)
{
   if(atr_period <= 0 || factor <= 0.0)
      return 0;

   const int warmup = MathMax(InpWarmupBars, atr_period + 20);
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(sym, tf, target_shift, warmup, rates); // perf-allowed: closed-bar Supertrend reconstruction
   if(copied < atr_period + 10)
      return 0;

   int trend = 0;
   double final_upper = 0.0;
   double final_lower = 0.0;

   for(int i = 0; i < copied; ++i)
   {
      const int bar_shift = target_shift + (copied - 1 - i);
      const double high  = rates[i].high;
      const double low   = rates[i].low;
      const double close = rates[i].close;
      const double atr   = QM_ATR(sym, tf, atr_period, bar_shift);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || atr <= 0.0)
         continue;

      const double median      = (high + low) * 0.5;
      const double basic_upper = median + factor * atr;
      const double basic_lower = median - factor * atr;

      if(trend == 0)
      {
         final_upper = basic_upper;
         final_lower = basic_lower;
         trend = (close >= median) ? 1 : -1;
         continue;
      }

      const double prev_close = rates[i - 1].close;
      final_upper = (basic_upper < final_upper || prev_close > final_upper) ? basic_upper : final_upper;
      final_lower = (basic_lower > final_lower || prev_close < final_lower) ? basic_lower : final_lower;

      if(trend < 0 && close > final_upper)
         trend = 1;
      else if(trend > 0 && close < final_lower)
         trend = -1;
   }

   out_line = (trend > 0) ? final_lower : final_upper;
   return trend;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const double atr_14 = QM_ATR(_Symbol, PERIOD_H1, InpSpreadATRPeriod, 1);
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

   double h4_line = 0.0;
   const int h4_trend = CalculateSupertrend(_Symbol, PERIOD_H4, InpATRPeriod, InpATRMultiplier, 1, h4_line);
   if(h4_trend == 0)
      return false;

   double h1_line_1 = 0.0;
   const int h1_trend_1 = CalculateSupertrend(_Symbol, PERIOD_H1, InpATRPeriod, InpATRMultiplier, 1, h1_line_1);
   if(h1_trend_1 == 0)
      return false;

   double h1_line_2 = 0.0;
   const int h1_trend_2 = CalculateSupertrend(_Symbol, PERIOD_H1, InpATRPeriod, InpATRMultiplier, 2, h1_line_2);
   if(h1_trend_2 == 0)
      return false;

   const double atr_1 = QM_ATR(_Symbol, PERIOD_H1, InpATRPeriod, 1);
   if(atr_1 <= 0.0)
      return false;

   const double buf = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(InpBufferPips * 10.0));

   // Long Entry: Macro H4 Bull + H1 fresh Bull flip
   if(h4_trend == 1 && h1_trend_1 == 1 && h1_trend_2 == -1)
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;

      double sl = h1_line_1 - buf;
      if(ask - sl < 0.5 * atr_1) sl = ask - 0.5 * atr_1;
      if(ask - sl > 3.5 * atr_1) sl = ask - 3.5 * atr_1;
      if(sl <= 0.0 || sl >= ask) return false;

      const double sl_dist = ask - sl;
      const double tp = ask + InpTakeProfitRR * sl_dist;

      req.type               = QM_BUY;
      req.price              = 0.0;
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason             = "SUPERTREND_MTF_H1_BUY";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   // Short Entry: Macro H4 Bear + H1 fresh Bear flip
   if(h4_trend == -1 && h1_trend_1 == -1 && h1_trend_2 == 1)
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;

      double sl = h1_line_1 + buf;
      if(sl - bid < 0.5 * atr_1) sl = bid + 0.5 * atr_1;
      if(sl - bid > 3.5 * atr_1) sl = bid + 3.5 * atr_1;
      if(sl <= 0.0 || sl <= bid) return false;

      const double sl_dist = sl - bid;
      const double tp = bid - InpTakeProfitRR * sl_dist;

      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason             = "SUPERTREND_MTF_H1_SELL";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   const double buf = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(InpBufferPips * 10.0));

   double h1_line = 0.0;
   const int h1_trend = CalculateSupertrend(_Symbol, PERIOD_H1, InpATRPeriod, InpATRMultiplier, 1, h1_line);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);

      if(ptype == POSITION_TYPE_BUY && h1_trend == 1)
      {
         const double new_sl = QM_StopRulesNormalizePrice(_Symbol, h1_line - buf);
         if(new_sl > current_sl && new_sl < SymbolInfoDouble(_Symbol, SYMBOL_BID))
         {
            QM_TM_MoveSL(ticket, new_sl, "SUPERTREND_H1_TRAIL");
         }
      }
      else if(ptype == POSITION_TYPE_SELL && h1_trend == -1)
      {
         const double new_sl = QM_StopRulesNormalizePrice(_Symbol, h1_line + buf);
         if((current_sl <= 0.0 || new_sl < current_sl) && new_sl > SymbolInfoDouble(_Symbol, SYMBOL_ASK))
         {
            QM_TM_MoveSL(ticket, new_sl, "SUPERTREND_H1_TRAIL");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   double h1_line = 0.0;
   const int h1_trend = CalculateSupertrend(_Symbol, PERIOD_H1, InpATRPeriod, InpATRMultiplier, 1, h1_line);
   if(h1_trend == 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && h1_trend == -1)
         return true;
      if(ptype == POSITION_TYPE_SELL && h1_trend == 1)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_40005_tradingview-multitimeframe-supertrend-atr\"}");
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
