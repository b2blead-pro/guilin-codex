#!/usr/bin/env python3
"""从本地原图生成供模型查看的低流量预览；原图不改动、不用于像素级评分。"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import re
from pathlib import Path

from PIL import Image, ImageOps


def parse_roi(raw: str) -> tuple[int, int, int, int]:
    try:
        x, y, width, height = (int(part.strip()) for part in raw.split(","))
    except (ValueError, TypeError) as error:
        raise argparse.ArgumentTypeError("ROI 须为原图像素 x,y,width,height") from error
    if min(x, y) < 0 or min(width, height) <= 0:
        raise argparse.ArgumentTypeError("ROI 坐标不得为负，宽高必须为正")
    return x, y, width, height


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def webp_bytes(image: Image.Image, *, lossless: bool, quality: int, icc: bytes | None) -> bytes:
    buffer = io.BytesIO()
    options = {"format": "WEBP", "method": 6, "lossless": lossless, "quality": quality}
    if icc:
        options["icc_profile"] = icc
    image.save(buffer, **options)
    return buffer.getvalue()


def choose_preview(image: Image.Image, budget: int, icc: bytes | None) -> tuple[bytes, str, int | None]:
    variants = [(webp_bytes(image, lossless=True, quality=100, icc=icc), "lossless", None)]
    if len(variants[0][0]) <= budget:
        return variants[0]
    for quality in (94, 90, 86, 82, 78):
        encoded = webp_bytes(image, lossless=False, quality=quality, icc=icc)
        variants.append((encoded, "lossy", quality))
        if len(encoded) <= budget:
            return variants[-1]
    return min(variants, key=lambda item: len(item[0]))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="已在本机的原始图片")
    parser.add_argument("--output-dir", required=True, type=Path, help="只写预览及元数据的目录")
    parser.add_argument("--roi", type=parse_roi, help="可选：原图像素坐标 x,y,width,height；细节分析从原图裁切")
    parser.add_argument("--max-edge", type=int, default=1600, help="预览最长边上限，默认 1600 像素")
    parser.add_argument("--max-pixels", type=int, default=1_000_000, help="预览总像素上限，默认 100 万")
    parser.add_argument("--budget-kib", type=int, default=256, help="预览建议字节预算，默认 256 KiB")
    args = parser.parse_args()
    if min(args.max_edge, args.max_pixels, args.budget_kib) <= 0:
        parser.error("尺寸与字节预算必须为正")
    source = args.input.expanduser().resolve(strict=True)
    if not source.is_file():
        parser.error("输入必须是本地图片文件")
    original_bytes = source.stat().st_size
    source_hash = digest(source)

    with Image.open(source) as opened:
        frames = getattr(opened, "n_frames", 1)
        icc = opened.info.get("icc_profile")
        image = ImageOps.exif_transpose(opened)
        original_size = list(image.size)
        if args.roi:
            x, y, width, height = args.roi
            if x + width > image.width or y + height > image.height:
                parser.error("ROI 超出经过 EXIF 方向校正后的原图边界")
            image = image.crop((x, y, x + width, y + height))
        has_alpha = "A" in image.getbands() or "transparency" in image.info
        image = image.convert("RGBA" if has_alpha else "RGB")

    crop_size = list(image.size)
    edge_scale = min(1.0, args.max_edge / max(image.size))
    pixel_scale = min(1.0, math.sqrt(args.max_pixels / (image.width * image.height)))
    scale = min(edge_scale, pixel_scale)
    if scale < 1:
        image = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))), Image.Resampling.LANCZOS)

    budget = args.budget_kib * 1024
    encoded, mode, quality = choose_preview(image, budget, icc)
    # 若默认尺寸仍超预算，逐步缩小概览；细字应另取原图 ROI，不继续压坏当前预览。
    for _ in range(3):
        if len(encoded) <= budget or args.roi or min(image.size) < 120:
            break
        image = image.resize((max(1, round(image.width * 0.82)), max(1, round(image.height * 0.82))), Image.Resampling.LANCZOS)
        encoded, mode, quality = choose_preview(image, budget, icc)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    label = re.sub(r"[^\w.-]+", "-", source.stem, flags=re.UNICODE)[:60] or "image"
    roi_label = "overview" if not args.roi else "roi-" + "-".join(map(str, args.roi))
    basename = f"{label}.{roi_label}.{source_hash[:10]}"
    preview = (args.output_dir / f"{basename}.webp").resolve()
    if preview == source:
        parser.error("输出不得覆盖原图")
    preview.write_bytes(encoded)
    metadata = {
        "source": str(source),
        "source_sha256": source_hash,
        "source_bytes": original_bytes,
        "source_dimensions": original_size,
        "source_frames": frames,
        "roi_original_pixels": list(args.roi) if args.roi else None,
        "cropped_dimensions": crop_size,
        "preview": str(preview),
        "preview_dimensions": list(image.size),
        "preview_bytes": len(encoded),
        "reduction_percent": round(100 * (1 - len(encoded) / original_bytes), 2) if original_bytes else 0,
        "budget_bytes": budget,
        "within_budget": len(encoded) <= budget,
        "encoding": mode,
        "quality": quality,
        "preview_only": True,
        "prefer_original_for_view": args.roi is None and original_bytes <= budget and original_bytes <= len(encoded) and max(original_size) <= args.max_edge and original_size[0] * original_size[1] <= args.max_pixels,
        "warnings": [],
    }
    if metadata["prefer_original_for_view"]:
        metadata["warnings"].append("原图已在预算内且不大于预览；可直接查看原图")
    if frames > 1:
        metadata["warnings"].append("仅预览首帧；分析动画须另取相关帧")
    if image.width < 350 and not args.roi:
        metadata["warnings"].append("长图概览过窄；文字或图标请从原图指定 ROI 再查看")
    if len(encoded) > budget:
        metadata["warnings"].append("在当前细节保护策略下未达到字节预算；请缩小 ROI")
    metadata_path = args.output_dir / f"{basename}.json"
    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metadata, ensure_ascii=False))


if __name__ == "__main__":
    main()
