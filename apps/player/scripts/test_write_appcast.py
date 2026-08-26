import unittest
from datetime import datetime, timezone

from write_appcast import parse_sign_update_output, render_appcast, validate_origin


class WriteAppcastTest(unittest.TestCase):
    def test_parse_sign_update_output(self):
        signature, length = parse_sign_update_output(
            'sparkle:edSignature="pbdyPt92pnPkzLfQ7BhS9hbjcV9/ndkzSIlWjFQIUMcaCNbAFO2fzl0tISMNJApG2POTkZY0/kJQ2yZYOSVgAA==" length="13400992"\n'
        )
        self.assertEqual(
            signature,
            "pbdyPt92pnPkzLfQ7BhS9hbjcV9/ndkzSIlWjFQIUMcaCNbAFO2fzl0tISMNJApG2POTkZY0/kJQ2yZYOSVgAA==",
        )
        self.assertEqual(length, 13400992)

    def test_rejects_http_origin(self):
        with self.assertRaises(ValueError):
            validate_origin("http://player.himym.us.ci")

    def test_render_appcast_uses_private_release_url(self):
        xml = render_appcast(
            origin="https://player.himym.us.ci",
            macos_version="1.0.48",
            macos_build=45,
            macos_name="navidrome_player-1.0.48+45-macos.dmg",
            signature="pbdyPt92pnPkzLfQ7BhS9hbjcV9/ndkzSIlWjFQIUMcaCNbAFO2fzl0tISMNJApG2POTkZY0/kJQ2yZYOSVgAA==",
            length=24000000,
            changelog="macOS 更新改为自动下载并安装。",
            pub_date=datetime(2026, 8, 26, 8, 0, tzinfo=timezone.utc),
        )
        self.assertIn(
            "https://player.himym.us.ci/releases/navidrome_player-1.0.48+45-macos.dmg",
            xml,
        )
        self.assertIn("<sparkle:version>45</sparkle:version>", xml)
        self.assertIn("macOS 更新改为自动下载并安装。", xml)
        self.assertIn('enclosure url="https://', xml)
        self.assertNotIn('enclosure url="http://', xml)


if __name__ == "__main__":
    unittest.main()
