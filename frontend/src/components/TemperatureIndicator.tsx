import React from 'react';
import { useTranslation } from 'react-i18next';
import { Thermometer } from 'lucide-react';
import InfoTooltip from './InfoTooltip';

interface TemperatureIndicatorProps {
  value: number;
  trend?: number;
}

const TemperatureIndicator: React.FC<TemperatureIndicatorProps> = ({ value, trend }) => {
  const { t } = useTranslation();

  return (
    <div className="card bg-base-100 shadow-xl h-full">
      <div className="card-body p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Thermometer className="w-5 h-5 text-error" />
            <h2 className="card-title text-lg">
              {t('sensors.temperature')}
              <InfoTooltip
                title="Sıcaklık"
                description="Ortam sıcaklığı. Yüksek sıcaklıklar rahatsızlık ve sağlık sorunlarına yol açabilir."
                optimalRange="20-25°C"
              />
            </h2>
          </div>
          {trend && (
            <div className={`text-xs ${trend > 0 ? 'text-error' : 'text-success'}`}>
              {trend > 0 ? '↑' : '↓'} {Math.abs(trend)}%
            </div>
          )}
        </div>
        <div className="text-2xl font-bold mt-1">
          {value.toFixed(1)} <span className="text-sm font-normal opacity-70">{t('units.temperature')}</span>
        </div>
      </div>
    </div>
  );
};

export default TemperatureIndicator; 