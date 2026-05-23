#property strict
#property version   "5.0"
#property description "QM5_1091 Quantpedia FX Carry Rates"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1091;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_atr_period        = 20;
input double strategy_atr_sl_mult       = 5.0;
input int    strategy_spread_days       = 20;
input double strategy_spread_mult       = 3.0;
input int    strategy_rebalance_hour    = 1;
input double strategy_rate_usd          = 5.25;
input double strategy_rate_eur          = 4.50;
input double strategy_rate_gbp          = 5.25;
input double strategy_rate_jpy          = 0.10;
input double strategy_rate_aud          = 4.35;
input double strategy_rate_cad          = 5.00;
input double strategy_rate_chf          = 1.75;
input double strategy_rate_nzd          = 5.50;

int g_last_entry_rebalance_ym = 0;
int g_last_exit_rebalance_ym = 0;

int CurrencyIndex(const string ccy)
  {
   if(ccy == "USD") return 0;
   if(ccy == "EUR") return 1;
   if(ccy == "GBP") return 2;
   if(ccy == "JPY") return 3;
   if(ccy == "AUD") return 4;
   if(ccy == "CAD") return 5;
   if(ccy == "CHF") return 6;
   if(ccy == "NZD") return 7;
   return -1;
  }

double CurrencyRateByIndex(const int idx)
  {
   if(idx == 0) return strategy_rate_usd;
   if(idx == 1) return strategy_rate_eur;
   if(idx == 2) return strategy_rate_gbp;
   if(idx == 3) return strategy_rate_jpy;
   if(idx == 4) return strategy_rate_aud;
   if(idx == 5) return strategy_rate_cad;
   if(idx == 6) return strategy_rate_chf;
   if(idx == 7) return strategy_rate_nzd;
   return 0.0;
  }

int CurrencyRankHighToLow(const int idx)
  {
   if(idx < 0)
      return 99;

   const double rate = CurrencyRateByIndex(idx);
   int rank = 1;
   for(int i = 0; i < 8; ++i)
     {
      if(i == idx)
         continue;
      const double other = CurrencyRateByIndex(i);
      if(other > rate || (other == rate && i < idx))
         rank++;
     }
   return rank;
  }

int RebalanceYm()
  {
   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   return (now_dt.year * 100 + now_dt.mon);
  }

bool IsMonthlyRebalanceBar()
  {
   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   if(now_dt.day != 1 || now_dt.hour < strategy_rebalance_hour)
      return false;
   return true;
  }

int SymbolCarryDirection()
  {
   string root = _Symbol;
   const int dot_pos = StringFind(root, ".");
   if(dot_pos > 0)
      root = StringSubstr(root, 0, dot_pos);
   if(StringLen(root) < 6)
      return 0;

   const string base = StringSubstr(root, 0, 3);
   const string quote = StringSubstr(root, 3, 3);
   string non_usd = "";
   bool inverse_quoted = false;

   if(base == "USD")
     {
      non_usd = quote;
      inverse_quoted = true;
     }
   else if(quote == "USD")
     {
      non_usd = base;
      inverse_quoted = false;
     }
   else
      return 0;

   const int rank = CurrencyRankHighToLow(CurrencyIndex(non_usd));
   if(rank <= 3)
      return inverse_quoted ? -1 : 1;
   if(rank >= 6)
      return inverse_quoted ? 1 : -1;
   return 0;
  }

bool SpreadAllowsEntry()
  {
   if(strategy_spread_days <= 0 || strategy_spread_mult <= 0.0)
      return true;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, strategy_spread_days, rates); // perf-allowed: called only from closed-bar Strategy_EntrySignal().
   if(copied <= 0)
      return true;

   int spreads[];
   ArrayResize(spreads, copied);
   int count = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread > 0)
        {
         spreads[count] = rates[i].spread;
         count++;
        }
     }
   if(count <= 0)
      return true;

   ArrayResize(spreads, count);
   ArraySort(spreads);
   const double median = (count % 2 == 1)
                         ? (double)spreads[count / 2]
                         : ((double)spreads[(count / 2) - 1] + (double)spreads[count / 2]) / 2.0;
   const double current = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (median <= 0.0 || current <= strategy_spread_mult * median);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   if(now_dt.day == 1 && now_dt.hour < strategy_rebalance_hour)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!IsMonthlyRebalanceBar())
      return false;

   const int ym = RebalanceYm();
   if(ym == g_last_entry_rebalance_ym)
      return false;

   const int direction = SymbolCarryDirection();
   if(direction == 0 || !SpreadAllowsEntry())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = (direction > 0) ? ask : bid;
   req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = (direction > 0) ? "QP_FX_CARRY_TOP3_LONG" : "QP_FX_CARRY_BOTTOM3_SHORT";
   if(req.sl <= 0.0)
      return false;

   g_last_entry_rebalance_ym = ym;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: no trailing, partial close, or break-even rule in the card.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!IsMonthlyRebalanceBar())
      return false;

   const int ym = RebalanceYm();
   if(ym == g_last_exit_rebalance_ym)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      g_last_exit_rebalance_ym = ym;
      return true;
     }
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: central-bank event handling is delegated to the framework calendar mode.
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
