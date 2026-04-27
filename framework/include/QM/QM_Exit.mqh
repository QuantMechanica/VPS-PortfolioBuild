#ifndef QM_EXIT_MQH
#define QM_EXIT_MQH

#include "QM_Logger.mqh"
#include "QM_TradeContext.mqh"

// V5 Framework Step 13:
// Standardized position close path with named exit reasons and Friday close defaults.

enum QM_ExitReason
  {
   QM_EXIT_TP_HIT = 0,
   QM_EXIT_SL_HIT = 1,
   QM_EXIT_TRAILING = 2,
   QM_EXIT_BREAK_EVEN = 3,
   QM_EXIT_TIME_STOP = 4,
   QM_EXIT_FRIDAY_CLOSE = 5,
   QM_EXIT_NEWS_EXIT = 6,
   QM_EXIT_KILLSWITCH = 7,
   QM_EXIT_MANUAL = 8,
   QM_EXIT_OPPOSITE_SIGNAL = 9,
   QM_EXIT_STRATEGY = 10,
   QM_EXIT_PARTIAL = 11
  };

bool g_qm_exit_initialized             = false;
long g_qm_exit_magic                   = 0;
bool g_qm_exit_friday_close_enabled    = true;
int  g_qm_exit_friday_close_hour       = 21;
int  g_qm_exit_friday_close_warn_hours = 1;
int  g_qm_exit_last_warn_day_key       = -1;
int  g_qm_exit_last_sweep_day_key      = -1;

string QM_ExitReasonToString(const QM_ExitReason reason)
  {
   switch(reason)
     {
      case QM_EXIT_TP_HIT:          return "QM_EXIT_TP_HIT";
      case QM_EXIT_SL_HIT:          return "QM_EXIT_SL_HIT";
      case QM_EXIT_TRAILING:        return "QM_EXIT_TRAILING";
      case QM_EXIT_BREAK_EVEN:      return "QM_EXIT_BREAK_EVEN";
      case QM_EXIT_TIME_STOP:       return "QM_EXIT_TIME_STOP";
      case QM_EXIT_FRIDAY_CLOSE:    return "QM_EXIT_FRIDAY_CLOSE";
      case QM_EXIT_NEWS_EXIT:       return "QM_EXIT_NEWS_EXIT";
      case QM_EXIT_KILLSWITCH:      return "QM_EXIT_KILLSWITCH";
      case QM_EXIT_MANUAL:          return "QM_EXIT_MANUAL";
      case QM_EXIT_OPPOSITE_SIGNAL: return "QM_EXIT_OPPOSITE_SIGNAL";
      case QM_EXIT_STRATEGY:        return "QM_EXIT_STRATEGY";
      case QM_EXIT_PARTIAL:         return "QM_EXIT_PARTIAL";
     }

   return "QM_EXIT_STRATEGY";
  }

int QM_ExitDayKey(const datetime broker_time)
  {
   MqlDateTime t;
   TimeToStruct(broker_time, t);
   return (t.year * 1000 + t.day_of_year);
  }

int QM_ExitDayOfWeek(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.day_of_week;
  }

int QM_ExitHour(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour;
  }

int QM_ExitVolumeDigits(const double volume_step)
  {
   if(volume_step <= 0.0)
      return 2;

   int digits = 0;
   double probe = volume_step;
   while(digits < 8 && MathAbs(probe - MathRound(probe)) > 1e-10)
     {
      probe *= 10.0;
      ++digits;
     }
   return digits;
  }

ENUM_ORDER_TYPE_FILLING QM_ExitResolveFilling(const string symbol)
  {
   const long fill_flags = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   if((fill_flags & SYMBOL_FILLING_FOK) != 0)
      return ORDER_FILLING_FOK;
   if((fill_flags & SYMBOL_FILLING_IOC) != 0)
      return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
  }

bool QM_ExitResolveLots(const ulong ticket,
                        const double requested_lots,
                        double &close_lots,
                        bool &is_partial)
  {
   close_lots = 0.0;
   is_partial = false;

   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;

   const string symbol = PositionGetString(POSITION_SYMBOL);
   const double position_lots = PositionGetDouble(POSITION_VOLUME);
   if(position_lots <= 0.0)
      return false;

   if(requested_lots <= 0.0 || requested_lots >= position_lots)
     {
      close_lots = position_lots;
      is_partial = false;
      return true;
     }

   const double volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   const double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const int volume_digits = QM_ExitVolumeDigits(volume_step);
   double normalized = requested_lots;

   if(volume_step > 0.0)
      normalized = MathFloor(requested_lots / volume_step) * volume_step;
   normalized = NormalizeDouble(normalized, volume_digits);

   if(normalized < min_lot)
      return false;

   if(normalized >= position_lots)
     {
      close_lots = position_lots;
      is_partial = false;
      return true;
     }

   close_lots = normalized;
   is_partial = true;
   return true;
  }

bool QM_ExitBuildRequest(const ulong ticket,
                         const double close_lots,
                         MqlTradeRequest &request)
  {
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;
   if(close_lots <= 0.0)
      return false;

   ZeroMemory(request);
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = symbol;
   request.volume = close_lots;
   request.magic = g_qm_exit_magic;
   request.type_filling = QM_ExitResolveFilling(symbol);

   if(pos_type == POSITION_TYPE_BUY)
     {
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(symbol, SYMBOL_BID);
      return (request.price > 0.0);
     }

   if(pos_type == POSITION_TYPE_SELL)
     {
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(symbol, SYMBOL_ASK);
      return (request.price > 0.0);
     }

   return false;
  }

bool QM_ExitInit(const long init_magic,
                 const bool init_friday_close_enabled = true,
                 const int init_friday_close_hour_broker = 21,
                 const int init_friday_close_warn_hours = 1)
  {
   g_qm_exit_magic = init_magic;
   g_qm_exit_friday_close_enabled = init_friday_close_enabled;
   g_qm_exit_friday_close_hour = MathMin(23, MathMax(0, init_friday_close_hour_broker));
   g_qm_exit_friday_close_warn_hours = MathMax(0, init_friday_close_warn_hours);
   g_qm_exit_last_warn_day_key = -1;
   g_qm_exit_last_sweep_day_key = -1;
   g_qm_exit_initialized = true;

   QM_LogEvent(QM_INFO,
               "EXIT_INIT",
               StringFormat("{\"magic\":%I64d,\"friday_close_enabled\":%s,\"friday_close_hour_broker\":%d,\"friday_close_warn_hours\":%d}",
                            g_qm_exit_magic,
                            g_qm_exit_friday_close_enabled ? "true" : "false",
                            g_qm_exit_friday_close_hour,
                            g_qm_exit_friday_close_warn_hours));
   return true;
  }

bool QM_ExitFridayCloseDue(datetime broker_time = 0)
  {
   if(!g_qm_exit_initialized || !g_qm_exit_friday_close_enabled)
      return false;
   if(broker_time <= 0)
      broker_time = TimeCurrent();

   if(QM_ExitDayOfWeek(broker_time) != 5)
      return false;
   return (QM_ExitHour(broker_time) >= g_qm_exit_friday_close_hour);
  }

bool QM_ExitFridayClosePending(datetime broker_time = 0)
  {
   if(!g_qm_exit_initialized || !g_qm_exit_friday_close_enabled || g_qm_exit_friday_close_warn_hours <= 0)
      return false;
   if(broker_time <= 0)
      broker_time = TimeCurrent();

   if(QM_ExitDayOfWeek(broker_time) != 5)
      return false;

   const int hour = QM_ExitHour(broker_time);
   if(hour < (g_qm_exit_friday_close_hour - g_qm_exit_friday_close_warn_hours) || hour >= g_qm_exit_friday_close_hour)
      return false;

   const int day_key = QM_ExitDayKey(broker_time);
   if(g_qm_exit_last_warn_day_key == day_key)
      return true;

   g_qm_exit_last_warn_day_key = day_key;
   QM_LogEvent(QM_WARN,
               "FRIDAY_CLOSE_PENDING",
               StringFormat("{\"day_key\":%d,\"hour\":%d,\"friday_close_hour_broker\":%d,\"warn_hours\":%d}",
                            day_key,
                            hour,
                            g_qm_exit_friday_close_hour,
                            g_qm_exit_friday_close_warn_hours));
   return true;
  }

bool QM_Exit(const ulong ticket, const QM_ExitReason reason, const double partial_lots = 0.0)
  {
   if(!g_qm_exit_initialized)
      QM_ExitInit(0, true, 21, 1);

   if(ticket == 0 || !PositionSelectByTicket(ticket))
     {
      QM_LogEvent(QM_ERROR,
                  "EXIT_FAILED",
                  StringFormat("{\"ticket\":%I64u,\"reason\":\"%s\",\"detail\":\"POSITION_NOT_FOUND\"}",
                               ticket,
                               QM_LoggerEscapeJson(QM_ExitReasonToString(reason))));
      return false;
     }

   const string symbol = PositionGetString(POSITION_SYMBOL);
   const double before_lots = PositionGetDouble(POSITION_VOLUME);

   double close_lots = 0.0;
   bool is_partial = false;
   if(!QM_ExitResolveLots(ticket, partial_lots, close_lots, is_partial))
     {
      QM_LogEvent(QM_ERROR,
                  "EXIT_FAILED",
                  StringFormat("{\"ticket\":%I64u,\"symbol\":\"%s\",\"reason\":\"%s\",\"requested_lots\":%.8f,\"detail\":\"INVALID_CLOSE_VOLUME\"}",
                               ticket,
                               QM_LoggerEscapeJson(symbol),
                               QM_LoggerEscapeJson(QM_ExitReasonToString(reason)),
                               partial_lots));
      return false;
     }

   MqlTradeRequest request;
   if(!QM_ExitBuildRequest(ticket, close_lots, request))
     {
      QM_LogEvent(QM_ERROR,
                  "EXIT_FAILED",
                  StringFormat("{\"ticket\":%I64u,\"symbol\":\"%s\",\"reason\":\"%s\",\"close_lots\":%.8f,\"detail\":\"REQUEST_BUILD_FAILED\"}",
                               ticket,
                               QM_LoggerEscapeJson(symbol),
                               QM_LoggerEscapeJson(QM_ExitReasonToString(reason)),
                               close_lots));
      return false;
     }

   MqlTradeResult result;
   string trade_error_class = "";
   const bool ok = QM_TradeContextSend(request, result, trade_error_class);
   const double remaining_lots = MathMax(0.0, before_lots - close_lots);

   if(!ok)
     {
      QM_LogEvent(QM_ERROR,
                  "EXIT_FAILED",
                  StringFormat("{\"ticket\":%I64u,\"symbol\":\"%s\",\"reason\":\"%s\",\"requested_lots\":%.8f,\"close_lots\":%.8f,\"retcode\":%u,\"retcode_desc\":\"%s\"}",
                               ticket,
                               QM_LoggerEscapeJson(symbol),
                               QM_LoggerEscapeJson(QM_ExitReasonToString(reason)),
                               partial_lots,
                               close_lots,
                               result.retcode,
                               QM_LoggerEscapeJson(result.comment)));
      return false;
     }

   const string effective_reason = is_partial ? QM_ExitReasonToString(QM_EXIT_PARTIAL) : QM_ExitReasonToString(reason);
   QM_LogEvent(QM_INFO,
               "EXIT",
               StringFormat("{\"ticket\":%I64u,\"symbol\":\"%s\",\"reason\":\"%s\",\"requested_reason\":\"%s\",\"partial\":%s,\"requested_lots\":%.8f,\"closed_lots\":%.8f,\"remaining_lots_est\":%.8f,\"retcode\":%u,\"order\":%I64u,\"deal\":%I64u}",
                            ticket,
                            QM_LoggerEscapeJson(symbol),
                            QM_LoggerEscapeJson(effective_reason),
                            QM_LoggerEscapeJson(QM_ExitReasonToString(reason)),
                            is_partial ? "true" : "false",
                            partial_lots,
                            close_lots,
                            remaining_lots,
                            result.retcode,
                            result.order,
                            result.deal));
   return true;
  }

int QM_ExitFridayCloseSweep(datetime broker_time = 0)
  {
   if(!g_qm_exit_initialized || !g_qm_exit_friday_close_enabled)
      return 0;
   if(broker_time <= 0)
      broker_time = TimeCurrent();

   QM_ExitFridayClosePending(broker_time);
   if(!QM_ExitFridayCloseDue(broker_time))
      return 0;

   const int day_key = QM_ExitDayKey(broker_time);
   if(g_qm_exit_last_sweep_day_key == day_key)
      return 0;
   g_qm_exit_last_sweep_day_key = day_key;

   int attempted = 0;
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(g_qm_exit_magic > 0 && PositionGetInteger(POSITION_MAGIC) != g_qm_exit_magic)
         continue;

      ++attempted;
      if(QM_Exit(ticket, QM_EXIT_FRIDAY_CLOSE))
         ++closed;
     }

   QM_LogEvent(QM_INFO,
               "FRIDAY_CLOSE_SWEEP",
               StringFormat("{\"day_key\":%d,\"attempted\":%d,\"closed\":%d,\"magic\":%I64d}",
                            day_key,
                            attempted,
                            closed,
                            g_qm_exit_magic));
   return closed;
  }

#endif // QM_EXIT_MQH
