#property strict
#property version   "5.0"
#property description "QM5_10384 Elite Trader pivot limit offset"

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
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 10384;
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
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
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
input int    strategy_range_ema_length      = 3;
input double strategy_offset_mult           = 0.50;
input int    strategy_atr_period            = 20;
input double strategy_atr_sl_mult           = 1.00;
input int    strategy_pending_expiry_bars   = 1;
input int    strategy_min_stop_spread_mult  = 4;
input int    strategy_session_edge_minutes  = 15;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

double Strategy_SpreadPrice()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
      return ask - bid;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(point <= 0.0 || spread_points <= 0)
      return 0.0;
   return (double)spread_points * point;
  }

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

bool Strategy_IsOurPendingLimitType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT);
  }

bool Strategy_HasPendingLimits()
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
      if(Strategy_IsOurPendingLimitType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
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

void Strategy_CancelPendingLimits(const string reason)
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
      if(!Strategy_IsOurPendingLimitType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      Strategy_DeleteOrderByTicket(ticket, reason);
     }
  }

bool Strategy_IsNearSessionEdge(const datetime broker_time)
  {
   const int edge_seconds = MathMax(0, strategy_session_edge_minutes) * 60;
   if(edge_seconds <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const ENUM_DAY_OF_WEEK day = (ENUM_DAY_OF_WEEK)dt.day_of_week;
   const int seconds_today = dt.hour * 3600 + dt.min * 60 + dt.sec;

   datetime from_time = 0;
   datetime to_time = 0;
   for(uint session = 0; session < 16; ++session)
     {
      if(!SymbolInfoSessionTrade(_Symbol, day, session, from_time, to_time))
         break;

      MqlDateTime from_dt;
      MqlDateTime to_dt;
      TimeToStruct(from_time, from_dt);
      TimeToStruct(to_time, to_dt);
      const int from_seconds = from_dt.hour * 3600 + from_dt.min * 60 + from_dt.sec;
      int to_seconds = to_dt.hour * 3600 + to_dt.min * 60 + to_dt.sec;
      if(to_seconds <= from_seconds)
         to_seconds += 24 * 3600;

      int current_seconds = seconds_today;
      if(current_seconds < from_seconds && to_seconds >= 24 * 3600)
         current_seconds += 24 * 3600;

      if(current_seconds >= from_seconds && current_seconds < to_seconds)
        {
         if(current_seconds - from_seconds < edge_seconds)
            return true;
         if(to_seconds - current_seconds <= edge_seconds)
            return true;
        }
     }
   return false;
  }

double Strategy_EMARange(const int period, const int shift)
  {
   const int p = MathMax(1, period);
   const int samples = MathMax(p * 8, p + 2);
   const double alpha = 2.0 / ((double)p + 1.0);
   double ema = 0.0;
   bool seeded = false;

   for(int s = shift + samples - 1; s >= shift; --s)
     {
      const double high = iHigh(_Symbol, _Period, s);
      const double low = iLow(_Symbol, _Period, s);
      if(high <= 0.0 || low <= 0.0 || high <= low)
         continue;

      const double range = high - low;
      if(!seeded)
        {
         ema = range;
         seeded = true;
        }
      else
         ema = alpha * range + (1.0 - alpha) * ema;
     }

   return seeded ? ema : 0.0;
  }

bool Strategy_LevelsFromShift(const int shift, double &long_limit, double &short_limit)
  {
   long_limit = 0.0;
   short_limit = 0.0;

   const double close_bar = iClose(_Symbol, _Period, shift);
   const double high_bar = iHigh(_Symbol, _Period, shift);
   const double low_bar = iLow(_Symbol, _Period, shift);
   const double offset = Strategy_EMARange(strategy_range_ema_length, shift) * strategy_offset_mult;
   if(close_bar <= 0.0 || high_bar <= 0.0 || low_bar <= 0.0 || high_bar <= low_bar || offset <= 0.0)
      return false;

   const double typical = (close_bar + high_bar + low_bar) / 3.0;
   long_limit = NormalizeDouble(typical - offset, _Digits);
   short_limit = NormalizeDouble(typical + offset, _Digits);
   return (long_limit > 0.0 && short_limit > long_limit);
  }

bool Strategy_LastBarWasAmbiguous()
  {
   double long_limit = 0.0;
   double short_limit = 0.0;
   if(!Strategy_LevelsFromShift(2, long_limit, short_limit))
      return false;

   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   if(high1 <= 0.0 || low1 <= 0.0)
      return false;
   return (low1 <= long_limit && high1 >= short_limit);
  }

bool Strategy_BuildLimitRequest(const QM_OrderType type,
                                const double price,
                                const double atr_value,
                                const int expiration_seconds,
                                const string reason,
                                QM_EntryRequest &req)
  {
   req.type = type;
   req.price = NormalizeDouble(price, _Digits);
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;
   req.sl = QM_StopATRFromValue(_Symbol, type, req.price, atr_value, strategy_atr_sl_mult);
   req.sl = NormalizeDouble(req.sl, _Digits);
   return (req.price > 0.0 && req.sl > 0.0);
  }

// No Trade Filter (time, spread, news): central news runs before this hook.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_IsNearSessionEdge(TimeCurrent()))
      return true;
   return (Strategy_SpreadPrice() <= 0.0);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   Strategy_CancelPendingLimits("new_bar_reprice");

   if(Strategy_LastBarWasAmbiguous())
      return false;

   double long_limit = 0.0;
   double short_limit = 0.0;
   if(!Strategy_LevelsFromShift(1, long_limit, short_limit))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double spread = Strategy_SpreadPrice();
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || spread <= 0.0 || atr <= 0.0)
      return false;

   const double stop_distance = atr * strategy_atr_sl_mult;
   if(stop_distance < (double)MathMax(1, strategy_min_stop_spread_mult) * spread)
      return false;

   if(long_limit >= bid - point || short_limit <= ask + point)
      return false;

   const int seconds_per_bar = PeriodSeconds(_Period);
   const int expiry_seconds = MathMax(seconds_per_bar, strategy_pending_expiry_bars * seconds_per_bar);

   QM_EntryRequest buy_req;
   if(!Strategy_BuildLimitRequest(QM_BUY_LIMIT, long_limit, atr, expiry_seconds, "ET_PIVOT_LIMIT_BUY", buy_req))
      return false;
   if(!Strategy_BuildLimitRequest(QM_SELL_LIMIT, short_limit, atr, expiry_seconds, "ET_PIVOT_LIMIT_SELL", req))
      return false;

   ulong buy_ticket = 0;
   return QM_TM_OpenPosition(buy_req, buy_ticket);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(Strategy_HasOpenPosition() && Strategy_HasPendingLimits())
      Strategy_CancelPendingLimits("oco_peer_cancel");
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int seconds_per_bar = PeriodSeconds(_Period);
   const datetime now_time = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(seconds_per_bar > 0 && now_time >= open_time + seconds_per_bar)
         return true;
      if(Strategy_IsNearSessionEdge(now_time))
         return true;
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
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
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
