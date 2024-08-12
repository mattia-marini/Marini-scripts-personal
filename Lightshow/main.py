import serial.tools.list_ports
import re
import serial
import time

def list_serial_ports():
    ports = serial.tools.list_ports.comports()
    for port in ports:
        print(f"Port: {port.device}, Description: {port.description}, HWID: {port.hwid}")

def get_arduino_port():
    ports = serial.tools.list_ports.comports()
    for port in ports:
        pattern = re.compile(r'Arduino', re.IGNORECASE)
        if pattern.search(port.description):
            return port.device


print(f'Connecting on port {get_arduino_port()}', end = "")
ser = serial.Serial(get_arduino_port(), 9600)

for i in range(4):
    print(".", end="", flush=True)
    time.sleep(0.5)

print()

usr_in = ""
pattern = re.compile(r"{\d+,[01]}")
while usr_in != '-1':
    usr_in = input("Valore a cui settare il led (-1 per uscire): ")
    
    if usr_in == "-1": 
        break;
    elif pattern.search(usr_in):
        ser.write(usr_in.encode())
    else: 
        print("Input non valido")


