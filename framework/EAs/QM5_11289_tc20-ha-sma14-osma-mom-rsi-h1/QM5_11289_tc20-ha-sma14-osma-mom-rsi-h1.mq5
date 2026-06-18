#property strict
#property version   "5.0"
#property description "QM5_11289 TC20 #4 Heiken-Ashi + SMA(14) + OsMA + Momentum + RSI(5) (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11289
// -----------------------------------------------------------------------------
// Thomas Carter, "20 Forex Trading Strategies (1 Hour)", Strategy #4.
// Multi-indicator confluence. Per build doctrine (.DWX invariant #4) ONE fresh
// cross is the TRIGGER EVENT; the rest are persistent STATES on the closed bar.
//
//   TRIGGER  : OsMA(12,26,9) = MACD_main - MACD_signal crosses ZERO.
//   STATES   : Heiken-Ashi candle colour aligns AND HA-close on the right side
//              of SMA(14); Momentum(10) on the right side of 100; RSI(5) on the
//              right side of 50.
//
// Heiken-Ashi is reconstructed deterministically from a bounded warmup window
// of raw OHLC (perf-allowed structural logic, gated by QM_IsNewBar), seeded by
// the canonical recurrence HAOpen=(prevHAOpen+prevHAClose)/2,
// HAClose=(O+H+L+C)/4.
//
// SL = swing structure (lookback low/high). TP = 2 x SL distance (RR 2).
// Early exit when OsMA crosses back through zero against the position.
// One position per magic (framework default).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11289;
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
input int    strategy_sma_period         = 14;     // SMA on close — HA-trend gate.
input int    strategy_macd_fast          = 12;     // OsMA fast EMA (MACD main).
input int    strategy_macd_slow          = 26;     // OsMA slow EMA (MACD main).
input int    strategy_macd_signal        = 9;      // OsMA signal EMA.
input int    strategy_mom_period         = 10;     // Momentum period (level 100 = flat).
input int    strategy_rsi_period         = 5;      // RSI period (level 50 = mid).
input int    strategy_swing_lookback     = 12;     // Bars back for swing low/high SL anchor.
input double strategy_tp_rr              = 2.0;    // TP = RR x SL distance.
input double strategy_min_sl_pips        = 5.0;    // Floor on SL distance (pips) to avoid degenerate stops.
input double strategy_spread_cap_pips    = 20.0;   // Card spread cap; fail-OPEN on zero modelled spread.

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

double Strategy_PipSize()
  {
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double pip_factor = (digits == 3 || digits == 5) ? 10.0 : 1.0;
   return point * pip_factor;
  }

// OsMA on a closed-bar shift = MACD main - MACD signal. Can be negative.
double Strategy_OsMA(const int shift)
  {
   const double main = QM_MACD_Main(_Symbol, PERIOD_H1, strategy_macd_fast,
                                    strategy_macd_slow, strategy_macd_signal, shift, PRICE_CLOSE);
   const double sig  = QM_MACD_Signal(_Symbol, PERIOD_H1, strategy_macd_fast,
                                      strategy_macd_slow, strategy_macd_signal, shift, PRICE_CLOSE);
   return main - sig;
  }

// Deterministic Heiken-Ashi reconstruction for the bar at `shift`.
// Bounded warmup window; raw OHLC reads are perf-allowed structural logic and
// run only inside the QM_IsNewBar-gated entry/exit path. Returns false if the
// raw series is unavailable.
bool Strategy_HeikinAshi(const int shift, double &ha_open, double &ha_close)
  {
   ha_open = 0.0;
   ha_close = 0.0;
   if(shift < 1)
      return false;

   const int warmup = 50;
   const int start = shift + warmup;
   double prev_ha_open = 0.0;
   double prev_ha_close = 0.0;
   bool seeded = false;

   for(int s = start; s >= shift; --s)
     {
      const double o = iOpen(_Symbol, PERIOD_H1, s);   // perf-allowed: deterministic HA reconstruction.
      const double h = iHigh(_Symbol, PERIOD_H1, s);   // perf-allowed: deterministic HA reconstruction.
      const double l = iLow(_Symbol, PERIOD_H1, s);    // perf-allowed: deterministic HA reconstruction.
      const double c = iClose(_Symbol, PERIOD_H1, s);  // perf-allowed: deterministic HA reconstruction.
      if(o <= 0.0 || h <= 0.0 || l <= 0.0 || c <= 0.0)
         return false;

      const double cur_ha_close = (o + h + l + c) / 4.0;
      const double cur_ha_open  = seeded ? ((prev_ha_open + prev_ha_close) / 2.0) : ((o + c) / 2.0);

      prev_ha_open = cur_ha_open;
      prev_ha_close = cur_ha_close;
      seeded = true;

      if(s == shift)
        {
         ha_open = cur_ha_open;
         ha_close = cur_ha_close;
         return true;
        }
     }
   return false;
  }

// +1 bullish HA / -1 bearish HA / 0 doji-or-error, for the bar at `shift`.
int Strategy_HAColor(const int shift)
  {
   double o = 0.0;
   double c = 0.0;
   if(!Strategy_HeikinAshi(shift, o, c))
      return 0;
   if(c > o)
      return 1;
   if(c < o)
      return -1;
   return 0;
  }

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &position_type)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Spread guard only. FAIL-OPEN on zero modelled spread (.DWX invariant #1):
// block ONLY a genuinely wide spread; never block on ask==bid / zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double cap = strategy_spread_cap_pips * Strategy_PipSize();
   if(ask > 0.0 && bid > 0.0 && ask > bid && cap > 0.0 && (ask - bid) > cap)
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

   if(_Period != PERIOD_H1)
      return false;

   // TRIGGER EVENT: OsMA zero-cross between the two most recent closed bars.
   const double osma_prev = Strategy_OsMA(2);
   const double osma_now  = Strategy_OsMA(1);
   const bool cross_up   = (osma_prev < 0.0 && osma_now >= 0.0);
   const bool cross_down = (osma_prev > 0.0 && osma_now <= 0.0);
   if(!cross_up && !cross_down)
      return false;

   // STATES on the last closed bar (shift 1).
   const int ha_color = Strategy_HAColor(1);
   if(ha_color == 0)
      return false;

   double ha_open = 0.0;
   double ha_close = 0.0;
   if(!Strategy_HeikinAshi(1, ha_open, ha_close))
      return false;

   const double sma = QM_SMA(_Symbol, PERIOD_H1, strategy_sma_period, 1, PRICE_CLOSE);
   const double mom = QM_Momentum(_Symbol, PERIOD_H1, strategy_mom_period, 1, PRICE_CLOSE);
   const double rsi = QM_RSI(_Symbol, PERIOD_H1, strategy_rsi_period, 1, PRICE_CLOSE);
   if(sma <= 0.0 || mom <= 0.0 || rsi <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double min_sl_dist = strategy_min_sl_pips * Strategy_PipSize();

   // LONG: OsMA cross up + bullish HA above SMA + Momentum>100 + RSI>50.
   if(cross_up && ha_color > 0 && ha_close > sma && mom > 100.0 && rsi > 50.0)
     {
      const double entry = ask;
      double sl = QM_StopStructure(_Symbol, QM_BUY, entry, strategy_swing_lookback);
      if(sl <= 0.0 || sl >= entry)
         return false;
      if((entry - sl) < min_sl_dist)
         sl = QM_StopRulesNormalizePrice(_Symbol, entry - min_sl_dist);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= entry)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "TC20_4_HA_OSMA_MOM_RSI_BUY";
      return true;
     }

   // SHORT mirror.
   if(cross_down && ha_color < 0 && ha_close < sma && mom < 100.0 && rsi < 50.0)
     {
      const double entry = bid;
      double sl = QM_StopStructure(_Symbol, QM_SELL, entry, strategy_swing_lookback);
      if(sl <= 0.0 || sl <= entry)
         return false;
      if((sl - entry) < min_sl_dist)
         sl = QM_StopRulesNormalizePrice(_Symbol, entry + min_sl_dist);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(tp >= entry || tp <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "TC20_4_HA_OSMA_MOM_RSI_SELL";
      return true;
     }

   return false;
  }

// No active trade management beyond SL/TP and the OsMA exit below.
void Strategy_ManageOpenPosition()
  {
  }

// Early exit: OsMA crosses back through zero against the open position.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_SelectOurPosition(position_type))
      return false;

   const double osma_prev = Strategy_OsMA(2);
   const double osma_now  = Strategy_OsMA(1);

   if(position_type == POSITION_TYPE_BUY && osma_prev > 0.0 && osma_now <= 0.0)
      return true;
   if(position_type == POSITION_TYPE_SELL && osma_prev < 0.0 && osma_now >= 0.0)
      return true;
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
