#property strict
#property version   "5.0"
#property description "QM5_13021 WS30 H4 Prior-Day Zone Fade (QM5-10094-GHH4ZONE-PORT-2026-07-06_WS30)"
// Strategy Card: QM5-10094-GHH4ZONE-PORT-2026-07-06_WS30 (ws30-h4-zone-fade),
// G0 APPROVED 2026-07-06. Port of the QM5_10094 gh-h4-zone family (graveyard
// mining 2026-07-06) to WS30.DWX H4 with a vol-percentile instability filter.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13021;
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
input int    strategy_atr_period_h4         = 14;   // Card Rules/Entry: ATR(period, H4) for both the vol filter and the hard stop.
input double strategy_atr_sl_mult           = 2.0;  // Card Exit & Stops: hard SL = ATR * mult from entry.
input double strategy_vol_pct_threshold     = 80.0; // Card Entry: skip when ATR is above this percentile.
input int    strategy_vol_pct_window_h4     = 250;  // Card Entry: trailing H4-bar window for the percentile.
input int    strategy_max_hold_bars_h4      = 12;   // Card Exit & Stops: time stop after N closed H4 bars.
input int    strategy_max_spread_points     = 100;  // Card Entry/Risk: spread cap in points.

// -----------------------------------------------------------------------------
// Bespoke structural reads — no QM_* reader exists for raw OHLC (Framework
// Corset: "Direct iOpen/iHigh/iLow/iClose ... use QM_* readers/signals or a
// documented `// perf-allowed` exception only for bespoke structural logic").
// Each call is a single closed-bar value: either behind the framework's own
// QM_IsNewBar() gate (Strategy_EntrySignal only runs post-gate; see
// EA_Skeleton OnTick wiring) or a one-shot per-position lookup in the exit
// hook — never a per-tick loop.
// -----------------------------------------------------------------------------

bool ReadClosedValue(const string sym, const ENUM_TIMEFRAMES tf, const int shift,
                     const int which, double &out_value) // which: 0=high 1=low 2=close
  {
   out_value = 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   int got = -1;
   if(which == 0)
      got = CopyHigh(sym, tf, shift, 1, buf);  // perf-allowed: single closed-bar zone/touch read
   else if(which == 1)
      got = CopyLow(sym, tf, shift, 1, buf);   // perf-allowed: single closed-bar zone/touch read
   else
      got = CopyClose(sym, tf, shift, 1, buf); // perf-allowed: single closed-bar zone/touch read
   if(got != 1 || buf[0] <= 0.0)
      return false;
   out_value = buf[0];
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card Entry/Risk: "No entry if WS30.DWX spread exceeds
   // strategy_max_spread_points." DWX invariant #1: never fail-closed on a
   // zero-modeled spread — only block a genuinely wide one.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && point > 0.0 && ask > bid)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > (double)strategy_max_spread_points)
         return true;
     }
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

   if(strategy_atr_period_h4 <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_vol_pct_window_h4 < 2 || strategy_max_hold_bars_h4 <= 0)
      return false;

   // Card Rules: no entry while a position is open for this magic (one
   // position at a time).
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Card Mechanism: zones from the prior D1 session high/low.
   double zone_high = 0.0;
   double zone_low = 0.0;
   if(!ReadClosedValue(_Symbol, PERIOD_D1, 1, 0, zone_high) ||
      !ReadClosedValue(_Symbol, PERIOD_D1, 1, 1, zone_low))
      return false; // card: skip entries when D1 history is unavailable
   if(zone_high <= 0.0 || zone_low <= 0.0 || zone_high <= zone_low)
      return false;

   // Card Entry: the completed H4 bar's high/low/close.
   double h1 = 0.0;
   double l1 = 0.0;
   double c1 = 0.0;
   if(!ReadClosedValue(_Symbol, PERIOD_CURRENT, 1, 0, h1) ||
      !ReadClosedValue(_Symbol, PERIOD_CURRENT, 1, 1, l1) ||
      !ReadClosedValue(_Symbol, PERIOD_CURRENT, 1, 2, c1))
      return false; // card: skip entries when H4 history is unavailable

   // Card Entry: instability filter — skip when ATR(H4) sits above its
   // trailing percentile. This loop runs O(window) once per closed H4 bar
   // only, because Strategy_EntrySignal is invoked exclusively after the
   // framework's own QM_IsNewBar() gate (EA_Skeleton OnTick); it must NOT be
   // duplicated into Strategy_NoTradeFilter, which runs every tick and would
   // turn this into a per-tick O(window) cost.
   const double current_atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period_h4, 1);
   if(current_atr <= 0.0)
      return false; // card: skip entries when the ATR series is unavailable

   double atr_samples[];
   ArrayResize(atr_samples, strategy_vol_pct_window_h4);
   int sample_count = 0;
   for(int i = 0; i < strategy_vol_pct_window_h4; ++i)
     {
      const double v = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period_h4, 1 + i);
      if(v <= 0.0)
         continue;
      atr_samples[sample_count] = v;
      sample_count++;
     }
   if(sample_count < strategy_vol_pct_window_h4)
      return false; // card: skip entries when the percentile window is unavailable (warmup)

   ArrayResize(atr_samples, sample_count);
   ArraySort(atr_samples);
   int rank_idx = (int)MathCeil((strategy_vol_pct_threshold / 100.0) * sample_count) - 1;
   if(rank_idx < 0)
      rank_idx = 0;
   if(rank_idx >= sample_count)
      rank_idx = sample_count - 1;
   const double vol_threshold = atr_samples[rank_idx];
   if(current_atr > vol_threshold)
      return false; // card: high-vol regime — instability filter suppresses the entry

   // Card Entry: Entry Short — upper-zone rejection (touch-and-reject close).
   if(h1 >= zone_high && c1 < zone_high)
     {
      const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry_price <= 0.0)
         return false;
      const double sl = QM_StopATR(_Symbol, QM_SELL, entry_price, strategy_atr_period_h4, strategy_atr_sl_mult);
      if(sl <= 0.0 || sl <= entry_price)
         return false;

      req.type = QM_SELL;
      req.sl = sl;
      req.tp = QM_StopRulesNormalizePrice(_Symbol, zone_low);
      req.reason = "WS30_H4_ZONE_FADE_SHORT";
      return true;
     }

   // Card Entry: Entry Long — lower-zone rejection (touch-and-reject close).
   if(l1 <= zone_low && c1 > zone_low)
     {
      const double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry_price <= 0.0)
         return false;
      const double sl = QM_StopATR(_Symbol, QM_BUY, entry_price, strategy_atr_period_h4, strategy_atr_sl_mult);
      if(sl <= 0.0 || sl >= entry_price)
         return false;

      req.type = QM_BUY;
      req.sl = sl;
      req.tp = QM_StopRulesNormalizePrice(_Symbol, zone_high);
      req.reason = "WS30_H4_ZONE_FADE_LONG";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card Trade Management Rules: "No pyramiding, gridding, martingale,
   // partial close, or trailing stop. Stop and target are fixed at entry;
   // only the time stop can close earlier." No per-tick management needed.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_max_hold_bars_h4 <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // Card Exit & Stops: time stop after strategy_max_hold_bars_h4 closed
      // H4 bars. perf-allowed: single iBarShift lookup per open position, no
      // QM_TM_* time-stop helper exists.
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int open_shift = iBarShift(_Symbol, PERIOD_CURRENT, opened, false);
      if(open_shift >= strategy_max_hold_bars_h4)
         return true;
     }

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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
