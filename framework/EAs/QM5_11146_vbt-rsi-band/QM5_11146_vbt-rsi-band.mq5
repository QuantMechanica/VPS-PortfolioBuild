#property strict
#property version   "5.0"
#property description "QM5_11146 vbt-rsi-band — RSI Band Mean Reversion (long-only, M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11146 vbt-rsi-band
// -----------------------------------------------------------------------------
// Source: Oleg Polakow / vectorbt, examples/PortingBTStrategy.ipynb
//   (GitHub polakowo/vectorbt). RSI band mean reversion: buy oversold, sell
//   (exit) overbought. Ported from 1m BTC/USDT to M15 .DWX CFDs.
// Card: artifacts/cards_approved/QM5_11146_vbt-rsi-band.md (g0_status APPROVED).
//
// Mechanics (long-only, closed-bar reads at shift 1; RSI on PRICE_OPEN to match
// the pure-vectorbt section of the source notebook):
//   Entry EVENT  : RSI(period) crosses BELOW RsiBottom (=35). One fresh cross:
//                  rsi@2 >= bottom AND rsi@1 < bottom. Enter long at next open.
//   Safety stop  : entry - 1.5 * ATR(14), frozen at entry (no take-profit; the
//                  RSI/time exits drive the trade lifecycle per the source).
//   Exit EVENT   : RSI(period) crosses ABOVE RsiTop (=70):
//                  rsi@2 <= top AND rsi@1 > top.
//   Time stop    : close after MaxHoldBars (=96) M15 bars held.
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of the
//                  stop distance (fail-open on .DWX zero modeled spread).
//
// Long-only by design — the source RSI band strategy is buy-oversold /
// sell-to-flat, NOT symmetric shorting. One position per symbol/magic.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11146;
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
input int    strategy_rsi_period         = 14;    // RSI lookback period
input double strategy_rsi_bottom         = 35.0;  // oversold entry threshold (cross below)
input double strategy_rsi_top            = 70.0;  // overbought exit threshold (cross above)
input int    strategy_atr_period         = 14;    // ATR period for the safety stop
input double strategy_sl_atr_mult        = 1.5;   // safety stop distance = mult * ATR
input int    strategy_max_hold_bars      = 96;    // time stop: max bars held before forced close
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the closed-bar
// path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
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

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Entry EVENT: RSI crosses BELOW the bottom threshold (one fresh cross) ---
   // RSI computed on PRICE_OPEN to match the pure-vectorbt section of the source.
   const double rsi_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1, PRICE_OPEN);
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2, PRICE_OPEN);
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;
   const bool crossed_below = (rsi_prev >= strategy_rsi_bottom &&
                               rsi_now  <  strategy_rsi_bottom);
   if(!crossed_below)
      return false;

   // --- Safety stop: 1.5 * ATR(14), frozen at entry. No take-profit. ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no TP — RSI exit + time stop + safety SL drive the close
   req.reason = "vbt_rsi_band_long";
   return true;
  }

// No active trade management beyond the fixed ATR safety stop. RSI-band and
// time-stop exits live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit when RSI crosses above the top threshold OR the time stop is reached.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // --- Exit EVENT: RSI crosses ABOVE the top threshold (one fresh cross) ---
   const double rsi_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1, PRICE_OPEN);
   const double rsi_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2, PRICE_OPEN);
   if(rsi_now > 0.0 && rsi_prev > 0.0)
     {
      const bool crossed_above = (rsi_prev <= strategy_rsi_top &&
                                  rsi_now  >  strategy_rsi_top);
      if(crossed_above)
         return true;
     }

   // --- Time stop: forced close after strategy_max_hold_bars closed bars held ---
   if(strategy_max_hold_bars > 0)
     {
      const int period_secs = PeriodSeconds(_Period);
      if(period_secs > 0)
        {
         const datetime cur_bar_time = iTime(_Symbol, _Period, 0); // current bar open time
         for(int i = PositionsTotal() - 1; i >= 0; --i)
           {
            const ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket))
               continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != magic)
               continue;
            const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
            const int bars_held = (int)((cur_bar_time - open_time) / period_secs);
            if(bars_held >= strategy_max_hold_bars)
               return true;
           }
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
