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
