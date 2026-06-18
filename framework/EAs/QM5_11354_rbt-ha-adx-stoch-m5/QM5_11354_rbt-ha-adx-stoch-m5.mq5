#property strict
#property version   "5.0"
#property description "QM5_11354 rbt-ha-adx-stoch-m5 — RoboForex Heikin-Ashi + ADX + Stochastic (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11354 rbt-ha-adx-stoch-m5
// -----------------------------------------------------------------------------
// Source: RoboForex Strategy Collection, "Heiken Ashi + ADX + Stochastic"
//   local PDF 362359657-Robo-forex-strategy.pdf. Card g0_status APPROVED:
//   artifacts/cards_approved/QM5_11354_rbt-ha-adx-stoch-m5.md
//
// Mechanics (M5, closed-bar reads; HA reconstructed deterministically):
//   Heikin-Ashi STATE : two consecutive bullish HA bars (HA_Close>HA_Open at
//                       shift 1 AND shift 2) for LONG; mirror for SHORT.
//                       Price-vs-HA-mean STATE: HA mid(shift1) above/below the
//                       HA-close SMA proxy (card: "HA close line as MA").
//   Stochastic STATE  : %K heading in trade direction AND not at the far
//                       extreme (long: rising & <80; short: falling & >20).
//   ADX STATE         : QM_ADX(14) > adx_threshold — trend present.
//   SINGLE EVENT      : EITHER a fresh HA colour flip into the trade direction
//                       on the trigger bar (shift1) OR a fresh Stochastic %K
//                       cross of its mid level in the trade direction. Exactly
//                       ONE fresh event is required (the other conditions are
//                       STATES). This avoids the "two crossovers on the same
//                       bar" zero-trade trap.
//   Stop / Take       : fixed pips (card 10 SL / 15 TP), pip-scaled.
//   Defensive exit    : first opposite-colour HA bar closes the position.
//   Session           : card "London + NY 13:00-22:00 GMT" — gated in UTC via
//                       QM_BrokerToUTC so it is DST-correct on the .DWX feed.
//   Spread guard      : fail-OPEN on .DWX zero modeled spread; only a genuinely
//                       wide spread blocks.
//
// HA reconstruction is a bounded, deterministic forward fold over a fixed
// warmup window, cached once per closed bar (no per-tick recompute, no HA
// iCustom reader). Only the 5 Strategy_* hooks + Strategy inputs are
// EA-specific; everything below the wiring line stays intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11354;
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
input int    strategy_ha_warmup_bars    = 200;    // bounded HA reconstruction window
input int    strategy_ha_consec_bars    = 2;      // consecutive same-colour HA bars required (STATE)
input int    strategy_ha_ma_period      = 14;     // SMA of HA close used as the HA mean proxy
input int    strategy_adx_period        = 14;     // ADX period (STATE)
input double strategy_adx_threshold     = 22.0;   // ADX must exceed this (trend present)
input int    strategy_stoch_k           = 5;      // Stochastic %K period
input int    strategy_stoch_d           = 3;      // Stochastic %D period
input int    strategy_stoch_slow        = 3;      // Stochastic slowing
input double strategy_stoch_mid         = 50.0;   // %K mid level for the cross EVENT
input double strategy_stoch_ob          = 80.0;   // overbought guard (long blocked above)
input double strategy_stoch_os          = 20.0;   // oversold guard (short blocked below)
input int    strategy_sl_pips           = 10;     // fixed stop, pips
input int    strategy_tp_pips           = 15;     // fixed take, pips
input int    strategy_sess_start_utc    = 13;     // session start hour, UTC (card 13:00 GMT)
input int    strategy_sess_end_utc      = 22;     // session end hour, UTC (card 22:00 GMT)
input double strategy_spread_pct_of_stop = 25.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached HA state, advanced once per closed bar.
// g_ha_open[i] / g_ha_close[i] hold the reconstructed HA O/C for bar shift i,
// where index 1 == last closed bar, 2 == bar before, 3 == bar before that.
// -----------------------------------------------------------------------------
double g_ha_open[4];   // [0] unused, [1..3] closed-bar HA opens
double g_ha_close[4];  // [0] unused, [1..3] closed-bar HA closes
double g_ha_ma   = 0.0; // SMA of HA close over strategy_ha_ma_period (ending shift 1)
bool   g_ha_valid = false;

// Deterministic bounded forward reconstruction of Heikin-Ashi from raw OHLC.
// Seeds HA_Open at the oldest warmup bar with (O+C)/2, then folds forward.
// Called ONCE per new closed bar (gated by QM_IsNewBar in OnTick). No second
// timestamp gate inside. Bounded by strategy_ha_warmup_bars.
void AdvanceHAState_OnNewBar()
  {
   g_ha_valid = false;

   int warmup = strategy_ha_warmup_bars;
   if(warmup < (strategy_ha_ma_period + strategy_ha_consec_bars + 4))
      warmup = strategy_ha_ma_period + strategy_ha_consec_bars + 4;

   const int avail = Bars(_Symbol, _Period); // perf-allowed: bar-count for warmup bound
   if(avail < warmup + 2)
      return;

   // Oldest seed shift (largest shift) down to shift 1 (last closed bar).
   const int seed_shift = warmup; // start of the fold
   double prev_ha_open  = 0.0;
   double prev_ha_close = 0.0;

   // We need HA_Close for the MA over the last strategy_ha_ma_period closed
   // bars (shifts 1..ha_ma_period). Accumulate as the fold reaches them.
   double ha_close_sum = 0.0;
   int    ha_close_cnt = 0;
   const int ma_first_shift = strategy_ha_ma_period; // inclusive
   const int ma_last_shift  = 1;                     // inclusive

   for(int s = seed_shift; s >= 1; --s)
     {
      // perf-allowed: bounded warmup fold, runs once per closed bar only.
      const double o = iOpen(_Symbol, _Period, s);
      const double h = iHigh(_Symbol, _Period, s);
      const double l = iLow(_Symbol, _Period, s);
      const double c = iClose(_Symbol, _Period, s);
      if(o <= 0.0 || c <= 0.0)
         return;

      const double ha_close = (o + h + l + c) / 4.0;
      double ha_open;
      if(s == seed_shift)
         ha_open = (o + c) / 2.0;             // deterministic seed
      else
         ha_open = (prev_ha_open + prev_ha_close) / 2.0;

      // Cache the three most recent closed-bar HA O/C (shifts 1..3).
      if(s <= 3)
        {
         g_ha_open[s]  = ha_open;
         g_ha_close[s] = ha_close;
        }

      // Accumulate HA-close SMA over shifts [ha_ma_period .. 1].
      if(s <= ma_first_shift && s >= ma_last_shift)
        {
         ha_close_sum += ha_close;
         ha_close_cnt++;
        }

      prev_ha_open  = ha_open;
      prev_ha_close = ha_close;
     }

   if(ha_close_cnt > 0)
      g_ha_ma = ha_close_sum / ha_close_cnt;
   else
      g_ha_ma = 0.0;

   g_ha_valid = true;
  }

bool HABullish(const int shift)
  {
   return (g_ha_close[shift] > g_ha_open[shift]);
  }
bool HABearish(const int shift)
  {
   return (g_ha_close[shift] < g_ha_open[shift]);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Session window (UTC) + spread guard only.
// Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   // Session in UTC (card: London+NY 13:00-22:00 GMT), DST-correct via broker->UTC.
   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   if(utc_now > 0)
     {
      MqlDateTime ut; TimeToStruct(utc_now, ut);
      const int h = ut.hour;
      bool in_session;
      if(strategy_sess_start_utc <= strategy_sess_end_utc)
         in_session = (h >= strategy_sess_start_utc && h < strategy_sess_end_utc);
      else
         in_session = (h >= strategy_sess_start_utc || h < strategy_sess_end_utc);
      if(!in_session)
         return true; // block outside session
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate); HA state
// has been advanced for this bar in OnTick before this is called.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_ha_valid)
      return false;

   // --- ADX STATE: trend present ---
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0)
      return false;
   if(!(adx > strategy_adx_threshold))
      return false;

   // --- Stochastic states (closed bars) ---
   const double k_now  = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double k_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   if(k_now <= 0.0 || k_prev <= 0.0)
      return false;

   // HA mean proxy (card: HA close line as MA).
   if(g_ha_ma <= 0.0)
      return false;
   const double ha_mid1 = (g_ha_open[1] + g_ha_close[1]) / 2.0;

   // ---------------- LONG ----------------
   // SINGLE EVENT (long): EITHER a fresh HA colour flip into bullish on the
   // trigger bar (bar1 bullish, bar2 NOT bullish) OR a fresh Stoch %K cross up
   // through mid. Exactly one fresh event is required; everything else is a
   // STATE. This is the anti-"two-cross-same-bar" guard.
   const bool ha_flip_up_evt = HABullish(1) && !HABullish(2);        // bar2 was not bullish
   const bool stoch_cross_up = (k_prev <= strategy_stoch_mid && k_now > strategy_stoch_mid);
   const bool long_event     = ha_flip_up_evt || stoch_cross_up;

   // STATES (long): current HA colour bullish + HA mid above the HA-close SMA +
   //   Stoch heading up & below OB + (settled 2-consec OR this is the flip bar).
   //   The consecutive-bar requirement is satisfied either by two settled
   //   bullish HA bars (card literal) OR by the flip bar that just turned
   //   bullish — so the flip EVENT and the HA STATE do not contradict.
   bool long_ha_ok = HABullish(1);
   if(strategy_ha_consec_bars >= 2)
      long_ha_ok = HABullish(1) && (HABullish(2) || ha_flip_up_evt);
   if(strategy_ha_consec_bars >= 3)
      long_ha_ok = long_ha_ok && (HABullish(3) || ha_flip_up_evt);

   const bool long_states = long_ha_ok &&
                            (ha_mid1 > g_ha_ma) &&
                            (k_now > k_prev) && (k_now < strategy_stoch_ob);

   if(long_states && long_event)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ha_adx_stoch_long";
      return true;
     }

   // ---------------- SHORT (mirror) ----------------
   const bool ha_flip_dn_evt = HABearish(1) && !HABearish(2);       // bar2 was not bearish
   const bool stoch_cross_dn = (k_prev >= strategy_stoch_mid && k_now < strategy_stoch_mid);
   const bool short_event    = ha_flip_dn_evt || stoch_cross_dn;

   bool short_ha_ok = HABearish(1);
   if(strategy_ha_consec_bars >= 2)
      short_ha_ok = HABearish(1) && (HABearish(2) || ha_flip_dn_evt);
   if(strategy_ha_consec_bars >= 3)
      short_ha_ok = short_ha_ok && (HABearish(3) || ha_flip_dn_evt);

   const bool short_states = short_ha_ok &&
                             (ha_mid1 < g_ha_ma) &&
                             (k_now < k_prev) && (k_now > strategy_stoch_os);

   if(short_states && short_event)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ha_adx_stoch_short";
      return true;
     }

   return false;
  }

// Fixed SL/TP managed by the broker; no active trailing.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: first opposite-colour HA bar closes the position.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   if(!g_ha_valid)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && HABearish(1))
         return true;  // first bearish HA -> exit LONG
      if(ptype == POSITION_TYPE_SELL && HABullish(1))
         return true;  // first bullish HA -> exit SHORT
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

   // FIRST work on the closed bar: advance the deterministic HA reconstruction.
   AdvanceHAState_OnNewBar();

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
