from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.core.config import Settings


def test_database_pool_bounds_are_validated():
    with pytest.raises(ValidationError, match="database_pool_max_size"):
        Settings(
            _env_file=None,
            database_pool_min_size=5,
            database_pool_max_size=2,
        )


def test_music_search_sources_are_normalized_and_deduplicated():
    settings = Settings(
        _env_file=None,
        music_search_sources=" Netease, migu,netease, unsupported ",
    )

    assert settings.music_search_source_list == ("netease", "migu")


def test_music_adapter_order_is_normalized_and_filtered():
    settings = Settings(
        _env_file=None,
        music_adapter_order=" Meting,gdstudio,meting,unsupported ",
    )

    assert settings.music_adapter_order_list == ("meting", "gdstudio")


def test_invalid_music_adapter_order_falls_back_to_safe_default():
    settings = Settings(_env_file=None, music_adapter_order="unsupported")

    assert settings.music_adapter_order_list == ("meting", "gdstudio", "chksz")


def test_music_search_sources_accept_qq_alias_and_tencent():
    settings = Settings(
        _env_file=None,
        music_search_sources="qq,kugou,tencent",
    )

    assert settings.music_search_source_list == ("tencent", "kugou")


def test_chksz_is_recognized_in_adapter_order():
    settings = Settings(
        _env_file=None,
        music_adapter_order="meting,chksz,gdstudio",
    )

    assert settings.music_adapter_order_list == ("meting", "chksz", "gdstudio")
