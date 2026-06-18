#property strict
#property version   "5.0"
#property description "QM5_11433 ibr-mean-reversion-d1 — Internal Bar Range mean reversion (dual-sided, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11433 ibr-mean-reversion-d1
// -----------------------------------------------------------------------------
// Source: Joe Marwood (Decoding Markets), "Mean Reversion Trading Strategy Guide".
// Card: artifacts/cards_approved/QM5_11433_ibr-mean-reversion-d1.md (g0_status APPROVED).
//
// Mechanics (dual-sided, closed-bar reads at shift 1 = prior CLOSED daily bar):
//   IBR (Internal Bar Range) = (Close[1] - Low[1]) / (High[1] - Low[1]).
//     0.0 = closed at the low; 1.0 = closed at the high. Deterministic 0..1
//     position of the close within the prior bar's range. The IBR-extreme is
//     the single EVENT that triggers the entry. Gapless-safe: it references the
//     prior CLOSED bar's OWN OHLC, not a cross-bar gap.
//   Doji guard : skip when High[1] - Low[1] <= 0 (zero-range bar -> div by zero).
//   LONG       : IBR < ibr_long_threshold (weak close) AND Close[1] > SMA(regime).
//   SHORT      : IBR > ibr_short_threshold (strong close) AND Close[1] < SMA(regime).
//   Stop       : entry -/+ sl_atr_mult * ATR  (1.5 * ATR per card).
//   Take profit: entry +/- tp_atr_mult * ATR  (2.0 * ATR per card, same ATR value).
//   Spread guard: skip only a genuinely wide spread > spread_pct_of_stop of the
//                 stop distance (fail-OPEN on .DWX zero modeled spread).
//
// Single entry per magic; hold until SL or TP. Only the 5 Strategy_* hooks +
// Strategy inputs are EA-specific. All else is framework wiring (keep intact).
// .DWX INVARIANTS: gapless-safe (IBR uses prior bar's own range, not a gap),
// no swap gate, no external feed, fail-open spread.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11433;
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
input double strategy_ibr_long_threshold  = 0.20;   // LONG when IBR < this (weak close)
input double strategy_ibr_short_threshold = 0.80;   // SHORT when IBR > this (strong close)
input int    strategy_sma_period          = 200;    // regime filter SMA period (close)
input int    strategy_atr_period          = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult         = 1.5;    // stop distance  = mult * ATR
input double strategy_tp_atr_mult         = 2.0;    // target distance = mult * ATR
input double strategy_spread_pct_of_stop  = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — IBR/regime work is on the
// closed-bar path in Strategy_EntrySignal. Fail-OPEN on .DWX zero modeled spread.
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

// Dual-sided IBR entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic; hold until SL/TP.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Prior CLOSED bar OHLC (shift 1). Single closed-bar reads. ---
   const double high1  = iHigh(_Symbol,  _Period, 1); // perf-allowed: single closed-bar read
   const double low1   = iLow(_Symbol,   _Period, 1); // perf-allowed: single closed-bar read
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   // --- Doji / zero-range guard (avoid division by zero). ---
   const double bar_range = high1 - low1;
   if(bar_range <= 0.0)
      return false;

   // --- IBR: deterministic 0..1 position of the close within the bar range. ---
   const double ibr = (close1 - low1) / bar_range;

   // --- Regime filter: SMA(period) on closed bar. ---
   const double sma = QM_SMA(_Symbol, _Period, strategy_sma_period, 1, PRICE_CLOSE);
   if(sma <= 0.0)
      return false;

   // --- ATR for stop / target (same value used for both). ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   QM_OrderType side;
   string reason;
   if(ibr < strategy_ibr_long_threshold && close1 > sma)
     {
      // Weak close in a bullish regime -> expect upward mean reversion.
      side   = QM_BUY;
      reason = "ibr_meanrev_long";
     }
   else if(ibr > strategy_ibr_short_threshold && close1 < sma)
     {
      // Strong close in a bearish regime -> expect downward mean reversion.
      side   = QM_SELL;
      reason = "ibr_meanrev_short";
     }
   else
      return false;

   // --- Build the entry. Framework fills market price + sizes lots (no lots field). ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = reason;
   return true;
  }

// Exits handled by the fixed ATR stop/target only. No active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — position is held until SL or TP per the card.
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
