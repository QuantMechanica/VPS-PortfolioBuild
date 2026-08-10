#property strict
#property version   "5.0"
#property description "QM5_1312 ha-sma-smoothed-flip-h1 — Double-SMA-smoothed Heiken-Ashi color-flip, streak + no-wick confirmed, EMA(200) bias (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1312 ha-sma-smoothed-flip-h1
// -----------------------------------------------------------------------------
// Source: ForexFactory Trading-Systems "HA SMA smoothed" / "Smoothed Heiken
//   Ashi" cluster (mladen/igorad indicator lineage). Card:
//   artifacts/cards_approved/QM5_1312_ha-sma-smoothed-flip-h1.md (g0_status
//   APPROVED). Sibling of QM5_1313 (heiken-ashi-smoothed-flip-h1, EMA pre-
//   smooth, no streak/no-wick gate) — this card is the SMA pre-smoothed
//   variant with an added streak + no-wick entry confirmation.
//
// Mechanics (closed-bar reads at shift 1; smoothed-HA computed in-EA over a
// bounded recursive seed window, gated by QM_IsNewBar -> never per-tick):
//   Step 1 — Pre-smooth OHLC with SMA(6): O'=SMA(open,6), H'=SMA(high,6),
//            L'=SMA(low,6), C'=SMA(close,6) (QM_SMA pooled handles).
//   Step 2 — HA transform on the smoothed series (recursive from a bounded
//            seed): HAClose=(O'+H'+L'+C')/4 ; HAOpen=(HAOpen_prev+HAClose_prev)/2
//            (seed HAOpen=(O'+C')/2) ; HAHigh=max(H',HAOpen,HAClose) ;
//            HALow=min(L',HAOpen,HAClose).
//   Step 3 — Post-smooth HAOpen/HAClose with SMA(2): HAO''=SMA(HAOpen,2),
//            HAC''=SMA(HAClose,2). Color: bull = HAC''>HAO'', bear = HAC''<HAO''.
//
//   Entry (H1 close), BUY: color[0]=bull AND color[1]=bear AND color[2]=bear
//     (flip confirmed by a >=2-bar prior bear streak, prevents flicker) AND
//     no-wick: (HAO''[0]-HALow[0]) <= 0.35*(HAHigh[0]-HALow[0]) AND
//     macro bias: close(1) > EMA(close,200,H1). SELL mirrors.
//   Exit: color flip against position (single event) OR fixed TP
//     2.0*ATR(14,H1) OR EMA(200) cross against position (genuine cross, not a
//     level state) OR (framework) Friday close.
//   Stop: BUY = min(HALow[0],HALow[1]) - 0.5*ATR(14,H1); SELL mirror on high.
//   Session: 06:00-21:00 broker time. Spread guard: block only if spread >
//     1.5x the trailing 20-closed-bar median spread (sampled once per closed
//     H1 bar — .DWX models 0 spread so this fails open in the tester).
//   Re-arm: the flip trigger (color[0]!=color[1]) is edge-triggered — it
//     cannot re-fire on the following bar without an intervening opposite
//     flip, and one-position-per-magic blocks stacked entries within a leg.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1312;
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
input int    strategy_pre_smooth_period   = 6;     // OHLC pre-smoothing SMA period (P3 4..10)
input int    strategy_post_smooth_period  = 2;     // HA post-smoothing SMA period (P3 2..4)
input int    strategy_macro_ema_period    = 200;   // H1 macro-bias EMA (P3 150..250)
input int    strategy_ha_seed_bars        = 120;   // smoothed-HA recursion seed depth (bounded)
input double strategy_wick_max_fraction   = 0.35;  // no-wick gate: shadow <= this * HA range
input int    strategy_atr_period          = 14;    // ATR period (stop / target)
input double strategy_sl_atr_buffer       = 0.5;   // SL = min/max(HALow/HAHigh, 2 bars) -/+ buffer*ATR
input double strategy_tp_atr_mult         = 2.0;   // TP distance = mult * ATR from entry
input int    strategy_session_start_hour  = 6;     // broker-time session open (inclusive)
input int    strategy_session_end_hour    = 21;    // broker-time session close (exclusive)
input double strategy_spread_median_mult  = 1.5;   // skip if spread > this * 20-bar median spread
input int    strategy_spread_median_bars  = 20;    // rolling window for median spread

// -----------------------------------------------------------------------------
// Rolling spread-history ring buffer, sampled once per closed H1 bar.
// -----------------------------------------------------------------------------
#define QM_1312_SPREAD_WIN 20
double g_spread_hist[QM_1312_SPREAD_WIN];
int    g_spread_count = 0;
int    g_spread_idx   = 0;

void SampleSpreadOnNewBar()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return;
   const double spread = ask - bid;
   if(spread < 0.0)
      return; // crossed/negative quote only; .DWX zero spread is tradeable
   g_spread_hist[g_spread_idx] = spread;
   g_spread_idx = (g_spread_idx + 1) % QM_1312_SPREAD_WIN;
   if(g_spread_count < QM_1312_SPREAD_WIN)
      g_spread_count++;
  }

double MedianSpread()
  {
   const int n = MathMin(g_spread_count, strategy_spread_median_bars);
   if(n < 5)
      return -1.0; // not enough samples yet -> caller fails open
   double buf[];
   ArrayResize(buf, n);
   for(int i = 0; i < n; ++i)
      buf[i] = g_spread_hist[i];
   ArraySort(buf); // MQL5 ArraySort: ascending, whole array
   if(n % 2 == 1)
      return buf[n / 2];
   return (buf[n / 2 - 1] + buf[n / 2]) / 2.0;
  }

// -----------------------------------------------------------------------------
// Double-SMA-smoothed Heiken-Ashi: recursive bounded-window computation.
// Returns, for rel = 0,1,2 (shift, shift+1, shift+2): post-smoothed HAOpen/
// HAClose (SMA(post) of the raw HA line), raw HAHigh/HALow (from the base
// recursion, NOT post-smoothed — per card, the no-wick/SL rules read the raw
// range), and the discrete color at each rel. perf-allowed: bounded
// closed-bar QM_SMA reads on the QM_IsNewBar-gated entry/exit path only.
// -----------------------------------------------------------------------------
bool ComputeSmoothedHA3(const int shift,
                        double &sm_open3[], double &sm_close3[],
                        double &raw_high3[], double &raw_low3[],
                        int &color3[])
  {
   const int pre  = (strategy_pre_smooth_period  < 1 ? 1 : strategy_pre_smooth_period);
   const int post = (strategy_post_smooth_period < 1 ? 1 : strategy_post_smooth_period);
   const int seed = (strategy_ha_seed_bars < 20 ? 20 : strategy_ha_seed_bars);

   const int oldest = shift + seed;
   if(Bars(_Symbol, _Period) <= oldest + pre + 2) // perf-allowed
      return false;

   const int keep = post + 3;
   double ha_open_win[];
   double ha_close_win[];
   ArrayResize(ha_open_win, keep);
   ArrayResize(ha_close_win, keep);
   ArrayInitialize(ha_open_win, 0.0);
   ArrayInitialize(ha_close_win, 0.0);

   double sO = QM_SMA(_Symbol, _Period, pre, oldest, PRICE_OPEN);
   double sH = QM_SMA(_Symbol, _Period, pre, oldest, PRICE_HIGH);
   double sL = QM_SMA(_Symbol, _Period, pre, oldest, PRICE_LOW);
   double sC = QM_SMA(_Symbol, _Period, pre, oldest, PRICE_CLOSE);
   if(sO <= 0.0 || sC <= 0.0)
      return false;

   double prev_ha_open  = (sO + sC) / 2.0;
   double prev_ha_close = (sO + sH + sL + sC) / 4.0;

   double smo_at[3], smc_at[3], smh_at[3], sml_at[3];
   bool   have_at[3];
   for(int k = 0; k < 3; ++k)
     {
      smo_at[k] = 0.0; smc_at[k] = 0.0; smh_at[k] = 0.0; sml_at[k] = 0.0;
      have_at[k] = false;
     }

   int win_count = 0;
   ha_open_win[win_count % keep]  = prev_ha_open;
   ha_close_win[win_count % keep] = prev_ha_close;
   win_count++;

   for(int s = oldest - 1; s >= shift; --s)
     {
      sO = QM_SMA(_Symbol, _Period, pre, s, PRICE_OPEN);
      sH = QM_SMA(_Symbol, _Period, pre, s, PRICE_HIGH);
      sL = QM_SMA(_Symbol, _Period, pre, s, PRICE_LOW);
      sC = QM_SMA(_Symbol, _Period, pre, s, PRICE_CLOSE);
      if(sO <= 0.0 || sC <= 0.0)
         return false;

      const double cur_ha_close = (sO + sH + sL + sC) / 4.0;
      const double cur_ha_open  = (prev_ha_open + prev_ha_close) / 2.0;
      const double cur_ha_high  = MathMax(sH, MathMax(cur_ha_open, cur_ha_close));
      const double cur_ha_low   = MathMin(sL, MathMin(cur_ha_open, cur_ha_close));

      prev_ha_open  = cur_ha_open;
      prev_ha_close = cur_ha_close;

      ha_open_win[win_count % keep]  = cur_ha_open;
      ha_close_win[win_count % keep] = cur_ha_close;
      win_count++;

      if(win_count >= post)
        {
         double sum_o = 0.0, sum_c = 0.0;
         for(int j = 0; j < post; ++j)
           {
            const int idx = (win_count - 1 - j) % keep;
            sum_o += ha_open_win[idx];
            sum_c += ha_close_win[idx];
           }
         const double po = sum_o / post;
         const double pc = sum_c / post;

         const int rel = s - shift; // 0,1,2 for the bars we care about
         if(rel >= 0 && rel <= 2)
           {
            smo_at[rel] = po;
            smc_at[rel] = pc;
            smh_at[rel] = cur_ha_high;
            sml_at[rel] = cur_ha_low;
            have_at[rel] = true;
           }
        }
     }

   if(!have_at[0] || !have_at[1] || !have_at[2])
      return false;

   ArrayResize(sm_open3, 3);  ArrayResize(sm_close3, 3);
   ArrayResize(raw_high3, 3); ArrayResize(raw_low3, 3);
   ArrayResize(color3, 3);
   for(int k = 0; k < 3; ++k)
     {
      sm_open3[k]  = smo_at[k];
      sm_close3[k] = smc_at[k];
      raw_high3[k] = smh_at[k];
      raw_low3[k]  = sml_at[k];
      color3[k]    = (smc_at[k] > smo_at[k]) ? +1 : -1;
     }
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1)-ish per-tick gate: session window + median-spread guard (the
// median itself is a cached rolling-buffer read, not recomputed per tick).
// Fail-open when there is not yet enough spread history.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int h = dt.hour;
   if(strategy_session_start_hour <= strategy_session_end_hour)
     {
      if(h < strategy_session_start_hour || h >= strategy_session_end_hour)
         return true;
     }
   else
     {
      if(h < strategy_session_start_hour && h >= strategy_session_end_hour)
         return true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote -> do not block

   const double med = MedianSpread();
   if(med <= 0.0)
      return false; // insufficient history -> fail open

   const double spread = ask - bid;
   if(spread > 0.0 && spread > strategy_spread_median_mult * med)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate) and that
// SampleSpreadOnNewBar() has already run this bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   double sm_open3[], sm_close3[], raw_high3[], raw_low3[];
   int    color3[];
   if(!ComputeSmoothedHA3(1, sm_open3, sm_close3, raw_high3, raw_low3, color3))
      return false;

   const double ema = QM_EMA(_Symbol, _Period, strategy_macro_ema_period, 1);
   if(ema <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double range0 = raw_high3[0] - raw_low3[0];
   if(range0 <= 0.0)
      return false;

   // color3[0]=color[0] (signal bar), color3[1]=color[1], color3[2]=color[2].
   const bool flip_up   = (color3[0] == +1 && color3[1] == -1 && color3[2] == -1);
   const bool flip_down = (color3[0] == -1 && color3[1] == +1 && color3[2] == +1);

   if(flip_up && close1 > ema)
     {
      // No-wick confirmation: lower shadow (HAO''[0]-HALow[0]) small.
      const double lower_shadow = sm_open3[0] - raw_low3[0];
      if(lower_shadow > strategy_wick_max_fraction * range0)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      double sl = MathMin(raw_low3[0], raw_low3[1]) - strategy_sl_atr_buffer * atr_value;
      sl = QM_TM_NormalizePrice(_Symbol, sl);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0 || sl >= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ha_sma_flip_long";
      return true;
     }

   if(flip_down && close1 < ema)
     {
      // No-wick confirmation: upper shadow (HAHigh[0]-HAO''[0]) small.
      const double upper_shadow = raw_high3[0] - sm_open3[0];
      if(upper_shadow > strategy_wick_max_fraction * range0)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      double sl = MathMax(raw_high3[0], raw_high3[1]) + strategy_sl_atr_buffer * atr_value;
      sl = QM_TM_NormalizePrice(_Symbol, sl);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0 || sl <= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ha_sma_flip_short";
      return true;
     }

   return false;
  }

// No active management beyond the fixed ATR SL/TP; discretionary exits (color
// flip, EMA cross) live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exits: color flip against the position (single event), or a
// genuine EMA(200) cross against the position (was on-side last closed bar,
// is off-side this closed bar).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   double sm_open3[], sm_close3[], raw_high3[], raw_low3[];
   int    color3[];
   if(!ComputeSmoothedHA3(1, sm_open3, sm_close3, raw_high3, raw_low3, color3))
      return false;

   const bool flip_to_bear = (color3[0] == -1 && color3[1] == +1);
   const bool flip_to_bull = (color3[0] == +1 && color3[1] == -1);

   const double ema1 = QM_EMA(_Symbol, _Period, strategy_macro_ema_period, 1);
   const double ema2 = QM_EMA(_Symbol, _Period, strategy_macro_ema_period, 2);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const bool have_ema = (ema1 > 0.0 && ema2 > 0.0 && close1 > 0.0 && close2 > 0.0);
   const bool crossed_below = have_ema && close2 >= ema2 && close1 < ema1;
   const bool crossed_above = have_ema && close2 <= ema2 && close1 > ema1;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && (flip_to_bear || crossed_below))
         return true;
      if(ptype == POSITION_TYPE_SELL && (flip_to_bull || crossed_above))
         return true;
     }
   return false;
  }

// Defer to the central two-axis news filter.
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

   ArrayInitialize(g_spread_hist, 0.0);
   g_spread_count = 0;
   g_spread_idx   = 0;

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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Management + rule-based exits run through news windows (gate entries
   // only, per the 2026-07-02 audit ordering rule).
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   SampleSpreadOnNewBar();
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
