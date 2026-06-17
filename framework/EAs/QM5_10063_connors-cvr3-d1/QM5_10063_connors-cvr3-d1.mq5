#property strict
#property version   "5.0"
#property description "QM5_10063 Connors CVR 3 VIX Stretch Timing D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — Connors CVR 3 (VIX SMA(10) stretch reversal, D1)
// -----------------------------------------------------------------------------
// Card: artifacts/cards_approved/QM5_10063_connors-cvr3-d1.md
//
// Mechanik (mirrored literally from the card):
//   CVR 3 buys/sells the index analogue when VIX stretches >=10% away from its
//   own 10-day SMA and stays entirely on the stretched side during the signal
//   day (evaluated on the just-closed D1 VIX bar).
//
//   Long  signal: VIX_low(1)   >  SMA10(VIX,1)  AND  VIX_close(1) >= 1.10*SMA10
//   Short signal: VIX_high(1)  <  SMA10(VIX,1)  AND  VIX_close(1) <= 0.90*SMA10
//
//   Exit (mean-reversion): close on the D1 close of the first day where VIX
//   trades intraday back across YESTERDAY's VIX SMA(10):
//     Long  exit: VIX_low(1)  <  SMA10_prev   (yesterday's SMA10)
//     Short exit: VIX_high(1) >  SMA10_prev
//   Time-stop: close after `strategy_hold_bars` (4) D1 bars if MR exit unfired.
//
//   Stop loss: SL = strategy_atr_sl_mult * ATR(strategy_atr_period, D1) at fill,
//   built via the framework QM_StopATR helper. Lots via the framework risk model
//   inside QM_TM_OpenPosition (req.lots is not set inline).
//
// VIX feed: the VIX daily OHLC is read from `strategy_vix_symbol` (a custom MT5
// symbol). DWX does not ship a native VIX series; this mirrors the sibling
// QM5_10062 CVR1 build, which reads VIX via CopyRates gated on its own new-bar
// event. When the feed is unavailable the signal latches "not ready" and the EA
// makes no trades (fail-safe), it never fabricates a signal. The CopyRates call
// is the documented perf-allowed exception for the external VIX OHLC feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10063;
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
// Card "Parameters To Test" defaults (CVR 3 VIX-stretch).
input string strategy_vix_symbol        = "VIX.DWX"; // custom VIX daily OHLC series
input int    strategy_vix_sma_period    = 10;        // VIX 10-day SMA baseline
input double strategy_stretch_pct       = 0.10;      // 10% stretch threshold (+/- around SMA)
input int    strategy_atr_period        = 14;        // ATR(14) for protective stop
input double strategy_atr_sl_mult       = 2.5;       // SL = 2.5 * ATR(14)
input double strategy_spread_atr_mult   = 0.25;      // skip if spread > 0.25 * ATR(14)
input int    strategy_hold_bars         = 4;         // time-stop: close after 4 D1 bars

// File-scope cached signal state, advanced once per VIX D1 close.
int  g_cvr3_signal = 0;          // +1 long, -1 short, 0 none
bool g_cvr3_signal_ready = false;
bool g_cvr3_mr_long_exit = false;  // VIX traded intraday below yesterday's SMA10
bool g_cvr3_mr_short_exit = false; // VIX traded intraday above yesterday's SMA10

// -----------------------------------------------------------------------------
// Advance the cached CVR3 VIX signal on each closed VIX D1 bar. Reads the just-
// closed VIX bar (shift 1) plus the SMA10 through that bar (shift 1) and the
// SMA10 through the prior bar (shift 2 = "yesterday's SMA10" for the exit test).
// -----------------------------------------------------------------------------
void CVR3_AdvanceSignal()
  {
   g_cvr3_signal_ready = false;
   g_cvr3_signal = 0;
   g_cvr3_mr_long_exit = false;
   g_cvr3_mr_short_exit = false;

   if(strategy_vix_sma_period < 2)
      return;

   // VIX SMA(10) through the just-closed bar (shift 1) and through the prior
   // bar (shift 2). QM_SMA is the pooled handle reader (no raw iMA / CopyBuffer).
   const double sma_now  = QM_SMA(strategy_vix_symbol, PERIOD_D1, strategy_vix_sma_period, 1);
   const double sma_prev = QM_SMA(strategy_vix_symbol, PERIOD_D1, strategy_vix_sma_period, 2);
   if(sma_now <= 0.0 || sma_prev <= 0.0)
      return;

   // Just-closed VIX D1 OHLC (shift 1). CopyRates is the documented perf-allowed
   // exception for the external VIX feed; gated by the new-bar caller below.
   MqlRates vix_rates[]; // perf-allowed: external VIX OHLC feed, advanced once per VIX D1 close.
   ArraySetAsSeries(vix_rates, true);
   const int copied = CopyRates(strategy_vix_symbol, PERIOD_D1, 1, 1, vix_rates);
   if(copied < 1)
      return;

   const double vix_high  = vix_rates[0].high;
   const double vix_low   = vix_rates[0].low;
   const double vix_close = vix_rates[0].close;
   if(vix_high <= 0.0 || vix_low <= 0.0 || vix_close <= 0.0)
      return;

   // Entry signal: stretched >=10% away from SMA10 and entirely on that side.
   const bool long_signal  = (vix_low  >  sma_now &&
                              vix_close >= (1.0 + strategy_stretch_pct) * sma_now);
   const bool short_signal = (vix_high <  sma_now &&
                              vix_close <= (1.0 - strategy_stretch_pct) * sma_now);

   if(long_signal && !short_signal)
      g_cvr3_signal = 1;
   else if(short_signal && !long_signal)
      g_cvr3_signal = -1;

   // Mean-reversion exit states vs YESTERDAY's SMA10 (sma_prev): VIX traded
   // intraday back across the average during the just-closed bar.
   g_cvr3_mr_long_exit  = (vix_low  < sma_prev);
   g_cvr3_mr_short_exit = (vix_high > sma_prev);

   g_cvr3_signal_ready = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick. Cheap O(1) checks (+ a single VIX
// new-bar advance). Spread guard is fail-OPEN on zero spread (.DWX invariant 1).
bool Strategy_NoTradeFilter()
  {
   // Reject degenerate params (.DWX invariant 9).
   if(strategy_vix_sma_period < 2 || strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 || strategy_stretch_pct <= 0.0 ||
      strategy_hold_bars <= 0)
      return true;

   // Advance the cached VIX signal once per VIX D1 close (single-consume of the
   // VIX-symbol new-bar event; the index new-bar gate stays in OnTick for entry).
   if(QM_IsNewBar(strategy_vix_symbol, PERIOD_D1))
      CVR3_AdvanceSignal();

   if(!g_cvr3_signal_ready)
      return true;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return true;

   // Spread filter: only block a genuinely wide spread. On .DWX ask==bid
   // (0 modeled spread) — never block on zero spread (fail-open).
   if(ask > 0.0 && bid > 0.0 && ask > bid && (ask - bid) > strategy_spread_atr_mult * atr)
      return true;

   return false;
  }

// Populate `req` and return TRUE if a NEW entry should fire on this closed bar.
// Lots are sized by the framework risk model inside QM_TM_OpenPosition (req.lots
// is intentionally not set here).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_cvr3_signal_ready || g_cvr3_signal == 0)
      return false;

   const bool long_signal = (g_cvr3_signal > 0);
   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const ENUM_POSITION_TYPE blocked_type = long_signal ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

   // Card filter: skip if a CVR-family EA already holds the same symbol/direction.
   const int our_magic = QM_FrameworkMagic();
   for(int p = PositionsTotal() - 1; p >= 0; --p)
     {
      const ulong ticket = PositionGetTicket(p);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != blocked_type)
         continue;

      const long foreign_magic = PositionGetInteger(POSITION_MAGIC);
      if((int)foreign_magic == our_magic)
         return false; // our own position already open same direction
      const string comment = PositionGetString(POSITION_COMMENT);
      const int foreign_ea_id = (int)(foreign_magic / 10000);
      if(StringFind(comment, "CVR") >= 0 || foreign_ea_id == 10062)
         return false; // another CVR-family EA holds this symbol/direction
     }

   const double entry_price = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;            // market fill at current price
   req.sl = sl;
   req.tp = 0.0;              // no fixed target; exit via MR / time-stop / SL
   req.reason = long_signal ? "CVR3_LONG" : "CVR3_SHORT";
   return true;
  }

// Card specifies a fixed SL plus mean-reversion / time-stop exits; no trailing,
// partial close, or break-even management.
void Strategy_ManageOpenPosition()
  {
  }

// Return TRUE to close the open position now: mean-reversion exit (VIX traded
// intraday back across yesterday's SMA10) or 4-bar time-stop.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   ulong active_ticket = 0;
   ENUM_POSITION_TYPE active_type = POSITION_TYPE_BUY;
   datetime open_time = 0;

   for(int p = PositionsTotal() - 1; p >= 0; --p)
     {
      const ulong ticket = PositionGetTicket(p);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      active_ticket = ticket;
      active_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }

   if(active_ticket == 0)
      return false;

   // Time-stop: close after `strategy_hold_bars` D1 bars.
   const int d1_seconds = PeriodSeconds(PERIOD_D1);
   if(d1_seconds > 0 && TimeCurrent() - open_time >= strategy_hold_bars * d1_seconds)
      return true;

   if(!g_cvr3_signal_ready)
      return false;

   // Mean-reversion exit vs yesterday's VIX SMA10 (cached in CVR3_AdvanceSignal).
   if(active_type == POSITION_TYPE_BUY && g_cvr3_mr_long_exit)
      return true;
   if(active_type == POSITION_TYPE_SELL && g_cvr3_mr_short_exit)
      return true;

   return false;
  }

// Optional news-filter override. Defer to the central QM_NewsAllowsTrade filter.
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
