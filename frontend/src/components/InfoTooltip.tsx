import React from 'react';
import { Info } from 'lucide-react';

interface InfoTooltipProps {
  title: string;
  description: string;
  optimalRange: string;
}

const InfoTooltip: React.FC<InfoTooltipProps> = ({ title, description, optimalRange }) => {
  return (
    <div className="group relative inline-block">
      <Info className="w-3 h-3 text-gray-400 cursor-help" />
      <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 hidden group-hover:block w-64 bg-gray-800 text-white text-xs rounded-lg p-2 z-50">
        <div className="font-semibold mb-1">{title}</div>
        <div className="text-gray-300 mb-1">{description}</div>
        <div className="text-xs text-gray-400">
          <span className="font-medium">Optimum Aralık:</span> {optimalRange}
        </div>
        <div className="absolute bottom-0 left-1/2 transform -translate-x-1/2 translate-y-1/2 rotate-45 w-2 h-2 bg-gray-800"></div>
      </div>
    </div>
  );
};

export default InfoTooltip; 