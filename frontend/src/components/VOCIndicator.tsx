import React from 'react';
import { useTranslation } from 'react-i18next';
import { Wind } from 'lucide-react';
import InfoTooltip from './InfoTooltip';

interface VOCIndicatorProps {
  value: number;
}

const VOCIndicator: React.FC<VOCIndicatorProps> = ({ value }) => {
  const { t } = useTranslation();

  return (
    <div className="card bg-base-100 shadow-xl h-full">
      <div className="card-body p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Wind className="w-5 h-5 text-primary" />
            <div className="flex items-center gap-1">
              <h2 className="card-title text-lg">VOC</h2>
              <InfoTooltip
                title="Uçucu Organik Bileşikler (VOC)"
                description="Havada bulunan organik kimyasal maddeler. Yüksek seviyeler baş ağrısı, mide bulantısı ve göz tahrişine neden olabilir."
                optimalRange="0-500 ppb"
              />
            </div>
          </div>
          <div className="text-2xl font-bold">{Math.round(value)} ppb</div>
        </div>
      </div>
    </div>
  );
};

export default VOCIndicator; 