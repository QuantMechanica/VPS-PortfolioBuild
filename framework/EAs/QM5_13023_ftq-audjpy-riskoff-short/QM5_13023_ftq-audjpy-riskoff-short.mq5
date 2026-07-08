#property strict
#property version   "5.0"
#property description "QM5_13023 Flight-To-Quality AUDJPY Risk-Off Short"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13023 - Flight-To-Quality AUDJPY Risk-Off Short
// -----------------------------------------------------------------------------
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_13023_ftq-audjpy-riskoff-short.md
// Source: Ranaldo/Soederlind (2010) safe-haven currencies; Moskowitz/Ooi/
// Pedersen (2012) time-series momentum. D1 short-only AUDJPY breakdown,
// gated by a bear regime (close < SMA(sma_regime)) AND a stacked bearish
// momentum alignment (close < SMA(sma_mom) < SMA(sma_regime)), triggered by
// a Donchian(entry) low breakdown. Exit via ATR hard stop, Donchian(trail)
// high cover, SMA(sma_mom) reclaim, or a max-hold time stop. Single-symbol,
// self-contained (single_symbol_only: true) — no cross-symbol reads.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13023; // magic = qm_ea_id * 10000 + symbol_slot
input int    qm_magic_slot_offset       = 0;     // AUDJPY.DWX slot 0 -> magic 130230000
input uint   qm_rng_seed                = 42;

input group "Risk"
// Backtests use RISK_FIXED=1000 and RISK_PERCENT=0. Any future live/deploy
// setfile must use portfolio-approved percent risk and RISK_FIXED=0.
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
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_sma_regime           = 200;  // bear-regime gate: close below this SMA
input int    strategy_sma_mom              = 50;   // momentum-stack SMA: close below + below sma_regime; also the reclaim-exit level
input int    strategy_donchian_entry       = 20;   // Donchian low lookback for the breakdown trigger
input int    strategy_atr_period           = 14;   // ATR period for the hard stop
input double strategy_atr_sl_mult          = 2.5;  // ATR hard-stop multiple
input int    strategy_donchian_trail       = 15;   // Donchian high lookback for the cover trail
input int    strategy_max_hold_bars        = 40;   // max D1 bars to hold before time-stop close
input int    strategy_max_spread_points    = 60;   // entry spread cap in broker points; 0 disables

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(strategy_sma_regime <= 1 || strategy_sma_mom <= 1)
      return true;
   if(strategy_donchian_entry <= 1 || strategy_donchian_trail <= 1)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_bars <= 0)
      return true;
   return false;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   if(ask < bid)
      return false;

   const double spread_points = (ask - bid) / point;
   return (spread_points <= (double)strategy_max_spread_points);
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Short-only, one position at a time (Card: Trade Management Rules).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!Strategy_SpreadAllowsEntry())
      return false;

   // Regime gate + stacked-bearish momentum alignment: no signal mixin covers
   // a plain-SMA stacked read (QM_Sig_MA_Position is EMA-only), so this reads
   // SMA/close directly — single closed-bar reads, gated to once per D1 bar
   // by the caller's QM_IsNewBar() check.
   const double sma_regime = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_sma_regime, 1);
   const double sma_mom    = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_sma_mom, 1);
   if(sma_regime <= 0.0 || sma_mom <= 0.0)
      return false;
   const double close_last = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: bespoke SMA-stack gate, no mixin fits; single closed-bar read
   if(close_last <= 0.0)
      return false;

   // Card Rules > Entry: regime gate.
   if(close_last >= sma_regime)
      return false;
   // Card Rules > Entry: momentum stack (close < SMA(mom) AND SMA(mom) < SMA(regime)).
   if(close_last >= sma_mom)
      return false;
   if(sma_mom >= sma_regime)
      return false;

   // Trigger A: fresh Donchian low breakdown.
   const bool donchian_breakdown =
      (QM_Sig_Range_Breakout(_Symbol, PERIOD_CURRENT, strategy_donchian_entry, 1) < 0);

   // Trigger B: failed SMA(mom) reclaim inside the same bear stack. This keeps
   // the source thesis as time-series momentum/flight-to-quality while allowing
   // re-entry after shallow pullbacks, which the original pure-Donchian trigger
   // under-sampled on AUDJPY's 2018-2022 risk-off regimes.
   const double sma_mom_prev = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_sma_mom, 2);
   const double close_prev = iClose(_Symbol, PERIOD_CURRENT, 2); // perf-allowed: prior close for failed-reclaim trigger
   const bool failed_reclaim =
      (sma_mom_prev > 0.0 && close_prev > 0.0 && close_prev >= sma_mom_prev && close_last < sma_mom);

   if(!donchian_breakdown && !failed_reclaim)
      return false;

   const double entry_price = QM_EntryMarketPrice(QM_SELL);
   if(entry_price <= 0.0)
      return false;

   const double sl_price = QM_StopATR(_Symbol, QM_SELL, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(sl_price <= 0.0)
      return false;

   req.type = QM_SELL;
   req.sl = sl_price;
   req.reason = donchian_breakdown ? "FTQ_AUDJPY_DONCHIAN_SHORT" : "FTQ_AUDJPY_RECLAIM_FAIL_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// The ATR hard stop is a broker-side SL set at entry; the Donchian trail,
// SMA reclaim, and time stop are discretionary closes handled in
// Strategy_ExitSignal. No additional per-tick management needed.
void Strategy_ManageOpenPosition()
  {
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Time stop: close after strategy_max_hold_bars completed D1 bars.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = iBarShift(_Symbol, PERIOD_D1, opened, false);
      if(bars_held >= strategy_max_hold_bars)
         return true;
     }

   // Channel trail: cover on a closed D1 bar close above the Donchian(trail) high.
   if(QM_Sig_Range_Breakout(_Symbol, PERIOD_CURRENT, strategy_donchian_trail, 1) > 0)
      return true;

   // SMA reclaim exit: cover when close reclaims back above SMA(strategy_sma_mom) —
   // the risk-off downtrend leg that justified the position has stalled.
   const double sma_mom = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_sma_mom, 1);
   const double close_last = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: bespoke SMA-reclaim exit, single closed-bar read
   if(sma_mom > 0.0 && close_last > 0.0 && close_last > sma_mom)
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13023\",\"ea\":\"ftq-audjpy-riskoff-short\"}");
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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
