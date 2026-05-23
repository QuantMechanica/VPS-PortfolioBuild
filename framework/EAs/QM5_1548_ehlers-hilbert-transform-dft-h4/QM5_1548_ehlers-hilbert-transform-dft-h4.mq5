#property strict
#property version   "5.0"
#property description "QM5_1548 Ehlers Hilbert-Transform DFT Dominant-Cycle (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1548;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.5;
input double strategy_spread_atr_mult   = 0.4;
input int    strategy_roof_hp_period    = 48;
input int    strategy_roof_ss_period    = 10;
input int    strategy_dft_window        = 48;
input int    strategy_scan_min_period   = 10;
input int    strategy_scan_max_period   = 48;
input int    strategy_trade_min_period  = 12;
input int    strategy_trade_max_period  = 32;
input double strategy_entry_clarity     = 1.8;
input double strategy_exit_clarity      = 1.2;
input double strategy_time_stop_fraction = 0.7;
input double strategy_hilbert_period_adjust = 1.0;

#define QM1548_PI 3.14159265358979323846
#define QM1548_MAX_DFT_WINDOW 96

double   g_rf_last = 0.0;
double   g_rf_prev = 0.0;
double   g_cycle_clarity = 0.0;
int      g_dominant_period = 0;
datetime g_cached_closed_bar = 0;

bool QM1548_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return true;
     }
   return false;
  }

bool QM1548_UpdateRoofing()
  {
   const int bars_needed = MathMax(strategy_roof_hp_period * 3,
                                   strategy_dft_window + strategy_scan_max_period + 16);
   if(Bars(_Symbol, PERIOD_H4) < bars_needed + 10)
      return false;

   double hp[];
   double filt[];
   ArrayResize(hp, bars_needed);
   ArrayResize(filt, bars_needed);

   const double hp_rad = 0.707 * 2.0 * QM1548_PI / (double)MathMax(2, strategy_roof_hp_period);
   const double alpha = (MathCos(hp_rad) + MathSin(hp_rad) - 1.0) / MathCos(hp_rad);
   const double a1 = MathExp(-1.414 * QM1548_PI / (double)MathMax(2, strategy_roof_ss_period));
   const double b1 = 2.0 * a1 * MathCos(1.414 * QM1548_PI / (double)MathMax(2, strategy_roof_ss_period));
   const double c2 = b1;
   const double c3 = -a1 * a1;
   const double c1 = 1.0 - c2 - c3;

   for(int j = 0; j < bars_needed; ++j)
     {
      const int shift = bars_needed - j;
      const double p0 = iClose(_Symbol, PERIOD_H4, shift);
      if(p0 <= 0.0)
         return false;

      if(j < 2)
        {
         hp[j] = 0.0;
         filt[j] = 0.0;
         continue;
        }

      const double p1 = iClose(_Symbol, PERIOD_H4, shift + 1);
      const double p2 = iClose(_Symbol, PERIOD_H4, shift + 2);
      if(p1 <= 0.0 || p2 <= 0.0)
         return false;

      hp[j] = MathPow(1.0 - alpha / 2.0, 2.0) * (p0 - 2.0 * p1 + p2)
              + 2.0 * (1.0 - alpha) * hp[j - 1]
              - MathPow(1.0 - alpha, 2.0) * hp[j - 2];
      filt[j] = c1 * 0.5 * (hp[j] + hp[j - 1]) + c2 * filt[j - 1] + c3 * filt[j - 2];
     }

   g_rf_last = filt[bars_needed - 1];
   g_rf_prev = filt[bars_needed - 2];
   return true;
  }

bool QM1548_UpdateHilbertDft()
  {
   const int window = MathMin(MathMax(strategy_dft_window, 8), QM1548_MAX_DFT_WINDOW);
   const int scan_min = MathMax(2, strategy_scan_min_period);
   const int scan_max = MathMax(scan_min, strategy_scan_max_period);
   if(Bars(_Symbol, PERIOD_H4) < window + 16)
      return false;

   double i_comp[];
   double q_comp[];
   ArrayResize(i_comp, window);
   ArrayResize(q_comp, window);

   for(int k = 0; k < window; ++k)
     {
      const int s = 1 + k;
      const double p0 = iClose(_Symbol, PERIOD_H4, s);
      const double p1 = iClose(_Symbol, PERIOD_H4, s + 1);
      const double p2 = iClose(_Symbol, PERIOD_H4, s + 2);
      const double p3 = iClose(_Symbol, PERIOD_H4, s + 3);
      const double p4 = iClose(_Symbol, PERIOD_H4, s + 4);
      const double p5 = iClose(_Symbol, PERIOD_H4, s + 5);
      const double p6 = iClose(_Symbol, PERIOD_H4, s + 6);
      const double p7 = iClose(_Symbol, PERIOD_H4, s + 7);
      if(p0 <= 0.0 || p1 <= 0.0 || p2 <= 0.0 || p3 <= 0.0 ||
         p4 <= 0.0 || p5 <= 0.0 || p6 <= 0.0 || p7 <= 0.0)
         return false;

      i_comp[k] = strategy_hilbert_period_adjust *
                  (0.0962 * p0 + 0.5769 * p2 - 0.5769 * p4 - 0.0962 * p6);
      q_comp[k] = 0.0962 * p1 + 0.5769 * p3 - 0.5769 * p5 - 0.0962 * p7;
     }

   double max_power = -1.0;
   double power_sum = 0.0;
   int count = 0;
   int best_period = scan_min;

   for(int period = scan_min; period <= scan_max; ++period)
     {
      double cos_part = 0.0;
      double sin_part = 0.0;
      for(int k = 0; k < window; ++k)
        {
         const double angle = 2.0 * QM1548_PI * (double)k / (double)period;
         cos_part += i_comp[k] * MathCos(angle);
         sin_part += q_comp[k] * MathSin(angle);
        }

      const double power = cos_part * cos_part + sin_part * sin_part;
      power_sum += power;
      count++;
      if(power > max_power)
        {
         max_power = power;
         best_period = period;
        }
     }

   if(count <= 0 || power_sum <= 0.0 || max_power <= 0.0)
      return false;

   g_dominant_period = best_period;
   g_cycle_clarity = max_power / (power_sum / (double)count);
   return true;
  }

bool QM1548_UpdateState()
  {
   const datetime closed_bar = iTime(_Symbol, PERIOD_H4, 1);
   if(closed_bar <= 0)
      return false;
   if(closed_bar == g_cached_closed_bar)
      return true;

   if(!QM1548_UpdateRoofing())
      return false;
   if(!QM1548_UpdateHilbertDft())
      return false;

   g_cached_closed_bar = closed_bar;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(QM1548_HasOpenPosition())
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return true;

   if((ask - bid) > strategy_spread_atr_mult * atr)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!QM1548_UpdateState())
      return false;

   if(g_cycle_clarity < strategy_entry_clarity)
      return false;
   if(g_dominant_period < strategy_trade_min_period || g_dominant_period > strategy_trade_max_period)
      return false;

   QM_OrderType side = QM_BUY;
   if(g_rf_prev < 0.0 && g_rf_last > 0.0)
      side = QM_BUY;
   else if(g_rf_prev > 0.0 && g_rf_last < 0.0)
      side = QM_SELL;
   else
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.sl = sl;
   req.reason = StringFormat("QM5_1548_RF_CROSS_DFT period=%d clarity=%.3f",
                             g_dominant_period,
                             g_cycle_clarity);
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   QM1548_UpdateState();

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(g_cycle_clarity > 0.0 && g_cycle_clarity < strategy_exit_clarity)
         return true;

      if(pos_type == POSITION_TYPE_BUY && g_rf_prev > 0.0 && g_rf_last < 0.0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && g_rf_prev < 0.0 && g_rf_last > 0.0)
         return true;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_since_entry = iBarShift(_Symbol, PERIOD_H4, open_time, false);
      const int max_hold_bars = (g_dominant_period > 0)
                                ? (int)MathCeil(strategy_time_stop_fraction * (double)g_dominant_period)
                                : 0;
      if(max_hold_bars > 0 && bars_since_entry >= max_hold_bars)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1548\",\"strategy\":\"ehlers_hilbert_transform_dft_h4\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
