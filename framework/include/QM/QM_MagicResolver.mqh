#ifndef QM_MAGIC_RESOLVER_MQH
#define QM_MAGIC_RESOLVER_MQH

#include "QM_Errors.mqh"

// V5 Framework Step 04:
// - canonical magic computation: magic = ea_id * 10000 + symbol_slot
// - baked registry snapshot (seed row for framework bring-up)
// - runtime collision guard against foreign open positions

#define QM_MAGIC_EA_ID_MIN 1000
#define QM_MAGIC_EA_ID_MAX 9999
#define QM_MAGIC_SLOT_MIN  0
#define QM_MAGIC_SLOT_MAX  9999

// SHA256 of framework/registry/magic_numbers.csv baked into the binary at build time.
#define QM_MAGIC_REGISTRY_SHA256 "A0C9475582A0D9745E7BC317F796CD6E7C6C6FB6EDC70E3431ED6DA5A06F612F"

#define QM_MAGIC_REGISTRY_ROWS 11
static const int    QM_MAGIC_REG_EA_ID[QM_MAGIC_REGISTRY_ROWS]   = {1001,40303,40303,40303,40303,40303,4303,4303,4303,4303,4303};
static const int    QM_MAGIC_REG_SLOT[QM_MAGIC_REGISTRY_ROWS]    = {0,0,1,2,3,4,0,1,2,3,4};
static const string QM_MAGIC_REG_SYMBOL[QM_MAGIC_REGISTRY_ROWS]  = {"EURUSD.DWX","EURUSD.DWX","GBPUSD.DWX","USDJPY.DWX","USDCAD.DWX","AUDUSD.DWX","EURUSD.DWX","GBPUSD.DWX","USDJPY.DWX","USDCAD.DWX","AUDUSD.DWX"};
static const int    QM_MAGIC_REG_MAGIC[QM_MAGIC_REGISTRY_ROWS]   = {10010000,403030000,403030001,403030002,403030003,403030004,43030000,43030001,43030002,43030003,43030004};

int QM_Magic(const int ea_id, const int symbol_slot)
{
   static int cache_ea_id = -1;
   static int cache_slot  = -1;
   static int cache_magic = -1;

   if(ea_id == cache_ea_id && symbol_slot == cache_slot)
   {
      return cache_magic;
   }

   if(ea_id < QM_MAGIC_EA_ID_MIN || ea_id > QM_MAGIC_EA_ID_MAX)
   {
      PrintFormat("%s: invalid ea_id=%d", EA_MAGIC_NOT_REGISTERED, ea_id);
      return -1;
   }

   if(symbol_slot < QM_MAGIC_SLOT_MIN || symbol_slot > QM_MAGIC_SLOT_MAX)
   {
      PrintFormat("%s: invalid symbol_slot=%d", EA_MAGIC_NOT_REGISTERED, symbol_slot);
      return -1;
   }

   const long magic64 = (long)ea_id * 10000L + (long)symbol_slot;
   if(magic64 <= 0 || magic64 > 2147483647L)
   {
      PrintFormat("%s: magic out of range ea_id=%d slot=%d", EA_MAGIC_NOT_REGISTERED, ea_id, symbol_slot);
      return -1;
   }

   const int magic = (int)magic64;
   if(magic == 0)
   {
      PrintFormat("%s: computed magic is zero ea_id=%d slot=%d", EA_MAGIC_NOT_REGISTERED, ea_id, symbol_slot);
      return -1;
   }

   cache_ea_id = ea_id;
   cache_slot  = symbol_slot;
   cache_magic = magic;
   return magic;
}

bool QM_MagicRegistered(const int ea_id, const int symbol_slot)
{
   const int computed_magic = QM_Magic(ea_id, symbol_slot);
   if(computed_magic <= 0)
   {
      return false;
   }

   for(int i = 0; i < QM_MAGIC_REGISTRY_ROWS; ++i)
   {
      if(QM_MAGIC_REG_EA_ID[i] == ea_id && QM_MAGIC_REG_SLOT[i] == symbol_slot)
      {
         return (QM_MAGIC_REG_MAGIC[i] == computed_magic);
      }
   }

   return false;
}

string QM_MagicRegistryHash()
{
   return QM_MAGIC_REGISTRY_SHA256;
}

bool QM_MagicCollisionWithForeignOpenPositions(const int magic, const string expected_symbol = "")
{
   if(magic <= 0)
   {
      return true;
   }

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
      {
         continue;
      }

      const long position_magic = PositionGetInteger(POSITION_MAGIC);
      if((int)position_magic != magic)
      {
         continue;
      }

      const string position_symbol = PositionGetString(POSITION_SYMBOL);
      if(expected_symbol != "" && position_symbol == expected_symbol)
      {
         continue;
      }

      PrintFormat("%s: magic=%d conflicts with ticket=%I64u symbol=%s expected_symbol=%s",
                  EA_MAGIC_COLLISION_DETECTED,
                  magic,
                  ticket,
                  position_symbol,
                  expected_symbol);
      return true;
   }

   return false;
}

int QM_MagicChecked(const int ea_id, const int symbol_slot, const string expected_symbol = "")
{
   const int magic = QM_Magic(ea_id, symbol_slot);
   if(magic <= 0)
   {
      return -1;
   }

   if(!QM_MagicRegistered(ea_id, symbol_slot))
   {
      PrintFormat("%s: ea_id=%d slot=%d magic=%d", EA_MAGIC_NOT_REGISTERED, ea_id, symbol_slot, magic);
      return -1;
   }

   if(QM_MagicCollisionWithForeignOpenPositions(magic, expected_symbol))
   {
      return -1;
   }

   return magic;
}

#endif // QM_MAGIC_RESOLVER_MQH
