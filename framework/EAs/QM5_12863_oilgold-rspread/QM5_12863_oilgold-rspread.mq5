#property strict
#property version   "5.0"
#property description "QM5_12863 XTI XAU Return Spread Reversion"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

// =============================================================================
// QM5_12863 - XTI/XAU Return-Spread Reversion
// -----------------------------------------------------------------------------
// D1 two-leg oil/gold basket:
//   rspread = log(XTI[t] / XTI[t-L]) - beta * log(XAU[t] / XAU[t-L])
//   z > entry: short return spread = sell oil, buy gold
//   z < -entry: long return spread = buy oil, sell gold
// The EA runs from the XTIUSD.DWX host chart and trades both registered legs
// through QM_BasketOrder. Runtime uses MT5 OHLC only; no external feed.
//
// OnTick order (2026-07-02 binding rule):
//   kill-switch → Friday-close → NoTradeFilter → [nb latch + state refresh]
//   → ManageOpenPosition → ExitSignal → news gate → entry-signal
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12863;
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
input int    strategy_return_lookback_d1 = 10;
input int    strategy_z_lookback_d1      = 120;
input double strategy_beta               = 1.0;
input double strategy_entry_z            = 2.0;
input double strategy_exit_z             = 0.4;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 3.0;
input int    strategy_max_hold_days      = 20;
input int    strategy_xti_max_spread_pts = 1000;
input int    strategy_xau_max_spread_pts = 500;
input int    strategy_deviation_points   = 20;

string   g_leg_xti = "XTIUSD.DWX";
string   g_leg_xau = "XAUUSD.DWX";
double   g_spread_z    = 0.0;
double   g_spread_mean = 0.0;
double   g_spread_sd   = 0.0;
bool     g_state_ready = false;
datetime g_pair_entry_time = 0;

int Strategy_SlotForSymbol(const string symbol)
  {
   if(symbol == g_leg_xti)
      return 0;
   if(symbol == g_leg_xau)
      return 1;
   return -1;
  }

bool Strategy_IsHostChart()
  {
   return (_Symbol == g_leg_xti && _Period == PERIOD_D1 && qm_magic_slot_offset == 0);
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   // DWX tester: spread == 0; only block a genuinely wide non-zero spread.
   const long spread_pts = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(symbol == g_leg_xti && strategy_xti_max_spread_pts > 0)
      return (spread_pts == 0 || spread_pts <= (long)strategy_xti_max_spread_pts);
   if(symbol == g_leg_xau && strategy_xau_max_spread_pts > 0)
      return (spread_pts == 0 || spread_pts <= (long)strategy_xau_max_spread_pts);
   return true;
  }

bool Strategy_IsPairPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0)
      return false;
   return ((int)PositionGetInteger(POSITION_MAGIC) == QM_MagicChecked(qm_ea_id, slot, symbol));
  }

int Strategy_OpenPairLegCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         ++count;
     }
   return count;
  }

datetime Strategy_CurrentPairEntryTime()
  {
   datetime earliest = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(!Strategy_IsPairPosition())
         continue;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && (earliest == 0 || opened < earliest))
         earliest = opened;
     }
   return earliest;
  }

void Strategy_ClosePair(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsPairPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
   g_pair_entry_time = 0;
  }

bool Strategy_RefreshSpreadState()
  {
   // Called once per new D1 bar from OnTick after QM_IsNewBar().
   // CopyClose over history required for rolling z-score. perf-allowed: single call per bar.
   g_state_ready = false;
   const int return_lookback = MathMax(5, strategy_return_lookback_d1);
   const int z_lookback      = MathMax(40, strategy_z_lookback_d1);
   const int history_needed  = z_lookback + return_lookback + 1;

   double xti[];
   double xau[];
   ArraySetAsSeries(xti, true);
   ArraySetAsSeries(xau, true);
   if(CopyClose(g_leg_xti, PERIOD_D1, 1, history_needed, xti) != history_needed) // perf-allowed
      return false;
   if(CopyClose(g_leg_xau, PERIOD_D1, 1, history_needed, xau) != history_needed) // perf-allowed
      return false;

   double spreads[];
   ArrayResize(spreads, z_lookback);
   double sum = 0.0;
   for(int i = 0; i < z_lookback; ++i)
     {
      const int past_idx = i + return_lookback;
      if(xti[i] <= 0.0 || xau[i] <= 0.0 || xti[past_idx] <= 0.0 || xau[past_idx] <= 0.0)
         return false;
      const double xti_ret = MathLog(xti[i] / xti[past_idx]);
      const double xau_ret = MathLog(xau[i] / xau[past_idx]);
      spreads[i] = xti_ret - strategy_beta * xau_ret;
      if(!MathIsValidNumber(spreads[i]))
         return false;
      sum += spreads[i];
     }

   g_spread_mean = sum / (double)z_lookback;
   double var_sum = 0.0;
   for(int i = 0; i < z_lookback; ++i)
     {
      const double d = spreads[i] - g_spread_mean;
      var_sum += d * d;
     }
   g_spread_sd = MathSqrt(var_sum / (double)MathMax(1, z_lookback - 1));
   if(g_spread_sd <= 0.0 || !MathIsValidNumber(g_spread_sd))
      return false;

   g_spread_z = (spreads[0] - g_spread_mean) / g_spread_sd;
   g_state_ready = MathIsValidNumber(g_spread_z);
   return g_state_ready;
  }

double Strategy_LotsForLeg(const string symbol, const double risk_weight, const double risk_weight_sum)
  {
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(atr <= 0.0 || point <= 0.0 || risk_weight <= 0.0 || risk_weight_sum <= 0.0)
      return 0.0;

   const double sl_points = strategy_atr_sl_mult * atr / point;
   double lots = QM_LotsForRisk(symbol, sl_points) * risk_weight / risk_weight_sum;
   const double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   const double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   const double step    = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lots <= 0.0 || min_lot <= 0.0 || max_lot <= 0.0 || step <= 0.0)
      return 0.0;

   lots = MathFloor(lots / step) * step;
   if(lots < min_lot)
      return 0.0;
   return MathMin(max_lot, NormalizeDouble(lots, 8));
  }

bool Strategy_OpenLeg(const string symbol,
                      const QM_OrderType type,
                      const double risk_weight,
                      const double risk_weight_sum,
                      const string reason)
  {
   const int slot = Strategy_SlotForSymbol(symbol);
   if(slot < 0 || !Strategy_SpreadAllowed(symbol))
      return false;

   const double entry = QM_OrderTypeIsBuy(type) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double atr   = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const int    digits    = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   const double stop_dist = strategy_atr_sl_mult * atr;
   const double lots      = Strategy_LotsForLeg(symbol, risk_weight, risk_weight_sum);
   if(lots <= 0.0)
      return false;

   QM_BasketOrderRequest req;
   req.symbol = symbol;
   req.type   = type;
   req.price  = 0.0;
   req.sl = QM_OrderTypeIsBuy(type) ? NormalizeDouble(entry - stop_dist, digits)
                                    : NormalizeDouble(entry + stop_dist, digits);
   req.tp               = 0.0;
   req.lots             = lots;
   req.reason           = reason;
   req.symbol_slot      = slot;
   req.expiration_seconds = 0;

   ulong ticket = 0;
   return QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, strategy_deviation_points, req, ticket);
  }

bool Strategy_OpenPair(const int spread_direction)
  {
   if(spread_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;
   if(!Strategy_SpreadAllowed(g_leg_xti) || !Strategy_SpreadAllowed(g_leg_xau))
      return false;

   const double xti_weight = 1.0;
   const double xau_weight = MathMax(0.1, MathAbs(strategy_beta));
   const double weight_sum = xti_weight + xau_weight;
   const bool long_spread  = (spread_direction > 0);
   const QM_OrderType xti_type = long_spread ? QM_BUY  : QM_SELL;
   const QM_OrderType xau_type = long_spread ? QM_SELL : QM_BUY;
   const string reason = long_spread ? "QM5_12863_LONG_XTI_XAU_RSPREAD"
                                     : "QM5_12863_SHORT_XTI_XAU_RSPREAD";

   bool xti_ok = Strategy_OpenLeg(g_leg_xti, xti_type, xti_weight, weight_sum, reason);
   bool xau_ok = Strategy_OpenLeg(g_leg_xau, xau_type, xau_weight, weight_sum, reason);
   if(xti_ok && xau_ok)
     {
      g_pair_entry_time = TimeCurrent();
      return true;
     }
   Strategy_ClosePair(QM_EXIT_STRATEGY);
   return false;
  }

// ---- Strategy hooks ----------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart())
      return true;
   if(strategy_return_lookback_d1 < 5 || strategy_z_lookback_d1 < 40 || strategy_beta <= 0.0)
      return true;
   if(strategy_entry_z <= 0.0 || strategy_exit_z < 0.0)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Uses g_spread_z refreshed earlier this bar in OnTick. Never refreshes itself.
   req.type               = QM_BUY;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "QM5_12863_RSPREAD_HOST";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!g_state_ready)
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;

   if(g_spread_z > strategy_entry_z)
      Strategy_OpenPair(-1);  // short XTI, long XAU
   else if(g_spread_z < -strategy_entry_z)
      Strategy_OpenPair(1);   // long XTI, short XAU

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // v1: hard ATR stops set at entry; no trailing or BE in v1.
  }

bool Strategy_ExitSignal()
  {
   const int open_legs = Strategy_OpenPairLegCount();
   if(open_legs <= 0)
      return false;

   // Pair-level Friday close — both legs must close together.
   if(qm_friday_close_enabled && QM_FrameworkFridayCloseNow())
     {
      Strategy_ClosePair(QM_EXIT_FRIDAY_CLOSE);
      return false;
     }

   // Orphan-leg cleanup: if one leg closed (via SL or broker), flatten the other.
   if(open_legs != 2)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }

   // Z-score mean-reversion exit (uses state cached this bar in OnTick).
   if(g_state_ready && MathAbs(g_spread_z) < strategy_exit_z)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }

   // Max-hold time stop.
   datetime entry_time = g_pair_entry_time;
   if(entry_time <= 0)
      entry_time = Strategy_CurrentPairEntryTime();
   if(entry_time > 0)
     {
      const long hold_seconds = (long)strategy_max_hold_days * 86400;
      if((long)(TimeCurrent() - entry_time) >= hold_seconds)
         Strategy_ClosePair(QM_EXIT_STRATEGY);
     }
   return false;
  }

// Entry-gate news check for both basket legs. No Friday-close logic here.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(g_leg_xti, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
      if(!QM_NewsAllowsTrade2(g_leg_xau, broker_time, qm_news_temporal, qm_news_compliance))
         return true;
     }
   else
     {
      if(!QM_NewsAllowsTrade(g_leg_xti, broker_time, qm_news_mode_legacy))
         return true;
      if(!QM_NewsAllowsTrade(g_leg_xau, broker_time, qm_news_mode_legacy))
         return true;
     }
   return false;
  }

// ---- Framework wiring --------------------------------------------------------

int OnInit()
  {
   SymbolSelect(g_leg_xti, true);
   SymbolSelect(g_leg_xau, true);

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

   string basket_symbols[2] = {g_leg_xti, g_leg_xau};
   QM_SymbolGuardInit(basket_symbols);
   QM_BasketWarmupHistory(basket_symbols,
                          PERIOD_D1,
                          MathMax(220, strategy_z_lookback_d1 + strategy_return_lookback_d1
                                  + strategy_atr_period_d1 + 10));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12863\",\"ea\":\"oilgold-rspread\"}");
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

   // Standard framework Friday-close guard (position management still runs below).
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Latch new-bar flag once; refresh spread state on bar roll.
   // QM_IsNewBar is single-consume — one call, latched for reuse below.
   const bool nb = QM_IsNewBar();
   if(nb)
     {
      QM_EquityStreamOnNewBar();
      Strategy_RefreshSpreadState();
     }

   // Position management and exit run every tick regardless of news.
   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

   // News gate — guards ENTRY ONLY; management/exit ran above.
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
     {
      if(!QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance))
         return;
     }
   else
     {
      if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy))
         return;
     }

   if(!nb)
      return;

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
