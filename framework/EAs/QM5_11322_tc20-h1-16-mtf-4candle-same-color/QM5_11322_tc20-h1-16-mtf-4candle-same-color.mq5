#property strict
#property version   "5.0"
#property description "QM5_11322 tc20-h1-16-mtf-4candle-same-color — Multi-TF 4-candle same-direction momentum stop-entry (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11322 tc20-h1-16-mtf-4candle-same-color
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         Strategy #16 (2014). Card:
//         artifacts/cards_approved/QM5_11322_tc20-h1-16-mtf-4candle-same-color.md
//         (g0_status APPROVED).
//
// Mechanics (no indicators — pure same-symbol multi-timeframe candle direction):
//   EVENT  : a new H1 bar opens (i.e. the prior H1 bar just CLOSED). This is the
//            single trigger; all four reads below are STATES on closed bars.
//   STATE  : the last CLOSED candle on M5, M15, M30 and H1 all share the same
//            direction (Close > Open = bullish, Close < Open = bearish). All
//            four bullish -> long setup; all four bearish -> short setup.
//            Direction is taken as Close-vs-Open on each closed bar (gapless-safe
//            on .DWX CFDs: open[0]==close[1], so no prior-RANGE / gap dependency).
//   ENTRY  : place a STOP pending order `entry_offset_pips` beyond the H1 close
//            (BuyStop above for longs, SellStop below for shorts). The pending
//            order auto-expires after `entry_expiry_minutes` (broker GTC->SPECIFIED
//            via req.expiration_seconds) if price never reaches the trigger.
//   STOP   : `sl_pips` fixed (pip-scaled for 3/5-digit + JPY symbols).
//   TARGET : `tp_pips` fixed (mid of the card's 30-40 pip range).
//   ONE-AT-A-TIME : skip if this magic already has an open position OR a live
//            pending order (keeps one position per magic).
//   Spread guard : fail-OPEN on .DWX zero modeled spread; only a genuinely wide
//            spread (> spread_cap_pips) blocks (entry edge is tight, only a few
//            pips beyond the close).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11322;
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
// Multi-timeframe candle-direction alignment. The four reads are STATES on the
// last closed bar of each timeframe; the H1 close (new H1 bar) is the EVENT.
input int    strategy_entry_offset_pips = 3;     // stop-entry offset beyond the H1 close
input int    strategy_sl_pips           = 20;    // fixed stop-loss, in pips
input int    strategy_tp_pips           = 35;    // fixed take-profit, in pips (mid of 30-40)
input int    strategy_expiry_minutes    = 15;    // pending-order expiry if not triggered
input double strategy_spread_cap_pips   = 10.0;  // block only a genuinely wide spread

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

// Direction of the last CLOSED candle on a same-symbol timeframe.
//   +1 bullish (Close>Open), -1 bearish (Close<Open), 0 doji / no data.
// perf-allowed: bespoke MTF candle-direction read; no QM indicator helper
// exists for "candle colour across timeframes". Single closed-bar (shift 1)
// reads, gated by QM_IsNewBar on the per-closed-bar path.
int LastClosedCandleDir(const ENUM_TIMEFRAMES tf)
  {
   const double o = iOpen(_Symbol, tf, 1);   // perf-allowed: single closed-bar read
   const double c = iClose(_Symbol, tf, 1);  // perf-allowed: single closed-bar read
   if(o <= 0.0 || c <= 0.0)
      return 0;
   if(c > o)
      return 1;
   if(c < o)
      return -1;
   return 0;
  }

// Count this magic's live pending orders for the current symbol.
// Order-management API (not strategy indicator math) — keeps one-at-a-time.
int OpenPendingCount(const int magic)
  {
   int count = 0;
   const int total = OrdersTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      count++;
     }
   return count;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// only a genuinely wide spread (in pips) blocks. The 4-candle alignment work is
// on the closed-bar path in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on a missing/zero price

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // zero modeled spread on .DWX — fail OPEN

   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_spread_cap_pips));
   if(cap_distance <= 0.0)
      return false; // cannot size the cap — do not block

   if(spread > cap_distance)
      return true;  // genuinely wide spread — block

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar(_Symbol, PERIOD_CURRENT) == true, i.e. a
// fresh H1 bar just opened (the prior H1 bar CLOSED). Places a STOP pending
// order beyond the H1 close when all four timeframes' last closed candles share
// one direction.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One position (and one pending order) at a time per magic/symbol.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(OpenPendingCount(magic) > 0)
      return false;

   // --- STATE: last closed candle direction on M5, M15, M30, H1 ---
   const int dir_m5  = LastClosedCandleDir(PERIOD_M5);
   const int dir_m15 = LastClosedCandleDir(PERIOD_M15);
   const int dir_m30 = LastClosedCandleDir(PERIOD_M30);
   const int dir_h1  = LastClosedCandleDir(PERIOD_H1);

   // Any doji / missing data on any timeframe -> no aligned setup.
   if(dir_m5 == 0 || dir_m15 == 0 || dir_m30 == 0 || dir_h1 == 0)
      return false;

   // All four must agree on a single direction.
   if(!(dir_m5 == dir_m15 && dir_m15 == dir_m30 && dir_m30 == dir_h1))
      return false;

   const bool is_long = (dir_h1 > 0);

   // --- ENTRY: stop pending order beyond the H1 close ---
   const double h1_close = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed: single closed-bar read
   if(h1_close <= 0.0)
      return false;

   const double offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_entry_offset_pips);
   if(offset <= 0.0)
      return false;

   const double entry = is_long ? (h1_close + offset) : (h1_close - offset);
   const QM_OrderType side = is_long ? QM_BUY_STOP : QM_SELL_STOP;

   // SL/TP are fixed pips measured from the stop-trigger entry price. Use the
   // directional position side (QM_BUY / QM_SELL) for the geometry.
   const QM_OrderType pos_side = is_long ? QM_BUY : QM_SELL;
   const double sl = QM_StopFixedPips(_Symbol, pos_side, entry, strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, pos_side, entry, strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type               = side;
   req.price              = QM_StopRulesNormalizePrice(_Symbol, entry);
   req.sl                 = sl;
   req.tp                 = tp;
   req.reason             = is_long ? "mtf_4candle_long_stop" : "mtf_4candle_short_stop";
   req.expiration_seconds = strategy_expiry_minutes * 60;
   return true;
  }

// Fixed SL/TP only; the broker auto-expires the untriggered pending order. No
// active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the fixed SL/TP.
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
