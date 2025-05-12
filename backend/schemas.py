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
    class Config:
        from_attributes = True

class PartialSensorData(BaseModel):
    timestamp: datetime
    temperature: float
    humidity: float
    pm25: float
    pm10: float

    class Config:
        from_attributes = True

class UserSettings(BaseModel):
    notifications: bool
    format: str
    thresholds: dict

class UserSettingsCreate(BaseModel):
    notifications: bool
    format: str
    thresholds: dict


class Alert(BaseModel):
    id: int
    timestamp: datetime
    type: str
    value: float
    threshold: float
    acknowledged: Optional[bool] = False

    class Config:
        from_attributes = True

class AlertAcknowledgeRequest(BaseModel):
    alert_id: int    

class UserCreate(BaseModel):
    email: str
    password: str

class UserOut(BaseModel):
    id: int
    email: str

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str

class AIOutputBase(BaseModel):
    timestamp: datetime
    temperature: float
    humidity: float
    pm25: float
    pm10: float
    prediction: str
    class Config:
        from_attributes = True

class AIOutput(AIOutputBase):
    id: int

    class Config:
        from_attributes = True  # V2'de from_attributes olabilir, uyarı alırsan güncellersin