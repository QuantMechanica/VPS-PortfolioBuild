#property strict
#property version   "5.0"
#property description "QM5_11130 tm-vix-stretch — VIX-Stretch Index Reversion (long-only, D1, self-contained vol proxy)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11130 tm-vix-stretch
// -----------------------------------------------------------------------------
// Source: David Penn, "Trading the VIX: Short Term Strategies for High
//   Probability Traders", TradingMarkets, 2010-01-04 (Larry Connors research).
// Card: artifacts/cards_approved/QM5_11130_tm-vix-stretch.md (g0_status APPROVED).
//
// VIX is NOT a .DWX-available symbol and external macro feeds are BANNED. The
// card's R3 PASS defines a self-contained DWX port: replace the VIX level with a
// realized-volatility proxy computed from the TRADED INDEX's OWN closed bars:
//
//     volproxy[s] = ATR(vp_atr_period) / SMA(close, vp_sma_period)   at shift s
//
// This is a price-normalised realized-vol measure that behaves like a VIX-style
// "fear" gauge on the index itself — entirely deterministic, no external feed.
//
// Mechanics (long-only, D1, closed-bar reads at shift >= 1):
//   Stretch STATE (per bar s): volproxy[s] >= (1 + stretch_pct/100) * MA10(volproxy)
//        where MA10(volproxy) = mean of volproxy[s+1 .. s+vp_ma_period].
//        Mirrors "VIX closes >=5% above its 10-day MA".
//   Entry TRIGGER: the stretch STATE is true for `stretch_days` CONSECUTIVE
//        closed bars (shifts 1 .. stretch_days). Enter long market on the new
//        bar after the qualifying run (framework next-bar market entry).
//   Exit (RSI):  close when RSI(rsi_period=2) of the last closed bar > rsi_exit.
//   Exit (time): close after `max_hold_bars` D1 bars if RSI exit has not fired.
//   Stop loss :  entry - sl_atr_mult * ATR(sl_atr_period); RISK_FIXED sizes lots.
//   No hard TP  (source specifies none); exits are RSI or time only.
//   Spread guard: skip only a genuinely WIDE spread (> spread_pct_of_stop of the
//        stop distance). Fail-OPEN on .DWX zero modeled spread.
//
// .DWX PROXY FLAG: "VIX" here is the index's own ATR/SMA realized-vol proxy, not
// the actual CBOE VIX. The proxy edge may differ from the SPY+VIX source edge —
// this is a faithful DWX porting experiment per the card's R3 note.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11130;
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
input int    vp_atr_period              = 10;    // ATR period for the vol proxy numerator
input int    vp_sma_period              = 10;    // SMA(close) period for the vol proxy denominator
input int    vp_ma_period               = 10;    // lookback for the proxy's own moving average
input double stretch_pct                = 5.0;   // proxy must close >= this % above its own MA
input int    stretch_days               = 3;     // consecutive qualifying stretch bars required
input int    rsi_period                 = 2;     // short-term RSI for the exit
input double rsi_exit                   = 65.0;  // exit when RSI(rsi_period) closes above this
input int    max_hold_bars              = 7;     // time exit after this many D1 bars
input int    sl_atr_period              = 14;    // ATR period for the protective stop
input double sl_atr_mult                = 2.5;   // stop distance = mult * ATR
input double spread_pct_of_stop         = 15.0;  // skip if spread > this % of the stop distance

// -----------------------------------------------------------------------------
// Self-contained realized-volatility proxy ("VIX" replacement).
// volproxy at a given closed-bar shift = ATR(vp_atr_period, shift) normalised by
// SMA(close, vp_sma_period, shift). Returns 0.0 if either component is unavailable.
// -----------------------------------------------------------------------------
double VolProxyAt(const int shift)
  {
   const double atr_v = QM_ATR(_Symbol, _Period, vp_atr_period, shift);
   if(atr_v <= 0.0)
      return 0.0;
   const double sma_c = QM_SMA(_Symbol, _Period, vp_sma_period, shift, PRICE_CLOSE);
   if(sma_c <= 0.0)
      return 0.0;
   return atr_v / sma_c;
  }

// Mean of volproxy over shifts [base_shift+1 .. base_shift+vp_ma_period]
// (the proxy's own "10-day MA"). Returns 0.0 if any sample is unavailable.
double VolProxyMA(const int base_shift)
  {
   double sum = 0.0;
   for(int k = 1; k <= vp_ma_period; ++k)
     {
      const double v = VolProxyAt(base_shift + k);
      if(v <= 0.0)
         return 0.0;
      sum += v;
     }
   return sum / (double)vp_ma_period;
  }

// True if the proxy is "stretched" (>= threshold above its own MA) at `shift`.
bool IsStretchedAt(const int shift)
  {
   const double vp = VolProxyAt(shift);
   if(vp <= 0.0)
      return false;
   const double ma = VolProxyMA(shift);
   if(ma <= 0.0)
      return false;
   return (vp >= (1.0 + stretch_pct / 100.0) * ma);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — all signal work is on the
// closed-bar path. Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, sl_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Entry TRIGGER: stretch STATE true for `stretch_days` consecutive bars,
   //     shifts 1 .. stretch_days (most recent closed bars before this entry). ---
   if(stretch_days < 1)
      return false;
   for(int s = 1; s <= stretch_days; ++s)
     {
      if(!IsStretchedAt(s))
         return false;
     }

   // --- Build the long entry. Framework sizes lots (no lots field). ---
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, sl_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no hard TP — exit is RSI(2)>65 or time stop
   req.reason = "vix_stretch_long";
   return true;
  }

// RSI(rsi_period) exit and time exit handled here so each closes with its own
// reason. Runs every tick; reads cached/handle-pooled values only (O(1)).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   // --- RSI exit: last closed bar's RSI(rsi_period) above the exit level. ---
   const double rsi_now = QM_RSI(_Symbol, _Period, rsi_period, 1, PRICE_CLOSE);
   const bool rsi_exit_fire = (rsi_now > 0.0 && rsi_now > rsi_exit);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(rsi_exit_fire)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }

      // --- Time exit: bars held since entry >= max_hold_bars. The shift of the
      //     bar on which the position opened equals the number of closed bars
      //     elapsed since entry (D1). This is trade-management bookkeeping, not
      //     a signal-cadence new-bar reimplementation. ---
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int held_bars = iBarShift(_Symbol, _Period, open_time, false);
      if(held_bars >= max_hold_bars)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

// Exits are handled in Strategy_ManageOpenPosition with explicit reasons.
bool Strategy_ExitSignal()
  {
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
