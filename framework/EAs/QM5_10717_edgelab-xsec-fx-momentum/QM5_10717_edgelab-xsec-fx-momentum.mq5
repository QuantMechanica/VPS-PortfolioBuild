#property strict
#property version   "5.0"
#property description "QM5_10717 Edge Lab Cross-Sectional FX Momentum (FX8 basket, D1)"

// QuantMechanica V5 Edge Lab - Direction 1, thesis T1.
//
// Thesis: information about a currency's fundamentals diffuses slowly into
// price; currencies strong over the past ~3 months tend to keep outperforming.
// Rank the 8 majors by relative strength, hold the strongest against the
// weakest. The edge is relative (long/short, roughly market-neutral), which
// mutes directional drawdown - the FTMO-friendly flagship of Edge Lab D1.
//
// This is a cross-sectional BASKET EA: one instance attaches to the host
// chart (EURUSD.DWX / D1), reads the full FX8 basket, and opens/closes real
// positions on the selected DWX pairs via the V5 basket-order helper.
//
// Source: Menkhoff, Sarno, Schmeling, Schrimpf (2012), Currency Momentum
// Strategies, Journal of Financial Economics 106(3).
//
// Card: QM5_10717_edgelab-xsec-fx-momentum
// Design: docs/ops/CROSS_SECTIONAL_BASKET_PIPELINE_DESIGN_2026-05-22.md
// Mechanical, deterministic, no ML (Hard Rule 14). No grid, no martingale.

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10717;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 500.0;   // per leg; 2 legs => ~2x book
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;   // weekly D1 swing holds over weekend
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    strategy_lookback_days       = 63;      // ~3-month momentum lookback
input int    strategy_rebalance_dow       = 1;       // weekly rebalance day (MT5: Sun=0, Mon=1)
input int    strategy_atr_period          = 20;      // per-leg hard-stop ATR period
input double strategy_atr_sl_mult         = 2.0;     // per-leg hard stop = 2.0 x ATR(20,D1)
input int    strategy_deviation_points    = 30;      // max execution slippage
input bool   strategy_volfilter_enabled   = true;    // momentum-crash guard
input int    strategy_vol_window          = 20;      // realized-vol window (D1 bars)
input int    strategy_vol_percentile_days = 252;     // ~1-year vol distribution
input double strategy_vol_skip_pct        = 0.90;    // skip rebalance if basket vol in top decile

// --- FX8 basket definition -------------------------------------------------
// 8 majors, fixed order.
const string QM10717_CCY[8] =
  {"USD","EUR","GBP","JPY","CHF","AUD","NZD","CAD"};

// 28 DWX basket pairs (every currency-pair combination of the 8 majors).
const string QM10717_PAIRS[28] =
  {
   "EURUSD.DWX","GBPUSD.DWX","AUDUSD.DWX","NZDUSD.DWX","USDJPY.DWX",
   "USDCHF.DWX","USDCAD.DWX","EURGBP.DWX","EURJPY.DWX","EURCHF.DWX",
   "EURAUD.DWX","EURNZD.DWX","EURCAD.DWX","GBPJPY.DWX","GBPCHF.DWX",
   "GBPAUD.DWX","GBPNZD.DWX","GBPCAD.DWX","AUDJPY.DWX","AUDCHF.DWX",
   "AUDNZD.DWX","AUDCAD.DWX","NZDJPY.DWX","NZDCHF.DWX","NZDCAD.DWX",
   "CADJPY.DWX","CADCHF.DWX","CHFJPY.DWX"
  };

// 7 USD-quoted/based pairs used for the basket realized-vol filter.
const string QM10717_USD_PAIRS[7] =
  {"EURUSD.DWX","GBPUSD.DWX","AUDUSD.DWX","NZDUSD.DWX",
   "USDJPY.DWX","USDCHF.DWX","USDCAD.DWX"};

// Basket leg magic slots. Slot 0 is reserved for the framework identity
// magic; the two market-neutral legs use slots 1 and 2.
const int QM10717_LEG_SLOT[2] = {1, 2};

//+------------------------------------------------------------------+
//| Resolve the DWX symbol carrying currency pair (base, quote).     |
//| out_inverted is TRUE when the symbol is quoted as quote/base.    |
//+------------------------------------------------------------------+
bool QM10717_FindPair(const string base, const string quote,
                      string &out_symbol, bool &out_inverted)
  {
   out_symbol = "";
   out_inverted = false;
   for(int i = 0; i < 28; ++i)
     {
      const string s = QM10717_PAIRS[i];
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
//| Return of currency `base` measured against `quote` over          |
//| `lookback` D1 bars (closed bars only).                           |
//+------------------------------------------------------------------+
bool QM10717_PairReturn(const string base, const string quote,
                        const int lookback, double &out_ret)
  {
   out_ret = 0.0;
   string sym;
   bool inv;
   if(!QM10717_FindPair(base, quote, sym, inv))
      return false;
   const double now  = iClose(sym, PERIOD_D1, 1);
   const double past = iClose(sym, PERIOD_D1, lookback + 1);
   if(now <= 0.0 || past <= 0.0)
      return false;
   if(inv)
      out_ret = (past / now) - 1.0;
   else
      out_ret = (now / past) - 1.0;
   return true;
  }

//+------------------------------------------------------------------+
//| Currency strength = mean return of a currency vs the other 7.    |
//+------------------------------------------------------------------+
bool QM10717_CurrencyStrength(double &strength[])
  {
   for(int i = 0; i < 8; ++i)
     {
      double sum = 0.0;
      int n = 0;
      for(int j = 0; j < 8; ++j)
        {
         if(i == j)
            continue;
         double r;
         if(!QM10717_PairReturn(QM10717_CCY[i], QM10717_CCY[j],
                                strategy_lookback_days, r))
            return false;
         sum += r;
         n++;
        }
      if(n != 7)
         return false;
      strength[i] = sum / 7.0;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Realized vol of one symbol over `window` D1 returns ending at    |
//| bar shift `endShift`.                                            |
//+------------------------------------------------------------------+
bool QM10717_SymVol(const string sym, const int window,
                    const int endShift, double &out_vol)
  {
   out_vol = 0.0;
   double sum = 0.0;
   double sumsq = 0.0;
   int n = 0;
   for(int k = 0; k < window; ++k)
     {
      const int sh = endShift + k;
      const double c0 = iClose(sym, PERIOD_D1, sh);
      const double c1 = iClose(sym, PERIOD_D1, sh + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         return false;
      const double r = (c0 / c1) - 1.0;
      sum += r;
      sumsq += r * r;
      n++;
     }
   if(n < 2)
      return false;
   const double mean = sum / n;
   const double var = (sumsq / n) - (mean * mean);
   out_vol = (var > 0.0) ? MathSqrt(var) : 0.0;
   return true;
  }

//+------------------------------------------------------------------+
//| Basket realized vol = mean of the 7 USD-pair vols.               |
//+------------------------------------------------------------------+
bool QM10717_BasketVol(const int window, const int endShift, double &out_vol)
  {
   out_vol = 0.0;
   double sum = 0.0;
   for(int i = 0; i < 7; ++i)
     {
      double v;
      if(!QM10717_SymVol(QM10717_USD_PAIRS[i], window, endShift, v))
         return false;
      sum += v;
     }
   out_vol = sum / 7.0;
   return true;
  }

//+------------------------------------------------------------------+
//| Momentum-crash guard: TRUE when basket realized vol is in its    |
//| top decile over the trailing window -> skip the rebalance.       |
//| Fails open (returns FALSE) when history is insufficient.         |
//+------------------------------------------------------------------+
bool QM10717_VolFilterRed()
  {
   double cur;
   if(!QM10717_BasketVol(strategy_vol_window, 1, cur))
      return false;
   int le = 0;
   int total = 0;
   for(int d = 1; d <= strategy_vol_percentile_days; ++d)
     {
      double v;
      if(!QM10717_BasketVol(strategy_vol_window, d, v))
         break;
      total++;
      if(v <= cur)
         le++;
     }
   if(total < 20)
      return false;
   const double pct = (double)le / (double)total;
   return (pct >= strategy_vol_skip_pct);
  }

//+------------------------------------------------------------------+
//| Flatten every position carrying this EA's magic block.           |
//+------------------------------------------------------------------+
void QM10717_CloseAll()
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
//| Open one market-neutral leg: long `strongCcy` vs `weakCcy`.      |
//+------------------------------------------------------------------+
bool QM10717_OpenLeg(const int slotIndex, const string strongCcy,
                     const string weakCcy)
  {
   string sym;
   bool inv;
   if(!QM10717_FindPair(strongCcy, weakCcy, sym, inv))
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
   req.lots = 0.0;                        // auto-size to configured per-leg risk
   req.reason = StringFormat("XSEC_MOM_%s%s", strongCcy, weakCcy);
   req.symbol_slot = QM10717_LEG_SLOT[slotIndex];
   req.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode,
                                strategy_deviation_points, req, ticket);
  }

//+------------------------------------------------------------------+
//| Weekly cross-sectional rebalance.                                |
//+------------------------------------------------------------------+
void QM10717_Rebalance()
  {
   QM10717_CloseAll();

   if(strategy_volfilter_enabled && QM10717_VolFilterRed())
     {
      QM_LogEvent(QM_INFO, "BASKET_REBALANCE",
                  "{\"action\":\"skip\",\"reason\":\"vol_filter_red\"}");
      return;
     }

   double strength[8];
   if(!QM10717_CurrencyStrength(strength))
     {
      QM_LogEvent(QM_WARN, "BASKET_REBALANCE",
                  "{\"action\":\"skip\",\"reason\":\"insufficient_history\"}");
      return;
     }

   // Rank currency indices by strength, descending (bubble sort, n=8).
   int order[8];
   for(int i = 0; i < 8; ++i)
      order[i] = i;
   for(int a = 0; a < 7; ++a)
      for(int b = 0; b < 7 - a; ++b)
         if(strength[order[b]] < strength[order[b + 1]])
           {
            const int tmp = order[b];
            order[b] = order[b + 1];
            order[b + 1] = tmp;
           }

   const int s1 = order[0];   // strongest
   const int s2 = order[1];   // 2nd strongest
   const int w2 = order[6];   // 2nd weakest
   const int w1 = order[7];   // weakest

   // Two extreme-vs-extreme legs: strongest/weakest and 2nd/2nd.
   const bool ok1 = QM10717_OpenLeg(0, QM10717_CCY[s1], QM10717_CCY[w1]);
   const bool ok2 = QM10717_OpenLeg(1, QM10717_CCY[s2], QM10717_CCY[w2]);

   const string payload = StringFormat(
      "{\"action\":\"rebalance\",\"lookback_days\":%d,"
      "\"long1\":\"%s\",\"short1\":\"%s\",\"long2\":\"%s\",\"short2\":\"%s\","
      "\"leg1_ok\":%s,\"leg2_ok\":%s,"
      "\"strength_strongest\":%.6f,\"strength_weakest\":%.6f}",
      strategy_lookback_days,
      QM10717_CCY[s1], QM10717_CCY[w1], QM10717_CCY[s2], QM10717_CCY[w2],
      (ok1 ? "true" : "false"), (ok2 ? "true" : "false"),
      strength[s1], strength[w1]);
   QM_LogEvent(QM_INFO, "BASKET_REBALANCE", payload);
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   // FW9 2026-05-24 — basket scope + history pre-load. SymbolSelect alone
   // adds to Market Watch but doesn't force the MT5 tester to load each
   // symbol's history; QM_BasketWarmupHistory triggers that load so first
   // iClose returns real data instead of 0 (which caused
   // NO_REAL_TICKS_MARKER_FAST_FINISH -> INVALID on prior Q02 runs).
   string basket_list[28];
   for(int i = 0; i < 28; ++i)
      basket_list[i] = QM10717_PAIRS[i];
   QM_SymbolGuardInit(basket_list);
   // Lookback covers vol-percentile window (252d) + momentum window (63d)
   QM_BasketWarmupHistory(basket_list, PERIOD_D1, 280);

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_10717_edgelab-xsec-fx-momentum\",\"scope\":\"basket\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(!QM_IsNewBar())
      return;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week != strategy_rebalance_dow)
      return;

   QM10717_Rebalance();
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
//+------------------------------------------------------------------+
