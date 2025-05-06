from fastapi import FastAPI, HTTPException, Depends, Query
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Optional
from datetime import datetime

import auth
from database import SessionLocal, engine
import models, schemas

models.Base.metadata.create_all(bind=engine)

app = FastAPI()

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

api_prefix = "/api"

# ENDPOINTS

@app.post(f"{api_prefix}/sensors/data")
async def receive_data(data: schemas.SensorData, db: Session = Depends(get_db)):
    new_data = models.ArduinoData(**data.dict())
    db.add(new_data)
    db.commit()
    return {"success": True, "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")}

# @app.get(f"{api_prefix}/sensors/history", response_model=List[schemas.SensorData])
# async def get_data(
#     start: Optional[datetime] = Query(None),
#     end: Optional[datetime] = Query(None),
#     db: Session = Depends(get_db)
# ):
#     query = db.query(models.ArduinoData).order_by(models.ArduinoData.timestamp.desc()).limit(180)
#     if start and end:
#         query = query.filter(models.ArduinoData.timestamp.between(start, end))
#     records = query.all()
#     return records
@app.get(f"{api_prefix}/sensors/history", response_model=List[schemas.SensorData])
async def get_data(
    start: Optional[datetime] = Query(None),
    end: Optional[datetime] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(models.ArduinoData).order_by(models.ArduinoData.timestamp.desc())

    if start and end:
        query = query.filter(models.ArduinoData.timestamp.between(start, end))

    query = query.limit(180)
    records = query.all()
    return records




@app.get(f"{api_prefix}/sensors/summary", response_model=List[schemas.PartialSensorData])
def get_sensor_summary(
    start_time: Optional[datetime] = Query(None),
    end_time: Optional[datetime] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(
        models.ArduinoData.timestamp,
        models.ArduinoData.temperature,
        models.ArduinoData.humidity,
        models.ArduinoData.pm25,
        models.ArduinoData.pm10
    )

    # if start_time:
    #     query = query.filter(models.ArduinoData.timestamp >= start_time)
    # if end_time:
    #     query = query.filter(models.ArduinoData.timestamp <= end_time)
    if start_time and end_time:
        query = query.filter(models.ArduinoData.timestamp.between(start_time, end_time))

    data = query.order_by(models.ArduinoData.timestamp.desc())
    return data

@app.get(f"{api_prefix}/sensors/current", response_model=schemas.SensorData)
async def get_current_data(db: Session = Depends(get_db)):
    record = db.query(models.ArduinoData).order_by(models.ArduinoData.timestamp.desc()).first()
    if not record:
        raise HTTPException(status_code=404, detail="No sensor data found")
    return record

@app.get(f"{api_prefix}/stats")
async def get_stats(metric: str, start: datetime, end: datetime, db: Session = Depends(get_db)):
    if metric not in ["temperature", "humidity", "pm25", "pm10", "co2", "voc"]:
        raise HTTPException(status_code=400, detail="Invalid metric")
    
    from sqlalchemy import func

    result = db.query(
        func.min(getattr(models.ArduinoData, metric)),
        func.max(getattr(models.ArduinoData, metric)),
        func.avg(getattr(models.ArduinoData, metric)),
        func.stddev_pop(getattr(models.ArduinoData, metric))
    ).filter(models.ArduinoData.timestamp.between(start, end)).one()

    return {
        "metric": metric,
        "min": result[0],
        "max": result[1],
        "avg": result[2],
        "stddev": result[3]
    }

# GET: Kullanıcının kendi ayarlarını getir
@app.get(f"{api_prefix}/settings", response_model=schemas.UserSettings)
def get_user_settings(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    settings = db.query(models.UserSettings).filter(models.UserSettings.user_id == current_user.id).first()
    if not settings:
        # Kullanıcının hiç ayarı yoksa varsayılan oluştur
        settings = models.UserSettings(
            user_id=current_user.id,
            notifications=True,
            format="metric",
            thresholds={"co2": 1000, "pm25": 35, "pm10": 50, "voc": 500}
        )
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings



# POST: Kullanıcının kendi ayarlarını güncelle
@app.post(f"{api_prefix}/settings", response_model=schemas.UserSettings)
def update_user_settings(
    updated_settings: schemas.UserSettingsCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    settings = db.query(models.UserSettings).filter(models.UserSettings.user_id == current_user.id).first()
    if not settings:
        settings = models.UserSettings(user_id=current_user.id, **updated_settings.dict())
        db.add(settings)
    else:
        for key, value in updated_settings.dict().items():
            setattr(settings, key, value)
    db.commit()
    db.refresh(settings)
    return settings

@app.get(f"{api_prefix}/alerts/recent", response_model=List[schemas.Alert])
async def get_recent_alerts():
    return [
        schemas.Alert(id=1, timestamp=datetime.now().isoformat(), type="co2", value=1200, threshold=1000),
        schemas.Alert(id=2, timestamp=datetime.now().isoformat(), type="pm25", value=50, threshold=35),
    ]

#USER AUTHENTICATION
@app.post("/auth/register", response_model=schemas.UserOut)
def register(user: schemas.UserCreate, db: Session = Depends(get_db)):
    existing_user = auth.get_user_by_email(db, user.email)
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    hashed_pw = auth.get_password_hash(user.password)
    db_user = models.User(email=user.email, hashed_password=hashed_pw)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@app.post("/auth/login", response_model=schemas.Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = auth.authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(status_code=401, detail="Incorrect email or password")

    access_token = auth.create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/auth/me", response_model=schemas.UserOut)
def read_users_me(current_user: models.User = Depends(auth.get_current_user)):
    return current_user