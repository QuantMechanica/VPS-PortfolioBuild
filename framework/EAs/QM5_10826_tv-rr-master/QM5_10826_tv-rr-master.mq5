#property strict
#property version   "5.0"
#property description "QM5_10826 TradingView RR Master LC"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10826;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_rsi_fast_period      = 7;
input int    strategy_rsi_slow_period      = 14;
input int    strategy_ema_period           = 200;
input int    strategy_adx_period           = 14;
input double strategy_adx_threshold        = 30.0;
input int    strategy_atr_period           = 14;
input double strategy_ema_atr_clear_mult   = 0.25;
input double strategy_stop_atr_buffer_mult = 0.20;
input double strategy_target_rr            = 1.70;
input int    strategy_cooldown_bars        = 8;
input int    strategy_vwap_max_bars        = 256;
input double strategy_spread_stop_fraction = 0.10;

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_CooldownActive(const datetime signal_time)
  {
   if(strategy_cooldown_bars <= 0)
      return false;

   int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0)
      period_seconds = 3600;

   const datetime window_start = signal_time - (datetime)(period_seconds * strategy_cooldown_bars);
   if(!HistorySelect(window_start, signal_time))
      return false;

   const long magic = (long)QM_FrameworkMagic();
   const int total = HistoryDealsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((long)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;

      const ENUM_DEAL_ENTRY entry_type = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_type == DEAL_ENTRY_OUT || entry_type == DEAL_ENTRY_INOUT || entry_type == DEAL_ENTRY_OUT_BY)
         return true;
     }

   return false;
  }

bool Strategy_ReadSignalRates(MqlRates &rates[], int &copied)
  {
   int bars_to_copy = strategy_vwap_max_bars;
   if(bars_to_copy < 64)
      bars_to_copy = 64;
   if(bars_to_copy > 512)
      bars_to_copy = 512;

   ArraySetAsSeries(rates, true);
   copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, bars_to_copy, rates); // perf-allowed: Strategy_EntrySignal is called only after QM_IsNewBar().
   return (copied >= 3);
  }

double Strategy_SessionVWAP(const MqlRates &rates[], const int copied)
  {
   if(copied < 3)
      return 0.0;

   MqlDateTime signal_dt;
   TimeToStruct(rates[1].time, signal_dt);

   double pv_sum = 0.0;
   double vol_sum = 0.0;
   for(int i = 1; i < copied; ++i)
     {
      MqlDateTime bar_dt;
      TimeToStruct(rates[i].time, bar_dt);
      if(bar_dt.year != signal_dt.year || bar_dt.day_of_year != signal_dt.day_of_year)
         break;

      const double volume = MathMax(1.0, (double)rates[i].tick_volume);
      const double typical = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      pv_sum += typical * volume;
      vol_sum += volume;
     }

   if(vol_sum <= 0.0)
      return 0.0;
   return pv_sum / vol_sum;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_rsi_fast_period <= 0 ||
      strategy_rsi_slow_period <= 0 ||
      strategy_rsi_fast_period >= strategy_rsi_slow_period ||
      strategy_ema_period <= 0 ||
      strategy_adx_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_adx_threshold <= 0.0 ||
      strategy_ema_atr_clear_mult < 0.0 ||
      strategy_stop_atr_buffer_mult <= 0.0 ||
      strategy_target_rr <= 0.0 ||
      strategy_spread_stop_fraction < 0.0)
      return false;

   MqlRates rates[];
   int copied = 0;
   if(!Strategy_ReadSignalRates(rates, copied))
      return false;

   if(Strategy_CooldownActive(rates[1].time))
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double close_1 = rates[1].close;
   const double ema_1 = QM_EMA(_Symbol, tf, strategy_ema_period, 1);
   const double atr_1 = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   const double adx_1 = QM_ADX(_Symbol, tf, strategy_adx_period, 1);
   const double adx_2 = QM_ADX(_Symbol, tf, strategy_adx_period, 2);
   const double rsi_fast_1 = QM_RSI(_Symbol, tf, strategy_rsi_fast_period, 1);
   const double rsi_fast_2 = QM_RSI(_Symbol, tf, strategy_rsi_fast_period, 2);
   const double rsi_slow_1 = QM_RSI(_Symbol, tf, strategy_rsi_slow_period, 1);
   const double rsi_slow_2 = QM_RSI(_Symbol, tf, strategy_rsi_slow_period, 2);
   const double vwap_1 = Strategy_SessionVWAP(rates, copied);

   if(close_1 <= 0.0 || ema_1 <= 0.0 || atr_1 <= 0.0 || adx_1 <= 0.0 || adx_2 <= 0.0 ||
      rsi_fast_1 <= 0.0 || rsi_fast_2 <= 0.0 || rsi_slow_1 <= 0.0 || rsi_slow_2 <= 0.0 ||
      vwap_1 <= 0.0)
      return false;

   if(adx_1 <= strategy_adx_threshold || adx_1 <= adx_2)
      return false;

   const double ema_clear = MathAbs(close_1 - ema_1);
   if(ema_clear < (strategy_ema_atr_clear_mult * atr_1))
      return false;

   const bool long_signal = (close_1 > ema_1 &&
                             close_1 > vwap_1 &&
                             rsi_fast_2 <= rsi_slow_2 &&
                             rsi_fast_1 > rsi_slow_1);
   const bool short_signal = (close_1 < ema_1 &&
                              close_1 < vwap_1 &&
                              rsi_fast_2 >= rsi_slow_2 &&
                              rsi_fast_1 < rsi_slow_1);
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry_price = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   const double raw_sl = long_signal ? (rates[1].low - strategy_stop_atr_buffer_mult * atr_1)
                                     : (rates[1].high + strategy_stop_atr_buffer_mult * atr_1);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
   if(sl <= 0.0)
      return false;
   if(long_signal && sl >= entry_price)
      return false;
   if(short_signal && sl <= entry_price)
      return false;

   const double stop_distance = MathAbs(entry_price - sl);
   const double spread = ask - bid;
   if(stop_distance <= 0.0 || spread > stop_distance * strategy_spread_stop_fraction)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry_price, sl, strategy_target_rr);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "RR_MASTER_LONG" : "RR_MASTER_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10826_tv-rr-master\"}");
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
