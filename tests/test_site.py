from html.parser import HTMLParser
from pathlib import Path
import unittest


class SiteStructure(HTMLParser):
    def __init__(self):
        super().__init__()
        self.title = False
        self.app_mount = False
        self.routes = set()
        self.in_title = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "title":
            self.in_title = True
        if tag == "main" and attrs.get("id") == "app":
            self.app_mount = True

    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False

    def handle_data(self, data):
        if self.in_title and data.strip():
            self.title = True


class StaticSiteTests(unittest.TestCase):
    def test_site_contains_document_title_and_app_mount(self):
        parser = SiteStructure()
        parser.feed(Path("index.html").read_text(encoding="utf-8"))
        self.assertTrue(parser.title, "the page should have a non-empty title")
        self.assertTrue(parser.app_mount, "the client app needs its #app mount point")

    def test_routes_are_declared_for_navigation(self):
        html = Path("index.html").read_text(encoding="utf-8")
        for route in ("home", "plans", "connect", "portal", "pay", "support", "coverage", "contact"):
            with self.subTest(route=route):
                self.assertIn(f'"{route}"', html)


if __name__ == "__main__":
    unittest.main()
