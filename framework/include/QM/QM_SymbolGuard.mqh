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

// FW9 2026-05-24 — basket history pre-load. Pre-fix, basket EAs like
// QM5_10717/10718 called SymbolSelect(symbol, true) in OnInit which only
// adds the symbol to Market Watch — the MT5 tester does NOT load that
// symbol's history into the testing context. First per-symbol iClose
// then returned 0 or stale data, the strategy made no decisions, MT5
// fast-finished, run_smoke flagged NO_REAL_TICKS_MARKER_FAST_FINISH ->
// INVALID. Fix: after SymbolSelect, force MT5 to load `warmup_bars` of
// history per symbol via CopyClose. The CopyClose itself triggers the
// tester's symbol-data sync; the returned data is not used.
//
// Call after QM_SymbolGuardInit(basket) in the EA's OnInit. Safe to call
// outside the tester too (live mode will just confirm history is loaded).
void QM_BasketWarmupHistory(const string &symbols[],
                             const ENUM_TIMEFRAMES tf = PERIOD_CURRENT,
                             const int warmup_bars = 300)
  {
   const int n = ArraySize(symbols);
   const ENUM_TIMEFRAMES effective_tf = (tf == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : tf;
   int loaded_count = 0;
   int skipped_count = 0;
   for(int i = 0; i < n; i++)
     {
      const string sym = symbols[i];
      if(StringLen(sym) == 0)
         continue;
      if(!SymbolSelect(sym, true))
        {
         skipped_count++;
         continue;
        }
      // Force history load. Result is discarded; we just need the side effect.
      double buf[];
      const int got = CopyClose(sym, effective_tf, 0, warmup_bars, buf);
      if(got > 0)
         loaded_count++;
      else
         skipped_count++;
     }
   QM_LogEvent(QM_INFO, "BASKET_WARMUP",
               StringFormat("{\"requested\":%d,\"loaded\":%d,\"skipped\":%d,\"warmup_bars\":%d,\"tf\":%d}",
                            n, loaded_count, skipped_count, warmup_bars, (int)effective_tf));
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
