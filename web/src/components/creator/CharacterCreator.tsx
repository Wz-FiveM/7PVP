import { useState, type ComponentType } from 'react';
import { useCreator } from '../../store/CreatorProvider';
import type { CameraPreset } from '../../types/appearance';
import { Logo } from '../ui/Logo';
import { CreatorStage } from './CreatorStage';
import { FaceSection } from './sections/FaceSection';
import { HairSection } from './sections/HairSection';
import { HeritageSection } from './sections/HeritageSection';
import { OutfitSection } from './sections/OutfitSection';
import { SkinSection } from './sections/SkinSection';
import './creator.css';

/** Onglets du créateur, avec la caméra la plus adaptée à chacun */
const TABS: { id: string; label: string; camera: CameraPreset; component: ComponentType }[] = [
  { id: 'heritage', label: 'Origines', camera: 'face', component: HeritageSection },
  { id: 'face', label: 'Visage', camera: 'face', component: FaceSection },
  { id: 'hair', label: 'Pilosité', camera: 'face', component: HairSection },
  { id: 'skin', label: 'Peau', camera: 'face', component: SkinSection },
  { id: 'outfit', label: 'Tenue', camera: 'body', component: OutfitSection },
];

export function CharacterCreator() {
  const { state, actions } = useCreator();
  const [tabId, setTabId] = useState(TABS[0].id);
  if (!state) return null;

  const tab = TABS.find((t) => t.id === tabId)!;
  const Section = tab.component;
  const isEdit = state.mode === 'edit';

  const selectTab = (id: string) => {
    const next = TABS.find((t) => t.id === id)!;
    setTabId(id);
    if (next.camera !== state.camera) actions.setCamera(next.camera);
  };

  return (
    <div className="creator">
      <aside className="creator-panel">
        <header className="creator-panel__header">
          <Logo size={52} />
          <div className="creator-panel__titles">
            <span className="label">{isEdit ? 'Apparence' : 'Nouvel opérateur'}</span>
            <h1 className="disp creator-panel__title">{isEdit ? 'Modifier le personnage' : 'Création du personnage'}</h1>
          </div>
        </header>

        <nav className="creator-tabs">
          {TABS.map((t) => (
            <button
              key={t.id}
              className={t.id === tabId ? 'creator-tabs__tab creator-tabs__tab--active disp' : 'creator-tabs__tab disp'}
              onClick={() => selectTab(t.id)}
            >
              {t.label}
            </button>
          ))}
        </nav>

        <div className="creator-panel__body">
          <Section />
        </div>

        <footer className="creator-panel__footer">
          {state.error && <p className="creator-panel__error">{state.error}</p>}
          <div className="creator-panel__actions">
            {isEdit && (
              <button className="btn cut-s" onClick={actions.cancel} disabled={state.saving}>
                Annuler
              </button>
            )}
            <button className="btn btn--primary cut-s creator-panel__confirm" onClick={actions.save} disabled={state.saving}>
              {state.saving ? 'Enregistrement…' : isEdit ? 'Enregistrer' : 'Entrer dans la zone'}
            </button>
          </div>
        </footer>
      </aside>

      <CreatorStage />
    </div>
  );
}
