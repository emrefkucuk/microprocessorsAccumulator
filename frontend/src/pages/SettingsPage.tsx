import React, { useState } from 'react';
import { useTranslation } from 'react-i18next';

const SettingsPage: React.FC = () => {
  const { t } = useTranslation();
  const [notifications, setNotifications] = useState(true);
  const [measurementSystem, setMeasurementSystem] = useState<'metric' | 'imperial'>('metric');

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-6">{t('settingsPage.title')}</h1>
      
      <div className="space-y-6">
        {/* Bildirim Ayarları */}
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h2 className="card-title">{t('settingsPage.notifications.title')}</h2>
            <div className="form-control">
              <label className="label cursor-pointer">
                <span className="label-text">{t('settingsPage.notifications.enable')}</span>
                <input
                  type="checkbox"
                  className="toggle toggle-primary"
                  checked={notifications}
                  onChange={(e) => setNotifications(e.target.checked)}
                />
              </label>
            </div>
            <p className="text-sm opacity-70">{t('settingsPage.notifications.description')}</p>
          </div>
        </div>

        {/* Uyarı Eşikleri */}
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h2 className="card-title">{t('settingsPage.thresholds.title')}</h2>
            <div className="space-y-4">
              <div className="form-control">
                <label className="label">
                  <span className="label-text">{t('settingsPage.thresholds.co2')}</span>
                </label>
                <input type="number" className="input input-bordered" placeholder="1000" />
              </div>
              <div className="form-control">
                <label className="label">
                  <span className="label-text">{t('settingsPage.thresholds.pm25')}</span>
                </label>
                <input type="number" className="input input-bordered" placeholder="25" />
              </div>
              <div className="form-control">
                <label className="label">
                  <span className="label-text">{t('settingsPage.thresholds.pm10')}</span>
                </label>
                <input type="number" className="input input-bordered" placeholder="50" />
              </div>
              <div className="form-control">
                <label className="label">
                  <span className="label-text">{t('settingsPage.thresholds.voc')}</span>
                </label>
                <input type="number" className="input input-bordered" placeholder="500" />
              </div>
            </div>
          </div>
        </div>

        {/* Görüntüleme Ayarları */}
        <div className="card bg-base-100 shadow-xl">
          <div className="card-body">
            <h2 className="card-title">{t('settingsPage.display.title')}</h2>
            <div className="form-control">
              <label className="label">
                <span className="label-text">{t('settingsPage.display.system')}</span>
              </label>
              <select
                className="select select-bordered w-full"
                value={measurementSystem}
                onChange={(e) => setMeasurementSystem(e.target.value as 'metric' | 'imperial')}
              >
                <option value="metric">{t('settingsPage.display.metric')}</option>
                <option value="imperial">{t('settingsPage.display.imperial')}</option>
              </select>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default SettingsPage; 