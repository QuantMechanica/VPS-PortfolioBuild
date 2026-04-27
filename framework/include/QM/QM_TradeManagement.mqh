#ifndef QM_TRADEMANAGEMENT_MQH
#define QM_TRADEMANAGEMENT_MQH

#include "QM_OrderTypes.mqh"
#include "QM_StopRules.mqh"
#include "QM_TradeContext.mqh"
#include "QM_Logger.mqh"

#define QM_TM_DEFAULT_DEVIATION_POINTS 20

// Step-14 compatibility shim: QM_Entry/QM_Exit may land in adjacent implementation steps.
#ifndef QM_ENTRY_REQUEST_DEFINED
#define QM_ENTRY_REQUEST_DEFINED
struct QM_EntryRequest
  {
   string       symbol;
   QM_OrderType side;
   double       lots;
   double       price;
   double       sl;
   double       tp;
   int          deviation_points;
   long         magic;
   string       comment;
  };
#endif

#ifndef QM_EXIT_REASON_DEFINED
#define QM_EXIT_REASON_DEFINED
enum QM_ExitReason
  {
   QM_EXIT_SIGNAL = 0,
   QM_EXIT_STOP_LOSS = 1,
   QM_EXIT_TAKE_PROFIT = 2,
   QM_EXIT_TIME = 3,
   QM_EXIT_FRIDAY_CLOSE = 4,
   QM_EXIT_KILL_SWITCH = 5,
   QM_EXIT_MANUAL = 6,
   QM_EXIT_PARTIAL = 7,
   QM_EXIT_UNKNOWN = 8
  };
#endif

string QM_ExitReasonToString(const QM_ExitReason reason)
  {
   switch(reason)
     {
      case QM_EXIT_SIGNAL:       return "QM_EXIT_SIGNAL";
      case QM_EXIT_STOP_LOSS:    return "QM_EXIT_STOP_LOSS";
      case QM_EXIT_TAKE_PROFIT:  return "QM_EXIT_TAKE_PROFIT";
      case QM_EXIT_TIME:         return "QM_EXIT_TIME";
      case QM_EXIT_FRIDAY_CLOSE: return "QM_EXIT_FRIDAY_CLOSE";
      case QM_EXIT_KILL_SWITCH:  return "QM_EXIT_KILL_SWITCH";
      case QM_EXIT_MANUAL:       return "QM_EXIT_MANUAL";
      case QM_EXIT_PARTIAL:      return "QM_EXIT_PARTIAL";
      case QM_EXIT_UNKNOWN:      return "QM_EXIT_UNKNOWN";
     }
   return "QM_EXIT_UNKNOWN";
  }

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

   MqlTradeResult result;
   string error_class = BROKER_OTHER;
   const bool ok = QM_TradeContextSend(request, result, error_class);

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

bool QM_TM_OpenPosition(const QM_EntryRequest &req, ulong &out_ticket)
  {
   out_ticket = 0;
   const string symbol = (StringLen(req.symbol) > 0) ? req.symbol : _Symbol;
   const double lots = QM_TM_NormalizeVolume(symbol, req.lots);
   if(lots <= 0.0)
      return false;

   const bool is_pending = (QM_OrderTypeIsLimit(req.side) || QM_OrderTypeIsStop(req.side));

   MqlTradeRequest request;
   ZeroMemory(request);
   request.action = is_pending ? TRADE_ACTION_PENDING : TRADE_ACTION_DEAL;
   request.symbol = symbol;
   request.type = QM_OrderTypeToMT5(req.side);
   request.volume = lots;
   request.magic = req.magic;
   request.deviation = (req.deviation_points > 0) ? req.deviation_points : QM_TM_DEFAULT_DEVIATION_POINTS;
   request.comment = (StringLen(req.comment) > 0) ? req.comment : "qm_tm_open";

   if(is_pending)
     {
      request.price = QM_TM_NormalizePrice(symbol, req.price);
      request.type_time = ORDER_TIME_GTC;
      if(request.price <= 0.0)
         return false;
     }
   else
     {
      if(req.price > 0.0)
         request.price = QM_TM_NormalizePrice(symbol, req.price);
      else
        {
         const bool is_buy = QM_OrderTypeIsBuy(req.side);
         request.price = QM_TM_NormalizePrice(symbol, is_buy ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                                             : SymbolInfoDouble(symbol, SYMBOL_BID));
        }
      if(request.price <= 0.0)
         return false;
     }

   request.sl = (req.sl > 0.0) ? QM_TM_NormalizePrice(symbol, req.sl) : 0.0;
   request.tp = (req.tp > 0.0) ? QM_TM_NormalizePrice(symbol, req.tp) : 0.0;

   MqlTradeResult result;
   string error_class = BROKER_OTHER;
   const bool ok = QM_TradeContextSend(request, result, error_class);
   if(ok)
      out_ticket = (result.order > 0) ? result.order : result.deal;

   const string payload = StringFormat(
      "{\"symbol\":\"%s\",\"side\":\"%s\",\"lots\":%.8f,\"price\":%.8f,\"sl\":%.8f,\"tp\":%.8f,\"magic\":%I64d,\"ok\":%s,\"ticket\":%I64u,\"retcode\":%u,\"retcode_class\":\"%s\"}",
      QM_LoggerEscapeJson(symbol),
      QM_LoggerEscapeJson(QM_OrderTypeToString(req.side)),
      lots,
      request.price,
      request.sl,
      request.tp,
      request.magic,
      ok ? "true" : "false",
      out_ticket,
      result.retcode,
      QM_LoggerEscapeJson(error_class)
   );
   QM_LogEvent(ok ? QM_INFO : QM_WARN, "TM_OPEN", payload);
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

bool QM_TM_TrailATR(const ulong ticket, const int atr_period, const double atr_mult)
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
   if(!QM_StopRulesReadATRValue(symbol, atr_period, 1, atr_value))
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

   const string reason = StringFormat("trail_atr period=%d mult=%.4f", atr_period, atr_mult);
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
   const long magic = PositionGetInteger(POSITION_MAGIC);
   const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy_position = (position_type == POSITION_TYPE_BUY);

   if((is_buy_position && !QM_OrderTypeIsBuy(add_req.side)) ||
      (!is_buy_position && QM_OrderTypeIsBuy(add_req.side)))
      return false;

   QM_EntryRequest local_req = add_req;
   if(StringLen(local_req.symbol) == 0)
      local_req.symbol = symbol;
   if(local_req.magic == 0)
      local_req.magic = magic;

   ulong added_ticket = 0;
   const bool ok = QM_TM_OpenPosition(local_req, added_ticket);
   const string payload = StringFormat(
      "{\"existing_ticket\":%I64u,\"added_ticket\":%I64u,\"symbol\":\"%s\",\"ok\":%s}",
      existing_ticket,
      added_ticket,
      QM_LoggerEscapeJson(local_req.symbol),
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
      pnl += PositionGetDouble(POSITION_COMMISSION);
     }
   return pnl;
  }

#endif // QM_TRADEMANAGEMENT_MQH
