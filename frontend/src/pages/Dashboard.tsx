import React, { useState, useEffect } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from 'recharts';
import { useTranslation } from 'react-i18next';
import { format, subHours } from 'date-fns';
import AQIIndicator from '../components/AQIIndicator';
import TemperatureIndicator from '../components/TemperatureIndicator';
import HumidityIndicator from '../components/HumidityIndicator';
import CO2Indicator from '../components/CO2Indicator';
import PM25Indicator from '../components/PM25Indicator';
import PM10Indicator from '../components/PM10Indicator';
import VOCIndicator from '../components/VOCIndicator';
import AIPredictions from '../components/AIPredictions';
import AlertIndicator from '../components/AlertIndicator';
import { useAlerts } from '../hooks/useAlerts';
import { sensorApi } from '../lib/sensorApi';
import { settingsApi } from '../lib/settingsApi';
import { SensorData, UserSettings } from '../types';
import { useAuth } from '../hooks/useAuth';

const convertToTurkishTime = (date: Date) => {
  const turkishOffset = 3 * 60 * 60 * 1000; // UTC+3
  const turkishDate = new Date(date.getTime() + turkishOffset);
  return turkishDate.toISOString();
};

const Dashboard = () => {
  const { t } = useTranslation();
  const { isAuthenticated } = useAuth();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [currentData, setCurrentData] = useState<SensorData | null>(null);
  const [historicalData, setHistoricalData] = useState<SensorData[]>([]);
  const [settings, setSettings] = useState<UserSettings | null>(null);
  
  // State for chart metric visibility
  const [visibleMetrics, setVisibleMetrics] = useState({
    temperature: true,
    humidity: true,
    co2: true,
    pm25: true,
    pm10: true,
    voc: true
  });
  
  // Fetch current sensor data
  useEffect(() => {
    const fetchCurrentData = async () => {
      try {
        setLoading(true);
        const data = await sensorApi.getCurrentData();
        setCurrentData(data);
      } catch (err) {
        console.error('Error fetching current sensor data:', err);
        setError('Failed to load current sensor data');
      } finally {
        setLoading(false);
      }
    };
    
    fetchCurrentData();
    
    // Refresh data every 30 seconds
    const intervalId = setInterval(fetchCurrentData, 30000);
    
    return () => clearInterval(intervalId);
  }, []);

  // Fetch historical sensor data for the last 24 hours
  useEffect(() => {
    const fetchHistoricalData = async () => {
      try {
        setLoading(true);
        
        // Calculate date range for the last 24 hours
        const endDate = new Date();
        const startDate = subHours(endDate, 24);
        
        // Format dates to ISO strings for API with Turkish time (UTC+3)
        const formattedStartDate = convertToTurkishTime(startDate);
        const formattedEndDate = convertToTurkishTime(endDate);
        
        // Pass date range to API
        const data = await sensorApi.getHistoricalData(formattedStartDate, formattedEndDate);
        
        // Format the data for the chart
        const formattedData = data.map(record => ({
          ...record,
          // Format the timestamp to display time only (HH:MM)
          time: new Date(record.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
          originalTimestamp: new Date(record.timestamp).getTime()
        }));
        
        // Sort by timestamp to ensure chronological order
        const sortedData = [...formattedData].sort((a, b) => 
          a.originalTimestamp - b.originalTimestamp
        );
        
        setHistoricalData(sortedData);
      } catch (err) {
        console.error('Error fetching historical sensor data:', err);
        setError('Failed to load historical sensor data');
      } finally {
        setLoading(false);
      }
    };
    
    fetchHistoricalData();
  }, []);

  // Fetch user settings - sadece giriş yapmış kullanıcılar için
  useEffect(() => {
    const fetchSettings = async () => {
      if (!isAuthenticated) return;
      
      try {
        const data = await settingsApi.getSettings();
        setSettings(data);
      } catch (err) {
        console.error('Error fetching user settings:', err);
        // Don't set error for settings - non-critical
      }
    };
    
    fetchSettings();
  }, [isAuthenticated]);

  // Toggle visibility of a metric in the chart
  const toggleMetricVisibility = (metric: string) => {
    setVisibleMetrics(prev => ({
      ...prev,
      [metric]: !prev[metric]
    }));
  };

  // Compute AQI from PM2.5 and PM10 values
  const calculateAQI = (pm25: number, pm10: number) => {
    // Simple AQI calculation - in reality this is much more complex
    const pm25Index = (pm25 / 12) * 50;
    const pm10Index = (pm10 / 55) * 50;
    return Math.max(pm25Index, pm10Index);
  };

  // Get the latest data from actual data or generate default values
  const getLatestData = () => {
    if (currentData) {
      return {
        temperature: currentData.temperature,
        humidity: currentData.humidity,
        co2: currentData.co2,
        pm25: currentData.pm25,
        pm10: currentData.pm10,
        voc: currentData.voc,
        aqi: calculateAQI(currentData.pm25, currentData.pm10)
      };
    }
    
    // Default values if no data available
    return {
      temperature: 22.5,
      humidity: 45.0,
      co2: 600,
      pm25: 15,
      pm10: 30,
      voc: 1.2,
      aqi: 60
    };
  };

  // Get the latest data
  const latestData = getLatestData();

  // Get thresholds from settings or use defaults
  const thresholds = settings?.thresholds || {
    co2: 1000,
    pm25: 35,
    pm10: 150,
    voc: 3,
  };

  // Calculate trends by analyzing the last few data points
  const calculateTrend = (metric: string) => {
    if (historicalData.length < 2) return 0;
    
    const lastFivePoints = [...historicalData]
      .slice(-5)
      .map(data => data[metric] as number);
    
    if (lastFivePoints.length < 2) return 0;
    
    const first = lastFivePoints[0];
    const last = lastFivePoints[lastFivePoints.length - 1];
    
    return last > first ? 0.5 : last < first ? -0.5 : 0;
  };

  // Calculate trends from real data if available
  const tempTrend = calculateTrend('temperature');
  const humidityTrend = calculateTrend('humidity');

  // Set up alerts using actual thresholds
  const co2Alerts = useAlerts(latestData.co2, thresholds.co2, 'co2');
  const pm25Alerts = useAlerts(latestData.pm25, thresholds.pm25, 'pm25');
  const pm10Alerts = useAlerts(latestData.pm10, thresholds.pm10, 'pm10');
  const vocAlerts = useAlerts(latestData.voc, thresholds.voc, 'voc');

  // Combine all alerts
  const allAlerts = [...co2Alerts, ...pm25Alerts, ...pm10Alerts, ...vocAlerts];

  // Chart metrics configuration
  const metrics = [
    { id: 'temperature', name: t('sensors.temperature'), color: '#ff4444', unit: '°C' },
    { id: 'humidity', name: t('sensors.humidity'), color: '#33b5e5', unit: '%' },
    { id: 'co2', name: t('sensors.co2'), color: '#8884d8', unit: 'ppm' },
    { id: 'pm25', name: t('sensors.pm25'), color: '#82ca9d', unit: 'μg/m³' },
    { id: 'pm10', name: t('sensors.pm10'), color: '#ffc658', unit: 'μg/m³' },
    { id: 'voc', name: t('sensors.voc'), color: '#ff8042', unit: 'ppm' }
  ];

  if (loading && !currentData && !historicalData.length) {
    return (
      <div className="flex items-center justify-center h-screen">
        <div className="loading loading-spinner loading-lg"></div>
      </div>
    );
  }

  if (error && !currentData && !historicalData.length) {
    return (
      <div className="alert alert-error shadow-lg m-6">
        <div>
          <svg xmlns="http://www.w3.org/2000/svg" className="stroke-current flex-shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span>{error}</span>
        </div>
        <div className="flex-none">
          <button className="btn btn-sm" onClick={() => window.location.reload()}>Retry</button>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 space-y-6">
      {error && (
        <div className="alert alert-warning shadow-lg mb-4">
          <div>
            <svg xmlns="http://www.w3.org/2000/svg" className="stroke-current flex-shrink-0 h-6 w-6" fill="none" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
            <span>{error}</span>
          </div>
        </div>
      )}

      <div className={`grid grid-cols-1 md:grid-cols-2 ${isAuthenticated ? 'lg:grid-cols-4' : 'lg:grid-cols-3'} gap-4`}>
        <AQIIndicator value={latestData.aqi} timestamp={currentData?.timestamp} />
        <TemperatureIndicator value={latestData.temperature} trend={tempTrend} timestamp={currentData?.timestamp} />
        <HumidityIndicator value={latestData.humidity} trend={humidityTrend} timestamp={currentData?.timestamp} />
        
        {/* Uyarılar kartını sadece giriş yapmış kullanıcılara göster */}
        {isAuthenticated && <AlertIndicator alerts={allAlerts} />}
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <CO2Indicator value={latestData.co2} timestamp={currentData?.timestamp} />
        <PM25Indicator value={latestData.pm25} timestamp={currentData?.timestamp} />
        <PM10Indicator value={latestData.pm10} timestamp={currentData?.timestamp} />
        <VOCIndicator value={latestData.voc} timestamp={currentData?.timestamp} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h2 className="card-title text-lg">{t('trend.title')}</h2>
            
            <div className="h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={historicalData.length > 0 ? historicalData : []}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                  <XAxis 
                    dataKey="time" 
                    stroke="#6b7280"
                    tick={{ fill: '#6b7280' }}
                  />
                  <YAxis 
                    stroke="#6b7280"
                    tick={{ fill: '#6b7280' }}
                  />
                  <Tooltip 
                    contentStyle={{
                      backgroundColor: 'rgba(255, 255, 255, 0.9)',
                      border: '1px solid #e5e7eb',
                      borderRadius: '0.5rem',
                      boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)'
                    }}
                  />
                  <Legend 
                    onClick={(dataEntry) => {
                      // Metrik ID'yi dataKey'den al (daha güvenilir)
                      const metricId = dataEntry.dataKey as string;
                      
                      if (metricId) {
                        toggleMetricVisibility(metricId);
                      }
                    }}
                    wrapperStyle={{ cursor: 'pointer' }}
                    formatter={(value, entry) => {
                      // dataKey doğrudan metrik ID'sini içerir
                      const metricId = entry.dataKey as string;
                      
                      // Style based on active state
                      const style = {
                        color: metricId && visibleMetrics[metricId] ? '#000000' : '#999999',
                        margin: '0 8px',
                        fontWeight: metricId && visibleMetrics[metricId] ? 'bold' : 'normal'
                      };
                      
                      return <span style={style}>{value}</span>;
                    }}
                  />
                  
                  {/* Tüm metrikleri her zaman ekleyin, sadece visible olmayanları gizleyin */}
                  {metrics.map(metric => (
                    <Line 
                      key={metric.id}
                      type="monotone" 
                      dataKey={metric.id} 
                      stroke={metric.color}
                      name={`${metric.name} (${metric.unit})`}
                      strokeWidth={2}
                      dot={false}
                      hide={!visibleMetrics[metric.id]} // visibleMetrics false ise sakla
                    />
                  ))}
                </LineChart>
              </ResponsiveContainer>
            </div>
            
            <div className="mt-2 text-sm text-center text-gray-500">
              {t('trend.legendHelp')}
            </div>
          </div>
        </div>

        <AIPredictions historicalData={historicalData} />
      </div>
    </div>
  );
};

export default Dashboard;