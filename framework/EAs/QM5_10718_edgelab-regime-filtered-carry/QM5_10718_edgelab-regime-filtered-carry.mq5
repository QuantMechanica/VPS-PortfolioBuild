#property strict
#property version   "5.0"
#property description "QM5_10718 Edge Lab Regime-Filtered Carry (FX8 basket, D1)"

// QuantMechanica V5 Edge Lab - Direction 1, thesis T2.
//
// Thesis: high-yield currencies pay a carry risk premium as compensation for
// crash risk. Naked carry is a known pipeline killer - it crashes in crises
// and fails Q08 by construction. THE FILTER IS THE THESIS: trade carry only
// while a realized-volatility / risk-on regime filter is GREEN, and stand
// flat otherwise. This card tests whether a simple, low-parameter regime
// gate caps the carry left tail enough to fit the FTMO 10% total-DD box.
//
// Cross-sectional BASKET EA: one instance attaches to the host chart
// (EURUSD.DWX / D1), reads the full FX8 basket, ranks the 8 majors by a
// carry signal derived from broker swap rates, and opens/closes real
// positions on the selected DWX pairs via the V5 basket-order helper.
//
// Sources: Lustig, Roussanov, Verdelhan (2011), Common Risk Factors in
// Currency Markets, Review of Financial Studies 24(11); Menkhoff, Sarno,
// Schmeling, Schrimpf (2012), Carry Trades and Global FX Volatility,
// Journal of Finance 67(2).
//
// Card: QM5_10718_edgelab-regime-filtered-carry
// Design: docs/ops/CROSS_SECTIONAL_BASKET_PIPELINE_DESIGN_2026-05-22.md
// Pattern: QM5_10717_edgelab-xsec-fx-momentum (first V5 basket EA).
// Mechanical, deterministic, no ML (Hard Rule 14). No grid, no martingale.

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 10718;
input int    qm_magic_slot_offset          = 0;

input group "Risk"
input double RISK_PERCENT                  = 0.0;
input double RISK_FIXED                    = 500.0;   // per leg; 2 legs => ~2x book
input double PORTFOLIO_WEIGHT              = 1.0;

input group "News"
input QM_NewsMode qm_news_mode             = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled       = false;   // weekly D1 swing holds over weekend
input int    qm_friday_close_hour_broker   = 21;

input group "Strategy"
input int    strategy_rebalance_dow        = 1;       // weekly rebalance day (MT5: Sun=0, Mon=1)
input int    strategy_atr_period           = 20;      // per-leg hard-stop ATR period
input double strategy_atr_sl_mult          = 2.0;     // per-leg hard stop = 2.0 x ATR(20,D1)
input int    strategy_deviation_points     = 30;      // max execution slippage
input bool   strategy_regime_enabled       = true;    // the thesis: regime gate ON (OFF = naked-carry falsification variant)
input int    strategy_vol_window           = 20;      // basket realized-vol window (D1 bars)
input int    strategy_regime_lookback_days = 252;     // ~1-year vol distribution
input double strategy_regime_vol_pct       = 0.50;    // RED when basket vol is above this percentile (median)

// --- FX8 basket definition -------------------------------------------------
// 8 majors, fixed order.
const string QM10718_CCY[8] =
  {"USD","EUR","GBP","JPY","CHF","AUD","NZD","CAD"};

// 28 DWX basket pairs (every currency-pair combination of the 8 majors).
const string QM10718_PAIRS[28] =
  {
   "EURUSD.DWX","GBPUSD.DWX","AUDUSD.DWX","NZDUSD.DWX","USDJPY.DWX",
   "USDCHF.DWX","USDCAD.DWX","EURGBP.DWX","EURJPY.DWX","EURCHF.DWX",
   "EURAUD.DWX","EURNZD.DWX","EURCAD.DWX","GBPJPY.DWX","GBPCHF.DWX",
   "GBPAUD.DWX","GBPNZD.DWX","GBPCAD.DWX","AUDJPY.DWX","AUDCHF.DWX",
   "AUDNZD.DWX","AUDCAD.DWX","NZDJPY.DWX","NZDCHF.DWX","NZDCAD.DWX",
   "CADJPY.DWX","CADCHF.DWX","CHFJPY.DWX"
  };

// 7 USD-quoted/based pairs used for the basket realized-vol regime filter.
const string QM10718_USD_PAIRS[7] =
  {"EURUSD.DWX","GBPUSD.DWX","AUDUSD.DWX","NZDUSD.DWX",
   "USDJPY.DWX","USDCHF.DWX","USDCAD.DWX"};

// Basket leg magic slots. Slot 0 is reserved for the framework identity
// magic; the two market-neutral legs use slots 1 and 2.
const int QM10718_LEG_SLOT[2] = {1, 2};

//+------------------------------------------------------------------+
//| Resolve the DWX symbol carrying currency pair (base, quote).     |
//| out_inverted is TRUE when the symbol is quoted as quote/base.    |
//+------------------------------------------------------------------+
bool QM10718_FindPair(const string base, const string quote,
                      string &out_symbol, bool &out_inverted)
  {
   out_symbol = "";
   out_inverted = false;
   for(int i = 0; i < 28; ++i)
     {
      const string s = QM10718_PAIRS[i];
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
//| Daily carry (return-equivalent) earned holding long `base` vs    |
//| `quote`, from the broker swap rate (G0-pinned proxy). Assumes    |
//| points-mode swap; normalized by point size and price so pairs    |
//| are cross-sectionally comparable.                                |
//+------------------------------------------------------------------+
bool QM10718_PairCarry(const string base, const string quote, double &out_carry)
  {
   out_carry = 0.0;
   string sym;
   bool inv;
   if(!QM10718_FindPair(base, quote, sym, inv))
      return false;
   // long base = BUY base/quote, or SELL quote/base when the symbol is inverted.
   const double swap = inv ? SymbolInfoDouble(sym, SYMBOL_SWAP_SHORT)
                           : SymbolInfoDouble(sym, SYMBOL_SWAP_LONG);
   const double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   const double px = iClose(sym, PERIOD_D1, 1);
   if(point <= 0.0 || px <= 0.0)
      return false;
   out_carry = (swap * point) / px;
   return true;
  }

//+------------------------------------------------------------------+
//| Currency carry = mean carry of a currency vs the other 7.        |
//| Returns FALSE on missing data or a degenerate (flat) carry       |
//| surface, so the EA never trades a meaningless ranking.           |
//+------------------------------------------------------------------+
bool QM10718_CurrencyCarry(double &carry[])
  {
   for(int i = 0; i < 8; ++i)
     {
      double sum = 0.0;
      int n = 0;
      for(int j = 0; j < 8; ++j)
        {
         if(i == j)
            continue;
         double c;
         if(!QM10718_PairCarry(QM10718_CCY[i], QM10718_CCY[j], c))
            return false;
         sum += c;
         n++;
        }
      if(n != 7)
         return false;
      carry[i] = sum / 7.0;
     }
   double mn = carry[0];
   double mx = carry[0];
   for(int i = 1; i < 8; ++i)
     {
      if(carry[i] < mn)
         mn = carry[i];
      if(carry[i] > mx)
         mx = carry[i];
     }
   return ((mx - mn) > 1e-9);
  }

//+------------------------------------------------------------------+
//| Realized vol of one symbol over `window` D1 returns ending at    |
//| bar shift `endShift`.                                            |
//+------------------------------------------------------------------+
bool QM10718_SymVol(const string sym, const int window,
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
bool QM10718_BasketVol(const int window, const int endShift, double &out_vol)
  {
   out_vol = 0.0;
   double sum = 0.0;
   for(int i = 0; i < 7; ++i)
     {
      double v;
      if(!QM10718_SymVol(QM10718_USD_PAIRS[i], window, endShift, v))
         return false;
      sum += v;
     }
   out_vol = sum / 7.0;
   return true;
  }

//+------------------------------------------------------------------+
//| Regime filter (the thesis): TRUE = RED = basket realized vol is  |
//| above its trailing percentile (median) -> stand flat.            |
//| Fails open (GREEN) when history is insufficient.                 |
//+------------------------------------------------------------------+
bool QM10718_RegimeRed()
  {
   double cur;
   if(!QM10718_BasketVol(strategy_vol_window, 1, cur))
      return false;
   int le = 0;
   int total = 0;
   for(int d = 1; d <= strategy_regime_lookback_days; ++d)
     {
      double v;
      if(!QM10718_BasketVol(strategy_vol_window, d, v))
         break;
      total++;
      if(v <= cur)
         le++;
     }
   if(total < 20)
      return false;
   const double pct = (double)le / (double)total;
   return (pct > strategy_regime_vol_pct);
  }

//+------------------------------------------------------------------+
//| Flatten every position carrying this EA's magic block.           |
//+------------------------------------------------------------------+
void QM10718_CloseAll()
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
bool QM10718_OpenLeg(const int slotIndex, const string strongCcy,
                     const string weakCcy)
  {
   string sym;
   bool inv;
   if(!QM10718_FindPair(strongCcy, weakCcy, sym, inv))
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
   req.reason = StringFormat("CARRY_%s%s", strongCcy, weakCcy);
   req.symbol_slot = QM10718_LEG_SLOT[slotIndex];
   req.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode,
                                strategy_deviation_points, req, ticket);
  }

//+------------------------------------------------------------------+
//| Weekly cross-sectional carry rebalance (regime already GREEN).   |
//+------------------------------------------------------------------+
void QM10718_Rebalance()
  {
   QM10718_CloseAll();

   double carry[8];
   if(!QM10718_CurrencyCarry(carry))
     {
      QM_LogEvent(QM_WARN, "BASKET_REBALANCE",
                  "{\"action\":\"skip\",\"reason\":\"no_carry_signal\"}");
      return;
     }

   // Rank currency indices by carry, descending (bubble sort, n=8).
   int order[8];
   for(int i = 0; i < 8; ++i)
      order[i] = i;
   for(int a = 0; a < 7; ++a)
      for(int b = 0; b < 7 - a; ++b)
         if(carry[order[b]] < carry[order[b + 1]])
           {
            const int tmp = order[b];
            order[b] = order[b + 1];
            order[b + 1] = tmp;
           }

   const int s1 = order[0];   // highest carry
   const int s2 = order[1];   // 2nd highest carry
   const int w2 = order[6];   // 2nd lowest carry
   const int w1 = order[7];   // lowest carry

   // Two extreme-vs-extreme legs: long top-2 carry, short bottom-2.
   const bool ok1 = QM10718_OpenLeg(0, QM10718_CCY[s1], QM10718_CCY[w1]);
   const bool ok2 = QM10718_OpenLeg(1, QM10718_CCY[s2], QM10718_CCY[w2]);

   const string payload = StringFormat(
      "{\"action\":\"rebalance\",\"regime\":\"green\","
      "\"long1\":\"%s\",\"short1\":\"%s\",\"long2\":\"%s\",\"short2\":\"%s\","
      "\"leg1_ok\":%s,\"leg2_ok\":%s,"
      "\"carry_highest\":%.8f,\"carry_lowest\":%.8f}",
      QM10718_CCY[s1], QM10718_CCY[w1], QM10718_CCY[s2], QM10718_CCY[w2],
      (ok1 ? "true" : "false"), (ok2 ? "true" : "false"),
      carry[s1], carry[w1]);
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

   for(int i = 0; i < 28; ++i)
      SymbolSelect(QM10718_PAIRS[i], true);

   QM_LogEvent(QM_INFO, "INIT_OK",
               "{\"card\":\"QM5_10718_edgelab-regime-filtered-carry\",\"scope\":\"basket\"}");
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

   // Regime gate, evaluated every D1 bar: RED -> flat out immediately.
   if(strategy_regime_enabled && QM10718_RegimeRed())
     {
      QM10718_CloseAll();
      QM_LogEvent(QM_INFO, "BASKET_REGIME",
                  "{\"regime\":\"red\",\"action\":\"flat\"}");
      return;
     }

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week != strategy_rebalance_dow)
      return;

   QM10718_Rebalance();
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
