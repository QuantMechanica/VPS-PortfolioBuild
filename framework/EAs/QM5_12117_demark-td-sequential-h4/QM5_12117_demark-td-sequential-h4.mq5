#property strict
#property version   "5.0"
#property description "QM5_12117 demark-td-sequential-h4"
// rework v2 2026-06-16 — enter on completed TD-9 setup instead of rare TD-13 countdown; setup-streak break no longer wipes signal -> fixes 0-trade MIN_TRADES fail

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12117;
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
input int    sma_trend_period       = 50;
input double trend_filter_atr       = 1.5;
input double tdst_buffer_atr        = 0.3;
input double tp1_atr_mult           = 1.5;
input double tp2_atr_mult           = 3.0;
input int    time_stop_bars         = 24;
input double atr_sl_mult            = 1.0;
input int    max_spread_points      = 25;

// ----------------------------------------------------------------------
// Helper functions
// ----------------------------------------------------------------------

// ----------------------------------------------------------------------
// TD Sequential
// ----------------------------------------------------------------------
struct TDState
{
   int setup_count;       // 0..9
   int setup_direction;   // 1=buy, -1=sell, 0=none
   int countdown_count;   // 0..13
   int countdown_direction;
   double tdst_level;     // TDST support/resistance
   int last_setup_start;  // bar index when last setup began
   bool entry_consumed;
};
TDState g_td;

void ResetTD()
{
   g_td.setup_count = 0;
   g_td.setup_direction = 0;
   g_td.countdown_count = 0;
   g_td.countdown_direction = 0;
   g_td.tdst_level = 0;
   g_td.last_setup_start = 0;
   g_td.entry_consumed = false;
}

bool HasPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
   }
   return false;
}

void CloseAll(const QM_ExitReason reason)
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      QM_TM_ClosePosition(ticket, reason);
   }
}


// ----------------------------------------------------------------------
// Strategy hooks
// ----------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   if(max_spread_points > 0)
   {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > max_spread_points) return true;
   }
   return false;

  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(g_td.entry_consumed) return false;

   const double close0 = iClose(_Symbol, PERIOD_H4, 0); // current forming
   const double close1 = iClose(_Symbol, PERIOD_H4, 1);
   const double close4 = iClose(_Symbol, PERIOD_H4, 4); // 4 bars ago
   const double close5 = iClose(_Symbol, PERIOD_H4, 5);

   if(close1 <= 0 || close4 <= 0) { ResetTD(); return false; }

   // TD Setup detection (BUY: close[i] < close[i-4] for i=0..8)
   // SELL: close[i] > close[i-4] for i=0..8
   bool buy_setup_bar = (close1 < iClose(_Symbol, PERIOD_H4, 5));
   bool sell_setup_bar = (close1 > iClose(_Symbol, PERIOD_H4, 5));

   if(g_td.setup_count == 0)
   {
      if(buy_setup_bar) { g_td.setup_direction = 1; g_td.setup_count = 1; }
      else if(sell_setup_bar) { g_td.setup_direction = -1; g_td.setup_count = 1; }
   }
   else if(g_td.setup_direction == 1 && buy_setup_bar) g_td.setup_count++;
   else if(g_td.setup_direction == -1 && sell_setup_bar) g_td.setup_count++;
   else { ResetTD(); return false; }

   if(g_td.setup_count < 9) return false; // Setup not complete

   // rework v2 2026-06-16: A completed TD-9 setup IS the entry signal (the
   // standard DeMark trade, several times/month on H4). The previous code
   // required a full TD-13 countdown, but the setup state-machine resets the
   // whole struct (incl. countdown) the first bar the setup streak broke, so
   // 13 was effectively unreachable -> 0 trades. We fire on the 9 directly.
   const int setup_dir = g_td.setup_direction;

   // TDST level over the 9-bar setup window (extreme against the setup).
   double tdst = 0.0;
   if(setup_dir == 1)
   {
      tdst = DBL_MAX;
      for(int b = 0; b < 9; b++)
      {
         double l = iLow(_Symbol, PERIOD_H4, b + 1);
         if(l < tdst) tdst = l;
      }
   }
   else
   {
      tdst = 0.0;
      for(int b = 0; b < 9; b++)
      {
         double h = iHigh(_Symbol, PERIOD_H4, b + 1);
         if(h > tdst) tdst = h;
      }
   }
   g_td.tdst_level = tdst;

   // Confirmation on the just-closed bar (mean-reversion snap on bar 1).
   const bool bull_conf = (close1 > iOpen(_Symbol, PERIOD_H4, 1)); // closed bar bullish
   const bool bear_conf = (close1 < iOpen(_Symbol, PERIOD_H4, 1)); // closed bar bearish

   // Trend filter: close > SMA(50) - 1.5*ATR for buy
   const double sma50 = QM_SMA(_Symbol, PERIOD_H4, sma_trend_period, 1);
   const double atr14 = QM_ATR(_Symbol, PERIOD_H4, 14, 1);
   if(sma50 <= 0 || atr14 <= 0) { ResetTD(); return false; }

   bool long_signal = false, short_signal = false;
   if(setup_dir == 1 && bull_conf && close1 > sma50 - trend_filter_atr * atr14)
      long_signal = true;
   else if(setup_dir == -1 && bear_conf && close1 < sma50 + trend_filter_atr * atr14)
      short_signal = true;
   else
   { ResetTD(); return false; }

   if(HasPosition()) { ResetTD(); return false; }

   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double sl;
   if(long_signal) sl = g_td.tdst_level - tdst_buffer_atr * atr14;
   else sl = g_td.tdst_level + tdst_buffer_atr * atr14;

   double sl_dist = MathAbs(entry - sl);
   if(sl_dist < atr14 * atr_sl_mult)
   {
      if(long_signal) sl = entry - atr14 * atr_sl_mult;
      else sl = entry + atr14 * atr_sl_mult;
      sl_dist = MathAbs(entry - sl);
   }

   // TP1 and TP2 are handled via fixed TP
   const double tp = long_signal ? entry + sl_dist * tp1_atr_mult : entry - sl_dist * tp1_atr_mult;

   // rework v2 2026-06-16: clear the whole TD struct after firing so the next
   // setup can re-arm. The old code latched entry_consumed=true forever (never
   // reset), which would have blocked every trade after the first.
   ResetTD();

   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "TDS_LONG" : "TDS_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;

  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!HasPosition()) return false;
   const int magic = QM_FrameworkMagic();
   const double close = iClose(_Symbol, PERIOD_H4, 1);
   if(close <= 0) return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // Opposite-side setup invalidates
      for(int b = 0; b < 9; b++)
      {
         const double cb = iClose(_Symbol, PERIOD_H4, b + 1);
         const double cb4 = iClose(_Symbol, PERIOD_H4, b + 5);
         if(cb <= 0 || cb4 <= 0) continue;
         if((pt == POSITION_TYPE_BUY && cb > cb4) ||
            (pt == POSITION_TYPE_SELL && cb < cb4))
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
            break;
         }
      }

      // Time stop
      const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = (int)((TimeCurrent() - entry_time) / PeriodSeconds(PERIOD_H4));
      if(bars_held >= time_stop_bars)
      {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
      }
   }
   return false;

  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ----------------------------------------------------------------------
// Framework wiring
// ----------------------------------------------------------------------
int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30,
                        qm_news_stale_max_hours, qm_news_min_impact,
                        qm_rng_seed, qm_stress_reject_probability,
                        qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12117\",\"strategy\":\"demark-td-sequential-h4\"}");
   return INIT_SUCCEEDED;
  }


void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {{
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
   Strategy_ExitSignal();
   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {{
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }}
  }}


void OnTimer() {{ QM_FrameworkOnTimer(); }}
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {{ QM_FrameworkOnTradeTransaction(trans, request, result); }}
double OnTester() {{ QM_ChartUI_Refresh(); return QM_DefaultObjective(); }}

