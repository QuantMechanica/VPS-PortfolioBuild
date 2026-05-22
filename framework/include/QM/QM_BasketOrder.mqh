#ifndef QM_BASKET_ORDER_MQH
#define QM_BASKET_ORDER_MQH

#include "QM_OrderTypes.mqh"
#include "QM_TradeContext.mqh"
#include "QM_KillSwitch.mqh"
#include "QM_NewsFilter.mqh"
#include "QM_RiskSizer.mqh"
#include "QM_MagicResolver.mqh"
#include "QM_Logger.mqh"

struct QM_BasketOrderRequest
{
   string        symbol;
   QM_OrderType  type;
   double        price;
   double        sl;
   double        tp;
   double        lots;
   string        reason;
   int           symbol_slot;
   int           expiration_seconds;
};

double QM_BasketMarketPrice(const string symbol, const QM_OrderType type)
{
   if(QM_OrderTypeIsBuy(type))
      return SymbolInfoDouble(symbol, SYMBOL_ASK);
   return SymbolInfoDouble(symbol, SYMBOL_BID);
}

double QM_BasketNormalizePrice(const string symbol, const double price)
{
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
}

double QM_BasketResolvePrice(const QM_BasketOrderRequest &req)
{
   if(req.price > 0.0)
      return req.price;
   return QM_BasketMarketPrice(req.symbol, req.type);
}

bool QM_BasketHasOpenPosition(const long magic, const string symbol)
{
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == symbol)
         return true;
   }
   return false;
}

double QM_BasketSLPoints(const string symbol, const double entry_price, const double sl_price)
{
   if(entry_price <= 0.0 || sl_price <= 0.0)
      return 0.0;
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const double dist = MathAbs(entry_price - sl_price);
   if(dist <= 0.0)
      return 0.0;
   return dist / point;
}

void QM_BasketLogReject(const QM_BasketOrderRequest &req, const string result, const string detail)
{
   const string payload = StringFormat(
      "{\"result\":\"%s\",\"host_symbol\":\"%s\",\"symbol\":\"%s\",\"type\":\"%s\",\"reason\":\"%s\",\"detail\":\"%s\",\"symbol_slot\":%d}",
      QM_LoggerEscapeJson(result),
      QM_LoggerEscapeJson(_Symbol),
      QM_LoggerEscapeJson(req.symbol),
      QM_LoggerEscapeJson(QM_OrderTypeToString(req.type)),
      QM_LoggerEscapeJson(req.reason),
      QM_LoggerEscapeJson(detail),
      req.symbol_slot
   );
   QM_LogEvent(QM_WARN, "BASKET_ORDER_REJECTED", payload);
}

bool QM_BasketOpenPosition(const int ea_id,
                           const QM_NewsMode news_mode,
                           const int deviation_points,
                           const QM_BasketOrderRequest &req,
                           ulong &out_ticket)
{
   out_ticket = 0;

   if(req.symbol == "")
   {
      QM_BasketLogReject(req, "QM_BASKET_REJECTED_SYMBOL", "blank_symbol");
      return false;
   }

   if(!QM_KillSwitchCheck())
   {
      QM_BasketLogReject(req, "QM_BASKET_REJECTED_KILLSWITCH", QM_KillSwitchHaltReason());
      return false;
   }

   if(!QM_NewsAllowsTrade(req.symbol, TimeCurrent(), news_mode))
   {
      QM_BasketLogReject(req, "QM_BASKET_REJECTED_NEWS", "news_mode_block");
      return false;
   }

   if(ea_id <= 0)
   {
      QM_BasketLogReject(req, "QM_BASKET_REJECTED_RISK", "ea_id_not_configured");
      return false;
   }

   const int magic = QM_MagicChecked(ea_id, req.symbol_slot, req.symbol);
   if(magic <= 0)
   {
      QM_BasketLogReject(req, "QM_BASKET_REJECTED_BROKER", "magic_resolution_failed");
      return false;
   }

   QM_LoggerSetMagic(magic);

   if(QM_BasketHasOpenPosition((long)magic, req.symbol))
   {
      QM_BasketLogReject(req, "QM_BASKET_REJECTED_DUPLICATE", "open_position_same_magic_symbol");
      return false;
   }

   const double entry_price = QM_BasketResolvePrice(req);
   if(entry_price <= 0.0)
   {
      QM_BasketLogReject(req, "QM_BASKET_REJECTED_BROKER", "invalid_entry_price");
      return false;
   }

   double lots = req.lots;
   if(lots <= 0.0)
   {
      const double sl_points = QM_BasketSLPoints(req.symbol, entry_price, req.sl);
      lots = QM_LotsForRisk(req.symbol, sl_points);
   }
   if(lots <= 0.0)
   {
      QM_BasketLogReject(req, "QM_BASKET_REJECTED_RISK", "lots_for_risk_zero");
      return false;
   }

   MqlTradeRequest trade_req;
   ZeroMemory(trade_req);
   trade_req.action = (QM_OrderTypeIsLimit(req.type) || QM_OrderTypeIsStop(req.type)) ? TRADE_ACTION_PENDING : TRADE_ACTION_DEAL;
   trade_req.symbol = req.symbol;
   trade_req.magic = magic;
   trade_req.volume = lots;
   trade_req.type = QM_OrderTypeToMT5(req.type);
   trade_req.price = QM_BasketNormalizePrice(req.symbol, entry_price);
   trade_req.sl = (req.sl > 0.0) ? QM_BasketNormalizePrice(req.symbol, req.sl) : 0.0;
   trade_req.tp = (req.tp > 0.0) ? QM_BasketNormalizePrice(req.symbol, req.tp) : 0.0;
   trade_req.deviation = (deviation_points > 0) ? deviation_points : 20;
   trade_req.type_time = ORDER_TIME_GTC;
   if(req.expiration_seconds > 0)
   {
      trade_req.type_time = ORDER_TIME_SPECIFIED;
      trade_req.expiration = TimeCurrent() + req.expiration_seconds;
   }
   trade_req.comment = req.reason;

   MqlTradeResult trade_res;
   string broker_error_class = "";
   if(!QM_TradeContextSend(trade_req, trade_res, broker_error_class))
   {
      QM_BasketLogReject(req, "QM_BASKET_REJECTED_BROKER", broker_error_class);
      return false;
   }

   out_ticket = (trade_res.order > 0) ? trade_res.order : trade_res.deal;
   const string payload = StringFormat(
      "{\"ticket\":%I64u,\"host_symbol\":\"%s\",\"symbol\":\"%s\",\"type\":\"%s\",\"lots\":%.8f,\"price\":%.8f,\"sl\":%.8f,\"tp\":%.8f,\"magic\":%d,\"reason\":\"%s\",\"symbol_slot\":%d,\"retcode\":%u}",
      out_ticket,
      QM_LoggerEscapeJson(_Symbol),
      QM_LoggerEscapeJson(req.symbol),
      QM_LoggerEscapeJson(QM_OrderTypeToString(req.type)),
      lots,
      trade_req.price,
      trade_req.sl,
      trade_req.tp,
      magic,
      QM_LoggerEscapeJson(req.reason),
      req.symbol_slot,
      trade_res.retcode
   );
   QM_LogEvent(QM_INFO, "BASKET_ORDER_ACCEPTED", payload);
   return true;
}

#endif // QM_BASKET_ORDER_MQH
