from app.adapters.normalize import extract_lyric_payload, normalize_song


def test_extract_lyric_payload_skips_empty_string_and_reads_nested_lrc():
    assert (
        extract_lyric_payload(
            {
                "lyric": "",
                "tlyric": "",
                "lrc": {"version": 1, "lyric": "[00:01.00]蝴蝶"},
            }
        )
        == "[00:01.00]蝴蝶"
    )


def test_extract_lyric_payload_reads_plain_lrc_string():
    assert extract_lyric_payload({"lrc": "[00:01.00]First line"}) == "[00:01.00]First line"


def test_extract_lyric_payload_ignores_whitespace_only():
    assert extract_lyric_payload({"lyric": "  \n", "lrc": "  "}) == ""


def test_normalize_song_reads_qq_and_kugou_native_fields():
    qq = normalize_song(
        {
            "songname": "晴天",
            "singer": [{"name": "周杰伦"}],
            "songmid": "0039MnYb0qxYhV",
            "albumname": "叶惠美",
        },
        provider="chksz",
        default_source="tencent",
    )
    kugou = normalize_song(
        {
            "FileName": "晴天",
            "SingerName": "周杰伦",
            "FileHash": "hash-1",
            "AlbumName": "叶惠美",
        },
        provider="chksz",
        default_source="kugou",
    )

    assert qq is not None
    assert qq["id"] == "0039MnYb0qxYhV"
    assert qq["title"] == "晴天"
    assert qq["artist"] == "周杰伦"
    assert kugou is not None
    assert kugou["id"] == "hash-1"
    assert kugou["title"] == "晴天"
    assert kugou["artist"] == "周杰伦"
