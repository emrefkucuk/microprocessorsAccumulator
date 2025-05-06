# models.py
import datetime
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey, String, JSON
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship

Base = declarative_base()  # SQLAlchemy'nin model taban sınıfı

class ArduinoData(Base):
    __tablename__ = 'arduino_data'

    data_id = Column(Integer, primary_key=True, index=True)  # Benzersiz ID
    timestamp = Column(DateTime, nullable=False)  # Zaman damgası
    temperature = Column(Float, nullable=False)  # Sıcaklık verisi
    humidity = Column(Float, nullable=False)  # Nem verisi
    pm25 = Column(Float, nullable=False)  # PM2.5
    pm10 = Column(Float, nullable=False)  # PM10
    co2 = Column(Float, nullable=False)  # CO2
    voc = Column(Float, nullable=False)  # VOC (Volatil Organik Bileşikler)
    # latitude = Column(Float, nullable=True)  # Enlem (isteğe bağlı)
    # longitude = Column(Float, nullable=True)  # Boylam (isteğe bağlı)

class User(Base):
    __tablename__ = 'users'

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(60), unique=True, index=True)
    hashed_password = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True)

    settings = relationship("UserSettings", back_populates="user", uselist=False)
    alerts = relationship("Alert", back_populates="user")
    
class UserSettings(Base):
    __tablename__ = 'user_settings'

    id = Column(Integer, primary_key=True, index=True)  # Benzersiz ID
    notifications = Column(Integer, nullable=False)  # Bildirim ayarı (1 = True, 0 = False)
    format = Column(String(50), nullable=False)  # UserSettings

    thresholds = Column(JSON, nullable=False)  # Eşik değerleri (JSON formatında)
    
    # Kullanıcıya ait ayarları bağlayacak foreign key
    user_id = Column(Integer, ForeignKey('users.id'))

    # Kullanıcı ile ilişki kurmak
    user = relationship("User", back_populates="settings")

class Alert(Base):
    __tablename__ = 'alerts'

    id = Column(Integer, primary_key=True, index=True)  # Benzersiz ID
    timestamp = Column(DateTime)  # Alarm zamanı
    type = Column(String(50), nullable=False)    # Alert
    value = Column(Float, nullable=False)  # Alarm değeri
    threshold = Column(Float, nullable=False)  # Alarmın eşik değeri
    acknowledged = Column(Boolean, default=False)  # Alarmın onaylanıp onaylanmadığı

    # Kullanıcıya ait alarmı bağlayacak foreign key
    user_id = Column(Integer, ForeignKey('users.id'))

    # Kullanıcı ile ilişki kurmak
    user = relationship("User", back_populates="alerts")