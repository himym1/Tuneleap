from scripts.benchmark_music_upstreams import safe_endpoint


def test_safe_endpoint_removes_credentials_and_query():
    assert (
        safe_endpoint("https://user:secret@example.test:8443/api?token=private")
        == "https://example.test:8443/api"
    )
