import math
temperature = "500"
try:
    temperature = float(temperature)
    math.isfinite(temperature)
    if temperature < 20:
        status = "LOW"
    elif temperature > 40:
        status = "HIGH"
    else:
        status = "NORMAL"

    print (status)
    print (temperature)
except ValueError, TypeError:
    print("INVALID SENSOR DATA")