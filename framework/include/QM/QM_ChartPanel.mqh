#ifndef QM_CHARTPANEL_MQH
#define QM_CHARTPANEL_MQH

#include <QM/QM_ChartScheme.mqh>

// QuantMechanica Signature Chart Panel v2.
// Presentation only: creates chart objects and reads account/position history.
// It never sends, changes, or closes orders. Refresh from OnTimer, never OnTick.

#define QM_PANEL_FONT      "Segoe UI"
#define QM_PANEL_FONT_MONO "Consolas"

struct QMChartPanelSnapshot
  {
   string trading_state;
   string trading_reason;
   string news_state;
   string news_detail;
   string friday_state;
   string friday_countdown;
   string governor_state;
   string governor_reason;
   string kill_switch_state;
   string spread_state;
   string session_state;
   string risk_mode;
   string risk_per_trade;
   string effective_risk;
   string daily_room;
   string total_room;
   string last_signal;
   string calendar_health;
   string heartbeat_state;
   string build_version;
   string support_line;
  };

string QM_PanelAscii(const string value)
  {
   string out = "";
   for(int i = 0; i < StringLen(value); ++i)
     {
      const ushort ch = StringGetCharacter(value, i);
      out += ShortToString((ushort)((ch >= 32 && ch <= 126) ? ch : 32));
     }
   return out;
  }

string QM_PanelTimeframeName(const ENUM_TIMEFRAMES value)
  {
   string name = EnumToString(value);
   if(StringFind(name, "PERIOD_") == 0)
      return StringSubstr(name, 7);
   return name;
  }

string QM_PanelDuration(const long raw_seconds)
  {
   const long seconds = MathMax(0, raw_seconds);
   const long days = seconds / 86400;
   const long hours = (seconds % 86400) / 3600;
   const long minutes = (seconds % 3600) / 60;
   const long secs = seconds % 60;
   if(days > 0)
      return StringFormat("%dd %02d:%02d", days, hours, minutes);
   return StringFormat("%02d:%02d:%02d", hours, minutes, secs);
  }

string QM_PanelMaskedLogin()
  {
   const string login = StringFormat("%I64d", AccountInfoInteger(ACCOUNT_LOGIN));
   if(StringLen(login) <= 4)
      return "****";
   return "****" + StringSubstr(login, StringLen(login) - 4);
  }

string QM_PanelEnvironment()
  {
   const long mode = AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode == ACCOUNT_TRADE_MODE_REAL)
      return "LIVE";
   if(mode == ACCOUNT_TRADE_MODE_DEMO)
      return "DEMO";
   if(mode == ACCOUNT_TRADE_MODE_CONTEST)
      return "CONTEST";
   return "UNKNOWN";
  }

string QM_PanelSignedMoney(const double value)
  {
   return StringFormat("%s%.2f", value > 0.0 ? "+" : "", value);
  }

string QM_PanelNextBar()
  {
   const int seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   const datetime bar = iTime(_Symbol, (ENUM_TIMEFRAMES)_Period, 0);
   if(seconds <= 0 || bar <= 0)
      return "N/A (bar clock unavailable)";
   const datetime next = bar + seconds;
   return TimeToString(next, TIME_DATE | TIME_SECONDS) +
          " (" + QM_PanelDuration((long)(next - TimeCurrent())) + ")";
  }

string QM_PanelPositionSummary(const long magic,
                               double &risk_money,
                               int &without_stop)
  {
   int count = 0;
   string first = "NONE";
   risk_money = 0.0;
   without_stop = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket) ||
         (long)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ++count;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      const double lots = PositionGetDouble(POSITION_VOLUME);
      const double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      const double tp = PositionGetDouble(POSITION_TP);
      const double pnl = PositionGetDouble(POSITION_PROFIT) +
                         PositionGetDouble(POSITION_SWAP);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const long type = PositionGetInteger(POSITION_TYPE);
      if(sl <= 0.0)
         ++without_stop;
      else
        {
         double projected = 0.0;
         const ENUM_ORDER_TYPE order_type =
            (type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         if(OrderCalcProfit(order_type, symbol, lots, entry, sl, projected))
            risk_money += MathAbs(MathMin(0.0, projected));
         else
            ++without_stop;
        }
      if(first == "NONE")
         first = StringFormat("%s %.2f @%.*f SL%.*f TP%.*f P/L %s OPEN %s",
                              type == POSITION_TYPE_BUY ? "BUY" : "SELL",
                              lots, digits, entry, digits, sl, digits, tp,
                              QM_PanelSignedMoney(pnl),
                              QM_PanelDuration((long)(TimeCurrent() - opened)));
     }
   if(count > 1)
      first += StringFormat(" +%d MORE", count - 1);
   return first;
  }

string QM_PanelPendingSummary(const long magic)
  {
   int count = 0;
   string first = "NONE";
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket) ||
         (long)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      ++count;
      if(first == "NONE")
        {
         const string symbol = OrderGetString(ORDER_SYMBOL);
         const datetime expiry = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
         first = StringFormat("%s %.2f @%.*f EXP %s",
                              EnumToString((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)),
                              OrderGetDouble(ORDER_VOLUME_CURRENT),
                              (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS),
                              OrderGetDouble(ORDER_PRICE_OPEN),
                              expiry > 0 ? TimeToString(expiry, TIME_DATE | TIME_MINUTES)
                                         : "GTC");
        }
     }
   if(count > 1)
      first += StringFormat(" +%d MORE", count - 1);
   return first;
  }

string QM_PanelTodayAndLastTrade(const long magic, string &last_trade)
  {
   MqlDateTime day;
   TimeToStruct(TimeCurrent(), day);
   day.hour = 0;
   day.min = 0;
   day.sec = 0;
   const datetime start = StructToTime(day);
   const datetime now = TimeCurrent();
   if(!HistorySelect(start, now))
     {
      last_trade = "N/A (history unavailable)";
      return "N/A (history unavailable)";
     }
   double pnl = 0.0;
   int trades = 0;
   datetime latest = 0;
   double latest_pnl = 0.0;
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 || (long)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      const long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         continue;
      const double value = HistoryDealGetDouble(deal, DEAL_PROFIT) +
                           HistoryDealGetDouble(deal, DEAL_SWAP) +
                           HistoryDealGetDouble(deal, DEAL_COMMISSION);
      const datetime when = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      pnl += value;
      ++trades;
      if(when >= latest)
        {
         latest = when;
         latest_pnl = value;
        }
     }
   last_trade = (latest > 0)
      ? QM_PanelSignedMoney(latest_pnl) + " @" +
        TimeToString(latest, TIME_DATE | TIME_MINUTES)
      : "NONE";
   return StringFormat("%s (%d trades)", QM_PanelSignedMoney(pnl), trades);
  }

class CQMChartPanel
  {
private:
   long m_chart;
   string m_prefix;
   string m_ea_id;
   string m_slug;
   long m_magic;
   string m_build_hash;
   bool m_ready;
   int m_corner;
   int m_x;
   int m_y;

   string Name(const string suffix) const { return m_prefix + suffix; }

   bool MakeRect(const string suffix, const int x, const int y,
                 const int width, const int height,
                 const color background, const color border)
     {
      const string name = Name(suffix);
      if(ObjectFind(m_chart, name) < 0 &&
         !ObjectCreate(m_chart, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return false;
      ObjectSetInteger(m_chart, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(m_chart, name, OBJPROP_XDISTANCE, m_x + x);
      ObjectSetInteger(m_chart, name, OBJPROP_YDISTANCE, m_y + y);
      ObjectSetInteger(m_chart, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(m_chart, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(m_chart, name, OBJPROP_BGCOLOR, background);
      ObjectSetInteger(m_chart, name, OBJPROP_BORDER_COLOR, border);
      ObjectSetInteger(m_chart, name, OBJPROP_BACK, false);
      ObjectSetInteger(m_chart, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chart, name, OBJPROP_ZORDER, 900);
      return true;
     }

   bool MakeLabel(const string suffix, const int x, const int y,
                  const string value, const color foreground,
                  const int font_size, const string font = QM_PANEL_FONT_MONO)
     {
      const string name = Name(suffix);
      if(ObjectFind(m_chart, name) < 0 &&
         !ObjectCreate(m_chart, name, OBJ_LABEL, 0, 0, 0))
         return false;
      ObjectSetInteger(m_chart, name, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(m_chart, name, OBJPROP_XDISTANCE, m_x + x);
      ObjectSetInteger(m_chart, name, OBJPROP_YDISTANCE, m_y + y);
      ObjectSetInteger(m_chart, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(m_chart, name, OBJPROP_COLOR, foreground);
      ObjectSetInteger(m_chart, name, OBJPROP_FONTSIZE, font_size);
      ObjectSetInteger(m_chart, name, OBJPROP_BACK, false);
      ObjectSetInteger(m_chart, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chart, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(m_chart, name, OBJPROP_ZORDER, 910);
      ObjectSetString(m_chart, name, OBJPROP_FONT, font);
      ObjectSetString(m_chart, name, OBJPROP_TEXT, QM_PanelAscii(value));
      return true;
     }

   void SetText(const int line, const string value, const color foreground)
     {
      const string name = Name(StringFormat("line_%02d", line));
      ObjectSetString(m_chart, name, OBJPROP_TEXT, QM_PanelAscii(value));
      ObjectSetInteger(m_chart, name, OBJPROP_COLOR, foreground);
     }

   color StateColor(const string value) const
     {
      string state = value;
      StringToUpper(state);
      if(StringFind(state, "NO") >= 0 || StringFind(state, "BLOCK") >= 0 ||
         StringFind(state, "HALT") >= 0 || StringFind(state, "FAIL") >= 0 ||
         StringFind(state, "STALE") >= 0 || StringFind(state, "DOWN") >= 0)
         return QM_SCHEME_RED;
      if(StringFind(state, "N/A") >= 0 || StringFind(state, "UNBOUND") >= 0 ||
         StringFind(state, "NEAR") >= 0)
         return QM_SCHEME_AMBER;
      return QM_SCHEME_EMERALD;
     }

public:
   CQMChartPanel(void)
     {
      m_chart = 0;
      m_prefix = "";
      m_ea_id = "";
      m_slug = "";
      m_magic = 0;
      m_build_hash = "";
      m_ready = false;
      m_corner = CORNER_LEFT_UPPER;
      m_x = 16;
      m_y = 24;
     }

   bool Initialize(const long chart_id, const int ea_id, const string slug,
                   const long magic, const string build_hash,
                   const bool enabled = true,
                   const int corner = CORNER_LEFT_UPPER,
                   const int x = 16, const int y = 24)
     {
      m_ready = false;
      if(!enabled || MQLInfoInteger(MQL_TESTER) != 0)
         return false;
      m_chart = chart_id;
      m_ea_id = IntegerToString(ea_id);
      m_slug = QM_PanelAscii(slug);
      m_magic = magic;
      m_build_hash = QM_PanelAscii(build_hash);
      m_corner = corner;
      m_x = x;
      m_y = y;
      m_prefix = "QM_SIG_" + m_ea_id + "_" + StringFormat("%I64d", magic) + "_";

      if(!MakeRect("bg", 0, 0, 570, 410, QM_SCHEME_SURFACE, QM_SCHEME_BORDER)) return false;
      if(!MakeRect("rail", 0, 0, 5, 410, QM_SCHEME_STEEL, QM_SCHEME_STEEL)) return false;
      if(!MakeLabel("brand", 18, 10, "QM | QUANTMECHANICA", QM_SCHEME_STEEL, 11, QM_PANEL_FONT)) return false;
      for(int line = 0; line < 18; ++line)
         if(!MakeLabel(StringFormat("line_%02d", line), 18, 36 + line * 19,
                       "-", QM_SCHEME_TEXT, 8)) return false;
      if(!MakeLabel("footer", 18, 382, "Support: MQL5 comments/messages",
                    QM_SCHEME_MUTED, 8, QM_PANEL_FONT)) return false;
      m_ready = true;
      return true;
     }

   bool Ready(void) const { return m_ready; }

   void Refresh(const QMChartPanelSnapshot &snapshot)
     {
      if(!m_ready)
         return;
      const double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double risk_money = 0.0;
      int without_stop = 0;
      const string position = QM_PanelPositionSummary(m_magic, risk_money, without_stop);
      const string pending = QM_PanelPendingSummary(m_magic);
      string last_trade = "NONE";
      const string today = QM_PanelTodayAndLastTrade(m_magic, last_trade);
      MqlTick tick;
      const bool tick_ok = SymbolInfoTick(_Symbol, tick);
      const long tick_age_ms = tick_ok ? (long)(TimeCurrent() - tick.time) * 1000 : -1;
      const string connection = TerminalInfoInteger(TERMINAL_CONNECTED) ? "UP" : "DOWN";
      const string risk_text = without_stop > 0
         ? StringFormat("UNPRICED (%d without SL)", without_stop)
         : QM_PanelSignedMoney(risk_money);

      SetText(0, "EA QM5_" + m_ea_id + " | " + m_slug + " | v" +
                 snapshot.build_version + " | BUILD " + StringSubstr(m_build_hash, 0, 8),
              QM_SCHEME_TEXT);
      SetText(1, _Symbol + " / " + QM_PanelTimeframeName((ENUM_TIMEFRAMES)_Period) +
                 " | MAGIC " + StringFormat("%I64d", m_magic) + " | " +
                 QM_PanelEnvironment() + " | LOGIN " + QM_PanelMaskedLogin(), QM_SCHEME_MUTED);
      SetText(2, "TRADING " + snapshot.trading_state + " | " + snapshot.trading_reason,
              StateColor(snapshot.trading_state));
      SetText(3, "NEWS " + snapshot.news_state + " | " + snapshot.news_detail,
              StateColor(snapshot.news_state));
      SetText(4, "GOV " + snapshot.governor_state + " " + snapshot.governor_reason +
                 " | KS " + snapshot.kill_switch_state,
              StateColor(snapshot.governor_state + " " + snapshot.kill_switch_state));
      SetText(5, "FRI " + snapshot.friday_state + " " + snapshot.friday_countdown +
                 " | SPREAD " + snapshot.spread_state + " | SESSION " + snapshot.session_state,
              StateColor(snapshot.friday_state + " " + snapshot.spread_state));
      SetText(6, "RISK " + snapshot.risk_mode + " " + snapshot.risk_per_trade +
                 " | EFFECTIVE " + snapshot.effective_risk, QM_SCHEME_TEXT);
      SetText(7, "ROOM DAILY " + snapshot.daily_room + " | TOTAL " + snapshot.total_room,
              StateColor(snapshot.daily_room + " " + snapshot.total_room));
      SetText(8, "EXPOSURE SL " + risk_text, without_stop > 0 ? QM_SCHEME_RED : QM_SCHEME_TEXT);
      SetText(9, "BAL " + DoubleToString(balance, 2) + " | EQ " + DoubleToString(equity, 2) +
                 " | TODAY " + today, QM_SCHEME_TEXT);
      SetText(10, "POS " + position, QM_SCHEME_TEXT);
      SetText(11, "ORD " + pending, QM_SCHEME_TEXT);
      SetText(12, "NEXT BAR " + QM_PanelNextBar(), QM_SCHEME_TEXT);
      SetText(13, "LAST SIGNAL " + snapshot.last_signal, QM_SCHEME_MUTED);
      SetText(14, "LAST TRADE " + last_trade, QM_SCHEME_MUTED);
      SetText(15, "HEALTH HB " + snapshot.heartbeat_state + " | TICK " +
                  (tick_age_ms >= 0 ? IntegerToString((int)tick_age_ms) + "ms" : "N/A") +
                  " | CONNECTION " + connection,
              StateColor(snapshot.heartbeat_state + " " + connection));
      SetText(16, "CAL " + snapshot.calendar_health, StateColor(snapshot.calendar_health));
      SetText(17, "LICENSE " + EnumToString((ENUM_LICENSE_TYPE)MQLInfoInteger(MQL_LICENSE_TYPE)) +
                  " | " + snapshot.support_line, QM_SCHEME_MUTED);
      ChartRedraw(m_chart);
     }

   void Shutdown(void)
     {
      if(m_prefix == "")
         return;
      ObjectDelete(m_chart, Name("footer"));
      for(int line = 0; line < 18; ++line)
         ObjectDelete(m_chart, Name(StringFormat("line_%02d", line)));
      ObjectDelete(m_chart, Name("brand"));
      ObjectDelete(m_chart, Name("rail"));
      ObjectDelete(m_chart, Name("bg"));
      ChartRedraw(m_chart);
      m_ready = false;
     }
  };

#endif // QM_CHARTPANEL_MQH
