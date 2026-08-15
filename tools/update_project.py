"""Adds the Core ML assets to SatViewAR's pbxproj and removes the TFLite ones.

The installed xcodeproj gem dates from 2022 and cannot parse the
XCLocalSwiftPackageReference that current Xcode writes, so the file is edited directly.
This is a shipped app, so the original is backed up and the result must be verified
with a build.

    python3 tools/update_project.py
"""

import re
import shutil
import uuid
from pathlib import Path

PROJECT = Path(__file__).parent.parent / "GnssFinder.xcodeproj" / "project.pbxproj"

ADDED_SOURCES = [
    ("SkySegmenter.swift", "sourcecode.swift", "gnssfinder"),
    ("SkyMaskRenderer.swift", "sourcecode.swift", "gnssfinder"),
    ("SkySeg_large_256_trained.mlpackage", "folder.mlpackage", "Assets"),
]

REMOVED = [
    "ImageSegmentationHelper.swift",
    "TFLiteExtension.swift",
    "sky_model_meta.tflite",
    "lite-model_deeplabv3-mobilenetv2-ade20k_1_default_2.tflite",
]

GROUP_ANCHOR = {
    # An existing entry in each group's children list to anchor the insertion against.
    # The tflite entries are removed first, so they cannot serve as anchors.
    "gnssfinder": "ViewController.swift */,",
    "Assets": "sat3.scn */,",
}


def new_identifier() -> str:
    """pbxproj identifiers are 24 uppercase hex characters."""
    return uuid.uuid4().hex[:24].upper()


def drop_lines(text: str, names: list[str]) -> tuple[str, int]:
    kept = []
    dropped = 0
    for line in text.split("\n"):
        if any(name in line for name in names):
            dropped += 1
            continue
        kept.append(line)
    return "\n".join(kept), dropped


def main() -> None:
    original = PROJECT.read_text()
    shutil.copy(PROJECT, PROJECT.with_suffix(".pbxproj.backup"))

    text, dropped = drop_lines(original, REMOVED)
    print(f"lines removed: {dropped}")

    build_file_lines = []
    file_ref_lines = []
    sources_lines = []

    for name, file_type, group in ADDED_SOURCES:
        build_id = new_identifier()
        file_id = new_identifier()

        quoted = name if re.fullmatch(r"[A-Za-z0-9_.]+", name) else f'"{name}"'

        build_file_lines.append(
            f"\t\t{build_id} /* {name} in Sources */ = {{isa = PBXBuildFile; "
            f"fileRef = {file_id} /* {name} */; }};"
        )
        file_ref_lines.append(
            f"\t\t{file_id} /* {name} */ = {{isa = PBXFileReference; "
            f"lastKnownFileType = {file_type}; path = {quoted}; sourceTree = \"<group>\"; }};"
        )
        sources_lines.append(f"\t\t\t\t{build_id} /* {name} in Sources */,")

        # Insert the file reference into that group's children.
        anchor = GROUP_ANCHOR[group]
        marker = [line for line in text.split("\n") if anchor in line]
        if not marker:
            raise SystemExit(f"anchor not found in group {group}: {anchor}")
        text = text.replace(
            marker[0], marker[0] + f"\n\t\t\t\t{file_id} /* {name} */,", 1
        )
        print(f"added: {name} -> {group}")

    # PBXBuildFile section
    text = text.replace(
        "/* End PBXBuildFile section */",
        "\n".join(build_file_lines) + "\n/* End PBXBuildFile section */",
        1,
    )
    # PBXFileReference section
    text = text.replace(
        "/* End PBXFileReference section */",
        "\n".join(file_ref_lines) + "\n/* End PBXFileReference section */",
        1,
    )
    # Sources build phase
    marker = "\t\t\tisa = PBXSourcesBuildPhase;"
    index = text.index(marker)
    files_index = text.index("files = (", index) + len("files = (")
    text = text[:files_index] + "\n" + "\n".join(sources_lines) + text[files_index:]

    PROJECT.write_text(text)
    print(f"saved. backup: {PROJECT.with_suffix('.pbxproj.backup').name}")


if __name__ == "__main__":
    main()
