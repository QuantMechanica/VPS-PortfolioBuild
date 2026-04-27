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
#define QM_MAGIC_REGISTRY_SHA256 "3DE3C276350EE94CA9644945FF79CD17FFFF73349EA7B261A40DA65BA75FE1D4"

#define QM_MAGIC_REGISTRY_ROWS 1
static const int    QM_MAGIC_REG_EA_ID[QM_MAGIC_REGISTRY_ROWS]   = {1001};
static const int    QM_MAGIC_REG_SLOT[QM_MAGIC_REGISTRY_ROWS]    = {0};
static const string QM_MAGIC_REG_SYMBOL[QM_MAGIC_REGISTRY_ROWS]  = {"EURUSD.DWX"};
static const int    QM_MAGIC_REG_MAGIC[QM_MAGIC_REGISTRY_ROWS]   = {10010000};

int QM_Magic(const int magic_ea_id, const int magic_symbol_slot)
{
   static int cache_ea_id = -1;
   static int cache_slot  = -1;
   static int cache_magic = -1;

   if(magic_ea_id == cache_ea_id && magic_symbol_slot == cache_slot)
   {
      return cache_magic;
   }

   if(magic_ea_id < QM_MAGIC_EA_ID_MIN || magic_ea_id > QM_MAGIC_EA_ID_MAX)
   {
      PrintFormat("%s: invalid ea_id=%d", EA_MAGIC_NOT_REGISTERED, magic_ea_id);
      return -1;
   }

   if(magic_symbol_slot < QM_MAGIC_SLOT_MIN || magic_symbol_slot > QM_MAGIC_SLOT_MAX)
   {
      PrintFormat("%s: invalid symbol_slot=%d", EA_MAGIC_NOT_REGISTERED, magic_symbol_slot);
      return -1;
   }

   const long magic64 = (long)magic_ea_id * 10000L + (long)magic_symbol_slot;
   if(magic64 <= 0 || magic64 > 2147483647L)
   {
      PrintFormat("%s: magic out of range ea_id=%d slot=%d", EA_MAGIC_NOT_REGISTERED, magic_ea_id, magic_symbol_slot);
      return -1;
   }

   const int magic = (int)magic64;
   if(magic == 0)
   {
      PrintFormat("%s: computed magic is zero ea_id=%d slot=%d", EA_MAGIC_NOT_REGISTERED, magic_ea_id, magic_symbol_slot);
      return -1;
   }

   cache_ea_id = magic_ea_id;
   cache_slot  = magic_symbol_slot;
   cache_magic = magic;
   return magic;
}

bool QM_MagicRegistered(const int reg_ea_id, const int reg_symbol_slot)
{
   const int computed_magic = QM_Magic(reg_ea_id, reg_symbol_slot);
   if(computed_magic <= 0)
   {
      return false;
   }

   for(int i = 0; i < QM_MAGIC_REGISTRY_ROWS; ++i)
   {
      if(QM_MAGIC_REG_EA_ID[i] == reg_ea_id && QM_MAGIC_REG_SLOT[i] == reg_symbol_slot)
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

int QM_MagicChecked(const int checked_ea_id, const int checked_symbol_slot, const string expected_symbol = "")
{
   const int magic = QM_Magic(checked_ea_id, checked_symbol_slot);
   if(magic <= 0)
   {
      return -1;
   }

   if(!QM_MagicRegistered(checked_ea_id, checked_symbol_slot))
   {
      PrintFormat("%s: ea_id=%d slot=%d magic=%d", EA_MAGIC_NOT_REGISTERED, checked_ea_id, checked_symbol_slot, magic);
      return -1;
   }

   if(QM_MagicCollisionWithForeignOpenPositions(magic, expected_symbol))
   {
      return -1;
   }

   return magic;
}

#endif // QM_MAGIC_RESOLVER_MQH
