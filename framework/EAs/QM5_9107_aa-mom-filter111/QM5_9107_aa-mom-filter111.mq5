#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

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
input int    qm_ea_id                   = 9107;
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
input int    strategy_min_monthly_bars      = 24;
input int    strategy_mom_11_1_recent_shift = 1;
input int    strategy_mom_11_1_old_shift    = 12;
input int    strategy_mom_10_0_recent_shift = 0;
input int    strategy_mom_10_0_old_shift    = 10;
input double strategy_top_decile_pct        = 10.0;
input bool   strategy_enable_short_decile   = false;
input int    strategy_atr_period_d1         = 20;
input double strategy_atr_sl_mult           = 3.0;
input double strategy_spread_median_mult    = 2.5;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

int Strategy_UniverseCount()
  {
   return 37;
  }

string Strategy_UniverseSymbol(const int idx)
  {
   switch(idx)
     {
      case 0:  return "AUDCAD.DWX";
      case 1:  return "AUDCHF.DWX";
      case 2:  return "AUDJPY.DWX";
      case 3:  return "AUDNZD.DWX";
      case 4:  return "AUDUSD.DWX";
      case 5:  return "CADCHF.DWX";
      case 6:  return "CADJPY.DWX";
      case 7:  return "CHFJPY.DWX";
      case 8:  return "EURAUD.DWX";
      case 9:  return "EURCAD.DWX";
      case 10: return "EURCHF.DWX";
      case 11: return "EURGBP.DWX";
      case 12: return "EURJPY.DWX";
      case 13: return "EURNZD.DWX";
      case 14: return "EURUSD.DWX";
      case 15: return "GBPAUD.DWX";
      case 16: return "GBPCAD.DWX";
      case 17: return "GBPCHF.DWX";
      case 18: return "GBPJPY.DWX";
      case 19: return "GBPNZD.DWX";
      case 20: return "GBPUSD.DWX";
      case 21: return "GDAXI.DWX";
      case 22: return "NDX.DWX";
      case 23: return "NZDCAD.DWX";
      case 24: return "NZDCHF.DWX";
      case 25: return "NZDJPY.DWX";
      case 26: return "NZDUSD.DWX";
      case 27: return "SP500.DWX";
      case 28: return "UK100.DWX";
      case 29: return "USDCAD.DWX";
      case 30: return "USDCHF.DWX";
      case 31: return "USDJPY.DWX";
      case 32: return "WS30.DWX";
      case 33: return "XAGUSD.DWX";
      case 34: return "XAUUSD.DWX";
      case 35: return "XNGUSD.DWX";
      case 36: return "XTIUSD.DWX";
     }
   return "";
  }

bool Strategy_IsFirstD1BarOfMonth()
  {
   const datetime t0 = iTime(_Symbol, PERIOD_D1, 0);
   const datetime t1 = iTime(_Symbol, PERIOD_D1, 1);
   if(t0 <= 0 || t1 <= 0)
      return false;

   MqlDateTime d0;
   MqlDateTime d1;
   TimeToStruct(t0, d0);
   TimeToStruct(t1, d1);
   return (d0.year != d1.year || d0.mon != d1.mon);
  }

bool Strategy_MonthlyMomentum(const string symbol,
                              const int recent_shift,
                              const int old_shift,
                              double &out_mom)
  {
   out_mom = 0.0;
   if(Bars(symbol, PERIOD_MN1) < strategy_min_monthly_bars)
      return false;

   const double recent_close = iClose(symbol, PERIOD_MN1, recent_shift);
   const double old_close = iClose(symbol, PERIOD_MN1, old_shift);
   if(recent_close <= 0.0 || old_close <= 0.0)
      return false;

   out_mom = (recent_close / old_close) - 1.0;
   return true;
  }

int Strategy_DecileCutoff(const int sample_count)
  {
   if(sample_count <= 0)
      return 0;
   int cutoff = (int)MathCeil(sample_count * strategy_top_decile_pct / 100.0);
   if(cutoff < 1)
      cutoff = 1;
   if(cutoff > sample_count)
      cutoff = sample_count;
   return cutoff;
  }

bool Strategy_RankPasses(const string symbol,
                         const bool want_long,
                         int &out_rank_11_1,
                         int &out_rank_10_0)
  {
   out_rank_11_1 = 0;
   out_rank_10_0 = 0;

   double target_11_1 = 0.0;
   double target_10_0 = 0.0;
   if(!Strategy_MonthlyMomentum(symbol,
                                strategy_mom_11_1_recent_shift,
                                strategy_mom_11_1_old_shift,
                                target_11_1))
      return false;
   if(!Strategy_MonthlyMomentum(symbol,
                                strategy_mom_10_0_recent_shift,
                                strategy_mom_10_0_old_shift,
                                target_10_0))
      return false;

   int samples_11_1 = 0;
   int samples_10_0 = 0;
   out_rank_11_1 = 1;
   out_rank_10_0 = 1;

   const int universe_count = Strategy_UniverseCount();
   for(int i = 0; i < universe_count; ++i)
     {
      const string peer = Strategy_UniverseSymbol(i);
      if(StringLen(peer) == 0)
         continue;

      double peer_11_1 = 0.0;
      if(Strategy_MonthlyMomentum(peer,
                                  strategy_mom_11_1_recent_shift,
                                  strategy_mom_11_1_old_shift,
                                  peer_11_1))
        {
         samples_11_1++;
         if((want_long && peer_11_1 > target_11_1) ||
            (!want_long && peer_11_1 < target_11_1))
            out_rank_11_1++;
        }

      double peer_10_0 = 0.0;
      if(Strategy_MonthlyMomentum(peer,
                                  strategy_mom_10_0_recent_shift,
                                  strategy_mom_10_0_old_shift,
                                  peer_10_0))
        {
         samples_10_0++;
         if((want_long && peer_10_0 > target_10_0) ||
            (!want_long && peer_10_0 < target_10_0))
            out_rank_10_0++;
        }
     }

   const int cutoff_11_1 = Strategy_DecileCutoff(samples_11_1);
   const int cutoff_10_0 = Strategy_DecileCutoff(samples_10_0);
   if(cutoff_11_1 <= 0 || cutoff_10_0 <= 0)
      return false;

   return (out_rank_11_1 <= cutoff_11_1 && out_rank_10_0 <= cutoff_10_0);
  }

bool Strategy_CurrentSpreadExceedsMedian()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || strategy_spread_median_mult <= 0.0)
      return false;

   double spreads[20];
   int n = 0;
   for(int i = 1; i <= 20; ++i)
     {
      const long bar_spread = iSpread(_Symbol, PERIOD_D1, i);
      if(bar_spread > 0)
        {
         spreads[n] = (double)bar_spread;
         n++;
        }
     }
   if(n <= 0)
      return false;

   for(int i = 1; i < n; ++i)
     {
      const double key = spreads[i];
      int j = i - 1;
      while(j >= 0 && spreads[j] > key)
        {
         spreads[j + 1] = spreads[j];
         j--;
        }
      spreads[j + 1] = key;
     }

   const double median = (n % 2 == 1) ? spreads[n / 2] : (0.5 * (spreads[(n / 2) - 1] + spreads[n / 2]));
   const double current_spread = (ask - bid) / point;
   return (median > 0.0 && current_spread > strategy_spread_median_mult * median);
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card has no per-tick no-trade regime; spread is checked only before entry.
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

   if(!Strategy_IsFirstD1BarOfMonth())
      return false;

   if(Strategy_CurrentSpreadExceedsMedian())
      return false;

   int rank_11_1 = 0;
   int rank_10_0 = 0;
   bool long_pass = Strategy_RankPasses(_Symbol, true, rank_11_1, rank_10_0);
   bool short_pass = false;
   if(!long_pass && strategy_enable_short_decile)
      short_pass = Strategy_RankPasses(_Symbol, false, rank_11_1, rank_10_0);

   if(!long_pass && !short_pass)
      return false;

   req.type = long_pass ? QM_BUY : QM_SELL;
   req.price = 0.0;
   const double entry = QM_EntryMarketPrice(req.type);
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr_d1, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = StringFormat("AA_MOM_FILTER_%s_R11_%d_R10_%d",
                             long_pass ? "LONG" : "SHORT",
                             rank_11_1,
                             rank_10_0);
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return false;

   if(!Strategy_IsFirstD1BarOfMonth())
      return false;

   int rank_11_1 = 0;
   int rank_10_0 = 0;
   if(Strategy_RankPasses(_Symbol, true, rank_11_1, rank_10_0))
      return false;
   if(strategy_enable_short_decile && Strategy_RankPasses(_Symbol, false, rank_11_1, rank_10_0))
      return false;

   return true;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
