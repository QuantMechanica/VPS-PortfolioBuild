#property strict
#property version   "5.0"
#property description "QM5_39007 forexfactory-100-pips-early-bird-breakout — 100 Pips Early Bird Breakout (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_39007 forexfactory-100-pips-early-bird-breakout
// -----------------------------------------------------------------------------
// Source: Robb (2008-2024). 100 Pips Today Early Bird. Forex Factory.
// Card: artifacts/cards_approved/QM5_39007_forexfactory-100-pips-early-bird-breakout.md (g0_status APPROVED).
//
// Mechanics (closed-bar, M15):
//   - Asian Tail Range: 05:00 to 07:00 GMT (UTC). Encapsulates Box High and Box Low.
//   - London Breakout Window: 07:00 to 12:00 GMT.
//   - Long Entry: First bar breakout above Box High + 3.0 pips buffer.
//   - Short Entry: First bar breakout below Box Low - 3.0 pips buffer.
//   - SL: 25.0 pips (or box boundary buffer clamped between 0.5*ATR and 3.5*ATR).
//   - TP: 50.0 pips target (1:2.0 R:R).
//   - Daily Exit: Close positions / cancel session at 12:00 GMT.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 39007;
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
input int    InpBoxStartHourUTC         = 5;      // Asian range box start hour (UTC)
input int    InpBoxEndHourUTC           = 7;      // Asian range box end / breakout start hour (UTC)
input int    InpSessionEndHourUTC       = 12;     // London morning session end hour (UTC)
input double InpBufferPips              = 3.0;    // Breakout entry buffer in pips
input double InpStopLossPips            = 25.0;   // Default stop loss in pips
input double InpTakeProfitPips          = 50.0;   // Default take profit in pips
input int    strategy_atr_period        = 14;     // ATR period (M15)
input double strategy_be_trigger_pips   = 20.0;   // Break-even trigger distance in pips

// -----------------------------------------------------------------------------
// File-scope cached state (updated once per new closed bar)
// -----------------------------------------------------------------------------
double g_cached_box_high = 0.0;
double g_cached_box_low  = 0.0;
int    g_cached_box_day  = -1;
bool   g_cached_traded   = false;
double g_cached_atr_1    = 0.0;

void AdvanceState_OnNewBar()
{
   g_cached_atr_1 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);

   const datetime b_time = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: closed bar open time
   const datetime u_time = QM_BrokerToUTC(b_time);
   MqlDateTime u_dt;
   TimeToStruct(u_time, u_dt);

   // Day transition reset
   if(u_dt.day != g_cached_box_day)
   {
      g_cached_box_day  = u_dt.day;
      g_cached_box_high = 0.0;
      g_cached_box_low  = 0.0;
      g_cached_traded   = false;
   }

   // At 07:00 UTC (the end of the 05:00 - 07:00 window), compute the 8-bar range
   if(u_dt.hour == InpBoxEndHourUTC && u_dt.min == 0)
   {
      double highest_h = 0.0;
      double lowest_l  = 999999.0;
      for(int s = 1; s <= 8; ++s)
      {
         const double h = iHigh(_Symbol, PERIOD_M15, s); // perf-allowed: 8-bar fixed box scan once per day
         const double l = iLow(_Symbol, PERIOD_M15, s);  // perf-allowed: 8-bar fixed box scan once per day
         if(h > highest_h) highest_h = h;
         if(l < lowest_l && l > 0.0) lowest_l = l;
      }
      if(highest_h > 0.0 && lowest_l < 999999.0)
      {
         g_cached_box_high = highest_h;
         g_cached_box_low  = lowest_l;
      }
   }
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid && g_cached_atr_1 > 0.0)
   {
      if((ask - bid) > 1.8 * g_cached_atr_1)
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

   if(g_cached_traded || g_cached_box_high <= 0.0 || g_cached_box_low <= 0.0 || g_cached_atr_1 <= 0.0)
      return false;

   const datetime b_time = iTime(_Symbol, PERIOD_M15, 1); // perf-allowed: closed bar open time
   const datetime u_time = QM_BrokerToUTC(b_time);
   MqlDateTime u_dt;
   TimeToStruct(u_time, u_dt);

   // Only trade within London morning breakout window [07:00, 12:00) UTC
   if(u_dt.hour < InpBoxEndHourUTC || u_dt.hour >= InpSessionEndHourUTC)
      return false;

   const double c1 = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed: closed bar close
   const double c2 = iClose(_Symbol, PERIOD_M15, 2); // perf-allowed: closed bar close
   if(c1 <= 0.0 || c2 <= 0.0) return false;

   const double buf = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(InpBufferPips * 10.0));
   const double sl_dist_fixed = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(InpStopLossPips * 10.0));
   const double tp_dist_fixed = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(InpTakeProfitPips * 10.0));

   // Bullish Breakout
   if(c1 > (g_cached_box_high + buf) && c2 <= (g_cached_box_high + buf))
   {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask <= 0.0) return false;

      double sl = ask - sl_dist_fixed;
      if(ask - sl < 0.5 * g_cached_atr_1) sl = ask - 0.5 * g_cached_atr_1;
      if(ask - sl > 3.5 * g_cached_atr_1) sl = ask - 3.5 * g_cached_atr_1;
      if(sl <= 0.0 || sl >= ask) return false;

      double tp = ask + tp_dist_fixed;
      if(tp <= ask) tp = ask + 2.0 * (ask - sl);

      req.type               = QM_BUY;
      req.price              = 0.0;
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason             = "EARLY_BIRD_LONDON_BUY";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_cached_traded        = true;
      return true;
   }

   // Bearish Breakout
   if(c1 < (g_cached_box_low - buf) && c2 >= (g_cached_box_low - buf))
   {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0) return false;

      double sl = bid + sl_dist_fixed;
      if(sl - bid < 0.5 * g_cached_atr_1) sl = bid + 0.5 * g_cached_atr_1;
      if(sl - bid > 3.5 * g_cached_atr_1) sl = bid + 3.5 * g_cached_atr_1;
      if(sl <= 0.0 || sl <= bid) return false;

      double tp = bid - tp_dist_fixed;
      if(tp >= bid) tp = bid - 2.0 * (sl - bid);

      req.type               = QM_SELL;
      req.price              = 0.0;
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason             = "EARLY_BIRD_LONDON_SELL";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_cached_traded        = true;
      return true;
   }

   return false;
}

void Strategy_ManageOpenPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      QM_TM_MoveToBreakEven(ticket, (int)MathRound(strategy_be_trigger_pips * 10.0), 10);
   }
}

bool Strategy_ExitSignal()
{
   const datetime u_time = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime u_dt;
   TimeToStruct(u_time, u_dt);

   // Daily cancel / exit at 12:00 UTC
   if(u_dt.hour >= InpSessionEndHourUTC)
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_39007_forexfactory-100-pips-early-bird-breakout\"}");
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
