import React, { useState, useEffect } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { useTranslation } from 'react-i18next';
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
import { fetchWithAuth } from '../lib/api';
import { SensorData, UserSettings } from '../types';

const Dashboard = () => {
  const { t } = useTranslation();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [currentData, setCurrentData] = useState<SensorData | null>(null);
  const [historicalData, setHistoricalData] = useState<SensorData[]>([]);
  const [settings, setSettings] = useState<UserSettings | null>(null);
  
  // Fetch current sensor data
  useEffect(() => {
    const fetchCurrentData = async () => {
      try {
        setLoading(true);
        const response = await fetchWithAuth(`${import.meta.env.VITE_API_URL || 'http://localhost:8000'}/api/sensors/current`);
        
        if (!response.ok) {
          throw new Error('Failed to fetch current sensor data');
        }
        
        const data = await response.json();
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

  // Fetch historical sensor data
  useEffect(() => {
    const fetchHistoricalData = async () => {
      try {
        setLoading(true);
        const response = await fetchWithAuth(`${import.meta.env.VITE_API_URL || 'http://localhost:8000'}/api/sensors/history`);
        
        if (!response.ok) {
          throw new Error('Failed to fetch historical sensor data');
        }
        
        const data = await response.json();
        
        // Format the data for the chart
        const formattedData = data.map(record => ({
          ...record,
          // Format the timestamp to display time only (HH:MM)
          time: new Date(record.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
        }));
        
        setHistoricalData(formattedData);
      } catch (err) {
        console.error('Error fetching historical sensor data:', err);
        setError('Failed to load historical sensor data');
      } finally {
        setLoading(false);
      }
    };
    
    fetchHistoricalData();
  }, []);

  // Fetch user settings
  useEffect(() => {
    const fetchSettings = async () => {
      try {
        const response = await fetchWithAuth(`${import.meta.env.VITE_API_URL || 'http://localhost:8000'}/api/settings`);
        
        if (!response.ok) {
          throw new Error('Failed to fetch user settings');
        }
        
        const data = await response.json();
        setSettings(data);
      } catch (err) {
        console.error('Error fetching user settings:', err);
        // Don't set error for settings - non-critical
      }
    };
    
    fetchSettings();
  }, []);

  // Use mock data as fallback if API call fails
  const mockData = React.useMemo(() => Array.from({ length: 24 }, (_, i) => ({
    time: `${i}:00`,
    temperature: Math.random() * 10 + 20, // 20-30°C
    humidity: Math.random() * 30 + 40, // 40-70%
    co2: Math.random() * 500 + 400,
    pm25: Math.random() * 30 + 10,
    pm10: Math.random() * 50 + 20,
    voc: Math.random() * 2 + 0.5,
    aqi: Math.floor(Math.random() * 150 + 30),
  })), []);

  // Compute AQI from PM2.5 and PM10 values
  const calculateAQI = (pm25: number, pm10: number) => {
    // Simple AQI calculation - in reality this is much more complex
    const pm25Index = (pm25 / 12) * 50;
    const pm10Index = (pm10 / 55) * 50;
    return Math.max(pm25Index, pm10Index);
  };

  // Get the latest data, either from API or mock data
  const latestData = currentData ? {
    temperature: currentData.temperature,
    humidity: currentData.humidity,
    co2: currentData.co2,
    pm25: currentData.pm25,
    pm10: currentData.pm10,
    voc: currentData.voc,
    aqi: calculateAQI(currentData.pm25, currentData.pm10)
  } : mockData[mockData.length - 1];

  // Determine chart data, either from API or mock data
  const chartData = historicalData.length > 0 ? historicalData : mockData;

  // Get thresholds from settings or use defaults
  const thresholds = settings?.thresholds || {
    co2: 1000,
    pm25: 35,
    pm10: 150,
    voc: 3,
  };

  // Calculate trends (would normally come from analyzing historical data)
  // For demo, using static values
  const tempTrend = 0.5;
  const humidityTrend = -0.2;

  // Set up alerts using actual thresholds
  const co2Alerts = useAlerts(latestData.co2, thresholds.co2, 'co2');
  const pm25Alerts = useAlerts(latestData.pm25, thresholds.pm25, 'pm25');
  const pm10Alerts = useAlerts(latestData.pm10, thresholds.pm10, 'pm10');
  const vocAlerts = useAlerts(latestData.voc, thresholds.voc, 'voc');

  // Combine all alerts
  const allAlerts = [...co2Alerts, ...pm25Alerts, ...pm10Alerts, ...vocAlerts];

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
            <span>{error} - Using cached data.</span>
          </div>
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <AQIIndicator value={latestData.aqi} />
        <TemperatureIndicator value={latestData.temperature} trend={tempTrend} />
        <HumidityIndicator value={latestData.humidity} trend={humidityTrend} />
        <AlertIndicator alerts={allAlerts} />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <CO2Indicator value={latestData.co2} />
        <PM25Indicator value={latestData.pm25} />
        <PM10Indicator value={latestData.pm10} />
        <VOCIndicator value={latestData.voc} />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h2 className="card-title text-lg">{t('trend.title')}</h2>
            <div className="h-[300px]">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={chartData}>
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
                  <Line 
                    type="monotone" 
                    dataKey="temperature" 
                    stroke="#ff4444" 
                    name={t('sensors.temperature')}
                    strokeWidth={2}
                    dot={false}
                  />
                  <Line 
                    type="monotone" 
                    dataKey="humidity" 
                    stroke="#33b5e5" 
                    name={t('sensors.humidity')}
                    strokeWidth={2}
                    dot={false}
                  />
                  <Line 
                    type="monotone" 
                    dataKey="co2" 
                    stroke="#8884d8" 
                    name={t('sensors.co2')}
                    strokeWidth={2}
                    dot={false}
                  />
                  <Line 
                    type="monotone" 
                    dataKey="pm25" 
                    stroke="#82ca9d" 
                    name={t('sensors.pm25')}
                    strokeWidth={2}
                    dot={false}
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>
        </div>

        <AIPredictions />
      </div>
    </div>
  );
};

export default Dashboard;