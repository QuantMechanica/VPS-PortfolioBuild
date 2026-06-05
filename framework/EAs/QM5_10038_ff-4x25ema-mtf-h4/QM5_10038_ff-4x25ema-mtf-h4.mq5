#property strict
#property version   "5.0"
#property description "QM5_10038 ForexFactory 4x25EMA MTF ATR Trend"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QM5_10038 — ForexFactory "4x25MA Simple Strategy" (foff00, 2019)
// Card: artifacts/cards_approved/QM5_10038_ff-4x25ema-mtf-h4.md (G0 APPROVED).
// -----------------------------------------------------------------------------
// Mechanic (H4 execution, four-timeframe EMA-side alignment):
//   - Long  when the last N closed bars on M15, H1, H4 AND D1 all close ABOVE
//     their own EMA(25), inside the liquid session, with H4 ATR above the 30th
//     percentile of the last 100 H4 bars.
//   - Short mirrors (all four timeframes close BELOW EMA(25)).
//   - SL = 2.0 * ATR(14,H4), TP = 3.5 * ATR(14,H4) (midpoint of source 3-4xATR).
//   - Exit early on a full opposite four-timeframe EMA alignment, or after a
//     20 H4-bar time stop.
//
// Framework corset:
//   - Four-timeframe alignment is computed ONCE per closed H4 bar inside
//     Strategy_EntrySignal (the caller gates it with QM_IsNewBar()) and cached
//     in file scope. Strategy_ExitSignal reads the cache on the per-tick path —
//     it never recomputes EMAs per tick.
//   - All MTF EMA-side reads go through QM_Sig_Price_Above_MA / QM_EMA. No raw
//     iClose / iMA / CopyBuffer. ATR via QM_ATR (handle-pooled).
//   - No per-EA IsNewBar(); OnTick uses the framework QM_IsNewBar() gate.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10038;
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
input int    strategy_ema_period              = 25;     // Card Entry: EMA(25) on each timeframe.
input int    strategy_atr_period              = 14;     // Card Exit/Stop: ATR(14,H4).
input double strategy_atr_sl_mult             = 2.0;     // Card Stop Loss: SL = 2.0 * ATR.
input double strategy_atr_tp_mult             = 3.5;     // Card Exit: TP = 3.5 * ATR (midpoint of 3-4x).
input int    strategy_alignment_bars          = 3;       // Card Entry: last 3 closed bars same side of EMA.
input int    strategy_atr_percentile_bars     = 100;     // Card Filter: ATR percentile window (100 H4 bars).
input double strategy_min_atr_percentile      = 30.0;    // Card Filter: minimum H4 ATR percentile (30).
input double strategy_max_spread_stop_fraction = 0.08;   // Card Stop Loss: skip if spread > 8% of stop dist.
input int    strategy_session_start_hour      = 8;       // Card Entry: liquid-session start (broker hour).
input int    strategy_session_end_hour        = 21;      // Card Entry: liquid-session end / not after NY close.
input int    strategy_max_hold_h4_bars        = 20;      // Card Exit: time stop of 20 H4 bars.

// -----------------------------------------------------------------------------
// File-scope cached four-timeframe alignment, refreshed once per closed H4 bar
// by RefreshAlignment() (called from Strategy_EntrySignal). Consumed on the
// per-tick path by Strategy_ExitSignal without any EMA recompute.
// -----------------------------------------------------------------------------
bool g_long_aligned  = false;   // last N closed bars on M15/H1/H4/D1 all ABOVE EMA(25)
bool g_short_aligned = false;   // last N closed bars on M15/H1/H4/D1 all BELOW EMA(25)

// Recompute the four-timeframe EMA-side alignment from the last N closed bars.
// Runs once per closed H4 bar; uses QM_Sig_Price_Above_MA (+1 above / -1 below
// / 0 equal) plus a QM_EMA validity guard so warmup (EMA==0) never registers as
// a false "above" alignment.
void RefreshAlignment()
  {
   bool all_long  = true;
   bool all_short = true;
   ENUM_TIMEFRAMES frames[4] = { PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1 };
   for(int f = 0; f < 4; ++f)
     {
      for(int shift = 1; shift <= strategy_alignment_bars; ++shift)
        {
         const double ema = QM_EMA(_Symbol, frames[f], strategy_ema_period, shift);
         if(ema <= 0.0)
           {
            all_long  = false;
            all_short = false;
            break;
           }
         const int side = QM_Sig_Price_Above_MA(_Symbol, frames[f], strategy_ema_period, 0.0, shift);
         if(side != +1)
            all_long = false;
         if(side != -1)
            all_short = false;
        }
      if(!all_long && !all_short)
         break;
     }
   g_long_aligned  = all_long;
   g_short_aligned = all_short;
  }

// True iff this EA's magic already holds a position on the current symbol.
bool HaveOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter — runs on every tick and must stay O(1). The card's no-trade
// conditions (liquid session, spread cap, volatility floor) are ENTRY-scoped,
// so they live in Strategy_EntrySignal; gating them here would also suppress the
// time-stop / opposite-alignment EXIT cadence. Nothing blocks the whole tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry — fires at most one new position per closed H4 bar. The caller
// guarantees QM_IsNewBar() == true, so this is the once-per-bar slot where the
// cached MTF alignment is refreshed for both entry and exit.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Refresh cached four-timeframe alignment first — Strategy_ExitSignal reads
   // it on the per-tick path, so it must advance every closed bar even when a
   // position is open (i.e. before the one-position early return below).
   RefreshAlignment();

   if(_Period != PERIOD_H4)
      return false;

   if(strategy_ema_period <= 0 || strategy_atr_period <= 0 ||
      strategy_alignment_bars <= 0 || strategy_atr_percentile_bars <= 0 ||
      strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
      return false;

   // Card Filter: one active position per symbol/magic.
   if(HaveOpenPosition())
      return false;

   // Card Entry: only inside the liquid session, not after New York close.
   if(QM_Sig_Session(TimeCurrent(), strategy_session_start_hour, strategy_session_end_hour) == 0)
      return false;

   // Card Entry: four-timeframe EMA-side alignment (cached above).
   const bool is_long  = g_long_aligned;
   const bool is_short = g_short_aligned;
   if(!is_long && !is_short)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   // Card Filter: minimum H4 ATR percentile over the last 100 H4 bars
   // (approximates the source "high volatility" wording).
   int atr_rank_hits = 0;
   int atr_count = 0;
   for(int shift = 1; shift <= strategy_atr_percentile_bars; ++shift)
     {
      const double atr_i = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, shift);
      if(atr_i <= 0.0)
         continue;
      ++atr_count;
      if(atr_i <= atr)
         ++atr_rank_hits;
     }
   if(atr_count <= 0)
      return false;
   const double atr_percentile = 100.0 * (double)atr_rank_hits / (double)atr_count;
   if(atr_percentile < strategy_min_atr_percentile)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   const double stop_dist = strategy_atr_sl_mult * atr;
   if(stop_dist <= 0.0)
      return false;

   // Card Stop Loss: skip if spread exceeds 8% of the stop distance.
   if((ask - bid) > strategy_max_spread_stop_fraction * stop_dist)
      return false;

   const double tp_dist = strategy_atr_tp_mult * atr;
   if(is_long)
     {
      req.type = QM_BUY;
      req.price = 0.0;                                   // market
      req.sl = NormalizeDouble(ask - stop_dist, _Digits);
      req.tp = NormalizeDouble(ask + tp_dist, _Digits);
      req.reason = "QM5_10038_LONG_4TF_EMA25";
      return true;
     }

   req.type = QM_SELL;
   req.price = 0.0;                                      // market
   req.sl = NormalizeDouble(bid + stop_dist, _Digits);
   req.tp = NormalizeDouble(bid - tp_dist, _Digits);
   req.reason = "QM5_10038_SHORT_4TF_EMA25";
   return true;
  }

// Trade Management — the card specifies a static ATR SL/TP with no trailing,
// partial, or break-even management.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close — discretionary exit, runs every tick and stays O(1): a time stop
// from POSITION_TIME plus an opposite full four-timeframe alignment read from
// the file-scope cache (refreshed once per closed H4 bar in Strategy_EntrySignal).
bool Strategy_ExitSignal()
  {
   if(strategy_max_hold_h4_bars <= 0)
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

      // Card Exit: 20 H4-bar time stop.
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int h4_seconds = PeriodSeconds(PERIOD_H4);
      if(opened > 0 && h4_seconds > 0 &&
         (TimeCurrent() - opened) >= (long)strategy_max_hold_h4_bars * h4_seconds)
         return true;

      // Card Exit: full opposite four-timeframe EMA alignment.
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && g_short_aligned)
         return true;
      if(type == POSITION_TYPE_SELL && g_long_aligned)
         return true;
     }

   return false;
  }

// News Filter Hook — callable by the P8 News Impact phase. Defers to the central
// QM_NewsAllowsTrade filter; this EA adds no custom high-impact handling.
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
