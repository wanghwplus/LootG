import importlib.util
import pathlib
import tempfile
import unittest
import zipfile


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPO_ROOT / "scripts" / "package.py"


def load_package_module(test_case):
    test_case.assertTrue(SCRIPT_PATH.exists(), f"missing script: {SCRIPT_PATH}")
    spec = importlib.util.spec_from_file_location("package_script", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_release_repo_files(repo_root, module, version):
    (repo_root / "LootG.toc").write_text(
        f"## Title: LootG\n## Version: {version}\nLocales.lua\n",
        encoding="utf-8",
    )
    (repo_root / "README.md").write_text("# LootG\n\n## Changelog\n\n### v1.2.0\n- Old note\n", encoding="utf-8")
    (repo_root / "README_zhCN.md").write_text(
        "# LootG\n\n## 更新日志\n\n### v1.2.0\n- 旧内容\n",
        encoding="utf-8",
    )

    for relative_path in module.RELEASE_FILES:
        file_path = repo_root / relative_path
        file_path.parent.mkdir(parents=True, exist_ok=True)
        if file_path.name != "LootG.toc":
            file_path.write_text(relative_path, encoding="utf-8")


class PackageScriptTests(unittest.TestCase):
    def test_update_toc_version_replaces_existing_value(self):
        package_script = load_package_module(self)

        with tempfile.TemporaryDirectory() as tmpdir:
            toc_path = pathlib.Path(tmpdir) / "LootG.toc"
            toc_path.write_text("## Title: LootG\n## Version: 1.2.0\nLocales.lua\n", encoding="utf-8")

            old_version = package_script.update_toc_version(toc_path, "1.2.1")

            self.assertEqual(old_version, "1.2.0")
            self.assertIn("## Version: 1.2.1", toc_path.read_text(encoding="utf-8"))

    def test_sync_readme_changelog_inserts_latest_block_and_preserves_history(self):
        package_script = load_package_module(self)

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

            package_script.sync_readme_changelog(
                readme_path,
                "1.2.1",
                ["- New note A", "- New note B"],
                "## Changelog",
            )

            updated = readme_path.read_text(encoding="utf-8")
            self.assertIn("### v1.2.1\n- New note A\n- New note B", updated)
            self.assertIn("### v1.2.0\n- Old latest note", updated)
            self.assertIn("### v1.1.0\n- Older note", updated)

    def test_build_release_zip_includes_only_runtime_files_under_lootg_directory(self):
        package_script = load_package_module(self)

        with tempfile.TemporaryDirectory() as tmpdir:
            repo_root = pathlib.Path(tmpdir)
            for relative_path in package_script.RELEASE_FILES:
                (repo_root / relative_path).write_text(relative_path, encoding="utf-8")

            (repo_root / "README.md").write_text("ignore", encoding="utf-8")
            (repo_root / "tests").mkdir()
            (repo_root / "tests" / "test_package.py").write_text("ignore", encoding="utf-8")

            archive_path = package_script.build_release_zip(repo_root, "1.2.1")

            self.assertEqual(archive_path.name, "LootG-1.2.1.zip")
            with zipfile.ZipFile(archive_path) as archive:
                names = sorted(archive.namelist())

            expected_names = sorted(
                f"{package_script.ARCHIVE_ROOT_DIR}/{relative_path}"
                for relative_path in package_script.RELEASE_FILES
            )
            self.assertEqual(names, expected_names)
            self.assertNotIn("README.md", names)
            self.assertTrue(all(name.startswith(f"{package_script.ARCHIVE_ROOT_DIR}/") for name in names))

    def test_validate_version_rejects_invalid_and_unchanged_inputs(self):
        package_script = load_package_module(self)

        self.assertEqual(package_script.validate_version("1.2.1", "1.2.0"), "1.2.1")

        with self.assertRaises(ValueError):
            package_script.validate_version("1.2", "1.2.0")

        with self.assertRaises(ValueError):
            package_script.validate_version("1.2.0", "1.2.0")

    def test_main_package_uses_current_version_and_does_not_update_files(self):
        package_script = load_package_module(self)

        with tempfile.TemporaryDirectory() as tmpdir:
            repo_root = pathlib.Path(tmpdir)
            write_release_repo_files(repo_root, package_script, "1.2.1")
            original_toc = (repo_root / "LootG.toc").read_text(encoding="utf-8")
            original_readme = (repo_root / "README.md").read_text(encoding="utf-8")
            original_readme_zh = (repo_root / "README_zhCN.md").read_text(encoding="utf-8")

            exit_code = package_script.main(["package"], repo_root=repo_root)

            self.assertEqual(exit_code, 0)
            self.assertEqual((repo_root / "LootG.toc").read_text(encoding="utf-8"), original_toc)
            self.assertEqual((repo_root / "README.md").read_text(encoding="utf-8"), original_readme)
            self.assertEqual((repo_root / "README_zhCN.md").read_text(encoding="utf-8"), original_readme_zh)
            self.assertTrue((repo_root / "LootG-1.2.1.zip").exists())

    def test_main_release_updates_version_readmes_and_builds_zip(self):
        package_script = load_package_module(self)

        with tempfile.TemporaryDirectory() as tmpdir:
            repo_root = pathlib.Path(tmpdir)
            write_release_repo_files(repo_root, package_script, "1.2.0")

            exit_code = package_script.main(["release", "1.2.1"], repo_root=repo_root)

            self.assertEqual(exit_code, 0)
            self.assertIn("## Version: 1.2.1", (repo_root / "LootG.toc").read_text(encoding="utf-8"))
            self.assertIn("### v1.2.1", (repo_root / "README.md").read_text(encoding="utf-8"))
            self.assertIn("### v1.2.1", (repo_root / "README_zhCN.md").read_text(encoding="utf-8"))
            self.assertTrue((repo_root / "LootG-1.2.1.zip").exists())

    def test_main_release_requires_version_argument(self):
        package_script = load_package_module(self)

        with self.assertRaises(SystemExit):
            package_script.main(["release"])


if __name__ == "__main__":
    unittest.main()
