#ifndef QM_CHARTPANEL_MQH
#define QM_CHARTPANEL_MQH

// QuantMechanica Signature Chart Panel.
// Presentation only: this include creates chart objects and reads positions.
// It never sends, changes, or closes orders. Call Refresh() from OnTimer, not OnTick.

#define QM_PANEL_BG          C'15,23,42'
#define QM_PANEL_SURFACE     C'30,41,59'
#define QM_PANEL_BORDER      C'71,85,105'
#define QM_PANEL_TEXT        C'226,232,240'
#define QM_PANEL_MUTED       C'148,163,184'
#define QM_PANEL_STEEL       C'41,84,212'
#define QM_PANEL_EMERALD     C'16,185,129'
#define QM_PANEL_AMBER       C'245,158,11'
#define QM_PANEL_RED         C'239,68,68'
#define QM_PANEL_FONT        "Segoe UI"
#define QM_PANEL_FONT_MONO   "Consolas"

struct QMChartPanelSnapshot
  {
   string news_state;
   string friday_state;
   string governor_state;
   string environment;
   string risk_mode;
   string risk_per_trade;
   string heartbeat_state;
  };

string QM_PanelAscii(const string value)
  {
   string out = "";
   for(int i = 0; i < StringLen(value); ++i)
     {
      ushort ch = StringGetCharacter(value, i);
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

double QM_PanelExposureForMagic(const long magic)
  {
   double exposure = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double price = PositionGetDouble(POSITION_PRICE_CURRENT);
      const double contract = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL),
                                               SYMBOL_TRADE_CONTRACT_SIZE);
      if(volume > 0.0 && price > 0.0 && contract > 0.0)
         exposure += volume * price * contract;
     }
   return exposure;
  }

class CQMChartPanel
  {
private:
   long              m_chart;
   string            m_prefix;
   string            m_ea_id;
   string            m_slug;
   long              m_magic;
   string            m_build_hash;
   bool              m_ready;
   int               m_corner;
   int               m_x;
   int               m_y;

   string Name(const string suffix) const { return m_prefix + suffix; }

   bool MakeRect(const string suffix,
                 const int x,
                 const int y,
                 const int width,
                 const int height,
                 const color background,
                 const color border)
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

   bool MakeLabel(const string suffix,
                  const int x,
                  const int y,
                  const string text,
                  const color foreground,
                  const int font_size,
                  const string font = QM_PANEL_FONT)
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
      ObjectSetString(m_chart, name, OBJPROP_TEXT, QM_PanelAscii(text));
      return true;
     }

   void SetText(const string suffix, const string text, const color foreground)
     {
      const string name = Name(suffix);
      if(ObjectFind(m_chart, name) < 0)
         return;
      ObjectSetString(m_chart, name, OBJPROP_TEXT, QM_PanelAscii(text));
      ObjectSetInteger(m_chart, name, OBJPROP_COLOR, foreground);
     }

   color StateColor(const string value) const
     {
      string state = value;
      StringToUpper(state);
      if(StringFind(state, "OK") >= 0 || StringFind(state, "OPEN") >= 0 ||
         StringFind(state, "RUN") >= 0 || StringFind(state, "ARM") >= 0)
         return QM_PANEL_EMERALD;
      if(StringFind(state, "HALT") >= 0 || StringFind(state, "BLOCK") >= 0 ||
         StringFind(state, "FAIL") >= 0 || StringFind(state, "STALE") >= 0)
         return QM_PANEL_RED;
      return QM_PANEL_AMBER;
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

   bool Initialize(const long chart_id,
                   const int ea_id,
                   const string slug,
                   const long magic,
                   const string build_hash,
                   const bool enabled = true,
                   const int corner = CORNER_LEFT_UPPER,
                   const int x = 16,
                   const int y = 24)
     {
      m_ready = false;
      if(!enabled)
         return false;
      if(MQLInfoInteger(MQL_TESTER) != 0 && MQLInfoInteger(MQL_VISUAL_MODE) == 0)
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

      if(!MakeRect("bg", 0, 0, 360, 210, QM_PANEL_BG, QM_PANEL_BORDER)) return false;
      if(!MakeRect("rail", 0, 0, 5, 210, QM_PANEL_STEEL, QM_PANEL_STEEL)) return false;
      if(!MakeLabel("brand", 18, 12, "QM | QUANTMECHANICA", QM_PANEL_TEXT, 11)) return false;
      if(!MakeLabel("identity", 18, 38, "", QM_PANEL_TEXT, 9, QM_PANEL_FONT_MONO)) return false;
      if(!MakeLabel("context", 18, 58, "", QM_PANEL_MUTED, 9, QM_PANEL_FONT_MONO)) return false;
      if(!MakeLabel("governance_key", 18, 84, "GOVERNANCE", QM_PANEL_MUTED, 8)) return false;
      if(!MakeLabel("governance", 18, 101, "", QM_PANEL_AMBER, 9, QM_PANEL_FONT_MONO)) return false;
      if(!MakeLabel("risk_key", 18, 126, "RISK / EXPOSURE", QM_PANEL_MUTED, 8)) return false;
      if(!MakeLabel("risk", 18, 143, "", QM_PANEL_TEXT, 9, QM_PANEL_FONT_MONO)) return false;
      if(!MakeLabel("heartbeat", 18, 177, "", QM_PANEL_MUTED, 8, QM_PANEL_FONT_MONO)) return false;

      m_ready = true;
      return true;
     }

   bool Ready(void) const { return m_ready; }

   void Refresh(const QMChartPanelSnapshot &snapshot)
     {
      if(!m_ready)
         return;

      SetText("identity", "EA " + m_ea_id + " | " + m_slug, QM_PANEL_TEXT);
      SetText("context", _Symbol + " / " + QM_PanelTimeframeName((ENUM_TIMEFRAMES)_Period) +
              " | MAGIC " + StringFormat("%I64d", m_magic), QM_PANEL_MUTED);

      const string governance = "NEWS " + snapshot.news_state + " | FRI " +
                                snapshot.friday_state + " | GOV " +
                                snapshot.governor_state + " | " +
                                snapshot.environment;
      SetText("governance", governance, StateColor(governance));

      const double exposure = QM_PanelExposureForMagic(m_magic);
      SetText("risk", snapshot.risk_mode + " " + snapshot.risk_per_trade +
              " | OPEN " + DoubleToString(exposure, 2), QM_PANEL_TEXT);

      SetText("heartbeat", "HB " + snapshot.heartbeat_state + " | " +
              TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + " | BUILD " +
              m_build_hash, StateColor(snapshot.heartbeat_state));
      ChartRedraw(m_chart);
     }

   void Shutdown(void)
     {
      if(m_prefix == "")
         return;
      ObjectDelete(m_chart, Name("heartbeat"));
      ObjectDelete(m_chart, Name("risk"));
      ObjectDelete(m_chart, Name("risk_key"));
      ObjectDelete(m_chart, Name("governance"));
      ObjectDelete(m_chart, Name("governance_key"));
      ObjectDelete(m_chart, Name("context"));
      ObjectDelete(m_chart, Name("identity"));
      ObjectDelete(m_chart, Name("brand"));
      ObjectDelete(m_chart, Name("rail"));
      ObjectDelete(m_chart, Name("bg"));
      ChartRedraw(m_chart);
      m_ready = false;
     }
  };

#endif // QM_CHARTPANEL_MQH
