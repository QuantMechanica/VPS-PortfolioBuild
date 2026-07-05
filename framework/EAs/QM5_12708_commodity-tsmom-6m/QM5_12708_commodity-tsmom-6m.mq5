#property strict
#property version   "5.1"
#property description "QM5_12708 Commodity TS-MOM 6-Month (Zhang & Urquhart 2021)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12708 - Commodity Time-Series Momentum 6-Month (TS-MOM J=6, K=1)
// -----------------------------------------------------------------------------
// Single-symbol sleeve, deployed independently per commodity (XAUUSD, XAGUSD,
// XTIUSD, XNGUSD). Monthly D1 rebalance: sign of the trailing 6-month
// (126 trading-day) return sets the direction; hold, flip, or open
// flat -> directional once per calendar month. Hard stop at 2.0x ATR(D1,20),
// fixed for the month (no trailing/BE/partial).
// Card: artifacts/cards_approved/QM5_12708_commodity-tsmom-6m.md
// Rebuild-in-place 2026-07-05 (DL-069): prior version hand-rolled an iTime
// month-key gate (flagged framework_corset by review) and produced exactly
// 1 trade then permanent silence in smoke; replaced with the sanctioned
// QM_IsNewCalendarPeriod helper and rebuilt for the current 4-symbol card.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12708;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// Card Zusaetzliche Filter: skip entry near major commodity events
// (EIA, FOMC, NFP). Closest built-in temporal mode to the card's "+/-48h"
// blackout intent is the framework SKIP_DAY mode (24h pre + 24h post around
// the news day) restricted to qm_news_min_impact="high".
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_SKIP_DAY;
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
input int    strategy_formation_bars    = 126;   // Card Entry #1: R6 lookback, 6M ~= 126 trading days (J=6)
input int    strategy_atr_period        = 20;    // Card Stop Loss: ATR(D1,20)
input double strategy_atr_stop_mult     = 2.0;   // Card Stop Loss: 2.0x ATR hard stop
input double strategy_min_atr_pct       = 0.003; // Card Filter: ATR(20)/Close > 0.003

bool Strategy_CurrentPosition(int &direction, ulong &ticket)
  {
   direction = 0;
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      direction = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      ticket = t;
      return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;
   if(strategy_formation_bars < 20)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_stop_mult <= 0.0)
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

   // Card Entry: evaluate exactly once, on the first D1 bar of each calendar
   // month. MN1 bars are untestable on .DWX (0 bars); QM_IsNewCalendarPeriod
   // derives the month key from D1 bar time internally and latches per
   // (symbol, period) so it fires exactly once per real calendar month.
   if(!QM_IsNewCalendarPeriod(PERIOD_MN1))
      return false;

   const double close_last = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(close_last <= 0.0 || atr <= 0.0)
      return false;

   // Card Zusaetzliche Filter: minimum ATR filter, ATR(20)/Close > 0.003.
   if(atr / close_last <= strategy_min_atr_pct)
      return false;

   // Card Entry #1: R6 = (Close[0]-Close[126])/Close[126] on the last closed
   // bar. QM_Momentum(shift=1) reads iMomentum's Close[1]/Close[1+period]*100,
   // so r6 = mom/100 - 1 reproduces the card's ratio without a raw iClose call.
   const double mom = QM_Momentum(_Symbol, PERIOD_D1, strategy_formation_bars, 1, PRICE_CLOSE);
   if(mom <= 0.0)
      return false;
   const double r6 = mom / 100.0 - 1.0;

   const int target_dir = (r6 > 0.0) ? 1 : ((r6 < 0.0) ? -1 : 0);
   if(target_dir == 0)
      return false;

   int current_dir = 0;
   ulong current_ticket = 0;
   Strategy_CurrentPosition(current_dir, current_ticket);

   // Card Entry #6: hold if signal matches current direction.
   if(target_dir == current_dir)
      return false;

   // Card Entry #4/#5: flip -- close the opposite-direction position first.
   if(current_ticket != 0)
      QM_TM_ClosePosition(current_ticket, QM_EXIT_OPPOSITE_SIGNAL);

   req.type = (target_dir > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr, strategy_atr_stop_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (target_dir > 0) ? "TSMOM6_LONG" : "TSMOM6_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card Stop Loss: hard stop is fixed for the 1-month holding window --
   // no trailing, no break-even, no partial close.
  }

bool Strategy_ExitSignal()
  {
   // Card Exit: exits are the hard ATR stop (broker-side SL) and the monthly
   // flip handled inside Strategy_EntrySignal; no separate discretionary exit.
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to the framework's two-axis QM_NewsAllowsTrade2 gate
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12708_commodity-tsmom-6m\"}");
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

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management (none) then discretionary exit (none). Kept
   // above the news gate per the 2026-07-02 OnTick-ordering rule: management
   // must keep running through news windows even though this EA has no
   // trailing logic today.
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

   // News blackout gates NEW entries only, below management/exit -- the ATR
   // hard stop is broker-side and keeps enforcing through news windows.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

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
