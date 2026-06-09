#property strict
#property version   "5.0"
#property description "QM5_10197 TradingView SSL WaveTrend Keltner"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10197;
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
input int    strategy_ssl_period        = 10;
input int    strategy_baseline_ema      = 60;
input int    strategy_wt_channel_len    = 10;
input int    strategy_wt_average_len    = 21;
input int    strategy_wt_signal_len     = 4;
input int    strategy_keltner_ema       = 20;
input double strategy_keltner_atr_mult  = 1.5;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
input double strategy_rr                = 2.0;
input double strategy_max_candle_atr    = 1.5;
input int    strategy_ema_sr_period     = 200;

double Strategy_TypicalPrice(const int shift)
  {
   const double h = iHigh(_Symbol, _Period, shift);   // perf-allowed: WaveTrend needs closed-bar typical price; no framework OHLC reader exists.
   const double l = iLow(_Symbol, _Period, shift);    // perf-allowed: WaveTrend needs closed-bar typical price; no framework OHLC reader exists.
   const double c = iClose(_Symbol, _Period, shift);  // perf-allowed: WaveTrend needs closed-bar typical price; no framework OHLC reader exists.
   if(h <= 0.0 || l <= 0.0 || c <= 0.0)
      return 0.0;
   return (h + l + c) / 3.0;
  }

double Strategy_WaveTrend(const int shift)
  {
   if(strategy_wt_channel_len < 1 || strategy_wt_average_len < 1)
      return 0.0;

   const int warmup = MathMax(80, strategy_wt_channel_len * 8 + strategy_wt_average_len * 4);
   const int start = shift + warmup;
   if(Bars(_Symbol, _Period) <= start + 2) // perf-allowed: bounded warmup availability check inside closed-bar entry path.
      return 0.0;

   const double alpha_esa = 2.0 / ((double)strategy_wt_channel_len + 1.0);
   const double alpha_tci = 2.0 / ((double)strategy_wt_average_len + 1.0);
   double esa = 0.0;
   double de = 0.0;
   double tci = 0.0;
   bool seeded = false;

   for(int s = start; s >= shift; --s)
     {
      const double ap = Strategy_TypicalPrice(s);
      if(ap <= 0.0)
         return 0.0;

      if(!seeded)
        {
         esa = ap;
         de = 0.0;
         tci = 0.0;
         seeded = true;
        }
      else
        {
         esa = esa + alpha_esa * (ap - esa);
         de = de + alpha_esa * (MathAbs(ap - esa) - de);
         const double ci = (de > 0.0) ? ((ap - esa) / (0.015 * de)) : 0.0;
         tci = tci + alpha_tci * (ci - tci);
        }
     }

   return tci;
  }

double Strategy_WaveTrendSignal(const int shift)
  {
   const int len = MathMax(1, strategy_wt_signal_len);
   double sum = 0.0;
   for(int i = 0; i < len; ++i)
      sum += Strategy_WaveTrend(shift + i);
   return sum / (double)len;
  }

int Strategy_SSLState(const int shift)
  {
   const int max_scan = MathMin(120, Bars(_Symbol, _Period) - shift - strategy_ssl_period - 2); // perf-allowed: bounded SSL state scan inside closed-bar entry path.
   for(int s = shift; s < shift + max_scan; ++s)
     {
      const double close_s = iClose(_Symbol, _Period, s); // perf-allowed: SSL state requires closed-bar close; no framework OHLC reader exists.
      const double ma_high = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ssl_period, s, PRICE_HIGH);
      const double ma_low = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ssl_period, s, PRICE_LOW);
      if(close_s <= 0.0 || ma_high <= 0.0 || ma_low <= 0.0)
         continue;
      if(close_s > ma_high)
         return 1;
      if(close_s < ma_low)
         return -1;
     }
   return 0;
  }

void Strategy_SSL(const int shift, double &green, double &red)
  {
   const double ma_high = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ssl_period, shift, PRICE_HIGH);
   const double ma_low = QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ssl_period, shift, PRICE_LOW);
   const int state = Strategy_SSLState(shift);
   if(state < 0)
     {
      green = ma_low;
      red = ma_high;
     }
   else
     {
      green = ma_high;
      red = ma_low;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
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

   if(strategy_ssl_period < 2 || strategy_baseline_ema < 2 ||
      strategy_wt_channel_len < 1 || strategy_wt_average_len < 1 ||
      strategy_wt_signal_len < 1 || strategy_keltner_ema < 1 ||
      strategy_keltner_atr_mult <= 0.0 || strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0 || strategy_rr <= 0.0 ||
      strategy_max_candle_atr <= 0.0 || strategy_ema_sr_period < 2)
      return false;

   double ssl_green_1 = 0.0;
   double ssl_red_1 = 0.0;
   double ssl_green_2 = 0.0;
   double ssl_red_2 = 0.0;
   Strategy_SSL(1, ssl_green_1, ssl_red_1);
   Strategy_SSL(2, ssl_green_2, ssl_red_2);
   if(ssl_green_1 <= 0.0 || ssl_red_1 <= 0.0 || ssl_green_2 <= 0.0 || ssl_red_2 <= 0.0)
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar candle check; no framework OHLC reader exists.
   const double high_1 = iHigh(_Symbol, _Period, 1);   // perf-allowed: single closed-bar candle check; no framework OHLC reader exists.
   const double low_1 = iLow(_Symbol, _Period, 1);     // perf-allowed: single closed-bar candle check; no framework OHLC reader exists.
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(close_1 <= 0.0 || high_1 <= 0.0 || low_1 <= 0.0 || atr <= 0.0)
      return false;

   if((high_1 - low_1) > atr * strategy_max_candle_atr)
      return false;

   const double kc_mid = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_keltner_ema, 1, PRICE_TYPICAL);
   const double kc_upper = kc_mid + atr * strategy_keltner_atr_mult;
   const double kc_lower = kc_mid - atr * strategy_keltner_atr_mult;
   if(kc_mid <= 0.0 || high_1 > kc_upper || low_1 < kc_lower)
      return false;

   const double base_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_baseline_ema, 1);
   const double base_2 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_baseline_ema, 2);
   if(base_1 <= 0.0 || base_2 <= 0.0)
      return false;

   const double wt_1 = Strategy_WaveTrend(1);
   const double wt_sig_1 = Strategy_WaveTrendSignal(1);
   const double wt_2 = Strategy_WaveTrend(2);
   const double wt_sig_2 = Strategy_WaveTrendSignal(2);

   const bool baseline_bull = (close_1 > base_1 && base_1 >= base_2);
   const bool baseline_bear = (close_1 < base_1 && base_1 <= base_2);
   const bool ssl_cross_up = (ssl_green_2 <= ssl_red_2 && ssl_green_1 > ssl_red_1);
   const bool ssl_cross_down = (ssl_red_2 <= ssl_green_2 && ssl_red_1 > ssl_green_1);
   const bool wt_cross_up = (wt_2 <= wt_sig_2 && wt_1 > wt_sig_1);
   const bool wt_cross_down = (wt_2 >= wt_sig_2 && wt_1 < wt_sig_1);

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const bool long_signal = (baseline_bull && ssl_cross_up && wt_cross_up);
   const bool short_signal = (baseline_bear && ssl_cross_down && wt_cross_down);
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = long_signal ? ask : bid;
   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_rr);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   const double ema_resistance = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_sr_period, 1, PRICE_HIGH);
   const double ema_support = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_sr_period, 1, PRICE_LOW);
   if(long_signal && ema_resistance > entry && ema_resistance <= tp)
      return false;
   if(short_signal && ema_support < entry && ema_support >= tp)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "SSL_WT_KC_LONG" : "SSL_WT_KC_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies ATR bracket exits only.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
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
