from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from models import Base
db_config = {
    "host": "localhost",        # e.g., "localhost"
    "user": "root",
    "password": "",
    "database": "accumulator",
    "port": 3306               # Optional, default is 3306
}


# Örnek bağlantı dizesi, `.env` veya config dosyasından alınmalı
DATABASE_URL = "mysql+mysqlconnector://root:@localhost/accumulator"

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
def create_database_tables():
    Base.metadata.create_all(bind=engine)
