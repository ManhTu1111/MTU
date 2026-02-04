import pygame
import math
import numpy as np
import os
import random

BLACK_COLOR = (0, 0, 0)
my_map = pygame.image.load(r".\m10x10.jpg")
map_copy = my_map.copy()

max_y_so_far = -np.inf
best_point = None
best_path = None
best_idx = -1

crash_points = []     # Danh sách điểm (x, y) robot crash
crash_points_count = {}  # Đếm số lần có robot crash ở 1 điểm (theo (x//5, y//5))
explore_threshold = 5    # 5 pixels cho vùng lân cận "tương đồng"


class Envir:
    def __init__(self, dim):
        self.black = (0, 0, 0)
        self.white = (255, 255, 255)
        self.red = (255, 0, 0)
        self.green = (0, 255, 0)
        self.blue = (0, 0, 255)
        self.height, self.width = dim
        pygame.display.set_caption("psonoron")
        self.map = pygame.display.set_mode((self.width, self.height))

    def robot_frame(self, pos, rotation):
        n = 40
        centerx, centery = pos
        x_axis = (centerx + n * math.cos(rotation), centery + n * math.sin(rotation))
        y_axis = (centerx + n * math.cos(rotation + math.pi / 2), centery + n * math.sin(rotation + math.pi / 2))
        pygame.draw.line(self.map, self.blue, pos, x_axis, 3)
        pygame.draw.line(self.map, self.green, pos, y_axis, 3)

    def robot_sensor(self, pos, points):
        for point in points:
            pygame.draw.line(self.map, self.green, pos, point, 1)
            pygame.draw.circle(self.map, self.green, point, 3)

class Robot:
    def __init__(self, startpos, img_path, width, Envir: Envir):
        self.w = width
        self.x, self.y = startpos
        self.theta = 0
        self.env = Envir
        self.vl = 0
        self.vr = 0
        self.l = 40*0.33
        self.r = 2
        self.maxSpeed = 100
        self.minSpeed = -100
        self.sensor_data = [0]
        self.crash = False
        self.points = []
        self.lastTime = pygame.time.get_ticks()
        self.img = pygame.image.load(img_path)
        self.img = pygame.transform.scale(self.img, (3*10, 3*10))
        self.rotated_img = self.img
        self.rect = self.rotated_img.get_rect(center=(self.x, self.y))
        self.time = 0
        self.crash_position = None
        self.path = [(self.x, self.y, self.theta)]
        self.is_alive = True

    def draw(self, map_surface):
        self.rotated_img = pygame.transform.rotate(self.img, -math.degrees(self.theta))
        self.rect = self.rotated_img.get_rect(center=(self.x, self.y))
        map_surface.blit(self.rotated_img, self.rect)

    def update_sensor_data(self, map_copy=map_copy):
        angles = [self.theta + i * np.pi / 4 for i in range(8)]
        edge_points, edge_distances = [], []
        for angle in angles:
            distance = 0
            while True:
                edge_x = int(self.x + distance * np.cos(angle))
                edge_y = int(self.y + distance * np.sin(angle))
                if edge_x < 0 or edge_x >= map_copy.get_width() or edge_y < 0 or edge_y >= map_copy.get_height():
                    break
                b, g, r, a = map_copy.get_at((edge_x, edge_y))
                if b < 100 and g < 100 and r < 100:
                    break
                distance += 1
            edge_points.append((edge_x, edge_y))
            edge_distances.append(distance)
        self.sensor_data = edge_distances
        self.points = edge_points

    def move(self):
        if not self.is_alive:
            return
        self.vr = min(max(self.vr, self.minSpeed), self.maxSpeed)
        self.vl = min(max(self.vl, self.minSpeed), self.maxSpeed)
        self.dataTime = (pygame.time.get_ticks() - self.lastTime) / 1000
        self.lastTime = pygame.time.get_ticks()
        self.dataTime = min(max(self.dataTime, 0.01), 0.1)
        R = np.array([
            [np.cos(self.theta), np.sin(self.theta), 0],
            [-np.sin(self.theta), np.cos(self.theta), 0],
            [0, 0, 1]
        ])
        j1f = np.array([[1, 0, -self.l], [-1, 0, -self.l]])
        j2 = np.array([[self.r, 0], [0, self.r]])
        vv = np.linalg.inv(R) @ np.linalg.pinv(j1f) @ j2 @ np.array([[self.vl], [self.vr]])
        vx, vy, omega = vv.flatten()

        steps = int(max(abs(vx), abs(vy)) * self.dataTime / 1.5) + 1
        for i in range(steps):
            x_step = self.x + (vx * self.dataTime) * (i + 1) / steps
            y_step = self.y + (vy * self.dataTime) * (i + 1) / steps
            if self.is_collision(x_step, y_step):
                self.crash = True
                self.is_alive = False
                self.crash_position = (x_step, y_step)
                return

        self.x += vx * self.dataTime
        self.y += vy * self.dataTime
        self.theta = (self.theta + omega * self.dataTime + np.pi) % (2 * np.pi) - np.pi
        self.path.append((self.x, self.y, self.theta))

    def is_collision(self, x, y):
        xi, yi = int(x), int(y)
        if 0 <= xi < map_copy.get_width() and 0 <= yi < map_copy.get_height():
            b, g, r, a = map_copy.get_at((xi, yi))
            return (b < 100 and g < 100 and r < 100)
        return True

    def check_crash(self):
        if not self.is_alive:
            return
        edge_x, edge_y = (int(self.x), int(self.y))
        if 0 <= edge_x < map_copy.get_width() and 0 <= edge_y < map_copy.get_height():
            if map_copy.get_at((edge_x, edge_y)) == BLACK_COLOR:
                self.crash = True
                self.is_alive = False
                self.crash_position = (self.x, self.y)
        else:
            self.crash = True
            self.is_alive = False
            self.crash_position = (self.x, self.y)
        if self.time > 100:
            self.crash = True
            self.is_alive = False
            self.crash_position = (self.x, self.y)

def af(x):
    return np.tanh(x)

def vd_nn(X, W1, B1, W2, B2, V, B3):
    H1_input = af(W1.T @ X + B1)
    H2_input = af(W2.T @ H1_input + B2)
    output = V.T @ H2_input + B3
    return output

def save_best_state(filename, Gbest_position, Gbest_fitness, P, Pbest_position, Pbest_fitness, **kwargs):
    np.savez(filename,
             Gbest_position=Gbest_position,
             Gbest_fitness=Gbest_fitness,
             P=P,
             Pbest_position=Pbest_position,
             Pbest_fitness=Pbest_fitness,
             **kwargs
    )
    print("Lưu trạng thái mô hình thành công.")

# ----------- Hàm thưởng/phạt crash point ----------
def crash_point_reward(crash_pos):
    # Làm tròn theo explore_threshold (5 pixel), tránh điểm lặp sát
    cell = (int(crash_pos[0])//explore_threshold, int(crash_pos[1])//explore_threshold)
    if cell in crash_points_count:
        crash_points_count[cell] += 1
        return -100   # Phạt nếu có 2 robot cùng chết tại đây
    else:
        crash_points_count[cell] = 1
        crash_points.append(crash_pos)
        return 300    # Thưởng nếu là điểm mới

def cost_function(robot, start_pos= (449,39)):
    # Thưởng theo y, crash mới thưởng nhiều, crash cũ phạt
    end_pos = robot.crash_position if robot.crash else (robot.x, robot.y)
    reward = 0
    # Thưởng xa trục y
    reward += (end_pos[1] - start_pos[1])
    # Nếu robot chết, tính thưởng/phạt vị trí crash
    if robot.crash:
        reward += crash_point_reward(end_pos)
    return -reward

# -------------- MAIN --------------

n_input = 11
h1 = 8
h2 = 6
n_output = 2

pygame.init()
my_map = my_map.copy()
map_width, map_height = my_map.get_width(), my_map.get_height()
env = Envir((1000, 1059))

running = True
clock = pygame.time.Clock()

number = 50
pop_size = number
npar = n_input * h1 + h1 + h1 * h2 + h2 + h2 * n_output + n_output
min_max = [-5, 5]
w = 0.5
c1 = 1.5
c2 = 1.0
max_iteration = 10000
start =  (449,39)
Robots = []
for i in range(number):
    Robots.append(Robot(start, r".\rb_3.png", 1, env))
iteration = 0
max_distance_so_far = 0
dt = 0
lasttime = pygame.time.get_ticks()

Pbest_fitness = np.inf * np.ones((pop_size,))
Gbest_fitness = np.inf
Pbest_position = np.zeros((pop_size, npar))
Gbest_position = np.zeros((npar,))

P = np.random.uniform(min_max[0], min_max[1], (pop_size, npar))
V = P * 0

state_filename = r".\robotdixa copy.npz"
if os.path.exists(state_filename):
    data = np.load(state_filename, allow_pickle=True)
    Gbest_position = data['Gbest_position']
    Gbest_fitness = data['Gbest_fitness']
    P = data['P']
    Pbest_fitness = data['Pbest_fitness']
    Pbest_position = data['Pbest_position']
    print("Đã tải trạng thái mô hình.")
    # Load thêm các biến sau:
    if 'best_point' in data:
        best_point = data['best_point']
    if 'max_y_so_far' in data:
        max_y_so_far = float(data['max_y_so_far'])
    if 'best_path' in data:
        best_path = data['best_path']
    if 'crash_points' in data:
        crash_points = [tuple(pt) for pt in data['crash_points']]
    if 'crash_points_count' in data:
        raw_dict = data['crash_points_count'].item() if isinstance(data['crash_points_count'], np.ndarray) else data['crash_points_count']
        crash_points_count = {
        tuple(map(int, k.strip('()').split(','))) if isinstance(k, str) else tuple(k): int(v)
        for k, v in raw_dict.items()
    }


while running and iteration < max_iteration:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

    FPS = 60
    clock.tick(FPS)

    for robot in Robots:
        robot.x, robot.y = start
        robot.theta = 0
        robot.crash = False
        robot.is_alive = True
        robot.time = 0
        robot.crash_position = None
        robot.path = [(robot.x, robot.y, robot.theta)]

    all_dead = False
    while not all_dead and running:
        for idx, robot in enumerate(Robots):
            if not robot.is_alive:
                continue
            robot.check_crash()
            robot.update_sensor_data()
            if robot.is_alive:
                nn_input = np.array([
                    robot.sensor_data[0] / 100, robot.sensor_data[1] / 100, robot.sensor_data[2] / 100,
                    robot.sensor_data[3] / 100, robot.sensor_data[4] / 100, robot.sensor_data[5] / 100,
                    robot.sensor_data[6] / 100, robot.sensor_data[7] / 100,
                    robot.x / map_width, robot.y / map_height, robot.theta / (2 * np.pi)
                ])
                vector = P[idx]
                i = 0
                W1 = vector[i:i+n_input*h1].reshape((n_input, h1)); i += n_input*h1
                B1 = vector[i:i+h1]; i += h1
                W2 = vector[i:i+h1*h2].reshape((h1, h2)); i += h1*h2
                B2 = vector[i:i+h2]; i += h2
                V1 = vector[i:i+h2*n_output].reshape((h2, n_output)); i += h2*n_output
                B3 = vector[i:i+n_output]
                out = vd_nn(nn_input, W1, B1, W2, B2, V1, B3)
                robot.vl = out[0] * 5
                robot.vr = out[1] * 5
                robot.move()
                robot.time += dt
                robot.check_crash()
                robot.draw(env.map)
                env.robot_frame((robot.x, robot.y), robot.theta)
                env.robot_sensor((robot.x, robot.y), robot.points)

        # Vẽ vạch xanh tại điểm xa nhất hiện tại
        if best_point is not None:
            pygame.draw.circle(env.map, (0,255,0), (int(best_point[0]), int(best_point[1])), 8)

        # Vẽ chấm đỏ tại tất cả điểm crash từng có
        for crash_pos in crash_points:
            pygame.draw.circle(env.map, (255,0,0), (int(crash_pos[0]), int(crash_pos[1])), 6)

        all_dead = all(not robot.is_alive for robot in Robots)
        dt = (pygame.time.get_ticks() - lasttime) / 1000
        lasttime = pygame.time.get_ticks()

        pygame.display.update()
        env.map.blit(my_map, (0, 0))

    # Cập nhật fitness khi tất cả robot chết
    for idx, robot in enumerate(Robots):
        J = cost_function(robot)
        if J < Pbest_fitness[idx]:
            Pbest_fitness[idx] = J
            Pbest_position[idx] = P[idx]
        if J < Gbest_fitness:
            Gbest_fitness = J
            Gbest_position = P[idx]

    # Tìm robot xa nhất theo y để update best_point/path
    max_y_in_iteration = -np.inf
    best_idx_in_iter = -1
    for idx, robot in enumerate(Robots):
        end_pos = robot.crash_position if robot.crash else (robot.x, robot.y)
        y_val = end_pos[1]
        if y_val > max_y_in_iteration:
            max_y_in_iteration = y_val
            best_idx_in_iter = idx

    if max_y_in_iteration > max_y_so_far:
        max_y_so_far = max_y_in_iteration
        best_idx = best_idx_in_iter
        best_robot = Robots[best_idx]
        best_point = (best_robot.x, best_robot.y, best_robot.theta)
        best_path = best_robot.path.copy()
        np.save(r".\robotdixa_y_max copy.npy", np.array(best_path, dtype=np.float32))
        # Chia sẻ Gbest cho tất cả robot
        Gbest_position = P[best_idx]
        Gbest_fitness = cost_function(best_robot)
        np.savez(r".\robotdixa copy.npy",
            Gbest_position=Gbest_position,
            Gbest_fitness=Gbest_fitness,
            P=P,
            Pbest_position=Pbest_position,
            Pbest_fitness=Pbest_fitness,
            best_point=np.array(best_point),
            max_y_so_far=max_y_so_far
        )

    gbest_indices = random.sample(range(pop_size), pop_size // 2)
    for idx in gbest_indices:
        P[idx] = Gbest_position.copy()
    V = w*V + c1*np.random.rand()*(Pbest_position - P) + c2*np.random.rand()*(Gbest_position - P)
    P = P + V

    print(f"Vòng lặp: {iteration}, chi phí: {Gbest_fitness}, {Pbest_fitness}")
    iteration += 1

    save_best_state(state_filename, Gbest_position, Gbest_fitness, P, Pbest_position, Pbest_fitness,
                best_point=best_point, max_y_so_far=max_y_so_far, best_path=best_path,
                crash_points=crash_points, crash_points_count=crash_points_count)


pygame.quit()
