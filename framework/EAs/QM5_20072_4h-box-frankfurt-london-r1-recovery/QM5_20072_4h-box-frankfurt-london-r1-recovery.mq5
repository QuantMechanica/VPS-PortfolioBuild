#property strict
#property version   "5.0"
#property description "QM5_20072 Frankfurt pre-London four-hour box breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20072;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// Card default is news-off for Q02; the two-axis hook remains callable for Q09.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_H1;
input int    strategy_box_start_hour_broker       = 3;
input int    strategy_box_end_hour_broker         = 7;
input int    strategy_pending_expiry_hour_broker  = 12;
input bool   strategy_eod_close_enabled           = true;
input int    strategy_eod_close_hour_broker       = 22;
input int    strategy_atr_period                  = 14;
input double strategy_min_box_atr_mult            = 0.5;
input double strategy_max_box_atr_mult            = 2.0;
input double strategy_take_profit_box_mult        = 1.5;
input int    strategy_sl_buffer_pips              = 1;
input int    strategy_max_spread_points           = 25;
input bool   strategy_trade_monday                = true;
input bool   strategy_trade_tuesday               = true;
input bool   strategy_trade_wednesday             = true;
input bool   strategy_trade_thursday              = true;
input bool   strategy_trade_friday                = false;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): keep exposure paths open so OCO
// cleanup and the 22:00 time exit continue regardless of entry-session state.
// The framework's two-axis news gate is applied later to new entries only.
bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   bool has_exposure = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
        {
         has_exposure = true;
         break;
        }
     }

   if(!has_exposure)
     {
      for(int i = OrdersTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = OrderGetTicket(i);
         if(ticket == 0 || !OrderSelect(ticket))
            continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)
            continue;
         if((int)OrderGetInteger(ORDER_MAGIC) == magic)
           {
            has_exposure = true;
            break;
           }
        }
     }

   if(has_exposure)
      return false;
   if(strategy_timeframe != PERIOD_H1)
      return true;

   MqlDateTime broker_dt;
   ZeroMemory(broker_dt);
   TimeToStruct(TimeCurrent(), broker_dt);

   bool day_allowed = false;
   if(broker_dt.day_of_week == 1)
      day_allowed = strategy_trade_monday;
   else if(broker_dt.day_of_week == 2)
      day_allowed = strategy_trade_tuesday;
   else if(broker_dt.day_of_week == 3)
      day_allowed = strategy_trade_wednesday;
   else if(broker_dt.day_of_week == 4)
      day_allowed = strategy_trade_thursday;
   else if(broker_dt.day_of_week == 5)
      day_allowed = strategy_trade_friday;

   if(!day_allowed || broker_dt.hour != strategy_box_end_hour_broker)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || ask < bid)
      return true;
   if(ask > bid && strategy_max_spread_points > 0 &&
      (ask - bid) > (double)strategy_max_spread_points * point)
      return true;

   return false;
  }

// Trade Entry: at the 07:00 H1 boundary, build the 03:00-07:00 box and
// submit the two expiry-bounded breakout stops. The framework sizes both
// requests from their absolute SL prices under the active risk mode.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_timeframe != PERIOD_H1)
      return false;
   if(strategy_box_start_hour_broker < 0 ||
      strategy_box_end_hour_broker > 23 ||
      strategy_pending_expiry_hour_broker > 23 ||
      strategy_eod_close_hour_broker > 23)
      return false;

   const int box_bars = strategy_box_end_hour_broker - strategy_box_start_hour_broker;
   if(box_bars != 4 ||
      strategy_pending_expiry_hour_broker <= strategy_box_end_hour_broker ||
      strategy_eod_close_hour_broker <= strategy_pending_expiry_hour_broker)
      return false;

   MqlRates current_bar;
   ZeroMemory(current_bar);
   if(!QM_ReadBar(_Symbol, strategy_timeframe, 0, current_bar))
      return false;

   MqlDateTime current_dt;
   ZeroMemory(current_dt);
   TimeToStruct(current_bar.time, current_dt);
   if(current_dt.hour != strategy_box_end_hour_broker || current_dt.min != 0)
      return false;

   bool day_allowed = false;
   if(current_dt.day_of_week == 1)
      day_allowed = strategy_trade_monday;
   else if(current_dt.day_of_week == 2)
      day_allowed = strategy_trade_tuesday;
   else if(current_dt.day_of_week == 3)
      day_allowed = strategy_trade_wednesday;
   else if(current_dt.day_of_week == 4)
      day_allowed = strategy_trade_thursday;
   else if(current_dt.day_of_week == 5)
      day_allowed = strategy_trade_friday;
   if(!day_allowed)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         (int)OrderGetInteger(ORDER_MAGIC) == magic)
         return false;
     }

   double box_high = -DBL_MAX;
   double box_low = DBL_MAX;
   for(int shift = 1; shift <= box_bars; ++shift)
     {
      MqlRates box_bar;
      ZeroMemory(box_bar);
      if(!QM_ReadBar(_Symbol, strategy_timeframe, shift, box_bar))
         return false;

      MqlDateTime box_dt;
      ZeroMemory(box_dt);
      TimeToStruct(box_bar.time, box_dt);
      const int expected_hour = strategy_box_end_hour_broker - shift;
      if(box_dt.year != current_dt.year ||
         box_dt.day_of_year != current_dt.day_of_year ||
         box_dt.hour != expected_hour ||
         box_dt.min != 0)
         return false;
      if(box_bar.high <= 0.0 || box_bar.low <= 0.0 || box_bar.high < box_bar.low)
         return false;

      box_high = MathMax(box_high, box_bar.high);
      box_low = MathMin(box_low, box_bar.low);
     }

   const double box_size = box_high - box_low;
   const double atr_d1 = QM_ATR(_Symbol,
                                PERIOD_D1,
                                MathMax(1, strategy_atr_period),
                                1);
   if(box_size <= 0.0 || atr_d1 <= 0.0)
      return false;
   if(strategy_min_box_atr_mult <= 0.0 ||
      strategy_max_box_atr_mult < strategy_min_box_atr_mult ||
      strategy_take_profit_box_mult <= 0.0 ||
      strategy_sl_buffer_pips < 0)
      return false;
   if(box_size < strategy_min_box_atr_mult * atr_d1 ||
      box_size > strategy_max_box_atr_mult * atr_d1)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || ask < bid)
      return false;

   double spread_price = 0.0;
   if(ask > bid)
      spread_price = ask - bid;
   if(strategy_max_spread_points > 0 &&
      spread_price > (double)strategy_max_spread_points * point)
      return false;

   const double stop_buffer =
      QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   if(stop_buffer < 0.0)
      return false;

   const double buy_entry =
      QM_StopRulesNormalizePrice(_Symbol, box_high + spread_price);
   const double sell_entry =
      QM_StopRulesNormalizePrice(_Symbol, box_low - spread_price);
   const double buy_sl =
      QM_StopRulesNormalizePrice(_Symbol, box_low - stop_buffer);
   const double sell_sl =
      QM_StopRulesNormalizePrice(_Symbol, box_high + stop_buffer);
   const double buy_tp =
      QM_StopRulesNormalizePrice(_Symbol,
                                 box_high + box_size * strategy_take_profit_box_mult);
   const double sell_tp =
      QM_StopRulesNormalizePrice(_Symbol,
                                 box_low - box_size * strategy_take_profit_box_mult);

   if(buy_entry <= ask || sell_entry >= bid)
      return false;
   if(buy_sl <= 0.0 || buy_sl >= buy_entry || buy_tp <= buy_entry)
      return false;
   if(sell_sl <= sell_entry || sell_tp <= 0.0 || sell_tp >= sell_entry)
      return false;

   MqlDateTime expiry_dt = current_dt;
   expiry_dt.hour = strategy_pending_expiry_hour_broker;
   expiry_dt.min = 0;
   expiry_dt.sec = 0;
   const datetime expiry_time = StructToTime(expiry_dt);
   const int expiration_seconds = (int)(expiry_time - TimeCurrent());
   if(expiration_seconds < 60)
      return false;

   QM_EntryRequest buy_req;
   ZeroMemory(buy_req);
   buy_req.type = QM_BUY_STOP;
   buy_req.price = buy_entry;
   buy_req.sl = buy_sl;
   buy_req.tp = buy_tp;
   buy_req.reason = "FRANKFURT_BOX_BUY_STOP";
   buy_req.symbol_slot = qm_magic_slot_offset;
   buy_req.expiration_seconds = expiration_seconds;

   req.type = QM_SELL_STOP;
   req.price = sell_entry;
   req.sl = sell_sl;
   req.tp = sell_tp;
   req.reason = "FRANKFURT_BOX_SELL_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;

   ulong buy_ticket = 0;
   if(!QM_TM_OpenPosition(buy_req, buy_ticket))
      return false;

   return true;
  }

// Trade Management: per-tick OCO cleanup only. A complete bracket has exactly
// two pending stop legs; after one fills (or one leg fails), remove the other.
// Any stale or post-12:00 pending leg is also removed explicitly.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
        {
         has_position = true;
         break;
        }
     }

   MqlDateTime now_dt;
   ZeroMemory(now_dt);
   TimeToStruct(TimeCurrent(), now_dt);

   int pending_count = 0;
   bool stale_pending = false;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_STOP &&
         order_type != ORDER_TYPE_SELL_STOP)
         continue;

      ++pending_count;
      const datetime setup_time =
         (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time > 0)
        {
         MqlDateTime setup_dt;
         ZeroMemory(setup_dt);
         TimeToStruct(setup_time, setup_dt);
         if(setup_dt.year != now_dt.year ||
            setup_dt.day_of_year != now_dt.day_of_year)
            stale_pending = true;
        }
     }

   if(pending_count == 0)
      return;

   const bool after_expiry =
      (now_dt.hour >= strategy_pending_expiry_hour_broker);
   const bool incomplete_bracket = (pending_count != 2);
   if(!has_position && !after_expiry && !stale_pending && !incomplete_bracket)
      return;

   string removal_reason = "FRANKFURT_BOX_PENDING_EXPIRY";
   if(has_position)
      removal_reason = "FRANKFURT_BOX_OCO_AFTER_FILL";
   else if(incomplete_bracket)
      removal_reason = "FRANKFURT_BOX_INCOMPLETE_BRACKET";
   else if(stale_pending)
      removal_reason = "FRANKFURT_BOX_STALE_PENDING";

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_STOP &&
         order_type != ORDER_TYPE_SELL_STOP)
         continue;
      QM_TM_RemovePendingOrder(ticket, removal_reason);
     }
  }

// Trade Close: SL/TP are server-side; this hook enforces the card's optional
// 22:00 broker-time end-of-day flattening rule.
bool Strategy_ExitSignal()
  {
   if(!strategy_eod_close_enabled)
      return false;

   MqlDateTime broker_dt;
   ZeroMemory(broker_dt);
   TimeToStruct(TimeCurrent(), broker_dt);
   if(broker_dt.hour < strategy_eod_close_hour_broker)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   return false;
  }

// News Filter Hook: callable by Q09/P8-compatible tooling. The card authorizes
// no custom event rule, so defer to the central two-axis framework gate.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   static bool broker_offset_logged = false;
   if(!broker_offset_logged)
     {
      const datetime server_now = TimeTradeServer();
      const datetime utc_now = QM_BrokerToUTC(server_now);
      QM_LogEvent(QM_INFO,
                  "STRATEGY_BROKER_OFFSET",
                  StringFormat("{\"offset_seconds\":%d}",
                               (int)(server_now - utc_now)));
      broker_offset_logged = true;
     }
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
