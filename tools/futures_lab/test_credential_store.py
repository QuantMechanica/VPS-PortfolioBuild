"""Actual Windows DPAPI roundtrip using synthetic bytes, no stored/API key."""
import ctypes
from ctypes import wintypes
import os
import unittest
from credential_store import Blob, ENTROPY, CredentialError, _blob, _unprotect


@unittest.skipUnless(os.name == 'nt', 'Windows DPAPI')
class CredentialTests(unittest.TestCase):
    def test_current_user_roundtrip(self):
        crypt = ctypes.WinDLL('crypt32', use_last_error=True)
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        crypt.CryptProtectData.argtypes = [ctypes.POINTER(Blob), wintypes.LPCWSTR,
            ctypes.POINTER(Blob), ctypes.c_void_p, ctypes.c_void_p,
            wintypes.DWORD, ctypes.POINTER(Blob)]
        crypt.CryptProtectData.restype = wintypes.BOOL
        kernel.LocalFree.argtypes = [ctypes.c_void_p]
        kernel.LocalFree.restype = ctypes.c_void_p
        payload = b'synthetic-local-roundtrip-not-an-api-key'
        source, source_buffer = _blob(payload)
        entropy, entropy_buffer = _blob(ENTROPY)
        output = Blob()
        self.assertTrue(crypt.CryptProtectData(ctypes.byref(source), None,
            ctypes.byref(entropy), None, None, 1, ctypes.byref(output)))
        try:
            encrypted = ctypes.string_at(output.pbData, output.cbData)
        finally:
            kernel.LocalFree(output.pbData)
        self.assertNotIn(payload, encrypted)
        self.assertEqual(_unprotect(encrypted), payload)

    def test_corrupted_blob_fails_sanitized(self):
        with self.assertRaisesRegex(CredentialError, '^Credential cannot be decrypted by this Windows user$'):
            _unprotect(b'corrupted-not-a-key')


if __name__ == '__main__':
    unittest.main()
