#property strict
#property version   "5.0"
#property description "QM5_11489 suhr-s-bank-stop-run-reversal-d1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11489 suhr-s-bank-stop-run-reversal-d1
// -----------------------------------------------------------------------------
// Card: D:\QM\strategy_farm\artifacts\cards_approved\QM5_11489_suhr-s-bank-stop-run-reversal-d1.md
// Source: Sterling Suhr, "The Bank Trading Forex Strategy" in TradingPub
// "6 Simple Strategies for Trading Forex" (2014).
//
// Implementation boundary: only strategy inputs and the five Strategy_* hooks
// are strategy-specific. Framework lifecycle, risk, magic, news, Friday close,
// kill-switch, and entry dispatch stay as provided by EA_Skeleton.mq5.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11489;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_stop_run_break_pips = 3;
input int    strategy_pullback_window_pips = 15;
input int    strategy_stop_loss_pips      = 20;
input double strategy_reward_rr           = 3.0;
input int    strategy_spread_cap_pips     = 20;
input bool   strategy_block_friday_entries = true;

enum SuhrSetupState
  {
   SUHR_IDLE = 0,
   SUHR_STOP_RUN_SEEN = 1,
   SUHR_CONFIRMATION_SEEN = 2,
   SUHR_DONE = 3
  };

int      g_suhr_day_of_year = -1;
int      g_suhr_year = -1;
double   g_manip_high = 0.0;
double   g_manip_low = 0.0;
int      g_short_state = SUHR_IDLE;
int      g_long_state = SUHR_IDLE;
datetime g_short_stop_bar_time = 0;
datetime g_long_stop_bar_time = 0;

bool ReadClosedBar(const ENUM_TIMEFRAMES tf, MqlRates &bar)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, 1, 1, rates); // perf-allowed: one closed bar inside framework new-bar gate
   if(copied != 1)
      return false;

   bar = rates[0];
   return (bar.high > 0.0 && bar.low > 0.0 && bar.close > 0.0);
  }

bool RefreshDailyState(const datetime closed_h1_time)
  {
   MqlDateTime dt;
   TimeToStruct(closed_h1_time, dt);

   if(dt.year == g_suhr_year && dt.day_of_year == g_suhr_day_of_year)
      return (g_manip_high > 0.0 && g_manip_low > 0.0);

   MqlRates day_bar;
   if(!ReadClosedBar(PERIOD_D1, day_bar))
      return false;

   g_suhr_year = dt.year;
   g_suhr_day_of_year = dt.day_of_year;
   g_manip_high = day_bar.high;
   g_manip_low = day_bar.low;
   g_short_state = SUHR_IDLE;
   g_long_state = SUHR_IDLE;
   g_short_stop_bar_time = 0;
   g_long_stop_bar_time = 0;

   return (g_manip_high > 0.0 && g_manip_low > 0.0);
  }

bool IsFridayEntryBlocked(const datetime closed_h1_time)
  {
   if(!strategy_block_friday_entries)
      return false;

   MqlDateTime dt;
   TimeToStruct(closed_h1_time, dt);
   return (dt.day_of_week == 5);
  }

void ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

// Return TRUE to block trading this tick. Spread guard is .DWX-safe:
// zero modeled spread passes, only genuinely wide spread blocks.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Caller guarantees QM_IsNewBar() == true. This implements the card's daily
// state machine: IDLE -> STOP_RUN_SEEN -> CONFIRMATION_SEEN -> ENTRY/DONE.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ResetEntryRequest(req);

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_stop_run_break_pips < 0 ||
      strategy_pullback_window_pips < 1 ||
      strategy_stop_loss_pips < 1 ||
      strategy_reward_rr <= 0.0)
      return false;

   MqlRates h1;
   if(!ReadClosedBar(PERIOD_H1, h1))
      return false;

   if(IsFridayEntryBlocked(h1.time))
      return false;

   if(!RefreshDailyState(h1.time))
      return false;

   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(pip <= 0.0)
      return false;

   const double stop_run_break = strategy_stop_run_break_pips * pip;
   const double pullback_window = strategy_pullback_window_pips * pip;

   if(g_short_state == SUHR_IDLE &&
      h1.high >= g_manip_high + stop_run_break)
     {
      g_short_state = SUHR_STOP_RUN_SEEN;
      g_short_stop_bar_time = h1.time;
     }

   if(g_long_state == SUHR_IDLE &&
      h1.low <= g_manip_low - stop_run_break)
     {
      g_long_state = SUHR_STOP_RUN_SEEN;
      g_long_stop_bar_time = h1.time;
     }

   if(g_short_state == SUHR_STOP_RUN_SEEN &&
      h1.time != g_short_stop_bar_time &&
      h1.close < g_manip_high)
      g_short_state = SUHR_CONFIRMATION_SEEN;

   if(g_long_state == SUHR_STOP_RUN_SEEN &&
      h1.time != g_long_stop_bar_time &&
      h1.close > g_manip_low)
      g_long_state = SUHR_CONFIRMATION_SEEN;

   if(g_short_state == SUHR_CONFIRMATION_SEEN &&
      h1.low >= g_manip_high - pullback_window)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_stop_loss_pips);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_reward_rr);
      if(sl <= 0.0 || tp <= 0.0 || sl <= entry || tp >= entry)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "prev_day_high_stop_run_reversal";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_short_state = SUHR_DONE;
      return true;
     }

   if(g_long_state == SUHR_CONFIRMATION_SEEN &&
      h1.high <= g_manip_low + pullback_window)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_stop_loss_pips);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_reward_rr);
      if(sl <= 0.0 || tp <= 0.0 || sl >= entry || tp <= entry)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "prev_day_low_stop_run_reversal";
      req.symbol_slot = qm_magic_slot_offset;
      req.expiration_seconds = 0;
      g_long_state = SUHR_DONE;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no trailing, partial close, or break-even.
  }

bool Strategy_ExitSignal()
  {
   // Exits are fixed SL/TP plus framework Friday close.
   return false;
  }

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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
