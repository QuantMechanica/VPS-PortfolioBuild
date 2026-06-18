#property strict
#property version   "5.0"
#property description "QM5_12479 gh-ha-momo — Heikin-Ashi momentum continuation (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12479 gh-ha-momo
// -----------------------------------------------------------------------------
// Source: je-suis-tm/quant-trading, Heikin-Ashi backtest.py, functions
//         heikin_ashi() and signal_generation().
// Card: artifacts/cards_approved/QM5_12479_gh-ha-momo.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; HA candles computed in-EA from real
// OHLC, recursive from a bounded seed — perf-allowed bounded closed-bar reads):
//
//   Heikin-Ashi transform:
//     HA_close = (O+H+L+C)/4
//     HA_open[t] = (HA_open[t-1] + HA_close[t-1]) / 2  (seeded HA_open=(O+C)/2)
//     HA_high = max(HA_open, HA_close, High, Low)
//     HA_low  = min(HA_open, HA_close, High, Low)
//
//   The source loop opens on a run of strong, body-EXPANDING HA candles with no
//   wick on the open side (HA_open == HA_high), confirmed by the prior candle
//   sharing the same colour. We port the explicit long path of the source loop.
//
//   STATE filters (no single one is the trigger):
//     - HA_open(1) > HA_close(1)             : signal-coloured candle, no upper wick run
//     - HA_open(1) == HA_high(1)             : no upper wick (within tick tolerance)
//     - HA_open(2) > HA_close(2)             : prior candle shares the colour (consecutive)
//     - body(1) >= body_atr_frac * ATR(20)   : minimum body filter (card 0.25*ATR)
//
//   Trigger EVENT (single, per bar):
//     - body(1) > body(2)  : the HA body EXPANDED vs the prior bar = momentum
//       impulse. This is the one fresh per-bar event; the colour/no-wick/consec
//       conditions above are STATES observed across bars. We never require two
//       fresh cross EVENTS on the same bar (.DWX two-cross trap).
//
//   Exit (source signal_generation opposite condition):
//     - HA_open(1) < HA_close(1) AND HA_open(1) == HA_low(1)
//       AND HA_open(2) < HA_close(2)         : opposite-coloured run, no lower wick.
//
//   Stop : entry - stop_atr_mult * ATR(atr_period)  (card 3.0 * ATR(20) emergency).
//          No fixed take profit; the strategy exits on the opposite HA condition
//          or the ATR emergency stop (source has no profit target).
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// NOTE (open_question): the source uses HA_open>HA_close (a "bearish"-coloured
// HA candle) as its LONG entry condition — an idiosyncrasy of the author's colour
// convention in the referenced script. The card reproduces this verbatim
// ("enters on consecutive strong bearish-colored HA candles"). We implement the
// card's explicit long path literally rather than re-interpreting the colour;
// flagged for the reviewer. Direction may be inverted in a P3 sweep if needed.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12479;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
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
input int    strategy_ha_seed_bars        = 200;   // HA recursion seed depth (bounded)
input int    strategy_atr_period          = 20;    // ATR period (body filter + stop)
input double strategy_body_atr_frac       = 0.25;  // min HA body = frac * ATR(period)
input double strategy_stop_atr_mult       = 3.0;   // emergency stop = mult * ATR(period)
input double strategy_spread_pct_of_stop  = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Heikin-Ashi helper — compute HA open/close/high/low at a given closed-bar
// shift by recursing from a bounded seed. perf-allowed: bounded closed-bar OHLC
// reads, only on the closed-bar entry/exit path (QM_IsNewBar-gated by frame).
// -----------------------------------------------------------------------------

// Fills HA open/close/high/low for the candle at `shift` (1 = last closed bar).
// Returns false if history is not yet available.
bool ComputeHA(const int shift, double &ha_open, double &ha_close,
               double &ha_high, double &ha_low)
  {
   const int seed = (strategy_ha_seed_bars < 10 ? 10 : strategy_ha_seed_bars);
   const int start = shift + seed; // oldest bar of the recursion seed

   if(Bars(_Symbol, _Period) <= start + 1)
      return false;

   // Seed at the oldest bar: HA_open = (O+C)/2, HA_close = (O+H+L+C)/4.
   double o = iOpen(_Symbol, _Period, start);   // perf-allowed: bounded closed-bar read
   double h = iHigh(_Symbol, _Period, start);   // perf-allowed
   double l = iLow(_Symbol, _Period, start);    // perf-allowed
   double c = iClose(_Symbol, _Period, start);  // perf-allowed
   if(o <= 0.0 || c <= 0.0)
      return false;

   double prev_ha_open  = (o + c) / 2.0;
   double prev_ha_close = (o + h + l + c) / 4.0;

   // Recurse forward from start-1 down to `shift`.
   for(int s = start - 1; s >= shift; --s)
     {
      o = iOpen(_Symbol, _Period, s);   // perf-allowed: bounded closed-bar read
      h = iHigh(_Symbol, _Period, s);   // perf-allowed
      l = iLow(_Symbol, _Period, s);    // perf-allowed
      c = iClose(_Symbol, _Period, s);  // perf-allowed
      if(o <= 0.0 || c <= 0.0)
         return false;

      const double cur_ha_close = (o + h + l + c) / 4.0;
      const double cur_ha_open  = (prev_ha_open + prev_ha_close) / 2.0;

      prev_ha_open  = cur_ha_open;
      prev_ha_close = cur_ha_close;
     }

   ha_open  = prev_ha_open;
   ha_close = prev_ha_close;
   ha_high  = MathMax(MathMax(ha_open, ha_close), MathMax(h, l));
   ha_low   = MathMin(MathMin(ha_open, ha_close), MathMin(h, l));
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop distance reference = stop_atr_mult * ATR, so the cap scales.
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = strategy_stop_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Heikin-Ashi candles at shift 1 (last closed) and shift 2 (prior). ---
   double hao1, hac1, hah1, hal1;
   double hao2, hac2, hah2, hal2;
   if(!ComputeHA(1, hao1, hac1, hah1, hal1))
      return false;
   if(!ComputeHA(2, hao2, hac2, hah2, hal2))
      return false;

   // --- ATR for the minimum-body filter (and stop). ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double body1 = MathAbs(hao1 - hac1);
   const double body2 = MathAbs(hao2 - hac2);

   // No-upper-wick test, tolerant of float noise (1 tick).
   const double tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tol  = (tick > 0.0 ? tick : 0.0);

   // --- STATES (observed across the last two closed bars): ---
   //  signal-coloured candle (source: HA_open > HA_close), no upper wick,
   //  prior candle shares the colour (consecutive run), body >= min filter.
   const bool colour_1   = (hao1 > hac1);
   const bool colour_2   = (hao2 > hac2);
   const bool no_upper_1 = (MathAbs(hao1 - hah1) <= tol);
   const bool body_ok    = (body1 >= strategy_body_atr_frac * atr_value);

   // --- Trigger EVENT (single, fresh this bar): body EXPANDED = momentum. ---
   const bool body_expanded = (body1 > body2);

   if(colour_1 && colour_2 && no_upper_1 && body_ok && body_expanded)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_stop_atr_mult);
      if(sl <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // source has no profit target — exit on opposite HA condition
      req.reason = "ha_momo_long";
      return true;
     }

   return false;
  }

// No active management beyond the ATR emergency stop. Discretionary HA exit
// lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit (source opposite condition): close long when the last closed HA
// candle is opposite-coloured (HA_open < HA_close), has no lower wick
// (HA_open == HA_low), and the prior candle shares that opposite colour.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   double hao1, hac1, hah1, hal1;
   double hao2, hac2, hah2, hal2;
   if(!ComputeHA(1, hao1, hac1, hah1, hal1))
      return false;
   if(!ComputeHA(2, hao2, hac2, hah2, hal2))
      return false;

   const double tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tol  = (tick > 0.0 ? tick : 0.0);

   const bool opp_colour_1 = (hao1 < hac1);
   const bool opp_colour_2 = (hao2 < hac2);
   const bool no_lower_1   = (MathAbs(hao1 - hal1) <= tol);

   return (opp_colour_1 && opp_colour_2 && no_lower_1);
  }

// Defer to the central news filter.
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

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
