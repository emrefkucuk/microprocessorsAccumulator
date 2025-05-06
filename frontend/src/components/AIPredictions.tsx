import React from 'react';
import { useTranslation } from 'react-i18next';
import { Thermometer, Droplets, TrendingUp } from 'lucide-react';

interface Prediction {
  date: string;
  temperature: number;
  humidity: number;
}

const mockPredictions: Prediction[] = Array.from({ length: 7 }, (_, i) => {
  const date = new Date();
  date.setDate(date.getDate() + i + 1);
  return {
    date: date.toISOString().split('T')[0],
    temperature: Math.random() * 10 + 20,
    humidity: Math.random() * 30 + 40
  };
});

const AIPredictions = () => {
  const { t } = useTranslation();

  return (
    <div className="card bg-base-100 shadow-xl">
      <div className="card-body">
        <div className="flex items-center gap-2">
          <TrendingUp className="w-5 h-5 text-primary" />
          <h2 className="card-title text-lg">{t('predictions.title')}</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="table table-zebra w-full">
            <thead>
              <tr>
                <th>{t('predictions.date')}</th>
                <th>{t('predictions.temperature')}</th>
                <th>{t('predictions.humidity')}</th>
              </tr>
            </thead>
            <tbody>
              {mockPredictions.map((prediction) => (
                <tr key={prediction.date}>
                  <td>{new Date(prediction.date).toLocaleDateString()}</td>
                  <td>
                    <div className="flex items-center gap-2">
                      <Thermometer className="w-4 h-4 text-error" />
                      {prediction.temperature.toFixed(1)}°C
                    </div>
                  </td>
                  <td>
                    <div className="flex items-center gap-2">
                      <Droplets className="w-4 h-4 text-info" />
                      {prediction.humidity.toFixed(1)}%
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};

export default AIPredictions; 