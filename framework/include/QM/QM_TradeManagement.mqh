#ifndef QM_TRADEMANAGEMENT_MQH
#define QM_TRADEMANAGEMENT_MQH

#include "QM_OrderTypes.mqh"
#include "QM_StopRules.mqh"
#include "QM_TradeContext.mqh"
#include "QM_Logger.mqh"
#include "QM_Entry.mqh"
#include "QM_Exit.mqh"

#define QM_TM_DEFAULT_DEVIATION_POINTS 20

bool QM_TM_SelectPosition(const ulong ticket)
  {
   if(ticket == 0)
      return false;
   return PositionSelectByTicket(ticket);
  }

double QM_TM_NormalizeVolume(const string symbol, const double requested)
  {
   if(requested <= 0.0)
      return 0.0;

   const double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(min_lot <= 0.0 || max_lot <= 0.0 || step <= 0.0)
      return 0.0;

   double capped = requested;
   if(capped > max_lot)
      capped = max_lot;

   const double steps = MathFloor((capped + 1e-12) / step);
   double normalized = NormalizeDouble(steps * step, 8);
   if(normalized < min_lot)
      return 0.0;
   if(normalized > max_lot)
      normalized = max_lot;
   return normalized;
  }

double QM_TM_NormalizePrice(const string symbol, const double price)
  {
   if(price <= 0.0)
      return 0.0;

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
  }

// 2026-07-20 framework audit — failed-modify hygiene. A rejected SLTP modify
// leaves the position's current SL/TP unchanged, so trailing/BE callers
// re-send the identical request every tick ([Invalid stops] journal spam +
// wasted round-trips). We remember the last failed/skipped target per ticket
// and suppress verbatim retries for a short window; a changed target or an
// elapsed window retries normally, so transient rejections still recover.
#define QM_TM_MODIFY_RETRY_SECONDS 30
struct QM_TM_FailedModify
  {
   ulong    ticket;
   double   sl;
   double   tp;
   datetime last_attempt;
  };
QM_TM_FailedModify g_qm_tm_failed_modifies[];

int QM_TM_FailedModifyIndex(const ulong ticket)
  {
   const int count = ArraySize(g_qm_tm_failed_modifies);
   for(int i = 0; i < count; ++i)
      if(g_qm_tm_failed_modifies[i].ticket == ticket)
         return i;
   return -1;
  }

bool QM_TM_ModifySuppressed(const ulong ticket, const double sl, const double tp)
  {
   const int idx = QM_TM_FailedModifyIndex(ticket);
   if(idx < 0)
      return false;
   if(MathAbs(g_qm_tm_failed_modifies[idx].sl - sl) > 1e-10 ||
      MathAbs(g_qm_tm_failed_modifies[idx].tp - tp) > 1e-10)
      return false;
   return (TimeCurrent() - g_qm_tm_failed_modifies[idx].last_attempt) < QM_TM_MODIFY_RETRY_SECONDS;
  }

void QM_TM_RememberFailedModify(const ulong ticket, const double sl, const double tp)
  {
   // Adversarial review 2026-07-20: entries older than the retry window can
   // never suppress again — sweep them here so the array stays bounded by
   // "tickets that failed within the last window", not terminal lifetime.
   const datetime now = TimeCurrent();
   for(int i = ArraySize(g_qm_tm_failed_modifies) - 1; i >= 0; --i)
      if((now - g_qm_tm_failed_modifies[i].last_attempt) >= QM_TM_MODIFY_RETRY_SECONDS)
         QM_TM_ClearFailedModify(g_qm_tm_failed_modifies[i].ticket);

   int idx = QM_TM_FailedModifyIndex(ticket);
   if(idx < 0)
     {
      idx = ArraySize(g_qm_tm_failed_modifies);
      if(ArrayResize(g_qm_tm_failed_modifies, idx + 1) != idx + 1)
         return;
     }
   g_qm_tm_failed_modifies[idx].ticket = ticket;
   g_qm_tm_failed_modifies[idx].sl = sl;
   g_qm_tm_failed_modifies[idx].tp = tp;
   g_qm_tm_failed_modifies[idx].last_attempt = TimeCurrent();
  }

void QM_TM_ClearFailedModify(const ulong ticket)
  {
   const int idx = QM_TM_FailedModifyIndex(ticket);
   if(idx < 0)
      return;
   const int last = ArraySize(g_qm_tm_failed_modifies) - 1;
   if(idx != last)
      g_qm_tm_failed_modifies[idx] = g_qm_tm_failed_modifies[last];
   ArrayResize(g_qm_tm_failed_modifies, last);
  }

bool QM_TM_SendSLTPModify(const ulong ticket,
                          const double new_sl,
                          const double new_tp,
                          const string reason)
  {
   if(!QM_TM_SelectPosition(ticket))
      return false;

   const string symbol = PositionGetString(POSITION_SYMBOL);
   MqlTradeRequest request;
   ZeroMemory(request);
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = symbol;
   request.sl = (new_sl > 0.0) ? QM_TM_NormalizePrice(symbol, new_sl) : 0.0;
   request.tp = (new_tp > 0.0) ? QM_TM_NormalizePrice(symbol, new_tp) : 0.0;

   // Adversarial review 2026-07-20: the modify-hygiene machinery is LIVE-ONLY.
   // In the tester it would delay a fixed break-even target by up to the retry
   // window and thereby shift trades against the historical RISK_FIXED
   // evidence; the tester keeps pre-bundle behavior byte-identical (same
   // containment as the Q08 deinit guard and the PERCENT cap in this bundle).
   const bool live_hygiene = (MQLInfoInteger(MQL_TESTER) == 0);

   if(live_hygiene && QM_TM_ModifySuppressed(ticket, request.sl, request.tp))
      return false;   // identical target already failed/skipped inside the retry window

   // audit: stops-level pre-check — a target inside the broker minimum
   // distance is a guaranteed [Invalid stops] rejection; skip the round-trip
   // and log the skip once per target/window instead of once per tick.
   const long stops_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(live_hygiene && stops_level > 0 && point > 0.0)
     {
      const double min_dist = (double)stops_level * point;
      const bool is_buy = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      bool too_close = false;
      if(is_buy && bid > 0.0)
        {
         if(request.sl > 0.0 && (bid - request.sl) < min_dist)
            too_close = true;
         if(request.tp > 0.0 && (request.tp - bid) < min_dist)
            too_close = true;
        }
      else if(!is_buy && ask > 0.0)
        {
         if(request.sl > 0.0 && (request.sl - ask) < min_dist)
            too_close = true;
         if(request.tp > 0.0 && (ask - request.tp) < min_dist)
            too_close = true;
        }
      if(too_close)
        {
         QM_TM_RememberFailedModify(ticket, request.sl, request.tp);
         QM_LogEvent(QM_INFO, "TM_MODIFY_SKIPPED",
                     StringFormat("{\"ticket\":%I64u,\"symbol\":\"%s\",\"new_sl\":%.8f,\"new_tp\":%.8f,\"reason\":\"%s\",\"detail\":\"stops_level_distance\",\"stops_level\":%I64d}",
                                  ticket, QM_LoggerEscapeJson(symbol), request.sl, request.tp,
                                  QM_LoggerEscapeJson(reason), stops_level));
         return false;
        }
     }

   MqlTradeResult result;
   string error_class = BROKER_OTHER;
   const bool ok = QM_TradeContextSend(request, result, error_class);
   if(live_hygiene)
     {
      if(ok)
         QM_TM_ClearFailedModify(ticket);
      else
         QM_TM_RememberFailedModify(ticket, request.sl, request.tp);
     }

   const string payload = StringFormat(
      "{\"ticket\":%I64u,\"symbol\":\"%s\",\"new_sl\":%.8f,\"new_tp\":%.8f,\"reason\":\"%s\",\"ok\":%s,\"retcode\":%u,\"retcode_class\":\"%s\"}",
      ticket,
      QM_LoggerEscapeJson(symbol),
      request.sl,
      request.tp,
      QM_LoggerEscapeJson(reason),
      ok ? "true" : "false",
      result.retcode,
      QM_LoggerEscapeJson(error_class)
   );
   QM_LogEvent(ok ? QM_INFO : QM_WARN, "TM_MODIFY", payload);
   return ok;
  }

bool QM_TM_CloseByVolume(const ulong ticket,
                         const double requested_lots,
                         const QM_ExitReason reason,
                         const bool partial)
  {
   if(!QM_TM_SelectPosition(ticket))
      return false;

   const string symbol = PositionGetString(POSITION_SYMBOL);
   const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double position_lots = PositionGetDouble(POSITION_VOLUME);
   const long magic = PositionGetInteger(POSITION_MAGIC);
   if(position_lots <= 0.0)
      return false;

   double lots_to_close = requested_lots;
   if(lots_to_close <= 0.0 || lots_to_close > position_lots)
      lots_to_close = position_lots;
   lots_to_close = QM_TM_NormalizeVolume(symbol, lots_to_close);
   if(lots_to_close <= 0.0)
      return false;

   const bool is_buy_position = (position_type == POSITION_TYPE_BUY);
   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   const double close_price = is_buy_position ? bid : ask;
   if(close_price <= 0.0)
      return false;

   MqlTradeRequest request;
   ZeroMemory(request);
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = symbol;
   request.magic = magic;
   request.volume = lots_to_close;
   request.type = is_buy_position ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = QM_TM_NormalizePrice(symbol, close_price);
   request.deviation = QM_TM_DEFAULT_DEVIATION_POINTS;
   request.type_filling = QM_TradeContextResolveFilling(symbol);
   request.comment = partial ? "qm_tm_partial_close" : "qm_tm_close";

   MqlTradeResult result;
   string error_class = BROKER_OTHER;
   const bool ok = QM_TradeContextSend(request, result, error_class);

   const string payload = StringFormat(
      "{\"ticket\":%I64u,\"symbol\":\"%s\",\"lots\":%.8f,\"reason\":\"%s\",\"partial\":%s,\"ok\":%s,\"retcode\":%u,\"retcode_class\":\"%s\"}",
      ticket,
      QM_LoggerEscapeJson(symbol),
      lots_to_close,
      QM_LoggerEscapeJson(QM_ExitReasonToString(reason)),
      partial ? "true" : "false",
      ok ? "true" : "false",
      result.retcode,
      QM_LoggerEscapeJson(error_class)
   );
   QM_LogEvent(ok ? QM_INFO : QM_WARN, partial ? "TM_PARTIAL_CLOSE" : "TM_CLOSE", payload);
   return ok;
  }

bool QM_TM_OpenPosition(const QM_EntryRequest &req,
                        ulong &out_ticket,
                        const int explicit_magic = 0,
                        const double explicit_risk_percent = 0.0,
                        const QM_TradeSendPolicy send_policy = QM_TRADE_SEND_RETRY_TRANSIENT)
  {
   const QM_EntryResult result = QM_Entry(req,
                                          out_ticket,
                                          explicit_magic,
                                          explicit_risk_percent,
                                          send_policy);
   const bool ok = (result == QM_ENTRY_OK);
   const string payload = StringFormat(
      "{\"symbol\":\"%s\",\"type\":\"%s\",\"ok\":%s,\"ticket\":%I64u,\"entry_result\":\"%s\"}",
      QM_LoggerEscapeJson(_Symbol),
      QM_LoggerEscapeJson(QM_OrderTypeToString(req.type)),
      ok ? "true" : "false",
      out_ticket,
      QM_LoggerEscapeJson(QM_EntryResultToString(result))
   );
   QM_LogEvent(ok ? QM_INFO : QM_WARN, "TM_OPEN", payload);
   return ok;
  }

// Phase 2.5 explicit per-call risk mode/value overload. It has distinct arity
// from the legacy/Phase-1 signature above, so all existing calls retain their
// original default arguments and percentage semantics.
bool QM_TM_OpenPosition(const QM_EntryRequest &req,
                        ulong &out_ticket,
                        const int explicit_magic,
                        const QM_RiskMode explicit_risk_mode,
                        const double explicit_risk_value,
                        const QM_TradeSendPolicy send_policy = QM_TRADE_SEND_RETRY_TRANSIENT)
  {
   const QM_EntryResult result = QM_Entry(req,
                                          out_ticket,
                                          explicit_magic,
                                          explicit_risk_mode,
                                          explicit_risk_value,
                                          send_policy);
   const bool ok = (result == QM_ENTRY_OK);
   const string payload = StringFormat(
      "{\"symbol\":\"%s\",\"type\":\"%s\",\"ok\":%s,\"ticket\":%I64u,\"entry_result\":\"%s\"}",
      QM_LoggerEscapeJson(_Symbol),
      QM_LoggerEscapeJson(QM_OrderTypeToString(req.type)),
      ok ? "true" : "false",
      out_ticket,
      QM_LoggerEscapeJson(QM_EntryResultToString(result))
   );
   QM_LogEvent(ok ? QM_INFO : QM_WARN, "TM_OPEN", payload);
   return ok;
  }

bool QM_TM_RemovePendingOrder(const ulong ticket, const string reason)
  {
   if(ticket == 0 || !OrderSelect(ticket))
      return false;

   const string symbol = OrderGetString(ORDER_SYMBOL);
   MqlTradeRequest request;
   ZeroMemory(request);
   request.action = TRADE_ACTION_REMOVE;
   request.order = ticket;
   request.symbol = symbol;

   MqlTradeResult result;
   string error_class = BROKER_OTHER;
   const bool ok = QM_TradeContextSend(request, result, error_class);

   const string payload = StringFormat(
      "{\"ticket\":%I64u,\"symbol\":\"%s\",\"reason\":\"%s\",\"ok\":%s,\"retcode\":%u,\"retcode_class\":\"%s\"}",
      ticket,
      QM_LoggerEscapeJson(symbol),
      QM_LoggerEscapeJson(reason),
      ok ? "true" : "false",
      result.retcode,
      QM_LoggerEscapeJson(error_class)
   );
   QM_LogEvent(ok ? QM_INFO : QM_WARN, "TM_REMOVE_PENDING", payload);
   return ok;
  }

bool QM_TM_ClosePosition(const ulong ticket, const QM_ExitReason reason)
  {
   return QM_TM_CloseByVolume(ticket, 0.0, reason, false);
  }

bool QM_TM_PartialClose(const ulong ticket, const double lots, const QM_ExitReason reason)
  {
   return QM_TM_CloseByVolume(ticket, lots, reason, true);
  }

bool QM_TM_MoveSL(const ulong ticket, const double new_sl, const string reason)
  {
   if(!QM_TM_SelectPosition(ticket))
      return false;
   const double current_tp = PositionGetDouble(POSITION_TP);
   return QM_TM_SendSLTPModify(ticket, new_sl, current_tp, reason);
  }

bool QM_TM_MoveTP(const ulong ticket, const double new_tp, const string reason)
  {
   if(!QM_TM_SelectPosition(ticket))
      return false;
   const double current_sl = PositionGetDouble(POSITION_SL);
   return QM_TM_SendSLTPModify(ticket, current_sl, new_tp, reason);
  }

bool QM_TM_MoveToBreakEven(const ulong ticket, const int trigger_pips, const int buffer_pips)
  {
   if(!QM_TM_SelectPosition(ticket))
      return false;

   const string symbol = PositionGetString(POSITION_SYMBOL);
   const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double trigger_distance = QM_StopRulesPipsToPriceDistance(symbol, trigger_pips);
   const double buffer_distance = QM_StopRulesPipsToPriceDistance(symbol, buffer_pips);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(trigger_distance <= 0.0 || point <= 0.0)
      return false;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market_price = is_buy ? SymbolInfoDouble(symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(market_price <= 0.0 || open_price <= 0.0)
      return false;

   const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
   if(moved < trigger_distance)
      return false;

   const double target_sl = is_buy ? (open_price + buffer_distance) : (open_price - buffer_distance);
   const double normalized_target = QM_TM_NormalizePrice(symbol, target_sl);
   if(normalized_target <= 0.0)
      return false;

   const bool improves = (current_sl <= 0.0) ||
                         (is_buy ? (normalized_target > current_sl + point * 0.5)
                                 : (normalized_target < current_sl - point * 0.5));
   if(!improves)
      return false;

   const string reason = StringFormat("move_to_breakeven trigger_pips=%d buffer_pips=%d", trigger_pips, buffer_pips);
   return QM_TM_MoveSL(ticket, normalized_target, reason);
  }

bool QM_TM_TrailATR(const ulong ticket, const int atr_period_value, const double atr_mult)
  {
   if(!QM_TM_SelectPosition(ticket))
      return false;

   const string symbol = PositionGetString(POSITION_SYMBOL);
   const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0 || atr_mult <= 0.0)
      return false;

   double atr_value = 0.0;
   if(!QM_StopRulesReadATRValue(symbol, atr_period_value, 1, atr_value))
      return false;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market_price = is_buy ? SymbolInfoDouble(symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(market_price <= 0.0)
      return false;

   const double raw_sl = is_buy ? (market_price - atr_value * atr_mult)
                                : (market_price + atr_value * atr_mult);
   const double target_sl = QM_TM_NormalizePrice(symbol, raw_sl);
   if(target_sl <= 0.0)
      return false;

   const bool improves = (current_sl <= 0.0) ||
                         (is_buy ? (target_sl > current_sl + point * 0.5)
                                 : (target_sl < current_sl - point * 0.5));
   if(!improves)
      return false;

   const string reason = StringFormat("trail_atr period=%d mult=%.4f", atr_period_value, atr_mult);
   return QM_TM_MoveSL(ticket, target_sl, reason);
  }

bool QM_TM_TrailStep(const ulong ticket, const int trigger_pips, const int step_pips)
  {
   if(!QM_TM_SelectPosition(ticket))
      return false;

   const string symbol = PositionGetString(POSITION_SYMBOL);
   const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double current_sl = PositionGetDouble(POSITION_SL);
   const double trigger_distance = QM_StopRulesPipsToPriceDistance(symbol, trigger_pips);
   const double step_distance = QM_StopRulesPipsToPriceDistance(symbol, step_pips);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(trigger_distance <= 0.0 || step_distance <= 0.0 || point <= 0.0)
      return false;

   const bool is_buy = (position_type == POSITION_TYPE_BUY);
   const double market_price = is_buy ? SymbolInfoDouble(symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(market_price <= 0.0 || open_price <= 0.0)
      return false;

   const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
   if(moved < trigger_distance)
      return false;

   const double raw_sl = is_buy ? (market_price - step_distance)
                                : (market_price + step_distance);
   const double target_sl = QM_TM_NormalizePrice(symbol, raw_sl);
   if(target_sl <= 0.0)
      return false;

   const bool improves = (current_sl <= 0.0) ||
                         (is_buy ? (target_sl > current_sl + point * 0.5)
                                 : (target_sl < current_sl - point * 0.5));
   if(!improves)
      return false;

   const string reason = StringFormat("trail_step trigger_pips=%d step_pips=%d", trigger_pips, step_pips);
   return QM_TM_MoveSL(ticket, target_sl, reason);
  }

bool QM_TM_AddToPosition(const ulong existing_ticket, const QM_EntryRequest &add_req)
  {
   if(!QM_TM_SelectPosition(existing_ticket))
      return false;

   const string symbol = PositionGetString(POSITION_SYMBOL);
   const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy_position = (position_type == POSITION_TYPE_BUY);

   if((is_buy_position && !QM_OrderTypeIsBuy(add_req.type)) ||
      (!is_buy_position && QM_OrderTypeIsBuy(add_req.type)))
      return false;

   QM_EntryRequest local_req = add_req;

   ulong added_ticket = 0;
   const bool ok = QM_TM_OpenPosition(local_req, added_ticket);
   const string payload = StringFormat(
      "{\"existing_ticket\":%I64u,\"added_ticket\":%I64u,\"symbol\":\"%s\",\"ok\":%s}",
      existing_ticket,
      added_ticket,
      QM_LoggerEscapeJson(symbol),
      ok ? "true" : "false"
   );
   QM_LogEvent(ok ? QM_INFO : QM_WARN, "TM_ADD", payload);
   return ok;
  }

int QM_TM_OpenPositionCount(const int magic)
  {
   int count = 0;
   const int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         count++;
     }
   return count;
  }

double QM_TM_TotalExposureLots(const int magic)
  {
   double lots = 0.0;
   const int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      lots += PositionGetDouble(POSITION_VOLUME);
     }
   return lots;
  }

double QM_TM_OpenPnL(const int magic)
  {
   double pnl = 0.0;
   const int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pnl += PositionGetDouble(POSITION_PROFIT);
      pnl += PositionGetDouble(POSITION_SWAP);
     }
   return pnl;
  }

// ---------------------------------------------------------------------------
// 2026-07-20 framework audit P0.4 — restart-safe held-period exits.
// Counts COMPLETED tf-periods between a position's open time and `now` by
// walking the actual bar series (iBarShift), so weekends and holidays are
// skipped exactly as the chart skips them and an EA restart cannot reset the
// count: the truth is POSITION_TIME, not a global counter that OnInit zeroes.
// Returns -1 when either time has no bar (history gap) — callers MUST treat
// -1 as "unknown", never as "due".
int QM_TM_HeldPeriods(const string symbol,
                      const ENUM_TIMEFRAMES tf,
                      const datetime open_time,
                      const datetime now = 0)
  {
   if(open_time <= 0)
      return -1;
   datetime t = now;
   if(t <= 0)
      t = TimeCurrent();
   if(t < open_time)
      return -1;
   // Adversarial review 2026-07-20: iBarShift(exact=false) does NOT return -1
   // for a time BEFORE the series start — it clamps to the oldest bar, which
   // would overstate the hold and fire a held-period exit early after a
   // restart with short history. Reject the pre-series case explicitly.
   const int bars = Bars(symbol, tf);
   if(bars <= 0)
      return -1;
   const datetime series_start = iTime(symbol, tf, bars - 1);
   if(series_start <= 0 || open_time < series_start)
      return -1;
   const int shift_open = iBarShift(symbol, tf, open_time, false);
   const int shift_now  = iBarShift(symbol, tf, t, false);
   if(shift_open < 0 || shift_now < 0)
      return -1;
   return shift_open - shift_now;
  }

// Held periods of the LONGEST-held open position owned by (magic, symbol).
// Returns -1 when no position is open or any owned position's history is
// unavailable (unknown must not silently understate the hold).
int QM_TM_HeldPeriodsForMagic(const long magic,
                              const string symbol,
                              const ENUM_TIMEFRAMES tf,
                              const datetime now = 0)
  {
   int held_max = -1;
   bool found = false;
   const int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      const int held = QM_TM_HeldPeriods(symbol, tf,
                                         (datetime)PositionGetInteger(POSITION_TIME), now);
      if(held < 0)
         return -1;
      found = true;
      if(held > held_max)
         held_max = held;
     }
   return found ? held_max : -1;
  }

#endif // QM_TRADEMANAGEMENT_MQH
