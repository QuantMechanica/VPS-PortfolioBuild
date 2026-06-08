#property strict
#property version   "5.0"
#property description "QM5_11224 ft-tdseq"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11224;
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
input int    strategy_setup_count       = 9;
input int    strategy_compare_lag       = 4;
input bool   strategy_require_ideal_exceed_low = true;
input int    strategy_atr_period        = 14;
input double strategy_atr_stop_mult     = 1.5;
input double strategy_disaster_stop_pct = 5.0;
input int    strategy_warmup_bars       = 30;
input double strategy_max_spread_stop_fraction = 0.06;

bool g_tdseq_exit_on_closed_bar = false;

// -----------------------------------------------------------------------------
// Strategy hooks — implemented mechanically from the approved card.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
      return true;

   if(strategy_setup_count < 1 || strategy_compare_lag < 1 ||
      strategy_atr_period < 1 || strategy_atr_stop_mult <= 0.0 ||
      strategy_disaster_stop_pct <= 0.0 ||
      strategy_warmup_bars < 1 ||
      strategy_max_spread_stop_fraction < 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double stop_distance = atr * strategy_atr_stop_mult;
   if(stop_distance <= 0.0)
      return true;

   const double spread = ask - bid;
   if(spread > stop_distance * strategy_max_spread_stop_fraction)
      return true;

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_11224_TDSEQ_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_tdseq_exit_on_closed_bar = false;

   const int required_bars = MathMax(strategy_warmup_bars,
                                     strategy_setup_count + strategy_compare_lag + 4);
   const double warmup_close = iClose(_Symbol, PERIOD_H1, required_bars); // perf-allowed: bounded TD Sequential warmup read on framework closed-bar path.
   if(warmup_close <= 0.0)
      return false;

   int buy_count = 0;
   int sell_count = 0;
   const int max_count = MathMax(strategy_setup_count, 9);

   for(int shift = 1; shift <= max_count; ++shift)
     {
      const double c_now = iClose(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded TD Sequential close comparison on framework closed-bar path.
      const double c_lag = iClose(_Symbol, PERIOD_H1, shift + strategy_compare_lag); // perf-allowed: bounded TD Sequential close comparison on framework closed-bar path.
      if(c_now <= 0.0 || c_lag <= 0.0 || !(c_now < c_lag))
         break;
      buy_count++;
     }

   for(int shift = 1; shift <= max_count; ++shift)
     {
      const double c_now = iClose(_Symbol, PERIOD_H1, shift); // perf-allowed: bounded TD Sequential close comparison on framework closed-bar path.
      const double c_lag = iClose(_Symbol, PERIOD_H1, shift + strategy_compare_lag); // perf-allowed: bounded TD Sequential close comparison on framework closed-bar path.
      if(c_now <= 0.0 || c_lag <= 0.0 || !(c_now > c_lag))
         break;
      sell_count++;
     }

   bool ideal_buy = !strategy_require_ideal_exceed_low;
   if(buy_count >= 9)
     {
      const int sh8 = buy_count - 8 + 1;
      const int sh9 = buy_count - 9 + 1;
      const int sh6 = buy_count - 6 + 1;
      const int sh7 = buy_count - 7 + 1;
      const double low8 = iLow(_Symbol, PERIOD_H1, sh8); // perf-allowed: bounded TD Sequential ideal-count low read.
      const double low9 = iLow(_Symbol, PERIOD_H1, sh9); // perf-allowed: bounded TD Sequential ideal-count low read.
      const double low6 = iLow(_Symbol, PERIOD_H1, sh6); // perf-allowed: bounded TD Sequential ideal-count low read.
      const double low7 = iLow(_Symbol, PERIOD_H1, sh7); // perf-allowed: bounded TD Sequential ideal-count low read.
      ideal_buy = (low8 > 0.0 && low9 > 0.0 && low6 > 0.0 && low7 > 0.0 &&
                   (low8 < low6 || low8 < low7 || low9 < low6 || low9 < low7));
     }

   bool ideal_sell = false;
   if(sell_count >= 9)
     {
      const int sh8 = sell_count - 8 + 1;
      const int sh9 = sell_count - 9 + 1;
      const int sh6 = sell_count - 6 + 1;
      const int sh7 = sell_count - 7 + 1;
      const double high8 = iHigh(_Symbol, PERIOD_H1, sh8); // perf-allowed: bounded TD Sequential ideal-count high read.
      const double high9 = iHigh(_Symbol, PERIOD_H1, sh9); // perf-allowed: bounded TD Sequential ideal-count high read.
      const double high6 = iHigh(_Symbol, PERIOD_H1, sh6); // perf-allowed: bounded TD Sequential ideal-count high read.
      const double high7 = iHigh(_Symbol, PERIOD_H1, sh7); // perf-allowed: bounded TD Sequential ideal-count high read.
      ideal_sell = (high8 > 0.0 && high9 > 0.0 && high6 > 0.0 && high7 > 0.0 &&
                    (high8 > high6 || high8 > high7 || high9 > high6 || high9 > high7));
     }

   g_tdseq_exit_on_closed_bar = (sell_count >= strategy_setup_count || ideal_sell);
   if(g_tdseq_exit_on_closed_bar)
      return false;

   if(buy_count < strategy_setup_count || !ideal_buy)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || bid <= 0.0 || entry <= bid)
      return false;

   const double atr_sl = QM_StopATR(_Symbol, QM_BUY, entry,
                                    strategy_atr_period, strategy_atr_stop_mult);
   const double disaster_sl = NormalizeDouble(entry * (1.0 - strategy_disaster_stop_pct / 100.0),
                                              _Digits);
   double sl = atr_sl;
   if(disaster_sl > sl)
      sl = disaster_sl;
   if(sl <= 0.0 || sl >= entry)
      return false;

   const double stop_distance = MathAbs(entry - sl);
   const double spread = entry - bid;
   if(stop_distance <= 0.0 || spread > stop_distance * strategy_max_spread_stop_fraction)
      return false;

   req.sl = sl;
   req.tp = 0.0;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   return g_tdseq_exit_on_closed_bar;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_11224_ft-tdseq\"}");
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

