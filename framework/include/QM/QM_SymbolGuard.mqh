#ifndef QM_SYMBOL_GUARD_MQH
#define QM_SYMBOL_GUARD_MQH

// V5 Framework — Symbol Guard.
//
// Created 2026-05-23 (FW7) after the Q02 hang investigation revealed that
// several "single-symbol" EAs were silently fanning iClose / iTime / Bars
// calls across multiple symbols, forcing the tester to load history for
// symbols the strategy was never meant to touch.
//
// Contract:
//   * Default: EAs are single-symbol. QM_FrameworkInit calls
//     QM_SymbolGuardInitSingle() so the allowed set is {_Symbol}.
//   * Basket / portfolio EAs MUST opt in by calling QM_SymbolGuardInit(...)
//     with the explicit symbol list AFTER QM_FrameworkInit, and SHOULD ship a
//     `basket_manifest.json` next to the .mq5 documenting the list.
//   * Runtime call sites that read foreign-symbol data should pass through
//     QM_SymbolAssertOrLog(symbol). The first violation per (symbol)
//     emits SYMBOL_GUARD_VIOLATION at QM_WARN; subsequent calls are
//     silent (throttled, one log per offending symbol per session).
//
// This module does NOT block MT5's iClose/iTime/CopyXxx calls — the only
// way to truly prevent data-load for a foreign symbol is to not call those
// functions in the first place. The runtime guard surfaces violations so
// the static build-time validator (Codex audit) and operator can fix the
// .mq5 source; the asserter log gives us evidence per EA.

#include "QM_Errors.mqh"
#include "QM_Logger.mqh"

string g_qm_sg_allowed_symbols[];
int    g_qm_sg_allowed_count       = 0;
bool   g_qm_sg_is_basket           = false;
string g_qm_sg_violations_seen[];   // throttle log keys (symbol)
int    g_qm_sg_violations_count    = 0;

void QM_SymbolGuardReset()
  {
   ArrayResize(g_qm_sg_allowed_symbols, 0);
   g_qm_sg_allowed_count = 0;
   ArrayResize(g_qm_sg_violations_seen, 0);
   g_qm_sg_violations_count = 0;
   g_qm_sg_is_basket = false;
  }

void QM_SymbolGuardInitSingle()
  {
   QM_SymbolGuardReset();
   ArrayResize(g_qm_sg_allowed_symbols, 1);
   g_qm_sg_allowed_symbols[0] = _Symbol;
   g_qm_sg_allowed_count = 1;
   g_qm_sg_is_basket = false;
   QM_LogEvent(QM_INFO, "SYMBOL_GUARD_INIT",
               StringFormat("{\"mode\":\"single\",\"symbol\":\"%s\"}", _Symbol));
  }

void QM_SymbolGuardInit(const string &allowed[])
  {
   QM_SymbolGuardReset();
   const int n = ArraySize(allowed);
   ArrayResize(g_qm_sg_allowed_symbols, n);
   for(int i = 0; i < n; i++)
      g_qm_sg_allowed_symbols[i] = allowed[i];
   g_qm_sg_allowed_count = n;
   g_qm_sg_is_basket = (n > 1);

   // Build a compact symbol list for the log payload.
   string list_json = "[";
   for(int i = 0; i < n; i++)
     {
      if(i > 0) list_json += ",";
      list_json += "\"" + QM_LoggerEscapeJson(allowed[i]) + "\"";
     }
   list_json += "]";
   QM_LogEvent(QM_INFO, "SYMBOL_GUARD_INIT",
               StringFormat("{\"mode\":\"%s\",\"n_symbols\":%d,\"symbols\":%s}",
                            g_qm_sg_is_basket ? "basket" : "single", n, list_json));
  }

bool QM_SymbolAllowed(const string symbol)
  {
   if(g_qm_sg_allowed_count == 0)
      return true; // guard not initialized → permissive (legacy EAs)
   for(int i = 0; i < g_qm_sg_allowed_count; i++)
      if(g_qm_sg_allowed_symbols[i] == symbol)
         return true;
   return false;
  }

bool QM_SymbolGuardIsBasket()
  {
   return g_qm_sg_is_basket;
  }

int QM_SymbolGuardCount()
  {
   return g_qm_sg_allowed_count;
  }

// Returns true if symbol is permitted; otherwise logs a throttled
// SYMBOL_GUARD_VIOLATION and returns false. Caller decides what to do
// with the verdict (skip the call, allow with warning logged, etc.).
bool QM_SymbolAssertOrLog(const string symbol)
  {
   if(QM_SymbolAllowed(symbol))
      return true;

   // Throttle: one log per offending symbol per session.
   for(int i = 0; i < g_qm_sg_violations_count; i++)
      if(g_qm_sg_violations_seen[i] == symbol)
         return false;

   ArrayResize(g_qm_sg_violations_seen, g_qm_sg_violations_count + 1);
   g_qm_sg_violations_seen[g_qm_sg_violations_count] = symbol;
   g_qm_sg_violations_count++;

   QM_LogEvent(QM_WARN, "SYMBOL_GUARD_VIOLATION",
               StringFormat("{\"requested_symbol\":\"%s\",\"chart_symbol\":\"%s\",\"allowed_count\":%d,\"is_basket\":%s}",
                            QM_LoggerEscapeJson(symbol),
                            _Symbol,
                            g_qm_sg_allowed_count,
                            g_qm_sg_is_basket ? "true" : "false"));
   return false;
  }

#endif // QM_SYMBOL_GUARD_MQH
