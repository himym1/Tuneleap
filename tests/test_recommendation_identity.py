from app.services.recommendation_identity import weak_identity


def test_duet_identity_ignores_separator_order_and_language_suffix():
    expected = weak_identity("花好月圆夜", "任贤齐 / 杨千嬅")

    assert weak_identity("花好月圆夜", "杨千嬅 & 任贤齐") == expected
    assert weak_identity("花好月圆夜(国)", "任贤齐 • 杨千嬅") == expected
    assert weak_identity("任贤齐 _ 杨千嬅 - 花好月圆夜", "杨千嬅/任贤齐") == expected


def test_latin_artist_punctuation_is_normalized():
    assert weak_identity("Enemy", "Imagine Dragons / J.I.D") == weak_identity(
        "Enemy", "J.I.D & Imagine Dragons"
    )


def test_featured_artist_keeps_primary_artist_weak_identity():
    assert weak_identity("Song", "Artist feat. Guest") == weak_identity(
        "Song", "Artist"
    )


def test_version_labels_do_not_strip_unrelated_chinese_brackets():
    assert weak_identity("Song - Live", "Artist") == weak_identity(
        "Song", "Artist"
    )
    assert weak_identity("Song (中国风)", "Artist") != weak_identity(
        "Song", "Artist"
    )
