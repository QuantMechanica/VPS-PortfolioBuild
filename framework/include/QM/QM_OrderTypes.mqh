#ifndef QM_ORDER_TYPES_MQH
#define QM_ORDER_TYPES_MQH

// V5 Framework Step 09:
// Typed wrappers around MT5 order types to remove raw enum usage from EA logic.
enum QM_OrderType
  {
   QM_BUY = 0,
   QM_SELL = 1,
   QM_BUY_LIMIT = 2,
   QM_SELL_LIMIT = 3,
   QM_BUY_STOP = 4,
   QM_SELL_STOP = 5
  };

bool QM_OrderTypeIsBuy(const QM_OrderType t)
  {
   return (t == QM_BUY || t == QM_BUY_LIMIT || t == QM_BUY_STOP);
  }

bool QM_OrderTypeIsLimit(const QM_OrderType t)
  {
   return (t == QM_BUY_LIMIT || t == QM_SELL_LIMIT);
  }

bool QM_OrderTypeIsStop(const QM_OrderType t)
  {
   return (t == QM_BUY_STOP || t == QM_SELL_STOP);
  }

ENUM_ORDER_TYPE QM_OrderTypeToMT5(const QM_OrderType t)
  {
   switch(t)
     {
      case QM_BUY:        return ORDER_TYPE_BUY;
      case QM_SELL:       return ORDER_TYPE_SELL;
      case QM_BUY_LIMIT:  return ORDER_TYPE_BUY_LIMIT;
      case QM_SELL_LIMIT: return ORDER_TYPE_SELL_LIMIT;
      case QM_BUY_STOP:   return ORDER_TYPE_BUY_STOP;
      case QM_SELL_STOP:  return ORDER_TYPE_SELL_STOP;
     }

   return ORDER_TYPE_BUY;
  }

QM_OrderType QM_OrderTypeFromMT5(const ENUM_ORDER_TYPE t)
  {
   switch(t)
     {
      case ORDER_TYPE_BUY:        return QM_BUY;
      case ORDER_TYPE_SELL:       return QM_SELL;
      case ORDER_TYPE_BUY_LIMIT:  return QM_BUY_LIMIT;
      case ORDER_TYPE_SELL_LIMIT: return QM_SELL_LIMIT;
      case ORDER_TYPE_BUY_STOP:   return QM_BUY_STOP;
      case ORDER_TYPE_SELL_STOP:  return QM_SELL_STOP;
     }

   return QM_BUY;
  }

string QM_OrderTypeToString(const QM_OrderType t)
  {
   switch(t)
     {
      case QM_BUY:        return "QM_BUY";
      case QM_SELL:       return "QM_SELL";
      case QM_BUY_LIMIT:  return "QM_BUY_LIMIT";
      case QM_SELL_LIMIT: return "QM_SELL_LIMIT";
      case QM_BUY_STOP:   return "QM_BUY_STOP";
      case QM_SELL_STOP:  return "QM_SELL_STOP";
     }

   return "QM_BUY";
  }

#endif // QM_ORDER_TYPES_MQH
