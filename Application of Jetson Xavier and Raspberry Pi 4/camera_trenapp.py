import cv2
import os
import time
import json
import base64
import asyncio
import websockets
import threading
import queue
from ultralytics import YOLO
from firebase_admin import credentials, db
import firebase_admin
import numpy as np

FIREBASE_HOST = "https://login-535de-default-rtdb.firebaseio.com/"
SAVE_DIR = r"D:\CHUONGTRINHDAIHOC\IUH\Nam_4_HKII\DAKTNCAO\CODE_LAN_1\data_images"
os.makedirs(SAVE_DIR, exist_ok=True)

# Khởi tạo Firebase
try:
    with open(r'D:\CHUONGTRINHDAIHOC\IUH\Nam_4_HKII\DAKTNCAO\CODE_LAN_1\CODE_NHANDIEN\main_fix_toiuu\firebase_config.json', 'r') as f:
        cred_dict = json.load(f)
    cred = credentials.Certificate(cred_dict)
    firebase_admin.initialize_app(cred, {'databaseURL': FIREBASE_HOST})
except Exception as e:
    print(f"Lỗi khởi tạo Firebase: {e}")
    exit(1)

# Hàm gửi hình ảnh qua WebSocket
async def stream_images(websocket, path, frame_queue):
    try:
        while True:
            if not frame_queue.empty():
                frame = frame_queue.get()
                _, buffer = cv2.imencode('.jpg', frame)
                jpg_as_text = base64.b64encode(buffer).decode('utf-8')
                await websocket.send(jpg_as_text)
            await asyncio.sleep(0.1)  # Điều chỉnh tốc độ gửi (10 frame/s)
    except Exception as e:
        print(f"Lỗi WebSocket: {e}")

# Hàm chạy WebSocket server
async def start_websocket_server(frame_queue):
    async with websockets.serve(lambda ws, path: stream_images(ws, path, frame_queue), "0.0.0.0", 8765):
        await asyncio.Future()  # Chạy mãi mãi

def run_websocket(frame_queue):
    asyncio.run(start_websocket_server(frame_queue))

def send_to_firebase(label):
    retries = 3
    for attempt in range(retries):
        try:
            ref = db.reference('detect_mask')
            ref.set(label)
            return
        except Exception as e:
            print(f"Lỗi Firebase (lần {attempt + 1}/{retries}): {e}")
            if attempt < retries - 1:
                time.sleep(1)

def calculate_sharpness(image):
    """Tính độ nét của ảnh dựa trên gradient"""
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    laplacian = cv2.Laplacian(gray, cv2.CV_64F)
    sharpness = laplacian.var()
    return sharpness

def save_image(frame, label_text):
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    filename = f"{SAVE_DIR}/{label_text}_{timestamp}.jpg"
    cv2.imwrite(filename, frame)
    print(f"Ảnh đã lưu: {filename}")

def display_camera(cap, model):
    frame_queue = queue.Queue()  # Hàng đợi để truyền frame cho WebSocket

    # Chạy WebSocket trong luồng riêng
    websocket_thread = threading.Thread(target=run_websocket, args=(frame_queue,))
    websocket_thread.daemon = True
    websocket_thread.start()

    last_save_time = 0
    last_label = None
    save_interval = 2  # Giảm tần suất lưu xuống mỗi 2 giây
    min_sharpness = 80  # Ngưỡng độ nét tối thiểu
    min_confidence = 0.4  # Ngưỡng độ tin cậy tối thiểu
    
    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                print("Không thể đọc frame, thử lại sau 2 giây...")
                time.sleep(2)
                continue

            results = model(frame)
            current_time = time.time()
            sharpness = calculate_sharpness(frame)

            for result in results:
                for box in result.boxes:
                    label = int(box.cls[0].cpu().numpy())
                    conf = box.conf[0].cpu().numpy()
                    x1, y1, x2, y2 = box.xyxy[0].cpu().numpy()
                    label_text = "mask" if label == 0 else "no_mask"

                    # Kiểm tra các điều kiện để lưu ảnh
                    should_save = (
                        (label_text != last_label or current_time - last_save_time >= save_interval) and
                        conf >= min_confidence and
                        sharpness >= min_sharpness
                    )

                    if should_save:
                        face_roi = frame[int(y1):int(y2), int(x1):int(x2)]
                        if face_roi.size > 0:
                            face_sharpness = calculate_sharpness(face_roi)
                            if face_sharpness >= min_sharpness:
                                send_to_firebase(label)
                                save_image(frame, label_text)
                                last_save_time = current_time
                                last_label = label_text

                    # Vẽ hộp và nhãn
                    cv2.rectangle(frame, (int(x1), int(y1)), (int(x2), int(y2)), (0, 255, 0), 2)
                    cv2.putText(frame, f'{label_text}: {conf:.2f}', (int(x1), int(y1) - 10),
                                cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 2)

            # Hiển thị thêm thông tin độ nét
            cv2.putText(frame, f'Sharpness: {sharpness:.2f}', (10, 30),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 0, 0), 2)
            
            # Thêm frame vào hàng đợi để gửi qua WebSocket
            if frame_queue.qsize() < 10:  # Giới hạn kích thước hàng đợi
                frame_queue.put(frame.copy())

            cv2.imshow("Camera", frame)
            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
    finally:
        cap.release()
        cv2.destroyAllWindows()
        print("Đã giải phóng tài nguyên camera.")

def main():
    model_path = r"D:\CHUONGTRINHDAIHOC\IUH\Nam_4_HKII\DAKTNCAO\CODE_LAN_1\CODE_NHANDIEN\best.pt"
    if not os.path.exists(model_path):
        print(f"Không tìm thấy file mô hình tại: {model_path}")
        return

    model = YOLO(model_path)
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Không thể mở camera")
        return

    display_camera(cap, model)

if __name__ == "__main__":
    main()