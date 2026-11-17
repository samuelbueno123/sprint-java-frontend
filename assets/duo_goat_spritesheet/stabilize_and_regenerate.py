import os
import json
import cv2
import numpy as np
from PIL import Image

BASE_DIR = r"C:\Users\Pedro\.gemini\antigravity\scratch\duo_goat_spritesheet"
FRAMES_SOURCE_DIR = os.path.join(BASE_DIR, "inspect_frames")
OUT_SHEETS_12 = os.path.join(BASE_DIR, "spritesheets_12fps")
OUT_SHEETS_4 = os.path.join(BASE_DIR, "spritesheets_duo")
OUT_FRAMES_DIR = os.path.join(BASE_DIR, "frames_12fps")

os.makedirs(OUT_SHEETS_12, exist_ok=True)
os.makedirs(OUT_SHEETS_4, exist_ok=True)
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
    print("Stabilizing mascot anchor and regenerating zero-blur spritesheets...")

    # Exact measured center shifts to lock anchor in place:
    # Completely eliminates backwards slide drift and sinking into ground
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

    # 1. Stabilize 4x4 Master Sheet from original inspect_frames
    master_4x4_stabilized = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    stabilized_keyframes = {}

    for anim_info in anims:
        anim_id = anim_info["id"]
        row_idx = anim_info["row"]
        shifts = ALIGNMENT_SHIFTS[anim_id]

        row_kfs = []
        strip_4 = Image.new("RGBA", (1024, 256), (0, 0, 0, 0))

        for c in range(4):
            frame_file = os.path.join(FRAMES_SOURCE_DIR, f"{anim_id}_{c}.png")
            cell_np = np.array(Image.open(frame_file))
            dx, dy = shifts[c]
            shifted_np = shift_image_crisp(cell_np, dx, dy)
            shifted_pil = Image.fromarray(shifted_np)

            row_kfs.append(shifted_np)
            master_4x4_stabilized.paste(shifted_pil, (c * 256, row_idx * 256))
            strip_4.paste(shifted_pil, (c * 256, 0))

        stabilized_keyframes[anim_id] = row_kfs

        # Save 4-frame strip
        strip_4_path = os.path.join(OUT_SHEETS_4, f"bode_branco_{anim_id}_sheet.png")
        strip_4.save(strip_4_path)

        # Save 4-frame GIF preview
        kfs_pil = [Image.fromarray(k) for k in row_kfs]
        kfs_pil[0].save(
            os.path.join(BASE_DIR, f"bode_branco_{anim_id}_anim.gif"),
            save_all=True,
            append_images=kfs_pil[1:],
            duration=250,
            loop=0,
            disposal=2
        )

    # Save stabilized 4x4 master
    master_4x4_stabilized.save(os.path.join(BASE_DIR, "bode_branco_spritesheet_master.png"))
    print("Stabilized 4x4 Master Sheet saved successfully!")

    # 2. Generate 12 FPS Sheets from Stabilized Keyframes
    master_12fps = Image.new("RGBA", (256 * 12, 256 * 4), (0, 0, 0, 0))
    grid_12fps = Image.new("RGBA", (256 * 6, 256 * 8), (0, 0, 0, 0))

    master_atlas_12 = {
        "meta": {
            "app": "CEFET-NI Goat Mascot - Antigravity",
            "version": "2.3 - Perfectly Stabilized Zero-Drift Edition",
            "image": "bode_branco_12fps_master_sheet.png",
            "size": {"w": 3072, "h": 1024},
            "fps": 12,
            "total_frames": 48
        },
        "animations": {}
    }

    catalog_data = []

    for anim_info in anims:
        anim_id = anim_info["id"]
        row_idx = anim_info["row"]
        title = anim_info["title"]
        print(f"Generating 12 stabilized frames for '{anim_id}'...")

        kfs = stabilized_keyframes[anim_id]

        twelve_frames_np = []
        for i in range(4):
            imA = kfs[i]
            imB = kfs[(i + 1) % 4]

            twelve_frames_np.append(imA)
            m1 = clean_warp_inbetween(imA, imB, 0.333)
            twelve_frames_np.append(m1)
            m2 = clean_warp_inbetween(imA, imB, 0.667)
            twelve_frames_np.append(m2)

        anim_frames_dir = os.path.join(OUT_FRAMES_DIR, anim_id)
        os.makedirs(anim_frames_dir, exist_ok=True)

        strip_sheet = Image.new("RGBA", (256 * 12, 256), (0, 0, 0, 0))
        anim_frames_pil = []
        anim_atlas_frames = []

        for f_idx, f_arr in enumerate(twelve_frames_np):
            f_pil = Image.fromarray(f_arr)
            anim_frames_pil.append(f_pil)

            frame_filename = f"frame_{f_idx:02d}.png"
            f_pil.save(os.path.join(anim_frames_dir, frame_filename))

            strip_sheet.paste(f_pil, (f_idx * 256, 0))
            master_12fps.paste(f_pil, (f_idx * 256, row_idx * 256))

            grid_row = row_idx * 2 + (f_idx // 6)
            grid_col = f_idx % 6
            grid_12fps.paste(f_pil, (grid_col * 256, grid_row * 256))

            anim_atlas_frames.append({
                "filename": frame_filename,
                "frame": {"x": f_idx * 256, "y": 0, "w": 256, "h": 256},
                "duration": 83
            })

        # Save horizontal strip
        strip_path = os.path.join(OUT_SHEETS_12, f"bode_branco_12fps_{anim_id}_sheet.png")
        strip_sheet.save(strip_path)

        # Save JSON atlas
        with open(os.path.join(OUT_SHEETS_12, f"bode_branco_12fps_{anim_id}.json"), "w", encoding="utf-8") as f:
            json.dump({
                "meta": {"animation": anim_id, "title": title, "fps": 12, "frames": 12},
                "frames": anim_atlas_frames
            }, f, indent=2, ensure_ascii=False)

        # Save 12 FPS loop GIF
        gif_path = os.path.join(BASE_DIR, f"bode_branco_12fps_{anim_id}.gif")
        anim_frames_pil[0].save(
            gif_path,
            save_all=True,
            append_images=anim_frames_pil[1:],
            duration=83,
            loop=0,
            disposal=2
        )

        master_atlas_12["animations"][anim_id] = {
            "title": title,
            "row": row_idx,
            "frames": anim_atlas_frames
        }

        catalog_data.append({
            "id": anim_id,
            "title": title,
            "frames_count": 12,
            "fps": 12,
            "sheet_path": f"spritesheets_12fps/bode_branco_12fps_{anim_id}_sheet.png",
            "gif_path": f"bode_branco_12fps_{anim_id}.gif"
        })

    # Save Master Sheets
    master_12fps.save(os.path.join(OUT_SHEETS_12, "bode_branco_12fps_master_sheet.png"))
    master_12fps.save(os.path.join(BASE_DIR, "bode_branco_12fps_master_sheet.png"))

    grid_12fps.save(os.path.join(OUT_SHEETS_12, "bode_branco_12fps_grid_sheet.png"))
    grid_12fps.save(os.path.join(BASE_DIR, "bode_branco_12fps_grid_sheet.png"))

    with open(os.path.join(OUT_SHEETS_12, "bode_branco_12fps_master.json"), "w", encoding="utf-8") as f:
        json.dump(master_atlas_12, f, indent=2, ensure_ascii=False)

    with open(os.path.join(OUT_SHEETS_12, "catalog_12fps.json"), "w", encoding="utf-8") as f:
        json.dump(catalog_data, f, indent=2, ensure_ascii=False)

    print("All stabilized, zero-drift, zero-blur spritesheets generated successfully!")

if __name__ == "__main__":
    main()
