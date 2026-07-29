"""Identity-safe weak-reference caches for pandas ``DataFrame`` objects."""

from __future__ import annotations

import weakref
from collections.abc import Mapping, MutableMapping
from typing import TypeAlias, TypeVar

import pandas as pd


KeyT = TypeVar("KeyT")
ValueT = TypeVar("ValueT")

FrameReference: TypeAlias = weakref.ReferenceType[pd.DataFrame]
FrameCacheEntry: TypeAlias = tuple[FrameReference, ValueT]


def get_for_frame(
    cache: Mapping[KeyT, FrameCacheEntry[ValueT]],
    key: KeyT,
    frame: pd.DataFrame,
) -> ValueT | None:
    """Return a cached value only when its weak reference is this exact frame."""

    cached = cache.get(key)
    if cached is not None and cached[0]() is frame:
        return cached[1]
    return None


def store_for_frame(
    cache: MutableMapping[KeyT, FrameCacheEntry[ValueT]],
    key: KeyT,
    frame: pd.DataFrame,
    value: ValueT,
) -> ValueT:
    """Bind a value to a frame and remove it once that frame is collected."""

    frame_ref: FrameReference

    def discard(dead_ref: FrameReference) -> None:
        current = cache.get(key)
        if current is not None and current[0] is dead_ref:
            cache.pop(key, None)

    frame_ref = weakref.ref(frame, discard)
    cache[key] = (frame_ref, value)
    return value
