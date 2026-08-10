#property strict
#property version   "5.0"
#property description "QM5_11362 robo-one-two-bb-reversal — RoboForex BB(20,2) reversal + 2-candle confirmation (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11362 robo-one-two-bb-reversal
// -----------------------------------------------------------------------------
// Source: RoboForex Strategy Collection, "Strategy One-Two" (pages 28-29).
// Card: artifacts/cards_approved/QM5_11362_robo-one-two-bb-reversal.md (APPROVED).
//
// Mechanics (closed-bar reads at shift 1, 2, 3; M15):
//   - BB Zone check LONG: bb_lower[1] < Close[1] < bb_mid[1]
//   - BB Zone check SHORT: bb_mid[1] < Close[1] < bb_upper[1]
//   - 2-candle confirmation LONG: Close[1] < Close[2] && Close[2] < Close[3]
//                                AND Close[1] < Open[1] && Close[2] < Open[2] (bearish candles)
//   - 2-candle confirmation SHORT: Close[1] > Close[2] && Close[2] > Close[3]
//                                 AND Close[1] > Open[1] && Close[2] > Open[2] (bullish candles)
//   - Entry: next bar open (Open[0])
//   - SL: LONG: Low[1] - 5 pips, SHORT: High[1] + 5 pips. Max 20 pips.
//         Skip entry if bar[1] range > 15 pips.
//   - TP: Dynamic exit at BB middle band.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11362;
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
input int    strategy_bb_period          = 20;    // Bollinger period
input double strategy_bb_deviation       = 2.0;   // Bollinger deviation
input int    strategy_sl_pips            = 20;    // maximum stop-loss (pips)
input int    strategy_sl_offset_pips     = 5;     // offset from bar[1] (pips)
input int    strategy_max_signal_range_pips = 15; // skip if bar[1] range > this (pips)
input double strategy_spread_cap_pips    = 5.0;   // spread cap (pips)

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

   MqlRates bar1, bar2, bar3;
   if(!QM_ReadBar(_Symbol, _Period, 1, bar1) ||
      !QM_ReadBar(_Symbol, _Period, 2, bar2) ||
      !QM_ReadBar(_Symbol, _Period, 3, bar3))
      return false;

   // Bollinger Bands at shift 1
   const double bb_low1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_mid1 = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_high1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(bb_low1 <= 0.0 || bb_mid1 <= 0.0 || bb_high1 <= 0.0)
      return false;

   // Check skip condition: bar[1] range > 15 pips
   const double max_range_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_signal_range_pips);
   if(max_range_dist > 0.0 && (bar1.high - bar1.low) > max_range_dist)
      return false;

   const double entry_sl_offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_offset_pips);
   const double entry_max_sl = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);

   QM_OrderType side;
   double sl_price = 0.0;

   // LONG check
   const bool price_in_lower_zone = (bar1.close > bb_low1 && bar1.close < bb_mid1);
   const bool long_pattern = (bar1.close < bar2.close && bar2.close < bar3.close) &&
                             (bar1.close < bar1.open && bar2.close < bar2.open);

   // SHORT check
   const bool price_in_upper_zone = (bar1.close > bb_mid1 && bar1.close < bb_high1);
   const bool short_pattern = (bar1.close > bar2.close && bar2.close > bar3.close) &&
                              (bar1.close > bar1.open && bar2.close > bar2.open);

   if(price_in_lower_zone && long_pattern)
   {
      side = QM_BUY;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0) return false;
      sl_price = bar1.low - entry_sl_offset;
      if(entry - sl_price > entry_max_sl)
         sl_price = entry - entry_max_sl;
   }
   else if(price_in_upper_zone && short_pattern)
   {
      side = QM_SELL;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0) return false;
      sl_price = bar1.high + entry_sl_offset;
      if(sl_price - entry > entry_max_sl)
         sl_price = entry + entry_max_sl;
   }
   else
   {
      return false;
   }

   req.type   = side;
   req.price  = 0.0;
   req.sl     = sl_price;
   req.tp     = 0.0; // dynamic exit via Strategy_ExitSignal
   req.reason = (side == QM_BUY) ? "robo_one_two_long" : "robo_one_two_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double bb_mid = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
      if(bb_mid <= 0.0) continue;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(bid <= 0.0 || ask <= 0.0) continue;

      if(pos_type == POSITION_TYPE_BUY)
      {
         if(bid >= bb_mid)
            return true;
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         if(ask <= bb_mid)
            return true;
      }
   }
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
