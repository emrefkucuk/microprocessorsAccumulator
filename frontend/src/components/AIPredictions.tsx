import React, { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Thermometer, Droplets, TrendingUp, Wind, Gauge, AlertCircle } from 'lucide-react';
import { format, subHours } from 'date-fns';
import { sensorApi } from '../lib/sensorApi';

interface PredictionData {
  time: string;
  temperature: number;
  humidity: number;
  co2?: number;
  pm25?: number;
  pm10?: number;
  voc?: number;
}

// Helper function to group data by hour and calculate averages
const calculateHourlyAverages = (data) => {
  // Group data by hour (HH:MM)
  const groupedByHour = {};
  
  data.forEach(item => {
    const date = new Date(item.timestamp);
    const timeString = format(date, 'HH:00');
    
    if (!groupedByHour[timeString]) {
      groupedByHour[timeString] = {
        temperature: [],
        humidity: [],
        co2: [],
        pm25: [],
        pm10: [],
        voc: [],
        count: 0,
        timestamp: date.getTime() // Save timestamp for sorting
      };
    }
    
    groupedByHour[timeString].temperature.push(item.temperature);
    groupedByHour[timeString].humidity.push(item.humidity);
    groupedByHour[timeString].co2.push(item.co2);
    groupedByHour[timeString].pm25.push(item.pm25);
    groupedByHour[timeString].pm10.push(item.pm10);
    groupedByHour[timeString].voc.push(item.voc);
    groupedByHour[timeString].count += 1;
  });
  
  // Calculate averages for each hour
  const hourlyData = Object.keys(groupedByHour).map(timeStr => {
    const hourData = groupedByHour[timeStr];
    
    const avgTemperature = hourData.temperature.reduce((a, b) => a + b, 0) / hourData.count;
    const avgHumidity = hourData.humidity.reduce((a, b) => a + b, 0) / hourData.count;
    const avgCO2 = hourData.co2.reduce((a, b) => a + b, 0) / hourData.count;
    const avgPM25 = hourData.pm25.reduce((a, b) => a + b, 0) / hourData.count;
    const avgPM10 = hourData.pm10.reduce((a, b) => a + b, 0) / hourData.count;
    const avgVOC = hourData.voc.reduce((a, b) => a + b, 0) / hourData.count;
    
    return {
      time: timeStr,
      temperature: avgTemperature,
      humidity: avgHumidity,
      co2: avgCO2,
      pm25: avgPM25,
      pm10: avgPM10,
      voc: avgVOC,
      timestamp: hourData.timestamp
    };
  });
  
  // Sort by timestamp
  hourlyData.sort((a, b) => a.timestamp - b.timestamp);
  
  return hourlyData;
};

const AIPredictions = ({ historicalData = [] }) => {
  const { t } = useTranslation();
  const [loading, setLoading] = useState(true);
  const [hourlyData, setHourlyData] = useState<PredictionData[]>([]);
  
  // State for visible metrics
  const [visibleMetrics, setVisibleMetrics] = useState({
    temperature: true,
    humidity: true,
    co2: false,
    pm25: false,
    pm10: false,
    voc: false
  });
  
  // Toggle metric visibility
  const toggleMetric = (metric: string) => {
    setVisibleMetrics(prev => ({
      ...prev,
      [metric]: !prev[metric]
    }));
  };
  
  // Fetch and process data for the last 7 hours
  useEffect(() => {
    const fetchHourlyData = async () => {
      try {
        setLoading(true);
        
        // If historicalData is provided and has enough data, use it
        if (historicalData.length > 0) {
          const averages = calculateHourlyAverages(historicalData);
          if (averages.length > 0) {
            // Take last 7 hours or all if less than 7
            const last7Hours = averages.slice(-7);
            setHourlyData(last7Hours);
            setLoading(false);
            return;
          }
        }
        
        // Otherwise, fetch the last 7 hours data from API
        const endDate = new Date();
        const startDate = subHours(endDate, 7);
        
        // Format dates to ISO strings for API with Turkish time (UTC+3)
        const turkishOffset = 3 * 60 * 60 * 1000; // UTC+3 için 3 saat
        const turkishStartDate = new Date(startDate.getTime() + turkishOffset);
        const turkishEndDate = new Date(endDate.getTime() + turkishOffset);
        
        const formattedStartDate = turkishStartDate.toISOString();
        const formattedEndDate = turkishEndDate.toISOString();
        
        const data = await sensorApi.getHistoricalData(formattedStartDate, formattedEndDate);
        
        if (data.length === 0) {
          // If no data, generate mock data as fallback
          const mockData = Array.from({ length: 7 }, (_, i) => {
            const date = new Date();
            date.setHours(date.getHours() - (6 - i));
            return {
              time: format(date, 'HH:00'),
              temperature: Math.random() * 10 + 20,
              humidity: Math.random() * 30 + 40,
              co2: Math.random() * 500 + 400,
              pm25: Math.random() * 30 + 10,
              pm10: Math.random() * 50 + 20,
              voc: Math.random() * 2 + 0.5
            };
          });
          setHourlyData(mockData);
        } else {
          // Process real data
          const averages = calculateHourlyAverages(data);
          
          // Take the most recent 7 hours (or all if less than 7)
          const last7Hours = averages.slice(-7);
          
          setHourlyData(last7Hours);
        }
      } catch (error) {
        console.error('Error fetching hourly data:', error);
        
        // Fallback to mock data
        const mockData = Array.from({ length: 7 }, (_, i) => {
          const date = new Date();
          date.setHours(date.getHours() - (6 - i));
          return {
            time: format(date, 'HH:00'),
            temperature: Math.random() * 10 + 20,
            humidity: Math.random() * 30 + 40,
            co2: Math.random() * 500 + 400,
            pm25: Math.random() * 30 + 10,
            pm10: Math.random() * 50 + 20,
            voc: Math.random() * 2 + 0.5
          };
        });
        setHourlyData(mockData);
      } finally {
        setLoading(false);
      }
    };
    
    fetchHourlyData();
  }, [historicalData]);

  // Metric configurations
  const metrics = [
    { id: 'temperature', name: t('sensors.temperature'), icon: <Thermometer className="w-4 h-4 text-error" />, unit: '°C', format: (val) => val.toFixed(1) },
    { id: 'humidity', name: t('sensors.humidity'), icon: <Droplets className="w-4 h-4 text-info" />, unit: '%', format: (val) => val.toFixed(1) },
    { id: 'co2', name: t('sensors.co2'), icon: <Wind className="w-4 h-4 text-primary" />, unit: 'ppm', format: (val) => Math.round(val) },
    { id: 'pm25', name: t('sensors.pm25'), icon: <AlertCircle className="w-4 h-4 text-success" />, unit: 'μg/m³', format: (val) => val.toFixed(1) },
    { id: 'pm10', name: t('sensors.pm10'), icon: <AlertCircle className="w-4 h-4 text-warning" />, unit: 'μg/m³', format: (val) => val.toFixed(1) },
    { id: 'voc', name: t('sensors.voc'), icon: <Gauge className="w-4 h-4 text-secondary" />, unit: 'ppb', format: (val) => val.toFixed(2) }
  ];

  return (
    <div className="card bg-base-100 shadow-xl">
      <div className="card-body">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <TrendingUp className="w-5 h-5 text-primary" />
            <h2 className="card-title text-lg">{t('predictions.title')} ({t('predictions.last7Hours')})</h2>
          </div>
        </div>
        
        <div className="flex flex-wrap gap-2 mt-2 mb-4">
          {metrics.map(metric => (
            <div key={metric.id} className="form-control">
              <label className="cursor-pointer label gap-2">
                <input
                  type="checkbox"
                  className="checkbox checkbox-sm checkbox-primary"
                  checked={visibleMetrics[metric.id]}
                  onChange={() => toggleMetric(metric.id)}
                />
                <span className="label-text">{metric.name}</span>
              </label>
            </div>
          ))}
        </div>
        
        {loading ? (
          <div className="flex justify-center items-center py-8">
            <div className="loading loading-spinner loading-md"></div>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="table table-zebra w-full">
              <thead>
                <tr>
                  <th>{t('predictions.time')}</th>
                  {metrics.map(metric => (
                    visibleMetrics[metric.id] && <th key={metric.id}>{metric.name}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {hourlyData.map((prediction, index) => (
                  <tr key={index}>
                    <td>{prediction.time}</td>
                    {metrics.map(metric => (
                      visibleMetrics[metric.id] && (
                        <td key={metric.id}>
                          <div className="flex items-center gap-2">
                            {metric.icon}
                            {metric.format(prediction[metric.id])}{metric.unit}
                          </div>
                        </td>
                      )
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
};

export default AIPredictions;