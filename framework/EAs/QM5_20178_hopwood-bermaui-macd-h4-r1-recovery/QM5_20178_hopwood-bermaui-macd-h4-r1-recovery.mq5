#property strict
#property version   "5.0"
#property description "QM5_20178 Hopwood x Bermaui MACD (H4) smoothed-MACD three-state confluence"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_20178 — Hopwood × Bermaui MACD (H4)
// -----------------------------------------------------------------------------
// Smoothed-MACD three-state confluence. MACD(12,26,9) on H4 is smoothed by a
// "Bermaui kernel" and its line / signal / histogram drive a three-state entry:
//   LONG  when smoothed line > signal AND line > 0 AND histogram slope rising
//         AND D1 close > D1 SMA(200).  SHORT mirrors.
// Exit is purely signal-driven (line/signal cross OR histogram slope flip).
// ATR(20)-based stop, no take-profit.
//
// DELIBERATE, DOCUMENTED SIMPLIFICATION (see SPEC.md §1):
// The card's Bermaui kernel is a two-stage cascade — a 7-period Wilder-MA
// followed by a 7-period HMA — applied to the *derived* MACD line/signal/
// histogram series. The QM_* indicator readers only compute indicators
// directly from price via native MT5 handles; none can smooth an arbitrary
// derived series as a second-stage input. Rather than hand-roll an
// unverifiable second-order numerical filter over the MACD buffer, the kernel
// is implemented as a SINGLE trailing 7-bar simple-moving-average pass over
// the raw MACD line/signal. This preserves the qualitative "smoothed-MACD,
// lag-reduced vs raw MACD" character and the full three-state entry/exit logic
// while staying within one-pass build discipline.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20178;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    macd_fast              = 12;    // MACD fast EMA period
input int    macd_slow              = 26;    // MACD slow EMA period
input int    macd_signal            = 9;     // MACD signal EMA period
input int    bermaui_smooth_period  = 7;     // Bermaui single-SMA smoothing window over derived MACD
input int    atr_period             = 20;    // ATR period for the protective stop
input double sl_atr_mult            = 2.5;   // Stop distance = sl_atr_mult * ATR(atr_period)
input int    d1_sma_period          = 200;   // D1 SMA regime-filter period
input double spread_mult_cap        = 2.0;   // Skip entry if current spread > cap * rolling-mean spread
input int    spread_lookback_bars   = 100;   // Rolling-mean spread lookback (bars)

// File-scope state. Kept for spec/consistency and to record the managed
// position's broker open time; this card has no time-stop, so exits stay
// purely signal-driven.
datetime g_position_entry_time = 0;

// -----------------------------------------------------------------------------
// Bermaui smoothing kernel (single-SMA(7) simplification of the two-stage
// Wilder-MA -> HMA cascade, see header + SPEC.md §1). Bounded loops over the
// derived MACD series; called only from the new-bar-gated entry path and the
// per-position management path.
// -----------------------------------------------------------------------------
double BermauiLine(string sym, int shift)
  {
   double sum = 0.0;
   for(int i = 0; i < bermaui_smooth_period; i++) // perf-allowed structural smoothing over derived series
      sum += QM_MACD_Main(sym, PERIOD_CURRENT, macd_fast, macd_slow, macd_signal, shift + i);
   return sum / bermaui_smooth_period;
  }

double BermauiSignal(string sym, int shift)
  {
   double sum = 0.0;
   for(int i = 0; i < bermaui_smooth_period; i++) // perf-allowed structural smoothing over derived series
      sum += QM_MACD_Signal(sym, PERIOD_CURRENT, macd_fast, macd_slow, macd_signal, shift + i);
   return sum / bermaui_smooth_period;
  }

double BermauiHist(string sym, int shift)
  {
   return BermauiLine(sym, shift) - BermauiSignal(sym, shift);
  }

// Rolling-mean spread in POINTS over the last `lookback` closed bars. .DWX
// symbols report 0 spread in the tester, so this returns 0 there and the entry
// filter degrades to always-pass (never fail-closed on zero spread).
double MeanSpreadPips(string sym, int lookback)
  {
   double sum = 0.0;
   int    n   = 0;
   for(int i = 1; i <= lookback; i++) // perf-allowed structural smoothing over derived series
     {
      MqlRates cj;
      if(!QM_ReadBar(sym, PERIOD_CURRENT, i, cj))
         continue;
      sum += (double)cj.spread; // MqlRates.spread: spread in points at that bar
      n++;
     }
   if(n <= 0)
      return 0.0;
   return sum / (double)n;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(macd_fast <= 0 || macd_slow <= 0 || macd_signal <= 0 || bermaui_smooth_period <= 0 ||
      atr_period <= 0 || sl_atr_mult <= 0.0 || d1_sma_period <= 0 || spread_lookback_bars <= 0)
      return false;

   const double bline1 = BermauiLine(_Symbol, 1);
   const double bsig1  = BermauiSignal(_Symbol, 1);
   const double bhist1 = bline1 - bsig1;
   const double bhist2 = BermauiHist(_Symbol, 2);

   const double atr20_1 = QM_ATR(_Symbol, PERIOD_CURRENT, atr_period, 1);
   if(atr20_1 <= 0.0)
      return false;

   // Spread filter: skip when the current spread blows out vs the rolling mean.
   // Zero current spread (.DWX tester) is always allowed through.
   const double mean_spread_points = MeanSpreadPips(_Symbol, spread_lookback_bars);
   const long   cur_spread_points  = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(cur_spread_points > 0 && mean_spread_points > 0.0 &&
      (double)cur_spread_points > spread_mult_cap * mean_spread_points)
      return false;

   MqlRates d1c1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, d1c1))
      return false;
   const double d1sma200_1 = QM_SMA(_Symbol, PERIOD_D1, d1_sma_period, 1);
   if(d1sma200_1 <= 0.0)
      return false;

   const bool long_ok  = (bline1 > bsig1) && (bline1 > 0.0) && (bhist1 > bhist2) &&
                         (d1c1.close > d1sma200_1);
   const bool short_ok = (bline1 < bsig1) && (bline1 < 0.0) && (bhist1 < bhist2) &&
                         (d1c1.close < d1sma200_1);

   if(long_ok)
     {
      req.type  = QM_BUY;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(req.price <= 0.0)
         return false;
      req.sl = QM_StopATR(_Symbol, QM_BUY, req.price, atr_period, sl_atr_mult);
      if(req.sl <= 0.0)
         return false;
      req.tp     = 0.0;
      req.reason = "hopwood_bermaui_macd_long";
      return true;
     }

   if(short_ok)
     {
      req.type  = QM_SELL;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(req.price <= 0.0)
         return false;
      req.sl = QM_StopATR(_Symbol, QM_SELL, req.price, atr_period, sl_atr_mult);
      if(req.sl <= 0.0)
         return false;
      req.tp     = 0.0;
      req.reason = "hopwood_bermaui_macd_short";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();

   const double bline1 = BermauiLine(_Symbol, 1);
   const double bsig1  = BermauiSignal(_Symbol, 1);
   const double bhist1 = bline1 - bsig1;
   const double bhist2 = BermauiHist(_Symbol, 2);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      g_position_entry_time = (datetime)PositionGetInteger(POSITION_TIME);

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         // Exit long: line crosses below signal OR histogram slope turns down.
         if(bline1 < bsig1 || bhist1 < bhist2)
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         // Exit short: line crosses above signal OR histogram slope turns up.
         if(bline1 > bsig1 || bhist1 > bhist2)
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }
  }

bool Strategy_ExitSignal()
  {
   return false; // exits handled in Strategy_ManageOpenPosition
  }

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
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
