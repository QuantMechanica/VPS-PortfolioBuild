"""Windows CurrentUser DPAPI credential access; never prints credentials.

The companion masked GUI writes this blob. No key argument, plaintext file,
environment persistence, Git, or Drive storage is used. Windows administrators
and processes running as this user remain part of the local trust boundary.
"""
import ctypes
from ctypes import wintypes
import os
from pathlib import Path
import re

KEY_PATH = Path("D:/QM/futures_lab/private/databento.dpapi")
ENTROPY = b"QM.FuturesLab.Databento.v1"


class CredentialError(RuntimeError):
    pass


class Blob(ctypes.Structure):
    _fields_ = [("cbData", wintypes.DWORD), ("pbData", ctypes.POINTER(ctypes.c_ubyte))]


def _blob(data):
    buffer = ctypes.create_string_buffer(data)
    return Blob(len(data), ctypes.cast(buffer, ctypes.POINTER(ctypes.c_ubyte))), buffer


def _unprotect(encrypted):
    if os.name != "nt":
        raise CredentialError("Windows DPAPI is required")
    crypt = ctypes.WinDLL("crypt32", use_last_error=True)
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    crypt.CryptUnprotectData.argtypes = [ctypes.POINTER(Blob), ctypes.c_void_p,
        ctypes.POINTER(Blob), ctypes.c_void_p, ctypes.c_void_p,
        wintypes.DWORD, ctypes.POINTER(Blob)]
    crypt.CryptUnprotectData.restype = wintypes.BOOL
    kernel.LocalFree.argtypes = [ctypes.c_void_p]
    kernel.LocalFree.restype = ctypes.c_void_p
    source, source_buffer = _blob(encrypted)
    entropy, entropy_buffer = _blob(ENTROPY)
    output = Blob()
    if not crypt.CryptUnprotectData(ctypes.byref(source), None,
            ctypes.byref(entropy), None, None, 1, ctypes.byref(output)):
        raise CredentialError("Credential cannot be decrypted by this Windows user")
    try:
        return ctypes.string_at(output.pbData, output.cbData)
    finally:
        ctypes.memset(output.pbData, 0, output.cbData)
        kernel.LocalFree(output.pbData)


def load_key():
    """Return an in-memory key; sanitized errors never include input or key."""
    try:
        for path in [KEY_PATH, *KEY_PATH.parents]:
            if path.lstat().st_file_attributes & 0x400:
                raise CredentialError("Credential path must not contain a reparse point")
        if not 32 <= KEY_PATH.stat().st_size <= 65536:
            raise CredentialError("Invalid credential container")
        key = _unprotect(KEY_PATH.read_bytes()).decode("utf-8")
        if re.fullmatch(r"db-[A-Za-z0-9_-]{29}", key) is None:
            raise CredentialError("Invalid credential format")
        return key
    except CredentialError:
        raise
    except Exception:
        raise CredentialError("Local credential is missing or unreadable") from None
