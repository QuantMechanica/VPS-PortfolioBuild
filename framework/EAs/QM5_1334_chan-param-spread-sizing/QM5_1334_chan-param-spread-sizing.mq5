#property strict
#property version   "5.0"
#property description "QM5_1334 Chan Parameterless Spread Sizing (XAUUSD/XAGUSD)"

#include <QM/QM_Common.mqh>
#include <QM/QM_BasketOrder.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1334;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_FTMO;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Calibration window (bars) over which spread_mean and max_dev are estimated.
input int    strategy_calib_window      = 120;
// Fixed hedge ratio beta in spread = leg1 - beta*leg2 (1.0 = normalized 1:1 baseline).
input double strategy_beta              = 1.0;
// Minimum |target_fraction| to hold any spread exposure (flat band).
input double strategy_min_trade_fraction = 0.20;
// Emergency-flat multiple of max_dev (close if |spread-mean| exceeds this * max_dev).
input double strategy_emergency_mult    = 1.25;
// ATR-based protective stop on each leg.
input int    strategy_atr_period_d1     = 20;
input double strategy_atr_sl_mult       = 2.0;
input int    strategy_max_spread_points = 0;

#define STRATEGY_SYMBOL_COUNT 2

string g_pair_symbols[STRATEGY_SYMBOL_COUNT] = {"XAUUSD.DWX", "XAGUSD.DWX"};
int    g_pair_slots[STRATEGY_SYMBOL_COUNT]   = {0, 1};

bool   g_basket_scope_ready = false;
bool   g_state_ready = false;
double g_spread_now = 0.0;
double g_spread_mean = 0.0;
double g_max_dev = 0.0;
double g_target_fraction = 0.0;
datetime g_pair_entry_time = 0;

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1334_PAIR_HOST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

int Strategy_SymbolIndex(const string symbol)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(symbol == g_pair_symbols[i])
         return i;
   return -1;
  }

int Strategy_SlotForSymbol(const string symbol)
  {
   const int idx = Strategy_SymbolIndex(symbol);
   if(idx >= 0)
      return g_pair_slots[idx];
   return qm_magic_slot_offset;
  }

bool Strategy_EnsureBasketScope()
  {
   if(g_basket_scope_ready)
      return true;

   string allowed[STRATEGY_SYMBOL_COUNT] = {"XAUUSD.DWX", "XAGUSD.DWX"};
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      SymbolSelect(allowed[i], true);

   QM_SymbolGuardInit(allowed);
   QM_BasketWarmupHistory(allowed, PERIOD_D1, MathMax(strategy_calib_window + 10, 300));
   g_basket_scope_ready = true;
   return true;
  }

bool Strategy_IsRegisteredPairPosition()
  {
   const string symbol = PositionGetString(POSITION_SYMBOL);
   const int idx = Strategy_SymbolIndex(symbol);
   if(idx < 0)
      return false;

   const int expected_magic = QM_MagicChecked(qm_ea_id, g_pair_slots[idx], symbol);
   return (expected_magic > 0 && (int)PositionGetInteger(POSITION_MAGIC) == expected_magic);
  }

int Strategy_OpenPairLegCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsRegisteredPairPosition())
         count++;
     }
   return count;
  }

void Strategy_ClosePair(const QM_ExitReason reason)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(Strategy_IsRegisteredPairPosition())
         QM_TM_ClosePosition(ticket, reason);
     }
  }

bool Strategy_CopyPairCloses(const int count, double &xau[], double &xag[])
  {
   if(count < 20)
      return false;
   if(!Strategy_EnsureBasketScope())
      return false;
   if(!QM_SymbolAssertOrLog(g_pair_symbols[0]) || !QM_SymbolAssertOrLog(g_pair_symbols[1]))
      return false;

   ArraySetAsSeries(xau, true);
   ArraySetAsSeries(xag, true);
   if(CopyClose(g_pair_symbols[0], PERIOD_D1, 1, count, xau) != count) // perf-allowed: bounded D1 basket spread read, called only from skeleton's QM_IsNewBar-gated EntrySignal.
      return false;
   if(CopyClose(g_pair_symbols[1], PERIOD_D1, 1, count, xag) != count) // perf-allowed: bounded D1 basket spread read, called only from skeleton's QM_IsNewBar-gated EntrySignal.
      return false;

   for(int i = 0; i < count; ++i)
     {
      if(xau[i] <= 0.0 || xag[i] <= 0.0)
         return false;
      if(!MathIsValidNumber(xau[i]) || !MathIsValidNumber(xag[i]))
         return false;
     }
   return true;
  }

double Strategy_SpreadAt(const int index, const double &xau[], const double &xag[])
  {
   if(xau[index] <= 0.0 || xag[index] <= 0.0)
      return 0.0;
   // Card spread definition: leg1_price - beta * leg2_price (linear, not log).
   return xau[index] - strategy_beta * xag[index];
  }

bool Strategy_RefreshState()
  {
   g_state_ready = false;
   g_spread_now = 0.0;
   g_spread_mean = 0.0;
   g_max_dev = 0.0;
   g_target_fraction = 0.0;

   const int lookback = MathMax(20, strategy_calib_window);
   double xau[];
   double xag[];
   if(!Strategy_CopyPairCloses(lookback, xau, xag))
      return false;

   double spreads[];
   ArrayResize(spreads, lookback);
   double sum = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double spread = Strategy_SpreadAt(i, xau, xag);
      if(!MathIsValidNumber(spread))
         return false;
      spreads[i] = spread;
      sum += spread;
     }

   const double mean = sum / (double)lookback;

   // max_dev = max(|spread - spread_mean|) over the calibration window.
   double max_dev = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double dev = MathAbs(spreads[i] - mean);
      if(dev > max_dev)
         max_dev = dev;
     }
   if(max_dev <= 0.0 || !MathIsValidNumber(max_dev))
      return false;

   g_spread_now = spreads[0];
   g_spread_mean = mean;
   g_max_dev = max_dev;

   // target_fraction = clamp((spread - spread_mean)/max_dev, -1, +1).
   double tf = (g_spread_now - g_spread_mean) / g_max_dev;
   if(tf > 1.0)
      tf = 1.0;
   else if(tf < -1.0)
      tf = -1.0;
   g_target_fraction = tf;

   g_state_ready = MathIsValidNumber(g_target_fraction);
   return g_state_ready;
  }

bool Strategy_NewsAllowsPair(const datetime broker_time)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      const string symbol = g_pair_symbols[i];
      if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
        {
         if(!QM_NewsAllowsTrade2(symbol, broker_time, qm_news_temporal, qm_news_compliance))
            return false;
        }
      else if(!QM_NewsAllowsTrade(symbol, broker_time, qm_news_mode_legacy))
         return false;
     }
   return true;
  }

double Strategy_NormalizedLotsForLeg(const string symbol, const double sl_points)
  {
   const double raw_lots = QM_LotsForRisk(symbol, sl_points) * 0.5;
   return QM_TM_NormalizeVolume(symbol, raw_lots);
  }

bool Strategy_BuildLegRequest(const string symbol,
                              const bool buy_leg,
                              const string reason,
                              QM_BasketOrderRequest &req)
  {
   const QM_OrderType type = buy_leg ? QM_BUY : QM_SELL;
   const double entry = buy_leg ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(symbol, SYMBOL_BID);
   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(entry <= 0.0 || atr <= 0.0 || point <= 0.0)
      return false;

   const double stop_dist = strategy_atr_sl_mult * atr;
   const double sl_points = stop_dist / point;
   if(sl_points <= 0.0 || !MathIsValidNumber(sl_points))
      return false;

   const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   req.type = type;
   req.price = 0.0;
   req.sl = buy_leg ? NormalizeDouble(entry - stop_dist, digits)
                    : NormalizeDouble(entry + stop_dist, digits);
   req.tp = 0.0;
   req.lots = Strategy_NormalizedLotsForLeg(symbol, sl_points);
   req.reason = reason;
   req.symbol_slot = Strategy_SlotForSymbol(symbol);
   req.expiration_seconds = 0;
   req.symbol = symbol;
   return (req.lots > 0.0);
  }

bool Strategy_OpenPair(const int spread_direction)
  {
   if(spread_direction == 0 || Strategy_OpenPairLegCount() > 0)
      return false;

   // spread_direction > 0 => spread above mean (rich) => SHORT spread:
   //   short leg1 (XAUUSD), long leg2 (XAGUSD).
   // spread_direction < 0 => spread below mean (cheap) => LONG spread:
   //   long leg1 (XAUUSD), short leg2 (XAGUSD).
   const bool buy_xau = (spread_direction < 0);
   const bool buy_xag = !buy_xau;
   const string reason = (spread_direction < 0) ? "QM5_1334_LONG_SPREAD_BELOW_MEAN"
                                                : "QM5_1334_SHORT_SPREAD_ABOVE_MEAN";

   QM_BasketOrderRequest xau_req;
   QM_BasketOrderRequest xag_req;
   if(!Strategy_BuildLegRequest(g_pair_symbols[0], buy_xau, reason, xau_req))
      return false;
   if(!Strategy_BuildLegRequest(g_pair_symbols[1], buy_xag, reason, xag_req))
      return false;

   ulong xau_ticket = 0;
   if(!QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, xau_req, xau_ticket))
      return false;

   ulong xag_ticket = 0;
   if(!QM_BasketOpenPosition(qm_ea_id, qm_news_mode_legacy, 20, xag_req, xag_ticket))
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }

   g_pair_entry_time = TimeCurrent();
   return true;
  }

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   Strategy_EnsureBasketScope();

   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;
   if(Strategy_SymbolIndex(_Symbol) < 0)
      return true;
   if(qm_magic_slot_offset != Strategy_SlotForSymbol(_Symbol))
      return true;

   // Fail-OPEN wide-spread guard: only block a genuinely wide quoted spread.
   // .DWX models 0 spread in the tester, so never block on zero spread.
   if(strategy_max_spread_points > 0)
     {
      for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
        {
         const string sym = g_pair_symbols[i];
         const double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
         const double bid = SymbolInfoDouble(sym, SYMBOL_BID);
         const double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
         if(ask > 0.0 && bid > 0.0 && ask > bid && pt > 0.0)
           {
            const double spread_pts = (ask - bid) / pt;
            if(spread_pts > (double)strategy_max_spread_points)
               return true;
           }
        }
     }

   return false;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);

   if(!Strategy_RefreshState())
      return false;
   if(Strategy_OpenPairLegCount() > 0)
      return false;

   // Hold spread exposure only when |target_fraction| exceeds the flat band.
   if(MathAbs(g_target_fraction) <= strategy_min_trade_fraction)
      return false;

   int spread_direction = 0;
   if(g_target_fraction > strategy_min_trade_fraction)
      spread_direction = 1;  // spread rich -> short spread (handled in OpenPair).
   else if(g_target_fraction < -strategy_min_trade_fraction)
      spread_direction = -1; // spread cheap -> long spread.
   else
      return false;

   Strategy_OpenPair(spread_direction);
   return false;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   const int legs = Strategy_OpenPairLegCount();
   // Self-heal a stranded single leg (the other leg failed/closed).
   if(legs == 1)
      Strategy_ClosePair(QM_EXIT_STRATEGY);
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   if(Strategy_OpenPairLegCount() <= 0)
      return false;
   if(!g_state_ready)
      return false;

   // Emergency flat: spread broke beyond historical max deviation.
   if(MathAbs(g_spread_now - g_spread_mean) > strategy_emergency_mult * g_max_dev)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }

   // Reversion exit: target_fraction back inside the flat band (toward zero).
   if(MathAbs(g_target_fraction) < strategy_min_trade_fraction)
     {
      Strategy_ClosePair(QM_EXIT_STRATEGY);
      return false;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(QM_FrameworkFridayCloseNow(broker_time))
     {
      Strategy_ClosePair(QM_EXIT_FRIDAY_CLOSE);
      return true;
     }

   return !Strategy_NewsAllowsPair(broker_time);
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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
