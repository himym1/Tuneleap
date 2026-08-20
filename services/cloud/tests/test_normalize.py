from app.adapters.normalize import extract_lyric_payload


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
