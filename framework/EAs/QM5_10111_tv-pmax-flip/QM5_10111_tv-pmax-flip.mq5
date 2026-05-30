#property strict
#property version   "5.0"
#property description "QM5_10111 TradingView PMax Flip"

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
input int    qm_ea_id                   = 10111;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period        = 10;
input double strategy_atr_mult          = 3.0;
input int    strategy_ma_period         = 10;
input int    strategy_filter_atr_period = 14;
input double strategy_min_stop_atr      = 0.5;
input double strategy_max_stop_atr      = 4.0;
input double strategy_max_spread_frac   = 0.10;
input bool   strategy_use_protective_tp = true;
input double strategy_tp_atr_mult       = 4.0;
input int    strategy_pmax_warmup_bars  = 150;

double g_pmax_closed = 0.0;

bool GetOurPosition(ENUM_POSITION_TYPE &ptype, ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   ticket = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = t;
      return true;
     }

   return false;
  }

bool CalculatePMax(const int target_shift, double &out_ma, double &out_pmax, int &out_dir)
  {
   out_ma = 0.0;
   out_pmax = 0.0;
   out_dir = 0;

   if(strategy_atr_period <= 0 || strategy_ma_period <= 0 || strategy_atr_mult <= 0.0)
      return false;

   int warmup = MathMax(strategy_pmax_warmup_bars, strategy_atr_period + strategy_ma_period + target_shift + 10);
   warmup = MathMin(warmup, 500);
   if(Bars(_Symbol, _Period) <= warmup + target_shift + 5)
      return false;

   double prev_long_stop = 0.0;
   double prev_short_stop = 0.0;
   int dir = 1;

   for(int shift = warmup; shift >= target_shift; --shift)
     {
      const double ma = QM_EMA(_Symbol, _Period, strategy_ma_period, shift);
      const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, shift);
      const double ma_prev = QM_EMA(_Symbol, _Period, strategy_ma_period, shift + 1);
      if(ma <= 0.0 || atr <= 0.0 || ma_prev <= 0.0)
         return false;

      double long_stop = ma - (strategy_atr_mult * atr);
      double short_stop = ma + (strategy_atr_mult * atr);

      if(prev_long_stop > 0.0 && prev_short_stop > 0.0)
        {
         if(ma_prev > prev_long_stop)
            long_stop = MathMax(long_stop, prev_long_stop);
         if(ma_prev < prev_short_stop)
            short_stop = MathMin(short_stop, prev_short_stop);

         if(dir < 0 && ma > prev_short_stop)
            dir = 1;
         else if(dir > 0 && ma < prev_long_stop)
            dir = -1;
        }

      prev_long_stop = long_stop;
      prev_short_stop = short_stop;
      out_ma = ma;
      out_pmax = (dir > 0) ? long_stop : short_stop;
      out_dir = dir;
     }

   return (out_ma > 0.0 && out_pmax > 0.0 && out_dir != 0);
  }

int PMaxCrossSignal(double &signal_pmax, double &atr_filter)
  {
   double ma1 = 0.0;
   double pmax1 = 0.0;
   int dir1 = 0;
   double ma2 = 0.0;
   double pmax2 = 0.0;
   int dir2 = 0;

   if(!CalculatePMax(1, ma1, pmax1, dir1))
      return 0;
   if(!CalculatePMax(2, ma2, pmax2, dir2))
      return 0;

   g_pmax_closed = pmax1;
   signal_pmax = pmax1;
   atr_filter = QM_ATR(_Symbol, _Period, strategy_filter_atr_period, 1);
   if(atr_filter <= 0.0)
      return 0;

   if(ma2 <= pmax2 && ma1 > pmax1)
      return 1;
   if(ma2 >= pmax2 && ma1 < pmax1)
      return -1;

   return 0;
  }

bool StopAndSpreadAllowed(const QM_OrderType side,
                          const double entry,
                          const double sl,
                          const double atr_filter)
  {
   if(entry <= 0.0 || sl <= 0.0 || atr_filter <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   const double stop_distance = MathAbs(entry - sl);
   if(stop_distance < strategy_min_stop_atr * atr_filter)
      return false;
   if(stop_distance > strategy_max_stop_atr * atr_filter)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread = ask - bid;
   if(spread <= 0.0 || spread > strategy_max_spread_frac * stop_distance)
      return false;

   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
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

   double pmax = 0.0;
   double atr_filter = 0.0;
   const int signal = PMaxCrossSignal(pmax, atr_filter);
   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double sl = NormalizeDouble(pmax, _Digits);
   if(!StopAndSpreadAllowed(side, entry, sl, atr_filter))
      return false;

   ENUM_POSITION_TYPE ptype;
   ulong ticket = 0;
   if(GetOurPosition(ptype, ticket))
     {
      const bool same_side = ((ptype == POSITION_TYPE_BUY && side == QM_BUY) ||
                              (ptype == POSITION_TYPE_SELL && side == QM_SELL));
      if(same_side)
         return false;
      if(!QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL))
         return false;
     }

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = strategy_use_protective_tp ? QM_TakeATRFromValue(_Symbol, side, entry, atr_filter, strategy_tp_atr_mult) : 0.0;
   req.reason = (side == QM_BUY) ? "PMAX_MA_CROSS_LONG" : "PMAX_MA_CROSS_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   if(g_pmax_closed <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double new_sl = NormalizeDouble(g_pmax_closed, _Digits);

      if(ptype == POSITION_TYPE_BUY && new_sl > current_sl && new_sl < bid)
         QM_TM_MoveSL(ticket, new_sl, "PMAX_TRAIL");
      if(ptype == POSITION_TYPE_SELL && (current_sl <= 0.0 || new_sl < current_sl) && new_sl > ask)
         QM_TM_MoveSL(ticket, new_sl, "PMAX_TRAIL");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
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

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
