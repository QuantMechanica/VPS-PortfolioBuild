#property strict
#property version   "5.0"
#property description "QM5_11291 EMA tunnel WMA crossover with RSI filter"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11291
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11291;
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
input int    strategy_ema_fast_period       = 18;
input int    strategy_ema_slow_period       = 28;
input int    strategy_wma_fast_period       = 5;
input int    strategy_wma_slow_period       = 12;
input int    strategy_rsi_period            = 21;
input double strategy_rsi_midline           = 50.0;
input int    strategy_atr_period            = 14;
input double strategy_tunnel_atr_max        = 0.20;
input bool   strategy_require_wma_cross     = false;
input bool   strategy_use_atr_stop          = false;
input double strategy_atr_sl_mult           = 2.0;
input int    strategy_fixed_sl_pips         = 50;
input int    strategy_fixed_tp_pips         = 50;
input double strategy_max_spread_pips       = 20.0;

bool   g_state_valid = false;
double g_ema18_latest = 0.0;
double g_ema18_older = 0.0;
double g_ema28_latest = 0.0;
double g_ema28_older = 0.0;
double g_wma5_latest = 0.0;
double g_wma5_older = 0.0;
double g_wma12_latest = 0.0;
double g_wma12_older = 0.0;
double g_rsi_latest = 0.0;
double g_atr_latest = 0.0;

double Strategy_SpreadPips()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return DBL_MAX;
   const double pip_size = point * ((digits == 3 || digits == 5) ? 10.0 : 1.0);
   return (pip_size > 0.0) ? (ask - bid) / pip_size : DBL_MAX;
  }

void Strategy_RefreshState()
  {
   g_state_valid = false;
   g_ema18_latest = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   g_ema18_older = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   g_ema28_latest = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   g_ema28_older = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   g_wma5_latest = QM_LWMA(_Symbol, _Period, strategy_wma_fast_period, 1);
   g_wma5_older = QM_LWMA(_Symbol, _Period, strategy_wma_fast_period, 2);
   g_wma12_latest = QM_LWMA(_Symbol, _Period, strategy_wma_slow_period, 1);
   g_wma12_older = QM_LWMA(_Symbol, _Period, strategy_wma_slow_period, 2);
   g_rsi_latest = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   g_atr_latest = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);

   g_state_valid = (g_ema18_latest > 0.0 && g_ema18_older > 0.0 &&
                    g_ema28_latest > 0.0 && g_ema28_older > 0.0 &&
                    g_wma5_latest > 0.0 && g_wma5_older > 0.0 &&
                    g_wma12_latest > 0.0 && g_wma12_older > 0.0 &&
                    g_rsi_latest > 0.0 && g_atr_latest > 0.0);
  }

bool Strategy_LongEntrySignal()
  {
   if(!g_state_valid ||
      MathAbs(g_ema18_latest - g_ema28_latest) > strategy_tunnel_atr_max * g_atr_latest)
      return false;

   const bool crossed_tunnel = (g_wma5_older <= g_ema28_older &&
                                g_wma12_older <= g_ema28_older &&
                                g_wma5_latest > g_ema28_latest &&
                                g_wma12_latest > g_ema28_latest);
   const bool fast_cross = (g_wma5_older <= g_wma12_older &&
                            g_wma5_latest > g_wma12_latest);
   return (crossed_tunnel && g_rsi_latest > strategy_rsi_midline &&
           (!strategy_require_wma_cross || fast_cross));
  }

bool Strategy_ShortEntrySignal()
  {
   if(!g_state_valid ||
      MathAbs(g_ema18_latest - g_ema28_latest) > strategy_tunnel_atr_max * g_atr_latest)
      return false;

   const bool crossed_tunnel = (g_wma5_older >= g_ema18_older &&
                                g_wma12_older >= g_ema18_older &&
                                g_wma5_latest < g_ema18_latest &&
                                g_wma12_latest < g_ema18_latest);
   const bool fast_cross = (g_wma5_older >= g_wma12_older &&
                            g_wma5_latest < g_wma12_latest);
   return (crossed_tunnel && g_rsi_latest < strategy_rsi_midline &&
           (!strategy_require_wma_cross || fast_cross));
  }

bool Strategy_GetOurPosition(int &direction)
  {
   direction = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      direction = (position_type == POSITION_TYPE_BUY) ? 1 : -1;
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_H1);
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

   const bool go_long = Strategy_LongEntrySignal();
   const bool go_short = Strategy_ShortEntrySignal();
   if(go_long == go_short || Strategy_SpreadPips() > strategy_max_spread_pips)
      return false;

   req.type = go_long ? QM_BUY : QM_SELL;
   req.reason = go_long ? "TC20_TUNNEL_LONG" : "TC20_TUNNEL_SHORT";
   const double entry_price = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   if(strategy_use_atr_stop)
      req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   else
      req.sl = QM_StopFixedPips(_Symbol, req.type, entry_price, strategy_fixed_sl_pips);
   req.tp = QM_TakeFixedPips(_Symbol, req.type, entry_price, strategy_fixed_tp_pips);

   if(go_long)
      return (req.sl > 0.0 && req.sl < entry_price && req.tp > entry_price);
   return (req.sl > entry_price && req.tp > 0.0 && req.tp < entry_price);
  }

void Strategy_ManageOpenPosition()
  {
   // The approved card specifies fixed protective exits and no trailing or partial close.
  }

bool Strategy_ExitSignal()
  {
   if(!g_state_valid)
      return false;

   int position_direction = 0;
   if(!Strategy_GetOurPosition(position_direction))
      return false;

   const double older_low = MathMin(g_ema18_older, g_ema28_older);
   const double latest_low = MathMin(g_ema18_latest, g_ema28_latest);
   const double older_high = MathMax(g_ema18_older, g_ema28_older);
   const double latest_high = MathMax(g_ema18_latest, g_ema28_latest);

   if(position_direction > 0)
      return ((g_wma5_older >= older_low || g_wma12_older >= older_low) &&
              g_wma5_latest < latest_low && g_wma12_latest < latest_low);
   return ((g_wma5_older <= older_high || g_wma12_older <= older_high) &&
           g_wma5_latest > latest_high && g_wma12_latest > latest_high);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(strategy_ema_fast_period < 2 || strategy_ema_slow_period < 2 ||
      strategy_wma_fast_period < 2 || strategy_wma_slow_period < 2 ||
      strategy_rsi_period < 2 || strategy_rsi_midline <= 0.0 || strategy_rsi_midline >= 100.0 ||
      strategy_atr_period < 2 || strategy_tunnel_atr_max <= 0.0 ||
      strategy_atr_sl_mult <= 0.0 || strategy_fixed_sl_pips <= 0 ||
      strategy_fixed_tp_pips <= 0 || strategy_max_spread_pips <= 0.0)
      return INIT_PARAMETERS_INCORRECT;

   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11291_tc20-ema18-28-wma5-12-rsi21-h1\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   Strategy_RefreshState();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;

   QM_EntryRequest req;
   ZeroMemory(req);
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
