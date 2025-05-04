from fastapi import FastAPI, HTTPException, Depends, Query
from sqlalchemy.orm import Session
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Optional
from datetime import datetime

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

@app.get(f"{api_prefix}/sensors/history", response_model=List[schemas.SensorData])
async def get_data(
    start: Optional[datetime] = Query(None),
    end: Optional[datetime] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(models.ArduinoData).order_by(models.ArduinoData.timestamp.desc()).limit(180)
    if start and end:
        query = query.filter(models.ArduinoData.timestamp.between(start, end))
    records = query.all()
    return records

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

@app.get(f"{api_prefix}/settings", response_model=schemas.UserSettings)
async def get_settings():
    return schemas.UserSettings(
        notifications=True,
        format="metric",
        thresholds={"co2": 1000, "pm25": 35, "pm10": 50, "voc": 500}
    )

@app.post(f"{api_prefix}/settings")
async def update_settings(settings: schemas.UserSettings):
    return {"message": "Settings updated", "settings": settings}

@app.get(f"{api_prefix}/alerts/recent", response_model=List[schemas.Alert])
async def get_recent_alerts():
    return [
        schemas.Alert(id=1, timestamp=datetime.now().isoformat(), type="co2", value=1200, threshold=1000),
        schemas.Alert(id=2, timestamp=datetime.now().isoformat(), type="pm25", value=50, threshold=35),
    ]
