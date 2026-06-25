#property strict
#property version   "5.0"
#property description "QM5_10241 TradingView VWAP Retest Continuation (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// -----------------------------------------------------------------------------
// Mechanic (Strategy Card QM5_10241 tv-vwap-retest):
//   Long-only intraday VWAP retest continuation on M15.
//   1. Price first BREAKS above session VWAP (a recent closed bar closed above).
//   2. Within strategy_retest_max_bars, price RETESTS VWAP (a closed bar trades
//      down to/through VWAP, low <= VWAP).
//   3. A bullish CONFIRMATION candle prints (close > open AND close > VWAP),
//      optionally with rejection-wick + volume-spike filters.
//   Exits: ATR stop-loss and ATR take-profit. Max trades per day cap.
//
// Session VWAP is reset at each broker-day rollover and accumulated from CLOSED
// bars only (shift>=1) using typical price (H+L+C)/3 weighted by tick volume.
// No QM_VWAP helper exists in the framework, so VWAP is computed here from raw
// price/volume series accessors (iHigh/iLow/iClose/iVolume) on closed bars —
// this is raw price/volume, NOT an indicator buffer.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10241;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_break_lookback_bars = 5;     // bars to confirm a prior break above VWAP
input int    strategy_retest_max_bars     = 8;     // max bars after break for the retest
input int    strategy_atr_period          = 14;    // ATR period for stop/target
input double strategy_atr_sl_mult         = 1.0;   // stop = 1.0 ATR
input double strategy_atr_tp_mult         = 1.5;   // target = 1.5 ATR
input bool   strategy_use_rejection_wick  = true;  // require lower-wick rejection on confirmation bar
input double strategy_rejection_wick_frac = 0.30;  // lower wick >= frac of bar range
input bool   strategy_use_volume_spike    = true;  // require volume spike on confirmation bar
input double strategy_volume_spike_mult   = 1.2;   // confirm vol >= mult * avg vol
input int    strategy_volume_avg_bars     = 20;    // bars for average volume
input double strategy_min_atr_dist_mult   = 0.0;   // min VWAP distance at break (0 = off), in ATR
input int    strategy_max_trades_per_day  = 2;     // selective framework cap
input int    strategy_max_spread_points   = 300;

// -----------------------------------------------------------------------------
// Session-VWAP + daily-trade-count state.
// -----------------------------------------------------------------------------
datetime g_trade_day      = 0;     // broker day (00:00) of last counted trade
int      g_trades_today   = 0;     // entries fired in current broker day

datetime QM10241_BrokerDayStart(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
  }

// Session VWAP at closed-bar `shift`, accumulated from the broker-day open of
// that bar up to and including `shift`. Returns 0.0 if unavailable.
double QM10241_SessionVWAP(const int shift)
  {
   if(shift < 1)
      return 0.0;

   const datetime bar_time = iTime(_Symbol, _Period, shift);
   if(bar_time == 0)
      return 0.0;
   const datetime day_start = QM10241_BrokerDayStart(bar_time);

   double pv_sum = 0.0;
   double v_sum  = 0.0;
   for(int s = shift; ; ++s)
     {
      const datetime t = iTime(_Symbol, _Period, s);
      if(t == 0 || t < day_start)
         break;
      const double h = iHigh(_Symbol, _Period, s);
      const double l = iLow(_Symbol, _Period, s);
      const double c = iClose(_Symbol, _Period, s);
      const long   v = iVolume(_Symbol, _Period, s);
      if(h <= 0.0 || l <= 0.0 || c <= 0.0 || v <= 0)
         continue;
      const double tp = (h + l + c) / 3.0;
      pv_sum += tp * (double)v;
      v_sum  += (double)v;
     }

   if(v_sum <= 0.0)
      return 0.0;
   return pv_sum / v_sum;
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15)
      return true;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

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

   if(strategy_break_lookback_bars <= 0 ||
      strategy_retest_max_bars <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_atr_tp_mult <= 0.0 ||
      strategy_volume_avg_bars <= 0)
      return false;

   // Daily trade cap (per broker day).
   const datetime cur_day = QM10241_BrokerDayStart(iTime(_Symbol, _Period, 1));
   if(cur_day != g_trade_day)
     {
      g_trade_day = cur_day;
      g_trades_today = 0;
     }
   if(strategy_max_trades_per_day > 0 && g_trades_today >= strategy_max_trades_per_day)
      return false;

   // Confirmation candle is the most recent CLOSED bar (shift 1).
   const double c1_open  = iOpen(_Symbol, _Period, 1);
   const double c1_close = iClose(_Symbol, _Period, 1);
   const double c1_high  = iHigh(_Symbol, _Period, 1);
   const double c1_low   = iLow(_Symbol, _Period, 1);
   if(c1_open <= 0.0 || c1_close <= 0.0 || c1_high <= 0.0 || c1_low <= 0.0)
      return false;

   const double vwap1 = QM10241_SessionVWAP(1);
   if(vwap1 <= 0.0)
      return false;

   // Confirmation: bullish bar closing back above VWAP.
   if(c1_close <= c1_open)
      return false;
   if(c1_close <= vwap1)
      return false;

   // Optional rejection-wick filter: lower wick is a meaningful fraction of range.
   if(strategy_use_rejection_wick)
     {
      const double rng = c1_high - c1_low;
      if(rng <= 0.0)
         return false;
      const double lower_wick = MathMin(c1_open, c1_close) - c1_low;
      if(lower_wick < strategy_rejection_wick_frac * rng)
         return false;
     }

   // Optional volume-spike filter on the confirmation bar.
   if(strategy_use_volume_spike)
     {
      double vsum = 0.0;
      int    vcnt = 0;
      for(int s = 2; s <= strategy_volume_avg_bars + 1; ++s)
        {
         const long v = iVolume(_Symbol, _Period, s);
         if(v <= 0)
            continue;
         vsum += (double)v;
         ++vcnt;
        }
      if(vcnt <= 0)
         return false;
      const double avg_vol = vsum / (double)vcnt;
      const long   v1 = iVolume(_Symbol, _Period, 1);
      if(avg_vol <= 0.0 || (double)v1 < strategy_volume_spike_mult * avg_vol)
         return false;
     }

   // Retest: within strategy_retest_max_bars before the confirmation bar, a bar
   // must have traded down to/through VWAP (low <= its session VWAP).
   bool retest_seen = false;
   int  retest_shift = 0;
   for(int s = 2; s <= strategy_retest_max_bars + 1; ++s)
     {
      const double lo = iLow(_Symbol, _Period, s);
      const double vw = QM10241_SessionVWAP(s);
      if(lo <= 0.0 || vw <= 0.0)
         continue;
      if(lo <= vw)
        {
         retest_seen = true;
         retest_shift = s;
         break;
        }
     }
   if(!retest_seen)
      return false;

   // Break: before the retest, a closed bar must have closed ABOVE its VWAP
   // (price first established itself above VWAP).
   bool break_seen = false;
   const int break_from = retest_shift + 1;
   const int break_to   = retest_shift + strategy_break_lookback_bars;
   for(int s = break_from; s <= break_to; ++s)
     {
      const double cc = iClose(_Symbol, _Period, s);
      const double vw = QM10241_SessionVWAP(s);
      if(cc <= 0.0 || vw <= 0.0)
         continue;
      if(cc > vw)
        {
         break_seen = true;
         break;
        }
     }
   if(!break_seen)
      return false;

   // ATR value for stop/target distances.
   const double atr_val = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_val <= 0.0)
      return false;

   // Optional minimum-distance gate at the break (confirmation close vs VWAP).
   if(strategy_min_atr_dist_mult > 0.0)
     {
      if((c1_close - vwap1) < strategy_min_atr_dist_mult * atr_val)
         return false;
     }

   const double entry_price = QM_EntryMarketPrice(QM_BUY);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.tp = NormalizeDouble(entry_price + strategy_atr_tp_mult * atr_val, _Digits);

   ++g_trades_today;
   req.reason = "TV_VWAP_RETEST_LONG";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, pyramiding, or partial close.
  }

bool Strategy_ExitSignal()
  {
   // Exits handled entirely by ATR stop-loss / take-profit attached at entry.
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
