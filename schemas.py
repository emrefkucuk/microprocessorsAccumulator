from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class SensorData(BaseModel):
    timestamp: datetime
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
