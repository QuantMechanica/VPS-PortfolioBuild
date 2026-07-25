#ifndef QM_BASKET_ORDER_MQH
#define QM_BASKET_ORDER_MQH

#include "QM_OrderTypes.mqh"
#include "QM_TradeContext.mqh"
#include "QM_KillSwitch.mqh"
#include "QM_NewsFilter.mqh"
#include "QM_RiskSizer.mqh"
#include "QM_MagicResolver.mqh"
#include "QM_Logger.mqh"
#include "QM_SeedRNG.mqh"   // WP-9: central seeded RNG for the stress-rejection hook
#include "QM_Entry.mqh"     // WP-9: shared stress-reject probability (g_qm_entry_stress_reject_prob, set by QM_EntryConfigure)

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

double QM_BasketNormalizeLots(const string symbol, const double raw_lots)
{
   QM_SymbolRiskSnapshot snapshot;
   if(!QM_RiskSizerReadSymbolSnapshot(symbol, snapshot))
      return 0.0;
   return QM_RiskSizerQuantizeLots(raw_lots,
                                   snapshot.volume_min,
                                   snapshot.volume_max,
                                   snapshot.volume_step);
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

   // FW2 (2026-05-23) — Q06 HARSH stress trade-rejection simulation, basket path.
   // WP-9 (2026-07-25): until now QM_BasketOpenPosition reached QM_TradeContextSend
   // with no RNG, so for every basket EA Q06's 10% rejection was a no-op and Q07 could
   // not diverge across seeds — the real legs open here while the standard-order hook
   // (QM_Entry.mqh) never fires. This mirrors that hook: the same central seeded RNG,
   // the same "entry_reject" sub-stream, and the same probability global
   // (g_qm_entry_stress_reject_prob, set once via QM_EntryConfigure in QM_FrameworkInit;
   // Q05 MED and live run at 0.0 = no-op, Q06/Q07 run at 0.10). Placement is AFTER the
   // kill-switch/news/duplicate safety checks so a stress reject can never mask a safety
   // reject, and BEFORE price/lot resolution and QM_TradeContextSend so no broker
   // round-trip is wasted.
   //
   // WP-9 REVISED (2026-07-25, after Codex CHANGES-REQUIRED review). Granularity is
   // ONE DRAW PER BASKET TRANSACTION, not per leg. Scar tissue — the first cut drew
   // once per leg and assumed every caller rolls a partial spread back. Two shipped
   // callers do NOT: QM5_10009 loops three legs on `any_opened` with an EMPTY
   // ManageOpenPosition, and QM5_10025 treats either pair leg as a valid entry. For
   // those "any-open" callers a per-leg reject does not net to all-or-nothing — the
   // dominant event is a CORRUPTED PARTIAL package (at p=0.10 the whole two-leg entry
   // is rejected by this hook alone with only p^2=1%, but a lopsided half-spread is
   // far more likely), which is strictly worse than the clean whole-basket reject the
   // gate intends. The per-leg cut also STACKED a second draw on QM5_20123, which
   // already preflights every member with its own "entry_reject" draw: 0.9^4 = 34.4%
   // reject instead of the intended ~19%.
   //
   // The fix: draw ONCE per logical basket and memoize the verdict in static state
   // keyed on (ea_id, TimeCurrent()). Verified per-caller (10009/10025/20123/12821/
   // 12778/13117/13140/10309): every basket caller opens ALL of its legs inside a
   // single OnTick, and MT5 does not advance TimeCurrent() within one OnTick execution
   // (it is the last-known server time, refreshed only between incoming ticks), and each
   // caller is new-bar gated + guarded against a second concurrent basket. So the first
   // leg of an entry draws; every later leg of the SAME entry (same ea_id, same tick)
   // reuses that one verdict. That gives all-or-nothing for EVERY caller BY CONSTRUCTION
   // — 10009's three legs now all open or none open, with no rollback code required —
   // restores single-order semantics (one logical entry, ONE draw at p, cleaner than the
   // previous 1-(1-p)^legs which over-rejected multi-leg baskets), and consumes exactly
   // ONE RNG stream advance per basket instead of one per leg.
   //
   // Key = (ea_id, TimeCurrent()). It deliberately EXCLUDES symbol/symbol_slot: legs of
   // one basket carry different slots and therefore different magics (magic = ea_id*10000
   // + slot), but must share the verdict — keying on the per-leg magic would re-introduce
   // the per-leg bug. ea_id is the EA-level identity, identical across every leg (each
   // caller passes a constant qm_ea_id); we use the parameter directly rather than
   // re-deriving ea_id = magic/10000 (same value, available here without coupling to the
   // magic formula). Static hygiene: MQL5 zero-inits the memo at the start of each tester
   // pass (s_memo_ea_id = 0) and ea_id is > 0 here (guarded above), so the initial key
   // can never collide with a real basket; the (ea_id, time) compare also forces a redraw
   // for any new bar, so a stale memo from a prior bar is never leaked. At p=0.0 the whole
   // block is skipped — no draw, no static touched — so Q05 MED / live determinism and RNG
   // cursor position are byte-identical to a no-hook build.
   //
   // RESOLVED (2026-07-25) — QM5_20123 double-stress. QM5_20123 previously ran its
   // OWN per-member "entry_reject" preflight (2 draws for its 2 members) ON TOP of this
   // basket draw, so a two-member package accepted with only 0.9^2 * 0.9 = 0.9^3 = 72.9%
   // (27.1% reject) instead of the intended single-draw 90%. That redundant preflight has
   // now been removed from QM5_20123_dailyopen-h1-basket.mq5 (its news gate is retained),
   // so this memoized basket hook is the SOLE stress rail for that EA. Every sampled
   // caller now draws ONLY here.
   if(g_qm_entry_stress_reject_prob > 0.0)
   {
      static int      s_memo_ea_id  = 0;
      static datetime s_memo_time   = 0;
      static bool     s_memo_reject = false;
      const datetime now = TimeCurrent();
      if(s_memo_ea_id != ea_id || s_memo_time != now)
      {
         // First leg of this basket transaction: one draw, memoized for the rest.
         s_memo_ea_id  = ea_id;
         s_memo_time   = now;
         s_memo_reject = QM_RandBoolTagged("entry_reject", g_qm_entry_stress_reject_prob);
      }
      if(s_memo_reject)
      {
         QM_BasketLogReject(req, "QM_BASKET_REJECTED_STRESS",
                            StringFormat("stress_reject_prob=%.4f", g_qm_entry_stress_reject_prob));
         return false;
      }
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
   if(lots > 0.0)
      lots = QM_BasketNormalizeLots(req.symbol, lots);
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
   trade_req.type_filling = QM_TradeContextResolveRequestFilling(trade_req);
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
