#ifndef QM_TRADE_CONTEXT_MQH
#define QM_TRADE_CONTEXT_MQH

#include "QM_Errors.mqh"
#include "QM_Logger.mqh"

bool g_qm_trade_block_not_enough_money = false;

string QM_TradeContextRetcodeClass(const uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_REQUOTE:
         return BROKER_REQUOTE;
      case TRADE_RETCODE_PRICE_OFF:
         return BROKER_OFF_QUOTE;
      case TRADE_RETCODE_NO_MONEY:
         return BROKER_NOT_ENOUGH_MONEY;
      case TRADE_RETCODE_TRADE_DISABLED:
         return BROKER_TRADE_DISABLED;
      case TRADE_RETCODE_INVALID_VOLUME:
         return BROKER_INVALID_VOLUME;
      default:
         break;
   }

   return BROKER_OTHER;
}

bool QM_TradeContextAcceptedRetcode(const uint retcode)
{
   return (retcode == TRADE_RETCODE_DONE ||
           retcode == TRADE_RETCODE_DONE_PARTIAL ||
           retcode == TRADE_RETCODE_PLACED);
}

bool QM_TradeContextSend(const MqlTradeRequest &request, MqlTradeResult &result, string &out_error_class)
{
   ZeroMemory(result);
   out_error_class = BROKER_OTHER;

   if(g_qm_trade_block_not_enough_money)
   {
      out_error_class = BROKER_NOT_ENOUGH_MONEY;
      return false;
   }

   MqlTradeResult local_result;
   ZeroMemory(local_result);
   bool sent = OrderSend(request, local_result);
   uint retcode = local_result.retcode;

   if(!sent || !QM_TradeContextAcceptedRetcode(retcode))
   {
      if(retcode == TRADE_RETCODE_REQUOTE)
      {
         ZeroMemory(local_result);
         sent = OrderSend(request, local_result);
         retcode = local_result.retcode;
      }
      else if(retcode == TRADE_RETCODE_PRICE_OFF)
      {
         Sleep(200);
         ZeroMemory(local_result);
         sent = OrderSend(request, local_result);
         retcode = local_result.retcode;
      }
   }

   result = local_result;
   if(sent && QM_TradeContextAcceptedRetcode(retcode))
      return true;

   out_error_class = QM_TradeContextRetcodeClass(retcode);
   const string payload = StringFormat(
      "{\"retcode\":%u,\"retcode_class\":\"%s\",\"retcode_comment\":\"%s\",\"symbol\":\"%s\",\"type\":%d,\"volume\":%.8f,\"price\":%.8f,\"sl\":%.8f,\"tp\":%.8f,\"magic\":%I64d}",
      retcode,
      QM_LoggerEscapeJson(out_error_class),
      QM_LoggerEscapeJson(result.comment),
      QM_LoggerEscapeJson(request.symbol),
      (int)request.type,
      request.volume,
      request.price,
      request.sl,
      request.tp,
      request.magic
   );

   if(out_error_class == BROKER_NOT_ENOUGH_MONEY)
   {
      g_qm_trade_block_not_enough_money = true;
      QM_LogFatal(BROKER_NOT_ENOUGH_MONEY, payload);
   }
   else if(out_error_class == BROKER_TRADE_DISABLED || out_error_class == BROKER_INVALID_VOLUME)
   {
      QM_LogEvent(QM_ERROR, out_error_class, payload);
   }
   else
   {
      QM_LogEvent(QM_WARN, out_error_class, payload);
   }

   return false;
}

#endif // QM_TRADE_CONTEXT_MQH
