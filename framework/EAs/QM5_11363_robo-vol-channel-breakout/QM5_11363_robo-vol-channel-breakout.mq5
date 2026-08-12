#property strict
#property version   "5.0"
#property description "QM5_11363 robo-vol-channel-breakout — RoboForex Dual ATR Volatility Channel Breakout (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11363 robo-vol-channel-breakout
// -----------------------------------------------------------------------------
// Source: RoboForex Forex Trading Strategies Collection, "Volatility channel breakout strategy" (page 42).
// Card: artifacts/cards_approved/QM5_11363_robo-vol-channel-breakout.md (APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M15):
//   - Wide channel: EMA(5) + ATR(30)
//   - Tight channel: EMA(4) + ATR(14)
//   - LONG breakout: Close[1] > EMA(5)[1] + ATR(30)[1] AND Close[1] > EMA(4)[1] + ATR(14)[1]
//   - SHORT breakout: Close[1] < EMA(5)[1] - ATR(30)[1] AND Close[1] < EMA(4)[1] - ATR(14)[1]
//   - Entry: next bar open (Open[0])
//   - TP: volatility-scaled: entry +/- 2.0 * ATR(14)[1]
//   - SL: EMA(5)[1], or entry +/- ATR(30)[1] if EMA(5) is too close. Max 20 pips.
//   - Volatility filter: Only trade when ATR(14)[1] > 5 pips.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11363;
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
input int    strategy_ema_wide           = 5;       // Wide channel EMA period
input int    strategy_atr_wide           = 30;      // Wide channel ATR period
input int    strategy_ema_tight          = 4;       // Tight channel EMA period
input int    strategy_atr_tight          = 14;      // Tight channel ATR period
input double strategy_tp_multiplier      = 2.0;     // TP = entry +/- multiplier * ATR_tight
input int    strategy_sl_max_pips        = 20;      // max stop-loss (pips)
input double strategy_spread_cap_pips    = 15.0;    // spread cap (pips)
input int    strategy_min_vol_pips       = 5;       // minimum volatility filter (pips)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false;

   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap_distance <= 0.0)
      return false;

   if(spread > cap_distance)
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   MqlRates bar1;
   if(!QM_ReadBar(_Symbol, _Period, 1, bar1))
      return false;

   // Calculate ATRs and EMAs at shift 1
   const double atr14 = QM_ATR(_Symbol, _Period, strategy_atr_tight, 1);
   const double atr30 = QM_ATR(_Symbol, _Period, strategy_atr_wide, 1);
   const double ema4  = QM_EMA(_Symbol, _Period, strategy_ema_tight, 1);
   const double ema5  = QM_EMA(_Symbol, _Period, strategy_ema_wide, 1);

   if(atr14 <= 0.0 || atr30 <= 0.0 || ema4 <= 0.0 || ema5 <= 0.0)
      return false;

   // Minimum volatility filter: ATR(14) > 5 pips
   const double min_vol = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_min_vol_pips);
   if(atr14 < min_vol)
      return false;

   const double max_sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);

   QM_OrderType side;
   double sl_price = 0.0;
   double tp_price = 0.0;

   // Check LONG breakout
   const bool long_wide  = (bar1.close > (ema5 + atr30));
   const bool long_tight = (bar1.close > (ema4 + atr14));

   // Check SHORT breakout
   const bool short_wide  = (bar1.close < (ema5 - atr30));
   const bool short_tight = (bar1.close < (ema4 - atr14));

   if(long_wide && long_tight)
   {
      side = QM_BUY;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0) return false;

      tp_price = entry + strategy_tp_multiplier * atr14;
      sl_price = ema5;
      if((entry - ema5) < atr30)
         sl_price = entry - atr30;

      if((entry - sl_price) > max_sl_dist)
         sl_price = entry - max_sl_dist;
   }
   else if(short_wide && short_tight)
   {
      side = QM_SELL;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0) return false;

      tp_price = entry - strategy_tp_multiplier * atr14;
      sl_price = ema5;
      if((ema5 - entry) < atr30)
         sl_price = entry + atr30;

      if((sl_price - entry) > max_sl_dist)
         sl_price = entry + max_sl_dist;
   }
   else
   {
      return false;
   }

   req.type   = side;
   req.price  = 0.0;
   req.sl     = sl_price;
   req.tp     = tp_price;
   req.reason = (side == QM_BUY) ? "robo_vol_long" : "robo_vol_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
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
