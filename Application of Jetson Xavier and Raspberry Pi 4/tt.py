import cv2
import time

cap = cv2.VideoCapture(0)  # Mở camera

fps = 5  # Số FPS mong muốn
delay = 1 / fps  # Thời gian delay giữa các frame

while cap.isOpened():
    ret, frame = cap.read()
    if not ret:
        break

    cv2.imshow("Camera", frame)
    time.sleep(delay)  # Giảm tốc độ đọc khung

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()
