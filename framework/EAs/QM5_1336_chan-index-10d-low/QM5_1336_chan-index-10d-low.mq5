#property strict
#property version   "5.0"
#property description "QM5_1336 Chan Index 10-Day Low Long"
// rework v2 2026-06-16 — set catastrophic ATR stop on entry (req.sl was 0.0, so the
// fixed-risk sizer returned lots=0 -> every entry REJECTED_RISK -> 0 trades). Card
// specifies a 2.5*ATR(14,D1) catastrophic stop; the EA never set it. Now applied.

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1336;
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
input int    strategy_low_lookback       = 10;
input int    strategy_exit_sma_period    = 5;
input int    strategy_time_stop_days     = 5;
input int    strategy_max_spread_points  = 0;
input int    strategy_atr_period         = 14;
input double strategy_atr_stop_mult      = 2.5;

datetime g_entry_day = 0;

bool AtNew10dLow()
{
   double closes[];
   ArraySetAsSeries(closes, true);
   const int bars = strategy_low_lookback + 2;
   if (CopyClose(_Symbol, PERIOD_D1, 1, bars, closes) != bars) return false;
   if (closes[0] <= 0.0) return false;
   for (int i = 1; i <= strategy_low_lookback; ++i)
   {
      if (closes[i] <= 0.0 || closes[0] > closes[i]) return false;
   }
   return true;
}

double SMA5Close()
{
   const int handle = iMA(_Symbol, PERIOD_D1, strategy_exit_sma_period, 0, MODE_SMA, PRICE_CLOSE);
   if (handle == INVALID_HANDLE) return 0.0;
   double val[1];
   const int copied = CopyBuffer(handle, 0, 1, 1, val);
   IndicatorRelease(handle);
   return (copied == 1) ? val[0] : 0.0;
}

bool HasPosition()
{
   const int magic = QM_FrameworkMagic();
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong t = PositionGetTicket(i);
      if (t == 0 || !PositionSelectByTicket(t)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
   }
   return false;
}

void ClosePosition(const QM_ExitReason reason)
{
   const int magic = QM_FrameworkMagic();
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong t = PositionGetTicket(i);
      if (t == 0 || !PositionSelectByTicket(t)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      QM_TM_ClosePosition(t, reason);
   }
}

bool Strategy_NoTradeFilter()
{
   if (strategy_max_spread_points > 0)
   {
      const int sp = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if (sp > strategy_max_spread_points) return true;
   }
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "10D_LOW";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if (HasPosition()) return false;
   if (!AtNew10dLow()) return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if (entry <= 0.0) return false;

   // rework v2 2026-06-16: catastrophic stop = 2.5*ATR(14,D1) below entry (card spec).
   // Required so the fixed-risk sizer can compute lots; without a stop, lots=0 -> reject.
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if (atr <= 0.0) return false;
   const double sl = entry - strategy_atr_stop_mult * atr;
   if (sl <= 0.0 || sl >= entry) return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "CHAN_10D_LOW";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_entry_day = iTime(_Symbol, PERIOD_D1, 0);
   return true;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   if (!HasPosition()) return false;

   const double close0 = iClose(_Symbol, PERIOD_D1, 1);
   if (close0 <= 0.0) return false;

   const double sma5 = SMA5Close();
   if (sma5 > 0.0 && close0 >= sma5)
   {
      ClosePosition(QM_EXIT_STRATEGY);
      return false;
   }

   if (g_entry_day > 0)
   {
      const int held = (int)((iTime(_Symbol, PERIOD_D1, 0) - g_entry_day) / 86400);
      if (held >= strategy_time_stop_days)
      {
         ClosePosition(QM_EXIT_TIME_STOP);
         return false;
      }
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

int OnInit()
{
   if (!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                         qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                         30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                         qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1336\",\"strategy\":\"chan-index-10d-low\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason)); QM_FrameworkShutdown(); }

void OnTick()
{
   if (!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if (Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if (qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if (!news_allows) return;
   if (QM_FrameworkHandleFridayClose()) return;
   if (Strategy_NoTradeFilter()) return;
   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();
   if (!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if (Strategy_EntrySignal(req)) { ulong t = 0; QM_TM_OpenPosition(req, t); }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result) { QM_FrameworkOnTradeTransaction(trans, request, result); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
