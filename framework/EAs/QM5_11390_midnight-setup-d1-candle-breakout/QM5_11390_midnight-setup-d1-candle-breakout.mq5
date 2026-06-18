#property strict
#property version   "5.0"
#property description "QM5_11390 Midnight Setup — D1 large-range candle breakout OCO straddle"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11390 midnight-setup-d1-candle-breakout
// -----------------------------------------------------------------------------
// Source: "Advanced System #1 — Midnight Setup", forex-strategies-revealed.com
// compilation. Card: artifacts/cards_approved/
//   QM5_11390_midnight-setup-d1-candle-breakout.md (g0_status APPROVED).
//
// Mechanics (pure price action, no indicators, D1-native):
//   "Midnight" = the new D1 bar boundary in BROKER time. It is taken from the
//   bar TIMESTAMP (QM_IsNewBar on the D1 chart fires once at the daily
//   rollover; iTime(_Symbol, PERIOD_D1, 0) is that boundary) — NEVER a fixed
//   wall-clock constant. The breakout-pending placement is the single EVENT.
//
//   On each new D1 bar, look at the PRIOR CLOSED D1 candle (shift 1):
//     Range filter : (High[1] - Low[1]) / pip >= MIN_RANGE_PIPS.
//     BUY STOP  at  High[1] + OFFSET_PIPS * pip.
//     SELL STOP at  Low[1]  - OFFSET_PIPS * pip.
//   Both pendings expire at the end of the current daily bar (next midnight).
//   Whichever fills first is the trade; the unfilled peer is cancelled (OCO).
//     SL : SL_PIPS from entry.   TP : TP_PIPS from entry.   One position/magic.
//
// .DWX invariants honoured: spread guard fails OPEN on zero modeled spread;
// no swap gate; day boundary derived from broker-time bar timestamp; prior
// CLOSED-bar High/Low (not gap math); pip-correct distances via QM_*FixedPips.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11390;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact         = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_min_range_pips    = 90;   // skip days whose prior D1 range < this
input int    strategy_offset_pips       = 5;    // stop-entry offset beyond prior H/L
input int    strategy_sl_pips           = 50;   // fixed stop-loss distance from entry
input int    strategy_tp_pips           = 100;  // fixed take-profit distance from entry
input double strategy_spread_pct_of_sl  = 30.0; // skip if spread > this % of SL distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Pip size in price units (5/3-digit FX => 10 * point), matching the framework
// pip convention used by QM_StopRulesPipsToPriceDistance.
double Strategy_PipSize()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return (digits == 3 || digits == 5) ? 10.0 * point : point;
  }

bool Strategy_IsPendingStopType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

// Open position for this EA's magic on this symbol?
bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

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

// Any live pending stop for this EA's magic on this symbol?
bool Strategy_HasPendingStops()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

// Already placed/traded for this EA's magic within the CURRENT daily bar?
// Prevents re-straddling the same day on subsequent new-bar ticks or after the
// pendings expire / fill. day_open is the current D1 bar timestamp (the
// broker-time midnight boundary).
bool Strategy_HasCurrentDayActivity(const datetime day_open)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || day_open <= 0)
      return false;
   if(!HistorySelect(day_open, TimeCurrent()))
      return false;

   const int orders = HistoryOrdersTotal();
   for(int i = orders - 1; i >= 0; --i)
     {
      const ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryOrderGetString(ticket, ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryOrderGetInteger(ticket, ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE);
      if(Strategy_IsPendingStopType(type) || type == ORDER_TYPE_BUY || type == ORDER_TYPE_SELL)
         return true;
     }

   const int deals = HistoryDealsTotal();
   for(int i = deals - 1; i >= 0; --i)
     {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_DeleteOrderByTicket(const ulong ticket, const string reason)
  {
   MqlTradeRequest request;
   ZeroMemory(request);
   request.action = TRADE_ACTION_REMOVE;
   request.order = ticket;
   request.symbol = _Symbol;
   request.comment = reason;

   MqlTradeResult result;
   string error_class = BROKER_OTHER;
   const bool ok = QM_TradeContextSend(request, result, error_class);
   QM_LogEvent(ok ? QM_INFO : QM_WARN,
               "PENDING_CANCEL",
               StringFormat("{\"ticket\":%I64u,\"reason\":\"%s\",\"ok\":%s,\"retcode\":%u,\"retcode_class\":\"%s\"}",
                            ticket,
                            QM_LoggerEscapeJson(reason),
                            ok ? "true" : "false",
                            result.retcode,
                            QM_LoggerEscapeJson(error_class)));
   return ok;
  }

void Strategy_CancelPendingStops(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!Strategy_IsPendingStopType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      Strategy_DeleteOrderByTicket(ticket, reason);
     }
  }

// Seconds remaining until the end of the current daily bar (the next broker-time
// midnight boundary). Derived from the bar timestamp, not a wall-clock constant.
int Strategy_SecondsToNextDayBoundary(const datetime broker_now)
  {
   const datetime day_open = iTime(_Symbol, PERIOD_D1, 0);
   if(day_open <= 0)
      return 0;
   const datetime next_open = day_open + 86400; // end of current D1 bar
   if(next_open <= broker_now)
      return 0;
   return (int)(next_open - broker_now);
  }

// Build one BUY_STOP / SELL_STOP request with fixed pip SL/TP.
bool Strategy_BuildStopRequest(const QM_OrderType type,
                               const double price,
                               const int expiration_seconds,
                               const string reason,
                               QM_EntryRequest &req)
  {
   req.type = type;
   req.price = NormalizeDouble(price, _Digits);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;
   req.reason = reason;

   if(req.price <= 0.0)
      return false;

   req.sl = QM_StopFixedPips(_Symbol, type, req.price, strategy_sl_pips);
   req.tp = QM_TakeFixedPips(_Symbol, type, req.price, strategy_tp_pips);
   req.sl = NormalizeDouble(req.sl, _Digits);
   req.tp = NormalizeDouble(req.tp, _Digits);
   return (req.sl > 0.0 && req.tp > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): cheap O(1) per-tick spread guard.
// Fail-OPEN on .DWX zero modeled spread; only a genuinely wide spread blocks.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double sl_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(sl_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_sl / 100.0) * sl_distance)
      return true;

   return false;
  }

// Trade Entry: on each new D1 bar, place the prior-candle OCO straddle if the
// prior D1 range cleared the threshold. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   const datetime day_open = iTime(_Symbol, PERIOD_D1, 0); // current D1 boundary
   if(day_open <= 0)
      return false;

   // One straddle per day; never while a position or pendings are already live.
   if(Strategy_HasOpenPosition() || Strategy_HasPendingStops() ||
      Strategy_HasCurrentDayActivity(day_open))
      return false;

   // Prior CLOSED daily candle (shift 1) — perf-allowed single closed-bar reads.
   const double prev_high = iHigh(_Symbol, PERIOD_D1, 1);
   const double prev_low  = iLow(_Symbol, PERIOD_D1, 1);
   const double pip = Strategy_PipSize();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(prev_high <= 0.0 || prev_low <= 0.0 || prev_high <= prev_low ||
      pip <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   // Range filter on the prior closed candle.
   const double range_pips = (prev_high - prev_low) / pip;
   if(range_pips < (double)strategy_min_range_pips)
      return false;

   const double buy_stop  = prev_high + strategy_offset_pips * pip;
   const double sell_stop = prev_low  - strategy_offset_pips * pip;
   // Stop entries must sit beyond the current market or the broker rejects them.
   if(buy_stop <= ask + point || sell_stop >= bid - point)
      return false;

   const int expiry_seconds = Strategy_SecondsToNextDayBoundary(broker_now);
   if(expiry_seconds <= 0)
      return false;

   // Place the BUY_STOP directly; return the SELL_STOP for the framework auto-send.
   QM_EntryRequest buy_req;
   if(!Strategy_BuildStopRequest(QM_BUY_STOP, buy_stop, expiry_seconds, "midnight_buy_stop", buy_req))
      return false;
   if(!Strategy_BuildStopRequest(QM_SELL_STOP, sell_stop, expiry_seconds, "midnight_sell_stop", req))
      return false;

   ulong buy_ticket = 0;
   QM_TM_OpenPosition(buy_req, buy_ticket);
   return true; // framework sends the SELL_STOP `req`
  }

// Trade Management: OCO — once one side fills, cancel the unfilled peer.
void Strategy_ManageOpenPosition()
  {
   if(Strategy_HasOpenPosition())
      Strategy_CancelPendingStops("oco_peer_cancel");
  }

// Trade Close: exits are handled by the fixed SL/TP attached to the order.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: defer to the central framework filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11390\",\"ea\":\"midnight-setup-d1-candle-breakout\"}");
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
