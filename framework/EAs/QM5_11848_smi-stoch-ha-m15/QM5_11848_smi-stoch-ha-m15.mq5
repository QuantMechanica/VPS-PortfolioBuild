#property strict
#property version   "5.0"
#property description "QM5_11848 smi-stoch-ha-m15"

#include <QM/QM_Common.mqh>

// QuantMechanica V5 EA — QM5_11848 smi-stoch-ha-m15
// Source card: D:/QM/strategy_farm/artifacts/cards_approved/QM5_11848_smi-stoch-ha-m15.md

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11848;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    smi_hl_period              = 14;
input int    smi_smooth1                = 10;
input int    smi_smooth2                = 14;
input int    smi_signal_period          = 5;
input double smi_extreme                = 40.0;
input int    ema_fast_period            = 5;
input int    ema_slow_period            = 6;
input int    ema_exit_period            = 60;
input int    ema_trend_period           = 200;
input int    stoch_k_period             = 10;
input int    stoch_d_period             = 1;
input int    stoch_slowing              = 7;
input double stoch_lo                   = 20.0;
input double stoch_hi                   = 80.0;
input int    swing_lookback_bars        = 8;
input int    atr_period                 = 14;
input double sl_atr_mult                = 2.0;
input int    hard_sl_pips               = 25;
input int    tp_pips                    = 40;
input int    breakeven_trigger_pips     = 20;
input int    breakeven_buffer_pips      = 2;
input int    session_start_utc_hour     = 7;
input double spread_pct_of_stop         = 15.0;

double g_smi[2];
double g_ha_open[2];
double g_ha_close[2];
double g_smi_ema1_num = 0.0;
double g_smi_ema2_num = 0.0;
double g_smi_ema1_den = 0.0;
double g_smi_ema2_den = 0.0;
double g_smi_signal = 0.0;
double g_ha_open_run = 0.0;
int    g_state_bars = 0;
bool   g_ha_seeded = false;

bool Strategy_IsAfterSessionStartUTC()
  {
   datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   MqlDateTime utc;
   TimeToStruct(utc_now, utc);
   return (utc.hour >= session_start_utc_hour);
  }

double Strategy_PipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

void Strategy_AdvanceState_OnNewBar()
  {
   // SMI and Heiken Ashi are bespoke card indicators; this block runs once per closed bar only.
   const int bars_needed = MathMax(smi_hl_period, 2);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, bars_needed, rates); // perf-allowed
   if(copied < bars_needed)
      return;

   const double o1 = rates[0].open;
   const double h1 = rates[0].high;
   const double l1 = rates[0].low;
   const double c1 = rates[0].close;
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0)
      return;

   double hh = -DBL_MAX;
   double ll = DBL_MAX;
   for(int i = 0; i < smi_hl_period; ++i)
     {
      if(rates[i].high > hh)
         hh = rates[i].high;
      if(rates[i].low < ll)
         ll = rates[i].low;
     }
   if(hh <= 0.0 || ll <= 0.0 || hh <= ll)
      return;

   const double midpoint = 0.5 * (hh + ll);
   const double rel = c1 - midpoint;
   const double rng = hh - ll;
   const double a1 = 2.0 / (smi_smooth1 + 1.0);
   const double a2 = 2.0 / (smi_smooth2 + 1.0);
   const double as = 2.0 / (smi_signal_period + 1.0);

   if(g_state_bars <= 0)
     {
      g_smi_ema1_num = rel;
      g_smi_ema2_num = rel;
      g_smi_ema1_den = rng;
      g_smi_ema2_den = rng;
     }
   else
     {
      g_smi_ema1_num = g_smi_ema1_num + a1 * (rel - g_smi_ema1_num);
      g_smi_ema2_num = g_smi_ema2_num + a2 * (g_smi_ema1_num - g_smi_ema2_num);
      g_smi_ema1_den = g_smi_ema1_den + a1 * (rng - g_smi_ema1_den);
      g_smi_ema2_den = g_smi_ema2_den + a2 * (g_smi_ema1_den - g_smi_ema2_den);
     }

   double smi_raw = 0.0;
   const double half_den = 0.5 * g_smi_ema2_den;
   if(half_den > 0.0)
      smi_raw = 100.0 * g_smi_ema2_num / half_den;

   if(g_state_bars <= 0)
      g_smi_signal = smi_raw;
   else
      g_smi_signal = g_smi_signal + as * (smi_raw - g_smi_signal);

   const double ha_close = 0.25 * (o1 + h1 + l1 + c1);
   double ha_open = 0.0;
   if(!g_ha_seeded)
     {
      ha_open = 0.5 * (o1 + c1);
      g_ha_seeded = true;
     }
   else
      ha_open = 0.5 * (g_ha_open_run + g_ha_close[0]);
   g_ha_open_run = ha_open;

   g_smi[1] = g_smi[0];
   g_ha_open[1] = g_ha_open[0];
   g_ha_close[1] = g_ha_close[0];

   g_smi[0] = g_smi_signal;
   g_ha_open[0] = ha_open;
   g_ha_close[0] = ha_close;
   g_state_bars++;
  }

double Strategy_StopPrice(const QM_OrderType side, const double entry, const double atr_value)
  {
   const double structure_sl = QM_StopStructure(_Symbol, side, entry, swing_lookback_bars);
   const double fixed_dist = Strategy_PipDistance(hard_sl_pips);
   const double atr_dist = atr_value * sl_atr_mult;
   const double min_dist = MathMax(fixed_dist, atr_dist);
   const double floor_sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, min_dist);
   if(structure_sl <= 0.0)
      return floor_sl;

   if(side == QM_BUY)
      return QM_StopRulesNormalizePrice(_Symbol, MathMin(structure_sl, floor_sl));
   return QM_StopRulesNormalizePrice(_Symbol, MathMax(structure_sl, floor_sl));
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsAfterSessionStartUTC())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, atr_period, 1);
   const double stop_distance = atr_value * sl_atr_mult;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (spread_pct_of_stop / 100.0) * stop_distance)
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

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(g_state_bars < 2)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double ema_fast_1 = QM_EMA(_Symbol, _Period, ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, ema_slow_period, 2);
   const double ema_trend_1 = QM_EMA(_Symbol, _Period, ema_trend_period, 1);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0 || ema_trend_1 <= 0.0)
      return false;

   const double stoch_1 = QM_Stoch_K(_Symbol, _Period, stoch_k_period, stoch_d_period, stoch_slowing, 1);
   const double stoch_2 = QM_Stoch_K(_Symbol, _Period, stoch_k_period, stoch_d_period, stoch_slowing, 2);
   const bool stoch_long = (stoch_2 <= stoch_lo && stoch_1 > stoch_2);
   const bool stoch_short = (stoch_2 >= stoch_hi && stoch_1 < stoch_2);

   const double smi_1 = g_smi[0];
   const double smi_2 = g_smi[1];
   const bool ha_white = (g_ha_close[0] > g_ha_open[0]);
   const bool ha_red = (g_ha_close[0] < g_ha_open[0]);

   const bool smi_long = ((smi_2 <= -smi_extreme && smi_1 > smi_2) ||
                          (smi_2 <= 0.0 && smi_1 > 0.0));
   const bool smi_short = ((smi_2 >= smi_extreme && smi_1 < smi_2) ||
                           (smi_2 >= 0.0 && smi_1 < 0.0));

   const bool ema_cross_long = (ema_fast_1 > ema_slow_1 && ema_fast_2 <= ema_slow_2);
   const bool ema_cross_short = (ema_fast_1 < ema_slow_1 && ema_fast_2 >= ema_slow_2);

   if(smi_long && ema_cross_long && ha_white && stoch_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = Strategy_StopPrice(QM_BUY, entry, atr_value);
      const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "smi_stoch_ha_long";
      return true;
     }

   if(smi_short && ema_cross_short && ha_red && stoch_short)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = Strategy_StopPrice(QM_SELL, entry, atr_value);
      const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "smi_stoch_ha_short";
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      QM_TM_MoveToBreakEven(ticket, breakeven_trigger_pips, breakeven_buffer_pips);
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0 || g_state_bars < 2)
      return false;

   const double ema_exit = QM_EMA(_Symbol, _Period, ema_exit_period, 1);
   if(ema_exit <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double smi_1 = g_smi[0];

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long type = PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
        {
         if(smi_1 >= smi_extreme)
            return true;
         if(bid > 0.0 && bid >= ema_exit)
            return true;
        }
      if(type == POSITION_TYPE_SELL)
        {
         if(smi_1 <= -smi_extreme)
            return true;
         if(ask > 0.0 && ask <= ema_exit)
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
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   g_state_bars = 0;
   g_ha_seeded = false;
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   Strategy_AdvanceState_OnNewBar();
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
