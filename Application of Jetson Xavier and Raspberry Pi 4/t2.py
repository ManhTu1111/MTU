import cv2
import torch
import os
from ultralytics import YOLO

# Load YOLOv8 model
model = YOLO(r"D:\WORKSPACE\DAKTNC\best.pt")  # Thay bằng đường dẫn đến model đã huấn luyện nhận diện mask/nomask

# Khởi tạo webcam
cap = cv2.VideoCapture(0)

# Thư mục lưu ảnh
os.makedirs("dataset/mask", exist_ok=True)
os.makedirs("dataset/nomask", exist_ok=True)

frame_count = 0

while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break
    
    frame_count += 1
    
    # Dự đoán bằng YOLOv8
    results = model(frame)
    
    # Duyệt qua các đối tượng được phát hiện
    for result in results:
        for box in result.boxes:
            x1, y1, x2, y2 = map(int, box.xyxy[0])  # Lấy tọa độ hộp
            conf = box.conf[0].item()  # Lấy độ chính xác
            cls = int(box.cls[0].item())  # Lấy nhãn phân loại
            
            label = "Mask" if cls == 0 else "NoMask"
            color = (0, 255, 0) if cls == 0 else (0, 0, 255)
            
            # Vẽ viền và nhãn
            cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
            cv2.putText(frame, f"{label} {conf:.2f}", (x1, y1 - 10), 
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)
            
            # Lưu ảnh
            face_crop = frame[y1:y2, x1:x2]
            if face_crop.size > 0:
                filename = os.path.join("dataset", label.lower(), f"face_{frame_count}.jpg")
                cv2.imwrite(filename, face_crop)
    
    # Hiển thị kết quả
    cv2.imshow("Mask Detection", frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()