import socket
import struct
import time
import multiprocessing
from saveDataMultiprocess import saveToFile
import pandas as pd
from SensorIDToNames import sensorIDToNamesDict


def unpack_simulink_message(data,system):
        # splits the data stream up in sensor ID numbers and sensor values
        sensor_dict = {}
        sensor_IDS = [data[i] for i in range(0, len(data), 5)]
        sensor_values = [data[i+1:i+5] for i in range(0, len(data), 5)]

        #Converting back into float format and packing in directionary
        for idx, ID in enumerate(sensor_IDS):
            sensor_dict[ID] = struct.unpack('f', sensor_values[idx])
        sensor_dict[f"Time{system}"]=time.time()

        #Pack into pdDaaframe, change collumnames from number to names, remove empty column
        sensor_df = pd.DataFrame(sensor_dict)
        sensor_df.rename(columns=sensorIDToNamesDict,inplace=True)
        sensor_df.drop(columns=sensor_df.columns[0],axis=1)

        return sensor_df

def GetAllDataFromSocket(givenSocket):
    UDPdata, addr = givenSocket.recvfrom(1024)
    givenSocket.settimeout(0.01)
    try:
        while True: 
            UDPdata, addr = givenSocket.recvfrom(1024)
            print("Read data while loop")
    except:
        givenSocket.settimeout(socketStandardTimeout)
    return UDPdata


if __name__ == '__main__':

    DELL_IP = "172.26.13.96"        #Control IP
    HVAC_IP = "172.26.12.106"
    WC_IP = "172.26.12.136"

    DELL_PORT = 25002
    DELL_PORT2 = 25001

    HVAC_PORT = 25000
    HVAC_PORT_TRANSMIT = 4796

    WC_PORT = 25000
    WC_PORT_TRANSMIT = 4796


    sock_HP = socket.socket(socket.AF_INET,socket.SOCK_DGRAM)  #Internet UDP
    sock_HP.bind((DELL_IP,DELL_PORT2))                         #Control PC IP, and port, data from HP, setting in simulink for HP system
    socketStandardTimeout = 1.1
    sock_HP.settimeout(socketStandardTimeout)                                    #Settime out

    sock_HVAC = socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
    sock_HVAC.bind((DELL_IP,DELL_PORT))                         #Control PC IP, and port, data from HVAC, setting in simulink for HVAC system
    sock_HVAC.settimeout(socketStandardTimeout)

    #DataSaver = saveToLogFile(2,20,40,True)
    #2,120,1800,true

    saveQueue = multiprocessing.Queue(30)
    saveToFileProcess = multiprocessing.Process(target=saveToFile,args=(2,20,7200,True,120,saveQueue,))   
    saveToFileProcess.start()


    try:
        while True: 
          
            UDPdata_HP=GetAllDataFromSocket(sock_HP)
            HP_data = unpack_simulink_message(UDPdata_HP,"HP") 

            
            UDPdata_HVAC=GetAllDataFromSocket(sock_HVAC)
            HVAC_data = unpack_simulink_message(UDPdata_HVAC,"HVAC") 

            saveQueue.put(pd.concat([HP_data, HVAC_data],axis=1))

            pd.options.display.max_columns = None
            print(HVAC_data.round(2))
            print("\n")
            print(HP_data.round(2))
            print("\n")
            
    except KeyboardInterrupt:
        pass     