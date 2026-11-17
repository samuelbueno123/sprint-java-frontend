import os
import json
import math
import cv2
import numpy as np
from PIL import Image

BASE_DIR = r"C:\Users\Pedro\.gemini\antigravity\scratch\duo_goat_spritesheet"
FRAMES_SRC = os.path.join(BASE_DIR, "inspect_frames")
OUT_SHEETS_DIR = os.path.join(BASE_DIR, "spritesheets_interactive")
OUT_FRAMES_DIR = os.path.join(BASE_DIR, "frames_interactive")
os.makedirs(OUT_SHEETS_DIR, exist_ok=True)
os.makedirs(OUT_FRAMES_DIR, exist_ok=True)

# Shifts used to stabilize keyframes:
ALIGNMENT_SHIFTS = {
    "idle":      [(0, 0), (10, 0), (10, -14), (26, 0)],
    "celebrate": [(0, 0), (8, 0),  (20, 0),   (19, 0)],
    "sad":       [(0, 0), (8, 0),  (16, 0),   (21, 0)],
    "intense":   [(0, 0), (4, 0),  (16, 0),   (20, 0)]
}

def shift_image_crisp(img_arr, dx, dy):
    if dx == 0 and dy == 0:
        return img_arr.copy()
    h, w = img_arr.shape[:2]
    out = np.zeros_like(img_arr)
    src_y1 = max(0, -dy); src_y2 = min(h, h - dy)
    src_x1 = max(0, -dx); src_x2 = min(w, w - dx)
    dst_y1 = max(0, dy);  dst_y2 = min(h, h + dy)
    dst_x1 = max(0, dx);  dst_x2 = min(w, w + dx)
    out[dst_y1:dst_y2, dst_x1:dst_x2] = img_arr[src_y1:src_y2, src_x1:src_x2]
    return out

def transform_crisp(img_arr, scale_x=1.0, scale_y=1.0, dx=0, dy=0, shear_x=0.0, anchor=(145, 241)):
    """
    Apply scale, shear and translation using nearest neighbor to preserve 100% pixel art crispness.
    """
    h, w = img_arr.shape[:2]
    ax, ay = anchor
    
    # Transformation matrix mapping from output to input (inverse mapping)
    # Output = M * (Input - Anchor) + Anchor + [dx, dy]
    # Input = M_inv * (Output - Anchor - [dx, dy]) + Anchor
    
    # Forward matrix:
    # [x'] = [scale_x, shear_x] * [x - ax] + ax + dx
    # [y'] = [0,       scale_y] * [y - ay] + ay + dy
    
    grid_y, grid_x = np.mgrid[0:h, 0:w].astype(np.float32)
    
    # Shift relative to destination anchor
    rel_x = grid_x - (ax + dx)
    rel_y = grid_y - (ay + dy)
    
    # Invert scale & shear
    in_y = rel_y / max(0.01, scale_y)
    in_x = (rel_x - shear_x * in_y) / max(0.01, scale_x)
    
    map_x = np.round(in_x + ax).astype(np.float32)
    map_y = np.round(in_y + ay).astype(np.float32)
    
    out = cv2.remap(img_arr, map_x, map_y, cv2.INTER_NEAREST, borderMode=cv2.BORDER_CONSTANT, borderValue=(0,0,0,0))
    return out

def draw_star(arr, cx, cy, radius=5, color=(255, 215, 0, 255)):
    """Draw clean pixel art 4-pointed sparkle star."""
    for i in range(-radius, radius + 1):
        if 0 <= cy < 256 and 0 <= cx + i < 256:
            arr[cy, cx + i] = color
        if 0 <= cy + i < 256 and 0 <= cx < 256:
            arr[cy + i, cx] = color
    # Diagonal sparkles
    r_diag = max(1, radius // 2)
    for d in range(-r_diag, r_diag + 1):
        if 0 <= cy + d < 256 and 0 <= cx + d < 256:
            arr[cy + d, cx + d] = color
        if 0 <= cy + d < 256 and 0 <= cx - d < 256:
            arr[cy + d, cx - d] = color

def draw_pixel_heart(arr, cx, cy, size=1):
    """Draw cute pixel art heart at (cx, cy)."""
    # 5x5 heart pattern
    pattern = [
        " 0 0 ",
        "00000",
        "00000",
        " 000 ",
        "  0  "
    ]
    pink = (255, 105, 180, 255)
    dark_pink = (219, 39, 119, 255)
    for r_idx, row in enumerate(pattern):
        for c_idx, ch in enumerate(row):
            if ch == '0':
                px = cx + (c_idx - 2) * size
                py = cy + (r_idx - 2) * size
                for dy in range(size):
                    for dx in range(size):
                        if 0 <= py + dy < 256 and 0 <= px + dx < 256:
                            arr[py + dy, px + dx] = pink if r_idx > 0 and 0 < c_idx < 4 else dark_pink

def draw_music_note(arr, cx, cy):
    """Draw clean 8th musical note in pixel art."""
    blue = (28, 176, 246, 255)
    dark_blue = (24, 153, 214, 255)
    # Stem
    for y in range(cy - 12, cy + 2):
        if 0 <= y < 256 and 0 <= cx + 4 < 256:
            arr[y, cx + 4] = blue
    # Note head (oval)
    for dy in range(-2, 3):
        for dx in range(-4, 3):
            if dx*dx + dy*dy*2 <= 8:
                if 0 <= cy + dy < 256 and 0 <= cx + dx < 256:
                    arr[cy + dy, cx + dx] = dark_blue
    # Flag
    for dy in range(5):
        if 0 <= cy - 12 + dy < 256 and 0 <= cx + 4 + dy < 256:
            arr[cy - 12 + dy, cx + 4 + dy] = blue

def draw_impact_shockwave(arr, cx, cy, radius_x, radius_y, color=(255, 255, 255, 220)):
    """Draw comic shockwave ring / lines."""
    for angle in range(0, 360, 10):
        rad = math.radians(angle)
        x = int(cx + radius_x * math.cos(rad))
        y = int(cy + radius_y * math.sin(rad))
        if 0 <= y < 256 and 0 <= x < 256:
            arr[y, x] = color
            if 0 <= y+1 < 256: arr[y+1, x] = color

def draw_dust_puff(arr, cx, cy, radius=6):
    """Draw cartoon dust cloud."""
    dust_c = (226, 232, 240, 255)
    border_c = (148, 163, 184, 255)
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            d2 = dx*dx + dy*dy
            if d2 <= radius*radius:
                py, px = cy + dy, cx + dx
                if 0 <= py < 256 and 0 <= px < 256:
                    arr[py, px] = border_c if d2 > (radius - 1)*(radius - 1) else dust_c

def load_stabilized_bases():
    bases = {}
    for anim in ["idle", "celebrate", "sad", "intense"]:
        shifts = ALIGNMENT_SHIFTS[anim]
        for c in range(4):
            path = os.path.join(FRAMES_SRC, f"{anim}_{c}.png")
            im = np.array(Image.open(path))
            dx, dy = shifts[c]
            bases[f"{anim}_{c}"] = shift_image_crisp(im, dx, dy)
    return bases

print("Base generator utilities defined!")

def build_fire_loop(bases):
    """
    Sustained flaming eyes loop: confident pointing streak-reminder stance,
    with organic crackling flames (fogo crepitando nos olhos), undulating licking tongues,
    sparks and flying embers (fagulhas), and incandescent eye pupil heat pulse.
    """
    base_img = bases["intense_3"].copy()
    H, W = base_img.shape[:2]

    def is_fire_pixel(c, x, y):
        if c[3] == 0:
            return False
        r, g, b = int(c[0]), int(c[1]), int(c[2])
        if r > 230 and g > 230 and b > 230:
            return False
        if x < 130 and y < 65:  # horn left
            return False
        if x > 195 and y < 55:  # horn right
            return False
        if r > 180 and g > 50 and b < 100:
            return True
        if r > 220 and g > 150 and b < 160:
            return True
        if r > 150 and g < 60 and b < 50:
            return True
        if r < 60 and g < 40 and b < 30 and y < 94:
            if (x in range(120, 150) or x in range(165, 202)):
                return True
        return False

    # Separate Left Flame and Right Flame sources (above eyebrows, Y <= 94)
    flame_left_src = np.zeros_like(base_img)
    flame_right_src = np.zeros_like(base_img)
    body_clean = base_img.copy()

    for y in range(35, 120):
        for x in range(115, 210):
            c = base_img[y, x]
            if is_fire_pixel(c, x, y) and y <= 94:
                if x <= 155:
                    flame_left_src[y, x] = c
                else:
                    flame_right_src[y, x] = c
                if y < 85:
                    body_clean[y, x] = [0, 0, 0, 0]

    COL_WHITE_HOT = np.array([255, 255, 235, 255], dtype=np.uint8)
    COL_YELLOW_HOT = np.array([255, 235, 59, 255], dtype=np.uint8)
    COL_ORANGE_FIRE = np.array([255, 140, 0, 255], dtype=np.uint8)
    COL_DEEP_EMBER = np.array([220, 50, 5, 255], dtype=np.uint8)

    left_iris_pixels = []
    for y in range(97, 109):
        for x in range(125, 145):
            c = base_img[y, x]
            if c[3] > 0 and c[0] > 220 and c[1] > 180 and c[2] < 150:
                left_iris_pixels.append((x, y))

    right_iris_pixels = []
    for y in range(95, 109):
        for x in range(165, 188):
            c = base_img[y, x]
            if c[3] > 0 and c[0] > 220 and c[1] > 180 and c[2] < 150:
                right_iris_pixels.append((x, y))

    def render_flame_eye(flame_src, x_center, y_base, phase_offset, t, is_left=True):
        out_flame = np.zeros_like(flame_src)
        sy = 1.0 + 0.32 * math.sin(2.0 * math.pi * (t / 6.0) + phase_offset)
        
        for y in range(25, y_base + 1):
            h = y_base - y
            if h <= 0:
                for x in range(x_center - 25, x_center + 26):
                    if 0 <= x < W:
                        out_flame[y, x] = flame_src[y, x]
                continue
            
            wave_phase = 2.0 * math.pi * (t / 6.0) - (h / 13.0) + phase_offset
            amp = 4.5 * ((h / 60.0) ** 1.3)
            dx = amp * math.sin(wave_phase)
            
            if is_left:
                dx -= 2.0 * (h / 60.0) * math.sin(math.pi * t / 6.0)
            else:
                dx += 2.0 * (h / 60.0) * math.cos(math.pi * t / 6.0)
                
            h_src = h / sy
            y_src = int(round(y_base - h_src))
            
            if not (0 <= y_src < H):
                continue
                
            for x in range(x_center - 28, x_center + 29):
                if not (0 <= x < W):
                    continue
                x_src = int(round(x - dx))
                if 0 <= x_src < W:
                    c = flame_src[y_src, x_src]
                    if c[3] > 0:
                        out_flame[y, x] = c
                        
        sin_val = math.sin(2.0 * math.pi * (t / 6.0) + phase_offset)
        if sin_val > 0.65:
            tip_y = int(round(y_base - (48 * sy + (sin_val - 0.65) * 22)))
            tip_x = int(round(x_center + dx * 1.2))
            if 20 <= tip_y < y_base:
                for dy_t in [-1, 0, 1]:
                    for dx_t in [-1, 0, 1]:
                        py = tip_y + dy_t
                        px = tip_x + dx_t
                        if 0 <= py < H and 0 <= px < W:
                            if abs(dy_t) + abs(dx_t) <= 1:
                                out_flame[py, px] = COL_YELLOW_HOT
                            elif abs(dy_t) + abs(dx_t) == 2:
                                out_flame[py, px] = COL_ORANGE_FIRE
                                
        return out_flame

    embers_spec = [
        # Left eye embers: (spawn_t, x_start, y_start, vx, vy)
        (0, 136, 75, -0.6, -4.5),
        (4, 138, 72, 0.4, -4.8),
        (8, 134, 76, -0.8, -4.6),
        # Right eye embers
        (2, 178, 73, 0.7, -4.7),
        (6, 180, 71, -0.5, -4.9),
        (10, 182, 74, 0.6, -4.6),
        # Extra quick pop sparks (crepitação instantânea)
        (1, 142, 60, 0.8, -3.0),
        (3, 172, 58, -0.7, -3.2),
        (5, 130, 62, -0.9, -3.5),
        (7, 188, 59, 1.0, -3.0),
        (9, 145, 55, 0.5, -3.4),
        (11, 175, 56, -0.6, -3.3)
    ]

    def draw_sparks(frame, t):
        for (spawn_t, sx, sy_start, vx, vy) in embers_spec:
            age = (t - spawn_t) % 12
            if age < 4:
                px = int(round(sx + vx * age + math.sin(age * 1.5) * 1.2))
                py = int(round(sy_start + vy * age - 0.3 * (age ** 2)))
                if 0 <= py < H and 0 <= px < W:
                    if age == 0:
                        for dy in [0, 1]:
                            for dx in [0, 1]:
                                if 0 <= py+dy < H and 0 <= px+dx < W:
                                    frame[py+dy, px+dx] = COL_WHITE_HOT
                    elif age == 1:
                        frame[py, px] = COL_WHITE_HOT
                        for (dx, dy) in [(-1,0), (1,0), (0,-1), (0,1)]:
                            if 0 <= py+dy < H and 0 <= px+dx < W:
                                frame[py+dy, px+dx] = COL_YELLOW_HOT
                    elif age == 2:
                        frame[py, px] = COL_ORANGE_FIRE
                        if 0 <= py-1 < H:
                            frame[py-1, px] = COL_YELLOW_HOT
                    elif age == 3:
                        frame[py, px] = COL_DEEP_EMBER

    def draw_eye_heat(frame, t):
        heat_left = math.sin(2.0 * math.pi * (t / 6.0))
        heat_right = math.sin(2.0 * math.pi * (t / 6.0) + math.pi / 2.0)
        
        for (x, y) in left_iris_pixels:
            if heat_left > 0.4:
                if (132 <= x <= 136) and (99 <= y <= 104):
                    frame[y, x] = COL_WHITE_HOT
                else:
                    frame[y, x] = COL_YELLOW_HOT
            elif heat_left < -0.4:
                frame[y, x] = np.array([255, 200, 0, 255], dtype=np.uint8)
                
        for (x, y) in right_iris_pixels:
            if heat_right > 0.4:
                if (174 <= x <= 178) and (97 <= y <= 102):
                    frame[y, x] = COL_WHITE_HOT
                else:
                    frame[y, x] = COL_YELLOW_HOT
            elif heat_right < -0.4:
                frame[y, x] = np.array([255, 200, 0, 255], dtype=np.uint8)

    frames = []
    for t in range(12):
        body_dy = int(round(math.sin(t * math.pi / 6.0) * 1.0))
        frame = np.zeros_like(body_clean)
        if body_dy == 0:
            frame[:] = body_clean
        elif body_dy > 0:
            frame[body_dy:, :] = body_clean[:-body_dy, :]
        else:
            frame[:body_dy, :] = body_clean[-body_dy:, :]
            
        flame_l = render_flame_eye(flame_left_src, 136, 94, 0.0, t, is_left=True)
        flame_r = render_flame_eye(flame_right_src, 180, 94, math.pi / 2.0, t, is_left=False)
        
        if body_dy != 0:
            fl_shifted_l = np.zeros_like(flame_l)
            fl_shifted_r = np.zeros_like(flame_r)
            if body_dy > 0:
                fl_shifted_l[body_dy:, :] = flame_l[:-body_dy, :]
                fl_shifted_r[body_dy:, :] = flame_r[:-body_dy, :]
            else:
                fl_shifted_l[:body_dy, :] = flame_l[-body_dy:, :]
                fl_shifted_r[:body_dy, :] = flame_r[-body_dy:, :]
            flame_l = fl_shifted_l
            flame_r = fl_shifted_r
            
        mask_l = flame_l[:, :, 3] > 0
        frame[mask_l] = flame_l[mask_l]
        mask_r = flame_r[:, :, 3] > 0
        frame[mask_r] = flame_r[mask_r]
        
        draw_eye_heat(frame, t)
        draw_sparks(frame, t)
        frames.append(frame)

    return frames

def build_click_poke(bases):
    """Click reaction 1: Surprised poke / hop in the air."""
    f0 = bases["idle_0"]
    f_squint = bases["idle_1"]
    f_alert = bases["idle_3"]
    f_jump = bases["celebrate_2"]
    f_squash = bases["celebrate_3"]
    
    frames = []
    # 0: idle
    frames.append(f0)
    # 1: dip anticipation
    frames.append(transform_crisp(f0, scale_x=1.05, scale_y=0.92, dy=4))
    # 2: pop up with surprised eyes
    f2 = transform_crisp(f_alert, scale_x=0.94, scale_y=1.08, dy=-14)
    # Exclamation mark
    draw_star(f2, 185, 50, radius=2, color=(255, 75, 75, 255))
    frames.append(f2)
    # 3: apex
    frames.append(transform_crisp(f_jump, scale_x=0.98, scale_y=1.02, dy=-16))
    # 4: hang in air
    frames.append(transform_crisp(f_jump, dy=-14))
    # 5: falling
    frames.append(transform_crisp(f_squash, dy=-7))
    # 6: touchdown squash
    frames.append(transform_crisp(f_squash, scale_x=1.08, scale_y=0.90, dy=4))
    # 7: recoil
    frames.append(transform_crisp(f_squint, scale_x=0.98, scale_y=1.02, dy=-2))
    # 8: blink
    frames.append(f_squint)
    # 9: cute smile
    frames.append(f_squint)
    # 10: settle
    frames.append(f_alert)
    # 11: return to idle
    frames.append(f0)
    return frames

def build_click_bleat(bases):
    """Click reaction 2: Loud happy BÉÉÉ! with musical note."""
    f0 = bases["idle_0"]
    f1 = bases["idle_1"]
    f2 = bases["idle_2"]
    
    frames = []
    # 0: idle
    frames.append(f0)
    # 1: inhale chest rise
    frames.append(transform_crisp(f0, scale_x=0.97, scale_y=1.04, dy=-2))
    # 2: head lifts
    frames.append(transform_crisp(f2, dy=-2))
    # 3: loud BÉÉÉ! shout + note emerges
    f3 = transform_crisp(f2, scale_x=1.05, scale_y=1.05, dy=-4)
    draw_music_note(f3, 185, 95)
    frames.append(f3)
    # 4: hold bleat, note rises
    f4 = transform_crisp(f2, scale_x=1.04, scale_y=1.04, dy=-3)
    draw_music_note(f4, 192, 80)
    frames.append(f4)
    # 5: note sparkles, mouth closing
    f5 = transform_crisp(f2, dy=-1)
    draw_music_note(f5, 198, 65)
    draw_star(f5, 208, 60, radius=2)
    frames.append(f5)
    # 6: big happy smile
    f6 = f1.copy()
    # Pink blush
    for dy in range(-2, 3):
        for dx in range(-4, 5):
            if dx*dx + dy*dy*2 <= 8:
                f6[115 + dy, 115 + dx] = (255, 182, 193, 255)
                f6[115 + dy, 175 + dx] = (255, 182, 193, 255)
    frames.append(f6)
    # 7: ear flap left
    frames.append(transform_crisp(f1, shear_x=-0.04))
    # 8: ear flap right
    frames.append(transform_crisp(f1, shear_x=0.04))
    # 9: smile
    frames.append(f1)
    # 10: settle
    frames.append(bases["idle_3"])
    # 11: idle
    frames.append(f0)
    return frames

def build_click_shake(bases):
    """Click reaction 3: Shake head vigorously to fluff wool."""
    f0 = bases["idle_0"]
    f1 = bases["idle_1"]
    
    frames = []
    # 0: idle
    frames.append(f0)
    # 1: tilt left
    frames.append(transform_crisp(f1, dx=-4, shear_x=-0.05))
    # 2: whip right
    f2 = transform_crisp(f1, dx=6, shear_x=0.08)
    draw_dust_puff(f2, 90, 235, radius=5)
    frames.append(f2)
    # 3: whip left
    f3 = transform_crisp(f1, dx=-6, shear_x=-0.08)
    draw_dust_puff(f3, 200, 235, radius=5)
    frames.append(f3)
    # 4: shake right
    frames.append(transform_crisp(f1, dx=4, shear_x=0.04))
    # 5: shake left
    frames.append(transform_crisp(f1, dx=-3, shear_x=-0.03))
    # 6: puff cheeks
    frames.append(transform_crisp(bases["intense_1"], scale_x=1.04, scale_y=0.96))
    # 7: exhale
    frames.append(bases["idle_2"])
    # 8: settle wool
    frames.append(bases["idle_3"])
    # 9: smile
    frames.append(f1)
    # 10: settle
    frames.append(bases["idle_3"])
    # 11: idle
    frames.append(f0)
    return frames

def build_click_spin(bases):
    """Click reaction 4: Joyful 360 pirouette spin."""
    f0 = bases["idle_0"]
    f_crouch = bases["celebrate_0"]
    f_jump = bases["celebrate_1"]
    f_squash = bases["celebrate_3"]
    f1 = bases["idle_1"]
    
    frames = []
    # 0: idle
    frames.append(f0)
    # 1: wind-up crouch
    frames.append(transform_crisp(f_crouch, scale_x=1.06, scale_y=0.92, dy=4))
    # 2: jump spin 45 deg
    frames.append(transform_crisp(f_jump, scale_x=0.75, scale_y=1.05, dy=-10))
    # 3: 90 deg profile
    f3 = transform_crisp(f_jump, scale_x=0.35, scale_y=1.08, dy=-16)
    # Wind swoosh line
    draw_dust_puff(f3, 100, 160, radius=3)
    frames.append(f3)
    # 4: 180 deg back view
    f4 = transform_crisp(f0[:, ::-1], scale_x=0.95, scale_y=1.05, dy=-16)
    frames.append(f4)
    # 5: 270 deg other profile
    f5 = transform_crisp(f_jump[:, ::-1], scale_x=0.35, scale_y=1.08, dy=-12)
    draw_dust_puff(f5, 190, 160, radius=3)
    frames.append(f5)
    # 6: facing front landing
    frames.append(transform_crisp(f_jump, scale_x=0.85, scale_y=1.02, dy=-6))
    # 7: touchdown squash with stars
    f7 = transform_crisp(f_squash, scale_x=1.10, scale_y=0.88, dy=5)
    draw_star(f7, 95, 60, radius=4)
    draw_star(f7, 195, 60, radius=4)
    draw_star(f7, 145, 30, radius=5)
    frames.append(f7)
    # 8: victory recoil
    f8 = transform_crisp(f_jump, scale_x=0.98, scale_y=1.02, dy=-2)
    draw_star(f8, 90, 50, radius=2)
    draw_star(f8, 200, 50, radius=2)
    frames.append(f8)
    # 9: wink
    frames.append(f1)
    # 10: settle
    frames.append(bases["idle_3"])
    # 11: idle
    frames.append(f0)
    return frames

def build_click_heart(bases):
    """Click reaction 5: Loving nuzzle with floating hearts."""
    f0 = bases["idle_0"]
    f1 = bases["idle_1"]
    
    frames = []
    # 0: idle
    frames.append(f0)
    # 1: nuzzle forward
    frames.append(transform_crisp(f0, dx=4, dy=-2))
    # 2: bliss smile
    f2 = f1.copy()
    # Cheeks blush
    for dy in range(-2, 3):
        for dx in range(-4, 5):
            if dx*dx + dy*dy*2 <= 8:
                f2[115 + dy, 115 + dx] = (255, 182, 193, 255)
                f2[115 + dy, 175 + dx] = (255, 182, 193, 255)
    frames.append(f2)
    # 3: heart 1 pops
    f3 = f2.copy()
    draw_pixel_heart(f3, 150, 45, size=2)
    frames.append(f3)
    # 4: heart 1 rises, heart 2 appears
    f4 = f2.copy()
    draw_pixel_heart(f4, 155, 32, size=2)
    draw_pixel_heart(f4, 135, 48, size=2)
    frames.append(f4)
    # 5: hearts pulse, body sways
    f5 = transform_crisp(f2, shear_x=0.03)
    draw_pixel_heart(f5, 160, 22, size=2)
    draw_pixel_heart(f5, 140, 36, size=2)
    frames.append(f5)
    # 6: tail wag
    f6 = transform_crisp(f2, shear_x=-0.03)
    draw_pixel_heart(f6, 162, 14, size=2)
    draw_pixel_heart(f6, 142, 26, size=2)
    frames.append(f6)
    # 7: hearts sparkle
    f7 = f2.copy()
    draw_star(f7, 162, 14, radius=3, color=(255, 105, 180, 255))
    draw_star(f7, 142, 26, radius=3, color=(255, 105, 180, 255))
    frames.append(f7)
    # 8: sparkles dissolve
    f8 = f2.copy()
    draw_star(f8, 162, 14, radius=1, color=(255, 192, 203, 255))
    frames.append(f8)
    # 9: warm smile
    frames.append(f1)
    # 10: settle
    frames.append(bases["idle_3"])
    # 11: idle
    frames.append(f0)
    return frames

# Drag Animations
def build_drag_start_right(bases):
    f0 = bases["idle_0"]
    f1 = bases["celebrate_1"]
    frames = []
    for i in range(12):
        t = i / 11.0
        dx = int(round(t * 18))
        shear = t * 0.16
        sx = 1.0 + t * 0.08
        sy = 1.0 - t * 0.05
        base = f0 if t < 0.6 else f1
        frame = transform_crisp(base, scale_x=sx, scale_y=sy, dx=dx, shear_x=shear)
        frames.append(frame)
    return frames

def build_drag_move_right(bases):
    f_fly = bases["celebrate_1"]
    frames = []
    for i in range(12):
        wobble_y = int(round(math.sin(i * math.pi / 3.0) * 3))
        wobble_x = int(round(math.cos(i * math.pi / 3.0) * 2))
        frame = transform_crisp(f_fly, scale_x=1.10, scale_y=0.94, dx=14 + wobble_x, dy=-8 + wobble_y, shear_x=0.18)
        # Wind speed lines
        line_y = 100 + (i * 12) % 100
        for lx in range(40, 100):
            if (lx + i * 8) % 16 < 8:
                frame[line_y, lx] = (226, 232, 240, 220)
        frames.append(frame)
    return frames

def build_drag_start_left(bases):
    f0 = bases["idle_0"]
    f1 = bases["celebrate_1"]
    frames = []
    for i in range(12):
        t = i / 11.0
        dx = int(round(-t * 18))
        shear = -t * 0.16
        sx = 1.0 + t * 0.08
        sy = 1.0 - t * 0.05
        base = f0 if t < 0.6 else f1
        frame = transform_crisp(base, scale_x=sx, scale_y=sy, dx=dx, shear_x=shear)
        frames.append(frame)
    return frames

def build_drag_move_left(bases):
    f_fly = bases["celebrate_1"]
    frames = []
    for i in range(12):
        wobble_y = int(round(math.sin(i * math.pi / 3.0) * 3))
        wobble_x = int(round(math.cos(i * math.pi / 3.0) * 2))
        frame = transform_crisp(f_fly, scale_x=1.10, scale_y=0.94, dx=-14 - wobble_x, dy=-8 + wobble_y, shear_x=-0.18)
        # Wind speed lines on right
        line_y = 100 + (i * 12) % 100
        for lx in range(160, 220):
            if (lx + i * 8) % 16 < 8:
                frame[line_y, lx] = (226, 232, 240, 220)
        frames.append(frame)
    return frames

def build_drag_start_up(bases):
    f0 = bases["idle_0"]
    f_jump = bases["celebrate_2"]
    frames = []
    for i in range(12):
        t = i / 11.0
        dy = int(round(-t * 22))
        sy = 1.0 + t * 0.14
        sx = 1.0 - t * 0.08
        base = f0 if t < 0.5 else f_jump
        frame = transform_crisp(base, scale_x=sx, scale_y=sy, dy=dy)
        frames.append(frame)
    return frames

def build_drag_move_up(bases):
    f_jump = bases["celebrate_2"]
    frames = []
    for i in range(12):
        wobble_y = int(round(math.sin(i * math.pi / 3.0) * 3))
        wobble_x = int(round(math.cos(i * math.pi / 3.0) * 3))
        frame = transform_crisp(f_jump, scale_x=0.92, scale_y=1.10, dx=wobble_x, dy=-20 + wobble_y)
        # Vertical speed lines streaming down
        line_x = 90 + (i * 17) % 100
        for ly in range(140, 210):
            if (ly + i * 10) % 20 < 10:
                frame[ly, line_x] = (226, 232, 240, 220)
        frames.append(frame)
    return frames

def build_drag_start_down(bases):
    f0 = bases["idle_0"]
    f_squash = bases["celebrate_3"]
    frames = []
    for i in range(12):
        t = i / 11.0
        dy = int(round(t * 12))
        sy = 1.0 - t * 0.18
        sx = 1.0 + t * 0.14
        base = f0 if t < 0.5 else f_squash
        frame = transform_crisp(base, scale_x=sx, scale_y=sy, dy=dy)
        frames.append(frame)
    return frames

def build_drag_move_down(bases):
    f_squash = bases["celebrate_3"]
    frames = []
    for i in range(12):
        wobble_y = int(round(math.sin(i * math.pi / 3.0) * 2))
        frame = transform_crisp(f_squash, scale_x=1.16, scale_y=0.82, dy=12 + wobble_y)
        frames.append(frame)
    return frames

# Hold / Grabbed
def build_hold_grab(bases):
    """Held by cursor / dangling in air: paddling hooves and swinging legs."""
    f_jump = bases["celebrate_2"]
    f_alert = bases["idle_3"]
    frames = []
    for i in range(12):
        # Dangling pendulum swing
        angle = math.sin(i * math.pi / 3.0) * 0.06
        dy = int(round(-18 + math.sin(i * math.pi / 3.0) * 2))
        frame = transform_crisp(f_jump, scale_x=0.94, scale_y=1.06, dy=dy, shear_x=angle)
        frames.append(frame)
    return frames

# Wall Impacts
def build_wall_hit_right(bases):
    """Impact against right wall: max splat against edge, recoil, dizzy stars."""
    f_fly = bases["celebrate_1"]
    f0 = bases["idle_0"]
    f_squash = bases["celebrate_3"]
    frames = []
    # 0: fast fly right
    frames.append(transform_crisp(f_fly, scale_x=1.10, dx=18, dy=-4))
    # 1: contact
    frames.append(transform_crisp(f_fly, scale_x=0.95, dx=30, dy=-2))
    # 2: MAX SPLAT! Compressed against right wall
    f2 = transform_crisp(f_fly, scale_x=0.65, scale_y=1.15, dx=46, dy=-2)
    draw_impact_shockwave(f2, 245, 120, radius_x=8, radius_y=45)
    frames.append(f2)
    # 3: peel off with stars
    f3 = transform_crisp(f_fly, scale_x=1.10, dx=18, dy=2)
    draw_star(f3, 210, 80, radius=5)
    draw_star(f3, 175, 55, radius=4)
    frames.append(f3)
    # 4: falling back dazed
    f4 = transform_crisp(f_squash, scale_x=0.95, dx=6, dy=0)
    draw_star(f4, 190, 70, radius=3)
    frames.append(f4)
    # 5: stars circle
    f5 = transform_crisp(bases["sad_0"], scale_x=0.96, dy=2)
    draw_star(f5, 145, 50, radius=3)
    frames.append(f5)
    # 6: dizzy wobble
    frames.append(transform_crisp(bases["sad_0"], shear_x=-0.04))
    # 7: dizzy wobble
    frames.append(transform_crisp(bases["sad_0"], shear_x=0.04))
    # 8: landing on 4 feet
    frames.append(f_squash)
    # 9: head shake
    frames.append(bases["idle_1"])
    # 10: settle
    frames.append(bases["idle_3"])
    # 11: idle
    frames.append(f0)
    return frames

def build_wall_hit_left(bases):
    """Impact against left wall."""
    f_fly = bases["celebrate_1"]
    f0 = bases["idle_0"]
    f_squash = bases["celebrate_3"]
    frames = []
    # 0: fast fly left
    frames.append(transform_crisp(f_fly, scale_x=1.10, dx=-18, dy=-4))
    # 1: contact
    frames.append(transform_crisp(f_fly, scale_x=0.95, dx=-30, dy=-2))
    # 2: MAX SPLAT!
    f2 = transform_crisp(f_fly, scale_x=0.65, scale_y=1.15, dx=-46, dy=-2)
    draw_impact_shockwave(f2, 10, 120, radius_x=8, radius_y=45)
    frames.append(f2)
    # 3: recoil
    f3 = transform_crisp(f_fly, scale_x=1.10, dx=-18, dy=2)
    draw_star(f3, 45, 80, radius=5)
    draw_star(f3, 80, 55, radius=4)
    frames.append(f3)
    # 4: falling back dazed
    f4 = transform_crisp(f_squash, scale_x=0.95, dx=-6, dy=0)
    draw_star(f4, 65, 70, radius=3)
    frames.append(f4)
    # 5: stars circle
    f5 = transform_crisp(bases["sad_0"], scale_x=0.96, dy=2)
    draw_star(f5, 145, 50, radius=3)
    frames.append(f5)
    # 6: dizzy wobble
    frames.append(transform_crisp(bases["sad_0"], shear_x=0.04))
    # 7: dizzy wobble
    frames.append(transform_crisp(bases["sad_0"], shear_x=-0.04))
    # 8: landing
    frames.append(f_squash)
    # 9: head shake
    frames.append(bases["idle_1"])
    # 10: settle
    frames.append(bases["idle_3"])
    # 11: idle
    frames.append(f0)
    return frames

def build_wall_hit_top(bases):
    """Impact against ceiling: accordion pancake squash, dizzy stars."""
    f_jump = bases["celebrate_2"]
    f0 = bases["idle_0"]
    f_squash = bases["celebrate_3"]
    frames = []
    # 0: fast fly up
    frames.append(transform_crisp(f_jump, scale_x=0.94, scale_y=1.10, dy=-20))
    # 1: contact
    frames.append(transform_crisp(f_jump, scale_x=1.10, scale_y=0.85, dy=-28))
    # 2: MAX ACCORDION SQUASH!
    f2 = transform_crisp(f_jump, scale_x=1.35, scale_y=0.50, dy=-38)
    draw_impact_shockwave(f2, 145, 15, radius_x=55, radius_y=10)
    frames.append(f2)
    # 3: rebound bounce down
    f3 = transform_crisp(f_jump, scale_x=0.90, scale_y=1.18, dy=-6)
    draw_star(f3, 110, 45, radius=5)
    draw_star(f3, 145, 30, radius=5)
    draw_star(f3, 180, 45, radius=5)
    frames.append(f3)
    # 4: falling down
    f4 = transform_crisp(f_squash, dy=-2)
    draw_star(f4, 125, 55, radius=3)
    draw_star(f4, 165, 55, radius=3)
    frames.append(f4)
    # 5: stars circle
    f5 = transform_crisp(bases["sad_0"], dy=2)
    draw_star(f5, 145, 50, radius=3)
    frames.append(f5)
    # 6: wobble
    frames.append(transform_crisp(bases["sad_0"], shear_x=-0.04))
    # 7: wobble
    frames.append(transform_crisp(bases["sad_0"], shear_x=0.04))
    # 8: touchdown squash
    frames.append(f_squash)
    # 9: clear head
    frames.append(bases["idle_1"])
    # 10: settle
    frames.append(bases["idle_3"])
    # 11: idle
    frames.append(f0)
    return frames

def build_wall_hit_bottom(bases):
    """Impact against floor: pancake rug splat, dust puffs, rubber band recoil."""
    f_drop = bases["celebrate_3"]
    f0 = bases["idle_0"]
    f_jump = bases["celebrate_1"]
    frames = []
    # 0: fast drop
    frames.append(transform_crisp(f_drop, scale_x=0.90, scale_y=1.15, dy=12))
    # 1: contact
    frames.append(transform_crisp(f_drop, scale_x=1.10, scale_y=0.85, dy=18))
    # 2: MAX PANCAKE RUG SPLAT!
    f2 = transform_crisp(f_drop, scale_x=1.45, scale_y=0.42, dy=24)
    # Dust puffs on both sides
    draw_dust_puff(f2, 55, 235, radius=7)
    draw_dust_puff(f2, 235, 235, radius=7)
    draw_impact_shockwave(f2, 145, 245, radius_x=65, radius_y=8)
    frames.append(f2)
    # 3: rubber-band recoil bounce up!
    f3 = transform_crisp(f_jump, scale_x=0.88, scale_y=1.22, dy=-12)
    draw_dust_puff(f3, 70, 230, radius=4)
    draw_dust_puff(f3, 220, 230, radius=4)
    frames.append(f3)
    # 4: secondary apex
    frames.append(transform_crisp(f_jump, scale_x=0.95, scale_y=1.05, dy=-6))
    # 5: settle drop
    frames.append(transform_crisp(f_drop, dy=0))
    # 6: soft landing
    frames.append(transform_crisp(f_drop, scale_x=1.06, scale_y=0.94, dy=3))
    # 7: recoil
    frames.append(transform_crisp(bases["idle_1"], dy=-1))
    # 8: dust off coat
    frames.append(bases["idle_1"])
    # 9: cheeky grin
    frames.append(bases["idle_1"])
    # 10: settle
    frames.append(bases["idle_3"])
    # 11: idle
    frames.append(f0)
    return frames

def generate_all():
    print("Loading base stabilized poses...")
    bases = load_stabilized_bases()
    
    animations_map = {
        # 1. Fire eyes loop
        "fire_loop": ("Olho Pegando Fogo em Loop", build_fire_loop),
        # 2. Click reactions (5 variations)
        "click_poke": ("Clique 1: Susto / Pulinho (Poke)", build_click_poke),
        "click_bleat": ("Clique 2: Berro 'BÉÉÉ!' Fofo (Bleat)", build_click_bleat),
        "click_shake": ("Clique 3: Sacudida de Cabeça (Shake)", build_click_shake),
        "click_spin": ("Clique 4: Pirueta 360 com Estrelas (Spin)", build_click_spin),
        "click_heart": ("Clique 5: Carinho com Corações (Heart)", build_click_heart),
        # 3. Drag transitions (4 directions x 2 states = 8)
        "drag_start_right": ("Arrastar: Início Direita", build_drag_start_right),
        "drag_move_right": ("Arrastar: Voando Direita", build_drag_move_right),
        "drag_start_left": ("Arrastar: Início Esquerda", build_drag_start_left),
        "drag_move_left": ("Arrastar: Voando Esquerda", build_drag_move_left),
        "drag_start_up": ("Arrastar: Início Cima", build_drag_start_up),
        "drag_move_up": ("Arrastar: Flutuando Cima", build_drag_move_up),
        "drag_start_down": ("Arrastar: Início Baixo", build_drag_start_down),
        "drag_move_down": ("Arrastar: Pressionado Baixo", build_drag_move_down),
        # 4. Hold / Grab
        "hold_grab": ("Segurar Clique: Suspenso no Ar (Grab)", build_hold_grab),
        # 5. Wall collisions (4 directions)
        "wall_hit_right": ("Bater Parede Direita (Splat)", build_wall_hit_right),
        "wall_hit_left": ("Bater Parede Esquerda (Splat)", build_wall_hit_left),
        "wall_hit_top": ("Bater no Teto (Accordion)", build_wall_hit_top),
        "wall_hit_bottom": ("Bater no Chão (Pancake)", build_wall_hit_bottom)
    }
    
    total_anims = len(animations_map)
    print(f"Total interactive animations to generate: {total_anims}")
    
    # Master Atlas: 12 columns x 19 rows = 3072 x 4864 px
    master_atlas_img = Image.new("RGBA", (256 * 12, 256 * total_anims), (0, 0, 0, 0))
    catalog_list = []
    
    for anim_idx, (anim_id, (anim_title, builder_fn)) in enumerate(animations_map.items()):
        print(f"[{anim_idx+1}/{total_anims}] Generating '{anim_id}' ({anim_title})...")
        frames_np = builder_fn(bases)
        
        # Directory for individual PNG frames
        anim_frames_dir = os.path.join(OUT_FRAMES_DIR, anim_id)
        os.makedirs(anim_frames_dir, exist_ok=True)
        
        # Flutter Grid Sheet: 6 columns x 2 rows (1536 x 512 px)
        grid_sheet = Image.new("RGBA", (256 * 6, 256 * 2), (0, 0, 0, 0))
        # Horizontal Strip: 12 columns x 1 row (3072 x 256 px)
        strip_sheet = Image.new("RGBA", (256 * 12, 256), (0, 0, 0, 0))
        
        pil_frames = []
        frames_meta = []
        
        for f_idx, f_arr in enumerate(frames_np):
            f_pil = Image.fromarray(f_arr)
            pil_frames.append(f_pil)
            
            # Save frame PNG
            frame_filename = f"frame_{f_idx:02d}.png"
            f_pil.save(os.path.join(anim_frames_dir, frame_filename))
            
            # Place in strip (12x1)
            strip_sheet.paste(f_pil, (f_idx * 256, 0))
            
            # Place in Flutter grid (6x2)
            g_col = f_idx % 6
            g_row = f_idx // 6
            grid_sheet.paste(f_pil, (g_col * 256, g_row * 256))
            
            # Place in Master Atlas (12x19)
            master_atlas_img.paste(f_pil, (f_idx * 256, anim_idx * 256))
            
            frames_meta.append({
                "index": f_idx,
                "file": frame_filename,
                "grid_pos": {"col": g_col, "row": g_row, "x": g_col * 256, "y": g_row * 256},
                "strip_pos": {"col": f_idx, "row": 0, "x": f_idx * 256, "y": 0},
                "duration_ms": 41.67
            })
            
        # Save individual sheets
        grid_path = os.path.join(OUT_SHEETS_DIR, f"{anim_id}_grid.png")
        grid_sheet.save(grid_path)
        
        strip_path = os.path.join(OUT_SHEETS_DIR, f"{anim_id}_strip.png")
        strip_sheet.save(strip_path)
        
        # Save JSON atlas
        with open(os.path.join(OUT_SHEETS_DIR, f"{anim_id}.json"), "w", encoding="utf-8") as f:
            json.dump({
                "id": anim_id,
                "title": anim_title,
                "fps": 24,
                "total_frames": 12,
                "frame_size": {"w": 256, "h": 256},
                "grid": {"cols": 6, "rows": 2, "w": 1536, "h": 512},
                "strip": {"cols": 12, "rows": 1, "w": 3072, "h": 256},
                "frames": frames_meta
            }, f, indent=2, ensure_ascii=False)
            
        # Save 24 FPS Preview GIF
        gif_path = os.path.join(BASE_DIR, f"{anim_id}.gif")
        pil_frames[0].save(
            gif_path,
            save_all=True,
            append_images=pil_frames[1:],
            duration=42,
            loop=0,
            disposal=2
        )
        
        catalog_list.append({
            "id": anim_id,
            "title": anim_title,
            "fps": 24,
            "frames": 12,
            "grid_path": f"spritesheets_interactive/{anim_id}_grid.png",
            "strip_path": f"spritesheets_interactive/{anim_id}_strip.png",
            "gif_path": f"{anim_id}.gif"
        })
        
    # Save Master Atlas
    master_atlas_path = os.path.join(OUT_SHEETS_DIR, "bode_branco_interactive_master.png")
    master_atlas_img.save(master_atlas_path)
    master_atlas_img.save(os.path.join(BASE_DIR, "bode_branco_interactive_master.png"))
    
    with open(os.path.join(OUT_SHEETS_DIR, "catalog_interactive.json"), "w", encoding="utf-8") as f:
        json.dump(catalog_list, f, indent=2, ensure_ascii=False)
        
    print("\nAll 19 Interactive Animations generated successfully!")

if __name__ == "__main__":
    generate_all()
