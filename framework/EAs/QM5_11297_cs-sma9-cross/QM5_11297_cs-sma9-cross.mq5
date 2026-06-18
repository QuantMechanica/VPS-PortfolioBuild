#property strict
#property version   "5.0"
#property description "QM5_11297 cs-sma9-cross — Close/SMA(9) reverse-cross (H1, long+short)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11297 cs-sma9-cross
// -----------------------------------------------------------------------------
// Source: CryptoSignal/Crypto-Signal — docs/config.md SMA example + crossover
//         analyzer. Card: artifacts/cards_approved/QM5_11297_cs-sma9-cross.md
//         (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1, prior at shift 2):
//   The SMA(9) cross is the single EVENT. Any filter would be a STATE; this
//   card has no extra filter, so the cross alone triggers.
//
//   Entry LONG  EVENT : close crosses ABOVE SMA(9)  (close[2]<=SMA[2] & close[1]>SMA[1]).
//   Entry SHORT EVENT : close crosses BELOW SMA(9)  (close[2]>=SMA[2] & close[1]<SMA[1]).
//   Exit  LONG        : close crosses BELOW SMA(9)  (the opposite reverse-cross).
//   Exit  SHORT       : close crosses ABOVE SMA(9).
//   Stop  (catastrophic): entry -/+ sl_atr_mult * ATR(atr_period). Source is
//                         alert-only; V5 adds a default 2.0*ATR(14) stop.
//   No take-profit: signal-driven (reverse-cross) exit only, plus the
//                   catastrophic ATR stop. Reverse only after flat: one
//                   position per magic + exit-on-opposite-cross means the
//                   reverse entry can only fire on a later completed bar.
//   Spread guard : skip only a genuinely wide spread (fail-OPEN on .DWX zero
//                  modeled spread).
//
// Two-cross-same-bar trap avoided: a single bar's close is either above OR
// below SMA(9), so the up-cross (entry-long / exit-short) and the down-cross
// (entry-short / exit-long) are mutually exclusive on any given bar.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11297;
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
input int    strategy_sma_period         = 9;     // SMA period (CryptoSignal 9-period example)
input int    strategy_atr_period         = 14;    // ATR period for the catastrophic stop
input double strategy_sl_atr_mult        = 2.0;   // catastrophic stop = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// +1 = close crossed ABOVE SMA on the last closed bar, -1 = crossed BELOW,
// 0 = no fresh cross. Uses closed bars: shift 1 (now) vs shift 2 (prior).
int Sma9_CrossDirection()
  {
   const double sma_now  = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double sma_prev = QM_SMA(_Symbol, _Period, strategy_sma_period, 2);
   if(sma_now <= 0.0 || sma_prev <= 0.0)
      return 0;

   const double close_now  = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close_prev = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close_now <= 0.0 || close_prev <= 0.0)
      return 0;

   if(close_prev <= sma_prev && close_now > sma_now)
      return +1;
   if(close_prev >= sma_prev && close_now < sma_now)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-OPEN on .DWX zero spread.
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

// Entry on the SMA(9) reverse-cross EVENT. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic; reverse only after flat.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int dir = Sma9_CrossDirection();
   if(dir == 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(dir > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no take-profit; reverse-cross / catastrophic stop only
      req.reason = "sma9_cross_long";
      return true;
     }

   // dir < 0 — short.
   const double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      return false;
   const double sl_s = QM_StopATRFromValue(_Symbol, QM_SELL, entry_s, atr_value, strategy_sl_atr_mult);
   if(sl_s <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl_s;
   req.tp     = 0.0;
   req.reason = "sma9_cross_short";
   return true;
  }

// No active trade management beyond the catastrophic ATR stop. Exits are
// signal-driven in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Signal exit: opposite reverse-cross. Close a long on a down-cross, close a
// short on an up-cross. One event per bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int dir = Sma9_CrossDirection();
   if(dir == 0)
      return false;

   // Determine the held direction from the open position.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && dir < 0)
         return true;  // long held, close crossed below SMA
      if(ptype == POSITION_TYPE_SELL && dir > 0)
         return true;  // short held, close crossed above SMA
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
