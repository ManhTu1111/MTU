import cv2
import time
import numpy as np
from scipy.signal import find_peaks, butter, filtfilt, detrend, hilbert
from scipy.ndimage import median_filter
import mediapipe as mp
import tkinter as tk
from PIL import Image, ImageTk
import csv
from datetime import datetime
import os
import json
import firebase_admin
from firebase_admin import credentials, db
import traceback
import threading
import queue
import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
from scipy.signal import butter, filtfilt  
import matplotlib
matplotlib.use('Agg')  

def plot_debug_signal(t, raw_signal, y, chosen_marks, filename="debug_signal_plot.png"):
    fig = plt.figure(figsize=(11, 6))
    plt.plot(t, raw_signal, label="Tín hiệu thô", alpha=0.45)
    plt.plot(t, y, label="Đã lọc (resampled)", linewidth=2)
    if chosen_marks is not None and len(chosen_marks) > 0:
        ys = np.interp(chosen_marks, t, y)
        plt.plot(chosen_marks, ys, 'ro', markersize=7, label=f"Mốc đếm ({len(chosen_marks)})")
    plt.xlabel("Thời gian (s)"); plt.ylabel("Biên độ")
    plt.title("Debug: Tín hiệu & mốc đếm chu kỳ (đã chọn)")
    plt.legend(); plt.grid(True, alpha=0.3); plt.tight_layout()
    plt.savefig(filename, dpi=150); plt.close(fig)

def plot_user_signal(t, y, chosen_marks, filename="user_breath_plot.png", hold_info=None):
    fig = plt.figure(figsize=(6, 3.5), facecolor='white')
    ax = fig.add_subplot(111, facecolor='white')
    ax.plot(t, y, label="Nhịp thở", linewidth=1.5)

    if chosen_marks is not None and len(chosen_marks) > 0:
        ys = np.interp(chosen_marks, t, y)
        ax.plot(chosen_marks, ys, 'ro', markersize=5, label=f"{len(chosen_marks)} nhịp")

    if hold_info is not None:
        hs = hold_info.get("start", None)
        he = hold_info.get("end", None)
        if hs is not None and he is not None and he > hs:
            ax.axvspan(hs, he, alpha=0.18, label="Nghi ngờ nín thở")

    ax.grid(True, alpha=0.3, linestyle='--')
    ax.set_xlabel("Thời gian (giây)", fontsize=8)
    ax.set_ylabel("Biên độ", fontsize=8)
    ax.set_title("Biểu đồ nhịp thở", fontsize=10, pad=10)
    ax.legend(fontsize=8)
    plt.tight_layout()
    plt.savefig(filename, dpi=100, facecolor='white')
    plt.close(fig)


def record_video(duration=10, output_path='output.avi', width=640, height=480, fps_target=30, stop_flag=None, frame_queue=None, recording_event=None, estimator=None, save_video=False, draw_roi=True):
    cap = None
    out = None
    try:
        cap = cv2.VideoCapture(0, cv2.CAP_V4L2)  # Dùng CAP_V4L2 trên Linux dùng Webcam trên window thì dùng cv2.CAP_DSHOW
        cap.set(cv2.CAP_PROP_FPS, fps_target)  # Thêm để ưu tiên FPS
        if not cap.isOpened():
            raise Exception("Không thể mở webcam!")
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)

        if save_video:
            fourcc = cv2.VideoWriter_fourcc(*'XVID')
            out = cv2.VideoWriter(output_path, fourcc, fps_target, (int(width), int(height)))

        start_time = None
        frame_count = 0
        PREVIEW_W, PREVIEW_H = 280, 210

        while True:
            if stop_flag and stop_flag[0]:
                break
            ret, frame = cap.read()
            if not ret:
                raise Exception("Không lấy được frame từ webcam!")

            if recording_event.is_set() and estimator is not None:
                if start_time is None:
                    start_time = time.time()
                    estimator.start()
                estimator.process_frame(frame)
                frame_count += 1
                if save_video and out is not None:
                    out.write(frame)
                if (time.time() - start_time) >= duration:
                    break

            # Preview: resize + vẽ ROI
            frame_show = cv2.resize(frame, (PREVIEW_W, PREVIEW_H))
            if draw_roi and estimator is not None and estimator.last_roi_rect is not None:
                x1, y1, x2, y2 = estimator.last_roi_rect
                # Tăng chiều dọc của khung ROI
                roi_height = y2 - y1
                y1 = int(y1 - 0.1 * roi_height)  # Giảm y1 (điểm trên) đi 10% chiều cao
                y2 = int(y2 + 0.1 * roi_height)  # Tăng y2 (điểm dưới) thêm 10% chiều cao
                h0, w0 = frame.shape[:2]
                sx = PREVIEW_W / float(w0)
                sy = PREVIEW_H / float(h0)
                rx1, ry1 = int(x1 * sx), int(y1 * sy)
                rx2, ry2 = int(x2 * sx), int(y2 * sy)
                cv2.rectangle(frame_show, (rx1, ry1), (rx2, ry2), (255, 0, 0), 2)  # Khung xanh dương

            if frame_queue is not None:
                frame_rgb = cv2.cvtColor(frame_show, cv2.COLOR_BGR2RGB)
                frame_queue.put(frame_rgb)

            time.sleep(0.001)

        elapsed = (time.time() - start_time) if start_time else duration
        est_fps = (frame_count / elapsed) if (elapsed and frame_count) else fps_target

        return None, est_fps
    except Exception as e:
        print(f"Lỗi khi quay video: {e}")
        return None, 0
    finally:
        if out is not None:
            out.release()
        if cap is not None and cap.isOpened():
            cap.release()
        try:
            cv2.destroyAllWindows()
        except Exception:
            pass

# ===================== Helpers xử lý ======================
def ema_smooth(x: np.ndarray, alpha: float = 0.25):
    if x.size == 0: return x
    y = np.empty_like(x, dtype=float); y[0] = x[0]
    for i in range(1, len(x)): y[i] = alpha * x[i] + (1 - alpha) * y[i - 1]
    return y

def robust_std(x: np.ndarray) -> float:
    med = np.median(x); mad = np.median(np.abs(x - med))
    return 1.4826 * mad if mad > 0 else float(np.std(x))

def zscore_robust(x: np.ndarray):
    med = np.median(x); rstd = robust_std(x)
    if rstd <= 1e-12: return np.zeros_like(x, dtype=float)
    return (x - med) / rstd

def resample_uniform(t: np.ndarray, y: np.ndarray, fs_proc: float = 30.0):
    t0, t1 = float(t[0]), float(t[-1])
    if t1 <= t0: return t, y, max(1.0, fs_proc)
    n = int(np.floor((t1 - t0) * fs_proc)) + 1
    t_new = np.linspace(t0, t1, n)
    y_new = np.interp(t_new, t, y)
    return t_new, y_new, fs_proc

# ===================== ROI helpers (chỉ vùng ngực-vai) ======================
def _clip(v, lo, hi): return int(max(lo, min(hi, v)))

def build_shoulder_roi(frame_shape, ls, rs, expand_scale=1.5, down_scale=0.8):
    H, W = frame_shape[:2]
    xL, yL = int(ls.x * W), int(ls.y * H)
    xR, yR = int(rs.x * W), int(rs.y * H)
    shoulder_w = max(20, abs(xR - xL))
    y_top = min(yL, yR)
    cx = (xL + xR) // 2
    half_w = int(0.5 * shoulder_w * expand_scale)
    roi_h = int(shoulder_w * 1.4)
    y1 = int(y_top - shoulder_w * 0.3)
    y2 = y1 + roi_h
    shift_down = int((y2 - y1) * (1.0 - down_scale))
    y1 += shift_down
    y2 += shift_down
    x1 = cx - half_w
    x2 = cx + half_w
    x1 = _clip(x1, 0, W - 1); x2 = _clip(x2, 0, W - 1)
    y1 = _clip(y1, 0, H - 1); y2 = _clip(y2, 0, H - 1)
    if x2 - x1 < 30 or y2 - y1 < 30: return None
    return (x1, y1, x2, y2)

def roi_vertical_motion(prev_roi_gray, curr_roi_gray):
    try:
        if prev_roi_gray is None or curr_roi_gray is None: return 0.0
        if prev_roi_gray.shape != curr_roi_gray.shape: return 0.0
        a = prev_roi_gray.astype(np.float32)
        b = curr_roi_gray.astype(np.float32)
        (dx, dy), _ = cv2.phaseCorrelate(a, b)
        return float(dy)
    except Exception:
        return 0.0

# ===================== Lọc Butterworth =====================
def bandpass(data, lowcut=0.1, highcut=2.0, fs=30.0, order=3):  # Tăng highcut lên 2.0
    try:
        nyq = 0.5 * fs
        low = max(1e-6, lowcut / nyq)
        high = min(0.999999, highcut / nyq)
        if low >= high: return data
        b, a = butter(order, [low, high], btype='band', analog=False)
        return filtfilt(b, a, data, method="gust")
    except Exception as e:
        print(f"Lỗi khi áp dụng Butterworth: {e}")
        return data

# ============= Peaks thích nghi (max/min) ==============
def adaptive_find_peaks(y: np.ndarray, t: np.ndarray, fs: float):
    if len(y) < 3: return np.array([], dtype=int), "maxima"
    zr = zscore_robust(y)
    base_min_dist = max(1, int(0.3 * fs))
    prom1 = 0.05  # Giảm từ 0.1 xuống 0.05 để phát hiện peaks nhẹ hơn
    p1, _ = find_peaks(zr, distance=base_min_dist, prominence=prom1)
    if len(p1) < 2: return p1, "maxima"
    itv = np.diff(t[p1]); valid = itv[(itv >= 0.3) & (itv <= 10.0)]
    if len(valid) == 0: return p1, "maxima"
    period = float(np.median(valid))
    min_dist2 = max(1, int(0.3 * period * fs))
    prom2 = 0.025  # Giảm từ 0.05 xuống 0.025 để phát hiện peaks nhẹ hơn
    p_max, _ = find_peaks(zr, distance=min_dist2, prominence=prom2)
    p_min, _ = find_peaks(-zr, distance=min_dist2, prominence=prom2)

    def clean_close(idx, thr=0.3):  # Giảm thr để giữ nhiều peaks hơn
        if len(idx) < 2: return idx
        keep = [idx[0]]
        for j in idx[1:]:
            if (t[j] - t[keep[-1]]) >= thr: keep.append(j)
        return np.array(keep, dtype=int)

    p_max = clean_close(p_max); p_min = clean_close(p_min)

    def spacing_quality(idx):
        if len(idx) < 3: return np.inf
        gaps = np.diff(t[idx]); return float(np.subtract(*np.percentile(gaps, [75, 25])))

    q_max, q_min = spacing_quality(p_max), spacing_quality(p_min)
    chosen, kind = (p_max, "maxima") if (q_max <= q_min) else (p_min, "minima")
    return chosen, kind

# ========== Zero-crossing đạo hàm (đỉnh & đáy) ==========
def derivative_events(y: np.ndarray, t: np.ndarray, fs: float):
    dy = np.gradient(y, 1.0/fs)
    s = np.sign(dy)
    idx_max, idx_min = [], []
    for i in range(1, len(s)):
        if s[i-1] > 0 and s[i] <= 0: idx_max.append(i)
        elif s[i-1] < 0 and s[i] >= 0: idx_min.append(i)
    idx_max = np.array(idx_max, dtype=int)
    idx_min = np.array(idx_min, dtype=int)

    def clean(idx, thr=0.15):  # Giảm thr để giữ nhiều events hơn
        if len(idx) < 2: return idx
        keep = [idx[0]]
        for j in idx[1:]:
            if (t[j] - t[keep[-1]]) >= thr: keep.append(j)
        return np.array(keep, dtype=int)

    return clean(idx_max), clean(idx_min)

# ========== Chu kỳ từ pha Hilbert (1 mốc / chu kỳ) ==========
def phase_marks(y: np.ndarray, t: np.ndarray, fs: float):
    zr = zscore_robust(y)
    analytic = hilbert(zr)
    phase = np.unwrap(np.angle(analytic))
    amp = np.abs(analytic)
    # Điều chỉnh amp_thr để chấp nhận biên độ thấp hơn
    amp_thr = max(0.2 * np.median(amp), 0.05)  # Giảm từ 0.3 xuống 0.2, min từ 0.1 xuống 0.05
    refractory = 0.5  # Giảm để phát hiện cycles ngắn hơn
    c = np.cos(phase)
    min_dist = max(1, int(refractory * fs))
    idx, _ = find_peaks(c, distance=min_dist, prominence=0.025)  # Giảm prominence từ 0.05 xuống 0.025
    idx = np.array([i for i in idx if amp[i] >= amp_thr], dtype=int)
    return t[idx] if idx.size > 0 else np.array([], dtype=float)

# ======= Đánh giá & chọn 1 track duy nhất để đếm =======
def eval_track(marks: np.ndarray):
    if marks is None or marks.size < 2: return (False, 0.0, np.inf, 0.0, np.array([]))
    itv = np.diff(marks)
    valid = itv[(itv >= 0.3) & (itv <= 10.0)]
    if valid.size == 0: return (False, 0.0, np.inf, 0.0, np.array([]))
    med = float(np.median(valid))
    iqr = float(np.subtract(*np.percentile(valid, [75, 25])))
    iqr_norm = iqr / (med + 1e-6)
    bpm = 60.0 / med
    return (True, bpm, iqr_norm, med, valid)

def select_best_track(candidates, total_duration, bpm_min=6.0, bpm_max=80.0):
    best = None
    best_score = None
    for name, mk in candidates:
        ok, bpm, iqr_norm, med_period, valid = eval_track(mk)
        if not ok: continue
        if not (bpm_min <= bpm <= bpm_max): continue
        score = iqr_norm + 0.03 * abs(len(valid) - (total_duration / med_period))
        if name == "phase": score *= 0.8  # Ưu tiên phase_marks bằng cách giảm score
        if best_score is None or score < best_score:
            best = (name, mk, bpm, med_period, len(valid))
            best_score = score
    return best

# ======= Tính BPM ổn định bằng cửa sổ trượt =======
def windowed_bpm(event_times: np.ndarray, window_sec: float, total_duration: float):
    if event_times.size < 2: return 0.0
    vals = []
    for te in np.arange(window_sec, total_duration + 1e-9, 1.0):
        ts = te - window_sec
        count = np.sum((event_times > ts) & (event_times <= te))
        vals.append(60.0 * count / window_sec)
    return float(np.mean(vals)) if vals else 0.0

def detect_breath_hold_segment(timestamps, filtered_signal, peak_times, min_hold_sec=13.0):
    try:
        if timestamps is None:
            return None
        t = np.array(timestamps, dtype=float)
        if t.size == 0:
            return None

        peaks = np.array(peak_times, dtype=float) if peak_times is not None and len(peak_times) > 0 else np.array([])

        start = float(t[0])
        end = float(t[-1])

        # Xây danh sách mốc (biên + peaks)
        boundaries = [start]
        if peaks.size > 0:
            boundaries.extend(peaks.tolist())
        boundaries.append(end)

        # Tìm khoảng trống lớn nhất giữa các mốc
        max_gap = 0.0
        max_seg = (None, None)
        for i in range(len(boundaries) - 1):
            gap = boundaries[i + 1] - boundaries[i]
            if gap > max_gap:
                max_gap = gap
                max_seg = (boundaries[i], boundaries[i + 1])

        # Nếu khoảng trống lớn nhất < ngưỡng nín thở thì coi như bình thường
        if max_gap < min_hold_sec:
            return None

        seg_start, seg_end = max_seg

        # Nếu muốn đoán nín thở sau hít đầy hơi hay thở hết hơi,
        # dùng vị trí tín hiệu trong đoạn đó so với toàn cục
        hold_type = "unknown"
        if filtered_signal is not None and len(filtered_signal) == len(t):
            sig = np.array(filtered_signal, dtype=float)
            mask = (t >= seg_start) & (t <= seg_end)
            if np.any(mask):
                seg_mean = float(np.mean(sig[mask]))
                g_min = float(np.min(sig))
                g_max = float(np.max(sig))
                g_mid = 0.5 * (g_min + g_max)

                # Nếu trung bình đoạn giữ gần phía "cao" -> nghi ngờ nín thở sau hít đầy hơi
                if seg_mean >= g_mid:
                    hold_type = "full_inhale"
                else:
                    hold_type = "full_exhale"

        return {
            "duration": max_gap,
            "start": seg_start,
            "end": seg_end,
            "type": hold_type,
        }
    except Exception as e:
        print(f"Lỗi detect_breath_hold_segment: {e}")
        return None

def detect_hold_from_bandpassed(
    t,
    clean_sig,
    min_hold_sec: float = 5.0,   # tối thiểu 5s mới coi là nín thở
    amp_drop_ratio: float = 0.3,
    win_sec: float = 1.0,
    severe_hold_sec: float = 13.0  # từ 13s trở lên coi là "đáng lo"
):
    try:
        t = np.asarray(t, dtype=float)
        s = np.asarray(clean_sig, dtype=float)

        if t.size < 10 or s.size != t.size:
            return None

        t0, t1 = float(t[0]), float(t[-1])
        if t1 <= t0:
            return None

        # Ước lượng dt và độ dài cửa sổ
        dt = np.median(np.diff(t))
        if dt <= 0:
            return None

        win_len = max(int(round(win_sec / dt)), 3)
        kernel = np.ones(win_len, dtype=np.float32) / win_len

        # Biên độ trung bình tuyệt đối trong cửa sổ trượt
        amp = np.convolve(np.abs(s), kernel, mode="same")
        if amp.size < 5:
            return None

        # Baseline = median của top 30% giá trị lớn nhất
        sorted_amp = np.sort(amp)
        k = max(int(0.7 * len(sorted_amp)), 1)
        baseline_amp = float(np.median(sorted_amp[k:]))

        # Nếu baseline quá nhỏ → tín hiệu yếu, không đủ tin cậy
        if baseline_amp < 1e-4:
            return None

        low_thr = amp_drop_ratio * baseline_amp  # ngưỡng “rất ít dao động”
        still_mask = amp < low_thr

        # Gom các đoạn liên tục có amp thấp
        segments = []
        start_idx = None
        for i, flag in enumerate(still_mask):
            if flag and start_idx is None:
                start_idx = i
            elif (not flag) and start_idx is not None:
                segments.append((start_idx, i - 1))
                start_idx = None
        if start_idx is not None:
            segments.append((start_idx, len(still_mask) - 1))

        if not segments:
            return None

        # Chọn đoạn dài nhất
        best = None
        best_dur = 0.0
        for s_idx, e_idx in segments:
            dur = float(t[e_idx] - t[s_idx])
            if dur > best_dur:
                best_dur = dur
                best = (s_idx, e_idx)

        # Nếu đoạn dài nhất vẫn < min_hold_sec thì coi như không nín thở
        if best is None or best_dur < min_hold_sec:
            return None

        s_idx, e_idx = best

        # Phân loại kiểu nín thở (sau hít vào / sau thở ra)
        hold_type = "unknown"
        try:
            g_min = float(np.min(s))
            g_max = float(np.max(s))
            g_mid = 0.5 * (g_min + g_max)
            seg_mean = float(np.mean(s[s_idx: e_idx + 1]))

            if seg_mean >= g_mid:
                hold_type = "full_inhale"  # nín thở sau khi hít vào (ngực cao)
            else:
                hold_type = "full_exhale"  # nín thở sau khi thở ra (ngực thấp)
        except Exception:
            hold_type = "unknown"

        # Phân cấp mức độ nín thở
        if best_dur >= severe_hold_sec:
            severity = "long_severe"   # ≥ 13s: nín thở dài đáng lo
        else:
            severity = "long"          # 5–13s: nín thở dài

        info = {
            "duration": best_dur,
            "start": float(t[s_idx]),
            "end": float(t[e_idx]),
            "type": hold_type,
            "method": "amp_drop",
            "baseline_amp": baseline_amp,
            "amp_threshold": low_thr,
            "severity": severity,      # <-- thêm field này để format cảnh báo
        }
        return info

    except Exception as e:
        print(f"Lỗi detect_hold_from_bandpassed: {e}")
        return None



def detect_shallow_breath_pattern(t, clean_sig, peak_times, min_cycles: int = 10):
    try:
        t = np.asarray(t, dtype=float)
        s = np.asarray(clean_sig, dtype=float)

        if t.size < 10 or s.size != t.size:
            return False, {}

        if peak_times is None or len(peak_times) < min_cycles:
            return False, {}

        # Chuẩn hoá theo z-score robust
        zr = zscore_robust(s)
        # Biên độ khoảng 5–95% (tránh outlier)
        lo = np.percentile(zr, 5)
        hi = np.percentile(zr, 95)
        amp_range = float(hi - lo)

        # Ngưỡng: < ~1.0 sigma coi như biên độ rất nhỏ
        is_shallow = amp_range < 1.5

        info = {
            "amp_range_z": amp_range,
            "low_z": lo,
            "high_z": hi,
        }
        return is_shallow, info
    except Exception as e:
        print(f"Lỗi detect_shallow_breath_pattern: {e}")
        return False, {}


def format_breath_hold_warning(info):
    if info is None:
        return None

    dur = info.get("duration", 0.0)
    hold_type = info.get("type", "unknown")
    start = info.get("start", 0.0)
    end = info.get("end", 0.0)
    severity = info.get("severity", "long")

    base = (
        f"Phát hiện khoảng ~{dur:.1f} giây gần như không có chuyển động hô hấp "
        f"(từ giây {start:.1f} đến {end:.1f})."
    )

    if severity == "long_severe":
        base += " Đây là khoảng nín thở kéo dài, cần đặc biệt lưu ý."

    if hold_type == "full_inhale":
        return base + " Cảnh báo: có dấu hiệu NÍN THỞ SAU KHI HÍT VÀO (ngực căng phồng và giữ lâu, chỉ hít vào rồi giữ)."
    elif hold_type == "full_exhale":
        return base + " Cảnh báo: có dấu hiệu NÍN THỞ SAU KHI THỞ RA (ngực xẹp xuống và giữ lâu, chỉ thở ra rồi giữ)."
    else:
        return base + " Cảnh báo: có dấu hiệu nín thở kéo dài."


class OnlineBreathEstimator:
    def __init__(self):
        self.mp_pose = mp.solutions.pose
        self.pose = self.mp_pose.Pose(
            min_detection_confidence=0.7,  # Tăng nhẹ để chính xác hơn
            min_tracking_confidence=0.7,
            model_complexity=2,  # Tăng lên full để chính xác hơn
            static_image_mode=False,
            enable_segmentation=False
        )
        self.prev_roi_gray = None
        self.cum_disp = 0.0
        self.last_roi_rect = None
        self.sig = []
        self._started = False
        self._t0 = None
        self.w_lm, self.w_roi = 0.2, 0.8  # Tăng trọng số ROI
        self.frame_count = 0
        # Lưu lại theo thời gian để tự phát hiện nín thở
        self.time_list = []
        self.chest_level_list = []   # mức lồng ngực (từ ROI)
        self.nose_level_list = []    # vị trí mũi theo trục y

        self.hold_info_mechanic = None
        self.hold_warning_text = None        

    def start(self):
        if not self._started:
            self._started = True
            self._t0 = time.time()

    def process_frame(self, frame_bgr):
        if not self._started: self.start()
        frame_rgb = cv2.cvtColor(frame_bgr, cv2.COLOR_BGR2RGB)
        results = self.pose.process(frame_rgb)
        lm_signal = 0.0
        roi_sig = 0.0
        self.last_roi_rect = None
        if results.pose_landmarks:
            ls = results.pose_landmarks.landmark[self.mp_pose.PoseLandmark.LEFT_SHOULDER]
            rs = results.pose_landmarks.landmark[self.mp_pose.PoseLandmark.RIGHT_SHOULDER]
            nose = results.pose_landmarks.landmark[self.mp_pose.PoseLandmark.NOSE]
            lm_signal = (ls.y + rs.y) / 2.0 - nose.y

            roi_rect = build_shoulder_roi(
                frame_shape=frame_bgr.shape,
                ls=ls, rs=rs,
                expand_scale=1.5,
                down_scale=0.8
            )
            if roi_rect is not None:
                x1, y1, x2, y2 = roi_rect
                roi = frame_bgr[y1:y2, x1:x2]
                if roi.size > 0:
                    roi_gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
                    dy = roi_vertical_motion(self.prev_roi_gray, roi_gray)
                    self.prev_roi_gray = roi_gray
                    self.cum_disp += dy
                    roi_sig = self.cum_disp
                    self.last_roi_rect = roi_rect
                else:
                    self.prev_roi_gray = None
            else:
                self.prev_roi_gray = None
        else:
            self.prev_roi_gray = None

        roi_h = (self.last_roi_rect[3] - self.last_roi_rect[1]) if self.last_roi_rect else 1
        roi_sig_norm = roi_sig / max(1.0, roi_h)
        sig_val = self.w_lm * lm_signal + self.w_roi * roi_sig_norm
        self.sig.append(sig_val)
        self.frame_count += 1

        # === Lưu thời gian + mức ngực + mũi cho bộ phát hiện nín thở riêng ===
        if self._t0 is None:
            self._t0 = time.time()
        t_now = time.time() - self._t0

        self.time_list.append(t_now)
        # Nếu không detect được pose thì để 0.0 cho an toàn
        chest_level = roi_sig_norm if results.pose_landmarks else 0.0
        nose_level = nose.y if results.pose_landmarks else 0.0

        self.chest_level_list.append(chest_level)
        self.nose_level_list.append(nose_level)
        # ======================================================================


    def finalize(self, fps_hint=None):
        try:
            if len(self.sig) < 3: return 0, 0.0, 0.0, 30.0, [], np.array([]), np.array([]), np.array([]), []
            sig = np.array(self.sig, dtype=float)
            if fps_hint is not None and fps_hint > 1e-3:
                t_cam = np.arange(self.frame_count, dtype=float) / float(fps_hint)
            else:
                t_cam = np.arange(self.frame_count, dtype=float) / 30.0

            sig = detrend(sig)
            sig = median_filter(sig, size=3)
            sig = ema_smooth(sig, alpha=0.05)
            sig = sig - np.mean(sig)

            fs_proc = 30.0
            t, x, fs = resample_uniform(t_cam, sig, fs_proc=fs_proc)
            y = bandpass(x, lowcut=0.1, highcut=2.0, fs=fs, order=3)  # Tăng highcut

            p_idx, kind = adaptive_find_peaks(y, t, fs)
            marks_ext = t[p_idx] if p_idx.size > 0 else np.array([])
            dmax_idx, dmin_idx = derivative_events(y, t, fs)
            marks_dmax = t[dmax_idx] if dmax_idx.size > 0 else np.array([])
            marks_dmin = t[dmin_idx] if dmin_idx.size > 0 else np.array([])
            marks_ph = phase_marks(y, t, fs)

            duration_total = float(t[-1] - t[0])
            best = select_best_track(
                candidates=[("phase", marks_ph), (kind, marks_ext), ("dmax", marks_dmax), ("dmin", marks_dmin)],
                total_duration=duration_total,
                bpm_min=6.0, bpm_max=120.0  # Tăng bpm_max
            )
            if best is None:
                chosen_name, chosen_marks = (kind, marks_ext) if marks_ext.size >= 2 else ("phase", marks_ph)
            else:
                chosen_name, chosen_marks, bpm_est, med_period, n_valid = best

            breath_count = 0
            avg_breath_duration = 0.0
            breath_per_min = 0.0
            if chosen_marks is not None and chosen_marks.size >= 2:
                intervals = np.diff(chosen_marks)
                valid = intervals[(intervals >= 0.3) & (intervals <= 10.0)]
                if valid.size > 0:
                    avg_breath_duration = float(np.median(valid))
                    bpm_inst = 60.0 / avg_breath_duration
                    iqr = float(np.subtract(*np.percentile(valid, [75, 25])))
                    iqr_norm = iqr / (avg_breath_duration + 1e-6)

                    if duration_total <= 20: win = 5.5
                    elif duration_total <= 30: win = 10.0
                    elif duration_total <= 40: win = 15.0
                    elif duration_total <= 45: win = 20.0
                    elif duration_total <= 50: win = 25.0
                    elif duration_total <= 60: win = 30.0
                    else: win = min(60.0, max(20.0, 0.5 * duration_total))

                    bpm_win = windowed_bpm(chosen_marks, win, duration_total)
                    breath_per_min = bpm_inst if iqr_norm < 0.5 else bpm_win  # Tăng threshold để ưu tiên bpm_inst
                    breath_count = int(round(breath_per_min * duration_total / 60.0))

            plot_debug_signal(t, x, y, chosen_marks)
            plot_user_signal(t, y, chosen_marks, hold_info=self.hold_info_mechanic)

            # === Cơ chế mới: phát hiện nín thở trực tiếp trên tín hiệu đã lọc (y) ===
            try:
                hold_info = detect_hold_from_bandpassed(
                    t=t,
                    clean_sig=y,
                    min_hold_sec=5.0,      # có thể đổi 4.0 / 6.0 tuỳ ý
                    amp_drop_ratio=0.3,    # nếu khó bắt, thử tăng lên 0.35–0.4
                    win_sec=1.0,
                )
                self.hold_info_mechanic = hold_info
                self.hold_warning_text = format_breath_hold_warning(hold_info)
            except Exception as e:
                print(f"Lỗi phát hiện nín thở (amp-based): {e}")
                self.hold_info_mechanic = None
                self.hold_warning_text = None
            # ================================================================

            peaks = np.searchsorted(t, chosen_marks) if len(chosen_marks) > 0 else []
            peak_times = chosen_marks.tolist()
            shoulder_y_signal = x
            filtered_y = y
            timestamps = t

            return breath_count, avg_breath_duration, breath_per_min, fs, peak_times, shoulder_y_signal, filtered_y, timestamps, peaks
        finally:
            try: self.pose.close()
            except Exception: pass

# ===================== Xử lý từ video ======================
def process_breathing(video_path, fps_cam, stop_flag=None):
    cap = None
    try:
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            raise Exception("Không mở được video!")
        mp_pose = mp.solutions.pose
        pose = mp_pose.Pose(
            min_detection_confidence=0.6,
            min_tracking_confidence=0.6,
            model_complexity=1,  # Tăng lên full
            static_image_mode=False,
            enable_segmentation=False
        )
        sig, t_cam, k = [], [], 0

        prev_roi_gray = None
        cum_disp = 0.0
        last_roi_rect = None

        while True:
            ret, frame = cap.read()
            if not ret:
                break
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = pose.process(frame_rgb)

            lm_signal = 0.0
            roi_sig = 0.0
            if results.pose_landmarks:
                ls = results.pose_landmarks.landmark[mp_pose.PoseLandmark.LEFT_SHOULDER]
                rs = results.pose_landmarks.landmark[mp_pose.PoseLandmark.RIGHT_SHOULDER]
                nose = results.pose_landmarks.landmark[mp_pose.PoseLandmark.NOSE]
                lm_signal = (ls.y + rs.y) / 2.0 - nose.y

                roi_rect = build_shoulder_roi(
                    frame_shape=frame.shape,
                    ls=ls, rs=rs,
                    expand_scale=1.5,
                    down_scale=0.8
                )
                if roi_rect is not None:
                    x1, y1, x2, y2 = roi_rect
                    roi = frame[y1:y2, x1:x2]
                    if roi.size > 0:
                        roi_gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
                        dy = roi_vertical_motion(prev_roi_gray, roi_gray)
                        prev_roi_gray = roi_gray
                        cum_disp += dy
                        roi_sig = cum_disp
                        last_roi_rect = roi_rect
                    else:
                        prev_roi_gray = None
                        last_roi_rect = None
                else:
                    prev_roi_gray = None
                    last_roi_rect = None
            else:
                prev_roi_gray = None
                last_roi_rect = None

            w_lm, w_roi = 0.2, 0.8  # Tăng trọng số ROI
            roi_height = (last_roi_rect[3] - last_roi_rect[1]) if last_roi_rect else 1
            roi_sig_norm = roi_sig / max(1.0, roi_height)
            sig_val = w_lm * lm_signal + w_roi * roi_sig_norm
            sig.append(sig_val)
            t_cam.append(k / fps_cam)
            k += 1

        sig = np.array(sig, dtype=float)
        t_cam = np.array(t_cam, dtype=float)

        sig = detrend(sig)
        sig = median_filter(sig, size=3)
        sig = ema_smooth(sig, alpha=0.05)
        sig = sig - np.mean(sig)

        fs_proc = 30.0
        t, x, fs = resample_uniform(t_cam, sig, fs_proc=fs_proc)

        y = bandpass(x, lowcut=0.1, highcut=2.0, fs=fs, order=3)  # Tăng highcut

        p_idx, kind = adaptive_find_peaks(y, t, fs)
        marks_ext = t[p_idx] if p_idx.size > 0 else np.array([])
        dmax_idx, dmin_idx = derivative_events(y, t, fs)
        marks_dmax = t[dmax_idx] if dmax_idx.size > 0 else np.array([])
        marks_dmin = t[dmin_idx] if dmin_idx.size > 0 else np.array([])

        marks_ph = phase_marks(y, t, fs)

        duration_total = float(t[-1] - t[0])
        best = select_best_track(
            candidates=[
                ("phase", marks_ph),
                (kind, marks_ext),
                ("dmax", marks_dmax),
                ("dmin", marks_dmin),
            ],
            total_duration=duration_total,
            bpm_min=6.0, bpm_max=120.0  # Tăng bpm_max
        )
        if best is None:
            chosen_name, chosen_marks = (kind, marks_ext) if marks_ext.size >= 2 else ("phase", marks_ph)
            bpm_est = 0.0
        else:
            chosen_name, chosen_marks, bpm_est, med_period, n_valid = best

        breath_count = 0
        avg_breath_duration = 0.0
        breath_per_min = 0.0
        if chosen_marks is not None and chosen_marks.size >= 2:
            intervals = np.diff(chosen_marks)
            valid = intervals[(intervals >= 0.3) & (intervals <= 10.0)]
            if valid.size > 0:
                avg_breath_duration = float(np.median(valid))
                bpm_inst = 60.0 / avg_breath_duration
                iqr = float(np.subtract(*np.percentile(valid, [75, 25])))
                iqr_norm = iqr / (avg_breath_duration + 1e-6)

                if duration_total <= 20: win = 5.5
                elif duration_total <= 30: win = 10.0
                elif duration_total <= 40: win = 15.0
                elif duration_total <= 45: win = 20.0
                elif duration_total <= 50: win = 25.0
                elif duration_total <= 60: win = 30.0
                else: win = min(60.0, max(20.0, 0.5 * duration_total))

                bpm_win = windowed_bpm(chosen_marks, win, duration_total)
                breath_per_min = bpm_inst if iqr_norm < 0.5 else bpm_win  # Tăng threshold
                breath_count = int(round(breath_per_min * duration_total / 60.0))

        # === PHÁT HIỆN NÍN THỞ OFFLINE (dựa trên y) ===
        hold_info = None
        hold_warning = None
        try:
            hold_info = detect_hold_from_bandpassed(
                t=t,
                clean_sig=y,
                min_hold_sec=5.0,      # hoặc 6–8s tùy yêu cầu
                amp_drop_ratio=0.3,    # nếu bắt khó quá có thể tăng 0.35–0.4
                win_sec=1.0,
            )
            hold_warning = format_breath_hold_warning(hold_info)
        except Exception as e:
            print(f"Lỗi phát hiện nín thở trong process_breathing: {e}")
            hold_info = None
            hold_warning = None

        # Vẽ debug + user plot có tô vùng nín thở
        plot_debug_signal(t, x, y, chosen_marks)
        plot_user_signal(t, y, chosen_marks, hold_info=hold_info)

        peaks = np.searchsorted(t, chosen_marks) if len(chosen_marks) > 0 else []
        peak_times = chosen_marks.tolist()
        shoulder_y_signal = x
        filtered_y = y
        timestamps = t

        # TRẢ THÊM hold_info, hold_warning
        return (
            breath_count,
            avg_breath_duration,
            breath_per_min,
            fs,
            peak_times,
            shoulder_y_signal,
            filtered_y,
            timestamps,
            peaks,
            hold_info,
            hold_warning,
        )
    finally:
        if cap is not None and cap.isOpened():
            cap.release()
        try:
            cv2.destroyAllWindows()
        except Exception:
            pass
        try:
            pose.close()
        except:
            pass


# Hàm lưu dữ liệu nhịp thở
def save_breath_data(timestamps, shoulder_y, filtered_y, peak_times, predicted_breaths, avg_breath_duration):
    try:
        filename = os.path.join(os.getcwd(), "breath_logs.csv")
        with open(filename, mode='a', newline='', encoding='utf-8') as file:
            writer = csv.writer(file)
            if file.tell() == 0:
                writer.writerow([
                    "thời gian",
                    "giá trị trung bình vai thô",
                    "độ lệch chuẩn vai thô",
                    "giá trị trung bình vai lọc",
                    "độ lệch chuẩn vai lọc",
                    "số đỉnh",
                    "nhịp thở dự đoán",
                    "chu kỳ thở trung bình"
                ])
            writer.writerow([
                datetime.now().isoformat(),
                np.mean(shoulder_y) if len(shoulder_y) > 0 else 0,
                np.std(shoulder_y) if len(shoulder_y) > 0 else 0,
                np.mean(filtered_y) if len(filtered_y) > 0 else 0,
                np.std(filtered_y) if len(filtered_y) > 0 else 0,
                len(peak_times),
                predicted_breaths,
                avg_breath_duration
            ])
    except Exception as e:
        print(f"Lỗi khi lưu dữ liệu nhịp thở: {e}")

# Lớp giao diện đăng nhập
class LoginApp:
    def __init__(self, root, on_login_success):
        self.root = root
        self.root.title("Đăng nhập")
        self.root.geometry("460x260")
        self.root.resizable(False, False)
        self.on_login_success = on_login_success
        self.current_user = None

        self.db_ref = None
        try:
            cred_path = os.path.join(os.getcwd(), "firebase_credentials.json")
            with open(cred_path, 'w') as f:
                json.dump({
                    "type": "service_account",
                    "project_id": "esp32demotest-b96e5",
                    "private_key_id": "e57d1273541fd22b42320d826342823e17e5ecf1",
                    "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC9ZhOiaEICxeEO\n8GvtJDmuGtBmTgXFkNizaAgrdvcmNo4ZGprrwGR5GT3coCLo+0e6Q9w1kIdzTL90\nWMssOWxh3Y715Wtf6XZNljvSU1KVQ9jnn0KZGGwg2PzM87n2mc7Rk/Jkq3IBPZyd\nUpPDcdm6dXUwtwLTNW7+gRQR6FZqVxugEnTbSKaj3Dbc+c1PFawFIKG4AyB9PZWM\nHxeaIMuOk6mBkg1qpPadxAZoudI6PDyi6SCOlJ1Gbk4u8Y5PbmyrfY5FfdPY8gj0\nrHeJD8u+fyqW7NwuoO1nL6srwrvhLmzEsZhEd2vuLU9VPouHX1bHGxctgNuu5YyA\nQIygHRzxAgMBAAECggEAXIXyvop/ANrJBKLHnovtT5PSzb98y1RkwFPodc9Cklzh\nUvsvxk5w5sXBdjeWhklG84P2HgayXM2X088SxdJxk2eIULCYIT0sKV/kbm188OU5\nn4EqKB8Jp4xJBxhjdsgRhElphutIILoH+cTe4YILMq7xpnApBaPbSqIk+1CMcpqt\nB3FxJHJ1tvqUEgciD0P7CTmG0KduFp/XKLkCubS2SfZqJNiG3INVxjn9ZLEYdwbg\ng2FrgFsfj/l8E6P2MIE9ikaXZgFGPKsiBZgMUUutyMAx1hXHFxbjOA8TvvkVEcfL\n1IDieEiYqxNKbVTooW0qvD8uObPMsqCNqkmHtNGpTwKBgQD8QjLv6vssInMpW5OO\nGYab2KCCEk62Kpo5reY8oULosNRLeWYJTwr0//3N4xL+N2KsWDHeL9ygzECHH3Lu\nJRVh+WeaBtFA+qrLPn1f6ibU7XbUXmRMx4aOp5RiVXIo0vU2TTwfPm5huay8s+Jm\nni1eK7BElOqkBVpAiF1OJTU2fwKBgQDANTR+UqFVJu+TQHgfHhkO1C7JZUcqksBr\nI+EFtrUQ5gSUuCdAsK4HwsY2Os/gAiKuDi1+s9tA+a07P0uQUT7brJ6N9ST0Feyj\nsUQJ8MxipRYFf2kCknAtlrVA5YhiEHvEg/N74oUdu/gNBqsN5DH7WLG7hi756rHO\nyUXO8X5UjwKBgFYxZGg32TTeXI0gHk3qiOUNYuKu0LhL3ECjG81RqKQLb66OP4Ak\nwvCt25IS6bV1RUDwLbHmlrNWtyG0bDfU8fZ1GqI1fCCAxgUGSB6SykvtC7JKwmi9\nsEtkFT54RbaPRnwUbdubIGpB4DTmHhDEMWpA8UytuXLr5UexkHgYHJOPAoGAGLP9\n3ipyj8YkTnGfvqgYol5E8R9yKReZYWvIFPrphJV7iz2r1dWfWGIBJaEjbG/50xMB\nZ+Jn0I8GY7H73T2D7ane6vHR4QkcU+GJlBl9u0Pqc6Rvc6QshL905jVZ9PiXX6dx\n2L9BSpQJCmuL+ooUnnBEz4wsZ3Rxi9k0fqdtDCMCgYEAh3XkpPoU3B9vqOUvTs7Z\n6xMug6s1PKr6c3JJRcjzB0Ipgf1a4vx10kdfKRZfQN+JIUNbIkIqIb+JM3n9KImz\nlej7IQRdTFfIatCJY5XoQ1QFgOCRn+67byJimkG4f7mc0zLN46aoqkheVa0naFEw\nlEMOCCnUQSpXqq2v6MeQsfc=\n-----END PRIVATE KEY-----\n",
                    "client_email": "firebase-adminsdk-ssr1u@esp32demotest-b96e5.iam.gserviceaccount.com",
                    "client_id": "118250326587767241409",
                    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                    "token_uri": "https://oauth2.googleapis.com/token",
                    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
                    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-ssr1u%40esp32demotest-b96e5.iam.gserviceaccount.com",
                    "universe_domain": "googleapis.com"
                }, f, indent=4)
            cred = credentials.Certificate(cred_path)
            if not firebase_admin._apps:  # Chỉ khởi tạo nếu chưa có app
                firebase_admin.initialize_app(cred, {
                    'databaseURL': 'https://esp32demotest-b96e5-default-rtdb.asia-southeast1.firebasedatabase.app/'
                })
            self.db_ref = db.reference('login')
            print("Firebase đã kết nối thành công.")
        except Exception as e:
            print(f"Lỗi khi khởi tạo Firebase: {e}")
            self.db_ref = None

        self.bg_color = "#f5f7fa"
        self.accent_color = "#0078d7"
        self.text_color = "#333333"
        self.button_color = "#0078d7"
        self.button_hover_color = "#005ea2"
        self.font_label = ("Helvetica", 10, "normal")
        self.font_title = ("Helvetica", 12, "bold")
        self.font_button = ("Helvetica", 9, "normal")

        self.main_frame = tk.Frame(self.root, bg=self.bg_color)
        self.main_frame.pack(fill="both", expand=True)

        self.login_frame = tk.Frame(self.main_frame, width=200, bg="#ffffff", bd=1, relief="flat")
        self.login_frame.pack(side="left", padx=10, pady=10, fill="y")
        self.login_frame.pack_propagate(False)

        self.keyboard_frame = tk.Frame(self.main_frame, width=230, bg=self.bg_color, bd=1, relief="flat")
        self.keyboard_frame.pack(side="right", padx=10, pady=10, fill="y")
        self.keyboard_frame.pack_propagate(False)

        tk.Label(
            self.login_frame,
            text="Đăng nhập",
            font=self.font_title,
            bg="#ffffff",
            fg=self.text_color
        ).pack(pady=(10, 15))

        tk.Label(
            self.login_frame,
            text="Tên người dùng:",
            font=self.font_label,
            bg="#ffffff",
            fg=self.text_color
        ).pack(anchor="w", padx=10)
        self.entry_username = tk.Entry(
            self.login_frame,
            font=self.font_label,
            width=20,
            bd=1,
            relief="solid",
            bg="#f9f9f9"
        )
        self.entry_username.pack(pady=5, padx=10, fill="x")

        tk.Label(
            self.login_frame,
            text="Mật khẩu:",
            font=self.font_label,
            bg="#ffffff",
            fg=self.text_color
        ).pack(anchor="w", padx=10)
        self.entry_password = tk.Entry(
            self.login_frame,
            show="*",
            font=self.font_label,
            width=20,
            bd=1,
            relief="solid",
            bg="#f9f9f9"
        )
        self.entry_password.pack(pady=5, padx=10, fill="x")

        # Frame để chứa hai nút đăng nhập và đo offline ngang hàng
        self.button_frame = tk.Frame(self.login_frame, bg="#ffffff")
        self.button_frame.pack(pady=10, padx=10, fill="x")

        self.btn_login = tk.Button(
            self.button_frame,
            text="Đăng nhập",
            command=self.login,
            font=self.font_button,
            bg=self.button_color,
            fg="white",
            activebackground=self.button_hover_color,
            activeforeground="white",
            bd=0,
            relief="flat",
            cursor="hand2",
            width=10  # Làm nhỏ nút để vừa với nút mới
        )
        self.btn_login.pack(side="left", padx=5)
        self.btn_login.bind("<Enter>", lambda e: self.btn_login.config(bg=self.button_hover_color))
        self.btn_login.bind("<Leave>", lambda e: self.btn_login.config(bg=self.button_color))

        self.btn_offline = tk.Button(
            self.button_frame,
            text="Đo offline",
            command=self.offline_mode,
            font=self.font_button,
            bg="#757575",
            fg="white",
            activebackground="#616161",
            activeforeground="white",
            bd=0,
            relief="flat",
            cursor="hand2",
            width=10
        )
        self.btn_offline.pack(side="left", padx=5)
        self.btn_offline.bind("<Enter>", lambda e: self.btn_offline.config(bg="#616161"))
        self.btn_offline.bind("<Leave>", lambda e: self.btn_offline.config(bg="#757575"))

        self.label_info = tk.Label(
            self.login_frame,
            text="",
            font=("Helvetica", 9, "italic"),
            fg="#d32f2f",
            bg="#ffffff"
        )
        self.label_info.pack(pady=5)

        tk.Label(
            self.keyboard_frame,
            text="HealthCam",
            font=("Helvetica", 14, "bold"),
            bg=self.bg_color,
            fg=self.accent_color
        ).pack(pady=(10, 5))
        tk.Label(
            self.keyboard_frame,
            text="Hệ thống giám sát tín hiệu\ny sinh không chạm qua camera",
            font=("Helvetica", 9, "normal"),
            bg=self.bg_color,
            fg=self.text_color,
            justify="center",
            wraplength=200
        ).pack(pady=5)

        self.keyboard_subframe = tk.Frame(self.keyboard_frame, bg=self.bg_color)
        self.keyboard_subframe.pack(side="bottom", pady=10)

        def insert_character(char):
            focused_widget = self.root.focus_get()
            if focused_widget == self.entry_username:
                self.entry_username.insert(tk.END, char)
            elif focused_widget == self.entry_password:
                self.entry_password.insert(tk.END, char)

        def delete_character():
            focused_widget = self.root.focus_get()
            if focused_widget == self.entry_username:
                current_text = self.entry_username.get()
                self.entry_username.delete(0, tk.END)
                self.entry_username.insert(0, current_text[:-1])
            elif focused_widget == self.entry_password:
                current_text = self.entry_password.get()
                self.entry_password.delete(0, tk.END)
                self.entry_password.insert(0, current_text[:-1])

        keyboard_layout = [
            "1234567890",
            "qwertyuiop",
            "asdfghjkl",
            "zxcvbnm"
        ]

        keyboard_align_frame = tk.Frame(self.keyboard_subframe, bg=self.bg_color)
        keyboard_align_frame.pack(anchor="e", padx=(10, 0))

        for row_idx, row in enumerate(keyboard_layout):
            row_frame = tk.Frame(keyboard_align_frame, bg=self.bg_color)
            row_frame.pack(pady=1)
            for char in row:
                btn = tk.Button(
                    row_frame,
                    text=char,
                    width=2,
                    font=("Helvetica", 8, "normal"),
                    height=1,
                    padx=1,
                    pady=1,
                    bg="#ffffff",
                    fg=self.text_color,
                    bd=1,
                    relief="flat",
                    cursor="hand2",
                    activebackground=self.button_hover_color,
                    activeforeground="white"
                )
                btn.pack(side="left", padx=1)
                btn.configure(command=lambda c=char: insert_character(c))
                btn.bind("<Enter>", lambda e, b=btn: b.config(bg=self.button_hover_color, fg="white"))
                btn.bind("<Leave>", lambda e, b=btn: b.config(bg="#ffffff", fg=self.text_color))
            if row == "zxcvbnm":
                btn_delete = tk.Button(
                    row_frame,
                    text="←",
                    width=2,
                    font=("Helvetica", 8, "normal"),
                    height=1,
                    padx=1,
                    pady=1,
                    bg="#ffffff",
                    fg=self.text_color,
                    bd=1,
                    relief="flat",
                    cursor="hand2",
                    activebackground=self.button_hover_color,
                    activeforeground="white"
                )
                btn_delete.pack(side="left", padx=1)
                btn_delete.configure(command=delete_character)
                btn_delete.bind("<Enter>", lambda e: btn_delete.config(bg=self.button_hover_color, fg="white"))
                btn_delete.bind("<Leave>", lambda e: btn_delete.config(bg="#ffffff", fg=self.text_color))

    def login(self):
        username = self.entry_username.get().strip()
        password = self.entry_password.get().strip()
        if self.db_ref is None:
            self.label_info.config(text="Lỗi kết nối Firebase!", fg="#d32f2f")
            return

        try:
            users = self.db_ref.get()
            if users is None:
                self.label_info.config(text="Không có dữ liệu đăng nhập!", fg="#d32f2f")
                return

            suffixes = set()
            for k in users:
                if k.startswith("user"):
                    suffix = k[4:] if len(k) > 4 else ""
                    suffixes.add(suffix)
                elif k.startswith("pass"):
                    suffix = k[4:] if len(k) > 4 else ""
                    suffixes.add(suffix)

            found = False
            for suffix in suffixes:
                user_key = "user" + suffix
                pass_key = "pass" + suffix
                if user_key in users and pass_key in users:
                    if str(users[user_key]) == username and str(users[pass_key]) == password:
                        found = True
                        self.current_user = username
                        break

            if found:
                self.label_info.config(text="Đăng nhập thành công!", fg="#2e7d32")
                self.root.after(1000, self.successful_login)
            else:
                self.label_info.config(text="Tên người dùng hoặc mật khẩu sai!", fg="#d32f2f")
        except Exception as e:
            print(f"Lỗi khi truy vấn Firebase: {e}")
            self.label_info.config(text="Lỗi kết nối Firebase!", fg="#d32f2f")

    def successful_login(self):
        self.root.destroy()
        self.on_login_success(self.current_user)

    def offline_mode(self):
        self.label_info.config(text="Chế độ offline: Không lưu dữ liệu!", fg="#FFB300")
        self.root.after(1000, self.start_offline_mode)  # Gọi hàm mới để xử lý
    
    def start_offline_mode(self):
        self.root.destroy()  # Đóng cửa sổ đăng nhập
        self.on_login_success("offline")  # Chuyển sang giao diện đo

class BreathingRateApp:
    def __init__(self, root, current_user):
        self.root = root
        self.current_user = current_user
        self.root.title("Ứng dụng đo nhịp thở")
        self.root.geometry("480x280")
        self.root.resizable(False, False)
        self.estimator = None
        self.realtime_results = None
        self.running = False
        self.countdown = False
        self.start_time = None
        self.countdown_start = None
        self.duration = 60
        self.results = []
        self.video_label_active = False
        self.stop_flag = [False]
        self.recording_thread = None
        self.processing_thread = None
        self.video_file = None
        self.est_fps = 0
        self.measure_start_time = None
        self.frame_queue = queue.Queue()
        self.result_text = None
        self.result_button_frame = None
        self.recording_event = threading.Event()
        self.signal_data = None
        self.signal_image = None
        self.pending_result = None
        self.pending_result_saved = False
        self.save_button = None
        self.after_id = None  # Thêm để lưu ID lệnh after
        self.breath_hold_warning = None  # <-- thêm dòng này
        self.breath_hold_info = None  # lưu luôn thông tin đoạn nín thở (start, end, duration, type)

        try:
            self.mp_drawing = mp.solutions.drawing_utils
            self.mp_pose = mp.solutions.pose
        except Exception as e:
            print(f"Lỗi khi khởi tạo MediaPipe: {e}. Thoát chương trình.")
            self.root.destroy()
            return

        self.bg_color = "#f5f7fa"
        self.accent_color = "#0078d7"
        self.text_color = "#333333"
        self.button_color = "#0078d7"
        self.button_hover_color = "#005ea2"
        self.font_label = ("Helvetica", 10, "normal")
        self.font_title = ("Helvetica", 12, "bold")
        self.font_button = ("Helvetica", 9, "normal")
        self.font_small = ("Helvetica", 8, "normal")

        self.main_frame = tk.Frame(self.root, bg=self.bg_color)
        self.main_frame.pack(fill="both", expand=True)

        self.video_frame = tk.Frame(self.main_frame, bg="#ffffff", bd=1, relief="flat")
        self.video_frame.pack(side="left", padx=10, pady=10, fill="both", expand=True)
        self.video_frame.grid_rowconfigure(1, weight=1)
        self.video_frame.grid_columnconfigure(0, weight=1)

        self.label_title = tk.Label(
            self.video_frame,
            text="HealthCam Đo Nhịp Thở",
            font=self.font_title,
            bg="#ffffff",
            fg=self.accent_color,
            justify="center",
            pady=5
        )
        self.label_title.grid(row=0, column=0, sticky="ew", pady=5)

        self.label_video = tk.Label(self.video_frame, bg="#ffffff")

        self.label_info = tk.Label(
            self.video_frame,
            text="Nhập thời gian và nhấn 'Bắt đầu đo'",
            font=self.font_small,
            bg="#ffffff",
            fg=self.text_color
        )
        self.label_info.grid(row=2, column=0, sticky="ew", pady=10)

        self.control_frame = tk.Frame(self.main_frame, width=150, bg=self.bg_color, bd=1, relief="flat")
        self.control_frame.pack(side="right", padx=10, pady=10, fill="y")
        self.control_frame.pack_propagate(False)

        self.label_duration = tk.Label(
            self.control_frame,
            text="Thời gian đo (giây):",
            font=self.font_small,
            bg=self.bg_color,
            fg=self.text_color
        )
        self.label_duration.pack(pady=5, anchor="w", padx=10)

        self.duration_frame = tk.Frame(self.control_frame, bg=self.bg_color)
        self.duration_frame.pack(pady=5, fill="x", padx=10)

        self.entry_duration = tk.Entry(
            self.duration_frame,
            font=self.font_small,
            width=5,
            bd=1,
            relief="solid",
            bg="#f9f9f9"
        )
        self.entry_duration.pack(side="left", pady=1)
        self.entry_duration.insert(0, "60")

        self.btn_increase = tk.Button(
            self.duration_frame,
            text="+",
            command=self.increase_duration,
            font=self.font_small,
            width=1,
            bg="#ffffff",
            fg=self.text_color,
            bd=1,
            relief="flat",
            cursor="hand2",
            activebackground=self.button_hover_color,
            activeforeground="white"
        )
        self.btn_increase.pack(side="left", padx=3, pady=1)
        self.btn_increase.bind("<Enter>", lambda e: self.btn_increase.config(bg=self.button_hover_color, fg="white"))
        self.btn_increase.bind("<Leave>", lambda e: self.btn_increase.config(bg="#ffffff", fg=self.text_color))

        self.btn_decrease = tk.Button(
            self.duration_frame,
            text="-",
            command=self.decrease_duration,
            font=self.font_small,
            width=1,
            bg="#ffffff",
            fg=self.text_color,
            bd=1,
            relief="flat",
            cursor="hand2",
            activebackground=self.button_hover_color,
            activeforeground="white"
        )
        self.btn_decrease.pack(side="left", padx=3, pady=1)
        self.btn_decrease.bind("<Enter>", lambda e: self.btn_decrease.config(bg=self.button_hover_color, fg="white"))
        self.btn_decrease.bind("<Leave>", lambda e: self.btn_decrease.config(bg="#ffffff", fg=self.text_color))

        self.btn_start = tk.Button(
            self.control_frame,
            text="Bắt đầu đo",
            command=self.start_countdown,
            font=self.font_button,
            bg="#4CAF50",
            fg="white",
            activebackground="#388E3C",
            activeforeground="white",
            bd=0,
            relief="flat",
            cursor="hand2"
        )
        self.btn_start.pack(pady=5, padx=10, fill="x")
        self.btn_start.bind("<Enter>", lambda e: self.btn_start.config(bg="#388E3C"))
        self.btn_start.bind("<Leave>", lambda e: self.btn_start.config(bg="#4CAF50"))

        self.btn_stop = tk.Button(
            self.control_frame,
            text="Dừng đo",
            command=self.stop_measurement,
            font=self.font_button,
            bg="#f44336",
            fg="white",
            activebackground="#d32f2f",
            activeforeground="white",
            bd=0,
            relief="flat",
            cursor="hand2",
            state="disabled"
        )
        self.btn_stop.pack(pady=5, padx=10, fill="x")
        self.btn_stop.bind("<Enter>", lambda e: self.btn_stop.config(bg="#d32f2f"))
        self.btn_stop.bind("<Leave>", lambda e: self.btn_stop.config(bg="#f44336"))

        self.btn_history = tk.Button(
            self.control_frame,
            text="Xem nhịp thở",
            command=self.show_history,
            font=self.font_button,
            bg=self.button_color,
            fg="white",
            activebackground=self.button_hover_color,
            activeforeground="white",
            bd=0,
            relief="flat",
            cursor="hand2"
        )
        self.btn_history.pack(pady=5, padx=10, fill="x")
        self.btn_history.bind("<Enter>", lambda e: self.btn_history.config(bg=self.button_hover_color))
        self.btn_history.bind("<Leave>", lambda e: self.btn_history.config(bg=self.button_color))

        self.btn_logout = tk.Button(
            self.control_frame,
            text="Đăng xuất",
            command=self.logout,
            font=self.font_button,
            bg="#757575",
            fg="white",
            activebackground="#616161",
            activeforeground="white",
            bd=0,
            relief="flat",
            cursor="hand2"
        )
        self.btn_logout.pack(pady=5, padx=10, fill="x")
        self.btn_logout.bind("<Enter>", lambda e: self.btn_logout.config(bg="#616161"))
        self.btn_logout.bind("<Leave>", lambda e: self.btn_logout.config(bg="#757575"))

        self.label_user = tk.Label(
            self.control_frame,
            text=f"Người dùng: {self.current_user}" if self.current_user != "offline" else "Chế độ offline",
            font=("Helvetica", 8, "italic"),
            bg=self.bg_color,
            fg=self.text_color
        )
        self.label_user.pack(side="bottom", pady=10)

        self.json_dir = os.path.join(os.getcwd(), "user_json_history")
        self.csv_dir = os.path.join(os.getcwd(), "total_csv_history")
        os.makedirs(self.json_dir, exist_ok=True)
        os.makedirs(self.csv_dir, exist_ok=True)

        self.history_file = os.path.join(self.json_dir, f"nhiptho_{self.current_user}.json") if self.current_user != "offline" else None
        self.total_csv = os.path.join(self.csv_dir, "tong_dulieu_nhiptho.csv") if self.current_user != "offline" else None

        self.db_ref = None
        if self.current_user != "offline":
            try:
                cred_path = os.path.join(os.getcwd(), "firebase_credentials.json")
                if not firebase_admin._apps:  # Chỉ khởi tạo nếu chưa có app
                    cred = credentials.Certificate(cred_path)
                    firebase_admin.initialize_app(cred, {
                        'databaseURL': 'https://esp32demotest-b96e5-default-rtdb.asia-southeast1.firebasedatabase.app/'
                    })
                self.db_ref = db.reference('data_nhiptho/' + self.current_user)
                print("Firebase đã kết nối thành công cho dữ liệu nhịp thở.")
            except Exception as e:
                print(f"Lỗi khi khởi tạo Firebase cho dữ liệu nhịp thở: {e}")
                self.db_ref = None

        self.load_history()

        self.history_text = None
        self.nav_frame = None
        self.btn_prev = None
        self.btn_next = None
        self.page_label = None
        self.current_index = None
        self.showing_history = False
        self.showing_results = False
        self.signal_image = None

    def save_current_result(self):
        if self.current_user == "offline":
            self.label_info.config(text="Bạn cần đăng nhập trước để lưu dữ liệu!", fg="#d32f2f")
            return
        if not self.pending_result or not self.signal_data:
            self.label_info.config(text="Không có dữ liệu để lưu!", fg="#d32f2f")
            return
        if self.pending_result_saved:
            self.label_info.config(text="Kết quả này đã được lưu.", fg=self.text_color)
            return
        try:
            timestamps, shoulder_y, filtered_y, peak_times, _ = self.signal_data
            breath_count = self.pending_result["breath_count"]
            avg_breath_duration = self.pending_result["avg_breath_duration"]
            breath_per_min = self.pending_result["breath_per_min"]

            self.save_history(breath_count, avg_breath_duration, breath_per_min)

            save_breath_data(
                timestamps=timestamps,
                shoulder_y=shoulder_y,
                filtered_y=filtered_y,
                peak_times=peak_times,
                predicted_breaths=breath_per_min,
                avg_breath_duration=avg_breath_duration
            )

            self.pending_result_saved = True
            if self.save_button:
                self.save_button.config(state="disabled", text="Đã lưu")
            self.label_info.config(text="Đã lưu kết quả đo.", fg="#2e7d32")
        except Exception as e:
            print(f"Lỗi khi lưu kết quả: {e}")
            self.label_info.config(text="Lưu thất bại!", fg="#d32f2f")

    def increase_duration(self):
        try:
            current_duration = int(self.entry_duration.get())
            new_duration = current_duration + 5
            if new_duration > 60:
                new_duration = 60
            self.entry_duration.delete(0, tk.END)
            self.entry_duration.insert(0, str(new_duration))
        except ValueError:
            self.label_info.config(text="Vui lòng nhập số hợp lệ!", fg="#d32f2f")

    def decrease_duration(self):
        try:
            current_duration = int(self.entry_duration.get())
            if current_duration > 20:
                new_duration = max(20, current_duration - 5)
                self.entry_duration.delete(0, tk.END)
                self.entry_duration.insert(0, str(new_duration))
        except ValueError:
            self.label_info.config(text="Vui lòng nhập số hợp lệ!", fg="#d32f2f")

    def load_history(self):
        if self.current_user == "offline":
            self.results = []  # Không tải dữ liệu ở offline
            return
        try:
            if os.path.exists(self.history_file):
                with open(self.history_file, 'r', encoding='utf-8') as f:
                    self.results = json.load(f)
            else:
                self.results = []

            for result in self.results:
                if not all(key in result for key in ["thời gian", "số nhịp thở", "thời gian đo", "chu kỳ thở trung bình", "nhịp thở mỗi phút"]):
                    self.results = []
                    break

            if self.db_ref:
                try:
                    fb_data = self.db_ref.get()
                    if fb_data:
                        self.results = fb_data
                        for result in self.results:
                            if not all(key in result for key in ["thời gian", "số nhịp thở", "thời gian đo", "chu kỳ thở trung bình", "nhịp thở mỗi phút"]):
                                self.results = []
                                break
                        self.db_ref.set(self.results)
                    else:
                        self.db_ref.set(self.results)
                except Exception as e:
                    print(f"Lỗi khi đồng bộ lịch sử với Firebase: {e}")

            with open(self.history_file, 'w', encoding='utf-8') as f:
                json.dump(self.results, f, indent=4, ensure_ascii=False)
        except Exception as e:
            print(f"Lỗi khi tải lịch sử: {e}")
            self.results = []

    def save_history(self, breath_count, avg_breath_duration, breath_per_min):
        try:
            timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            result = {
                "thời gian": timestamp,
                "số nhịp thở": breath_count,
                "thời gian đo": self.duration,
                "chu kỳ thở trung bình": round(avg_breath_duration, 2),
                "nhịp thở mỗi phút": round(breath_per_min)
            }
            self.results.append(result)
            with open(self.history_file, 'w', encoding='utf-8') as f:
                json.dump(self.results, f, indent=4, ensure_ascii=False)
            if self.db_ref:
                self.db_ref.set(self.results)
            print(f"Đã lưu lịch sử cho người dùng {self.current_user} vào {self.history_file}")
            self.save_to_total_csv(result)
        except Exception as e:
            print(f"Lỗi khi lưu lịch sử: {e}")

    def save_to_total_csv(self, result):
        try:
            fieldnames = ["user", "thời gian", "số nhịp thở", "thời gian đo", "chu kỳ thở trung bình", "nhịp thở mỗi phút"]
            file_exists = os.path.isfile(self.total_csv) and os.path.getsize(self.total_csv) > 0
            with open(self.total_csv, mode='a', newline='', encoding='utf-8') as file:
                writer = csv.DictWriter(file, fieldnames=fieldnames)
                if not file_exists:
                    writer.writeheader()
                row = {"user": self.current_user}
                row.update(result)
                writer.writerow(row)
            print(f"Đã lưu vào csv tổng: {self.total_csv}")
        except Exception as e:
            print(f"Lỗi khi lưu csv tổng: {e}")

    def center_window(self, window, width, height):
        screen_width = window.winfo_screenwidth()
        screen_height = window.winfo_screenheight()
        x = (screen_width - width) // 2
        y = (screen_height - height) // 2
        window.geometry(f"{width}x{height}+{x}+{y}")

    def show_signal_plot(self):
        if self.signal_data is None:
            self.label_info.config(text="Không có dữ liệu biểu đồ!", fg="#d32f2f")
            return
        try:
            plot_window = tk.Toplevel(self.root)
            plot_window.title("Biểu đồ nhịp thở")
            self.center_window(plot_window, 460, 250)

            signal_image_path = "user_breath_plot.png"
            if not os.path.exists(signal_image_path):
                self.label_info.config(text="Không tìm thấy biểu đồ!", fg="#d32f2f")
                plot_window.destroy()
                return

            img = Image.open(signal_image_path)
            img = img.resize((460, 250), Image.Resampling.LANCZOS)
            self.signal_image = ImageTk.PhotoImage(img)
            label = tk.Label(plot_window, image=self.signal_image)
            label.pack(fill="both", expand=True)

            close_button = tk.Button(
                plot_window,
                text="Đóng",
                command=plot_window.destroy,
                font=self.font_small,
                width=8,
                bg=self.button_color,
                fg="white",
                bd=0,
                relief="flat",
                cursor="hand2",
                activebackground=self.button_hover_color,
                activeforeground="white"
            )
            close_button.pack(pady=5)
            close_button.bind("<Enter>", lambda e: close_button.config(bg=self.button_hover_color))
            close_button.bind("<Leave>", lambda e: close_button.config(bg=self.button_color))
        except Exception as e:
            print(f"Lỗi khi hiển thị biểu đồ: {e}")
            self.label_info.config(text="Lỗi hiển thị biểu đồ!", fg="#d32f2f")
            if 'plot_window' in locals():
                plot_window.destroy()

    def enable_controls(self):
        self.entry_duration.config(state="normal")
        self.btn_increase.config(state="normal")
        self.btn_decrease.config(state="normal")
        self.btn_start.config(state="normal")
        self.btn_history.config(state="normal")
        self.btn_logout.config(state="normal")
        self.btn_stop.config(state="disabled")

    def disable_controls(self):
        self.entry_duration.config(state="disabled")
        self.btn_increase.config(state="disabled")
        self.btn_decrease.config(state="disabled")
        self.btn_history.config(state="disabled")
        self.btn_logout.config(state="disabled")
        self.btn_stop.config(state="normal")

    def start_countdown(self):
        try:
            self.duration = float(self.entry_duration.get())
            if not 20 <= self.duration <= 60:
                self.label_info.config(text="Thời gian phải từ 20 đến 60 giây!", fg="#d32f2f")
                return
        except ValueError:
            self.label_info.config(text="Vui lòng nhập số hợp lệ!", fg="#d32f2f")
            return

        if not self.running and not self.countdown:
            self.countdown = True
            self.countdown_start = time.time()
            self.disable_controls()
            self.label_info.config(text="Chuẩn bị, đo bắt đầu sau 10 giây...", fg=self.text_color)
            if self.showing_history:
                self.hide_history()
            if self.showing_results:
                self.hide_results()
            self.video_label_active = True
            self.label_video.grid(row=1, column=0, sticky="nsew")
            self.recording_event.clear()
            self.start_preview_and_recording()
            self.root.after(30, self.update_video_feed)
            self.update_countdown_label()

    def update_countdown_label(self):
        if self.countdown:
            elapsed = time.time() - self.countdown_start
            countdown_time = max(0, 10 - int(elapsed))
            self.label_info.config(text=f"Chuẩn bị, đo bắt đầu sau {countdown_time} giây...", fg=self.text_color)
            if elapsed >= 10:
                self.countdown = False
                self.running = True
                self.measure_start_time = time.time()
                self.label_info.config(text=f"Đang đo, còn {int(self.duration)} giây...", fg=self.text_color)
                self.recording_event.set()
                self.root.after(100, self.update_measurement_timer)
            else:
                self.root.after(100, self.update_countdown_label)

    def update_measurement_timer(self):
        if self.running and self.measure_start_time:
            elapsed = time.time() - self.measure_start_time
            remaining = max(0, self.duration - elapsed)
            if remaining <= 10:
                text = f"Gần xong rồi... còn {int(remaining)} giây"
            else:
                text = f"Đang đo, còn {int(remaining)} giây..."
            self.label_info.config(text=text)
            if remaining > 0:
                self.root.after(100, self.update_measurement_timer)

    def update_video_feed(self):
        frame_rgb = None
        while not self.frame_queue.empty():
            frame_rgb = self.frame_queue.get()
        if frame_rgb is not None:
            img = Image.fromarray(frame_rgb)
            imgtk = ImageTk.PhotoImage(image=img)
            self.label_video.imgtk = imgtk
            self.label_video.configure(image=imgtk)
        if self.video_label_active:
            self.root.after(30, self.update_video_feed)

    def start_preview_and_recording(self):
        self.stop_flag[0] = False
        self.estimator = OnlineBreathEstimator()
        self.realtime_results = None
        # Reset thông tin nín thở cho lần đo mới
        self.breath_hold_info = None
        self.breath_hold_warning = None
        self.recording_thread = threading.Thread(target=self.recording_worker)
        self.recording_thread.start()

    def recording_worker(self):
        self.video_file, self.est_fps = record_video(
            duration=self.duration,
            stop_flag=self.stop_flag,
            frame_queue=self.frame_queue,
            recording_event=self.recording_event,
            estimator=self.estimator,
            save_video=False,
            draw_roi=True
        )
        try:
            if self.estimator is not None:
                self.realtime_results = self.estimator.finalize(fps_hint=self.est_fps)
                # Lấy thông tin nín thở từ cơ chế riêng
                self.breath_hold_info = getattr(self.estimator, "hold_info_mechanic", None)
                self.breath_hold_warning = getattr(self.estimator, "hold_warning_text", None)
        except Exception as e:
            print(f"Lỗi finalize realtime: {e}")
            self.realtime_results = None
            self.breath_hold_info = None
            self.breath_hold_warning = None
        finally:
            # RẤT QUAN TRỌNG: báo cho UI là quay xong rồi
            try:
                self.root.after(0, self.on_recording_complete)
            except Exception as e:
                print(f"Lỗi khi schedule on_recording_complete: {e}")

    def on_recording_complete(self):
        if self.stop_flag[0]:
            self.handle_stopped("Đo bị dừng trong quá trình quay.")
            return

        if self.realtime_results is not None:
            (breath_count, avg_breath_duration, breath_per_min, fs, peak_times, shoulder_y, filtered_y, timestamps, peaks) = self.realtime_results
            self.on_processing_complete(
                breath_count, avg_breath_duration, breath_per_min, fs, peak_times, shoulder_y, filtered_y, timestamps, peaks
            )
            return

        self.label_info.config(text="Đang xử lý video...", fg=self.text_color)
        self.processing_thread = threading.Thread(target=self.processing_worker)
        self.processing_thread.start()

    def processing_worker(self):
        if self.video_file:
            (
                breath_count,
                avg_breath_duration,
                breath_per_min,
                fps,
                peak_times,
                shoulder_y,
                filtered_y,
                timestamps,
                peaks,
                hold_info,
                hold_warning,
            ) = process_breathing(self.video_file, self.est_fps, stop_flag=self.stop_flag)

            # GÁN vào biến của app để UI dùng chung với realtime
            self.breath_hold_info = hold_info
            self.breath_hold_warning = hold_warning

            self.root.after(
                0,
                lambda: self.on_processing_complete(
                    breath_count,
                    avg_breath_duration,
                    breath_per_min,
                    fps,
                    peak_times,
                    shoulder_y,
                    filtered_y,
                    timestamps,
                    peaks,
                ),
            )
        else:
            self.root.after(0, self.on_processing_failed)


    def on_processing_complete(self, breath_count, avg_breath_duration, breath_per_min, fps, peak_times, shoulder_y, filtered_y, timestamps, peaks):
        if self.stop_flag[0]:
            self.handle_stopped("Đo bị dừng trong quá trình xử lý.")
            return

        self.signal_data = (timestamps, shoulder_y, filtered_y, peak_times, peaks)
        self.pending_result = {
            "breath_count": breath_count,
            "avg_breath_duration": avg_breath_duration,
            "breath_per_min": breath_per_min,
        }
        self.pending_result_saved = False

        # KHÔNG phân tích nín thở ở đây nữa
        # breath_hold_info & breath_hold_warning đã được set trong recording_worker
        # từ self.estimator.hold_info_mechanic / hold_warning_text

        # Vẽ lại biểu đồ cho user, có vùng nín thở (nếu phát hiện)
        try:
            marks_arr = np.array(peak_times, dtype=float) if peak_times else np.array([])
            plot_user_signal(
                t=np.array(timestamps, dtype=float),
                y=np.array(filtered_y, dtype=float),
                chosen_marks=marks_arr,
                filename="user_breath_plot.png",
                hold_info=self.breath_hold_info  # dùng info lấy từ estimator
            )
        except Exception as e:
            print(f"Lỗi vẽ biểu đồ user với vùng nín thở: {e}")

        self.show_results(breath_count, avg_breath_duration, breath_per_min, fps)
        self.finalize_measurement()



    def on_processing_failed(self):
        self.handle_stopped("Lỗi xử lý video.")

    def show_results(self, breath_count, avg_breath_duration, breath_per_min, fps):
        # Ẩn preview webcam
        if self.video_label_active:
            self.label_video.grid_forget()
            self.label_video.configure(image='')
            self.video_label_active = False

        # Ẩn lịch sử nếu đang mở
        if self.showing_history:
            self.hide_history()

        self.showing_results = True
        self.label_info.config(text="Kết quả đo nhịp thở", fg=self.text_color)

        # Khung text kết quả
        self.result_text = tk.Text(
            self.video_frame,
            font=(self.font_small[0], self.font_small[1], "bold"),  # Chữ đậm
            bg="#f9f9f9",
            fg=self.text_color,
            wrap="word",
            height=6,
            width=35,
            bd=1,
            relief="solid",
            padx=5,
            pady=5
        )
        self.result_text.grid(row=3, column=0, sticky="nsew", pady=5, padx=5)

        # ================== LOGIC PHÂN LOẠI TRẠNG THÁI ==================
        status_color = "#2E7D32"  # mặc định: xanh lá (bình thường)
        status = "Thở bình thường"
        extra_warning_lines = []

        hold_info = getattr(self, "breath_hold_info", None)

        # --- Ưu tiên: nếu phát hiện nín thở / không thở ---
        if hold_info is not None:
            dur = float(hold_info.get("duration", 0.0) or 0.0)
            hold_type = hold_info.get("type", "unknown")

            # Chỉ cảnh báo nếu đoạn này đủ dài (>= 5s, đúng với min_hold_sec)
            if dur >= 5.0:
                if hold_type == "full_inhale":
                    status = "Nghi ngờ nín thở sau khi hít vào (chỉ hít vào/giữ hơi)"
                elif hold_type == "full_exhale":
                    status = "Nghi ngờ nín thở sau khi thở ra (chỉ thở ra/giữ hơi)"
                else:
                    status = "Nghi ngờ nín thở / không thở"

                status_color = "#D32F2F"  # đỏ

                # Thêm câu mô tả chi tiết đã format sẵn (nếu có)
                if self.breath_hold_warning:
                    extra_warning_lines.append(self.breath_hold_warning)

        # --- Nếu KHÔNG có nín thở rõ ràng thì dùng logic nhịp/phút + chu kỳ ---
        if hold_info is None or (hold_info is not None and hold_info.get("duration", 0.0) < 5.0):
            # Phân loại dựa vào nhịp/phút và chu kỳ trung bình
            # Bạn có thể chỉnh lại ngưỡng tùy ý
            if breath_per_min < 10:
                status = "Thở bất thường (rất chậm)"
                status_color = "#D32F2F"  # Đỏ đậm
            elif 10 <= breath_per_min < 12:
                status = "Thở hơi chậm"
                status_color = "#FFB300"  # Vàng đậm
            elif 12 <= breath_per_min <= 20:
                status = "Thở bình thường"
                status_color = "#2E7D32"  # Xanh lá đậm
            else:
                # > 20 nhịp/phút → xem thêm chu kỳ để nhận diện THỞ NÔNG
                # Ví dụ: nhịp nhanh + chu kỳ ngắn hơn ~2s → nghi ngờ thở nông
                if breath_per_min >= 20 and avg_breath_duration <= 2.0:
                    status = "Thở nông (nhanh, chu kỳ ngắn)"
                    status_color = "#D32F2F"  # Đỏ cảnh báo
                    extra_warning_lines.append(
                        "Hệ thống nghi ngờ bạn đang thở nông: nhịp thở nhanh và thời gian mỗi chu kỳ ngắn."
                    )
                elif 20 < breath_per_min <= 22:
                    status = "Thở hơi nhanh"
                    status_color = "#FFB300"  # Vàng đậm
                else:  # breath_per_min > 22 và chu kỳ không quá ngắn
                    status = "Thở bất thường (rất nhanh)"
                    status_color = "#D32F2F"  # Đỏ đậm

        # ================== GHÉP TEXT HIỂN THỊ ==================
        result_text = (
            f"Số nhịp thở: {breath_count}\n"
            f"Thời gian đo: {self.duration:.1f} giây\n"
            f"Chu kỳ thở TB: {avg_breath_duration:.2f} giây\n"
            f"Nhịp/phút: {round(breath_per_min)}\n"
            f"Trạng thái: {status}"
        )

        # Thêm các dòng cảnh báo chi tiết (nếu có)
        if extra_warning_lines:
            result_text += "\n" + "\n".join(extra_warning_lines)

        self.result_text.config(state="normal")
        self.result_text.delete(1.0, tk.END)
        self.result_text.insert(tk.END, result_text)

        # Tô màu dòng "Trạng thái"
        self.result_text.tag_configure(
            "status",
            foreground=status_color,
            font=(self.font_small[0], self.font_small[1], "bold")
        )
        start_idx = self.result_text.search("Trạng thái", "1.0", tk.END)
        if start_idx:
            line_no = start_idx.split('.')[0]
            self.result_text.tag_add("status", f"{line_no}.0", f"{line_no}.end")

        self.result_text.config(state="disabled")

        # ================== NÚT BÊN DƯỚI KẾT QUẢ ==================
        self.result_button_frame = tk.Frame(self.video_frame, bg="#ffffff")
        self.result_button_frame.grid(row=4, column=0, sticky="ew", pady=5)

        self.save_button = tk.Button(
            self.result_button_frame,
            text="Lưu kết quả đo",
            command=self.save_current_result,
            font=self.font_small,
            width=14,
            bg=self.button_color,
            fg="white",
            bd=0,
            relief="flat",
            cursor="hand2",
            activebackground=self.button_hover_color,
            activeforeground="white",
            state="normal" if not self.pending_result_saved else "disabled"
        )
        self.save_button.pack(side="left", padx=5, pady=2)
        self.save_button.bind("<Enter>", lambda e: self.save_button.config(bg=self.button_hover_color))
        self.save_button.bind("<Leave>", lambda e: self.save_button.config(bg=self.button_color))

        plot_button = tk.Button(
            self.result_button_frame,
            text="Xem biểu đồ",
            command=self.show_signal_plot,
            font=self.font_small,
            width=10,
            bg=self.button_color,
            fg="white",
            bd=0,
            relief="flat",
            cursor="hand2",
            activebackground=self.button_hover_color,
            activeforeground="white"
        )
        plot_button.pack(side="left", padx=5, pady=2)
        plot_button.bind("<Enter>", lambda e: plot_button.config(bg=self.button_hover_color))
        plot_button.bind("<Leave>", lambda e: plot_button.config(bg=self.button_color))

        close_button = tk.Button(
            self.result_button_frame,
            text="Đóng",
            command=self.hide_results,
            font=self.font_small,
            width=8,
            bg=self.button_color,
            fg="white",
            bd=0,
            relief="flat",
            cursor="hand2",
            activebackground=self.button_hover_color,
            activeforeground="white"
        )
        close_button.pack(side="left", padx=5, pady=2)
        close_button.bind("<Enter>", lambda e: close_button.config(bg=self.button_hover_color))
        close_button.bind("<Leave>", lambda e: close_button.config(bg=self.button_color))


    def hide_results(self):
        if self.result_text:
            self.result_text.grid_forget()
            self.result_text.destroy()
            self.result_text = None
        if self.result_button_frame:
            self.result_button_frame.grid_forget()
            self.result_button_frame.destroy()
            self.result_button_frame = None
        self.showing_results = False
        # Đảm bảo label_info tồn tại
        if not hasattr(self, 'label_info') or self.label_info is None or not self.label_info.winfo_exists():
            self.label_info = tk.Label(
                self.video_frame,
                text="",
                font=self.font_small,
                bg="#ffffff",
                fg=self.text_color
            )
            self.label_info.grid(row=2, column=0, sticky="ew", pady=10)
        self.label_info.config(text="Nhập thời gian và nhấn 'Bắt đầu đo'", fg=self.text_color)
        self.root.update()

    def stop_measurement(self):
        if self.running or self.countdown:
            self.stop_flag[0] = True
            self.running = False
            self.countdown = False
            self.measure_start_time = None
            self.enable_controls()
            self.label_info.config(text="Đang dừng đo...", fg="#d32f2f")
            self.root.update()
            if self.recording_thread and self.recording_thread.is_alive():
                self.recording_thread.join(timeout=2.0)
            if self.processing_thread and self.processing_thread.is_alive():
                self.processing_thread.join(timeout=2.0)
            if self.showing_history:
                self.hide_history()
            if self.showing_results:
                self.hide_results()
            try:
                cv2.destroyAllWindows()
            except Exception:
                pass

    def handle_stopped(self, message):
        self.label_info.config(text=message, fg="#d32f2f")
        self.finalize_measurement()
        self.after_id = self.root.after(3000, self.reset_info_label)  # Lưu ID

    def finalize_measurement(self):
        self.running = False
        self.countdown = False
        self.measure_start_time = None
        self.enable_controls()
        self.video_label_active = False
        if self.label_video:
            self.label_video.grid_forget()
            self.label_video.configure(image='')
        while not self.frame_queue.empty():
            self.frame_queue.get()
        self.stop_flag[0] = False
        self.video_file = None
        self.est_fps = 0
        self.recording_event.clear()
        if self.recording_thread and self.recording_thread.is_alive():
            self.recording_thread.join(timeout=2.0)
        if self.processing_thread and self.processing_thread.is_alive():
            self.processing_thread.join(timeout=2.0)
        try:
            cv2.destroyAllWindows()
        except Exception:
            pass

    def reset_info_label(self):
        self.label_info.config(text="Nhập thời gian và nhấn 'Bắt đầu đo'", fg=self.text_color)
        self.root.update()

    def hide_history(self):
        if self.history_text:
            self.history_text.grid_forget()
            self.history_text.destroy()
            self.history_text = None
        if self.nav_frame:
            self.nav_frame.grid_forget()
            self.nav_frame.destroy()
            self.nav_frame = None
        self.btn_prev = None
        self.btn_next = None
        self.page_label = None
        self.current_index = None
        self.showing_history = False
        # Đảm bảo label_info tồn tại
        if not hasattr(self, 'label_info') or self.label_info is None or not self.label_info.winfo_exists():
            self.label_info = tk.Label(
                self.video_frame,
                text="",
                font=self.font_small,
                bg="#ffffff",
                fg=self.text_color
            )
            self.label_info.grid(row=2, column=0, sticky="ew", pady=10)
        self.label_info.config(text="Nhập thời gian và nhấn 'Bắt đầu đo'", fg=self.text_color)
        self.root.update()

    def show_history(self):
        if self.current_user == "offline":
            # Ở chế độ offline, hiển thị không có dữ liệu
            if self.video_label_active:
                self.label_video.grid_forget()
                self.label_video.configure(image='')
                self.video_label_active = False
            if self.showing_results:
                self.hide_results()
            self.showing_history = True
            self.label_info.config(text="Không có dữ liệu (chế độ offline)!", fg="#d32f2f")
            return
        try:
            self.load_history()
            if self.video_label_active:
                self.label_video.grid_forget()
                self.label_video.configure(image='')
                self.video_label_active = False
            if self.showing_results:
                self.hide_results()
            if self.showing_history:
                self.hide_history()
            self.showing_history = True

            # Kiểm tra và khởi tạo lại self.label_info nếu cần
            if not hasattr(self, 'label_info') or self.label_info is None or not self.label_info.winfo_exists():
                self.label_info = tk.Label(
                    self.video_frame,
                    text="",
                    font=self.font_small,
                    bg="#ffffff",
                    fg=self.text_color
                )
                self.label_info.grid(row=2, column=0, sticky="ew", pady=10)

            self.label_info.config(text="Đang xem lịch sử nhịp thở...", fg=self.text_color)
            self.history_text = tk.Text(
                self.video_frame,
                font=self.font_small,
                bg="#f9f9f9",
                fg=self.text_color,
                wrap="word",
                height=6,
                width=35,
                bd=1,
                relief="solid",
                padx=5,
                pady=5
            )
            self.history_text.grid(row=3, column=0, sticky="nsew", pady=5, padx=5)

            sorted_results = sorted(self.results, key=lambda x: x.get("thời gian", ""), reverse=True)
            total_records = len(sorted_results)
            if self.current_index is None:
                self.current_index = tk.IntVar(value=0)

            def update_text(index):
                self.history_text.config(state="normal")
                self.history_text.delete(1.0, tk.END)
                if not sorted_results:
                    self.history_text.insert(tk.END, "Chưa có dữ liệu nhịp thở!\n")
                else:
                    start = index
                    end = min(index + 2, total_records)
                    for i in range(start, end):
                        result = sorted_results[i]
                        self.history_text.insert(tk.END, f"Thời gian: {result.get('thời gian', 'N/A')}\n")
                        self.history_text.insert(tk.END, f"Nhịp thở: {result.get('số nhịp thở', 'N/A')} nhịp/{result.get('thời gian đo', 'N/A')}s\n")
                        self.history_text.insert(tk.END, f"Chu kỳ TB: {result.get('chu kỳ thở trung bình', 'N/A')}s\n")
                        self.history_text.insert(tk.END, f"Nhịp/phút: {result.get('nhịp thở mỗi phút', 'N/A')}\n\n")
                self.history_text.config(state="disabled")
                self.btn_prev.config(state="normal" if index + 2 < total_records else "disabled")
                self.btn_next.config(state="normal" if index > 0 else "disabled")
                start_disp = index + 1
                end_disp = min(index + 2, total_records)
                self.page_label.config(text=f"{start_disp}-{end_disp}/{total_records}")

            self.nav_frame = tk.Frame(self.video_frame, bg="#ffffff")
            self.nav_frame.grid(row=4, column=0, sticky="ew", pady=5)
            self.nav_frame.grid_columnconfigure(0, weight=1)
            self.nav_frame.grid_columnconfigure(1, weight=1)
            self.nav_frame.grid_columnconfigure(2, weight=1)

            self.btn_prev = tk.Button(
                self.nav_frame,
                text="Trước",
                command=lambda: change_page(2),
                font=self.font_small,
                width=8,
                bg="#ffffff",
                fg=self.text_color,
                bd=1,
                relief="flat",
                cursor="hand2",
                activebackground=self.button_hover_color,
                activeforeground="white"
            )
            self.btn_prev.grid(row=0, column=0, sticky="w", padx=5)
            self.btn_prev.bind("<Enter>", lambda e: self.btn_prev.config(bg=self.button_hover_color, fg="white"))
            self.btn_prev.bind("<Leave>", lambda e: self.btn_prev.config(bg="#ffffff", fg=self.text_color))

            self.page_label = tk.Label(
                self.nav_frame,
                text=f"Hiển thị 1-{min(2, total_records)}/{total_records}",
                font=self.font_small,
                bg="#ffffff",
                fg=self.text_color
            )
            self.page_label.grid(row=0, column=1, sticky="n", padx=5)

            self.btn_next = tk.Button(
                self.nav_frame,
                text="Sau",
                command=lambda: change_page(-2),
                font=self.font_small,
                width=8,
                bg="#ffffff",
                fg=self.text_color,
                bd=1,
                relief="flat",
                cursor="hand2",
                activebackground=self.button_hover_color,
                activeforeground="white"
            )
            self.btn_next.grid(row=0, column=2, sticky="e", padx=5)
            self.btn_next.bind("<Enter>", lambda e: self.btn_next.config(bg=self.button_hover_color, fg="white"))
            self.btn_next.bind("<Leave>", lambda e: self.btn_next.config(bg="#ffffff", fg=self.text_color))

            def change_page(delta):
                new_index = self.current_index.get() + delta
                if 0 <= new_index < total_records:
                    self.current_index.set(new_index)
                    update_text(new_index)

            update_text(self.current_index.get())
        except Exception as e:
                print(f"Lỗi khi hiển thị lịch sử: {e}\n{traceback.format_exc()}")
                # Đảm bảo self.label_info tồn tại trước khi config
                if not hasattr(self, 'label_info') or self.label_info is None or not self.label_info.winfo_exists():
                    self.label_info = tk.Label(
                        self.video_frame,
                        text="",
                        font=self.font_small,
                        bg="#ffffff",
                        fg=self.text_color
                    )
                    self.label_info.grid(row=2, column=0, sticky="ew", pady=10)
                self.label_info.config(text="Lỗi hiển thị lịch sử!", fg="#d32f2f")
                self.hide_history()

    def logout(self):
        # Dừng mọi hoạt động đo và luồng
        if self.running or self.countdown:
            self.stop_measurement()  # Gọi hàm stop_measurement để đảm bảo dừng luồng và giải phóng tài nguyên
        else:
            self.stop_flag[0] = True  # Đặt stop_flag để ngăn chặn luồng mới
            # Đảm bảo các thread được dừng
            if self.recording_thread and self.recording_thread.is_alive():
                self.recording_thread.join(timeout=2.0)
            if self.processing_thread and self.processing_thread.is_alive():
                self.processing_thread.join(timeout=2.0)
        
        # Ẩn giao diện lịch sử hoặc kết quả nếu đang hiển thị
        if self.showing_history:
            self.hide_history()
        if self.showing_results:
            self.hide_results()
        
        # Giải phóng tài nguyên Firebase
        try:
            if firebase_admin._apps:
                firebase_admin.delete_app(firebase_admin.get_app())
            print("Đã xóa ứng dụng Firebase.")
        except Exception as e:
            print(f"Lỗi khi xóa ứng dụng Firebase: {e}")
        
        # Giải phóng webcam và các cửa sổ OpenCV
        try:
            cv2.destroyAllWindows()
        except Exception:
            pass
        
        # Đóng cửa sổ hiện tại
        self.root.destroy()
        
        # Mở cửa sổ đăng nhập mới
        login_root = tk.Tk()
        login_app = LoginApp(login_root, start_main_app)
        login_root.mainloop()

    def on_closing(self):
        if self.after_id is not None:
            self.root.after_cancel(self.after_id)  # Hủy lệnh after
            self.after_id = None
        self.running = False
        self.countdown = False
        self.stop_flag[0] = True
        if self.showing_history:
            self.hide_history()
        if self.showing_results:
            self.hide_results()
        try:
            if firebase_admin._apps:
                firebase_admin.delete_app(firebase_admin.get_app())
            print("Đã xóa ứng dụng Firebase khi đóng ứng dụng.")
        except Exception as e:
            print(f"Lỗi khi xóa ứng dụng Firebase: {e}")
        try:
            cv2.destroyAllWindows()
        except Exception:
            pass
        self.root.destroy()

def start_main_app(current_user):
    root = tk.Tk()
    app = BreathingRateApp(root, current_user)
    root.protocol("WM_DELETE_WINDOW", app.on_closing)
    root.mainloop()

if __name__ == "__main__":
    try:
        login_root = tk.Tk()
        login_app = LoginApp(login_root, start_main_app)
        login_root.mainloop()
    except Exception as e:
        print(f"Lỗi khi khởi động chương trình: {e}")