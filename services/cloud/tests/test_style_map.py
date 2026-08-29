from app.services.style_map import (
    map_closed_style,
    refine_coarse_style,
    script_storefronts,
)


def test_itunes_cn_mandarin_pop_maps_to_closed_style():
    assert map_closed_style("国语流行", title="晴天", artist="周杰伦") == "华语流行"
    assert map_closed_style("Mandopop", title="晴天", artist="周杰伦") == "华语流行"
    assert map_closed_style("粤语流行", title="浮夸", artist="陈奕迅") == "粤语流行"
    assert map_closed_style("廣東歌/香港流行樂", title="海阔天空", artist="Beyond") == "粤语流行"


def test_itunes_western_pop_uses_latin_bucket():
    assert map_closed_style("Pop", title="Blank Space", artist="Taylor Swift") == "欧美流行"
    assert map_closed_style("Hip-Hop/Rap", title="Lose Yourself", artist="Eminem") == "嘻哈说唱"
    assert map_closed_style("R&B/Soul", title="Blinding Lights", artist="The Weeknd") == "R&B"


def test_kpop_is_not_forced_into_pop():
    assert map_closed_style("K-Pop", title="Dynamite", artist="BTS") is None


def test_cjk_titles_prefer_cn_storefront():
    assert script_storefronts("晴天", "周杰伦") == ("cn", "hk")
    assert script_storefronts("Blank Space", "Taylor Swift") == ("us", "gb")


def test_coarse_mandopop_refines_from_title_markers():
    assert (
        refine_coarse_style(
            "华语流行",
            title="恋爱情歌",
            artist="歌手",
            album="精选",
        )
        == "抒情情歌"
    )
    assert (
        refine_coarse_style(
            "华语流行",
            title="故乡民谣",
            artist="歌手",
            album="专辑",
        )
        == "民谣"
    )
    assert (
        refine_coarse_style(
            "华语流行",
            title="何日君再来",
            artist="周璇",
            album="老歌",
            year=1940,
        )
        == "经典老歌"
    )
    assert (
        refine_coarse_style(
            "华语流行",
            title="晴天",
            artist="周杰伦",
            album="叶惠美",
        )
        is None
    )


def test_coarse_western_pop_refines_rock_marker():
    assert (
        refine_coarse_style(
            "欧美流行",
            title="Rock Song",
            artist="Band",
            album="Album",
        )
        == "摇滚"
    )
