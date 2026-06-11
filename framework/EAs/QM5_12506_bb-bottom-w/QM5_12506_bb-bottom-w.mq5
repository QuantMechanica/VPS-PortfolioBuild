#property strict
#property version   "5.0"
#property description "QM5_12506 Bollinger Bottom-W Reversal (bb-bottom-w)"

#include <QM/QM_Common.mqh>

// ============================================================================
// Strategy: Bollinger Bottom-W Reversal
// Enter long when the most recent closed-bar close breaks above the upper
// Bollinger band AND a W-bottom (two touches of the lower band separated by a
// mid-band recovery) is detected within the last pattern_horizon bars.
// Exit: BB bandwidth contracts below beta_atr_fraction * ATR (volatility
// squeeze), plus ATR-based trailing stop as the primary exit.
// Emergency SL: sl_atr_mult * ATR from entry.
// Source: je-suis-tm Bollinger Bands Pattern Recognition (GitHub).
// ============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 12506;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours              = 336;
input string qm_news_min_impact                   = "high";
input QM_NewsMode qm_news_mode_legacy             = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_bb_period           = 20;   // Bollinger SMA period
input double strategy_bb_deviation        = 2.0;  // Bollinger sigma multiplier
input int    strategy_atr_period          = 20;   // ATR period for SL/exit/alpha/beta
input int    strategy_pattern_horizon     = 75;   // bars to scan for W-bottom pattern
input double strategy_alpha_atr_fraction  = 0.05; // tolerance for band-touch = fraction of ATR
input double strategy_beta_atr_fraction   = 0.05; // BB-width exit threshold = fraction of ATR
input double strategy_sl_atr_mult         = 3.0;  // emergency SL = mult * ATR below entry

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

bool HasOpenPosition()
  {
   const long magic = (long)QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

// Scan rates[offset .. offset+count-1] for the Bollinger W-bottom pattern.
// rates[] is AS_SERIES (index 0 = most recent closed bar).
// Pattern (chronological, oldest→newest):
//   first_bottom : close <= lower + alpha_thr
//   middle_node  : |close - middle| <= alpha_thr  (after first_bottom)
//   second_bottom: close <= lower + alpha_thr AND close <= first_bottom_close (after middle_node)
bool FindBottomW(const MqlRates &rates[], const int offset, const int count,
                 const double lower, const double middle, const double alpha_thr)
  {
   const int end = offset + count;
   for(int i = end - 1; i >= offset + 2; i--)
     {
      if(rates[i].close > lower + alpha_thr) continue;
      const double first_close = rates[i].close;
      for(int j = i - 1; j >= offset + 1; j--)
        {
         if(MathAbs(rates[j].close - middle) > alpha_thr) continue;
         for(int k = j - 1; k >= offset; k--)
           {
            if(rates[k].close <= lower + alpha_thr &&
               rates[k].close <= first_close)
               return true;
           }
        }
     }
   return false;
  }

// ---------------------------------------------------------------------------
// Strategy hooks
// ---------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Called only when QM_IsNewBar() == true (gated in OnTick below).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(HasOpenPosition()) return false;

   const int ph = strategy_pattern_horizon;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // Shift=1: rates[0]=last closed bar, rates[1..ph]=pattern window
   if(CopyRates(_Symbol, _Period, 1, ph + 1, rates) < ph + 1) return false;

   const double upper  = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double middle = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower  = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double atr    = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);

   if(upper <= 0.0 || lower <= 0.0 || atr <= 0.0) return false;

   // Entry trigger: last closed bar's close above upper BB
   if(rates[0].close <= upper) return false;

   const double alpha_thr = strategy_alpha_atr_fraction * atr;

   // W-pattern must be complete in bars[1..ph] (older than current entry bar)
   if(!FindBottomW(rates, 1, ph, lower, middle, alpha_thr)) return false;

   const double ask      = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double sl_price = ask - strategy_sl_atr_mult * atr;
   if(sl_price <= 0.0) return false;

   req.type               = QM_BUY;
   req.price              = 0.0;   // market order
   req.sl                 = sl_price;
   req.tp                 = 0.0;   // no fixed TP; exit by volatility squeeze or trail
   req.reason             = "bb-bottom-w";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const long magic = (long)QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_sl_atr_mult);
     }
  }

// Volatility-squeeze exit: close when BB bandwidth < beta threshold.
bool Strategy_ExitSignal()
  {
   if(!HasOpenPosition()) return false;

   const double upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double atr   = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0) return false;

   return ((upper - lower) < strategy_beta_atr_fraction * atr);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// ---------------------------------------------------------------------------
// Framework wiring
// ---------------------------------------------------------------------------

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
      const long magic = (long)QM_FrameworkMagic();
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
