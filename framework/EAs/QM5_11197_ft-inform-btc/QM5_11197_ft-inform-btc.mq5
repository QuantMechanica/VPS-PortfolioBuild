#property strict
#property version   "5.0"
#property description "QM5_11197 ft-inform-btc — M5 EMA trend (Freqtrade InformativeSample base; BTC-informative leg DROPPED, non-portable)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11197 ft-inform-btc
// -----------------------------------------------------------------------------
// Source: xmatthias, "InformativeSample.py", freqtrade-strategies (GitHub).
//   user_data/strategies/InformativeSample.py @ dbd5b0b21cfbf...
// Card: artifacts/cards_approved/QM5_11197_ft-inform-btc.md (g0_status APPROVED).
//
// PORTABILITY NOTE — BTC INFORMATIVE LEG DROPPED (un-portable):
//   The source layers an OPTIONAL cross-market regime filter on top of a fully
//   self-contained base entry. The base entry is the traded-symbol EMA-trend
//   (source M5 EMA20>EMA50). The optional leg reads BTC/USDT 15m close vs SMA20.
//   There is NO crypto/BTC symbol in framework/registry/dwx_symbol_matrix.csv,
//   so the Freqtrade "informative BTC pair" feed is NOT available in the .DWX
//   tester. The card's suggested "NDX.DWX H15 as a BTC risk proxy" is a
//   fabricated cross-asset substitute — an index is NOT bitcoin and would
//   inject an invented, unfaithful signal. Per the .DWX BACKTEST INVARIANTS
//   ("no external-macro feed", "never fabricate a feed") we DROP the informative
//   leg rather than fake it. The branch is gated behind `informative_filter_on`
//   which DEFAULTS TO FALSE. If a real, matrix-listed BTC feed is ever added,
//   wire QM_BasketWarmupHistory + the informative SMA read into the gated block.
//
// Mechanics (closed-bar reads at shift 1; base strategy only):
//   Regime / Entry EVENT : EMA(fast) crosses ABOVE EMA(slow) on the traded
//                          symbol (one fresh upward cross per bar = the trigger).
//   Defensive exit EVENT : EMA(fast) crosses BELOW EMA(slow) -> close manually
//                          (mirror of the source signal exit).
//   Stop   : entry - sl_atr_mult * ATR(atr_period)   (card MT5 baseline 14, 2.0).
//   Take   : entry + tp_rr * stop_distance           (bounded RR take; the
//            source ROI ladder is a Freqtrade time-decay construct with no
//            MT5 idiom — an RR-multiple take is the faithful bounded-risk MT5
//            mechanization, with the EMA-cross as the primary exit).
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// One position per symbol/magic. RISK_FIXED in tester, RISK_PERCENT live.
// No ML, no martingale, no grid. Only the 5 Strategy_* hooks + Strategy inputs
// are EA-specific; everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11197;
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
input int    strategy_ema_fast_period   = 20;     // traded-symbol fast EMA (source EMA20)
input int    strategy_ema_slow_period   = 50;     // traded-symbol slow EMA (source EMA50)
input int    strategy_atr_period        = 14;     // ATR period (stop / take)
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR (card baseline)
input double strategy_tp_rr             = 2.0;    // take distance = tp_rr * stop distance
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance
// BTC informative leg — DROPPED as un-portable. Default OFF; do NOT enable
// unless a real, matrix-listed BTC feed exists. See portability note above.
input bool   informative_filter_on      = false;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long-only entry on a fresh EMA(fast)>EMA(slow) upward cross of the traded
// symbol. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trigger EVENT: EMA(fast) crosses up through EMA(slow) (closed bars) ---
   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   const bool crossed_up = (fast_prev <= slow_prev && fast_now > slow_now);
   if(!crossed_up)
      return false;

   // --- OPTIONAL informative-BTC regime filter — DROPPED as un-portable. ---
   // Gated OFF by default. There is no .DWX BTC feed; we refuse to fabricate
   // one (an index proxy would be an invented, unfaithful signal). If a real
   // BTC feed is ever matrix-listed, read its H15 close vs SMA20 here.
   if(informative_filter_on)
      return false; // self-disable: no faithful BTC series available.

   // --- Build the long entry. Framework sizes lots (no lots field). ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "ft_inform_btc_ema_cross_long";
   return true;
  }

// No active trade management beyond the fixed ATR stop / RR take. The defensive
// EMA-cross exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit (mirror of source signal exit): EMA(fast) crosses BELOW
// EMA(slow). One event at shift 1.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   const bool crossed_down = (fast_prev >= slow_prev && fast_now < slow_now);
   return crossed_down;
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
