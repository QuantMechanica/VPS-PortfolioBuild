#property strict
#property version   "5.0"
#property description "QM5_2001 NNFX Classic SSL"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_2001: The Classic SSL
// -----------------------------------------------------------------------------
// Baseline: Kijun-sen (26 period)
// Confirmation: SSL Channel (10 period SMA of High/Low)
// Volume: ATR Volatility Filter (Current ATR > 14-period MA of ATR)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2001;
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
input int    strategy_kijun_period      = 26;
input int    strategy_ssl_period        = 10;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 1.5;
input double strategy_rr                 = 1.5;
input int    strategy_spread_cap_points  = 25;

// --- SSL Channel Logic ---
double SslHigh(const int shift) { return QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ssl_period, shift, PRICE_HIGH); }
double SslLow(const int shift)  { return QM_SMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ssl_period, shift, PRICE_LOW); }

int SslColor(const int shift)
  {
   const double close = iClose(_Symbol, _Period, shift);
   const double h = SslHigh(shift);
   const double l = SslLow(shift);

   if(close > h) return 1;  // Bullish
   if(close < l) return -1; // Bearish
   return 0;
  }

// --- Kijun-sen Logic ---
double KijunValue(const int shift)
  {
   const double high = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, strategy_kijun_period, shift));
   const double low  = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, strategy_kijun_period, shift));
   return (high + low) / 2.0;
  }

// --- Volume Filter Logic ---
bool VolumeAllowsTrade(const int shift)
  {
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, shift);
   double atr_sum = 0;
   for(int i = 0; i < strategy_atr_period; ++i)
      atr_sum += QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, shift + i);
   const double atr_ma = atr_sum / strategy_atr_period;
   return (atr > atr_ma);
  }

bool HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic) return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_spread_cap_points > 0 && spread > strategy_spread_cap_points) return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(HasOpenPosition()) return false;

   const double close_1 = iClose(_Symbol, _Period, 1);
   const double kijun_1 = KijunValue(1);
   const int ssl_1 = SslColor(1);

   if(!VolumeAllowsTrade(1)) return false;

   if(close_1 > kijun_1 && ssl_1 > 0)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = "NNFX_SSL_LONG";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(close_1 < kijun_1 && ssl_1 < 0)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, QM_EntryMarketPrice(req.type), strategy_atr_period, strategy_atr_sl_mult);
      req.tp = QM_TakeRR(_Symbol, req.type, QM_EntryMarketPrice(req.type), req.sl, strategy_rr);
      req.reason = "NNFX_SSL_SHORT";
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double close_1 = iClose(_Symbol, _Period, 1);
      const double kijun_1 = KijunValue(1);

      if(ptype == POSITION_TYPE_BUY && close_1 < kijun_1) return true;
      if(ptype == POSITION_TYPE_SELL && close_1 > kijun_1) return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, qm_news_mode, qm_friday_close_enabled, qm_friday_close_hour_broker))
      return INIT_FAILED;
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode)) return;
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   if(!QM_IsNewBar()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer() { QM_FrameworkOnTimer(); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
