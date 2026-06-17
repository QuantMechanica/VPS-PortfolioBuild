#property strict
#property version   "5.0"
#property description "QM5_10475 Puria Method MA+MACD (contrarian three-MA displacement)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10475 mql5-puria
// -----------------------------------------------------------------------------
// Source: MQL5 CodeBase "Puria method" (Sergey Deev / Vladimir Karputov),
//   https://www.mql5.com/en/code/23250 — card QM5_10475_mql5-puria.
//
// Mechanic (card ## Mechanik):
//   Three MAs: one fast, two slow. The Puria method is CONTRARIAN — it SELLS
//   when the fast MA displaces ABOVE both slow MAs, and BUYS when the fast MA
//   displaces BELOW both slow MAs, by more than a small point threshold. MACD
//   acts as a CONFIRMING STATE (source-code direction), not a second trigger.
//
//   TRIGGER  : fresh fast-vs-slow1 MA cross on the last closed bar (ONE event).
//   STATES   : fast beyond BOTH slow MAs by > displacement threshold, AND the
//              MACD main line confirms the contrarian direction.
//   Short : fast crosses ABOVE slow1, fast > both slows + thr, MACD main > 0.
//   Long  : fast crosses BELOW slow1, fast < both slows - thr, MACD main < 0.
//   Exit  : opposite full setup (Strategy_ExitSignal re-reads the closed bar).
//   Stop  : SL = 1.5 x ATR(14).  TP = 2R.
//   Sizing: framework (RISK_FIXED backtest / RISK_PERCENT live).
//   One position per magic; closed-bar reads only.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific; all framework
// wiring below the marker is untouched skeleton boilerplate.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10475;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Three-MA Puria displacement. Fast + two slow MAs (LWMA family per source).
input int    strategy_fast_period       = 6;     // fast MA period
input int    strategy_slow1_period      = 17;    // first slow MA (cross reference)
input int    strategy_slow2_period      = 28;    // second slow MA (displacement gate)
input double strategy_disp_points       = 0.5;   // min fast-vs-slow displacement, in points
// MACD confirming state (source-code direction). Standard 12/26/9.
input int    strategy_macd_fast         = 12;
input int    strategy_macd_slow         = 26;
input int    strategy_macd_signal       = 9;
// Stop / target
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;   // SL = 1.5 x ATR(14)
input double strategy_tp_rr             = 2.0;   // TP = 2R

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Evaluate the full Puria setup on closed bars. Returns +1 long, -1 short, 0 none.
// `shift` = closed-bar index (1 = last closed bar). Pure read of pooled helpers.
// The fast-vs-slow1 MA cross is the single fresh TRIGGER; the dual-slow
// displacement and the MACD-main sign are confirming STATES.
int Strategy_PuriaSetup(const int shift)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0;
   const double thr = strategy_disp_points * point;

   const double fast_now   = QM_LWMA(_Symbol, PERIOD_CURRENT, strategy_fast_period,  shift);
   const double slow1_now  = QM_LWMA(_Symbol, PERIOD_CURRENT, strategy_slow1_period, shift);
   const double slow2_now  = QM_LWMA(_Symbol, PERIOD_CURRENT, strategy_slow2_period, shift);
   const double fast_prev  = QM_LWMA(_Symbol, PERIOD_CURRENT, strategy_fast_period,  shift + 1);
   const double slow1_prev = QM_LWMA(_Symbol, PERIOD_CURRENT, strategy_slow1_period, shift + 1);

   if(fast_now <= 0.0 || slow1_now <= 0.0 || slow2_now <= 0.0 ||
      fast_prev <= 0.0 || slow1_prev <= 0.0)
      return 0;

   // MACD confirming STATE (main-line sign) — source-code direction.
   const double macd_main = QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, shift);

   // SHORT: fast just crossed ABOVE slow1 (trigger), fast above BOTH slows by
   //        thr (displacement state), MACD main > 0 (state). Contrarian => SELL.
   const bool cross_up = (fast_prev <= slow1_prev && fast_now > slow1_now);
   if(cross_up &&
      fast_now > slow1_now + thr &&
      fast_now > slow2_now + thr &&
      macd_main > 0.0)
      return -1;

   // LONG: fast just crossed BELOW slow1 (trigger), fast below BOTH slows by
   //       thr (displacement state), MACD main < 0 (state). Contrarian => BUY.
   const bool cross_dn = (fast_prev >= slow1_prev && fast_now < slow1_now);
   if(cross_dn &&
      fast_now < slow1_now - thr &&
      fast_now < slow2_now - thr &&
      macd_main < 0.0)
      return +1;

   return 0;
  }

// Cheap O(1) per-tick block check. Baseline uses only V5 default guards.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// New entry on the last closed bar. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One position per magic — do not stack.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int dir = Strategy_PuriaSetup(1);
   if(dir == 0)
      return false;

   const QM_OrderType side = (dir > 0) ? QM_BUY : QM_SELL;

   // Market entry; framework fills price at send. SL from ATR, TP from RR.
   const double entry_ref = (dir > 0)
                            ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                            : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_ref <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry_ref, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, entry_ref, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // market
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir > 0) ? "QM5_10475_PURIA_LONG" : "QM5_10475_PURIA_SHORT";
   return true;
  }

// No active trade management in the baseline (no breakeven / partial / trail).
void Strategy_ManageOpenPosition()
  {
  }

// Close on the opposite full setup. Re-read the closed-bar setup; if it now
// resolves to the side opposite the open position, signal a manual close.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int dir = Strategy_PuriaSetup(1);
   if(dir == 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && dir < 0)
         return true;
      if(ptype == POSITION_TYPE_SELL && dir > 0)
         return true;
     }
   return false;
  }

// Defer to the central two-axis news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. opposite-signal exit). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled.
   QM_EquityStreamOnNewBar();

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

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
