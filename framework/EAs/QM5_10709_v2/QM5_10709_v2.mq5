#property strict
#property version   "5.0"
#property description "QM5_10709 tv-orb-multitp _v2"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica Strategy Card: QM5_10709_v2
// Logic: Opening Range Breakout (ORB) with multi-TP.
// Fixes: Added to magic resolver, increased news stale tolerance.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10709;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 1.0;
input double RISK_FIXED                 = 0.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 8760;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_or_minutes         = 30;
input int    strategy_session_start_hour = 9;
input int    strategy_session_start_min  = 0;
input int    strategy_session_end_hour   = 17;
input int    strategy_session_end_min    = 30;
input double strategy_min_width_pct      = 0.15;
input double strategy_max_width_pct      = 1.25;
input int    strategy_stop_mode          = 0; // 0=opposite, 1=midpoint
input double strategy_tp1_r              = 1.0;
input double strategy_tp2_r              = 2.0;

// Internal state
double g_or_high = 0.0;
double g_or_low = 0.0;
bool   g_or_locked = false;
bool   g_long_taken = false;
bool   g_short_taken = false;
datetime g_last_session_start = 0;

// -----------------------------------------------------------------------------
// Helper logic
// -----------------------------------------------------------------------------

bool IsInSession(datetime t, int start_h, int start_m, int end_h, int end_m)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   int m = dt.hour * 60 + dt.min;
   int s = start_h * 60 + start_m;
   int e = end_h * 60 + end_m;
   if(s <= e) return (m >= s && m < e);
   return (m >= s || m < e);
  }

void UpdateOR()
  {
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   datetime session_start = now - (dt.hour * 3600 + dt.min * 60 + dt.sec) + strategy_session_start_hour * 3600 + strategy_session_start_min * 60;
   if(session_start > now) session_start -= 86400;

   if(session_start != g_last_session_start)
     {
      g_last_session_start = session_start;
      g_or_high = 0.0;
      g_or_low = 0.0;
      g_or_locked = false;
      g_long_taken = false;
      g_short_taken = false;
     }

   if(g_or_locked) return;

   if(now >= session_start && now < session_start + strategy_or_minutes * 60)
     {
      double h = iHigh(_Symbol, PERIOD_CURRENT, 0);
      double l = iLow(_Symbol, PERIOD_CURRENT, 0);
      if(g_or_high == 0.0 || h > g_or_high) g_or_high = h;
      if(g_or_low == 0.0 || l < g_or_low) g_or_low = l;
     }
   else if(now >= session_start + strategy_or_minutes * 60)
     {
      if(g_or_high > 0 && g_or_low > 0) g_or_locked = true;
     }
  }

bool HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
        {
         if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
        }
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Framework Hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   UpdateOR();
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_or_locked || HasOurPosition()) return false;
   
   datetime now = TimeCurrent();
   if(!IsInSession(now, strategy_session_start_hour, strategy_session_start_min, strategy_session_end_hour, strategy_session_end_min)) return false;

   double width_pct = 100.0 * (g_or_high - g_or_low) / g_or_low;
   if(width_pct < strategy_min_width_pct || width_pct > strategy_max_width_pct) return false;

   double close_1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double close_2 = iClose(_Symbol, PERIOD_CURRENT, 2);

   int signal = 0;
   if(!g_long_taken && close_2 <= g_or_high && close_1 > g_or_high) signal = 1;
   else if(!g_short_taken && close_2 >= g_or_low && close_1 < g_or_low) signal = -1;

   if(signal == 0) return false;

   req.type = (signal > 0) ? QM_BUY : QM_SELL;
   double entry = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(strategy_stop_mode == 0) req.sl = (signal > 0) ? g_or_low : g_or_high;
   else req.sl = (g_or_high + g_or_low) / 2.0;

   if(req.sl <= 0.0 || MathAbs(entry - req.sl) <= 0.0) return false;

   req.reason = (signal > 0) ? "ORB_LONG" : "ORB_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   if(signal > 0) g_long_taken = true; else g_short_taken = true;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == magic)
        {
         ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl_price = PositionGetDouble(POSITION_SL);
         double current_lots = PositionGetDouble(POSITION_VOLUME);
         
         double risk = MathAbs(open_price - sl_price);
         if(risk <= 0.0) continue;

         double price = (ptype == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profit_r = (ptype == POSITION_TYPE_BUY) ? (price - open_price) / risk : (open_price - price) / risk;

         // Partial close at TP1 (50%)
         if(profit_r >= strategy_tp1_r && current_lots > 0.01)
           {
            // Simple heuristic for "haven't closed 50% yet": 
            // if volume is close to initial full risk sizing (1000 fixed / risk points).
            // Actually, we can check if we already did it by storing state or checking deal history.
            // For simplicity in _v2: check if current volume > 55% of what we'd expect for 1R risk.
            // Better: just use a flag or a custom comment.
            string comment = PositionGetString(POSITION_COMMENT);
            if(StringFind(comment, "TP1_DONE") < 0)
              {
               if(QM_TM_PartialClose(ticket, current_lots * 0.5, QM_EXIT_STRATEGY))
                  return; // Position refreshed, stop for this tick
              }
           }
           
         // Full close at TP2 (2R)
         if(profit_r >= strategy_tp2_r)
           {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
           }
        }
     }
  }

bool Strategy_ExitSignal()
  {
   datetime now = TimeCurrent();
   if(!IsInSession(now, strategy_session_start_hour, strategy_session_start_min, strategy_session_end_hour, strategy_session_end_min)) return true;
   return false;
  }

bool Strategy_NewsFilterHook(const datetime t) { return false; }

// -----------------------------------------------------------------------------
// Framework Wiring
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker, 30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed, qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE) news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows || QM_FrameworkHandleFridayClose() || Strategy_NoTradeFilter()) return;
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == magic) QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res) { QM_FrameworkOnTradeTransaction(t, r, res); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
