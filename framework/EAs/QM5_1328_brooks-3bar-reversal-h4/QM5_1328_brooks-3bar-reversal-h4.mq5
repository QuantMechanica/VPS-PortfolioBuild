#property strict
#property version   "5.0"
#property description "QM5_1328 Brooks 3-Bar Reversal H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1328;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — Q06 HARSH sets to 0.10; default 0.0 = no rejection.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf        = PERIOD_H4;
input int    strategy_atr_period         = 14;
input int    strategy_sma_period         = 50;
input int    strategy_swing_lookback     = 10;
input double strategy_trend_body_min     = 0.50;
input double strategy_stall_body_max     = 0.40;
input double strategy_stall_atr_poke     = 0.25;
input double strategy_sma_atr_buffer     = 0.50;
input double strategy_tp1_rr             = 2.0;
input double strategy_tp2_rr             = 3.5;
input double strategy_tp1_close_fraction = 0.50;
input int    strategy_time_stop_bars     = 12;
input int    strategy_rearm_bars         = 3;
input double strategy_spread_mult        = 2.0;
input int    strategy_spread_lookback    = 20;

// File-scope state
double   g_median_spread_points   = 0.0;
ulong    g_active_ticket          = 0;
int      g_active_direction       = 0;
double   g_initial_risk_price     = 0.0;
bool     g_tp1_done               = false;
bool     g_strategy_cadence_ready = false;
int      g_rearm_direction        = 0;
int      g_rearm_remaining        = 0;

double PipDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return point * pip_factor;
  }

double BodySize(const int shift)
  {
   return MathAbs(iClose(_Symbol, strategy_tf, shift) - iOpen(_Symbol, strategy_tf, shift)); // perf-allowed: fixed closed-bar OHLC structural pattern
  }

double BarRange(const int shift)
  {
   return iHigh(_Symbol, strategy_tf, shift) - iLow(_Symbol, strategy_tf, shift); // perf-allowed: fixed closed-bar OHLC structural pattern
  }

double LowestLow(const int first_shift, const int count)
  {
   double low = DBL_MAX;
   for(int shift = first_shift; shift < first_shift + count; ++shift)
      low = MathMin(low, iLow(_Symbol, strategy_tf, shift)); // perf-allowed: bounded swing-low structural scan
   return low;
  }

double HighestHigh(const int first_shift, const int count)
  {
   double high = -DBL_MAX;
   for(int shift = first_shift; shift < first_shift + count; ++shift)
      high = MathMax(high, iHigh(_Symbol, strategy_tf, shift)); // perf-allowed: bounded swing-high structural scan
   return high;
  }

void RefreshSpreadMedian()
  {
   // .DWX symbols quote bid==ask (0 modeled spread); median will be 0.0
   // and the guard below is skipped — correct behaviour, no spread blocking on .DWX.
   if(!g_strategy_cadence_ready && g_median_spread_points > 0.0)
      return;

   double spreads[];
   ArrayResize(spreads, strategy_spread_lookback);
   int n = 0;
   for(int shift = 1; shift <= strategy_spread_lookback; ++shift)
     {
      const long spread = iSpread(_Symbol, strategy_tf, shift); // perf-allowed: fixed closed-bar spread sample
      if(spread > 0)
        {
         spreads[n] = (double)spread;
         n++;
        }
     }

   if(n <= 0)
     {
      g_median_spread_points = 0.0;
      return;
     }

   ArrayResize(spreads, n);
   ArraySort(spreads);
   if((n % 2) == 1)
      g_median_spread_points = spreads[n / 2];
   else
      g_median_spread_points = 0.5 * (spreads[n / 2 - 1] + spreads[n / 2]);
  }

bool SelectOurPosition(ulong &ticket, int &direction, double &open_price, double &sl, double &tp, double &volume, datetime &open_time)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      direction = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      volume = PositionGetDouble(POSITION_VOLUME);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

void RefreshPositionLifecycle()
  {
   ulong ticket = 0;
   int direction = 0;
   double open_price = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   double volume = 0.0;
   datetime open_time = 0;

   if(SelectOurPosition(ticket, direction, open_price, sl, tp, volume, open_time))
     {
      if(ticket != g_active_ticket)
        {
         g_active_ticket = ticket;
         g_active_direction = direction;
         g_initial_risk_price = MathAbs(open_price - sl);
         g_tp1_done = false;
        }
      return;
     }

   if(g_active_ticket != 0)
     {
      g_rearm_direction = g_active_direction;
      g_rearm_remaining = MathMax(strategy_rearm_bars, 0);
     }

   g_active_ticket = 0;
   g_active_direction = 0;
   g_initial_risk_price = 0.0;
   g_tp1_done = false;
  }

void AdvanceRearmCountdown()
  {
   if(g_rearm_remaining <= 0)
     {
      g_rearm_remaining = 0;
      g_rearm_direction = 0;
      return;
     }

   g_rearm_remaining--;
   if(g_rearm_remaining <= 0)
      g_rearm_direction = 0;
  }

bool RearmBlocksDirection(const int direction)
  {
   if(g_rearm_remaining <= 0 || g_rearm_direction != direction)
      return false;
   return true;
  }

bool PatternBuy(double &entry_sl, double &entry_tp)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
   const double pip = PipDistance();
   if(atr <= 0.0 || sma <= 0.0 || pip <= 0.0)
      return false;

   const double o3 = iOpen(_Symbol, strategy_tf, 3);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double c3 = iClose(_Symbol, strategy_tf, 3); // perf-allowed: fixed closed-bar OHLC structural pattern
   const double h3 = iHigh(_Symbol, strategy_tf, 3);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double l3 = iLow(_Symbol, strategy_tf, 3);   // perf-allowed: fixed closed-bar OHLC structural pattern
   const double h2 = iHigh(_Symbol, strategy_tf, 2);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double l2 = iLow(_Symbol, strategy_tf, 2);   // perf-allowed: fixed closed-bar OHLC structural pattern
   const double o1 = iOpen(_Symbol, strategy_tf, 1);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: fixed closed-bar OHLC structural pattern
   const double l1 = iLow(_Symbol, strategy_tf, 1);   // perf-allowed: fixed closed-bar OHLC structural pattern

   const double r3 = BarRange(3);
   const double r2 = BarRange(2);
   if(r3 <= 0.0 || r2 <= 0.0)
      return false;

   // Trend bar: clean bearish with dominant body
   if(!(c3 < o3 && BodySize(3) >= strategy_trend_body_min * r3))
      return false;
   // Stall bar: small body, contained around trend bar range (allow wick poke)
   if(!(BodySize(2) <= strategy_stall_body_max * r2 && h2 <= h3 && l2 >= l3 - strategy_stall_atr_poke * atr))
      return false;
   // Reversal bar: closes above trend bar close and is bullish
   if(!(c1 > c3 && c1 > o1))
      return false;

   // Swing-low test: cluster contains the 10-bar swing low
   const double cluster_low = MathMin(MathMin(l3, l2), l1);
   if(cluster_low > LowestLow(1, strategy_swing_lookback) + _Point * 0.5)
      return false;
   // Macro-trend filter: close is above SMA(50) minus ATR buffer
   if(c1 <= sma - strategy_sma_atr_buffer * atr)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   entry_sl = NormalizeDouble(cluster_low - pip, _Digits);
   const double risk = ask - entry_sl;
   if(ask <= 0.0 || risk <= 0.0)
      return false;
   entry_tp = NormalizeDouble(ask + strategy_tp2_rr * risk, _Digits);
   return true;
  }

bool PatternSell(double &entry_sl, double &entry_tp)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
   const double pip = PipDistance();
   if(atr <= 0.0 || sma <= 0.0 || pip <= 0.0)
      return false;

   const double o3 = iOpen(_Symbol, strategy_tf, 3);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double c3 = iClose(_Symbol, strategy_tf, 3); // perf-allowed: fixed closed-bar OHLC structural pattern
   const double h3 = iHigh(_Symbol, strategy_tf, 3);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double l3 = iLow(_Symbol, strategy_tf, 3);   // perf-allowed: fixed closed-bar OHLC structural pattern
   const double h2 = iHigh(_Symbol, strategy_tf, 2);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double l2 = iLow(_Symbol, strategy_tf, 2);   // perf-allowed: fixed closed-bar OHLC structural pattern
   const double o1 = iOpen(_Symbol, strategy_tf, 1);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: fixed closed-bar OHLC structural pattern
   const double h1 = iHigh(_Symbol, strategy_tf, 1);  // perf-allowed: fixed closed-bar OHLC structural pattern

   const double r3 = BarRange(3);
   const double r2 = BarRange(2);
   if(r3 <= 0.0 || r2 <= 0.0)
      return false;

   // Trend bar: clean bullish with dominant body
   if(!(c3 > o3 && BodySize(3) >= strategy_trend_body_min * r3))
      return false;
   // Stall bar: small body, contained around trend bar range (allow wick poke above)
   if(!(BodySize(2) <= strategy_stall_body_max * r2 && l2 >= l3 && h2 <= h3 + strategy_stall_atr_poke * atr))
      return false;
   // Reversal bar: closes below trend bar close and is bearish
   if(!(c1 < c3 && c1 < o1))
      return false;

   // Swing-high test: cluster contains the 10-bar swing high
   const double cluster_high = MathMax(MathMax(h3, h2), h1);
   if(cluster_high < HighestHigh(1, strategy_swing_lookback) - _Point * 0.5)
      return false;
   // Macro-trend filter: close is below SMA(50) plus ATR buffer
   if(c1 >= sma + strategy_sma_atr_buffer * atr)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   entry_sl = NormalizeDouble(cluster_high + pip, _Digits);
   const double risk = entry_sl - bid;
   if(bid <= 0.0 || risk <= 0.0)
      return false;
   entry_tp = NormalizeDouble(bid - strategy_tp2_rr * risk, _Digits);
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   RefreshPositionLifecycle();
   RefreshSpreadMedian();

   // Only block on a genuinely wide spread; zero spread on .DWX is NOT a block
   if(g_median_spread_points > 0.0 && strategy_spread_mult > 0.0)
     {
      const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(current_spread > 0 && (double)current_spread > strategy_spread_mult * g_median_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   RefreshPositionLifecycle();
   if(g_active_ticket != 0)
      return false;

   double sl = 0.0;
   double tp = 0.0;
   if(!RearmBlocksDirection(1) && PatternBuy(sl, tp))
     {
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BROOKS_3BAR_REVERSAL_BUY_H4";
      g_initial_risk_price = MathAbs(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - sl);
      g_tp1_done = false;
      return true;
     }

   if(!RearmBlocksDirection(-1) && PatternSell(sl, tp))
     {
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BROOKS_3BAR_REVERSAL_SELL_H4";
      g_initial_risk_price = MathAbs(sl - SymbolInfoDouble(_Symbol, SYMBOL_BID));
      g_tp1_done = false;
      return true;
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0 || g_tp1_done || g_initial_risk_price <= 0.0)
      return;

   if(!PositionSelectByTicket(g_active_ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double volume = PositionGetDouble(POSITION_VOLUME);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double moved = is_buy ? (market - open_price) : (open_price - market);

   if(moved >= strategy_tp1_rr * g_initial_risk_price)
     {
      const double close_lots = volume * strategy_tp1_close_fraction;
      if(QM_TM_PartialClose(g_active_ticket, close_lots, QM_EXIT_PARTIAL))
        {
         QM_TM_MoveSL(g_active_ticket, NormalizeDouble(open_price, _Digits), "brooks_tp1_move_sl_to_be");
         g_tp1_done = true;
        }
     }
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   RefreshPositionLifecycle();
   // Time-stop only applies before TP1 is hit
   if(g_active_ticket == 0 || g_tp1_done)
      return false;
   // Only evaluate at bar close (cadence gate)
   if(!g_strategy_cadence_ready)
      return false;

   if(!PositionSelectByTicket(g_active_ticket))
      return false;

   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int bars_since_open = iBarShift(_Symbol, strategy_tf, open_time, false); // perf-allowed: bar-count time-stop
   return (bars_since_open >= strategy_time_stop_bars);
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade2 in OnTick (FW1 axes)
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1328\",\"ea\":\"brooks-3bar-reversal-h4\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   g_strategy_cadence_ready = false;

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   // FW1 — 2-axis check. Falls through to legacy qm_news_mode_legacy only
   // when both new axes are at their OFF defaults.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   // Advance closed-bar state once per new H4 bar
   g_strategy_cadence_ready = QM_IsNewBar(_Symbol, strategy_tf);
   if(g_strategy_cadence_ready)
     {
      QM_EquityStreamOnNewBar();
      AdvanceRearmCountdown();
     }

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: TP1 partial close + break-even shift
   Strategy_ManageOpenPosition();

   // Time-stop: evaluated at bar close (cadence-gated inside ExitSignal)
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   if(!g_strategy_cadence_ready)
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
