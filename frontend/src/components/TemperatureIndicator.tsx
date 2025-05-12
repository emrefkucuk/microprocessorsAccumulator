import React from 'react';
import { useTranslation } from 'react-i18next';
import { Thermometer } from 'lucide-react';
import InfoTooltip from './InfoTooltip';

interface TemperatureIndicatorProps {
  value: number;
  trend: number;
  timestamp?: Date | string | null;
}

const TemperatureIndicator: React.FC<TemperatureIndicatorProps> = ({ value, trend, timestamp }) => {
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
                timestamp={timestamp}
              />
            </h2>
          </div>
          <div className="text-2xl font-bold">{value.toFixed(1)}°C</div>
        </div>
        <div className="mt-2">
          <div className={`text-sm ${trend > 0 ? 'text-error' : trend < 0 ? 'text-info' : 'text-base-content'}`}>
            {trend > 0 ? (
              <span>↑ {t('sensors.increasing')}</span>
            ) : trend < 0 ? (
              <span>↓ {t('sensors.decreasing')}</span>
            ) : (
              <span>→ {t('sensors.stable')}</span>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default TemperatureIndicator;