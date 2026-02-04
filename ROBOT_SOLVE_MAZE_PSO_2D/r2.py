import pygame
import numpy as np
import math

# ====== CẤU HÌNH ======
MAP_PATH = r"D:\WORKSPACE\ROBOT_29_04\m10x10.jpg"
ROBOT_IMG_PATH = r"D:\WORKSPACE\ROBOT_29_04\rb_3.png"
NPZ_PATH = r"D:\WORKSPACE\ROBOT_29_04\robotdixa copy.npz"
PIXEL_PER_CM = 3
SENSOR_RANGE = 1000

# ====== HÀM KIỂM TRA ĐIỂM CÓ LÀ TƯỜNG ======
def is_wall(x, y, map_img):
    if 0 <= x < map_img.get_width() and 0 <= y < map_img.get_height():
        b, g, r, *_ = map_img.get_at((x, y))
        return b < 100 and g < 100 and r < 100
    return True

# ====== CLASS ROBOT TÁI HIỆN ======
class ReplayRobot:
    def __init__(self, path, img_path, map_img):
        self.path = path
        self.index = 0
        self.done = False
        self.map_img = map_img
        self.img = pygame.image.load(img_path)
        self.img = pygame.transform.scale(self.img, (int(PIXEL_PER_CM * 10), int(PIXEL_PER_CM * 10)))  # 10cm robot

    def update(self):
        if self.index < len(self.path):
            x, y, theta = self.path[self.index]
            self.index += 1
            return x, y, theta
        else:
            self.done = True
            return None, None, None

    def draw(self, screen, x, y, theta):
        # Robot image
        rotated = pygame.transform.rotate(self.img, -math.degrees(theta))
        rect = rotated.get_rect(center=(x, y))
        screen.blit(rotated, rect)

        # Vẽ trục robot như trong file huấn luyện
        n = 40  # chiều dài trục như ban đầu
        centerx, centery = x, y
        x_axis = (centerx + n * math.cos(theta), centery + n * math.sin(theta))
        y_axis = (centerx + n * math.cos(theta + math.pi / 2), centery + n * math.sin(theta + math.pi / 2))
        pygame.draw.line(screen, (0, 0, 255), (centerx, centery), x_axis, 5)  # Trục X - xanh dương
        pygame.draw.line(screen, (0, 255, 0), (centerx, centery), y_axis, 5)  # Trục Y - xanh lá


        # Vẽ 8 cảm biến (màu xanh lục, bám tường)
        for i in range(8):
            angle = theta + i * math.pi / 4
            for dist in range(0, SENSOR_RANGE, 5):
                sx = int(x + dist * math.cos(angle))
                sy = int(y + dist * math.sin(angle))
                if is_wall(sx, sy, self.map_img):
                    pygame.draw.line(screen, (0, 255, 0), (x, y), (sx, sy), 2)
                    pygame.draw.circle(screen, (0, 255, 0), (sx, sy), 3)
                    break

# ====== KHỞI TẠO PYGAME ======
pygame.init()
pygame.font.init()
map_img = pygame.image.load(MAP_PATH)
screen = pygame.display.set_mode((map_img.get_width(), map_img.get_height()))
pygame.display.set_caption("Replay Robot Tốt Nhất từ .npz - FINAL")
clock = pygame.time.Clock()

# ====== LOAD DỮ LIỆU TỪ .NPZ ======
data = np.load(NPZ_PATH, allow_pickle=True)
if "best_path" not in data or "Gbest_position" not in data:
    raise Exception("File .npz thiếu best_path hoặc Gbest_position")

best_path = data["best_path"]
Gbest_position = data["Gbest_position"]

# THÊM: in giá trị hàm mục tiêu
if "Gbest_fitness" in data:
    Gbest_fitness = data["Gbest_fitness"]
    print(f" Gbest_fitness (Chi phí nhỏ nhất): {Gbest_fitness:.2f}")
# ====== IN TRỌNG SỐ MẠNG NƠ-RON ======
print("========= Gbest_position (Trọng số mạng nơ-ron) =========")
print(f"Số lượng biến: {len(Gbest_position)}")
np.set_printoptions(precision=4, suppress=True, linewidth=150)
print(Gbest_position)

# ====== KHỞI TẠO ROBOT ======
robot = ReplayRobot(best_path, ROBOT_IMG_PATH, map_img)

# ====== VÒNG LẶP PYGAME ======
running = True
while running:
    clock.tick(30)
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

    screen.blit(map_img, (0, 0))
    x, y, theta = robot.update()

    if not robot.done:
        robot.draw(screen, x, y, theta)

    pygame.display.update()

pygame.quit()
