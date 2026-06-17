#property strict
#property version   "5.0"
#property description "QM5_11089 trade-asst-conf — EarnForex Trade Assistant 4-indicator confluence (Stoch+RSI+CCI x2, H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11089 trade-asst-conf
// -----------------------------------------------------------------------------
// Source: EarnForex "Trade Assistant" (GitHub + MQL5). Card:
//   artifacts/cards_approved/QM5_11089_trade-asst-conf.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1 vs prior at shift 2; H4):
//   The card asks for a 4-component ALL-AGREE confluence:
//     1. Stochastic main(%K) vs signal(%D)          — STATE
//     2. RSI(fast, typical) vs RSI(slow, typical)    — STATE
//     3. Entry CCI > 0 (long) / < 0 (short) AND rising/falling vs prior bar
//     4. Trend  CCI > 0 (long) / < 0 (short) AND rising/falling vs prior bar
//
//   To avoid the ".DWX two-cross-same-bar zero-trade trap", ONE component is the
//   directional TRIGGER EVENT and the others are STATES. Entry-CCI direction
//   (rising/falling vs prior closed bar) is the trigger; Stoch, RSI-pair,
//   Trend-CCI sign and Trend-CCI direction are co-confirming STATES read on the
//   same closed bar. All four must agree on the same side to open.
//
//   Exit: any component flips to the opposite side -> close. Plus a deterministic
//   12-bar (H4) time stop as the card's V5 conversion default.
//   Stop : ATR(period) catastrophic stop at sl_atr_mult (card P2 default 2.0).
//   TP   : ATR-multiple target (RR-style via ATR) so the catastrophic stop is
//          not the only exit path; opposite-flip / time-stop are the primary exits.
//   Spread guard: skip only a genuinely wide spread (fail-open on .DWX 0 spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11089;
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
// Stochastic (EarnForex defaults: %K=8, %D=3, Slowing=3).
input int    strategy_stoch_k_period    = 8;      // Stochastic %K period
input int    strategy_stoch_d_period    = 3;      // Stochastic %D (signal) period
input int    strategy_stoch_slowing     = 3;      // Stochastic slowing
// RSI pair on typical price (EarnForex defaults: 14 and 70).
input int    strategy_rsi_fast_period   = 14;     // fast RSI period
input int    strategy_rsi_slow_period   = 70;     // slow RSI period
// CCI pair: Entry CCI (faster) is the directional trigger; Trend CCI (slower)
// is a regime-confirming state. EarnForex uses TF-specific arrays; H4 defaults.
input int    strategy_cci_entry_period  = 14;     // Entry CCI period (trigger)
input int    strategy_cci_trend_period  = 50;     // Trend CCI period (state)
// ATR catastrophic stop / target (card P2 baseline: 2.0 ATR, sweep 1.5-3.0).
input int    strategy_atr_period        = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR
input double strategy_tp_atr_mult       = 4.0;    // target distance = mult * ATR
// Deterministic time stop in bars (card default: 12 H4 bars).
input int    strategy_time_stop_bars    = 12;     // close after N closed bars
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// File-scope: bar-open time of the bar on which the current position was opened.
// Used by the deterministic time-stop. Reset to 0 when flat.
datetime g_entry_bar_time = 0;

// -----------------------------------------------------------------------------
// Confluence direction on the LAST CLOSED bar.
// Returns +1 = full long confluence, -1 = full short confluence, 0 = none.
// Entry-CCI direction is the trigger; the others are co-confirming states.
// -----------------------------------------------------------------------------
int Strategy_Confluence()
  {
   // --- Stochastic main vs signal (closed bar) ---
   const double stoch_k = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                     strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double stoch_d = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period,
                                     strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(stoch_k <= 0.0 || stoch_d <= 0.0)
      return 0;

   // --- RSI pair on typical price ---
   const double rsi_fast = QM_RSI(_Symbol, _Period, strategy_rsi_fast_period, 1, PRICE_TYPICAL);
   const double rsi_slow = QM_RSI(_Symbol, _Period, strategy_rsi_slow_period, 1, PRICE_TYPICAL);
   if(rsi_fast <= 0.0 || rsi_slow <= 0.0)
      return 0;

   // --- Entry CCI now + prior (trigger via rising/falling) ---
   const double cci_e_now  = QM_CCI(_Symbol, _Period, strategy_cci_entry_period, 1, PRICE_TYPICAL);
   const double cci_e_prev = QM_CCI(_Symbol, _Period, strategy_cci_entry_period, 2, PRICE_TYPICAL);

   // --- Trend CCI now + prior (state via sign + rising/falling) ---
   const double cci_t_now  = QM_CCI(_Symbol, _Period, strategy_cci_trend_period, 1, PRICE_TYPICAL);
   const double cci_t_prev = QM_CCI(_Symbol, _Period, strategy_cci_trend_period, 2, PRICE_TYPICAL);

   // --- Long confluence: all four agree bullish ---
   const bool long_ok =
        (stoch_k > stoch_d) &&
        (rsi_fast > rsi_slow) &&
        (cci_e_now > 0.0 && cci_e_now > cci_e_prev) &&
        (cci_t_now > 0.0 && cci_t_now > cci_t_prev);
   if(long_ok)
      return +1;

   // --- Short confluence: all four agree bearish ---
   const bool short_ok =
        (stoch_k < stoch_d) &&
        (rsi_fast < rsi_slow) &&
        (cci_e_now < 0.0 && cci_e_now < cci_e_prev) &&
        (cci_t_now < 0.0 && cci_t_now < cci_t_prev);
   if(short_ok)
      return -1;

   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — confluence work runs on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
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

   const int dir = Strategy_Confluence();
   if(dir == 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const QM_OrderType otype = (dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, otype, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, otype, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir > 0) ? "trade_asst_conf_long" : "trade_asst_conf_short";

   // Stamp the entry bar for the deterministic time stop.
   g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: single bar-open read
   return true;
  }

// No active trade management beyond the fixed ATR stop/target. Opposite-flip and
// time-stop exits live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: opposite full confluence flips against the open side, OR the deterministic
// N-bar time stop elapses.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      g_entry_bar_time = 0;
      return false;
     }

   // Determine the open side from the live position.
   int pos_dir = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? +1 : -1;
      break;
     }
   if(pos_dir == 0)
      return false;

   // --- Opposite full confluence appears -> close. ---
   const int conf = Strategy_Confluence();
   if(conf != 0 && conf != pos_dir)
      return true;

   // --- Deterministic time stop: N closed bars since entry. ---
   if(g_entry_bar_time > 0 && strategy_time_stop_bars > 0)
     {
      const datetime cur_bar = iTime(_Symbol, _Period, 0); // perf-allowed: single bar-open read
      const int tf_secs = PeriodSeconds(_Period);
      if(tf_secs > 0)
        {
         const long elapsed_bars = (long)((cur_bar - g_entry_bar_time) / tf_secs);
         if(elapsed_bars >= (long)strategy_time_stop_bars)
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
      g_entry_bar_time = 0;
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
