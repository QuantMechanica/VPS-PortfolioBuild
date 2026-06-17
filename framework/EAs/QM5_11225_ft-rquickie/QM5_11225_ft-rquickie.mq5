#property strict
#property version   "5.0"
#property description "QM5_11225 ft-rquickie — Reinforced Quickie M5 reversal w/ 1h SMA trend gate (long-only)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11225 ft-rquickie
// -----------------------------------------------------------------------------
// Source: freqtrade-strategies ReinforcedQuickie.py (Gert Wohlgemuth), commit
//   dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4.
// Card: artifacts/cards_approved/QM5_11225_ft-rquickie.md (g0_status APPROVED).
//
// Mechanics (long-only, M5, closed-bar reads at shift >= 1):
//   Reinforcement (resampled 1h) gate, ALL required:
//     - tick volume[1] < vol_spike_mult * mean(tick volume[2..vol_mean_bars+1])
//     - resampled SMA (PERIOD_H1, sma_period) below the last M5 close
//     - resampled SMA rising vs the prior H1 bar
//   Then EITHER entry branch:
//     A) close[1] < EMA(short)  AND  close[1] < EMA(medium)  AND
//        close[1] == 12-bar minimum close  AND  close[1] <= lower Bollinger band
//     B) 5-bar lopsided V-bottom on close (apex at shift 3)  AND
//        low[2]  < BB middle  AND  CCI[2] < cci_floor  AND
//        RSI(rsi_period)[2] < rsi_floor  AND  MFI[2] < mfi_floor
//   Exit (Strategy_ExitSignal), EITHER branch:
//     - close[1] > EMA(short) AND close[1] > EMA(medium) AND close[1] == 12-bar
//       maximum close AND close[1] >= upper Bollinger band AND MFI[1] > mfi_exit
//     - eight consecutive green M5 closes AND RSI[1] > rsi_exit
//   Stop : QM_StopATR(atr_period, atr_stop_mult). Source -5% retained as a
//          disaster cap exit in Strategy_ExitSignal.
//
// .DWX invariants honoured: fail-OPEN spread guard (zero modeled spread passes);
//   no swap gate; gapless-CFD math references prior CLOSE not range; tick volume
//   is the exchange-volume proxy (MFI reader already uses VOLUME_TICK); no
//   external macro CSV. QM_IsNewBar() consumed exactly once (entry gate).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11225;
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
input int    strategy_ema_short          = 5;      // fast EMA (source EMA5)
input int    strategy_ema_medium         = 12;     // medium EMA (source EMA12)
input int    strategy_resample_sma       = 25;     // SMA period on resampled 1h series
input int    strategy_minmax_lookback    = 12;     // local min/max window (closes)
input int    strategy_bb_period          = 20;     // Bollinger period
input double strategy_bb_deviation       = 2.0;    // Bollinger std-dev (MANDATORY arg)
input int    strategy_rsi_period         = 7;      // source RSI7
input double strategy_rsi_floor          = 30.0;   // branch-B RSI oversold floor
input double strategy_rsi_exit           = 70.0;   // exit: 8-green RSI threshold
input int    strategy_cci_period         = 20;     // CCI period
input double strategy_cci_floor          = -100.0; // branch-B CCI oversold floor
input int    strategy_mfi_period         = 14;     // MFI period (tick-volume proxy)
input double strategy_mfi_floor          = 30.0;   // branch-B MFI oversold floor
input double strategy_mfi_exit           = 80.0;   // exit: MFI exhaustion threshold
input int    strategy_vol_mean_bars      = 30;     // prior-bar window for volume spike guard
input double strategy_vol_spike_mult     = 20.0;   // reject if vol[1] >= mult * mean
input int    strategy_atr_period         = 14;     // ATR period (stop)
input double strategy_atr_stop_mult      = 1.5;    // stop distance = mult * ATR
input double strategy_disaster_cap_pct   = 5.0;    // source -5% disaster exit
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// One position per symbol/magic.
bool Strategy_HavePosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; regime/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block

   const double stop_distance = strategy_atr_stop_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(Strategy_HavePosition())
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;

   // --- Reinforcement gate 1: tick-volume spike rejection ---
   // tick volume[1] must be below vol_spike_mult * mean of prior vol_mean_bars.
   const long vol_now = iVolume(_Symbol, tf, 1); // perf-allowed: single closed-bar read
   if(vol_now <= 0)
      return false;
   double vol_sum = 0.0;
   for(int s = 2; s <= strategy_vol_mean_bars + 1; ++s)
     {
      const long v = iVolume(_Symbol, tf, s); // perf-allowed: bounded closed-bar read
      if(v <= 0)
         return false;
      vol_sum += (double)v;
     }
   const double vol_mean = vol_sum / (double)strategy_vol_mean_bars;
   if(vol_mean <= 0.0)
      return false;
   if((double)vol_now >= strategy_vol_spike_mult * vol_mean)
      return false;

   // --- Reinforcement gate 2+3: resampled 1h SMA below close AND rising ---
   const double sma_h1_now  = QM_SMA(_Symbol, PERIOD_H1, strategy_resample_sma, 1);
   const double sma_h1_prev = QM_SMA(_Symbol, PERIOD_H1, strategy_resample_sma, 2);
   if(sma_h1_now <= 0.0 || sma_h1_prev <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, tf, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;
   if(!(sma_h1_now < close1))     // SMA below price
      return false;
   if(!(sma_h1_now > sma_h1_prev)) // SMA rising
      return false;

   // Shared indicator reads (closed bars).
   const double ema_short  = QM_EMA(_Symbol, tf, strategy_ema_short, 1);
   const double ema_medium = QM_EMA(_Symbol, tf, strategy_ema_medium, 1);
   const double bb_lower   = QM_BB_Lower(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_middle  = QM_BB_Middle(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 1);
   if(ema_short <= 0.0 || ema_medium <= 0.0 || bb_lower <= 0.0 || bb_middle <= 0.0)
      return false;

   // --- Branch A: lower-band capitulation / 12-bar low ---
   bool branch_a = false;
   if(close1 < ema_short && close1 < ema_medium && close1 <= bb_lower)
     {
      // close[1] is the minimum close over the lookback window (gapless CFD =>
      // close reference, not range).
      double min_close = close1;
      bool is_min = true;
      for(int s = 2; s <= strategy_minmax_lookback; ++s)
        {
         const double c = iClose(_Symbol, tf, s); // perf-allowed: bounded closed-bar read
         if(c <= 0.0) { is_min = false; break; }
         if(c < min_close) { is_min = false; break; }
        }
      branch_a = is_min;
     }

   // --- Branch B: 5-bar lopsided V-bottom + oscillator capitulation ---
   bool branch_b = false;
     {
      // Lopsided V-bottom on close: apex at shift 3 is a strict local minimum,
      // with the left wing falling and right wing recovering.
      const double c1 = close1;
      const double c2 = iClose(_Symbol, tf, 2);
      const double c3 = iClose(_Symbol, tf, 3);
      const double c4 = iClose(_Symbol, tf, 4);
      const double c5 = iClose(_Symbol, tf, 5);
      const double low2 = iLow(_Symbol, tf, 2);   // perf-allowed: single closed-bar read
      if(c2 > 0.0 && c3 > 0.0 && c4 > 0.0 && c5 > 0.0 && low2 > 0.0)
        {
         const bool v_shape = (c5 > c4 && c4 > c3 && c3 < c2 && c2 < c1);
         if(v_shape && low2 < bb_middle)
           {
            const double cci2 = QM_CCI(_Symbol, tf, strategy_cci_period, 2);
            const double rsi2 = QM_RSI(_Symbol, tf, strategy_rsi_period, 2);
            const double mfi2 = QM_MFI(_Symbol, tf, strategy_mfi_period, 2);
            if(cci2 < strategy_cci_floor &&
               rsi2 > 0.0 && rsi2 < strategy_rsi_floor &&
               mfi2 > 0.0 && mfi2 < strategy_mfi_floor)
               branch_b = true;
           }
        }
     }

   if(!branch_a && !branch_b)
      return false;

   // --- Build the long entry. Framework sizes lots (no lots field). ---
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_stop_mult);
   if(sl <= 0.0 || sl >= entry)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // exits are signal/ROI/disaster-cap driven, no fixed TP
   req.reason = branch_a ? "rquickie_lowerband_long" : "rquickie_vbottom_long";
   return true;
  }

// No active trade management beyond the initial ATR stop. Exits live in
// Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exits: source exhaustion signal, 8-green-RSI signal, or the -5% disaster cap.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool have_position = false;
   double open_price = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      have_position = true;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      break;
     }
   if(!have_position || open_price <= 0.0)
      return false;

   // --- Disaster cap: source -5% stoploss (per-tick safe, O(1)) ---
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid > 0.0)
     {
      const double pnl_pct = (bid - open_price) / open_price * 100.0;
      if(pnl_pct <= -strategy_disaster_cap_pct)
         return true;
     }

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double close1     = iClose(_Symbol, tf, 1); // perf-allowed: single closed-bar read
   const double ema_short  = QM_EMA(_Symbol, tf, strategy_ema_short, 1);
   const double ema_medium = QM_EMA(_Symbol, tf, strategy_ema_medium, 1);
   const double bb_upper   = QM_BB_Upper(_Symbol, tf, strategy_bb_period, strategy_bb_deviation, 1);
   if(close1 <= 0.0 || ema_short <= 0.0 || ema_medium <= 0.0 || bb_upper <= 0.0)
      return false;

   // --- Exit branch 1: upper-band / EMA / MFI exhaustion at the 12-bar high ---
   if(close1 > ema_short && close1 > ema_medium && close1 >= bb_upper)
     {
      bool is_max = true;
      for(int s = 2; s <= strategy_minmax_lookback; ++s)
        {
         const double c = iClose(_Symbol, tf, s); // perf-allowed: bounded closed-bar read
         if(c <= 0.0) { is_max = false; break; }
         if(c > close1) { is_max = false; break; }
        }
      if(is_max)
        {
         const double mfi1 = QM_MFI(_Symbol, tf, strategy_mfi_period, 1);
         if(mfi1 > strategy_mfi_exit)
            return true;
        }
     }

   // --- Exit branch 2: eight consecutive green closes AND RSI exhausted ---
   bool eight_green = true;
   for(int s = 1; s <= 8; ++s)
     {
      const double c  = iClose(_Symbol, tf, s);     // perf-allowed: bounded closed-bar read
      const double op = iOpen(_Symbol, tf, s);      // perf-allowed: bounded closed-bar read
      if(c <= 0.0 || op <= 0.0 || !(c > op)) { eight_green = false; break; }
     }
   if(eight_green)
     {
      const double rsi1 = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
      if(rsi1 > strategy_rsi_exit)
         return true;
     }

   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
