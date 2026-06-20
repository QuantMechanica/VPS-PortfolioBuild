#property strict
#property version   "5.0"
#property description "QM5_11528 ciurea-inv-hammer-shooting-star-m30"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11528 ciurea-inv-hammer-shooting-star-m30
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_11528_ciurea-inv-hammer-shooting-star-m30.md
// Source: 0192e348-5570-531c-9110-7954a36caca2
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11528;
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
input double strategy_min_body_pips     = 3.0;
input double strategy_upper_shadow_ratio = 2.0;
input double strategy_lower_shadow_ratio = 0.5;
input int    strategy_sl_struct_bars    = 3;
input double strategy_sl_buffer_pips    = 3.0;
input double strategy_sl_cap_pips       = 30.0;
input double strategy_rr_multiple       = 2.0;
input double strategy_spread_cap_pips   = 12.0;
input bool   strategy_no_friday_entry   = true;

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): spread only here. Friday entry is checked
// in Strategy_EntrySignal so exits and framework Friday close remain available.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(pip <= 0.0)
      return false;

   const double spread = ask - bid;
   const double cap = strategy_spread_cap_pips * pip;
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Trade Entry: closed-bar upper-shadow candle. Caller guarantees QM_IsNewBar().
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   const double o1 = iOpen(_Symbol, _Period, 1);   // perf-allowed: fixed closed-bar OHLC for bespoke candle pattern; no QM_Open reader exists.
   const double h1 = iHigh(_Symbol, _Period, 1);   // perf-allowed: fixed closed-bar OHLC for bespoke candle pattern; no QM_High reader exists.
   const double l1 = iLow(_Symbol, _Period, 1);    // perf-allowed: fixed closed-bar OHLC for bespoke candle pattern; no QM_Low reader exists.
   const double c1 = iClose(_Symbol, _Period, 1);  // perf-allowed: fixed closed-bar OHLC for bespoke candle pattern; no QM_Close reader exists.
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0)
      return false;

   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(pip <= 0.0)
      return false;

   const double body = MathAbs(c1 - o1);
   const double upper_shadow = h1 - MathMax(o1, c1);
   const double lower_shadow = MathMin(o1, c1) - l1;

   if(body <= strategy_min_body_pips * pip)
      return false;
   if(upper_shadow < strategy_upper_shadow_ratio * body)
      return false;
   if(lower_shadow > strategy_lower_shadow_ratio * body)
      return false;

   bool go_long = false;
   bool go_short = false;
   if(c1 >= o1)
      go_long = true;
   else
      go_short = true;

   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;
   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   double sl = QM_StopStructure(_Symbol, side, entry, strategy_sl_struct_bars);
   if(sl <= 0.0)
      return false;

   const double buffer = strategy_sl_buffer_pips * pip;
   if(go_long)
      sl -= buffer;
   else
      sl += buffer;

   const double sl_cap = strategy_sl_cap_pips * pip;
   const double raw_sl_distance = MathAbs(entry - sl);
   if(raw_sl_distance <= 0.0)
      return false;
   if(sl_cap > 0.0 && raw_sl_distance > sl_cap)
      sl = go_long ? (entry - sl_cap) : (entry + sl_cap);

   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_rr_multiple);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = go_long ? "ciurea_inv_hammer_long" : "ciurea_shooting_star_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management: card specifies fixed SL/TP only.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close: no discretionary exit beyond SL, TP, and framework Friday close.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: defer to the central two-axis news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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
