#property strict
#property version   "5.0"
#property description "QM5_41222 Double Bollinger Band trend zone — Q09 REQUAL-8"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_41222 lien-k-double-bb-trend-h1-requal8
// -----------------------------------------------------------------------------
// New-identity requalification port of
// QM5_11476_lien-k-double-bb-trend-h1 under
// OWNER-DEC-Q09HOLD-REQUAL-8-20260829. Strategy mechanics are unchanged:
// a completed H1 close transitioning into the 1SD-to-2SD Bollinger trend zone
// enters with an optional middle-band slope filter; a neutral-channel close
// exits. The opposite inner band supplies a stop, capped at 60 pips, with a
// 40-pip fallback when the band stop is invalid.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 41222;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;
input double qm_risk_cap_pct             = 1.0;

input group "News"
input QM_NewsTemporalMode       qm_news_temporal        = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int                       qm_news_stale_max_hours = 336;
input string                    qm_news_min_impact      = "high";
input QM_NewsMode               qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_bb_period          = 20;
input double strategy_bb_dev_inner       = 1.0;
input double strategy_bb_dev_outer       = 2.0;
input bool   strategy_use_slope_filter   = true;
input int    strategy_slope_bars         = 5;
input double strategy_sl_fixed_pips      = 40.0;
input double strategy_sl_cap_pips        = 60.0;
input double strategy_spread_cap_pips    = 20.0;
input bool   strategy_no_friday_entry    = true;
input int    strategy_direction_mode     = 0;
input int    strategy_min_exit_bars      = 0;

// -----------------------------------------------------------------------------
// No Trade Filter
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   const double spread_cap =
      QM_StopRulesPipsToPriceDistance(_Symbol,
                                      (int)strategy_spread_cap_pips);
   return (spread > 0.0 && spread_cap > 0.0 && spread > spread_cap);
  }

// -----------------------------------------------------------------------------
// Trade Entry
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_bb_period < 2 ||
      strategy_bb_dev_inner <= 0.0 ||
      strategy_bb_dev_outer <= strategy_bb_dev_inner ||
      strategy_slope_bars < 1 ||
      strategy_sl_fixed_pips <= 0.0 ||
      strategy_sl_cap_pips <= 0.0 ||
      strategy_spread_cap_pips < 0.0 ||
      strategy_direction_mode < -1 || strategy_direction_mode > 1 ||
      strategy_min_exit_bars < 0)
      return false;

   // The approved card prohibits Friday entries; framework management and
   // exits remain active before this entry-only check.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   MqlRates bar1;
   MqlRates bar2;
   ZeroMemory(bar1);
   ZeroMemory(bar2);
   if(!QM_ReadBar(_Symbol, PERIOD_H1, 1, bar1) ||
      !QM_ReadBar(_Symbol, PERIOD_H1, 2, bar2))
      return false;
   if(bar1.close <= 0.0 || bar2.close <= 0.0)
      return false;

   const double bb1_up_1 =
      QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period,
                  strategy_bb_dev_inner, 1);
   const double bb1_lo_1 =
      QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period,
                  strategy_bb_dev_inner, 1);
   const double bb2_up_1 =
      QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period,
                  strategy_bb_dev_outer, 1);
   const double bb2_lo_1 =
      QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period,
                  strategy_bb_dev_outer, 1);
   const double bb1_up_2 =
      QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period,
                  strategy_bb_dev_inner, 2);
   const double bb1_lo_2 =
      QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period,
                  strategy_bb_dev_inner, 2);
   const double bb2_up_2 =
      QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period,
                  strategy_bb_dev_outer, 2);
   const double bb2_lo_2 =
      QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period,
                  strategy_bb_dev_outer, 2);

   if(bb1_up_1 <= 0.0 || bb1_lo_1 <= 0.0 ||
      bb2_up_1 <= 0.0 || bb2_lo_1 <= 0.0 ||
      bb1_up_2 <= 0.0 || bb1_lo_2 <= 0.0 ||
      bb2_up_2 <= 0.0 || bb2_lo_2 <= 0.0)
      return false;

   const bool buy_zone_1 =
      (bar1.close >= bb1_up_1 && bar1.close <= bb2_up_1);
   const bool buy_zone_2 =
      (bar2.close >= bb1_up_2 && bar2.close <= bb2_up_2);
   const bool sell_zone_1 =
      (bar1.close <= bb1_lo_1 && bar1.close >= bb2_lo_1);
   const bool sell_zone_2 =
      (bar2.close <= bb1_lo_2 && bar2.close >= bb2_lo_2);

   const bool enter_long = (buy_zone_1 && !buy_zone_2);
   const bool enter_short = (sell_zone_1 && !sell_zone_2);
   if(!enter_long && !enter_short)
      return false;
   if(strategy_direction_mode > 0 && enter_short)
      return false;
   if(strategy_direction_mode < 0 && enter_long)
      return false;

   if(strategy_use_slope_filter)
     {
      const double mid_now =
         QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period,
                      strategy_bb_dev_inner, 1);
      const double mid_prev =
         QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period,
                      strategy_bb_dev_inner, 1 + strategy_slope_bars);
      if(mid_now <= 0.0 || mid_prev <= 0.0)
         return false;
      if(enter_long && !(mid_now > mid_prev))
         return false;
      if(enter_short && !(mid_now < mid_prev))
         return false;
     }

   if(enter_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      double sl = bb1_lo_1;
      const double sl_dist = entry - sl;
      const double cap_dist =
         QM_StopRulesPipsToPriceDistance(_Symbol,
                                         (int)strategy_sl_cap_pips);
      if(sl <= 0.0 || sl_dist <= 0.0)
         sl = QM_StopFixedPips(_Symbol, QM_BUY, entry,
                               (int)strategy_sl_fixed_pips);
      else if(cap_dist > 0.0 && sl_dist > cap_dist)
         return false;
      if(sl <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp = 0.0;
      req.reason = "double_bb_buy_zone";
      return true;
     }

   const double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      return false;

   double sl_s = bb1_up_1;
   const double sl_dist_s = sl_s - entry_s;
   const double cap_dist_s =
      QM_StopRulesPipsToPriceDistance(_Symbol,
                                      (int)strategy_sl_cap_pips);
   if(sl_s <= 0.0 || sl_dist_s <= 0.0)
      sl_s = QM_StopFixedPips(_Symbol, QM_SELL, entry_s,
                              (int)strategy_sl_fixed_pips);
   else if(cap_dist_s > 0.0 && sl_dist_s > cap_dist_s)
      return false;
   if(sl_s <= 0.0)
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl_s);
   req.tp = 0.0;
   req.reason = "double_bb_sell_zone";
   return true;
  }

// -----------------------------------------------------------------------------
// Trade Management
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
  }

// -----------------------------------------------------------------------------
// Trade Close
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double bb1_up_1 =
      QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period,
                  strategy_bb_dev_inner, 1);
   const double bb1_lo_1 =
      QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period,
                  strategy_bb_dev_inner, 1);
   if(bb1_up_1 <= 0.0 || bb1_lo_1 <= 0.0)
      return false;

   MqlRates bar1;
   ZeroMemory(bar1);
   if(!QM_ReadBar(_Symbol, PERIOD_H1, 1, bar1) || bar1.close <= 0.0)
      return false;

   bool is_long = false;
   bool is_short = false;
   datetime opened_at = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         is_long = true;
      if(ptype == POSITION_TYPE_SELL)
         is_short = true;
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }

   if(strategy_min_exit_bars > 0 && opened_at > 0)
     {
      const int period_seconds = PeriodSeconds(PERIOD_H1);
      if(period_seconds > 0 &&
         (TimeCurrent() - opened_at) <
         strategy_min_exit_bars * period_seconds)
         return false;
     }

   if(is_long && bar1.close < bb1_up_1)
      return true;
   if(is_short && bar1.close > bb1_lo_1)
      return true;
   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Current V5 framework wiring
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

   if(!QM_FrameworkSetRiskCapPct(qm_risk_cap_pct))
      return INIT_FAILED;

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_H1,
         QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
         "DXZ_LEGACY_BOOK_POLICY_REQUAL_REQUIRED"))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT",
               StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: no guard may skip open-position MAE sampling.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Mandatory news blackout gates new entries only. Management and exits
   // above remain reachable throughout restricted windows.
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar(_Symbol, PERIOD_H1))
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

