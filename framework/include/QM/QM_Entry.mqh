#ifndef QM_ENTRY_MQH
#define QM_ENTRY_MQH

#include "QM_OrderTypes.mqh"
#include "QM_TradeContext.mqh"
#include "QM_KillSwitch.mqh"
#include "QM_NewsFilter.mqh"
#include "QM_RiskSizer.mqh"
#include "QM_MagicResolver.mqh"
#include "QM_Logger.mqh"

struct QM_EntryRequest
{
   QM_OrderType  type;
   double        price;
   double        sl;
   double        tp;
   string        reason;
   int           symbol_slot;
   int           expiration_seconds;
};

enum QM_EntryResult
{
   QM_ENTRY_OK = 0,
   QM_ENTRY_REJECTED_KILLSWITCH,
   QM_ENTRY_REJECTED_NEWS,
   QM_ENTRY_REJECTED_RISK,
   QM_ENTRY_REJECTED_BROKER,
   QM_ENTRY_REJECTED_DUPLICATE
};

int         g_qm_entry_ea_id            = 0;
QM_NewsMode g_qm_entry_news_mode        = QM_NEWS_OFF;
int         g_qm_entry_deviation_points = 20;

void QM_EntryConfigure(const int entry_ea_id,
                       const QM_NewsMode entry_news_mode = QM_NEWS_OFF,
                       const int deviation_points = 20)
{
   g_qm_entry_ea_id = entry_ea_id;
   g_qm_entry_news_mode = entry_news_mode;
   g_qm_entry_deviation_points = (deviation_points > 0) ? deviation_points : 20;
}

string QM_EntryResultToString(const QM_EntryResult result)
{
   switch(result)
   {
      case QM_ENTRY_OK:                   return "QM_ENTRY_OK";
      case QM_ENTRY_REJECTED_KILLSWITCH: return "QM_ENTRY_REJECTED_KILLSWITCH";
      case QM_ENTRY_REJECTED_NEWS:       return "QM_ENTRY_REJECTED_NEWS";
      case QM_ENTRY_REJECTED_RISK:       return "QM_ENTRY_REJECTED_RISK";
      case QM_ENTRY_REJECTED_BROKER:     return "QM_ENTRY_REJECTED_BROKER";
      case QM_ENTRY_REJECTED_DUPLICATE:  return "QM_ENTRY_REJECTED_DUPLICATE";
   }
   return "QM_ENTRY_REJECTED_BROKER";
}

double QM_EntryMarketPrice(const QM_OrderType type)
{
   if(QM_OrderTypeIsBuy(type))
      return SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return SymbolInfoDouble(_Symbol, SYMBOL_BID);
}

double QM_EntryResolvePrice(const QM_EntryRequest &req)
{
   if(req.price > 0.0)
      return req.price;
   return QM_EntryMarketPrice(req.type);
}

bool QM_EntryHasOpenPosition(const long magic, const string symbol)
{
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;

      const long pos_magic = PositionGetInteger(POSITION_MAGIC);
      if(pos_magic != magic)
         continue;

      const string pos_symbol = PositionGetString(POSITION_SYMBOL);
      if(pos_symbol == symbol)
         return true;
   }
   return false;
}

double QM_EntrySLPoints(const double entry_price, const double sl_price)
{
   if(entry_price <= 0.0 || sl_price <= 0.0)
      return 0.0;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const double dist = MathAbs(entry_price - sl_price);
   if(dist <= 0.0)
      return 0.0;

   return dist / point;
}

void QM_EntryLogReject(const QM_EntryRequest &req, const QM_EntryResult result, const string detail)
{
   const string payload = StringFormat(
      "{\"result\":\"%s\",\"symbol\":\"%s\",\"type\":\"%s\",\"reason\":\"%s\",\"detail\":\"%s\",\"symbol_slot\":%d}",
      QM_LoggerEscapeJson(QM_EntryResultToString(result)),
      QM_LoggerEscapeJson(_Symbol),
      QM_LoggerEscapeJson(QM_OrderTypeToString(req.type)),
      QM_LoggerEscapeJson(req.reason),
      QM_LoggerEscapeJson(detail),
      req.symbol_slot
   );
   QM_LogEvent(QM_WARN, "ENTRY_REJECTED", payload);
}

QM_EntryResult QM_Entry(const QM_EntryRequest &req, ulong &out_ticket)
{
   out_ticket = 0;

   if(!QM_KillSwitchCheck())
   {
      QM_EntryLogReject(req, QM_ENTRY_REJECTED_KILLSWITCH, QM_KillSwitchHaltReason());
      return QM_ENTRY_REJECTED_KILLSWITCH;
   }

   if(!QM_NewsAllowsTrade(_Symbol, TimeCurrent(), g_qm_entry_news_mode))
   {
      QM_EntryLogReject(req, QM_ENTRY_REJECTED_NEWS, "news_mode_block");
      return QM_ENTRY_REJECTED_NEWS;
   }

   if(g_qm_entry_ea_id <= 0)
   {
      QM_EntryLogReject(req, QM_ENTRY_REJECTED_RISK, "entry_not_configured");
      return QM_ENTRY_REJECTED_RISK;
   }

   const int magic = QM_MagicChecked(g_qm_entry_ea_id, req.symbol_slot, _Symbol);
   if(magic <= 0)
   {
      QM_EntryLogReject(req, QM_ENTRY_REJECTED_BROKER, "magic_resolution_failed");
      return QM_ENTRY_REJECTED_BROKER;
   }

   QM_LoggerSetMagic(magic);

   if(QM_EntryHasOpenPosition((long)magic, _Symbol))
   {
      QM_EntryLogReject(req, QM_ENTRY_REJECTED_DUPLICATE, "open_position_same_magic_symbol");
      return QM_ENTRY_REJECTED_DUPLICATE;
   }

   const double entry_price = QM_EntryResolvePrice(req);
   if(entry_price <= 0.0)
   {
      QM_EntryLogReject(req, QM_ENTRY_REJECTED_BROKER, "invalid_entry_price");
      return QM_ENTRY_REJECTED_BROKER;
   }

   const double sl_points = QM_EntrySLPoints(entry_price, req.sl);
   const double lots = QM_LotsForRisk(_Symbol, sl_points);
   if(lots <= 0.0)
   {
      QM_EntryLogReject(req, QM_ENTRY_REJECTED_RISK, "lots_for_risk_zero");
      return QM_ENTRY_REJECTED_RISK;
   }

   MqlTradeRequest trade_req;
   ZeroMemory(trade_req);
   trade_req.action = (QM_OrderTypeIsLimit(req.type) || QM_OrderTypeIsStop(req.type)) ? TRADE_ACTION_PENDING : TRADE_ACTION_DEAL;
   trade_req.symbol = _Symbol;
   trade_req.magic = magic;
   trade_req.volume = lots;
   trade_req.type = QM_OrderTypeToMT5(req.type);
   trade_req.price = NormalizeDouble(entry_price, _Digits);
   trade_req.sl = (req.sl > 0.0) ? NormalizeDouble(req.sl, _Digits) : 0.0;
   trade_req.tp = (req.tp > 0.0) ? NormalizeDouble(req.tp, _Digits) : 0.0;
   trade_req.deviation = g_qm_entry_deviation_points;
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
      QM_EntryLogReject(req, QM_ENTRY_REJECTED_BROKER, broker_error_class);
      return QM_ENTRY_REJECTED_BROKER;
   }

   out_ticket = (trade_res.order > 0) ? trade_res.order : trade_res.deal;
   const string payload = StringFormat(
      "{\"ticket\":%I64u,\"symbol\":\"%s\",\"type\":\"%s\",\"lots\":%.8f,\"price\":%.8f,\"sl\":%.8f,\"tp\":%.8f,\"magic\":%d,\"reason\":\"%s\",\"symbol_slot\":%d,\"retcode\":%u}",
      out_ticket,
      QM_LoggerEscapeJson(_Symbol),
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
   QM_LogEvent(QM_INFO, "ENTRY_ACCEPTED", payload);
   return QM_ENTRY_OK;
}

#endif // QM_ENTRY_MQH
