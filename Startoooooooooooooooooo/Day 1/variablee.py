temperature = "1"
try:
    temperature = float(temperature)
    if temperature < 20:
        status = "LOW"
    elif temperature > 40:
        status = "HIGH"
    else:
        status = "NORMAL"

    print (status)
except:
    print("INVALID SENSOR DATA")