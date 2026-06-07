#property strict
#property version   "5.0"
#property description "QM5_11080 EarnForex BB-MACD Flip (bb-macd-flip)"
// Strategy Card: QM5_11080 (bb-macd-flip), G0 APPROVED 2026-05-22.
// Source: EarnForex BB-MACD (github.com/EarnForex/BB-MACD).

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — EarnForex BB-MACD Flip
// -----------------------------------------------------------------------------
// Mechanic (card §Mechanik):
//   bbMACD = EMA(close, FastLen) - EMA(close, SlowLen)   (= MACD main line)
//   Bollinger bands are computed ON the bbMACD series with BBLength period and
//   StDv standard deviations:  band = SMA(bbMACD, BBLength) +/- StDv*stddev.
//   The BB-MACD "colour" is a band-cross state machine: it turns UP when the
//   bbMACD crosses ABOVE the upper band, DOWN when it crosses BELOW the lower
//   band, and holds otherwise. A colour flip is exactly the band-cross event on
//   the completed bar.
//     Long  flip (down->up): bbMACD crosses above the upper band.
//     Short flip (up->down): bbMACD crosses below the lower band.
//   Optional stricter variant additionally requires bbMACD > 0 (long) / < 0
//   (short) on the completed bar.
//
// Stop-and-reverse: a flip closes any opposite open position and opens a new one
// in the flip direction (card Exit: "close long on next short flip" etc.). The
// only standalone protective exit is the catastrophic ATR stop (broker-side SL).
//
// All per-bar work runs inside Strategy_EntrySignal, which the framework calls
// once per closed bar behind its QM_IsNewBar() gate — no per-EA new-bar gate,
// no raw indicator calls, no CopyRates. bbMACD values come from the pooled
// QM_MACD_Main reader.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11080;
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
// Card §Mechanik — EarnForex BB-MACD defaults.
input int    strategy_fast_len          = 12;    // bbMACD fast EMA length (FastLen).
input int    strategy_slow_len          = 26;    // bbMACD slow EMA length (SlowLen).
input int    strategy_bb_length         = 10;    // Bollinger length over bbMACD (Length).
input double strategy_bb_stdv           = 2.5;   // Bollinger deviations over bbMACD (StDv).
input bool   strategy_stricter_zero     = false; // Stricter variant: require bbMACD>0 long / <0 short.
input int    strategy_atr_period        = 14;    // Catastrophic stop ATR period.
input double strategy_atr_sl_mult       = 2.5;   // Catastrophic stop = 2.5 ATR (card P2 baseline).
input double strategy_atr_tp_mult       = 0.0;   // Optional TP in ATR (0 = disabled; flip exit only).

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

// bbMACD value at the given closed-bar shift. MACD main line = EMA(fast)-EMA(slow);
// the signal period does not affect the main line, so any value (9) is fine.
double BBMacd(const int shift)
  {
   return QM_MACD_Main(_Symbol, _Period, strategy_fast_len, strategy_slow_len, 9, shift);
  }

// Mean + population standard deviation of the bbMACD series over `length`
// values starting at `start_idx` (inclusive, walking back in time).
void BBMacdBand(const double &series[], const int start_idx, const int length,
                double &upper, double &lower)
  {
   double sum = 0.0;
   for(int k = 0; k < length; ++k)
      sum += series[start_idx + k];
   const double mean = sum / length;

   double sq = 0.0;
   for(int k = 0; k < length; ++k)
     {
      const double d = series[start_idx + k] - mean;
      sq += d * d;
     }
   const double sd = MathSqrt(sq / length);

   upper = mean + strategy_bb_stdv * sd;
   lower = mean - strategy_bb_stdv * sd;
  }

// Direction of our currently-open position: +1 long, -1 short, 0 flat.
// Also returns the ticket via out_ticket when a position exists.
int OurPositionDir(ulong &out_ticket)
  {
   out_ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      out_ticket = t;
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
     }
   return 0;
  }

// Build an entry request for the given side with a catastrophic ATR stop and
// optional ATR target. Returns true on success.
bool BuildEntry(const QM_OrderType side, const string reason, QM_EntryRequest &req)
  {
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   double tp = 0.0;
   if(strategy_atr_tp_mult > 0.0)
     {
      const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr > 0.0)
         tp = (side == QM_BUY) ? entry + atr * strategy_atr_tp_mult
                               : entry - atr * strategy_atr_tp_mult;
     }

   req.type               = side;
   req.price              = 0.0;            // market
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = reason;
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter — no bespoke session/regime gate; news + spread + Friday-close
// are handled by the framework. Cheap O(1).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry — evaluated once per closed bar (framework QM_IsNewBar gate).
// Detects the BB-MACD colour flip (band cross) and applies stop-and-reverse.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int need = strategy_bb_length + 1;      // bands needed for shift 1 and shift 2
   const int count = need + 1;                    // series indices 1..need
   double series[];
   ArrayResize(series, count);
   series[0] = 0.0;                                // unused (shift 0 = forming bar)
   for(int s = 1; s <= need; ++s)
      series[s] = BBMacd(s);

   double up1, lo1, up2, lo2;
   BBMacdBand(series, 1, strategy_bb_length, up1, lo1);   // band on completed bar (shift 1)
   BBMacdBand(series, 2, strategy_bb_length, up2, lo2);   // band on prior bar    (shift 2)

   const double bbm1 = series[1];
   const double bbm2 = series[2];

   bool long_flip  = (bbm2 <= up2) && (bbm1 > up1);   // crossed above upper band
   bool short_flip = (bbm2 >= lo2) && (bbm1 < lo1);   // crossed below lower band

   if(strategy_stricter_zero)
     {
      if(bbm1 <= 0.0) long_flip  = false;
      if(bbm1 >= 0.0) short_flip = false;
     }

   // A single bar cannot be both above the upper and below the lower band.
   if(long_flip == short_flip)
      return false;

   ulong cur_ticket = 0;
   const int dir = OurPositionDir(cur_ticket);

   if(long_flip)
     {
      if(dir > 0)
         return false;                              // already long
      if(dir < 0)
         QM_TM_ClosePosition(cur_ticket, QM_EXIT_STRATEGY);   // reverse: close short first
      return BuildEntry(QM_BUY, "bb_macd_flip_long", req);
     }

   // short_flip
   if(dir < 0)
      return false;                                 // already short
   if(dir > 0)
      QM_TM_ClosePosition(cur_ticket, QM_EXIT_STRATEGY);      // reverse: close long first
   return BuildEntry(QM_SELL, "bb_macd_flip_short", req);
  }

// Trade Management — flip-based system carries a fixed catastrophic ATR stop;
// no break-even or trailing per card. No-op.
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close — discretionary close is handled as stop-and-reverse inside
// Strategy_EntrySignal; the protective exit is the broker-side ATR stop.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook — defer to the central two-axis QM news filter.
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
