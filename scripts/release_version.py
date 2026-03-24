#!/usr/bin/env python3
import argparse
import pathlib
import re
import sys
import zipfile


RELEASE_FILES = (
    "LootG.toc",
    "Locales.lua",
    "Config.lua",
    "LootGUtils.lua",
    "LootG.lua",
    "icon.png",
)

ENGLISH_RELEASE_NOTES = {
    "1.2.1": [
        "- Added loot, currency, and gold notifications from opened containers, and restored missing chest and quest reward messages",
        "- Fixed duplicate or mixed notifications for personal currency, dungeon loot, and chest gold rewards",
        "- Fixed gold amount scaling, currency link fallback parsing, and duplicate gold icon display issues",
        "- Improved scrolling message updates with one shared animation loop, overlap avoidance, and smoother fading",
        "- Fixed profession skill notifications to use stable fileID icons and more reliable profession name matching",
    ],
}

CHINESE_RELEASE_NOTES = {
    "1.2.1": [
        "- 新增容器开启后的物品、通货与金币通知，并恢复遗漏的宝箱与任务奖励提示",
        "- 修复个人货币、地下城掉落与宝箱金币提示重复或数值串入的问题",
        "- 修复金币倍率、通货链接回退解析以及金币图标重复显示问题",
        "- 优化滚动消息更新逻辑，统一动画循环，避免消息重叠并让渐隐更平滑",
        "- 修复商业技能提升提示的图标来源与专业名称匹配稳定性",
    ],
}

VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+$")


def validate_version(version, current_version):
    if not VERSION_PATTERN.match(version):
        raise ValueError(f"invalid version: {version}")
    if version == current_version:
        raise ValueError(f"version unchanged: {version}")
    return version


def read_current_toc_version(toc_path):
    content = toc_path.read_text(encoding="utf-8")
    match = re.search(r"^## Version:\s*(.+)$", content, re.MULTILINE)
    if not match:
        raise ValueError(f"missing version line in {toc_path}")
    return match.group(1).strip()


def update_toc_version(toc_path, new_version):
    content = toc_path.read_text(encoding="utf-8")
    match = re.search(r"^## Version:\s*(.+)$", content, re.MULTILINE)
    if not match:
        raise ValueError(f"missing version line in {toc_path}")

    old_version = match.group(1).strip()
    updated = re.sub(
        r"^## Version:\s*.+$",
        f"## Version: {new_version}",
        content,
        count=1,
        flags=re.MULTILINE,
    )
    toc_path.write_text(updated, encoding="utf-8")
    return old_version


def release_notes_for_version(version, language):
    notes_map = ENGLISH_RELEASE_NOTES if language == "en" else CHINESE_RELEASE_NOTES
    notes = notes_map.get(version)
    if notes:
        return notes
    if language == "en":
        return [
            "- Update this section with release highlights",
            "- Summarize user-visible fixes and improvements",
        ]
    return [
        "- 请在此补充本次版本的主要更新内容",
        "- 建议概括用户可感知的修复与改进",
    ]


def sync_readme_changelog(readme_path, new_version, notes, changelog_heading):
    lines = readme_path.read_text(encoding="utf-8").splitlines()
    heading_index = None
    for index, line in enumerate(lines):
        if line.strip() == changelog_heading:
            heading_index = index
            break
    if heading_index is None:
        raise ValueError(f"missing changelog heading in {readme_path}")

    latest_start = None
    for index in range(heading_index + 1, len(lines)):
        if lines[index].startswith("### v"):
            latest_start = index
            break

    replacement = [f"### v{new_version}", *notes, ""]

    if latest_start is None:
        insert_at = heading_index + 1
        if insert_at < len(lines) and lines[insert_at] != "":
            replacement.insert(0, "")
        lines[insert_at:insert_at] = [""] + replacement
    else:
        lines[latest_start:latest_start] = replacement

    readme_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_release_zip(repo_root, version):
    archive_path = repo_root / f"LootG-{version}.zip"
    if archive_path.exists():
        archive_path.unlink()

    with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for relative_path in RELEASE_FILES:
            file_path = repo_root / relative_path
            if not file_path.exists():
                raise FileNotFoundError(f"missing release file: {relative_path}")
            archive.write(file_path, arcname=relative_path)

    return archive_path


def main(argv=None):
    parser = argparse.ArgumentParser(description="Update LootG version, changelog, and release zip.")
    parser.add_argument("version", help="semantic version, for example 1.2.1")
    args = parser.parse_args(argv)

    repo_root = pathlib.Path(__file__).resolve().parents[1]
    toc_path = repo_root / "LootG.toc"
    current_version = read_current_toc_version(toc_path)
    new_version = validate_version(args.version, current_version)

    update_toc_version(toc_path, new_version)
    sync_readme_changelog(
        repo_root / "README.md",
        new_version,
        release_notes_for_version(new_version, "en"),
        "## Changelog",
    )
    sync_readme_changelog(
        repo_root / "README_zhCN.md",
        new_version,
        release_notes_for_version(new_version, "zhCN"),
        "## 更新日志",
    )
    archive_path = build_release_zip(repo_root, new_version)

    print(f"Updated version: {current_version} -> {new_version}")
    print(f"Created archive: {archive_path.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
