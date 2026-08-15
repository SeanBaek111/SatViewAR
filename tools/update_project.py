"""SatViewAR 의 pbxproj 에 Core ML 자산을 넣고 TFLite 자산을 뺀다.

xcodeproj gem 이 설치본 기준 2022년 버전이라 최신 Xcode 가 쓰는
XCLocalSwiftPackageReference 를 못 읽어서 직접 편집한다.
출시된 앱이므로 원본을 백업하고, 변경 후에는 반드시 빌드로 확인한다.

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
    # 각 그룹의 children 목록에서 기준으로 삼을 기존 항목.
    # tflite 항목들은 이 스크립트가 먼저 지우므로 기준으로 쓸 수 없다.
    "gnssfinder": "ViewController.swift */,",
    "Assets": "sat3.scn */,",
}


def new_identifier() -> str:
    """pbxproj 는 24자리 대문자 16진수 식별자를 쓴다."""
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
    print(f"제거된 줄: {dropped}")

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

        # 해당 그룹의 children 에 파일 참조를 끼워 넣는다.
        anchor = GROUP_ANCHOR[group]
        marker = [line for line in text.split("\n") if anchor in line]
        if not marker:
            raise SystemExit(f"{group} 그룹의 기준 항목을 찾지 못했다: {anchor}")
        text = text.replace(
            marker[0], marker[0] + f"\n\t\t\t\t{file_id} /* {name} */,", 1
        )
        print(f"추가: {name} → {group}")

    # PBXBuildFile 구역
    text = text.replace(
        "/* End PBXBuildFile section */",
        "\n".join(build_file_lines) + "\n/* End PBXBuildFile section */",
        1,
    )
    # PBXFileReference 구역
    text = text.replace(
        "/* End PBXFileReference section */",
        "\n".join(file_ref_lines) + "\n/* End PBXFileReference section */",
        1,
    )
    # Sources 빌드 단계
    marker = "\t\t\tisa = PBXSourcesBuildPhase;"
    index = text.index(marker)
    files_index = text.index("files = (", index) + len("files = (")
    text = text[:files_index] + "\n" + "\n".join(sources_lines) + text[files_index:]

    PROJECT.write_text(text)
    print(f"저장 완료. 백업: {PROJECT.with_suffix('.pbxproj.backup').name}")


if __name__ == "__main__":
    main()
