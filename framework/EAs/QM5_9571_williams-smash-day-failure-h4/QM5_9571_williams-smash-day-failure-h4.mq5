#property strict
#property version   "5.0"
#property description "QM5_9571 Williams Failed Smash-Day Reversal H4"

#include <QM/QM_Common.mqh>

// QM5_9571 - Larry Williams failed Smash-Day reversal on H4.
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_9571_williams-smash-day-failure-h4.md
// Mechanic:
//   - A Smash-Day setup bar extends beyond the prior H4 low/high and closes in its extreme quartile.
//   - The next closed H4 bar rejects that move by closing beyond the setup bar in the opposite direction.
//   - Fade the failed breakout with structure+ATR SL, 2R TP, opposite-failure exit, and a 16-bar time stop.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9571;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_PRE60_POST60;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period              = 14;
input double strategy_smash_extreme_atr_mult  = 0.25;
input double strategy_setup_close_quartile    = 0.25;
input double strategy_failure_break_atr_mult  = 0.10;
input double strategy_failure_range_atr_mult  = 0.80;
input double strategy_sl_atr_mult             = 0.50;
input double strategy_rr                      = 2.0;
input double strategy_spread_atr_mult         = 0.20;
input int    strategy_time_stop_h4_bars       = 16;

MqlRates g_rates[]; // perf-allowed: structural Smash-Day check populated once per QM_IsNewBar-gated EntrySignal.
bool     g_rates_valid = false;

bool         g_last_signal_valid = false;
QM_OrderType g_last_signal_type  = QM_BUY;
datetime     g_last_signal_time  = 0;

const int RATES_NEEDED = 8;

int Strategy_SymbolSlot()
  {
   if(_Symbol == "EURUSD.DWX") return 0;
   if(_Symbol == "GBPUSD.DWX") return 1;
   if(_Symbol == "USDJPY.DWX") return 2;
   if(_Symbol == "AUDUSD.DWX") return 3;
   if(_Symbol == "USDCAD.DWX") return 4;
   if(_Symbol == "USDCHF.DWX") return 5;
   if(_Symbol == "NZDUSD.DWX") return 6;
   if(_Symbol == "XAUUSD.DWX") return 7;
   if(_Symbol == "XTIUSD.DWX") return 8;
   if(_Symbol == "GDAXI.DWX")  return 9;
   if(_Symbol == "NDX.DWX")    return 10;
   if(_Symbol == "WS30.DWX")   return 11;
   if(_Symbol == "UK100.DWX")  return 12;
   return -1;
  }

bool Strategy_ValidInputs()
  {
   return (strategy_atr_period > 0 &&
           strategy_smash_extreme_atr_mult > 0.0 &&
           strategy_setup_close_quartile > 0.0 &&
           strategy_setup_close_quartile < 1.0 &&
           strategy_failure_break_atr_mult >= 0.0 &&
           strategy_failure_range_atr_mult > 0.0 &&
           strategy_sl_atr_mult > 0.0 &&
           strategy_rr > 0.0 &&
           strategy_spread_atr_mult > 0.0 &&
           strategy_time_stop_h4_bars > 0);
  }

bool Strategy_RefreshRateCache()
  {
   ArraySetAsSeries(g_rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 0, RATES_NEEDED, g_rates); // perf-allowed: bounded H4 OHLC window; EntrySignal is called only after QM_IsNewBar().
   g_rates_valid = (copied >= RATES_NEEDED);
   return g_rates_valid;
  }

bool Strategy_HaveOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_SpreadAllowed(const double atr)
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid || atr <= 0.0)
      return false;
   return ((ask - bid) <= strategy_spread_atr_mult * atr);
  }

void Strategy_UpdateSignalCache(const bool is_valid,
                                const QM_OrderType signal_type,
                                const datetime signal_time)
  {
   g_last_signal_valid = is_valid;
   if(!is_valid)
      return;

   g_last_signal_type = signal_type;
   g_last_signal_time = signal_time;
  }

bool Strategy_ResolveSignal(QM_OrderType &signal_type,
                            double &stop_loss,
                            double &take_profit,
                            string &reason)
  {
   signal_type = QM_BUY;
   stop_loss = 0.0;
   take_profit = 0.0;
   reason = "";

   if(!g_rates_valid || ArraySize(g_rates) < RATES_NEEDED)
      return false;

   const MqlRates failure_bar = g_rates[1];
   const MqlRates setup_bar = g_rates[2];
   const MqlRates prior_bar = g_rates[3];

   const double setup_range = setup_bar.high - setup_bar.low;
   const double failure_range = failure_bar.high - failure_bar.low;
   if(setup_bar.high <= 0.0 || setup_bar.low <= 0.0 ||
      failure_bar.high <= 0.0 || failure_bar.low <= 0.0 ||
      prior_bar.high <= 0.0 || prior_bar.low <= 0.0 ||
      setup_range <= 0.0 || failure_range <= 0.0)
      return false;

   const double atr_prior = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 3);
   const double atr_setup = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 2);
   const double atr_failure = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr_prior <= 0.0 || atr_setup <= 0.0 || atr_failure <= 0.0)
      return false;

   if(failure_range < strategy_failure_range_atr_mult * atr_setup)
      return false;

   const bool down_smash = (setup_bar.low < prior_bar.low - strategy_smash_extreme_atr_mult * atr_prior &&
                            setup_bar.close <= setup_bar.low + strategy_setup_close_quartile * setup_range);
   const bool up_smash = (setup_bar.high > prior_bar.high + strategy_smash_extreme_atr_mult * atr_prior &&
                          setup_bar.close >= setup_bar.high - strategy_setup_close_quartile * setup_range);

   if(down_smash)
     {
      const bool failed_down = (failure_bar.close > setup_bar.high + strategy_failure_break_atr_mult * atr_setup);
      if(failed_down)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double sl_raw = MathMin(setup_bar.low, failure_bar.low) - strategy_sl_atr_mult * atr_failure;
         const double tp_raw = entry + strategy_rr * (entry - sl_raw);
         if(entry <= 0.0 || sl_raw >= entry || tp_raw <= entry)
            return false;

         signal_type = QM_BUY;
         stop_loss = QM_StopRulesNormalizePrice(_Symbol, sl_raw);
         take_profit = QM_StopRulesNormalizePrice(_Symbol, tp_raw);
         if(stop_loss >= entry || take_profit <= entry)
            return false;
         reason = "WILLIAMS_FAILED_DOWN_SMASH_LONG";
         return true;
        }
     }

   if(up_smash)
     {
      const bool failed_up = (failure_bar.close < setup_bar.low - strategy_failure_break_atr_mult * atr_setup);
      if(failed_up)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double sl_raw = MathMax(setup_bar.high, failure_bar.high) + strategy_sl_atr_mult * atr_failure;
         const double tp_raw = entry - strategy_rr * (sl_raw - entry);
         if(entry <= 0.0 || sl_raw <= entry || tp_raw >= entry)
            return false;

         signal_type = QM_SELL;
         stop_loss = QM_StopRulesNormalizePrice(_Symbol, sl_raw);
         take_profit = QM_StopRulesNormalizePrice(_Symbol, tp_raw);
         if(stop_loss <= entry || take_profit >= entry)
            return false;
         reason = "WILLIAMS_FAILED_UP_SMASH_SHORT";
         return true;
        }
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H4)
      return true;

   const int slot = Strategy_SymbolSlot();
   if(slot < 0)
      return true;
   if(slot != qm_magic_slot_offset)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_UpdateSignalCache(false, QM_BUY, 0);

   if(!Strategy_ValidInputs())
      return false;
   if(!Strategy_RefreshRateCache())
      return false;

   QM_OrderType signal_type = QM_BUY;
   double stop_loss = 0.0;
   double take_profit = 0.0;
   string reason = "";
   if(!Strategy_ResolveSignal(signal_type, stop_loss, take_profit, reason))
      return false;

   Strategy_UpdateSignalCache(true, signal_type, g_rates[1].time);

   if(Strategy_HaveOpenPosition())
      return false;

   const double atr_failure = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(!Strategy_SpreadAllowed(atr_failure))
      return false;

   req.type = signal_type;
   req.sl = stop_loss;
   req.tp = take_profit;
   req.reason = reason;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int h4_seconds = PeriodSeconds(PERIOD_H4);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(h4_seconds > 0 && strategy_time_stop_h4_bars > 0 &&
         opened > 0 && (TimeCurrent() - opened) >= (long)strategy_time_stop_h4_bars * h4_seconds)
         return true;

      if(g_last_signal_valid && opened > 0 && g_last_signal_time > opened)
        {
         const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(position_type == POSITION_TYPE_BUY && g_last_signal_type == QM_SELL)
            return true;
         if(position_type == POSITION_TYPE_SELL && g_last_signal_type == QM_BUY)
            return true;
        }
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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
                        60,
                        60,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   ArraySetAsSeries(g_rates, true);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9571_williams-smash-day-failure-h4\"}");
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
