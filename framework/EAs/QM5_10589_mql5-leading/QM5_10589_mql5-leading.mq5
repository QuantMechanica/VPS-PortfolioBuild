#property strict
#property version   "5.0"
#property description "QM5_10589 MQL5 Leading Indicator Line Crossover"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10589;
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
input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_H4;
input int    strategy_calc_bars         = 160;
input double strategy_leading_alpha1    = 0.25;
input double strategy_leading_alpha2    = 0.33;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input double strategy_reward_r_multiple = 1.5;
input int    strategy_max_spread_points = 0;

bool Strategy_ReadOurPosition(ENUM_POSITION_TYPE &pos_type, ulong &ticket)
  {
   pos_type = POSITION_TYPE_BUY;
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = t;
      return true;
     }
   return false;
  }

bool Strategy_LeadingCrossSignal(int &signal)
  {
   signal = 0;
   if(strategy_calc_bars < 8 || strategy_leading_alpha1 <= 0.0 ||
      strategy_leading_alpha2 <= 0.0 || strategy_leading_alpha2 > 1.0)
      return false;
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, strategy_calc_bars, rates);
   if(copied < 8) return false;
   double net_lead[];
   double ema[];
   ArrayResize(net_lead, copied);
   ArrayResize(ema, copied);
   ArrayInitialize(net_lead, 0.0);
   ArrayInitialize(ema, 0.0);
   double lead = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      const double price = (rates[i].high + rates[i].low) / 2.0;
      if(i <= 2) { lead = price; net_lead[i] = lead; ema[i] = lead; continue; }
      const double prev_price = (rates[i - 1].high + rates[i - 1].low) / 2.0;
      lead = 2.0 * price + (strategy_leading_alpha1 - 2.0) * prev_price
             + (1.0 - strategy_leading_alpha1) * lead;
      net_lead[i] = strategy_leading_alpha2 * lead + (1.0 - strategy_leading_alpha2) * net_lead[i - 1];
      ema[i] = 0.5 * price + 0.5 * ema[i - 1];
     }
   const int now = copied - 1;
   const int prev = copied - 2;
   if(net_lead[prev] <= ema[prev] && net_lead[now] > ema[now]) signal = 1;
   else if(net_lead[prev] >= ema[prev] && net_lead[now] < ema[now]) signal = -1;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points) return true;
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY; req.price = 0.0; req.sl = 0.0; req.tp = 0.0;
   req.reason = ""; req.symbol_slot = qm_magic_slot_offset; req.expiration_seconds = 0;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_reward_r_multiple <= 0.0)
      return false;
   int signal = 0;
   if(!Strategy_LeadingCrossSignal(signal) || signal == 0) return false;
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   ulong pos_ticket = 0;
   if(Strategy_ReadOurPosition(pos_type, pos_ticket))
     {
      if((signal > 0 && pos_type == POSITION_TYPE_BUY) || (signal < 0 && pos_type == POSITION_TYPE_SELL))
         return false;
      if(!QM_TM_ClosePosition(pos_ticket, QM_EXIT_STRATEGY)) return false;
     }
   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0) return false;
   const double sl_distance = atr * strategy_atr_sl_mult;
   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   req.tp = QM_StopRulesTakeFromDistance(_Symbol, side, entry, sl_distance * strategy_reward_r_multiple);
   req.reason = (signal > 0) ? "LEADING_BULL_CROSS" : "LEADING_BEAR_CROSS";
   req.symbol_slot = qm_magic_slot_offset;
   return (req.sl > 0.0 && req.tp > 0.0);
  }

void Strategy_ManageOpenPosition() { }

bool Strategy_ExitSignal() { return false; }

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
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
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }
   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()        { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  { QM_FrameworkOnTradeTransaction(trans, request, result); }
double OnTester()     { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
