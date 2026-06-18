#property strict
#property version   "5.0"
#property description "QM5_11260 cs-stoch-mfi — Stochastic cross + MFI confirmation reversion (long-only, M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11260 cs-stoch-mfi
// -----------------------------------------------------------------------------
// Source: Abenezer Mamo / CryptoSignal contributors, Crypto-Signal StochRSI+MFI
//   config example (docs/config.md, StochRSI(14) hot:20/cold:80 + MFI(14)
//   hot:20/cold:80 on 5m candles).
// Card: artifacts/cards_approved/QM5_11260_cs-stoch-mfi.md (g0_status APPROVED).
//
// Mechanics (long-only, closed-bar reads at shift 1):
//   Confirming STATE : MFI(period) below the oversold floor (volume pressure).
//                      MFI uses .DWX tick volume (QM_MFI handles the port).
//   Trigger EVENT    : Stochastic %K crosses back UP through the oversold level
//                      (prev <= level at shift 2, now > level at shift 1).
//                      ONE event/bar — this is the entry trigger. MFI is a
//                      STATE checked on the same closed bar (not a second event),
//                      which avoids the two-cross-same-bar zero-trade trap.
//   Stop             : entry - sl_atr_mult * ATR(period).
//   Take profit      : RR multiple of the stop distance (QM_TakeRR).
//   Manage           : move to break-even after +be_trigger_R of the stop dist.
//   Discretionary exit: Stochastic %K rises above the overbought level OR
//                       MFI rises above the overbought level (reversal-to-strength
//                       exit, mirroring the source cold:80 logic) OR the time stop
//                       (max_hold_bars closed bars in the position) fires.
//   Spread guard     : skip only a genuinely wide spread > spread_pct_of_stop of
//                      the stop distance (fail-OPEN on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11260;
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
input int    strategy_stoch_k_period    = 14;     // Stochastic %K period (StochRSI-style oscillator port)
input int    strategy_stoch_d_period    = 3;      // Stochastic %D smoothing period
input int    strategy_stoch_slowing     = 3;      // Stochastic slowing
input double strategy_stoch_oversold    = 20.0;   // %K oversold floor (source hot:20)
input double strategy_stoch_overbought  = 80.0;   // %K overbought ceiling (source cold:80)
input int    strategy_mfi_period        = 14;     // MFI period on tick volume
input double strategy_mfi_oversold      = 30.0;   // MFI confirming oversold STATE (<30 per card P3 variant)
input double strategy_mfi_overbought    = 80.0;   // MFI overbought exit (source cold:80)
input int    strategy_atr_period        = 14;     // ATR period for stop / target sizing
input double strategy_sl_atr_mult       = 1.5;    // stop distance = mult * ATR
input double strategy_tp_rr             = 2.0;    // take-profit = tp_rr * stop distance
input double strategy_be_trigger_r      = 0.8;    // move to break-even after +R of the stop distance
input int    strategy_max_hold_bars     = 36;     // time stop: close after this many M5 bars
input double strategy_spread_pct_of_stop = 25.0;  // skip if spread > this % of stop distance (card: 0.25 ATR)

// -----------------------------------------------------------------------------
// File-scope state for the time stop. Counts closed bars while a position of
// this EA's magic is open; advanced ONCE per closed bar from Strategy_ExitSignal
// (which the framework calls on the per-tick path; the bar-roll is detected by a
// cached open-bar time so no per-EA new-bar reimplementation is introduced).
// -----------------------------------------------------------------------------
datetime g_entry_bar_time = 0;   // bar-open time of the bar on which we entered

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — oscillator work is in
// Strategy_EntrySignal on the closed-bar path. Fail-OPEN on .DWX zero spread.
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

   // --- Trigger EVENT: Stochastic %K crosses back UP through oversold ---
   // prev (shift 2) at/below the floor, now (shift 1) above it = one fresh event.
   const double k_now  = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                    strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                    strategy_stoch_d_period, strategy_stoch_slowing, 2);
   if(k_now <= 0.0 || k_prev <= 0.0)
      return false;
   const bool stoch_crossed_up = (k_prev <= strategy_stoch_oversold &&
                                  k_now  >  strategy_stoch_oversold);
   if(!stoch_crossed_up)
      return false;

   // --- Confirming STATE: MFI oversold on the same closed bar (NOT a 2nd event) ---
   const double mfi_now = QM_MFI(_Symbol, _Period, strategy_mfi_period, 1);
   if(mfi_now <= 0.0)
      return false;
   if(!(mfi_now < strategy_mfi_oversold))
      return false;

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
   req.reason = "cs_stoch_mfi_long";

   // Latch the entry bar-open time for the time-stop counter.
   g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: single current-bar time read
   return true;
  }

// Break-even shift after +be_trigger_R of the stop distance.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl_price   = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || sl_price <= 0.0)
         continue;

      const double stop_dist = open_price - sl_price; // long: positive
      if(stop_dist <= 0.0)
         continue;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         continue;

      // Once price has run be_trigger_R of the stop distance in our favour and
      // the stop is still below entry, lift it to break-even.
      if(bid - open_price >= strategy_be_trigger_r * stop_dist && sl_price < open_price)
         QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, open_price), "cs_stoch_mfi_breakeven");
     }
  }

// Discretionary exit: oscillator reached overbought (StochRSI > 80 OR MFI > 80,
// per source cold:80), OR the time stop (max_hold_bars closed bars) fired.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
     {
      g_entry_bar_time = 0; // no position — reset the time-stop latch
      return false;
     }

   // --- Reversal-to-strength exit (mirrors source cold:80 on either oscillator) ---
   const double k_now = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                   strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double mfi_now = QM_MFI(_Symbol, _Period, strategy_mfi_period, 1);
   if(k_now > strategy_stoch_overbought || (mfi_now > 0.0 && mfi_now > strategy_mfi_overbought))
      return true;

   // --- Time stop: close after max_hold_bars closed M5 bars in the position ---
   if(g_entry_bar_time > 0 && strategy_max_hold_bars > 0)
     {
      const datetime cur_bar = iTime(_Symbol, _Period, 0); // perf-allowed: single current-bar time read
      if(cur_bar > 0)
        {
         const int tf_secs = PeriodSeconds(_Period);
         if(tf_secs > 0)
           {
            const long elapsed_bars = (long)((cur_bar - g_entry_bar_time) / tf_secs);
            if(elapsed_bars >= (long)strategy_max_hold_bars)
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
