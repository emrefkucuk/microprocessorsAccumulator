import React from 'react';
import { useTranslation } from 'react-i18next';
import { Droplets } from 'lucide-react';
import InfoTooltip from './InfoTooltip';

interface HumidityIndicatorProps {
  value: number;
  trend?: number;
}

const HumidityIndicator: React.FC<HumidityIndicatorProps> = ({ value, trend }) => {
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
          {value.toFixed(1)} <span className="text-sm font-normal opacity-70">{t('units.humidity')}</span>
        </div>
      </div>
    </div>
  );
};

export default HumidityIndicator; 