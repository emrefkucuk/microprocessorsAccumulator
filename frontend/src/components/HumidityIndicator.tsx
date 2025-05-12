import React from 'react';
import { useTranslation } from 'react-i18next';
import { Droplets } from 'lucide-react';
import InfoTooltip from './InfoTooltip';

interface HumidityIndicatorProps {
  value: number;
  trend: number;
  timestamp?: Date | string | null;
}

const HumidityIndicator: React.FC<HumidityIndicatorProps> = ({ value, trend, timestamp }) => {
  const { t } = useTranslation();

  return (
    <div className="card bg-base-100 shadow-xl h-full">
      <div className="card-body p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Droplets className="w-5 h-5 text-info" />
            <h2 className="card-title text-lg">
              {t('sensors.humidity')}
              <InfoTooltip
                title="Nem"
                description="Havadaki nem oranı. Düşük nem cilt kuruluğuna, yüksek nem küf ve bakteri üremesine neden olabilir."
                optimalRange="40-60%"
                timestamp={timestamp}
              />
            </h2>
          </div>
          <div className="text-2xl font-bold">{Math.round(value)}%</div>
        </div>
        <div className="mt-2">
          <div className={`text-sm ${trend > 0 ? 'text-info' : trend < 0 ? 'text-warning' : 'text-base-content'}`}>
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

export default HumidityIndicator;