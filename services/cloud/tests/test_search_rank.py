from app.models.schemas import SongDTO
from app.services.search_rank import (
    looks_like_artist_query,
    rank_search_hits,
    search_hit_score,
)


def _song(id: str, title: str, artist: str) -> SongDTO:
    return SongDTO(
        id=id,
        title=title,
        artist=artist,
        source="netease",
        provider="gdstudio",
    )


def test_artist_query_ranks_solo_catalog_above_collabs_live_and_beats():
    items = [
        _song("1", "想你就写信 (Live)", "周杰伦 / 李硕 / 张鑫"),
        _song("2", "布拉格广场", "蔡依林 / 周杰伦"),
        _song("3", "周杰伦“半岛铁盒”Pop Rap x RnB Beat", "Beat Maker"),
        _song("4", "晴天", "周杰伦"),
        _song("5", "屋顶", "周杰伦 / 温岚"),
        _song("6", "晴天 (女声版)", "翻唱"),
    ]
    ranked = rank_search_hits("周杰伦", items)
    assert [item.title for item in ranked[:3]] == [
        "晴天",
        "屋顶",
        "想你就写信 (Live)",
    ]
    assert ranked[-1].title.startswith("周杰伦")
    assert looks_like_artist_query("周杰伦", items)


def test_song_query_prefers_original_over_cover():
    items = [
        _song("1", "晴天(深情版)", "未知"),
        _song("2", "晴天 (女声版)", "翻唱"),
        _song("3", "晴天", "周杰伦"),
    ]
    ranked = rank_search_hits("晴天", items)
    assert ranked[0].title == "晴天"
    assert ranked[0].artist == "周杰伦"
    assert search_hit_score("晴天", ranked[0]) > search_hit_score("晴天", items[1])
