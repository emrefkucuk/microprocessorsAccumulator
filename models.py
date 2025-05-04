# models.py

from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy import Column, Integer, Float, DateTime

Base = declarative_base()  # <-- Bu satır çok önemli

class ArduinoData(Base):
    __tablename__ = "arduino_data"

    data_id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime)
    temperature = Column(Float)
    humidity = Column(Float)
    pm25 = Column(Float)
    pm10 = Column(Float)
    co2 = Column(Float)
    voc = Column(Float)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
