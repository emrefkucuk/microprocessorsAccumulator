from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List
import mysql.connector
from mysql.connector import Error

import dbconfig # This should be the path to your dbconfig.py file


app = FastAPI()

class SensorData(BaseModel):
    timestamp: str
    temperature: float
    humidity: float
    pm25: float
    pm10: float
    co2: float
    voc: float
    latitude: Optional[float] = None
    longitude: Optional[float] = None

def insert_sensor_data(data: SensorData):
    try:
        # Establish connection
        connection = mysql.connector.connect(**dbconfig.db_config)
        cursor = connection.cursor()

        # SQL query to insert data
        insert_query = """
        INSERT INTO arduino_data (
            timestamp, temperature, humidity, pm25, pm10, co2, voc, latitude, longitude
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """

        values = (
            data.timestamp,
            data.temperature,
            data.humidity,
            data.pm25,
            data.pm10,
            data.co2,
            data.voc,
            data.latitude,
            data.longitude
        )

        cursor.execute(insert_query, values)
        connection.commit()

    except Error as e:
        print(f"Error while inserting data: {e}")
        raise HTTPException(status_code=500, detail="Database insertion failed")

    finally:
        if cursor:
            cursor.close()
        if connection.is_connected():
            connection.close()

def fetch_sensor_data():
    try:
        connection = mysql.connector.connect(**dbconfig.db_config)
        cursor = connection.cursor(dictionary=True)  # dictionary=True -> sonuçları dict olarak alıyoruz

        select_query = "SELECT * FROM sensor_data ORDER BY timestamp DESC LIMIT 180;"
        cursor.execute(select_query)
        records = cursor.fetchall()

        return records

    except Error as e:
        print(f"Error while reading data: {e}")
        raise HTTPException(status_code=500, detail="Database reading failed")

    finally:
        if cursor:
            cursor.close()
        if connection.is_connected():
            connection.close()

@app.post("/arduino-data")
async def receive_data(data: SensorData):
   
    insert_sensor_data(data)
    
    response = {
        "success": True,
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    }
    return response

@app.get("/arduino-data", response_model=List[SensorData])
async def get_data():
    records = fetch_sensor_data()
    return records
#get methods