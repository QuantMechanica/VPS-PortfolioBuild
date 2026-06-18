#property strict
#property version   "5.0"
#property description "QM5_12377 gbc-good-carry — Good-Carry (bad-carry-excluded) FX6 cross-sectional, D1"

// QuantMechanica V5 — QM5_12377 Good Carry Without Bad Carry Currencies.
//
// Source: Bekaert & Panayotov, "Good Carry, Bad Carry"
//   (Papers With Backtest / awesome-systematic-trading).
// Card: artifacts/cards_approved/QM5_12377_gbc-good-carry.md (g0_status APPROVED).
// Pattern: QM5_10718_edgelab-regime-filtered-carry (first V5 cross-sectional
//          carry basket EA) and QM5_10717_edgelab-xsec-fx-momentum.
//
// THESIS (card): keep the classic carry thesis (long high-yield / short
// low-yield FX) but EXCLUDE the prototypical "bad carry" currencies the paper
// flags (AUD, JPY, NOK), yielding a lower-skew carry book. Monthly rebalance,
// rank-loss exit.
//
// =========================================================================
//  ******  .DWX BACKTEST CARRY-EDGE FLAG — READ BEFORE TRUSTING RESULTS  ******
//  .DWX symbols apply $0 SWAP in the MT5 strategy tester (see MEMORY
//  "Backtests are cost-free 2026-05-29" and the deferred live_swap.json
//  research, "Swap research FTMO/DXZ/5pers — DEFERRED 2026-06-09"). The
//  *actual* carry edge (overnight interest / swap differential) is therefore
//  NOT MODELLED in any backtest. Ranking currencies by SYMBOL_SWAP_* would
//  read a flat 0 surface -> degenerate ranking -> zero or meaningless trades
//  (this is exactly why QM5_10718, which ranks by broker swap, generates no
//  trades in the tester).
//
//  REALIZATION CHOSEN: the carry edge is realized here as a PRICE/TREND
//  proxy — currencies that are *appreciating* are the ones carry capital is
//  flowing into ("carry follows trend"). We rank the allowed currencies by
//  their recent cross-sectional momentum (mean log return vs the other
//  allowed currencies over `strategy_mom_lookback` D1 bars) and run the same
//  long-top / short-bottom cross-sectional book the card specifies. This
//  trades in the tester and preserves the long-high / short-low STRUCTURE.
//
//  LIVE PROMOTION REQUIREMENT: the true swap/carry edge must be injected via
//  live_swap.json (deferred) before this EA's economic thesis is validated
//  live. The backtest proves the *trend realization* survives, not the swap
//  premium. Flagged in setfile_flags / SPEC.md / build_result open_questions.
// =========================================================================
//
// Mechanical, deterministic, no ML (Hard Rule 14). No grid, no martingale.
// One position per leg-magic. RISK_FIXED backtest / RISK_PERCENT live.

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12377;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;     // live = 0.25 (per leg) via setfile
input double RISK_FIXED                 = 1000.0;  // backtest = 1000 per leg
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = false;    // monthly carry swing holds over weekends
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_mom_lookback      = 63;     // carry-proxy momentum lookback (D1 bars, ~3 months)
input int    strategy_atr_period        = 20;     // per-leg hard-stop ATR period (card: ATR(20,D1))
input double strategy_atr_sl_mult       = 3.0;    // per-leg hard stop = 3.0 x ATR(20,D1) (card emergency stop)
input int    strategy_deviation_points  = 30;     // max execution slippage
input int    strategy_min_warmup_bars   = 260;    // card: minimum 260 D1 warmup bars

// --- Allowed "good carry" currency universe (AUD, JPY, NOK EXCLUDED) -------
// 6 allowed majors, fixed order. NOK has no DWX pair and is naturally absent.
const string QM12377_CCY[6] =
  {"USD","EUR","GBP","CHF","CAD","NZD"};

// All 15 direct DWX pairs spanning the 6 allowed currencies. Every
// (strong, weak) combination is directly routable, so no triangulation is
// ever required. Verified against framework/registry/dwx_symbol_matrix.csv.
const string QM12377_PAIRS[15] =
  {
   "EURUSD.DWX","GBPUSD.DWX","USDCHF.DWX","USDCAD.DWX","NZDUSD.DWX",
   "EURGBP.DWX","EURCHF.DWX","EURCAD.DWX","EURNZD.DWX","GBPCHF.DWX",
   "GBPCAD.DWX","GBPNZD.DWX","CADCHF.DWX","NZDCHF.DWX","NZDCAD.DWX"
  };

// Basket leg magic slots. Slot 0 is the framework identity magic; the two
// long-short legs use slots 1 and 2 (mirrors QM5_10718).
const int QM12377_LEG_SLOT[2] = {1, 2};

// Last-rebalanced calendar month (1..12); 0 = never. File-scope state advanced
// once per closed D1 bar through QM12377_IsNewMonth — NOT a per-EA new-bar gate
// (the framework QM_IsNewBar drives cadence; this only detects the month roll).
int g_qm12377_last_rebalance_month = 0;

//+------------------------------------------------------------------+
//| Resolve the DWX symbol carrying currency pair (base, quote).     |
//| out_inverted is TRUE when the symbol is quoted as quote/base.    |
//+------------------------------------------------------------------+
bool QM12377_FindPair(const string base, const string quote,
                      string &out_symbol, bool &out_inverted)
  {
   out_symbol = "";
   out_inverted = false;
   for(int i = 0; i < 15; ++i)
     {
      const string s = QM12377_PAIRS[i];
      const string b = StringSubstr(s, 0, 3);
      const string q = StringSubstr(s, 3, 3);
      if(b == base && q == quote)
        {
         out_symbol = s;
         out_inverted = false;
         return true;
        }
      if(b == quote && q == base)
        {
         out_symbol = s;
         out_inverted = true;
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Log return of holding LONG `base` vs `quote` over `lookback`     |
//| closed D1 bars (close[1] vs close[lookback+1]). This is the      |
//| PRICE/TREND carry proxy (see top-of-file flag); it replaces the  |
//| unmodellable broker-swap differential.                           |
//+------------------------------------------------------------------+
bool QM12377_PairReturn(const string base, const string quote,
                        const int lookback, double &out_ret)
  {
   out_ret = 0.0;
   string sym;
   bool inv;
   if(!QM12377_FindPair(base, quote, sym, inv))
      return false;

   // Closed-bar reads on D1 for the basket symbol. perf-allowed: bounded,
   // gated by the monthly-rebalance new-bar path, single reads (no per-tick).
   const double px_now = iClose(sym, PERIOD_D1, 1);             // perf-allowed
   const double px_old = iClose(sym, PERIOD_D1, lookback + 1);  // perf-allowed
   if(px_now <= 0.0 || px_old <= 0.0)
      return false;

   double r = MathLog(px_now / px_old);
   // Symbol quotes quote/base when inverted -> long base = short the symbol,
   // so flip the sign to express the return of holding LONG `base`.
   if(inv)
      r = -r;
   out_ret = r;
   return true;
  }

//+------------------------------------------------------------------+
//| Currency strength = mean trend-proxy return of a currency vs the |
//| other 5 allowed currencies. Returns FALSE on missing data or a   |
//| degenerate (flat) surface, so the EA never trades a meaningless  |
//| ranking.                                                         |
//+------------------------------------------------------------------+
bool QM12377_CurrencyStrength(double &strength[])
  {
   for(int i = 0; i < 6; ++i)
     {
      double sum = 0.0;
      int n = 0;
      for(int j = 0; j < 6; ++j)
        {
         if(i == j)
            continue;
         double r;
         if(!QM12377_PairReturn(QM12377_CCY[i], QM12377_CCY[j],
                                strategy_mom_lookback, r))
            return false;
         sum += r;
         n++;
        }
      if(n != 5)
         return false;
      strength[i] = sum / 5.0;
     }

   double mn = strength[0];
   double mx = strength[0];
   for(int i = 1; i < 6; ++i)
     {
      if(strength[i] < mn)
         mn = strength[i];
      if(strength[i] > mx)
         mx = strength[i];
     }
   return ((mx - mn) > 1e-9);
  }

//+------------------------------------------------------------------+
//| Flatten every position carrying this EA's magic block.           |
//+------------------------------------------------------------------+
void QM12377_CloseAll()
  {
   const long base = (long)qm_ea_id * 10000;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      const long m = PositionGetInteger(POSITION_MAGIC);
      if(m >= base && m <= base + 9)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

//+------------------------------------------------------------------+
//| Open one long-short leg: long `strongCcy` vs `weakCcy`, routing  |
//| the direct DWX pair. Hard stop = strategy_atr_sl_mult x ATR.     |
//+------------------------------------------------------------------+
bool QM12377_OpenLeg(const int slotIndex, const string strongCcy,
                     const string weakCcy)
  {
   string sym;
   bool inv;
   if(!QM12377_FindPair(strongCcy, weakCcy, sym, inv))
      return false;
   SymbolSelect(sym, true);

   QM_BasketOrderRequest req;
   // long strong vs weak: BUY strong/weak, or SELL when symbol is weak/strong.
   req.type = inv ? QM_SELL : QM_BUY;
   const double px = QM_BasketMarketPrice(sym, req.type);
   if(px <= 0.0)
      return false;
   const double sl = QM_StopATR(sym, req.type, px,
                                strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.symbol = sym;
   req.price = px;
   req.sl = sl;
   req.tp = 0.0;
   req.lots = 0.0;                          // auto-size to configured per-leg risk
   req.reason = StringFormat("GOODCARRY_%s%s", strongCcy, weakCcy);
   req.symbol_slot = QM12377_LEG_SLOT[slotIndex];
   req.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy,
                                strategy_deviation_points, req, ticket);
  }

//+------------------------------------------------------------------+
//| Monthly cross-sectional rank-and-rebalance.                      |
//| Rank-loss exit is implicit: every rebalance flattens the book    |
//| and re-opens only the current top/bottom currencies, so a leg    |
//| whose currency leaves the bucket is closed.                      |
//+------------------------------------------------------------------+
void QM12377_Rebalance()
  {
   QM12377_CloseAll();

   double strength[6];
   if(!QM12377_CurrencyStrength(strength))
     {
      QM_LogEvent(QM_WARN, "BASKET_REBALANCE",
                  "{\"action\":\"skip\",\"reason\":\"no_carry_signal\"}");
      return;
     }

   // Rank currency indices by strength, descending (bubble sort, n=6).
   int order[6];
   for(int i = 0; i < 6; ++i)
      order[i] = i;
   for(int a = 0; a < 5; ++a)
      for(int b = 0; b < 5 - a; ++b)
         if(strength[order[b]] < strength[order[b + 1]])
           {
            const int tmp = order[b];
            order[b] = order[b + 1];
            order[b + 1] = tmp;
           }

   const int s1 = order[0];   // strongest (top carry proxy)
   const int s2 = order[1];   // 2nd strongest
   const int w2 = order[4];   // 2nd weakest
   const int w1 = order[5];   // weakest (bottom carry proxy)

   // Two extreme-vs-extreme legs: long top-2 vs short bottom-2.
   const bool ok1 = QM12377_OpenLeg(0, QM12377_CCY[s1], QM12377_CCY[w1]);
   const bool ok2 = QM12377_OpenLeg(1, QM12377_CCY[s2], QM12377_CCY[w2]);

   const string payload = StringFormat(
      "{\"action\":\"rebalance\",\"proxy\":\"trend\","
      "\"long1\":\"%s\",\"short1\":\"%s\",\"long2\":\"%s\",\"short2\":\"%s\","
      "\"leg1_ok\":%s,\"leg2_ok\":%s,"
      "\"str_top\":%.8f,\"str_bot\":%.8f}",
      QM12377_CCY[s1], QM12377_CCY[w1], QM12377_CCY[s2], QM12377_CCY[w2],
      (ok1 ? "true" : "false"), (ok2 ? "true" : "false"),
      strength[s1], strength[w1]);
   QM_LogEvent(QM_INFO, "BASKET_REBALANCE", payload);
  }

//+------------------------------------------------------------------+
//| Detect the first closed D1 bar of a new calendar month. Uses the |
//| closed-bar open time (shift 1), NOT a per-EA timestamp gate —    |
//| the framework QM_IsNewBar already provides closed-bar cadence;   |
//| this only compares the month component.                          |
//+------------------------------------------------------------------+
bool QM12377_IsNewMonth()
  {
   const datetime bar_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed-bar read
   if(bar_time <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   if(dt.mon != g_qm12377_last_rebalance_month)
     {
      g_qm12377_last_rebalance_month = dt.mon;
      return (g_qm12377_last_rebalance_month != 0);
     }
   return false;
  }

//+------------------------------------------------------------------+
//| MT5 lifecycle                                                    |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   // FW9 — basket scope + history pre-load. The carry-proxy ranking reads
   // closes on all 15 basket pairs; without the warmup the tester returns 0
   // for foreign-symbol reads and the EA would never trade.
   string basket_list[15];
   for(int i = 0; i < 15; ++i)
      basket_list[i] = QM12377_PAIRS[i];
   QM_SymbolGuardInit(basket_list);
   QM_BasketWarmupHistory(basket_list, PERIOD_D1,
                          strategy_min_warmup_bars + strategy_mom_lookback + 20);

   g_qm12377_last_rebalance_month = 0;

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_12377_gbc-good-carry\",\"scope\":\"basket\","
               "\"carry_edge\":\"swap_unmodelled_in_backtest_trend_proxy\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

// -----------------------------------------------------------------------------
// Framework-named strategy sections (verifiable by build_check.ps1). This EA
// drives its book from OnTick's monthly-rebalance path, so the per-tick hooks
// are intentionally light; the named functions keep the framework contract.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news). Cross-sectional rebalance carries no
// per-tick spread gate; .DWX models zero spread so a spread guard here would
// never help and could only fail-closed. News handled centrally in OnTick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry — the entry decision is the monthly rebalance (see OnTick).
// Kept as a named hook for the framework contract; the basket book is opened
// via QM12377_Rebalance, not the single-entry QM_EntryRequest path.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   return false;
  }

// Trade Management — per-leg hard ATR stops are attached at open; the carry
// book is otherwise managed only at the monthly rebalance.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close — rank-loss / monthly exit is performed inside QM12377_Rebalance
// (flatten-then-reopen). No separate discretionary close.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook (callable for the Q09 News Impact phase). Defer to the
// central two-axis news filter evaluated in OnTick.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   // Light per-tick hooks (no-ops here) keep the framework section contract.
   Strategy_ManageOpenPosition();

   // Closed-bar cadence: consume the new-bar event ONCE.
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // Monthly cross-sectional carry rebalance on the first D1 bar of each month.
   if(QM12377_IsNewMonth())
      QM12377_Rebalance();
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
//+------------------------------------------------------------------+
