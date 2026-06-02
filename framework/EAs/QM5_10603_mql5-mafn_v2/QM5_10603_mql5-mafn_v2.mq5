#property strict
#property version   "5.0"
#property description "QM5_10603_v2 MQL5 MovingAverage_FN direction flip"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10603;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_H4;
input int             strategy_filter_period     = 44;
input int             strategy_smooth_period     = 12;
input int             strategy_calc_bars         = 180;
input int             strategy_atr_period        = 14;
input double          strategy_atr_sl_mult       = 2.5;
input int             strategy_max_hold_bars     = 16;
input int             strategy_max_spread_points = 0;

bool Strategy_NoTradeFilter()
  {
   if(strategy_signal_tf != (ENUM_TIMEFRAMES)_Period ||
      strategy_filter_period < 4 || strategy_smooth_period < 2 ||
      strategy_calc_bars < strategy_filter_period + strategy_smooth_period + 3 ||
      strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_max_hold_bars <= 0 || strategy_max_spread_points < 0)
      return true;
   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points) return true;
     }
   return false;
  }

bool Strategy_ReadOurPosition(ENUM_POSITION_TYPE &pos_type, ulong &ticket)
  {
   pos_type = POSITION_TYPE_BUY; ticket = 0;
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

bool Strategy_MAFNSignal(int &signal)
  {
   signal = 0;
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, strategy_calc_bars, rates);
   if(copied < strategy_filter_period + strategy_smooth_period + 3) return false;
   const double alpha_filter = 2.0 / ((double)strategy_filter_period + 1.0);
   const double alpha_smooth = 2.0 / ((double)strategy_smooth_period + 1.0);
   double filter = 0.0; double smooth = 0.0;
   double latest = 0.0; double prev = 0.0; double prior = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      const double price = rates[i].close;
      if(price <= 0.0) return false;
      if(i == 0) { filter = price; smooth = price; }
      else { filter = filter + alpha_filter * (price - filter); smooth = smooth + alpha_smooth * (filter - smooth); }
      prior = prev; prev = latest; latest = smooth;
     }
   if(prev <= prior && latest > prev) signal = 1;
   else if(prev >= prior && latest < prev) signal = -1;
   return true;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY; req.price = 0.0; req.sl = 0.0; req.tp = 0.0;
   req.reason = ""; req.symbol_slot = qm_magic_slot_offset; req.expiration_seconds = 0;
   int signal = 0;
   if(!Strategy_MAFNSignal(signal) || signal == 0) return false;
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   ulong pos_ticket = 0;
   if(Strategy_ReadOurPosition(pos_type, pos_ticket))
     {
      if((signal > 0 && pos_type == POSITION_TYPE_BUY) || (signal < 0 && pos_type == POSITION_TYPE_SELL))
         return false;
      if(!QM_TM_ClosePosition(pos_ticket, QM_EXIT_OPPOSITE_SIGNAL)) return false;
     }
   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0) return false;
   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0) return false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0) return false;
   if(QM_LotsForRisk(_Symbol, MathAbs(entry - sl) / point) <= 0.0) return false;
   req.type = side; req.price = 0.0; req.sl = sl; req.tp = 0.0;
   req.reason = (signal > 0) ? "MAFN_DIRECTION_FLIP_UP" : "MAFN_DIRECTION_FLIP_DOWN";
   req.symbol_slot = qm_magic_slot_offset;
   return true;
  }

void Strategy_ManageOpenPosition() { }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0) return false;
   const int hold_seconds = PeriodSeconds(strategy_signal_tf) * strategy_max_hold_bars;
   if(hold_seconds <= 0) return false;
   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now >= opened + hold_seconds) return true;
     }
   return false;
  }

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
