#property strict
#property version   "5.0"
#property description "QM5_9132_v2 Alpha Architect Currency Economic Momentum — V2 parameter-injection rebuild"

#include <QM/QM_Common.mqh>

// V2 note: Replaces CSV-file macro signal with direct parameter inputs per SPEC.
// strategy_macro_signal: +1 = long (top tercile), -1 = short (bottom tercile), 0 = neutral
// strategy_macro_approved: set true when point-in-time macro data is confirmed
// For production use, generate a setfile per symbol with the monthly signal value.

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9132;
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
input int    strategy_macro_signal      = 0;     // +1=long, -1=short, 0=neutral/no trade
input bool   strategy_macro_approved    = false; // must be true before entries fire
input int    strategy_rebalance_day     = 3;     // calendar day of monthly rebalance
input int    strategy_atr_period        = 20;    // ATR period for stop loss
input double strategy_atr_sl_mult       = 2.5;   // ATR stop multiplier
input double strategy_tp_rr             = 0.0;   // R-multiple TP; 0 = no fixed TP
input int    strategy_max_spread_points = 35;    // max spread in points

int DayOfMonth(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day;
  }

bool HasOpenPositionForCurrentMagic(ENUM_POSITION_TYPE &ptype)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!strategy_macro_approved || strategy_macro_signal == 0) return true;
   if(strategy_rebalance_day > 1 && DayOfMonth(TimeCurrent()) < strategy_rebalance_day) return true;
   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread < 0 || spread > strategy_max_spread_points) return true;
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY; req.price = 0.0; req.sl = 0.0; req.tp = 0.0;
   req.reason = ""; req.symbol_slot = qm_magic_slot_offset; req.expiration_seconds = 0;

   if(!strategy_macro_approved || strategy_macro_signal == 0) return false;

   ENUM_POSITION_TYPE ptype;
   if(HasOpenPositionForCurrentMagic(ptype)) return false;

   req.type = (strategy_macro_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (req.type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0) return false;

   req.tp = (strategy_tp_rr > 0.0) ? QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_tp_rr) : 0.0;
   req.reason = (strategy_macro_signal > 0) ? "ECON_MOM_TOP_TERCILE" : "ECON_MOM_BOTTOM_TERCILE";
   return true;
  }

void Strategy_ManageOpenPosition() { }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!HasOpenPositionForCurrentMagic(ptype)) return false;
   if(!strategy_macro_approved || strategy_macro_signal == 0) return true;
   if(ptype == POSITION_TYPE_BUY && strategy_macro_signal < 0) return true;
   if(ptype == POSITION_TYPE_SELL && strategy_macro_signal > 0) return true;
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED,
                        PORTFOLIO_WEIGHT, qm_news_mode_legacy, qm_friday_close_enabled,
                        qm_friday_close_hour_broker, 30, 30, qm_news_stale_max_hours,
                        qm_news_min_impact, qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
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
   if(Strategy_EntrySignal(req)) { ulong t = 0; QM_TM_OpenPosition(req, t); }
  }

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  { QM_FrameworkOnTradeTransaction(trans, request, result); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
