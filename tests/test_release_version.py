import importlib.util
import pathlib
import tempfile
import unittest
import zipfile


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPO_ROOT / "scripts" / "release_version.py"


def load_release_module():
    spec = importlib.util.spec_from_file_location("release_version", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ReleaseVersionTests(unittest.TestCase):
    def test_update_toc_version_replaces_existing_value(self):
        release_version = load_release_module()

        with tempfile.TemporaryDirectory() as tmpdir:
            toc_path = pathlib.Path(tmpdir) / "LootG.toc"
            toc_path.write_text("## Title: LootG\n## Version: 1.2.0\nLocales.lua\n", encoding="utf-8")

            old_version = release_version.update_toc_version(toc_path, "1.2.1")

            self.assertEqual(old_version, "1.2.0")
            self.assertIn("## Version: 1.2.1", toc_path.read_text(encoding="utf-8"))

    def test_sync_readme_changelog_inserts_latest_block_and_preserves_history(self):
        release_version = load_release_module()

        original = """# LootG

## Changelog

### v1.2.0
- Old latest note

### v1.1.0
- Older note
"""

        with tempfile.TemporaryDirectory() as tmpdir:
            readme_path = pathlib.Path(tmpdir) / "README.md"
            readme_path.write_text(original, encoding="utf-8")

            release_version.sync_readme_changelog(
                readme_path,
                "1.2.1",
                ["- New note A", "- New note B"],
                "## Changelog",
            )

            updated = readme_path.read_text(encoding="utf-8")
            self.assertIn("### v1.2.1\n- New note A\n- New note B", updated)
            self.assertIn("### v1.2.0\n- Old latest note", updated)
            self.assertIn("### v1.1.0\n- Older note", updated)

    def test_build_release_zip_includes_only_runtime_files_at_root(self):
        release_version = load_release_module()

        with tempfile.TemporaryDirectory() as tmpdir:
            repo_root = pathlib.Path(tmpdir)
            for relative_path in release_version.RELEASE_FILES:
                (repo_root / relative_path).write_text(relative_path, encoding="utf-8")

            (repo_root / "README.md").write_text("ignore", encoding="utf-8")
            (repo_root / "tests").mkdir()
            (repo_root / "tests" / "test_release_version.py").write_text("ignore", encoding="utf-8")

            archive_path = release_version.build_release_zip(repo_root, "1.2.1")

            self.assertEqual(archive_path.name, "LootG-1.2.1.zip")
            with zipfile.ZipFile(archive_path) as archive:
                names = sorted(archive.namelist())

            self.assertEqual(names, sorted(release_version.RELEASE_FILES))
            self.assertNotIn("README.md", names)
            self.assertTrue(all("/" not in name for name in names))

    def test_validate_version_rejects_invalid_and_unchanged_inputs(self):
        release_version = load_release_module()

        self.assertEqual(release_version.validate_version("1.2.1", "1.2.0"), "1.2.1")

        with self.assertRaises(ValueError):
            release_version.validate_version("1.2", "1.2.0")

        with self.assertRaises(ValueError):
            release_version.validate_version("1.2.0", "1.2.0")


if __name__ == "__main__":
    unittest.main()
