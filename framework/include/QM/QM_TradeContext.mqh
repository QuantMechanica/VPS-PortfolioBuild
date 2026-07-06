#ifndef QM_TRADE_CONTEXT_MQH
#define QM_TRADE_CONTEXT_MQH

#include "QM_Errors.mqh"
#include "QM_Logger.mqh"

bool g_qm_trade_block_not_enough_money = false;
int  g_qm_trade_block_day_key = -1;

// Entry-class requests open NEW exposure: deals without a position ticket, or
// pending placements. Closes, SL/TP modifies, pending removals and close-by
// requests must NEVER be latched — they need no margin, and blocking
// risk-reducing requests turns a fail-stop into a fail-open (positions the EA
// can no longer close). 2026-07-06 audit finding F1/D2.
// F3 (2026-07-06 audit): resolve the symbol's allowed filling mode instead of
// defaulting to FOK (ZeroMemory'd requests carry type_filling=0=FOK). The
// tester accepts any filling mode; a live broker/symbol without FOK returns
// TRADE_RETCODE_INVALID_FILL — a tester-invisible, broker-fragile divergence
// that previously covered every path except QM_Exit. Darwinex and FTMO differ
// per-symbol; resolve per request.
ENUM_ORDER_TYPE_FILLING QM_TradeContextResolveFilling(const string symbol)
{
   const long fill_flags = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   if((fill_flags & SYMBOL_FILLING_FOK) != 0)
      return ORDER_FILLING_FOK;
   if((fill_flags & SYMBOL_FILLING_IOC) != 0)
      return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

bool QM_TradeContextOpensExposure(const MqlTradeRequest &request)
{
   if(request.action == TRADE_ACTION_SLTP ||
      request.action == TRADE_ACTION_REMOVE ||
      request.action == TRADE_ACTION_CLOSE_BY)
      return false;
   if(request.action == TRADE_ACTION_DEAL && request.position > 0)
      return false;
   return true;
}

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
      // The latch re-arms each broker day: margin conditions change as
      // positions close and equity moves; a permanent latch silences the EA
      // for the rest of the session. If NO_MONEY persists, the next rejected
      // entry re-sets it immediately.
      MqlDateTime block_dt;
      TimeToStruct(TimeCurrent(), block_dt);
      const int block_day_key = block_dt.year * 1000 + block_dt.day_of_year;
      if(block_day_key != g_qm_trade_block_day_key)
         g_qm_trade_block_not_enough_money = false;
   }

   if(g_qm_trade_block_not_enough_money && QM_TradeContextOpensExposure(request))
   {
      out_error_class = BROKER_NOT_ENOUGH_MONEY;
      QM_LogEvent(QM_WARN, BROKER_NOT_ENOUGH_MONEY,
                  StringFormat("{\"latched\":true,\"symbol\":\"%s\",\"action\":%d,\"magic\":%I64d}",
                               QM_LoggerEscapeJson(request.symbol),
                               (int)request.action,
                               request.magic));
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
      MqlDateTime latch_dt;
      TimeToStruct(TimeCurrent(), latch_dt);
      g_qm_trade_block_day_key = latch_dt.year * 1000 + latch_dt.day_of_year;
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
