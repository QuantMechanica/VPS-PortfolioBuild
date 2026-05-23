#ifndef QM_ENTRY_MQH
#define QM_ENTRY_MQH

#include "QM_OrderTypes.mqh"
#include "QM_TradeContext.mqh"
#include "QM_KillSwitch.mqh"
#include "QM_NewsFilter.mqh"
#include "QM_RiskSizer.mqh"
#include "QM_MagicResolver.mqh"
#include "QM_Logger.mqh"
#include "QM_SeedRNG.mqh"

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
   QM_ENTRY_REJECTED_DUPLICATE,
   QM_ENTRY_REJECTED_STRESS       // FW2: Q06 HARSH simulated trade rejection
};

int                       g_qm_entry_ea_id              = 0;
QM_NewsMode               g_qm_entry_news_mode          = QM_NEWS_OFF;  // legacy
QM_NewsTemporalMode       g_qm_entry_news_temporal      = QM_NEWS_TEMPORAL_OFF;
QM_NewsComplianceProfile  g_qm_entry_news_compliance    = QM_NEWS_COMPLIANCE_NONE;
int                       g_qm_entry_deviation_points   = 20;
double                    g_qm_entry_stress_reject_prob = 0.0;   // FW2: Q06 HARSH default = 0.10

void QM_EntryConfigure(const int ea_id,
                       const QM_NewsMode news_mode = QM_NEWS_OFF,
                       const int deviation_points = 20,
                       const double stress_reject_probability = 0.0,
                       const QM_NewsTemporalMode news_temporal = QM_NEWS_TEMPORAL_OFF,
                       const QM_NewsComplianceProfile news_compliance = QM_NEWS_COMPLIANCE_NONE)
{
   g_qm_entry_ea_id = ea_id;
   g_qm_entry_news_mode = news_mode;
   g_qm_entry_news_temporal = news_temporal;
   g_qm_entry_news_compliance = news_compliance;
   g_qm_entry_deviation_points = (deviation_points > 0) ? deviation_points : 20;
   g_qm_entry_stress_reject_prob = (stress_reject_probability < 0.0) ? 0.0
                                  : ((stress_reject_probability > 1.0) ? 1.0 : stress_reject_probability);
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
      case QM_ENTRY_REJECTED_STRESS:     return "QM_ENTRY_REJECTED_STRESS";
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

   // FW1 2026-05-23: prefer 2-axis if either axis is non-default; otherwise
   // fall back to legacy single-mode (back-compat with pre-FW1 setfiles).
   bool news_allows = true;
   if(g_qm_entry_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      g_qm_entry_news_compliance != QM_NEWS_COMPLIANCE_NONE)
   {
      news_allows = QM_NewsAllowsTrade2(_Symbol, TimeCurrent(),
                                        g_qm_entry_news_temporal,
                                        g_qm_entry_news_compliance);
   }
   else
   {
      news_allows = QM_NewsAllowsTrade(_Symbol, TimeCurrent(), g_qm_entry_news_mode);
   }
   if(!news_allows)
   {
      QM_EntryLogReject(req, QM_ENTRY_REJECTED_NEWS, "news_filter_block");
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

   // FW2 (2026-05-23) — Q06 HARSH stress trade-rejection simulation.
   // When stress probability > 0, draw from the central seeded RNG (sub-stream
   // "entry_reject") and drop the entry deterministically. Q05 MED runs with
   // probability = 0 (this is a no-op); Q06 HARSH runs with probability = 0.10.
   // The reject happens *before* QM_TradeContextSend, so no broker round-trip
   // is wasted. Per-rejection log carries the magic + symbol for evidence.
   if(g_qm_entry_stress_reject_prob > 0.0 &&
      QM_RandBoolTagged("entry_reject", g_qm_entry_stress_reject_prob))
   {
      QM_EntryLogReject(req, QM_ENTRY_REJECTED_STRESS,
                        StringFormat("stress_reject_prob=%.4f", g_qm_entry_stress_reject_prob));
      return QM_ENTRY_REJECTED_STRESS;
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
