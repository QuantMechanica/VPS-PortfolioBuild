#property strict
#property version   "5.0"
#property description "QM5_9400 Brooks Failed Outside-Outside Reversal H4"

#include <QM/QM_Common.mqh>

// QM5_9400 — Brooks failed outside-outside reversal on H4.
// Card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_9400_brooks-failed-outside-outside-h4.md
// Mechanic:
//   - Two consecutive meaningful outside bars define an OO range.
//   - A close breaks beyond the range within 12 H4 bars.
//   - Within 8 H4 bars, a red/green failure bar closes back inside the range.
//   - Fade the failed breakout with fixed structure+ATR SL/TP and a 24-bar time stop.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 9400;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal      = QM_NEWS_TEMPORAL_PRE60_POST60;
input QM_NewsComplianceProfile qm_news_compliance    = QM_NEWS_COMPLIANCE_DXZ;
input int                      qm_news_stale_max_hours = 336;
input string                   qm_news_min_impact      = "high";
input QM_NewsMode              qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period          = 14;
input double strategy_oo_range_atr_min    = 1.20;
input double strategy_breakout_atr_mult   = 0.20;
input double strategy_failure_atr_mult    = 0.40;
input double strategy_tp_atr_mult         = 0.80;
input double strategy_sl_atr_mult         = 0.30;
input double strategy_spread_atr_mult     = 0.20;
input int    strategy_breakout_window     = 12;
input int    strategy_failure_window      = 8;
input int    strategy_time_stop_h4_bars   = 24;

MqlRates g_rates[]; // perf-allowed: structural OO scan populated once per QM_IsNewBar-gated EntrySignal.
bool     g_rates_valid = false;

const int RATES_NEEDED = 26;

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
           strategy_oo_range_atr_min > 0.0 &&
           strategy_breakout_atr_mult > 0.0 &&
           strategy_failure_atr_mult > 0.0 &&
           strategy_tp_atr_mult > 0.0 &&
           strategy_sl_atr_mult > 0.0 &&
           strategy_spread_atr_mult > 0.0 &&
           strategy_breakout_window > 0 &&
           strategy_failure_window > 0 &&
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

bool Strategy_IsOutsideBar(const int shift)
  {
   if(shift <= 0 || shift + 1 >= ArraySize(g_rates))
      return false;

   const double high = g_rates[shift].high;
   const double low = g_rates[shift].low;
   const double prev_high = g_rates[shift + 1].high;
   const double prev_low = g_rates[shift + 1].low;
   const double range = high - low;
   const double atr_ref = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, shift + 1);

   if(high <= 0.0 || low <= 0.0 || prev_high <= 0.0 || prev_low <= 0.0 || range <= 0.0 || atr_ref <= 0.0)
      return false;

   return (high > prev_high &&
           low < prev_low &&
           range >= strategy_oo_range_atr_min * atr_ref);
  }

bool Strategy_RangeExtreme(const int newer_shift,
                           const int older_shift,
                           const bool want_high,
                           double &extreme)
  {
   extreme = 0.0;
   if(newer_shift <= 0 || older_shift < newer_shift || older_shift >= ArraySize(g_rates))
      return false;

   bool have_value = false;
   for(int shift = newer_shift; shift <= older_shift; ++shift)
     {
      const double value = want_high ? g_rates[shift].high : g_rates[shift].low;
      if(value <= 0.0)
         return false;

      if(!have_value)
        {
         extreme = value;
         have_value = true;
        }
      else if(want_high && value > extreme)
         extreme = value;
      else if(!want_high && value < extreme)
         extreme = value;
     }

   return have_value;
  }

bool Strategy_BreakoutInvalidated(const int breakout_shift,
                                  const double breakout_extreme,
                                  const bool up_breakout)
  {
   for(int shift = breakout_shift - 1; shift >= 2; --shift)
     {
      if(up_breakout && g_rates[shift].high > breakout_extreme)
         return true;
      if(!up_breakout && g_rates[shift].low < breakout_extreme)
         return true;
     }
   return false;
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

   const double atr_failure = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   if(atr_failure <= 0.0 || !Strategy_SpreadAllowed(atr_failure))
      return false;

   const MqlRates fail_bar = g_rates[1];
   if(fail_bar.close <= 0.0 || fail_bar.open <= 0.0 || fail_bar.high <= 0.0 || fail_bar.low <= 0.0)
      return false;

   const int max_breakout_shift = MathMin(strategy_failure_window + 1, RATES_NEEDED - 4);
   for(int breakout_shift = 2; breakout_shift <= max_breakout_shift; ++breakout_shift)
     {
      const double atr_breakout = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, breakout_shift);
      if(atr_breakout <= 0.0)
         continue;

      const int max_anchor_shift = MathMin(breakout_shift + strategy_breakout_window, RATES_NEEDED - 3);
      for(int anchor_shift = breakout_shift + 1; anchor_shift <= max_anchor_shift; ++anchor_shift)
        {
         if(!Strategy_IsOutsideBar(anchor_shift + 1) || !Strategy_IsOutsideBar(anchor_shift))
            continue;

         const double oo_high = MathMax(g_rates[anchor_shift + 1].high, g_rates[anchor_shift].high);
         const double oo_low = MathMin(g_rates[anchor_shift + 1].low, g_rates[anchor_shift].low);
         if(oo_high <= oo_low || oo_low <= 0.0)
            continue;

         const bool up_breakout = (g_rates[breakout_shift].close > oo_high + strategy_breakout_atr_mult * atr_breakout);
         const bool down_breakout = (g_rates[breakout_shift].close < oo_low - strategy_breakout_atr_mult * atr_breakout);
         if(up_breakout == down_breakout)
            continue;

         double breakout_extreme = 0.0;
         if(!Strategy_RangeExtreme(breakout_shift, anchor_shift, up_breakout, breakout_extreme))
            continue;
         if(Strategy_BreakoutInvalidated(breakout_shift, breakout_extreme, up_breakout))
            continue;

         if(up_breakout)
           {
            const bool failed_inside = (fail_bar.close < oo_high &&
                                        fail_bar.close < fail_bar.open &&
                                        fail_bar.low <= oo_high - strategy_failure_atr_mult * atr_failure);
            if(!failed_inside)
               continue;

            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            const double sl_raw = MathMax(entry, breakout_extreme) + strategy_sl_atr_mult * atr_failure;
            const double tp_raw = oo_low - strategy_tp_atr_mult * atr_failure;
            if(entry <= 0.0 || sl_raw <= entry || tp_raw >= entry)
               continue;

            signal_type = QM_SELL;
            stop_loss = QM_StopRulesNormalizePrice(_Symbol, sl_raw);
            take_profit = QM_StopRulesNormalizePrice(_Symbol, tp_raw);
            if(stop_loss <= entry || take_profit >= entry)
               continue;
            reason = "BROOKS_OO_UP_FAIL_SHORT";
            return true;
           }

         const bool failed_inside = (fail_bar.close > oo_low &&
                                     fail_bar.close > fail_bar.open &&
                                     fail_bar.high >= oo_low + strategy_failure_atr_mult * atr_failure);
         if(!failed_inside)
            continue;

         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double sl_raw = MathMin(entry, breakout_extreme) - strategy_sl_atr_mult * atr_failure;
         const double tp_raw = oo_high + strategy_tp_atr_mult * atr_failure;
         if(entry <= 0.0 || sl_raw >= entry || tp_raw <= entry)
            continue;

         signal_type = QM_BUY;
         stop_loss = QM_StopRulesNormalizePrice(_Symbol, sl_raw);
         take_profit = QM_StopRulesNormalizePrice(_Symbol, tp_raw);
         if(stop_loss >= entry || take_profit <= entry)
            continue;
         reason = "BROOKS_OO_DOWN_FAIL_LONG";
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

   if(!Strategy_ValidInputs())
      return false;
   if(Strategy_HaveOpenPosition())
      return false;
   if(!Strategy_RefreshRateCache())
      return false;

   QM_OrderType signal_type = QM_BUY;
   double stop_loss = 0.0;
   double take_profit = 0.0;
   string reason = "";
   if(!Strategy_ResolveSignal(signal_type, stop_loss, take_profit, reason))
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
   if(h4_seconds <= 0 || strategy_time_stop_h4_bars <= 0)
      return false;

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
      if(opened > 0 && (TimeCurrent() - opened) >= (long)strategy_time_stop_h4_bars * h4_seconds)
         return true;
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9400_brooks-failed-outside-outside-h4\"}");
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
