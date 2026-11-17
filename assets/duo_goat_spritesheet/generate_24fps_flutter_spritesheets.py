import os
import json
import cv2
import numpy as np
from PIL import Image

BASE_DIR = r"C:\Users\Pedro\.gemini\antigravity\scratch\duo_goat_spritesheet"
FRAMES_SOURCE_DIR = os.path.join(BASE_DIR, "inspect_frames")
OUT_SHEETS_24 = os.path.join(BASE_DIR, "spritesheets_24fps")
OUT_FRAMES_DIR = os.path.join(BASE_DIR, "frames_24fps")

os.makedirs(OUT_SHEETS_24, exist_ok=True)
os.makedirs(OUT_FRAMES_DIR, exist_ok=True)

def shift_image_crisp(img_arr, dx, dy):
    """Lossless integer pixel shift with zero interpolation or resampling."""
    if dx == 0 and dy == 0:
        return img_arr.copy()
    h, w = img_arr.shape[:2]
    out = np.zeros_like(img_arr)

    src_y1 = max(0, -dy)
    src_y2 = min(h, h - dy)
    src_x1 = max(0, -dx)
    src_x2 = min(w, w - dx)

    dst_y1 = max(0, dy)
    dst_y2 = min(h, h + dy)
    dst_x1 = max(0, dx)
    dst_x2 = min(w, w + dx)

    out[dst_y1:dst_y2, dst_x1:dst_x2] = img_arr[src_y1:src_y2, src_x1:src_x2]
    return out

def fill_interior_holes(arr):
    """Fill interior holes without altering exterior boundary."""
    alpha = arr[:, :, 3] > 10
    inv = (~alpha).astype(np.uint8)
    h, w = inv.shape
    mask = np.zeros((h + 2, w + 2), np.uint8)
    flooded = inv.copy()
    cv2.floodFill(flooded, mask, (0, 0), 2)
    is_hole = (flooded == 1)

    if np.sum(is_hole) > 0:
        out = arr.copy()
        ys, xs = np.where(is_hole)
        for y, x in zip(ys, xs):
            y0, y1 = max(0, y - 2), min(h, y + 3)
            x0, x1 = max(0, x - 2), min(w, x + 3)
            patch = arr[y0:y1, x0:x1]
            valid = patch[patch[:, :, 3] > 10]
            if len(valid) > 0:
                out[y, x] = valid[0]
        return out
    return arr

def clean_warp_inbetween(im0, im1, t):
    """
    Zero-blur in-between generator.
    Discrete nearest-neighbor sampling from median-smoothed optical flow.
    Zero new colors, zero cross-fade, zero ghosting.
    """
    h, w = im0.shape[:2]

    if t < 0.5:
        a0 = im0[:, :, 3].astype(float) / 255.0
        a1 = im1[:, :, 3].astype(float) / 255.0
        gray0 = (cv2.cvtColor(im0[:, :, :3], cv2.COLOR_RGB2GRAY).astype(float) * a0).astype(np.uint8)
        gray1 = (cv2.cvtColor(im1[:, :, :3], cv2.COLOR_RGB2GRAY).astype(float) * a1).astype(np.uint8)

        flow = cv2.calcOpticalFlowFarneback(gray0, gray1, None, 0.5, 4, 31, 5, 7, 1.5, 0)
        flow[:, :, 0] = cv2.medianBlur(flow[:, :, 0], 5)
        flow[:, :, 1] = cv2.medianBlur(flow[:, :, 1], 5)

        grid_y, grid_x = np.mgrid[0:h, 0:w].astype(np.float32)
        map_x = np.round(grid_x - t * flow[:, :, 0]).astype(np.float32)
        map_y = np.round(grid_y - t * flow[:, :, 1]).astype(np.float32)

        out = cv2.remap(im0, map_x, map_y, cv2.INTER_NEAREST, borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))
    else:
        a0 = im0[:, :, 3].astype(float) / 255.0
        a1 = im1[:, :, 3].astype(float) / 255.0
        gray0 = (cv2.cvtColor(im0[:, :, :3], cv2.COLOR_RGB2GRAY).astype(float) * a0).astype(np.uint8)
        gray1 = (cv2.cvtColor(im1[:, :, :3], cv2.COLOR_RGB2GRAY).astype(float) * a1).astype(np.uint8)

        flow = cv2.calcOpticalFlowFarneback(gray1, gray0, None, 0.5, 4, 31, 5, 7, 1.5, 0)
        flow[:, :, 0] = cv2.medianBlur(flow[:, :, 0], 5)
        flow[:, :, 1] = cv2.medianBlur(flow[:, :, 1], 5)

        grid_y, grid_x = np.mgrid[0:h, 0:w].astype(np.float32)
        t_bwd = 1.0 - t
        map_x = np.round(grid_x - t_bwd * flow[:, :, 0]).astype(np.float32)
        map_y = np.round(grid_y - t_bwd * flow[:, :, 1]).astype(np.float32)

        out = cv2.remap(im1, map_x, map_y, cv2.INTER_NEAREST, borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0, 0))

    out[out[:, :, 3] < 10] = 0
    out = fill_interior_holes(out)
    return out

def main():
    print("Generating 24 FPS Flutter-Optimized Spritesheets (Mobile + Web)...")

    # Exact measured center shifts to lock anchor in place:
    ALIGNMENT_SHIFTS = {
        "idle":      [(0, 0), (10, 0), (10, -14), (26, 0)],
        "celebrate": [(0, 0), (8, 0),  (20, 0),   (19, 0)],
        "sad":       [(0, 0), (8, 0),  (16, 0),   (21, 0)],
        "intense":   [(0, 0), (4, 0),  (16, 0),   (20, 0)]
    }

    anims = [
        {"id": "idle", "title": "Repouso & Respiração (Idle)", "row": 0},
        {"id": "celebrate", "title": "Salto & Comemoração (Celebrate)", "row": 1},
        {"id": "sad", "title": "Tristeza & Choro (Sad)", "row": 2},
        {"id": "intense", "title": "Olhos de Fogo & Ofensiva (Intense)", "row": 3}
    ]

    # Master Atlas for Flutter: 12 columns x 8 rows (3072 x 2048 px)
    # Each animation takes 2 rows of 12 columns (24 frames)
    # Total dimensions: 3072 x 2048 px -> Guaranteed under 4096px WebGL/Mobile MAX_TEXTURE_SIZE!
    master_grid_24 = Image.new("RGBA", (256 * 12, 256 * 8), (0, 0, 0, 0))

    master_atlas_data = {
        "meta": {
            "app": "CEFET-NI Goat Mascot - Flutter & Web Edition",
            "version": "3.0 - 24 FPS Cinematic",
            "image": "bode_branco_24fps_master_grid.png",
            "size": {"w": 3072, "h": 2048},
            "fps": 24,
            "total_frames": 96,
            "target_platforms": ["Flutter Mobile (Android/iOS)", "Flutter Web (CanvasKit/Skia)", "Flame Engine"]
        },
        "animations": {}
    }

    catalog_data = []

    for anim_idx, anim_info in enumerate(anims):
        anim_id = anim_info["id"]
        title = anim_info["title"]
        shifts = ALIGNMENT_SHIFTS[anim_id]
        print(f"\nProcessing animation '{anim_id}' (24 frames)...")

        # Load and align 4 keyframes
        kfs = []
        for c in range(4):
            frame_file = os.path.join(FRAMES_SOURCE_DIR, f"{anim_id}_{c}.png")
            cell_np = np.array(Image.open(frame_file))
            dx, dy = shifts[c]
            kfs.append(shift_image_crisp(cell_np, dx, dy))

        # Generate 24 frames: 6 frames per segment
        # Segment 0: 0->1, Segment 1: 1->2, Segment 2: 2->3, Segment 3: 3->0
        twenty_four_frames_np = []
        for seg_idx in range(4):
            imA = kfs[seg_idx]
            imB = kfs[(seg_idx + 1) % 4]

            for sub_f in range(6):
                t = sub_f / 6.0
                if sub_f == 0:
                    twenty_four_frames_np.append(imA)
                else:
                    m = clean_warp_inbetween(imA, imB, t)
                    twenty_four_frames_np.append(m)

        anim_frames_dir = os.path.join(OUT_FRAMES_DIR, anim_id)
        os.makedirs(anim_frames_dir, exist_ok=True)

        # 1. Flutter Safe Grid: 6 columns x 4 rows (1536 x 1024 px)
        anim_grid = Image.new("RGBA", (256 * 6, 256 * 4), (0, 0, 0, 0))

        # 2. Horizontal Strip: 24 columns x 1 row (6144 x 256 px)
        anim_strip = Image.new("RGBA", (256 * 24, 256), (0, 0, 0, 0))

        anim_frames_pil = []
        anim_frames_meta = []

        for f_idx, f_arr in enumerate(twenty_four_frames_np):
            f_pil = Image.fromarray(f_arr)
            anim_frames_pil.append(f_pil)

            # Individual PNG frame
            frame_filename = f"frame_{f_idx:02d}.png"
            f_pil.save(os.path.join(anim_frames_dir, frame_filename))

            # Horizontal strip placement
            anim_strip.paste(f_pil, (f_idx * 256, 0))

            # 6x4 Grid placement (col: 0..5, row: 0..3)
            g_col = f_idx % 6
            g_row = f_idx // 6
            anim_grid.paste(f_pil, (g_col * 256, g_row * 256))

            # Master 12x8 Atlas placement (each anim takes 2 rows of 12)
            m_col = f_idx % 12
            m_row = anim_idx * 2 + (f_idx // 12)
            master_grid_24.paste(f_pil, (m_col * 256, m_row * 256))

            anim_frames_meta.append({
                "index": f_idx,
                "file": frame_filename,
                "grid_pos": {"col": g_col, "row": g_row, "x": g_col * 256, "y": g_row * 256},
                "master_pos": {"col": m_col, "row": m_row, "x": m_col * 256, "y": m_row * 256},
                "duration_ms": 41.67
            })

        # Save Grid Sheet (Flutter Recommended)
        grid_sheet_path = os.path.join(OUT_SHEETS_24, f"bode_branco_24fps_{anim_id}_grid.png")
        anim_grid.save(grid_sheet_path)
        print(f"Saved Flutter Grid Sheet (1536x1024): {grid_sheet_path}")

        # Save Strip Sheet
        strip_sheet_path = os.path.join(OUT_SHEETS_24, f"bode_branco_24fps_{anim_id}_strip.png")
        anim_strip.save(strip_sheet_path)

        # Save JSON Atlas
        json_path = os.path.join(OUT_SHEETS_24, f"bode_branco_24fps_{anim_id}.json")
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump({
                "animation": anim_id,
                "title": title,
                "fps": 24,
                "total_frames": 24,
                "frame_size": {"w": 256, "h": 256},
                "grid": {"cols": 6, "rows": 4, "sheet_size": {"w": 1536, "h": 1024}},
                "strip": {"cols": 24, "rows": 1, "sheet_size": {"w": 6144, "h": 256}},
                "frames": anim_frames_meta
            }, f, indent=2, ensure_ascii=False)

        # Save 24 FPS Preview GIF (duration = 41.67ms -> 42ms per frame)
        gif_path = os.path.join(BASE_DIR, f"bode_branco_24fps_{anim_id}.gif")
        anim_frames_pil[0].save(
            gif_path,
            save_all=True,
            append_images=anim_frames_pil[1:],
            duration=42,
            loop=0,
            disposal=2
        )
        print(f"Saved 24 FPS GIF: {gif_path}")

        master_atlas_data["animations"][anim_id] = {
            "title": title,
            "grid_rows": [anim_idx * 2, anim_idx * 2 + 1],
            "frames": anim_frames_meta
        }

        catalog_data.append({
            "id": anim_id,
            "title": title,
            "fps": 24,
            "frames": 24,
            "grid_path": f"spritesheets_24fps/bode_branco_24fps_{anim_id}_grid.png",
            "strip_path": f"spritesheets_24fps/bode_branco_24fps_{anim_id}_strip.png",
            "gif_path": f"bode_branco_24fps_{anim_id}.gif"
        })

    # Save Master Atlas (3072 x 2048 px)
    master_atlas_path = os.path.join(OUT_SHEETS_24, "bode_branco_24fps_master_grid.png")
    master_grid_24.save(master_atlas_path)
    master_grid_24.save(os.path.join(BASE_DIR, "bode_branco_24fps_master_grid.png"))
    print(f"\nSaved Master Atlas (3072x2048 px): {master_atlas_path}")

    # Save Master JSON Atlas
    master_json_path = os.path.join(OUT_SHEETS_24, "bode_branco_24fps_master.json")
    with open(master_json_path, "w", encoding="utf-8") as f:
        json.dump(master_atlas_data, f, indent=2, ensure_ascii=False)

    # Save Catalog JSON
    catalog_json_path = os.path.join(OUT_SHEETS_24, "catalog_24fps.json")
    with open(catalog_json_path, "w", encoding="utf-8") as f:
        json.dump(catalog_data, f, indent=2, ensure_ascii=False)

    print("\nAll 24 FPS Flutter-optimized assets generated successfully!")

if __name__ == "__main__":
    main()
