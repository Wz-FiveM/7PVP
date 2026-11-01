import { useState } from 'react';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import { useT } from '../../i18n';
import type { NuiMessage } from '../../types/nui';
import { Icon } from '../icons/Icon';
import './voice.css';

type VoiceData = Extract<NuiMessage, { action: 'voice' }>['data'];

/** Chat vocal : qui entend le joueur quand il parle, et ses coéquipiers qui parlent. Rien tant que personne ne parle. */
export function VoiceIndicator() {
  const t = useT();
  const [voice, setVoice] = useState<VoiceData | null>(null);

  useNuiMessage((message) => {
    if (message.action === 'voice') setVoice(message.data);
  });

  if (!voice || (!voice.talking && voice.speakers.length === 0)) return null;

  const audience = voice.team ? (voice.proximity ? t('Équipe + proximité') : t('Équipe')) : t('Proximité');
  return (
    <div className="voice">
      {voice.talking && (
        <div className="voice__row voice__row--me cut-s">
          <Icon name="mic" size={14} strokeWidth={2.2} />
          {audience}
        </div>
      )}
      {voice.speakers.map((name) => (
        <div key={name} className="voice__row cut-s">
          <Icon name="mic" size={14} strokeWidth={2.2} />
          {name}
        </div>
      ))}
    </div>
  );
}
