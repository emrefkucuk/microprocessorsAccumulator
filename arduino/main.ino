#include <Adafruit_GFX.h>
#include <Adafruit_ILI9341.h>
#include <DHT.h>
#include <TinyGPS++.h>
#include <SPI.h>
#include <SD.h>
#include <Wire.h>
#include <RTClib.h>
#include "ccs811.h"  // CCS811 kütüphanesi değiştirildi

RTC_DS3231 rtc;
CCS811 ccs811; // CCS811 sensörü için nesne tanımı güncellendi

// DHT11 Ayarları
#define DHTPIN 6
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

// LED pinleri
const int led1 = 5;
const int led2 = 10;
const int led3 = 11;

// Buzzer pini
const int buzzer = 4;

// ESP8266 için donanımsal Serial2 kullanımı
// ESP bağlantıları: 
// ESP8266 RX -> Arduino TX2 (pin 16)
// ESP8266 TX -> Arduino RX2 (pin 17)
#define ESP8266_SERIAL Serial2

// GPS için donanımsal Serial3
TinyGPSPlus gps;

// PMS5003 için SET pini
const int pmsSetPin = 7;
#define PMS Serial1

// TFT ekran pinleri
#define TFT_CS   53
#define TFT_DC   48
#define TFT_RST  49
Adafruit_ILI9341 tft(TFT_CS, TFT_DC, TFT_RST);

// SD kart için CS pini
#define SD_CS 47

// PMS5003 verisi - başlangıçta null (-1) olarak ayarlandı
int pm25 = -1;
int pm10 = -1;

// SD Kart bileşenleri
Sd2Card card;
SdVolume volume;
SdFile root;

// WiFi Ayarları
const char* ssid = "ERDEMLER ERKEK YURDU";
const char* password = "Yurt--2017";

// Veri geçmişi için değişkenler - son 100 ölçümü saklayacak
#define MAX_DATA_POINTS 100
float tempHistory[MAX_DATA_POINTS];
float humHistory[MAX_DATA_POINTS];
int pm25History[MAX_DATA_POINTS];
int pm10History[MAX_DATA_POINTS];
int co2History[MAX_DATA_POINTS]; // CO2 değerleri için geçmiş veriler
int vocHistory[MAX_DATA_POINTS]; // VOC değerleri için geçmiş veriler

// Geçmiş veri sayacı
int dataCount = 0;
// Sensör verileri toplanma süresi (ms)
unsigned long dataPeriod = 10000; // 10 saniye
// Son veri toplama zamanı
unsigned long lastDataTime = 0;

// Ekran gösterme modları
#define DISPLAY_CURRENT 0
#define DISPLAY_TEMP_GRAPH 1
#define DISPLAY_HUM_GRAPH 2  
#define DISPLAY_PM25_GRAPH 3
#define DISPLAY_PM10_GRAPH 4
#define DISPLAY_CO2_GRAPH 5   // CO2 grafiği için yeni mod
#define DISPLAY_VOC_GRAPH 6   // VOC grafiği için yeni mod
#define DISPLAY_IP_LOCATION 7 // IP tabanlı konum bilgisi için yeni mod
#define DISPLAY_ALERTS 8      // Uyarı durumlarını gösteren ekran modu
int currentDisplayMode = DISPLAY_CURRENT;

// Mod değişimi için zamanlama
unsigned long lastModeChangeTime = 0;
unsigned long modeChangePeriod = 5000; // 5 saniye

// HTTP POST zamanlaması
unsigned long lastPostTime = 0;
unsigned long postPeriod = 10000; // 10 saniye

// Ekran modu değişim kontrolü için flag
bool displayNeedsUpdate = true;

// Sensör değerleri için güvenli aralık tanımları
// Güvenlik seviyesi enum tanımı
#define LEVEL_SAFE 0
#define LEVEL_ATTENTION 1
#define LEVEL_DANGEROUS 2

// Sensör durum kontrolü zamanlaması
unsigned long lastLedUpdateTime = 0;
unsigned long ledUpdatePeriod = 2000;  // 2 saniyede bir LED ve buzzer durumunu kontrol et

// Buzzer için zamanlama değişkenleri
unsigned long buzzerStartTime = 0;
bool buzzerActive = false;
int currentBeepCount = 0;
int maxBeepCount = 0;
int beepRepeatCount = 0;
int currentBeepSensor = -1; // Hangi sensörün sesinin çaldığını takip et (-1: hiçbiri)

// PM2.5 (ince partikül maddeler, 2.5 mikron altı) aralıkları
float PM25_SAFE_MAX = 12.0;
float PM25_ATTENTION_MAX = 35.4;
float PM25_VERY_DANGEROUS = 55.5; // Çok tehlikeli eşik değeri

// PM10 (partikül maddeler, 10 mikron altı) aralıkları
float PM10_SAFE_MAX = 50.0;
float PM10_ATTENTION_MAX = 150.0;
float PM10_VERY_DANGEROUS = 250.0; // Çok tehlikeli eşik değeri

// CO2 (Karbon dioksit) aralıkları - ppm
float CO2_SAFE_MAX = 800.0;
float CO2_ATTENTION_MAX = 1200.0;  
float CO2_VERY_DANGEROUS = 5000.0; // Uzun süreli maruz kalmada ciddi sağlık riski

// VOC (Uçucu Organik Bileşikler) aralıkları - ppb
float VOC_SAFE_MAX = 220.0;
float VOC_ATTENTION_MAX = 660.0;
float VOC_VERY_DANGEROUS = 1000.0; // Baş ağrısı, baş dönmesi riski

// Sıcaklık (İç ortam için ideal) aralıkları
float TEMP_SAFE_MIN = 20.0;
float TEMP_SAFE_MAX = 24.0;
float TEMP_ATTENTION_MIN = 18.0;
float TEMP_ATTENTION_MAX = 28.0;
float TEMP_DANGEROUS_MIN = 16.0; // Hipotermi riski
float TEMP_DANGEROUS_MAX = 35.0; // Isı stresi riski

// Nem (Bağıl Nem) aralıkları
float HUM_SAFE_MIN = 30.0;
float HUM_SAFE_MAX = 50.0;
float HUM_ATTENTION_MIN = 20.0;
float HUM_ATTENTION_MAX = 60.0;

// Sensör değerini kontrol edip güvenlik seviyesini döndüren fonksiyon
int checkSensorLevel(float value, float safeMin, float safeMax, float attentionMin, float attentionMax) {
  if (value >= safeMin && value <= safeMax) {
    return LEVEL_SAFE;
  } else if (value >= attentionMin && value <= attentionMax) {
    return LEVEL_ATTENTION;
  } else {
    return LEVEL_DANGEROUS;
  }
}

// Ekran yönetimi için değişkenler
int currentLine = 0;
const int maxDisplayLines = 14; // ILI9341 için uygun satır sayısı
String statusMessages[maxDisplayLines]; // Durum mesajlarını saklamak için
bool clearScreenNeeded = false;

// Durum mesajlarını eklemek için fonksiyon - ekran yönetimini otomatik yapar
void printStatusMessage(String message) {
  Serial.println(message); // Serial monitöre yazdır
  
  // TFT ekranı etkin olduğundan emin ol
  digitalWrite(SD_CS, HIGH);
  digitalWrite(TFT_CS, LOW);

  // Ekranın ilk kurulumunda
  if (currentLine == 0 && statusMessages[0] == "") {
    tft.fillScreen(ILI9341_BLACK);
    tft.setTextColor(ILI9341_WHITE);
    tft.setTextSize(2);
    tft.setCursor(0, 0);
  }

  // Ekran doldu mu kontrol et
  if (currentLine >= maxDisplayLines) {
    // Ekranı temizle ve "Sayfa 2" gibi bir mesaj göster
    tft.fillScreen(ILI9341_BLACK);
    tft.setCursor(0, 0);
    tft.setTextColor(ILI9341_CYAN);
    tft.print("Devam... Sayfa ");
    tft.print((currentLine / maxDisplayLines) + 1);
    tft.setTextColor(ILI9341_WHITE);
    tft.setCursor(0, 20); // Bir satır aşağı geç
    
    // Satır sayacını sıfırla, ama toplam satır sayısını takip et
    currentLine = 1; // İlk satır sayfa başlığı olduğu için 1'den başlat
    
    // Buffer'ı temizle
    for (int i = 0; i < maxDisplayLines; i++) {
      statusMessages[i] = "";
    }
  }
  
  // Mesajı buffer'a ve ekrana ekle
  statusMessages[currentLine % maxDisplayLines] = message;
  tft.println(message);
  currentLine++;
}

void setup() {
  Serial.begin(9600);
  ESP8266_SERIAL.begin(115200);
  Serial3.begin(9600);
  PMS.begin(9600);

  pinMode(pmsSetPin, OUTPUT);
  digitalWrite(pmsSetPin, HIGH);

  pinMode(led1, OUTPUT);
  pinMode(led2, OUTPUT);
  pinMode(led3, OUTPUT);
  pinMode(buzzer, OUTPUT);

  dht.begin();

  pinMode(9, OUTPUT); // Arka ışık
  analogWrite(9, 255);

  // SPI başlatma - önce SPI'yi başlatalım
  SPI.begin();
  
  // SD kart ve TFT için pinleri ayarla
  pinMode(SD_CS, OUTPUT);
  pinMode(TFT_CS, OUTPUT);
  digitalWrite(SD_CS, HIGH);  // SD kartı başlangıçta devre dışı bırak
  digitalWrite(TFT_CS, HIGH); // TFT'yi başlangıçta devre dışı bırak

  // TFT ekranı başlat
  digitalWrite(TFT_CS, LOW);  // TFT'yi etkinleştir
  tft.begin();
  tft.setRotation(0);
  tft.fillScreen(ILI9341_BLACK);
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(2);
  printStatusMessage("Sistem Baslatiliyor...");
  delay(2000);
  
  // SD Kart Başlat - En fazla 5 kez deneme yapacak şekilde güncellendi
  printStatusMessage("SD Kart Baslatiliyor...");
  
  int sdRetryCount = 0;
  const int maxSdRetry = 3;
  bool sdInitSuccess = false;
  
  while (sdRetryCount <= maxSdRetry && !sdInitSuccess) {
    digitalWrite(TFT_CS, HIGH); // TFT'yi devre dışı bırak
    digitalWrite(SD_CS, LOW);   // SD kartı etkinleştir
    
    if (sdRetryCount > 0) {
      Serial.print("SD Kart Deneme #");
      Serial.println(sdRetryCount + 1);
      printStatusMessage("SD Kart Deneme #" + String(sdRetryCount + 1));
      delay(1000);
    }
    
    if (!card.init(SPI_HALF_SPEED, SD_CS)) {
      Serial.println("SD Kart: Basarisiz (card.init)!");
      printStatusMessage("SD Kart: Basarisiz!");
    } else if (!volume.init(card)) {
      Serial.println("SD Kart: FAT16/32 bulunamadi!");
      printStatusMessage("SD Kart: Format hatasi!");
    } else {
      Serial.println("SD Kart: Basarili.");
      printStatusMessage("SD Kart: Basarili.");
      
      // SD.begin() ile SD kütüphanesini başlat - bu SD.open() için gerekli
      if (!SD.begin(SD_CS)) {
        Serial.println("SD.begin() başarısız!");
        printStatusMessage("SD.begin() basarisiz!");
      } else {
        Serial.println("SD.begin() başarılı");
        printStatusMessage("SD.begin() basarili!");
        sdInitSuccess = true; // Başarılı olduğunu işaretle
      }
    }
    
    if (!sdInitSuccess) {
      sdRetryCount++;
      if (sdRetryCount <= maxSdRetry) {
        delay(2000); // Her yeniden deneme arasında 2 saniye bekle
      }
    }
  }
  
  digitalWrite(SD_CS, HIGH);  // SD kartı devre dışı bırak
  digitalWrite(TFT_CS, LOW);  // TFT'yi tekrar etkinleştir

  // RTC başlat
  if (!rtc.begin()) {
    Serial.println("RTC baglanamadi!");
    printStatusMessage("RTC: Baglanamadi!");
  } else {
    Serial.println("RTC baglandi.");
    printStatusMessage("RTC: Baglandi.");
  }

  if (rtc.lostPower()) {
    rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
    printStatusMessage("RTC: Zaman ayarlandi.");
  }

  // CCS811 sensörünü başlat
  printStatusMessage("CCS811 baslatiliyor...");
  
  // I2C başlatma - önceki Wire.begin() çağrısı kullanılıyor
  ccs811.set_i2cdelay(50); // ESP8266 benzeri cihazlar için delay ayarı
  
  if(!ccs811.begin()){
    Serial.println("CCS811 baglanti hatasi!");
    printStatusMessage("CCS811: Baglanamadi!");
  } else {
    // Sensör versiyonlarını yazdır
    Serial.print("CCS811 hardware version: "); 
    Serial.println(ccs811.hardware_version(), HEX);
    Serial.print("CCS811 bootloader version: "); 
    Serial.println(ccs811.bootloader_version(), HEX);
    Serial.print("CCS811 application version: "); 
    Serial.println(ccs811.application_version(), HEX);
    
    // Sensörü ölçüm modunda başlat
    bool ok = ccs811.start(CCS811_MODE_1SEC);
    if(!ok) {
      Serial.println("CCS811 start hatasi!");
      printStatusMessage("CCS811: Baslatma hatasi!");
    } else {
      Serial.println("CCS811 baglandi ve baslatildi.");
      printStatusMessage("CCS811: Baglandi.");
    }
  }

  // Sensör Kalibrasyonu (Varsa)
  printStatusMessage("Kalibrasyon yapiliyor...");
  delay(2000);
  printStatusMessage("Kalibrasyon tamamlandi.");

  // ESP8266 WiFi Bağlantısı - ilk başlangıçta bağlan
  printStatusMessage("ESP8266 baslaniyor...");
  
  // WiFi bağlantısı
  connectToWiFi();
  
  printStatusMessage("Sistem hazir.");
  delay(2000);
}

void loop() {
  unsigned long currentTime = millis();
  bool needToSendData = false;
  
  // Her 10 saniyede bir sensör verilerini topla
  if (currentTime - lastDataTime >= dataPeriod || lastDataTime == 0) {
    lastDataTime = currentTime;
    
    // Sensör değerlerini oku
    float temp = dht.readTemperature();
    float hum = dht.readHumidity();
    
    // GPS bilgilerini güncelle
    while (Serial3.available()) {
      gps.encode(Serial3.read());
    }
    
    // PMS5003 verileri
    if (!readPMS5003Data()) {
      pm25 = -1;
      pm10 = -1;
    }
    
    // CCS811 verilerini oku
    int co2Value = -1;
    int vocValue = -1;
    
    // CCS811 sensöründen veri okuma (yeni kütüphane)
    uint16_t eco2, etvoc, errstat, raw;
    ccs811.read(&eco2, &etvoc, &errstat, &raw);
    
    if(errstat == CCS811_ERRSTAT_OK) {
      co2Value = eco2;
      vocValue = etvoc;
      Serial.print("CO2: ");
      Serial.print(co2Value);
      Serial.print("ppm, TVOC: ");
      Serial.print(vocValue);
      Serial.println("ppb");
    } else if(errstat == CCS811_ERRSTAT_OK_NODATA) {
      Serial.println("CCS811: Yeni veri bekliyor...");
    } else if(errstat & CCS811_ERRSTAT_I2CFAIL) {
      Serial.println("CCS811: I2C hatasi!");
    } else {
      Serial.print("CCS811 hata kodu: "); 
      Serial.print(errstat, HEX); 
      Serial.print(" - "); 
      Serial.println(ccs811.errstat_str(errstat));
    }
    
    // Zaman bilgisini oku
    DateTime now = rtc.now();
    
    // Yeni verileri geçmiş veri dizilerine ekle
    storeNewData(temp, hum, pm25, pm10, co2Value, vocValue);
      // JSON veriyi oluştur - yeni format
    String jsonData = "{";
    // ISO 8601 formatında timestamp oluştur (YYYY-MM-DDThh:mm:ss.sssZ)
    char formattedMonth[3];
    char formattedDay[3]; 
    char formattedHour[3];
    char formattedMinute[3];
    char formattedSecond[3];
    
    sprintf(formattedMonth, "%02d", now.month());
    sprintf(formattedDay, "%02d", now.day());
    sprintf(formattedHour, "%02d", now.hour());
    sprintf(formattedMinute, "%02d", now.minute());
    sprintf(formattedSecond, "%02d", now.second());
    
    jsonData += "\"timestamp\":\"" + String(now.year()) + "-" + String(formattedMonth) + "-" + String(formattedDay) + "T" +
                String(formattedHour) + ":" + String(formattedMinute) + ":" + String(formattedSecond) + ".000Z\",";
    
    jsonData += "\"temperature\":" + String(temp) + ",";
    jsonData += "\"humidity\":" + String(hum) + ",";
    
    // PM2.5 ve PM10 için null kontrolü
    if (pm25 == -1) {
      jsonData += "\"pm25\":null,";
    } else {
      jsonData += "\"pm25\":" + String(pm25) + ",";
    }
    
    if (pm10 == -1) {
      jsonData += "\"pm10\":null,";
    } else {
      jsonData += "\"pm10\":" + String(pm10) + ",";
    }
    
    // CO2 ve VOC değerleri için null kontrolü
    if (co2Value == -1) {
      jsonData += "\"co2\":null";
    } else {
      jsonData += "\"co2\":" + String(co2Value);
    }
    
    if (vocValue == -1) {
      jsonData += ",\"voc\":null";
    } else {
      jsonData += ",\"voc\":" + String(vocValue);
    }
    
    // Latitude ve longitude verileri artık eklenmeyecek
    jsonData += "}";
    
    Serial.println("JSON verisi:");
    Serial.println(jsonData);
    
    // Yeni veri geldiğinde ekranı güncellemek için flag'i set et
    displayNeedsUpdate = true;      // HTTP POST zamanı geldiyse, veri gönderim bayrağını ayarla
    if (currentTime - lastPostTime >= postPeriod || lastPostTime == 0) {
      lastPostTime = currentTime;
      
      // Önce FAIL klasöründeki verileri göndermeyi dene
      bool failedDataSent = false;
      if (checkAndSendFailedData()) {
        failedDataSent = true;
        Serial.println("Başarısız verileri gönderme işlemi tamamlandı");
      }
      
      // Ekran modunu bozmadan arka planda veri gönderimi yapılacak
      // 192.168.0.39:8000/api/sensors/data adresine gönderme
      ESP8266_SERIAL.println("AT+CIPSTART=\"TCP\",\"192.168.0.39\",8000");
      delay(2000);
      String httpRequest = 
        "POST /api/sensors/data HTTP/1.1\r\n"
        "Host: 192.168.0.39:8000\r\n"
        "Content-Type: application/json\r\n"
        "Content-Length: " + String(jsonData.length()) + "\r\n\r\n" +
        jsonData;
    
      ESP8266_SERIAL.println("AT+CIPSEND=" + String(httpRequest.length()));
      delay(1000);
      ESP8266_SERIAL.print(httpRequest);
        // HTTP yanıtını bekle ve kontrol et
      delay(3000);
      bool postSuccess = false;
      String response = "";
      bool isSuccessTrue = false;
      
      while(ESP8266_SERIAL.available()) {
        response += ESP8266_SERIAL.readString();
      }
      
      // HTTP 200 OK yanıtı kontrol et
      if(response.indexOf("HTTP/1.1 200 OK") != -1 || response.indexOf("200 OK") != -1) {
        // JSON yanıtından "success" değerini kontrol et
        if(response.indexOf("\"success\":true") != -1) {
          isSuccessTrue = true;
          postSuccess = true;
          Serial.println("POST başarılı, success:true");
        } else {
          Serial.println("POST başarılı, fakat success:false");
          postSuccess = false;
        }
      } else {
        Serial.println("POST başarısız");
        Serial.println("Yanıt: " + response);
      }
        // SD karta kaydet
      backupToSD(jsonData, postSuccess);
    }
  }
    // Ekran modunun değiştirilme zamanı geldi mi?
  if (currentTime - lastModeChangeTime >= modeChangePeriod) {
    lastModeChangeTime = currentTime;
      // Bir sonraki ekran moduna geç
    currentDisplayMode = (currentDisplayMode + 1) % 9; // 9 ayrı mod (0-8 arası)
    
    Serial.print("Ekran modu değişti: ");
    Serial.println(currentDisplayMode);
    
    // Mod değiştiği için ekranı güncelleme flag'ini set et
    displayNeedsUpdate = true;
  }
  
  // Sadece ihtiyaç olduğunda ekranı güncelle
  if (displayNeedsUpdate) {
    // Aktif ekran moduna göre ilgili içeriği göster
    switch (currentDisplayMode) {
      case DISPLAY_CURRENT:
        showCurrentData();
        break;
          case DISPLAY_TEMP_GRAPH:
        // Sıcaklık grafiğini çiz
        drawGraph(tempHistory, dataCount, ILI9341_ORANGE, 150, "Sicaklik Grafigi", "C", 0, 50);
        displayPageNumber(1, 8); // Sayfa numarası eklendi
        break;
        
      case DISPLAY_HUM_GRAPH:
        // Nem grafiğini çiz
        drawGraph(humHistory, dataCount, ILI9341_CYAN, 150, "Nem Grafigi", "%", 0, 100);
        displayPageNumber(2, 8); // Sayfa numarası eklendi
        break;
        
      case DISPLAY_PM25_GRAPH:
        // PM2.5 grafiğini çiz
        drawIntGraph(pm25History, dataCount, ILI9341_YELLOW, 150, "PM2.5 Grafigi", "ug/m3", 0, 100);
        displayPageNumber(3, 8); // Sayfa numarası eklendi
        break;
        
      case DISPLAY_PM10_GRAPH:
        // PM10 grafiğini çiz
        drawIntGraph(pm10History, dataCount, ILI9341_RED, 150, "PM10 Grafigi", "ug/m3", 0, 150);
        displayPageNumber(4, 8); // Sayfa numarası eklendi
        break;

      case DISPLAY_CO2_GRAPH:
        // CO2 grafiğini çiz
        drawIntGraph(co2History, dataCount, ILI9341_GREEN, 150, "CO2 Grafigi", "ppm", 0, 2000);
        displayPageNumber(5, 8); // Sayfa numarası eklendi
        break;

      case DISPLAY_VOC_GRAPH:        // VOC grafiğini çiz
        drawIntGraph(vocHistory, dataCount, ILI9341_MAGENTA, 150, "VOC Grafigi", "ppb", 0, 1000);
        displayPageNumber(6, 8); // Sayfa numarası eklendi
        break;
        
      case DISPLAY_IP_LOCATION:
        // IP lokasyon bilgisini göster (varsa)
        // Henüz eklenmemiş olabilir
        displayPageNumber(7, 8); // Sayfa numarası eklendi
        break;
        
      case DISPLAY_ALERTS:
        // Sensör uyarılarını göster
        showSensorAlerts();
        displayPageNumber(8, 8); // Sayfa numarası eklendi
        break;
    }
    
    // Ekran güncellendiği için flag'i resetle
    displayNeedsUpdate = false;
  }
  
  // LED ve buzzer kontrolü
  if (currentTime - lastLedUpdateTime >= ledUpdatePeriod) {
    lastLedUpdateTime = currentTime;
    checkSensorStatus();
  }
  
  // Buzzer alarmını güncelle
  updateBuzzer();
  
  // Kısa bir süre bekle
  delay(50);
}

// Mevcut sensör verilerini gösteren fonksiyon
void showCurrentData() {
  // TFT'yi etkinleştir
  digitalWrite(SD_CS, HIGH);  // SD kartı devre dışı bırak
  digitalWrite(TFT_CS, LOW);  // TFT'yi etkinleştir
  
  // Ekranı temizle
  tft.fillScreen(ILI9341_BLACK);
  
  // Zaman bilgisini al
  DateTime now = rtc.now();

  // Mevcut veri değerlerini hazırla
  float temp = (dataCount > 0) ? tempHistory[dataCount - 1] : 0;
  float hum = (dataCount > 0) ? humHistory[dataCount - 1] : 0;
  int pm25Value = (dataCount > 0) ? pm25History[dataCount - 1] : -1;
  int pm10Value = (dataCount > 0) ? pm10History[dataCount - 1] : -1;
  int co2Value = (dataCount > 0) ? co2History[dataCount - 1] : -1;
  int vocValue = (dataCount > 0) ? vocHistory[dataCount - 1] : -1;
  
  // Ekrana veri yazdırma
  tft.setTextSize(2);

  // Zaman
  tft.setCursor(10, 10);
  tft.setTextColor(ILI9341_WHITE);
  tft.print("Tarih: ");
  tft.print(now.day());
  tft.print("/");
  tft.print(now.month());
  tft.print("/");
  tft.print(now.year());

  tft.setCursor(10, 40);
  tft.print("Saat: ");
  tft.print(now.hour());
  tft.print(":");
  if (now.minute() < 10) tft.print("0");
  tft.print(now.minute());

  // Sensör güvenlik seviyelerini kontrol et
  int tempStatus = checkSensorLevel(temp, TEMP_SAFE_MIN, TEMP_SAFE_MAX, TEMP_ATTENTION_MIN, TEMP_ATTENTION_MAX);
  int humStatus = checkSensorLevel(hum, HUM_SAFE_MIN, HUM_SAFE_MAX, HUM_ATTENTION_MIN, HUM_ATTENTION_MAX);
  int pm25Status = (pm25Value != -1) ? 
    ((pm25Value <= PM25_SAFE_MAX) ? LEVEL_SAFE : 
     (pm25Value <= PM25_ATTENTION_MAX) ? LEVEL_ATTENTION : LEVEL_DANGEROUS) : LEVEL_SAFE;
  int pm10Status = (pm10Value != -1) ? 
    ((pm10Value <= PM10_SAFE_MAX) ? LEVEL_SAFE : 
     (pm10Value <= PM10_ATTENTION_MAX) ? LEVEL_ATTENTION : LEVEL_DANGEROUS) : LEVEL_SAFE;
  int co2Status = (co2Value != -1) ? 
    ((co2Value <= CO2_SAFE_MAX) ? LEVEL_SAFE : 
     (co2Value <= CO2_ATTENTION_MAX) ? LEVEL_ATTENTION : LEVEL_DANGEROUS) : LEVEL_SAFE;
  int vocStatus = (vocValue != -1) ? 
    ((vocValue <= VOC_SAFE_MAX) ? LEVEL_SAFE : 
     (vocValue <= VOC_ATTENTION_MAX) ? LEVEL_ATTENTION : LEVEL_DANGEROUS) : LEVEL_SAFE;
  // Sıcaklık - durum renginde göster
  tft.setCursor(10, 80);
  tft.setTextColor(ILI9341_ORANGE); // Başlık her zaman turuncu
  tft.print("Sicaklik: ");
  
  // Değer için durum rengini seç
  if (tempStatus == LEVEL_SAFE) {
    tft.setTextColor(ILI9341_GREEN); // Güvenli - yeşil
  } else if (tempStatus == LEVEL_ATTENTION) {
    tft.setTextColor(0xFDA0); // Dikkat - turuncu
  } else {
    tft.setTextColor(ILI9341_RED); // Tehlikeli - kırmızı
  }
  
  tft.print(temp);
  tft.println(" C");
  // Nem - durum renginde göster
  tft.setCursor(10, 110);
  tft.setTextColor(ILI9341_CYAN); // Başlık her zaman cyan
  tft.print("Nem: ");
  
  // Değer için durum rengini seç
  if (humStatus == LEVEL_SAFE) {
    tft.setTextColor(ILI9341_GREEN); // Güvenli - yeşil
  } else if (humStatus == LEVEL_ATTENTION) {
    tft.setTextColor(0xFDA0); // Dikkat - turuncu
  } else {
    tft.setTextColor(ILI9341_RED); // Tehlikeli - kırmızı
  }
  
  tft.print(hum);
  tft.println(" %");
  // PM2.5 - durum renginde göster
  tft.setCursor(10, 140);
  tft.setTextColor(ILI9341_YELLOW); // Başlık her zaman sarı
  tft.print("PM2.5: ");
  
  if (pm25Value != -1) {
    // Değer için durum rengini seç
    if (pm25Status == LEVEL_SAFE) {
      tft.setTextColor(ILI9341_GREEN); // Güvenli - yeşil
    } else if (pm25Status == LEVEL_ATTENTION) {
      tft.setTextColor(0xFDA0); // Dikkat - turuncu
    } else {
      tft.setTextColor(ILI9341_RED); // Tehlikeli - kırmızı
    }
    
    tft.print(pm25Value);
    tft.println(" ug/m3");
  } else {
    tft.println("Veri Yok");
  }
  // PM10 - durum renginde göster
  tft.setCursor(10, 170);
  tft.setTextColor(ILI9341_RED); // Başlık her zaman kırmızı
  tft.print("PM10: ");
  
  if (pm10Value != -1) {
    // Değer için durum rengini seç
    if (pm10Status == LEVEL_SAFE) {
      tft.setTextColor(ILI9341_GREEN); // Güvenli - yeşil
    } else if (pm10Status == LEVEL_ATTENTION) {
      tft.setTextColor(0xFDA0); // Dikkat - turuncu
    } else {
      tft.setTextColor(ILI9341_RED); // Tehlikeli - kırmızı
    }
    
    tft.print(pm10Value);
    tft.println(" ug/m3");
  } else {
    tft.println("Veri Yok");
  }
  // CO2 - durum renginde göster
  tft.setCursor(10, 200);
  tft.setTextColor(ILI9341_GREEN); // Başlık her zaman yeşil
  tft.print("CO2: ");
  
  if (co2Value != -1) {
    // Değer için durum rengini seç
    if (co2Status == LEVEL_SAFE) {
      tft.setTextColor(ILI9341_GREEN); // Güvenli - yeşil
    } else if (co2Status == LEVEL_ATTENTION) {
      tft.setTextColor(0xFDA0); // Dikkat - turuncu
    } else {
      tft.setTextColor(ILI9341_RED); // Tehlikeli - kırmızı
    }
    
    tft.print(co2Value);
    tft.println(" ppm");
  } else {
    tft.println("Veri Yok");
  }
  // VOC - durum renginde göster
  tft.setCursor(10, 230);
  tft.setTextColor(ILI9341_MAGENTA); // Başlık her zaman magenta
  tft.print("VOC: ");
  
  if (vocValue != -1) {
    // Değer için durum rengini seç
    if (vocStatus == LEVEL_SAFE) {
      tft.setTextColor(ILI9341_GREEN); // Güvenli - yeşil
    } else if (vocStatus == LEVEL_ATTENTION) {
      tft.setTextColor(0xFDA0); // Dikkat - turuncu
    } else {
      tft.setTextColor(ILI9341_RED); // Tehlikeli - kırmızı
    }
    
    tft.print(vocValue);
    tft.println(" ppb");
  } else {
    tft.println("Veri Yok");
  }

  // Konum
  tft.setCursor(10, 260);
  if (gps.location.isValid()) {
    tft.setTextColor(ILI9341_GREEN);
    tft.print("Konum: ");
    tft.setCursor(10, 280);
    tft.print("Lat: ");
    tft.print(gps.location.lat(), 6);
    tft.setCursor(10, 300);
    tft.print("Lng: ");
    tft.print(gps.location.lng(), 6);
  } else {
    tft.setTextColor(ILI9341_LIGHTGREY);
    tft.println("Konum Alinamadi...");
  }
  
  // Ana bilgi mesajı ekle
  tft.setTextSize(1);
  tft.setTextColor(ILI9341_WHITE);
  tft.setCursor(10, 320);
  tft.print("Guncel Veriler - Son guncelleme: ");
  tft.print(now.hour());
  tft.print(":");
  if (now.minute() < 10) tft.print("0");
  tft.print(now.minute());
  tft.print(":");
  if (now.second() < 10) tft.print("0");
  tft.print(now.second());
  
  // Sayfa numarası ekle
  displayPageNumber(0, 8);
}

bool readPMS5003Data() {
  const int frameLength = 32;
  uint8_t buffer[frameLength];

  while (PMS.available() >= frameLength) {
    if (PMS.peek() == 0x42) {
      if (PMS.read() == 0x42 && PMS.peek() == 0x4D) {
        PMS.read();
        buffer[0] = 0x42;
        buffer[1] = 0x4D;

        for (int i = 2; i < frameLength; i++) {
          buffer[i] = PMS.read();
        }

        pm25 = (buffer[10] << 8) | buffer[11];
        pm10 = (buffer[12] << 8) | buffer[13];
        return true;
      } else {
        PMS.read();
      }
    } else {
      PMS.read();
    }
  }
  return false;
}

void connectToWiFi() {
  printStatusMessage("WiFi baglantisi kuruluyor...");
  Serial.println("WiFi baglantisi kuruluyor...");

  int wifiRetryCount = 0;
  const int maxWifiRetry = 3;
  bool wifiConnected = false;
  
  while (wifiRetryCount <= maxWifiRetry && !wifiConnected) {
    if (wifiRetryCount > 0) {
      Serial.print("WiFi Deneme #");
      Serial.println(wifiRetryCount + 1);
      printStatusMessage("WiFi Deneme #" + String(wifiRetryCount + 1));
      delay(1000);
    }
    
    ESP8266_SERIAL.println("AT");
    delay(1000);
    ESP8266_SERIAL.println("AT+CWMODE=1");
    delay(1000);
    ESP8266_SERIAL.println("AT+CWJAP=\"" + String(ssid) + "\",\"" + String(password) + "\"");
    delay(5000);

    String res = "";
    while (ESP8266_SERIAL.available()) {
      res += ESP8266_SERIAL.readString();
    }

    if (res.indexOf("WIFI CONNECTED") != -1 || res.indexOf("OK") != -1) {
      Serial.println("WiFi Baglandi.");
      printStatusMessage("WiFi: Baglandi.");
      wifiConnected = true;
    } else {
      Serial.println("WiFi Baglanti Hatasi!");
      printStatusMessage("WiFi: Baglanamadi!");
      wifiRetryCount++;
      
      if (wifiRetryCount <= maxWifiRetry) {
        Serial.println("Yeniden deneniyor...");
        printStatusMessage("Yeniden deneniyor...");
        delay(3000); // Her yeniden deneme arasında 3 saniye bekle
      }
    }
  }
  
  if (!wifiConnected) {
    Serial.println("WiFi baglantisi kurulamadi. Maximum deneme sayisina ulasildi.");
    printStatusMessage("WiFi: Baglanamadi!");
    printStatusMessage("Max deneme sayisina ulasildi");
  }
}

void backupToSD(String jsonData, bool success) {
  DateTime now = rtc.now();

  // TFT ve SD kart için CS pinlerini düzenle
  digitalWrite(TFT_CS, HIGH);  // TFT'yi devre dışı bırak
  digitalWrite(SD_CS, LOW);    // SD kartı etkinleştir
  delay(10);  // SD kartın hazır olmasını bekle

  // SD kart ile işlem yapmadan önce SD.begin() kontrolü yap
  if (!SD.begin(SD_CS)) {
    Serial.println("SD kart başlatılamadı!");
    digitalWrite(SD_CS, HIGH);
    digitalWrite(TFT_CS, LOW);
    return;
  }

  if (success) {
    // Başarılı isteği DATA klasörüne kaydet
    saveToFolder("DATA", jsonData, success, now);
  } else {
    // Başarısız isteği FAIL klasörüne kaydet
    saveToFolder("FAIL", jsonData, success, now);
  }
  
  // İşlem bittikten sonra CS pinlerini geri ayarla
  digitalWrite(SD_CS, HIGH);   // SD kartı devre dışı bırak
  digitalWrite(TFT_CS, LOW);   // TFT'yi etkinleştir
}

// Şu anda hangi klasör numarasında olduğumuzu bulan fonksiyon
int findCurrentFolder(const char* mainFolder) {
  // index.txt dosyasını kontrol et
  char indexPath[20];
  sprintf(indexPath, "%s/INDEX.TXT", mainFolder);
  
  if (!SD.exists(indexPath)) {
    // Index dosyası yoksa, "1" klasörünü ve index dosyasını oluştur
    updateIndexFile(mainFolder, 1, 0);
    return 1;
  }
  
  // Index dosyası varsa, içeriğini oku
  File indexFile = SD.open(indexPath, FILE_READ);
  if (!indexFile) {
    return 1; // Dosya açılamazsa varsayılan olarak 1
  }
  
  // Dosya içeriğini oku (folderNum,fileNum formatında)
  String indexContent = "";
  while (indexFile.available()) {
    char c = indexFile.read();
    if (c == '\n' || c == '\r') break;
    indexContent += c;
  }
  indexFile.close();
  
  // İçeriği parse et
  int comma = indexContent.indexOf(',');
  if (comma == -1) return 1;
  
  return indexContent.substring(0, comma).toInt();
}

// Şu anda klasörde kaç dosya olduğunu bulan fonksiyon
int findCurrentFile(const char* mainFolder, int folderNum) {
  // index.txt dosyasını kontrol et
  char indexPath[20];
  sprintf(indexPath, "%s/INDEX.TXT", mainFolder);
  
  if (!SD.exists(indexPath)) {
    return 0;
  }
  
  // Index dosyası varsa, içeriğini oku
  File indexFile = SD.open(indexPath, FILE_READ);
  if (!indexFile) {
    return 0;
  }
  
  // Dosya içeriğini oku (folderNum,fileNum formatında)
  String indexContent = "";
  while (indexFile.available()) {
    char c = indexFile.read();
    if (c == '\n' || c == '\r') break;
    indexContent += c;
  }
  indexFile.close();
  
  // İçeriği parse et
  int comma = indexContent.indexOf(',');
  if (comma == -1) return 0;
  
  int fileNum = indexContent.substring(comma + 1).toInt();
  
  // Eğer dosya numarası 9999'a ulaştıysa, bir sonraki klasöre geç
  if (fileNum > 9999) {
    updateIndexFile(mainFolder, folderNum + 1, 0);
    return 0;
  }
  
  return fileNum;
}

// Index dosyasını güncelleme fonksiyonu
void updateIndexFile(const char* mainFolder, int folderNum, int fileNum) {
  char indexPath[20];
  sprintf(indexPath, "%s/INDEX.TXT", mainFolder);
  
  // İlk önce dosyayı sil (mevcut içeriği temizlemek için)
  if (SD.exists(indexPath)) {
    SD.remove(indexPath);
  }
  
  // Yeni dosyayı oluştur ve yaz
  File indexFile = SD.open(indexPath, FILE_WRITE);
  if (indexFile) {
    indexFile.print(folderNum);
    indexFile.print(",");
    indexFile.println(fileNum);
    indexFile.close();
    Serial.println("Index dosyası güncellendi: Klasör " + String(folderNum) + ", Dosya " + String(fileNum));
  } else {
    Serial.println("Index dosyası güncellenemedi!");
  }
}

// Yeni sensör verilerini geçmiş veri dizilerine kaydetme fonksiyonu
void storeNewData(float temp, float hum, int pm25Value, int pm10Value, int co2Value, int vocValue) {
  // Dizinin içeriğini bir indeks geri kaydır (en eskiyi sil)
  if (dataCount >= MAX_DATA_POINTS) {
    for (int i = 0; i < MAX_DATA_POINTS - 1; i++) {
      tempHistory[i] = tempHistory[i + 1];
      humHistory[i] = humHistory[i + 1];
      pm25History[i] = pm25History[i + 1];
      pm10History[i] = pm10History[i + 1];
      co2History[i] = co2History[i + 1];
      vocHistory[i] = vocHistory[i + 1];
    }
    // En son elemanı ekle
    tempHistory[MAX_DATA_POINTS - 1] = temp;
    humHistory[MAX_DATA_POINTS - 1] = hum;
    pm25History[MAX_DATA_POINTS - 1] = pm25Value;
    pm10History[MAX_DATA_POINTS - 1] = pm10Value;
    co2History[MAX_DATA_POINTS - 1] = co2Value;
    vocHistory[MAX_DATA_POINTS - 1] = vocValue;
  } else {
    // Diziyi doldurma aşamasında
    tempHistory[dataCount] = temp;
    humHistory[dataCount] = hum;
    pm25History[dataCount] = pm25Value;
    pm10History[dataCount] = pm10Value;
    co2History[dataCount] = co2Value;
    vocHistory[dataCount] = vocValue;
    dataCount++;
  }
}

// Grafik çizme fonksiyonu
void drawGraph(float data[], int dataSize, int graphColor, int baseLineY, const char* title, const char* unit, float minVal, float maxVal) {
  digitalWrite(SD_CS, HIGH);  // SD kartı devre dışı bırak
  digitalWrite(TFT_CS, LOW);  // TFT'yi etkinleştir
  
  // Ekranı temizle
  tft.fillScreen(ILI9341_BLACK);
  
  // Başlık
  tft.setTextSize(2);
  tft.setTextColor(ILI9341_WHITE);
  tft.setCursor(10, 10);
  tft.print(title);
  
  // Bugünün tarihi
  DateTime now = rtc.now();
  tft.setTextSize(1);
  tft.setCursor(10, 30);
  tft.print(now.day());
  tft.print("/");
  tft.print(now.month());
  tft.print("/");
  tft.print(now.year());
  
  // Eksen çizgileri - grafiği biraz küçültüp aşağıya kaydırıyoruz
  int graphX = 40;
  int graphY = 60;
  int graphWidth = tft.width() - 50;
  int graphHeight = 160;
  
  // Grafik kutusu çiz
  tft.drawLine(graphX, graphY, graphX, graphY + graphHeight, ILI9341_WHITE);
  tft.drawLine(graphX, graphY + graphHeight, graphX + graphWidth, graphY + graphHeight, ILI9341_WHITE);
  
  // Y ekseni etiketleri
  tft.setTextSize(1);
  tft.setTextColor(ILI9341_CYAN);  // Maksimum ve minimum değerleri için ortak renk: CYAN
  
  // Y ekseni değerlerini yaz
  tft.setCursor(5, graphY);
  tft.print(maxVal);
  tft.setCursor(5, graphY + graphHeight - 10);
  tft.print(minVal);
  
  // Ölçek birimi - birim rengi de maksimum/minimum rengi ile aynı olsun
  tft.setCursor(5, graphY + graphHeight/2);
  tft.print(unit);
  
  // Veri içindeki güncel, minimum ve maksimum değerleri bul
  if (dataSize > 0) {
    float currentVal = data[dataSize - 1];  // Son değer (güncel)
    float minDataVal = currentVal;
    float maxDataVal = currentVal;
    
    // Veri setindeki minimum ve maksimum değerleri bul
    for (int i = 0; i < dataSize; i++) {
      if (data[i] < minDataVal) minDataVal = data[i];
      if (data[i] > maxDataVal) maxDataVal = data[i];
    }
    
    // Y ekseninde bu değerlerin konumlarını hesapla
    int yCurrentVal = graphY + graphHeight - ((currentVal - minVal) * graphHeight) / (maxVal - minVal);
    int yMinDataVal = graphY + graphHeight - ((minDataVal - minVal) * graphHeight) / (maxVal - minVal);
    int yMaxDataVal = graphY + graphHeight - ((maxDataVal - minVal) * graphHeight) / (maxVal - minVal);
    
    // Y ekseninde bu değerleri göster
    // Maks değer
    tft.setTextColor(ILI9341_CYAN); // Maksimum/minimum için ortak renk
    tft.drawLine(graphX - 5, yMaxDataVal, graphX, yMaxDataVal, ILI9341_CYAN);
    tft.setCursor(10, yMaxDataVal - 4);
    // tft.print("Max:");
    tft.print(maxDataVal);
    
    // Min değer
    tft.drawLine(graphX - 5, yMinDataVal, graphX, yMinDataVal, ILI9341_CYAN);
    tft.setCursor(10, yMinDataVal - 4);
    // tft.print("Min:");
    tft.print(minDataVal);
    
    // Güncel değer - farklı renkte
    tft.setTextColor(0xFFFF); // Güncel değer için beyaz
    tft.drawLine(graphX - 5, yCurrentVal, graphX, yCurrentVal, 0xFFFF);
    tft.setCursor(10, yCurrentVal - 4);
    // tft.print("Guncel:");
    tft.print(currentVal);
    
    // X ekseni boyunca Minimum ve Maximum çizgileri (ince kesikli)
    for (int x = graphX; x < graphX + graphWidth; x += 5) {
      tft.drawPixel(x, yMinDataVal, ILI9341_CYAN); // Min çizgisi
      tft.drawPixel(x, yMaxDataVal, ILI9341_CYAN); // Max çizgisi
    }
    
    // Güncel değer çizgisi (farklı renk ve stil)
    for (int x = graphX; x < graphX + graphWidth; x += 8) {
      tft.drawPixel(x, yCurrentVal, 0xFFFF);     // Güncel değer çizgisi
      tft.drawPixel(x+1, yCurrentVal, 0xFFFF);   // Biraz daha kalın
    }
  }
  
  // X-ekseni saat gösterimi
  if (dataSize > 0) {
    // X ekseninde saatleri göster - en az 4 nokta (başlangıç, 1/3, 2/3 ve son nokta)
    DateTime now = rtc.now();
    int timeStep = max(1, dataSize / 4);
    
    // Zaman bilgileri için farklı bir renk kullan
    tft.setTextColor(ILI9341_LIGHTGREY);
    
    // ... mevcut X ekseni saat gösterimi kodu ...
    
    // Şu anki saat
    char timeStr[6];
    sprintf(timeStr, "%02d:%02d", now.hour(), now.minute());
    tft.setCursor(graphX + graphWidth - 25, graphY + graphHeight + 10);
    tft.print(timeStr);
    
    // Şu anki saatten zaman aralıklarını hesapla ve göster
    if (dataSize >= 4) {
      // 1/3 nokta
      int point1 = dataSize * 1 / 3;
      int minutes1 = (dataSize - point1) * 10 / 60;  // Her nokta 10 saniye
      int hours1 = now.hour();
      int mins1 = now.minute() - minutes1;
      
      // Dakika taşması kontrolü
      while (mins1 < 0) {
        mins1 += 60;
        hours1--;
      }
      // Saat taşması kontrolü
      while (hours1 < 0) {
        hours1 += 24;
      }
      
      sprintf(timeStr, "%02d:%02d", hours1, mins1);
      tft.setCursor(graphX + graphWidth * 1/3 - 15, graphY + graphHeight + 10);
      tft.print(timeStr);
      
      // 2/3 nokta
      int point2 = dataSize * 2 / 3;
      int minutes2 = (dataSize - point2) * 10 / 60;
      int hours2 = now.hour();
      int mins2 = now.minute() - minutes2;
      
      // Dakika taşması kontrolü
      while (mins2 < 0) {
        mins2 += 60;
        hours2--;
      }
      // Saat taşması kontrolü
      while (hours2 < 0) {
        hours2 += 24;
      }
      
      sprintf(timeStr, "%02d:%02d", hours2, mins2);
      tft.setCursor(graphX + graphWidth * 2/3 - 15, graphY + graphHeight + 10);
      tft.print(timeStr);
    }
    
    // Başlangıç noktası (en eski veri)
    int minutesTotal = dataSize * 10 / 60;  // Her veri 10 saniye aralıklı
    int hoursOld = now.hour();
    int minsOld = now.minute() - minutesTotal;
    
    // Dakika taşması kontrolü
    while (minsOld < 0) {
      minsOld += 60;
      hoursOld--;
    }
    // Saat taşması kontrolü
    while (hoursOld < 0) {
      hoursOld += 24;
    }
    
    sprintf(timeStr, "%02d:%02d", hoursOld, minsOld);
    tft.setCursor(graphX - 15, graphY + graphHeight + 10);
    tft.print(timeStr);
  }
  
  // Veri noktaları arası çizgiyi çiz
  if (dataSize > 1) {
    for (int i = 0; i < dataSize - 1; i++) {
      // Grafik değerlerini Y eksenine dönüştür
      int x1 = graphX + (i * graphWidth) / (dataSize - 1);
      int y1 = graphY + graphHeight - ((data[i] - minVal) * graphHeight) / (maxVal - minVal);
      int x2 = graphX + ((i + 1) * graphWidth) / (dataSize - 1);
      int y2 = graphY + graphHeight - ((data[i + 1] - minVal) * graphHeight) / (maxVal - minVal);
      
      // Değer geçerli aralıktaysa çizgiyi çiz
      if (y1 >= graphY && y1 <= graphY + graphHeight && 
          y2 >= graphY && y2 <= graphY + graphHeight) {
        tft.drawLine(x1, y1, x2, y2, graphColor);
      }
    }
  }
    // Mevcut değeri göster - güvenlik seviyesine göre farklı renkte
  if (dataSize > 0) {
    tft.setTextSize(2);
    
    // Sensör durumunu kontrol et ve rengi belirle
    // Eğer bu bir sıcaklık grafiği ise
    if (strcmp(title, "Sicaklik Grafigi") == 0) {
      float currentValue = data[dataSize - 1];
      int status = checkSensorLevel(currentValue, TEMP_SAFE_MIN, TEMP_SAFE_MAX, TEMP_ATTENTION_MIN, TEMP_ATTENTION_MAX);
      
      if (status == LEVEL_SAFE) {
        tft.setTextColor(ILI9341_GREEN); // Güvenli - yeşil
      } else if (status == LEVEL_ATTENTION) {
        tft.setTextColor(0xFDA0); // Dikkat - turuncu
      } else {
        tft.setTextColor(ILI9341_RED); // Tehlikeli - kırmızı
      }
    } 
    // Eğer bu bir nem grafiği ise
    else if (strcmp(title, "Nem Grafigi") == 0) {
      float currentValue = data[dataSize - 1];
      int status = checkSensorLevel(currentValue, HUM_SAFE_MIN, HUM_SAFE_MAX, HUM_ATTENTION_MIN, HUM_ATTENTION_MAX);
      
      if (status == LEVEL_SAFE) {
        tft.setTextColor(ILI9341_GREEN); // Güvenli - yeşil
      } else if (status == LEVEL_ATTENTION) {
        tft.setTextColor(0xFDA0); // Dikkat - turuncu
      } else {
        tft.setTextColor(ILI9341_RED); // Tehlikeli - kırmızı
      }
    }
    // PM2.5 grafiği için
    else if (strcmp(title, "PM2.5 Grafigi") == 0) {
      float currentValue = data[dataSize - 1];
      if (currentValue <= PM25_SAFE_MAX) {
        tft.setTextColor(ILI9341_GREEN); // Güvenli - yeşil
      } else if (currentValue <= PM25_ATTENTION_MAX) {
        tft.setTextColor(0xFDA0); // Dikkat - turuncu
      } else {
        tft.setTextColor(ILI9341_RED); // Tehlikeli - kırmızı
      }
    }
    // PM10 grafiği için
    else if (strcmp(title, "PM10 Grafigi") == 0) {
      float currentValue = data[dataSize - 1];
      if (currentValue <= PM10_SAFE_MAX) {
        tft.setTextColor(ILI9341_GREEN); // Güvenli - yeşil
      } else if (currentValue <= PM10_ATTENTION_MAX) {
        tft.setTextColor(0xFDA0); // Dikkat - turuncu
      } else {
        tft.setTextColor(ILI9341_RED); // Tehlikeli - kırmızı
      }
    }
    // CO2 grafiği için
    else if (strcmp(title, "CO2 Grafigi") == 0) {
      float currentValue = data[dataSize - 1];
      if (currentValue <= CO2_SAFE_MAX) {
        tft.setTextColor(ILI9341_GREEN); // Güvenli - yeşil
      } else if (currentValue <= CO2_ATTENTION_MAX) {
        tft.setTextColor(0xFDA0); // Dikkat - turuncu
      } else {
        tft.setTextColor(ILI9341_RED); // Tehlikeli - kırmızı
      }
    }
    // VOC grafiği için
    else if (strcmp(title, "VOC Grafigi") == 0) {
      float currentValue = data[dataSize - 1];
      if (currentValue <= VOC_SAFE_MAX) {
        tft.setTextColor(ILI9341_GREEN); // Güvenli - yeşil
      } else if (currentValue <= VOC_ATTENTION_MAX) {
        tft.setTextColor(0xFDA0); // Dikkat - turuncu
      } else {
        tft.setTextColor(ILI9341_RED); // Tehlikeli - kırmızı
      }
    }
    // Diğer grafikler için varsayılan beyaz renk
    else {
      tft.setTextColor(0xFFFF); // Beyaz renk
    }
    
    tft.setCursor(graphX, 250);
    tft.print("Mevcut: ");
    tft.print(data[dataSize - 1]);
    tft.print(" ");
    tft.print(unit);
    
    // Zaman bilgisini ekle
    tft.setTextSize(1);
    tft.setTextColor(ILI9341_LIGHTGREY); // İstatistik bilgileri için gri renk
    tft.setCursor(graphX, 275);
    tft.print("Veri araligi: 10 saniyede bir");
    tft.setCursor(graphX, 290);
    tft.print("Toplam veri sayisi: ");
    tft.print(dataSize);
  }
}

// Grafik göstermek için integer dizileri işleme fonksiyonu
void drawIntGraph(int data[], int dataSize, int graphColor, int baseLineY, const char* title, const char* unit, int minVal, int maxVal) {
  // Integer diziyi float diziye dönüştür
  float floatData[MAX_DATA_POINTS];
  for (int i = 0; i < dataSize; i++) {
    floatData[i] = (float)data[i];
  }
  
  // Float grafik çizme fonksiyonunu çağır
  drawGraph(floatData, dataSize, graphColor, baseLineY, title, unit, minVal, maxVal);
}

// LED kontrolü ve buzzer için fonksiyonlar
void checkSensorStatus() {
  // En son sensör değerlerini al
  float temp = (dataCount > 0) ? tempHistory[dataCount - 1] : 0;
  float hum = (dataCount > 0) ? humHistory[dataCount - 1] : 0;
  int pm25Value = (dataCount > 0) ? pm25History[dataCount - 1] : -1;
  int pm10Value = (dataCount > 0) ? pm10History[dataCount - 1] : -1;
  int co2Value = (dataCount > 0) ? co2History[dataCount - 1] : -1;
  int vocValue = (dataCount > 0) ? vocHistory[dataCount - 1] : -1;
  
  // Her sensörün durumunu kontrol et
  int tempStatus = checkSensorLevel(temp, TEMP_SAFE_MIN, TEMP_SAFE_MAX, TEMP_ATTENTION_MIN, TEMP_ATTENTION_MAX);
  int humStatus = checkSensorLevel(hum, HUM_SAFE_MIN, HUM_SAFE_MAX, HUM_ATTENTION_MIN, HUM_ATTENTION_MAX);
  
  // PM2.5 ve PM10 için kontrol (eğer veri yoksa atla)
  int pm25Status = (pm25Value != -1) ? 
    ((pm25Value <= PM25_SAFE_MAX) ? LEVEL_SAFE : 
     (pm25Value <= PM25_ATTENTION_MAX) ? LEVEL_ATTENTION : LEVEL_DANGEROUS) : LEVEL_SAFE;
  
  int pm10Status = (pm10Value != -1) ? 
    ((pm10Value <= PM10_SAFE_MAX) ? LEVEL_SAFE : 
     (pm10Value <= PM10_ATTENTION_MAX) ? LEVEL_ATTENTION : LEVEL_DANGEROUS) : LEVEL_SAFE;
  
  // CO2 için kontrol (eğer veri yoksa atla)
  int co2Status = (co2Value != -1) ? 
    ((co2Value <= CO2_SAFE_MAX) ? LEVEL_SAFE : 
     (co2Value <= CO2_ATTENTION_MAX) ? LEVEL_ATTENTION : LEVEL_DANGEROUS) : LEVEL_SAFE;
  
  // VOC için kontrol (eğer veri yoksa atla)
  int vocStatus = (vocValue != -1) ? 
    ((vocValue <= VOC_SAFE_MAX) ? LEVEL_SAFE : 
     (vocValue <= VOC_ATTENTION_MAX) ? LEVEL_ATTENTION : LEVEL_DANGEROUS) : LEVEL_SAFE;
  
  // En yüksek tehlike seviyesini bul
  int highestDanger = LEVEL_SAFE;
  if (tempStatus > highestDanger) highestDanger = tempStatus;
  if (humStatus > highestDanger) highestDanger = humStatus;
  if (pm25Status > highestDanger) highestDanger = pm25Status;
  if (pm10Status > highestDanger) highestDanger = pm10Status;
  if (co2Status > highestDanger) highestDanger = co2Status;
  if (vocStatus > highestDanger) highestDanger = vocStatus;
  
  // LED'leri kontrol et
  digitalWrite(led1, (highestDanger == LEVEL_SAFE) ? HIGH : LOW);       // Yeşil LED - tüm değerler güvenli
  digitalWrite(led2, (highestDanger == LEVEL_ATTENTION) ? HIGH : LOW);  // Sarı LED - en az bir değer dikkat gerektiriyor
  digitalWrite(led3, (highestDanger == LEVEL_DANGEROUS) ? HIGH : LOW);  // Kırmızı LED - en az bir değer tehlikeli

  // Çok tehlikeli durumlar için özel kontrol
  bool veryDangerous = false;
  if(pm25Value > PM25_VERY_DANGEROUS) veryDangerous = true;
  if(pm10Value > PM10_VERY_DANGEROUS) veryDangerous = true;
  if(co2Value > CO2_VERY_DANGEROUS) veryDangerous = true;
  if(vocValue > VOC_VERY_DANGEROUS) veryDangerous = true;
  
  // Çok tehlikeli durum varsa, tüm LED'leri yakıp söndür
  if(veryDangerous) {
    // Yanıp sönme etkisi için zamanlamayı kontrol et
    if(millis() % 1000 < 500) {
      digitalWrite(led1, HIGH);
      digitalWrite(led2, HIGH);
      digitalWrite(led3, HIGH);
    } else {
      digitalWrite(led1, LOW);
      digitalWrite(led2, LOW);
      digitalWrite(led3, LOW);
    }
  }

  // Buzzer kontrolü - tehlikeli durumlarda ilgili sensör için ses çal
  if (highestDanger == LEVEL_DANGEROUS && !buzzerActive) {
    // Hangi sensör tehlikeli durumda, buna göre buzzer sesini ayarla
    if (tempStatus == LEVEL_DANGEROUS) {
      startBuzzerAlarm(1); // Sıcaklık için tek bip
    } else if (humStatus == LEVEL_DANGEROUS) {
      startBuzzerAlarm(2); // Nem için iki bip
    } else if (pm25Status == LEVEL_DANGEROUS) {
      startBuzzerAlarm(3); // PM2.5 için üç bip
    } else if (pm10Status == LEVEL_DANGEROUS) {
      startBuzzerAlarm(4); // PM10 için dört bip
    } else if (co2Status == LEVEL_DANGEROUS) {
      startBuzzerAlarm(5); // CO2 için beş bip
    } else if (vocStatus == LEVEL_DANGEROUS) {
      startBuzzerAlarm(6); // VOC için altı bip
    }
  } else if (highestDanger != LEVEL_DANGEROUS && buzzerActive) {
    // Tehlike geçtiyse buzzer'ı kapat
    stopBuzzer();
  }
}

// Belirli bir bip sayısı ile buzzer alarmını başlat
void startBuzzerAlarm(int sensorType) {
  buzzerActive = true;
  buzzerStartTime = millis();
  currentBeepCount = 0;
  maxBeepCount = sensorType;  // Hangi sensör için alarm çalıyor
  beepRepeatCount = 0;
  currentBeepSensor = sensorType;  // Hangi sensör için alarm çalıyor
}

// Buzzer alarmını durdur
void stopBuzzer() {
  buzzerActive = false;
  digitalWrite(buzzer, LOW);
  currentBeepSensor = -1;
}

// Buzzer alarmını güncelle
void updateBuzzer() {
  if (!buzzerActive) return;
  
  unsigned long currentTime = millis();
  unsigned long elapsedTime = currentTime - buzzerStartTime;
  
  // Bir döngü süresi: 2000ms (2 saniye) - alarm tekrar etme sıklığı
  const unsigned long cycleDuration = 2000;
  
  // Döngü içindeki konumunu belirle
  unsigned long cyclePosition = elapsedTime % cycleDuration;
  
  // Her bip sesi 100ms sürsün, bipler arası 150ms boşluk olsun
  const unsigned long beepDuration = 100;
  const unsigned long beepInterval = 150;
  
  // Mevcut bip sayısını hesapla
  int currentBeep = cyclePosition / (beepDuration + beepInterval);
  
  if (currentBeep < maxBeepCount) {
    // Bip süresinin içinde miyiz?
    unsigned long beepPosition = cyclePosition % (beepDuration + beepInterval);
    if (beepPosition < beepDuration) {
      digitalWrite(buzzer, HIGH);  // Bip sesi çal
    } else {
      digitalWrite(buzzer, LOW);   // Sessizlik
    }
  } else {
    digitalWrite(buzzer, LOW);    // Tüm bipler tamamlandı, sessiz kal
  }
  
  // Döngü tamamlandıysa tekrar sayacını arttır
  if (cyclePosition == 0 && elapsedTime > 0) {
    beepRepeatCount++;
    
    // 3 tekrardan sonra alarmı 5 saniye durdur
    if (beepRepeatCount >= 3) {
      buzzerStartTime = currentTime; // Zamanı yenile
      beepRepeatCount = 0; // Tekrar sayacını sıfırla
      
      // 5 saniyelik bir ara ver - buzzer'ı kapat
      digitalWrite(buzzer, LOW);
      delay(5000);
    }
  }
}

// Sayfa numarasını ekrana yazdıran fonksiyon
void displayPageNumber(int currentPage, int totalPages) {
  tft.setTextSize(1);
  tft.setTextColor(ILI9341_WHITE);
  tft.setCursor(10, 310);
  tft.print("Sayfa ");
  tft.print(currentPage);
  tft.print(" / ");
  tft.print(totalPages);
}

// Verileri belirtilen klasöre kaydetme fonksiyonu
void saveToFolder(String mainFolder, String jsonData, bool success, DateTime now) {
  // Ana klasörü kontrol et/oluştur
  if (!SD.exists(mainFolder.c_str())) {
    if (!SD.mkdir(mainFolder.c_str())) {
      Serial.println("Ana klasör oluşturulamadı: " + mainFolder);
      return;
    } else {
      Serial.println("Ana klasör oluşturuldu: " + mainFolder);
    }
  }
  
  // Mevcut klasör numarasını ve dosya sayısını bul
  int currentFolder = findCurrentFolder(mainFolder.c_str());
  int currentFileNum = findCurrentFile(mainFolder.c_str(), currentFolder);
  
  // Klasör yolu
  char folderPath[20];
  sprintf(folderPath, "%s/%d", mainFolder.c_str(), currentFolder);
  
  // Klasör yoksa oluştur
  if (!SD.exists(folderPath)) {
    if (!SD.mkdir(folderPath)) {
      Serial.println("Klasör oluşturulamadı: " + String(folderPath));
      return;
    } else {
      Serial.println("Klasör oluşturuldu: " + String(folderPath));
    }
  }
  
  // Dosya adı (XXXX.TXT formatında, 0000.TXT'den başlayarak)
  char filename[30];
  sprintf(filename, "%s/%d/%04d.TXT", mainFolder.c_str(), currentFolder, currentFileNum);
  
  Serial.print("Dosya oluşturuluyor: ");
  Serial.println(filename);
  
  // JSON veriyi "success" ile birleştir
  String combinedData = "{\"data\":";
  combinedData += jsonData;
  combinedData += ",\"success\":";
  combinedData += success ? "true" : "false";
  combinedData += "}";

  // Dosyayı aç ve yaz
  File dataFile = SD.open(filename, FILE_WRITE);
  
  if (dataFile) {
    // Tarih ve saati ek bilgi olarak dosyaya ekle
    dataFile.print("Tarih: ");
    dataFile.print(now.day());
    dataFile.print("/");
    dataFile.print(now.month());
    dataFile.print("/");
    dataFile.print(now.year());
    dataFile.print(" ");
    dataFile.print(now.hour());
    dataFile.print(":");
    dataFile.print(now.minute());
    dataFile.print(":");
    dataFile.print(now.second());
    dataFile.println();
    
    // Ana veriyi yaz
    dataFile.println(combinedData);
    dataFile.close();
    Serial.println("Veri kaydedildi: " + String(filename));
    
    // İşlem başarılı olduğu için index.txt dosyasını güncelle
    updateIndexFile(mainFolder.c_str(), currentFolder, currentFileNum + 1);
  } else {
    Serial.println("Dosya açılamadı: " + String(filename));
    
    // Alternatif olarak kök dizine yazma dene
    File rootFile = SD.open("BACKUP.TXT", FILE_WRITE);
    if (rootFile) {
      rootFile.println("Tarih: " + String(now.day()) + "/" + String(now.month()) + "/" + String(now.year()));
      rootFile.println(combinedData);
      rootFile.close();
      Serial.println("Veri yedek dosyaya kaydedildi: BACKUP.TXT");
    } else {
      Serial.println("Yedek dosya da açılamadı!");
    }
  }
}

// FAIL klasöründeki verileri kontrol edip göndermeyi deneyen fonksiyon
bool checkAndSendFailedData() {
  // TFT ve SD kart için CS pinlerini düzenle
  digitalWrite(TFT_CS, HIGH);  // TFT'yi devre dışı bırak
  digitalWrite(SD_CS, LOW);    // SD kartı etkinleştir
  delay(10);  // SD kartın hazır olmasını bekle

  // SD kart ile işlem yapmadan önce SD.begin() kontrolü yap
  if (!SD.begin(SD_CS)) {
    Serial.println("SD kart başlatılamadı!");
    digitalWrite(SD_CS, HIGH);
    digitalWrite(TFT_CS, LOW);
    return false;
  }

  // FAIL klasörü yoksa işlem yapma
  if (!SD.exists("FAIL")) {
    digitalWrite(SD_CS, HIGH);
    digitalWrite(TFT_CS, LOW);
    return false;
  }

  // FAIL klasörü altındaki alt klasörleri kontrol et
  File root = SD.open("FAIL");
  if (!root) {
    digitalWrite(SD_CS, HIGH);
    digitalWrite(TFT_CS, LOW);
    return false;
  }
  
  if (!root.isDirectory()) {
    root.close();
    digitalWrite(SD_CS, HIGH);
    digitalWrite(TFT_CS, LOW);
    return false;
  }

  bool anyFileSent = false;
  bool anySendingFailed = false;
  
  // Alt klasörleri tara (en küçük numaralı klasörden başla)
  for (int folderNum = 1; folderNum <= 1000; folderNum++) {  // Maksimum 1000 klasör kontrolü
    char folderPath[20];
    sprintf(folderPath, "FAIL/%d", folderNum);
    
    if (!SD.exists(folderPath)) {
      continue;  // Bu klasör yoksa sonrakine geç
    }
    
    File folder = SD.open(folderPath);
    if (!folder) {
      continue;
    }
    
    if (!folder.isDirectory()) {
      folder.close();
      continue;
    }
    
    // Bu klasör içindeki dosyaları sırayla oku ve gönder
    File subFolder = SD.open(folderPath);
    File entry;
    
    // Klasörün içeriğini oku
    // Önce dosyaları bir diziye kaydet
    const int maxFiles = 100;  // Maksimum dosya sayısı
    char fileNames[maxFiles][30];
    int fileCount = 0;
    
    while ((entry = subFolder.openNextFile()) && fileCount < maxFiles) {
      if (!entry.isDirectory()) {
        // Sadece .TXT dosyalarını listeye al
        String fileName = entry.name();
        if (fileName.endsWith(".TXT")) {
          sprintf(fileNames[fileCount], "%s/%s", folderPath, entry.name());
          fileCount++;
        }
      }
      entry.close();
    }
    subFolder.close();
    
    // Dosyaları sırayla gönder
    for (int i = 0; i < fileCount; i++) {
      // Dosyayı oku
      File dataFile = SD.open(fileNames[i]);
      if (!dataFile) {
        continue;
      }
      
      // Dosya içeriğini oku (tüm JSON içeriği değil, sadece "data" kısmını al)
      String fileContent = "";
      bool jsonDataStarted = false;
      String jsonData = "";
      
      while (dataFile.available()) {
        String line = dataFile.readStringUntil('\n');
        fileContent += line + "\n";
          // "data" kısmını bul ve çıkart
        if (line.indexOf("\"data\":") >= 0) {
          int start = line.indexOf("\"data\":");
          start = line.indexOf(":", start) + 1;
          
          // Artık "success" değeri de farklı bir konumda olabilir, sonraki kapama parantezini ara
          int end = line.indexOf(",\"success\":", start);
          if (end == -1) { // Eğer bu formatta değilse sonraki kapama parantezini bul
            end = line.indexOf("}", start);
            if (end == -1) { // Kapama parantezi de yoksa satırın sonuna kadar al
              end = line.length();
            }
          }
          
          if (end > start) {
            jsonData = line.substring(start, end);
          }
        }
      }
      dataFile.close();
      
      // JSON verisi çıkartılabildiyse göndermeyi dene
      if (jsonData.length() > 0) {
        Serial.println("FAIL klasöründen veri gönderiliyor: " + String(fileNames[i]));
        
        // HTTP isteği gönder
        ESP8266_SERIAL.println("AT+CIPSTART=\"TCP\",\"192.168.0.39\",8000");
        delay(2000);
        
        String httpRequest = 
          "POST /api/sensors/data HTTP/1.1\r\n"
          "Host: 192.168.0.39:8000\r\n"
          "Content-Type: application/json\r\n"
          "Content-Length: " + String(jsonData.length()) + "\r\n\r\n" +
          jsonData;
      
        ESP8266_SERIAL.println("AT+CIPSEND=" + String(httpRequest.length()));
        delay(1000);
        ESP8266_SERIAL.print(httpRequest);
        
        // HTTP yanıtını bekle ve kontrol et
        delay(3000);
        String response = "";
        bool resendSuccess = false;
        
        while(ESP8266_SERIAL.available()) {
          response += ESP8266_SERIAL.readString();
        }
          // HTTP 200 OK yanıtı ve success:true kontrolü
        if((response.indexOf("HTTP/1.1 200 OK") != -1 || response.indexOf("200 OK") != -1) && 
           response.indexOf("\"success\":true") != -1) {
          resendSuccess = true;
          Serial.println("Başarısız veri başarıyla gönderildi");
          
          // Başarıyla gönderilen dosyayı sil
          if (SD.remove(fileNames[i])) {
            Serial.println("Dosya silindi: " + String(fileNames[i]));
            anyFileSent = true;
          } else {
            Serial.println("Dosya silinemedi: " + String(fileNames[i]));
          }
        } else {
          Serial.println("Yeniden gönderim başarısız");
          Serial.println("Yanıt: " + response);
          anySendingFailed = true;
        }
        
        // Her göndermeden sonra biraz bekle
        delay(1000);
      }
    }
    
    // Klasör boşaldıysa klasörü sil
    folder = SD.open(folderPath);
    bool isEmpty = true;
    
    while (entry = folder.openNextFile()) {
      isEmpty = false;
      entry.close();
      break;
    }
    folder.close();
    
    if (isEmpty) {
      if (SD.rmdir(folderPath)) {
        Serial.println("Boş klasör silindi: " + String(folderPath));
      }
    }
  }
  
  // İşlem bittikten sonra CS pinlerini geri ayarla
  digitalWrite(SD_CS, HIGH);   // SD kartı devre dışı bırak
  digitalWrite(TFT_CS, LOW);   // TFT'yi etkinleştir
  
  return anyFileSent;
}

// Sensör uyarılarını gösteren ekran modu
void showSensorAlerts() {
  // TFT'yi etkinleştir
  digitalWrite(SD_CS, HIGH);  // SD kartı devre dışı bırak
  digitalWrite(TFT_CS, LOW);  // TFT'yi etkinleştir
  
  // Ekranı temizle
  tft.fillScreen(ILI9341_BLACK);
  
  // Zaman bilgisini al
  DateTime now = rtc.now();
  
  // Mevcut veri değerlerini hazırla
  float temp = (dataCount > 0) ? tempHistory[dataCount - 1] : 0;
  float hum = (dataCount > 0) ? humHistory[dataCount - 1] : 0;
  int pm25Value = (dataCount > 0) ? pm25History[dataCount - 1] : -1;
  int pm10Value = (dataCount > 0) ? pm10History[dataCount - 1] : -1;
  int co2Value = (dataCount > 0) ? co2History[dataCount - 1] : -1;
  int vocValue = (dataCount > 0) ? vocHistory[dataCount - 1] : -1;
  
  // Sensör güvenlik seviyelerini kontrol et
  int tempStatus = checkSensorLevel(temp, TEMP_SAFE_MIN, TEMP_SAFE_MAX, TEMP_ATTENTION_MIN, TEMP_ATTENTION_MAX);
  int humStatus = checkSensorLevel(hum, HUM_SAFE_MIN, HUM_SAFE_MAX, HUM_ATTENTION_MIN, HUM_ATTENTION_MAX);
  int pm25Status = (pm25Value != -1) ? 
    ((pm25Value <= PM25_SAFE_MAX) ? LEVEL_SAFE : 
     (pm25Value <= PM25_ATTENTION_MAX) ? LEVEL_ATTENTION : LEVEL_DANGEROUS) : LEVEL_SAFE;
  int pm10Status = (pm10Value != -1) ? 
    ((pm10Value <= PM10_SAFE_MAX) ? LEVEL_SAFE : 
     (pm10Value <= PM10_ATTENTION_MAX) ? LEVEL_ATTENTION : LEVEL_DANGEROUS) : LEVEL_SAFE;
  int co2Status = (co2Value != -1) ? 
    ((co2Value <= CO2_SAFE_MAX) ? LEVEL_SAFE : 
     (co2Value <= CO2_ATTENTION_MAX) ? LEVEL_ATTENTION : LEVEL_DANGEROUS) : LEVEL_SAFE;
  int vocStatus = (vocValue != -1) ? 
    ((vocValue <= VOC_SAFE_MAX) ? LEVEL_SAFE : 
     (vocValue <= VOC_ATTENTION_MAX) ? LEVEL_ATTENTION : LEVEL_DANGEROUS) : LEVEL_SAFE;
  
  // Başlık ve zaman bilgisi
  tft.setTextSize(2);
  tft.setTextColor(ILI9341_WHITE);
  tft.setCursor(10, 10);
  tft.print("UYARI DURUMU");
  
  tft.setTextSize(1);
  tft.setCursor(10, 35);
  tft.print("Tarih: ");
  tft.print(now.day());
  tft.print("/");
  tft.print(now.month());
  tft.print("/");
  tft.print(now.year());
  tft.print(" ");
  tft.print(now.hour());
  tft.print(":");
  if (now.minute() < 10) tft.print("0");
  tft.print(now.minute());
  
  // Durum renklerini belirle
  uint16_t attentionColor = 0xFDA0; // Turuncu
  uint16_t dangerColor = ILI9341_RED;
  
  // Başlangıç Y pozisyonu
  int yPos = 60;
  bool anyAlert = false;
  
  tft.setTextSize(2);
  
  // Tüm sensörlerin durumlarını kontrol et ve uyarı varsa göster
  // Sıcaklık uyarısı
  if (tempStatus > LEVEL_SAFE) {
    anyAlert = true;
    tft.setTextColor((tempStatus == LEVEL_ATTENTION) ? attentionColor : dangerColor);
    tft.setCursor(10, yPos);
    tft.print("Sicaklik: ");
    tft.print(temp);
    tft.print(" C");
      tft.setCursor(10, yPos + 25);
    tft.print((tempStatus == LEVEL_ATTENTION) ? "Dikkat! Optimal aralik disinda" : "Tehlikeli! Kritik seviye");
    
    yPos += 70; // Boşluğu arttırdık
  }
  
  // Nem uyarısı
  if (humStatus > LEVEL_SAFE) {
    anyAlert = true;
    tft.setTextColor((humStatus == LEVEL_ATTENTION) ? attentionColor : dangerColor);
    tft.setCursor(10, yPos);
    tft.print("Nem: ");
    tft.print(hum);
    tft.print(" %");
      tft.setCursor(10, yPos + 25);
    tft.print((humStatus == LEVEL_ATTENTION) ? "Dikkat! Optimal aralik disinda" : "Tehlikeli! Kritik seviye");
    
    yPos += 70; // Boşluğu arttırdık
  }
  
  // PM2.5 uyarısı
  if (pm25Status > LEVEL_SAFE && pm25Value != -1) {
    anyAlert = true;
    tft.setTextColor((pm25Status == LEVEL_ATTENTION) ? attentionColor : dangerColor);
    tft.setCursor(10, yPos);
    tft.print("PM2.5: ");
    tft.print(pm25Value);
    tft.print(" ug/m3");
      tft.setCursor(10, yPos + 25);
    tft.print((pm25Status == LEVEL_ATTENTION) ? "Dikkat! Hava kalitesi azaliyor" : "Tehlikeli! Solunum riski");
    
    yPos += 70; // Boşluğu arttırdık
  }
  
  // PM10 uyarısı
  if (pm10Status > LEVEL_SAFE && pm10Value != -1) {
    anyAlert = true;
    tft.setTextColor((pm10Status == LEVEL_ATTENTION) ? attentionColor : dangerColor);
    tft.setCursor(10, yPos);
    tft.print("PM10: ");
    tft.print(pm10Value);
    tft.print(" ug/m3");
      tft.setCursor(10, yPos + 25);
    tft.print((pm10Status == LEVEL_ATTENTION) ? "Dikkat! Hava kalitesi azaliyor" : "Tehlikeli! Solunum riski");
    
    yPos += 70; // Boşluğu arttırdık
  }
  
  // CO2 uyarısı
  if (co2Status > LEVEL_SAFE && co2Value != -1) {
    anyAlert = true;
    tft.setTextColor((co2Status == LEVEL_ATTENTION) ? attentionColor : dangerColor);
    tft.setCursor(10, yPos);
    tft.print("CO2: ");
    tft.print(co2Value);
    tft.print(" ppm");
      tft.setCursor(10, yPos + 25);
    tft.print((co2Status == LEVEL_ATTENTION) ? "Dikkat! Havalandirma gerekli" : "Tehlikeli! Yuksek CO2 seviyesi");
    
    yPos += 70; // Boşluğu arttırdık
  }
  
  // VOC uyarısı
  if (vocStatus > LEVEL_SAFE && vocValue != -1) {
    anyAlert = true;
    tft.setTextColor((vocStatus == LEVEL_ATTENTION) ? attentionColor : dangerColor);
    tft.setCursor(10, yPos);
    tft.print("VOC: ");
    tft.print(vocValue);
    tft.print(" ppb");
      tft.setCursor(10, yPos + 25);
    tft.print((vocStatus == LEVEL_ATTENTION) ? "Dikkat! Kimyasal buhar artiyor" : "Tehlikeli! Yuksek kimyasal seviyesi");
    
    yPos += 70; // Boşluğu arttırdık
  }
  
  // Hiç uyarı yoksa
  if (!anyAlert) {
    tft.setTextColor(ILI9341_GREEN);
    tft.setCursor(10, 120);
    tft.print("Tüm değerler normal");
    tft.setCursor(10, 150);
    tft.print("Güvenli seviyede");
  }
  
  // Bilgi mesajı
  tft.setTextSize(1);
  tft.setTextColor(ILI9341_WHITE);
  tft.setCursor(10, 320);
  tft.print("Son guncelleme: ");
  tft.print(now.hour());
  tft.print(":");
  if (now.minute() < 10) tft.print("0");
  tft.print(now.minute());
  tft.print(":");
  if (now.second() < 10) tft.print("0");
  tft.print(now.second());
}
