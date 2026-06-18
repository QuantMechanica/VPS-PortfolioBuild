#property strict
#property version   "5.0"
#property description "QM5_11266 qt-ha-trend — Heikin-Ashi trend/reversal (long-only, H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11266 qt-ha-trend
// -----------------------------------------------------------------------------
// Source: je-suis-tm/quant-trading "Heikin-Ashi backtest.py".
// Card: artifacts/cards_approved/QM5_11266_qt-ha-trend.md (g0_status APPROVED).
//
// There is NO Heikin-Ashi reader in the framework, so HA candles are
// reconstructed deterministically from raw OHLC by a BOUNDED forward roll:
//   HA_close = (O + H + L + C) / 4
//   HA_open  = (prior HA_open + prior HA_close) / 2   (recursive)
//   HA_high  = max(HA_open, HA_close, H, L)
//   HA_low   = min(HA_open, HA_close, H, L)
// The recursion is seeded HA_WARMUP bars before the target shift with
// HA_open := (O+C)/2 of the seed bar and rolled forward a FIXED number of
// steps. This makes every HA value a pure deterministic function of a bounded
// closed-bar OHLC window (no per-tick history scan beyond the fixed window,
// no external feed). The roll uses single closed-bar iOpen/iHigh/iLow/iClose
// reads (perf-allowed: bespoke structural reconstruction the QM_* readers do
// not provide).
//
// Mechanics (long-only, closed-bar reads at shift 1 = just-closed bar):
//   A HA COLOUR FLIP is the single EVENT.
//   Long ENTRY (all on shift 1, the just-closed bar):
//     - HA_open > HA_close                 (bearish-bodied expansion bar)
//     - HA_open == HA_high                  (no upper shadow)
//     - |HA_open - HA_close| > prior HA body (body expansion vs shift 2)
//     - prior bar also HA_open > HA_close   (two consecutive same-colour bars)
//     - body size >= min_ha_body_atr_frac * ATR(period)   (skip tiny bars)
//   EXIT (close the long):
//     - HA_open < HA_close                  (opposite colour)
//     - HA_open == HA_low                   (no lower shadow)
//     - prior bar also HA_open < HA_close
//     - OR time stop after time_stop_bars closed bars in trade.
//   Stop : entry - sl_atr_mult * ATR(period)   (hard ATR stop, no TP).
//
// Note on directional labels: the card text mirrors the source's quirky
// labelling verbatim (it "enters long" on the no-upper-shadow expansion
// sequence and exits on the no-lower-shadow opposite sequence). Implemented
// LITERALLY per the card; P3 may test the symmetric reverse variant.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11266;
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
input int    strategy_ha_warmup_bars      = 50;    // bounded HA reconstruction seed depth
input int    strategy_atr_period          = 14;    // ATR period (stop + body floor)
input double strategy_sl_atr_mult         = 2.0;   // hard stop distance = mult * ATR
input double strategy_min_ha_body_atr_frac = 0.25; // skip entries with HA body < frac * ATR
input int    strategy_time_stop_bars      = 20;    // close long after N closed bars if no HA exit

// -----------------------------------------------------------------------------
// Bounded deterministic Heikin-Ashi reconstruction
// -----------------------------------------------------------------------------
// Fills HA OHLC for a given closed-bar `shift` by seeding the recursion
// `strategy_ha_warmup_bars` bars earlier and rolling forward a fixed number of
// steps. Returns false if any raw bar in the window is unavailable.
bool ComputeHA(const int shift,
               double &ha_open, double &ha_high, double &ha_low, double &ha_close)
  {
   if(shift < 0)
      return false;

   const int warmup = (strategy_ha_warmup_bars < 1) ? 1 : strategy_ha_warmup_bars;
   const int seed_shift = shift + warmup; // oldest bar in the bounded window

   // Seed bar raw OHLC (perf-allowed: bespoke HA structural reconstruction).
   double o = iOpen(_Symbol, _Period, seed_shift);
   double c = iClose(_Symbol, _Period, seed_shift);
   if(o <= 0.0 || c <= 0.0)
      return false;

   // Seed HA: prev HA_open := (O+C)/2, prev HA_close := HA_close of seed bar.
   double prev_ha_open  = (o + c) / 2.0;
   double h = iHigh(_Symbol, _Period, seed_shift);
   double l = iLow(_Symbol, _Period, seed_shift);
   if(h <= 0.0 || l <= 0.0)
      return false;
   double prev_ha_close = (o + h + l + c) / 4.0;

   ha_open = prev_ha_open;
   ha_close = prev_ha_close;
   ha_high = MathMax(prev_ha_open, MathMax(prev_ha_close, h));
   ha_low  = MathMin(prev_ha_open, MathMin(prev_ha_close, l));

   // Roll forward from seed_shift-1 down to the target shift (fixed-length loop).
   for(int s = seed_shift - 1; s >= shift; --s)
     {
      o = iOpen(_Symbol, _Period, s);
      h = iHigh(_Symbol, _Period, s);
      l = iLow(_Symbol, _Period, s);
      c = iClose(_Symbol, _Period, s);
      if(o <= 0.0 || h <= 0.0 || l <= 0.0 || c <= 0.0)
         return false;

      ha_close = (o + h + l + c) / 4.0;
      ha_open  = (prev_ha_open + prev_ha_close) / 2.0;
      ha_high  = MathMax(ha_open, MathMax(ha_close, h));
      ha_low   = MathMin(ha_open, MathMin(ha_close, l));

      prev_ha_open  = ha_open;
      prev_ha_close = ha_close;
     }

   return (ha_open > 0.0 && ha_close > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No spread guard needed (.DWX models 0 spread and
// we must fail-open); regime/signal work is on the closed-bar path.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Reconstruct HA for the just-closed bar (shift 1) and the prior bar (shift 2).
   double o1, h1, l1, c1;
   double o2, h2, l2, c2;
   if(!ComputeHA(1, o1, h1, l1, c1))
      return false;
   if(!ComputeHA(2, o2, h2, l2, c2))
      return false;

   // Entry conditions (literal card mechanics on the just-closed bar):
   //  - HA_open > HA_close (bearish-bodied), no upper shadow (HA_open == HA_high)
   //  - body expansion vs prior HA body
   //  - prior bar same colour (HA_open > HA_close)
   const bool col1   = (o1 > c1);
   const bool col2   = (o2 > c2);
   const bool no_up  = (o1 >= h1); // HA_open == HA_high (>= guards FP rounding)
   const double body1 = MathAbs(o1 - c1);
   const double body2 = MathAbs(o2 - c2);
   const bool expand = (body1 > body2);

   if(!(col1 && col2 && no_up && expand))
      return false;

   // Volatility floor: skip tiny no-shadow bars (body >= frac * ATR).
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   if(body1 < strategy_min_ha_body_atr_frac * atr_value)
      return false;

   // Build the long entry. Framework sizes lots (no lots field). Hard ATR stop,
   // no take-profit (exit is HA reversal / time stop).
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP — HA reversal / time stop closes the trade
   req.reason = "ha_trend_long";
   return true;
  }

// No active trade management beyond the fixed ATR stop. Exit logic is in
// Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: opposite HA colour with no lower shadow on two consecutive bars, OR a
// time stop after strategy_time_stop_bars closed bars in the trade.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // --- HA reversal exit (literal card mechanics) ---
   double o1, h1, l1, c1;
   double o2, h2, l2, c2;
   if(ComputeHA(1, o1, h1, l1, c1) && ComputeHA(2, o2, h2, l2, c2))
     {
      const bool col1    = (o1 < c1);          // bullish-bodied HA
      const bool col2    = (o2 < c2);          // prior bar same colour
      const bool no_low  = (o1 <= l1);         // HA_open == HA_low (no lower shadow)
      if(col1 && col2 && no_low)
         return true;
     }

   // --- Time stop: close after N closed bars since entry ---
   if(strategy_time_stop_bars > 0)
     {
      datetime open_time = 0;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         open_time = (datetime)PositionGetInteger(POSITION_TIME);
         break;
        }
      if(open_time > 0)
        {
         const int bars_held = iBarShift(_Symbol, _Period, open_time, false);
         if(bars_held >= strategy_time_stop_bars)
            return true;
        }
     }

   return false;
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
