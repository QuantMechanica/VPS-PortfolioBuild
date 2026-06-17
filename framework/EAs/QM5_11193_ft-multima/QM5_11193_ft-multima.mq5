#property strict
#property version   "5.0"
#property description "QM5_11193 ft-multima — Freqtrade MultiMa TEMA stack (long-only, H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11193 ft-multima
// -----------------------------------------------------------------------------
// Source: Masoud Azizi (@mablue), MultiMa.py, freqtrade-strategies (GitHub).
// Card: artifacts/cards_approved/QM5_11193_ft-multima.md (g0_status APPROVED).
//
// Mechanics (long-only, closed-bar reads at shift 1; H4):
//   The source builds a stack of TEMA(count*gap) lines for count=1..buy_ma_count
//   and goes long when each SHORTER TEMA sits above the next LONGER TEMA, i.e.
//   the source condition TEMA(longer) < TEMA(shorter) holds across the whole
//   stack — a bullish moving-average alignment STATE.
//   Default buy params: buy_ma_count=4, buy_ma_gap=15 -> periods 15,30,45,60,
//   stack ordering TEMA15 > TEMA30 > TEMA45 > TEMA60.
//
//   Entry is ONE EVENT, not a coincidence of crosses: the full bullish stack is
//   aligned NOW (shift 1) and was NOT fully aligned on the prior closed bar
//   (shift 2). That single alignment transition is the trigger; the rest of the
//   stack ordering is a STATE checked at shift 1. (Avoids the two-cross-same-bar
//   zero-trade trap.)
//
//   Exit (source sell params: sell_ma_count=12, sell_ma_gap=68): the bearish
//   sell-stack flip — any adjacent pair in the sell stack turns bearish, i.e.
//   a shorter sell-TEMA falls below the next longer one (source TEMA(short) >
//   TEMA(long) reversed). Implemented as: the sell stack is NOT fully bullish-
//   aligned at shift 1 while it WAS at shift 2 (a fresh bearish flip event), OR
//   defensively when the buy stack loses bullish alignment.
//
//   Stop: entry - atr_stop_mult * ATR(atr_period)   (QM_StopATRFromValue).
//   Spread guard: skip only a genuinely wide spread (.DWX models zero spread —
//                 fail-open).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific; the rest is
// framework wiring and MUST stay intact.
//
// TEMA reader: MT5 exposes TEMA only via iTEMA (not an iMA mode), so this EA
// defines a thin pooled-handle wrapper (Strategy_TEMA) that reuses the
// framework indicator pool — same sanctioned pattern as QM5_11221_ft-quickie.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11193;
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
input int    strategy_buy_ma_count      = 4;      // number of TEMA lines in the buy stack
input int    strategy_buy_ma_gap        = 15;     // period gap; buy TEMA periods = k*gap, k=1..count
input int    strategy_sell_ma_count     = 12;     // number of TEMA lines in the sell stack
input int    strategy_sell_ma_gap       = 68;     // period gap; sell TEMA periods = k*gap (capped)
input int    strategy_atr_period        = 14;     // ATR period for the protective stop
input double strategy_atr_stop_mult     = 3.0;    // stop distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// Hard cap on TEMA lines evaluated per bar (bounds per-tick work & warmup).
#define QM_MULTIMA_MAX_LINES 16

// -----------------------------------------------------------------------------
// TEMA pooled-handle reader (MT5 iTEMA has no iMA mode; reuse framework pool).
// -----------------------------------------------------------------------------
int Strategy_IndTEMA(const string sym,
                     const ENUM_TIMEFRAMES tf,
                     const int period,
                     const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   const string key = StringFormat("TEMA|%s|%d|%d|%d", sym, (int)tf, period, (int)price);
   int h = QM_IndicatorsLookup(key);
   if(h != INVALID_HANDLE)
      return h;
   h = iTEMA(sym, tf, period, 0, price);
   return QM_IndicatorsRegister(key, h);
  }

double Strategy_TEMA(const string sym,
                     const ENUM_TIMEFRAMES tf,
                     const int period,
                     const int shift = 1,
                     const ENUM_APPLIED_PRICE price = PRICE_CLOSE)
  {
   return QM_IndicatorReadBuffer(Strategy_IndTEMA(sym, tf, period, price), 0, shift);
  }

// Effective, clamped line count for a stack (>=2 so a "stack" exists).
int Strategy_StackLines(const int requested)
  {
   int n = requested;
   if(n < 2)
      n = 2;
   if(n > QM_MULTIMA_MAX_LINES)
      n = QM_MULTIMA_MAX_LINES;
   return n;
  }

// Returns +1 if the TEMA stack at `shift` is fully bullish-aligned
// (shorter period TEMA strictly above each next-longer one), 0 if not aligned,
// and -1 if any TEMA read is invalid (warmup / no data).
int Strategy_StackBullish(const int count, const int gap, const int shift)
  {
   const int lines = Strategy_StackLines(count);
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;

   double prev_shorter = Strategy_TEMA(_Symbol, tf, gap, shift); // k=1 (shortest)
   if(prev_shorter <= 0.0)
      return -1;

   for(int k = 2; k <= lines; ++k)
     {
      const int period = k * gap;
      const double cur = Strategy_TEMA(_Symbol, tf, period, shift);
      if(cur <= 0.0)
         return -1;
      // Bullish stack: each shorter TEMA strictly above the next longer one.
      if(!(prev_shorter > cur))
         return 0;
      prev_shorter = cur;
     }
   return 1;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = strategy_atr_stop_mult * atr_value;
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

   // Trigger EVENT: buy stack becomes fully bullish-aligned on this closed bar.
   // STATE now (shift 1) aligned; was NOT aligned on the prior bar (shift 2).
   const int now  = Strategy_StackBullish(strategy_buy_ma_count, strategy_buy_ma_gap, 1);
   if(now != 1)
      return false; // not aligned now (or warmup) -> no entry
   const int prev = Strategy_StackBullish(strategy_buy_ma_count, strategy_buy_ma_gap, 2);
   if(prev < 0)
      return false; // warmup on prior bar -> wait
   if(prev == 1)
      return false; // already aligned last bar -> not a fresh event, no re-fire

   // Build the long entry. Framework sizes lots (no lots field).
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_atr_stop_mult);
   if(sl <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP; exit on bearish sell-stack flip / stack loss
   req.reason = "multima_stack_long";
   return true;
  }

// No active trade management beyond the fixed ATR stop. Exit logic lives in
// Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: a fresh bearish flip of the (longer) sell stack, OR the buy stack
// losing its bullish alignment. Each is evaluated as a closed-bar state.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   // Defensive: buy stack no longer bullish-aligned at shift 1 -> exit.
   const int buy_now = Strategy_StackBullish(strategy_buy_ma_count, strategy_buy_ma_gap, 1);
   if(buy_now == 0)
      return true; // valid reads, alignment lost
   // buy_now < 0 -> warmup/no data: fall through to sell-stack check below.

   // Sell-stack bearish flip EVENT: sell stack was bullish-aligned last bar
   // (shift 2) and is no longer aligned this bar (shift 1).
   const int sell_now  = Strategy_StackBullish(strategy_sell_ma_count, strategy_sell_ma_gap, 1);
   const int sell_prev = Strategy_StackBullish(strategy_sell_ma_count, strategy_sell_ma_gap, 2);
   if(sell_now == 0 && sell_prev == 1)
      return true;

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
