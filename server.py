from fastapi import FastAPI, HTTPException, Query
from pydantic import BaseModel
from datetime import datetime
from typing import Optional, List
import mysql.connector
from mysql.connector import Error
import dbconfig

app = FastAPI()
api_prefix = "/api"

# ========== MODELLER ==========
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

class UserSettings(BaseModel):
    notifications: bool
    format: str
    thresholds: dict

class Alert(BaseModel):
    id: int
    timestamp: str
    type: str
    value: float
    threshold: float
    acknowledged: Optional[bool] = False

# ========== YARDIMCI FONKSİYONLAR ==========

def connect_db():
    return mysql.connector.connect(**dbconfig.db_config) # dbconfig.py'den ayarları al gitignoreda var

def insert_sensor_data(data: SensorData):
    try:
        connection = connect_db()
        cursor = connection.cursor()

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
        raise HTTPException(status_code=500, detail=f"Database insertion failed: {e}")

    finally:
        cursor.close()
        connection.close()

def fetch_sensor_data(limit=180):
    cursor = None
    connection = None
    try:
        connection = connect_db()
        cursor = connection.cursor(dictionary=True)
        select_query = f"SELECT * FROM arduino_data ORDER BY timestamp DESC LIMIT {limit};"
        cursor.execute(select_query)
        records = cursor.fetchall()
        
        # timestamp değerlerini string formatına dönüştür
        for record in records:
            record['timestamp'] = record['timestamp'].isoformat()  # ISO string formatında
        return records

    except Error as e:
        raise HTTPException(status_code=500, detail=f"Database reading failed: {e}")

    finally:
        if cursor:
            cursor.close()
        if connection:
            connection.close()

# ========== ENDPOINTLER ==========

# 1. Sensör verisi kaydet (arduino kullanacak)
@app.post(f"{api_prefix}/sensors/data")
async def receive_data(data: SensorData):
    insert_sensor_data(data)
    return {
        "success": True,
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    }

# 2. Son 180 veri (geçmiş)
@app.get(f"{api_prefix}/sensors/history", response_model=List[SensorData])
async def get_data(
    start: Optional[datetime] = Query(None),
    end: Optional[datetime] = Query(None)
):
    records = fetch_sensor_data(limit=180)
    if start and end:
        records = [record for record in records if start <= datetime.fromisoformat(record['timestamp']) <= end]
    return records

# 3. Son veri (current)
@app.get(f"{api_prefix}/sensors/current", response_model=SensorData)
async def get_current_data():
    records = fetch_sensor_data(limit=1)
    if not records:
        raise HTTPException(status_code=404, detail="No sensor data found")
    return records[0]

# 4. İstatistik hesapla
@app.get(f"{api_prefix}/stats")
async def get_stats(
    metric: str,
    start: datetime,
    end: datetime
):
    if metric not in ["temperature", "humidity", "pm25", "pm10", "co2", "voc"]:
        raise HTTPException(status_code=400, detail="Invalid metric")

    try:
        connection = connect_db()
        cursor = connection.cursor()

        query = f"""
        SELECT MIN({metric}), MAX({metric}), AVG({metric}),
        STDDEV({metric}) FROM arduino_data
        WHERE timestamp BETWEEN %s AND %s;
        """
        cursor.execute(query, (start, end))
        stats = cursor.fetchone()

        return {
            "metric": metric,
            "min": stats[0],
            "max": stats[1],
            "avg": stats[2],
            "stddev": stats[3]
        }

    except Error as e:
        raise HTTPException(status_code=500, detail=f"Statistics query failed: {e}")

    finally:
        cursor.close()
        connection.close()

# 5. Ayarları oku (sabit veri döndürülüyor)
@app.get(f"{api_prefix}/settings", response_model=UserSettings)
async def get_settings():
    settings = UserSettings(
        notifications=True,
        format="metric",
        thresholds={"co2": 1000, "pm25": 35, "pm10": 50, "voc": 500}
    )
    return settings

# 6. Ayarları güncelle (şimdilik sabit veri döndürüyor)
@app.post(f"{api_prefix}/settings")
async def update_settings(settings: UserSettings):
    return {"message": "Settings updated", "settings": settings}

# 7. Alarm verileri (dummy)
@app.get(f"{api_prefix}/alerts/recent", response_model=List[Alert])
async def get_recent_alerts():
    alerts = [
        Alert(id=1, timestamp=datetime.now().isoformat(), type="co2", value=1200, threshold=1000, acknowledged=False),
        Alert(id=2, timestamp=datetime.now().isoformat(), type="pm25", value=50, threshold=35, acknowledged=False),
    ]
    return alerts



