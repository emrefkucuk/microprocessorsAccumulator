from fastapi import FastAPI, Request
from pydantic import BaseModel
from datetime import datetime
from typing import Optional
import mysql.connector
from mysql.connector import Error


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

@app.post("/arduino-data")
async def receive_data(data: SensorData):
    
   




    response = {
        "success": True,
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    }
    return response
