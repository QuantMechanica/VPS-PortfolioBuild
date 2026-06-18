#property strict
#property version   "5.0"
#property description "QM5_11257 cs-rsi-mtf — CryptoSignal Multi-Timeframe RSI Reversion (long-only, H1 entry / D1 state)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11257 cs-rsi-mtf
// -----------------------------------------------------------------------------
// Source: CryptoSignal/Crypto-Signal docs/config.md RSI example (Abenezer Mamo
// and contributors). Card: artifacts/cards_approved/QM5_11257_cs-rsi-mtf.md
// (g0_status APPROVED).
//
// Multi-timeframe RSI mean-reversion, long-only. Same-symbol aggregation: the
// higher TF (D1) is read off the same symbol — no basket, no foreign-symbol
// warmup required.
//
//   Higher-TF STATE  : D1 RSI(d1_period) < d1_hot   (oversold regime context).
//   Entry-TF EVENT   : H1 RSI(h1_period) crosses DOWN into oversold this bar
//                      (rsi@2 >= h1_hot AND rsi@1 < h1_hot).
//                      The D1 leg is a STATE, the H1 cross is the single EVENT —
//                      this avoids the two-fresh-crosses-same-bar zero-trade trap.
//   Exit             : H1 RSI(h1_period) > h1_cold  (reversion complete), OR
//                      force-close when D1 RSI(d1_period) > d1_cold, OR
//                      time-stop after time_stop_bars H1 bars.
//   Stop             : entry - sl_atr_mult * ATR(atr_period)  (hard stop).
//   Breakeven        : move SL to breakeven once price has advanced +1R.
//   Spread guard     : skip only when ATR < spread_atr_mult * spread; fail-OPEN
//                      on .DWX zero modeled spread (never block on zero spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11257;
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
// Higher timeframe (D1) RSI — oversold/overbought STATE.
input int    strategy_d1_rsi_period     = 21;     // D1 RSI period (CryptoSignal 1d RSI(21))
input double strategy_d1_hot            = 30.0;   // D1 oversold threshold (long context)
input double strategy_d1_cold           = 70.0;   // D1 overbought threshold (force-close)
// Entry timeframe (H1) RSI — cross-down-into-oversold EVENT / overbought exit.
input int    strategy_h1_rsi_period     = 50;     // H1 RSI period (CryptoSignal 1h RSI(50))
input double strategy_h1_hot            = 30.0;   // H1 oversold entry threshold
input double strategy_h1_cold           = 70.0;   // H1 overbought exit threshold
// Stops / management.
input int    strategy_atr_period        = 14;     // ATR period for the hard stop
input double strategy_sl_atr_mult       = 2.0;    // hard stop distance = mult * ATR
input int    strategy_time_stop_bars    = 10;     // close after N H1 bars if no RSI exit
input double strategy_spread_atr_mult   = 10.0;   // skip if ATR < this * spread (card: 10x)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-OPEN on .DWX zero spread.
// Card filter: "Skip if ATR(14) is below 10 times current spread."
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on a missing quote

   const double spread = ask - bid;
   // Zero / negative modeled spread (.DWX tester) MUST fail open — never block.
   if(spread <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   // Only a genuinely thin-vol / wide-spread bar blocks: ATR below 10x spread.
   if(atr_value < strategy_spread_atr_mult * spread)
      return true;

   return false;
  }

// Long-only entry. Caller guarantees QM_IsNewBar() == true on the entry TF (H1).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Higher-TF STATE: D1 RSI oversold (regime context, not an event) ---
   const double d1_rsi = QM_RSI(_Symbol, PERIOD_D1, strategy_d1_rsi_period, 1);
   if(d1_rsi <= 0.0)
      return false;
   if(!(d1_rsi < strategy_d1_hot))
      return false;

   // --- Entry-TF EVENT: H1 RSI crosses DOWN into oversold this closed bar ---
   // Single fresh event (prev>=hot, now<hot); D1 leg above is a state so the two
   // legs never need to coincide on a fresh cross — no zero-trade trap.
   const double h1_now  = QM_RSI(_Symbol, _Period, strategy_h1_rsi_period, 1);
   const double h1_prev = QM_RSI(_Symbol, _Period, strategy_h1_rsi_period, 2);
   if(h1_now <= 0.0 || h1_prev <= 0.0)
      return false;
   const bool crossed_into_oversold = (h1_prev >= strategy_h1_hot &&
                                       h1_now  <  strategy_h1_hot);
   if(!crossed_into_oversold)
      return false;

   // --- Build the long entry. Framework sizes lots (no lots field). ---
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0 || sl >= entry)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP — RSI / time-stop exits manage the close
   req.reason = "cs_rsi_mtf_long";
   return true;
  }

// Active management: move SL to breakeven once price has advanced +1R.
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl_price    = PositionGetDouble(POSITION_SL);
      if(entry_price <= 0.0 || sl_price <= 0.0 || sl_price >= entry_price)
         continue; // need a below-entry stop to define R for a long

      const double risk_dist = entry_price - sl_price;
      if(risk_dist <= 0.0)
         continue;

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid <= 0.0)
         continue;

      // +1R reached and stop still below entry -> move stop to breakeven.
      if(bid >= entry_price + risk_dist && sl_price < entry_price)
         QM_TM_MoveSL(ticket, entry_price, "breakeven_after_1R");
     }
  }

// Discretionary exit: H1 RSI overbought, OR D1 RSI overbought force-close,
// OR time-stop after strategy_time_stop_bars H1 bars.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // RSI reversion-complete exits.
   const double h1_rsi = QM_RSI(_Symbol, _Period, strategy_h1_rsi_period, 1);
   if(h1_rsi > 0.0 && h1_rsi > strategy_h1_cold)
      return true;

   const double d1_rsi = QM_RSI(_Symbol, PERIOD_D1, strategy_d1_rsi_period, 1);
   if(d1_rsi > 0.0 && d1_rsi > strategy_d1_cold)
      return true;

   // Time-stop: close after N H1 bars elapsed since the position opened.
   if(strategy_time_stop_bars > 0)
     {
      const int bar_seconds = PeriodSeconds(_Period);
      if(bar_seconds > 0)
        {
         for(int i = PositionsTotal() - 1; i >= 0; --i)
           {
            const ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket))
               continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != magic)
               continue;
            const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
            if(opened <= 0)
               continue;
            const long bars_held = (long)((TimeCurrent() - opened) / bar_seconds);
            if(bars_held >= strategy_time_stop_bars)
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
