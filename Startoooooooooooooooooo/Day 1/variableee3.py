import math
sensors = [35.5,40.1,"Error","nan"]
valid_sensor = []
for i, sensor in enumerate(sensors, start=1):
    try:
        value = float(sensor)
        if math.isfinite(value):
            valid_sensor.append(value)
        else:
            print(f"Sensor {i} Invalid Data")   
    except ValueError:
        print(f"Sensor {i} Error")

if valid_sensor:
    max_temp = max(valid_sensor)
    if max_temp < 20:
        print("LOW")
    elif max_temp > 40:
        print("HIGH")
    else:
        print("NORMAL")
else:
    print("Invalid data sensor")



