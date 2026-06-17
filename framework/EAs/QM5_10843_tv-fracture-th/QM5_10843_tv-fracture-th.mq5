#property strict
#property version   "5.0"
#property description "QM5_10843 TradingView Fracture Threshold EMA Score (M15 trend-confluence)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10843 tv-fracture-th
// -----------------------------------------------------------------------------
// Card: artifacts/cards_approved/QM5_10843_tv-fracture-th.md
// Source: TradingView "Fracture Threshold Strategy [JOAT]"
//         (officialjackofalltrades), open-source mechanical strategy.
//
// Mechanics (M15 baseline, all reads on the CLOSED bar = shift 1):
//   Seven-condition MasterTrend bull/bear score:
//     1. EMA(4)  vs EMA(5)
//     2. RSI(14) vs 50
//     3. Close   vs EMA(21)
//     4. EMA(21) vs SMA(50)
//     5. SMA(50) vs EMA(55)
//     6. EMA(55) vs EMA(89)
//     7. Close   vs EMA(750)
//   Volume regime: volRatio = EMA(shortVolMA / longVolMA, smoothing) >= 0.90
//                  (tick volume on .DWX).
//   Session filter: London + New York broker-time windows (either active).
//   Trigger EVENT (only one fresh cross): EMA(4) crosses EMA(5) on confirmed bar.
//   Long  = bull score>=min AND volume-pass AND session AND EMA(4) crosses UP   EMA(5).
//   Short = bear score>=min AND volume-pass AND session AND EMA(4) crosses DOWN EMA(5).
//   Stop  = 1.5 * ATR(14). TP = 3.0R. One position per symbol/magic.
//   Spread guard: skip if a genuinely wide spread exceeds 15% of stop distance
//                 (fail-open on .DWX zero modeled spread).
//
// Framework owns: lot sizing, magic, news, Friday close, kill switch, new-bar
// gate, indicator handle pooling. Only the five Strategy_* hooks are bespoke.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10843;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// --- MasterTrend score EMAs/SMA (closed-bar shift 1) ---
input int    strategy_ema_fast          = 4;     // fast trigger EMA
input int    strategy_ema_signal        = 5;     // signal trigger EMA
input int    strategy_rsi_period        = 14;    // RSI for >50 / <50 condition
input int    strategy_ema_mid           = 21;    // close-vs and stack EMA
input int    strategy_sma_mid           = 50;    // SMA(50) stack
input int    strategy_ema_slow1         = 55;    // EMA(55) stack
input int    strategy_ema_slow2         = 89;    // EMA(89) stack
input int    strategy_ema_baseline      = 750;   // long-trend baseline EMA
input int    strategy_min_score         = 5;     // min MasterTrend score (of 7)
// --- Relative volume regime ---
input bool   strategy_volume_gate_on    = true;  // enable volume regime filter
input int    strategy_vol_short         = 5;     // short tick-volume MA length
input int    strategy_vol_long          = 20;    // long tick-volume MA length
input int    strategy_vol_smooth        = 14;    // EMA smoothing of the ratio
input double strategy_vol_threshold     = 0.90;  // volRatio pass threshold
// --- Session windows (BROKER time hours; defaults for DXZ NY-Close GMT+2) ---
input bool   strategy_session_london_on = true;  // London window enabled
input int    strategy_london_start_hr   = 10;    // London 08:00 UTC -> broker ~10
input int    strategy_london_end_hr     = 19;    // London 17:00 UTC -> broker ~19
input bool   strategy_session_ny_on     = true;  // New York window enabled
input int    strategy_ny_start_hr       = 16;    // NY 14:00 UTC -> broker ~16
input int    strategy_ny_end_hr         = 23;    // NY 21:00 UTC -> broker ~23
// --- Stop / target ---
input int    strategy_atr_period        = 14;    // ATR period for stop distance
input double strategy_atr_sl_mult       = 1.5;   // stop = 1.5 * ATR(14)
input double strategy_reward_risk       = 3.0;   // take profit at 3.0R
input double strategy_spread_stop_frac  = 0.15;  // skip if spread > 15% of stop dist
input int    strategy_warmup_bars       = 750;   // EMA(750) warmup requirement

// File-scope cached relative-volume regime state. Advanced ONCE per closed bar.
double  g_vol_ratio_ema   = 0.0;    // EMA-smoothed (shortVolMA/longVolMA)
bool    g_vol_ratio_ready = false;  // false until first valid bar fills it

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Bull MasterTrend score (0..7) on the closed bar (shift 1).
int Strategy_BullScore()
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double ema_fast = QM_EMA(_Symbol, tf, strategy_ema_fast,   1);
   const double ema_sig  = QM_EMA(_Symbol, tf, strategy_ema_signal, 1);
   const double rsi      = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, tf, strategy_ema_mid,    1);
   const double sma_mid  = QM_SMA(_Symbol, tf, strategy_sma_mid,    1);
   const double ema_s1   = QM_EMA(_Symbol, tf, strategy_ema_slow1,  1);
   const double ema_s2   = QM_EMA(_Symbol, tf, strategy_ema_slow2,  1);
   const double ema_base = QM_EMA(_Symbol, tf, strategy_ema_baseline, 1);
   const double close1   = iClose(_Symbol, tf, 1); // perf-allowed: single closed-bar close read, O(1); gated by QM_IsNewBar before entry.

   int s = 0;
   if(ema_fast > ema_sig) s++;
   if(rsi > 50.0)         s++;
   if(close1 > ema_mid)   s++;
   if(ema_mid > sma_mid)  s++;
   if(sma_mid > ema_s1)   s++;
   if(ema_s1 > ema_s2)    s++;
   if(close1 > ema_base)  s++;
   return s;
  }

// Bear MasterTrend score (0..7) on the closed bar (shift 1) — mirror of bull.
int Strategy_BearScore()
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double ema_fast = QM_EMA(_Symbol, tf, strategy_ema_fast,   1);
   const double ema_sig  = QM_EMA(_Symbol, tf, strategy_ema_signal, 1);
   const double rsi      = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, tf, strategy_ema_mid,    1);
   const double sma_mid  = QM_SMA(_Symbol, tf, strategy_sma_mid,    1);
   const double ema_s1   = QM_EMA(_Symbol, tf, strategy_ema_slow1,  1);
   const double ema_s2   = QM_EMA(_Symbol, tf, strategy_ema_slow2,  1);
   const double ema_base = QM_EMA(_Symbol, tf, strategy_ema_baseline, 1);
   const double close1   = iClose(_Symbol, tf, 1); // perf-allowed: single closed-bar close read, O(1); gated by QM_IsNewBar before entry.

   int s = 0;
   if(ema_fast < ema_sig) s++;
   if(rsi < 50.0)         s++;
   if(close1 < ema_mid)   s++;
   if(ema_mid < sma_mid)  s++;
   if(sma_mid < ema_s1)   s++;
   if(ema_s1 < ema_s2)    s++;
   if(close1 < ema_base)  s++;
   return s;
  }

// Advance the cached relative-volume regime by ONE closed bar.
// volRatio = EMA( shortVolMA / longVolMA, smoothing ) evaluated on shift 1.
// Called ONCE per new closed bar from Strategy_EntrySignal's new-bar context.
void Strategy_AdvanceVolumeRegime()
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const int need = strategy_vol_long + 1;
   long vols[];
   // perf-allowed: single closed-bar tick-volume window copy, O(vol_long) once
   // per new bar (Strategy_EntrySignal runs only after QM_IsNewBar()). .DWX has
   // no real volume; tick volume is the documented proxy per the card.
   if(CopyTickVolume(_Symbol, tf, 1, need, vols) < need)
      return;

   double sum_short = 0.0;
   for(int i = 0; i < strategy_vol_short && i < need; i++)
      sum_short += (double)vols[i];
   double sum_long = 0.0;
   for(int j = 0; j < strategy_vol_long && j < need; j++)
      sum_long += (double)vols[j];

   const double n_short = (double)MathMin(strategy_vol_short, need);
   const double n_long  = (double)MathMin(strategy_vol_long,  need);
   if(n_short <= 0.0 || n_long <= 0.0)
      return;

   const double short_ma = sum_short / n_short;
   const double long_ma  = sum_long  / n_long;
   if(long_ma <= 0.0)
      return;

   const double ratio = short_ma / long_ma;

   if(!g_vol_ratio_ready)
     {
      g_vol_ratio_ema   = ratio;     // seed
      g_vol_ratio_ready = true;
      return;
     }
   const double k = 2.0 / (double)(strategy_vol_smooth + 1);
   g_vol_ratio_ema = ratio * k + g_vol_ratio_ema * (1.0 - k);
  }

// True when the (cached) relative-volume regime passes the threshold.
bool Strategy_VolumePass()
  {
   if(!strategy_volume_gate_on)
      return true;
   if(!g_vol_ratio_ready)
      return false;
   return (g_vol_ratio_ema >= strategy_vol_threshold);
  }

// Session active if either enabled window currently contains broker time.
bool Strategy_SessionActive(const datetime broker_now)
  {
   bool active = false;
   if(strategy_session_london_on &&
      QM_Sig_Session(broker_now, strategy_london_start_hr, strategy_london_end_hr) > 0)
      active = true;
   if(strategy_session_ny_on &&
      QM_Sig_Session(broker_now, strategy_ny_start_hr, strategy_ny_end_hr) > 0)
      active = true;
   return active;
  }

// Fresh EMA(fast)/EMA(signal) cross direction on the confirmed (closed) bar.
// +1 = fast crossed ABOVE signal (bull trigger), -1 = crossed BELOW, 0 = none.
// Cross is the single EVENT; score/volume/session are STATES (invariant #4).
int Strategy_FastCross()
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double fast1 = QM_EMA(_Symbol, tf, strategy_ema_fast,   1);
   const double sig1  = QM_EMA(_Symbol, tf, strategy_ema_signal, 1);
   const double fast2 = QM_EMA(_Symbol, tf, strategy_ema_fast,   2);
   const double sig2  = QM_EMA(_Symbol, tf, strategy_ema_signal, 2);
   if(fast2 <= sig2 && fast1 > sig1) return +1;
   if(fast2 >= sig2 && fast1 < sig1) return -1;
   return 0;
  }

// True if this EA's magic already holds an open position (one-per-symbol).
bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter — cheap O(1) per-tick guards (valid quotes + warmup ready).
// Spread guard lives in Strategy_EntrySignal where the stop distance is known.
bool Strategy_NoTradeFilter()
  {
   const double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;
   if(Bars(_Symbol, (ENUM_TIMEFRAMES)_Period) < strategy_warmup_bars + 5)
      return true; // EMA(750) not warmed up yet
   return false;
  }

// Trade Entry — confirmed-bar EMA(4)/EMA(5) cross with MasterTrend score,
// relative-volume regime, and session all aligned. One position per symbol.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Advance cached volume regime once per closed bar (caller guarantees newbar).
   Strategy_AdvanceVolumeRegime();

   if(Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   if(!Strategy_SessionActive(broker_now))
      return false;
   if(!Strategy_VolumePass())
      return false;

   const int cross = Strategy_FastCross();
   if(cross == 0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   QM_OrderType order_type;
   double entry_price;
   if(cross > 0)
     {
      if(Strategy_BullScore() < strategy_min_score)
         return false;
      order_type  = QM_BUY;
      entry_price = ask;
     }
   else
     {
      if(Strategy_BearScore() < strategy_min_score)
         return false;
      order_type  = QM_SELL;
      entry_price = bid;
     }

   // Stop = strategy_atr_sl_mult * ATR(14) from entry (as a PRICE).
   const double sl_price = QM_StopATRFromValue(_Symbol, order_type, entry_price,
                                               atr, strategy_atr_sl_mult);
   if(sl_price <= 0.0)
      return false;

   const double stop_dist = MathAbs(entry_price - sl_price);
   if(stop_dist <= 0.0)
      return false;

   // V5 spread guard — fail-open on .DWX zero modeled spread; only block a
   // genuinely wide spread that exceeds the configured fraction of the stop.
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double spread = ask - bid;
      if(spread > strategy_spread_stop_frac * stop_dist)
         return false;
     }

   const double tp_price = QM_TakeRR(_Symbol, order_type, entry_price, sl_price,
                                     strategy_reward_risk);
   if(tp_price <= 0.0)
      return false;

   req.type               = order_type;
   req.price              = 0.0;        // framework fills market at send
   req.sl                 = sl_price;
   req.tp                 = tp_price;
   req.reason             = (cross > 0) ? "FRACTURE_LONG" : "FRACTURE_SHORT";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management — baseline has no trailing/break-even; SL/TP are static.
void Strategy_ManageOpenPosition()
  {
   // Baseline: fixed 1.5-ATR stop and 3R target only. No trade-management work.
  }

// Trade Close — no discretionary exit; positions resolve via SL or 3R TP.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook — no strategy-specific override; defer to the central
// framework news filter (callable for the Q09 News Impact phase).
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
