import { useCallback, useEffect, useState } from 'react';
import { isEnvBrowser } from '../../api/nui';
import { vehicleCustomApi } from '../../api/vehicleCustomApi';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import { useT } from '../../i18n';
import type { NuiMessage } from '../../types/nui';
import type {
  VehicleCustomChoice,
  VehicleCustomColor,
  VehicleCustomMod,
  VehicleCustomOptions,
  VehicleCustomPalettes,
  VehicleCustomProps,
} from '../../types/vehicleCustom';
import { Stepper } from '../creator/controls/Stepper';
import { Logo } from '../ui/Logo';
import { CustomStage } from './CustomStage';
import '../creator/creator.css';
import './vehicleCustom.css';

type TabId = 'colors' | 'body' | 'wheels' | 'extras' | 'performance';

/** Pièces dont la liste change avec le type de jantes */
const WHEEL_MODS = ['23', '24'];

interface VehicleCustomData {
  label: string;
  props: VehicleCustomProps;
  options: VehicleCustomOptions;
  palettes: VehicleCustomPalettes;
}

/** Menu du mécanicien, en mode PvP. Monté en permanence : Lua peut le fermer à tout moment. */
export function VehicleCustom({ onOpenChange }: { onOpenChange: (open: boolean) => void }) {
  const [data, setData] = useState<VehicleCustomData | null>(null);

  const handleMessage = useCallback(
    (message: NuiMessage) => {
      if (message.action !== 'vehicleCustom') return;
      setData(message.data.open ? message.data : null);
      onOpenChange(message.data.open);
    },
    [onOpenChange],
  );
  useNuiMessage(handleMessage);

  const close = () => {
    if (!isEnvBrowser()) return;
    setData(null);
    onOpenChange(false);
  };

  return data ? <VehicleCustomPanel data={data} onClose={close} /> : null;
}

function VehicleCustomPanel({ data, onClose }: { data: VehicleCustomData; onClose: () => void }) {
  const t = useT();
  const [props, setProps] = useState(data.props);
  const [options, setOptions] = useState(data.options);
  const [tab, setTab] = useState<TabId>('colors');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const hasWheels = options.mods.some((mod) => mod.tab === 'wheels');
  const tabs: { id: TabId; label: string }[] = [
    { id: 'colors', label: 'Peinture' },
    { id: 'body', label: 'Carrosserie' },
    ...(hasWheels ? [{ id: 'wheels' as const, label: 'Roues' }] : []),
    { id: 'extras', label: 'Options' },
    ...(options.performance ? [{ id: 'performance' as const, label: 'Performances' }] : []),
  ];

  /** Applique tout de suite sur le véhicule : rien n'est gardé avant « Enregistrer » */
  const change = async (next: VehicleCustomProps) => {
    setProps(next);
    const result = await vehicleCustomApi.preview(next);
    if (result?.options) setOptions(result.options);
  };

  const cancel = useCallback(() => {
    vehicleCustomApi.cancel();
    onClose();
  }, [onClose]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') cancel();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [cancel]);

  const save = async () => {
    setSaving(true);
    setError(null);
    const result = await vehicleCustomApi.save();
    setSaving(false);
    if (!result?.ok) return setError(result?.message ?? t('Le serveur ne répond pas.'));
    onClose();
  };

  const label = t(data.label);

  return (
    <div className="creator vehicle-custom">
      <aside className="creator-panel">
        <header className="creator-panel__header">
          <Logo size={52} />
          <div className="creator-panel__titles">
            <span className="label">{t('Mécanicien')}</span>
            <h1 className="disp creator-panel__title">{label}</h1>
          </div>
        </header>

        <nav className="creator-tabs">
          {tabs.map((entry) => (
            <button
              key={entry.id}
              className={entry.id === tab ? 'creator-tabs__tab creator-tabs__tab--active disp' : 'creator-tabs__tab disp'}
              onClick={() => setTab(entry.id)}
            >
              {t(entry.label)}
            </button>
          ))}
        </nav>

        <div className="creator-panel__body">
          {tab === 'colors' && <ColorsTab props={props} colors={data.palettes.colors} onChange={change} />}
          {tab === 'body' && <ModsTab tab="body" props={props} options={options} onChange={change} empty={t('Pas de pièces de carrosserie pour ce modèle.')} />}
          {tab === 'wheels' && <WheelsTab props={props} options={options} palettes={data.palettes} onChange={change} />}
          {tab === 'extras' && <ExtrasTab props={props} options={options} palettes={data.palettes} onChange={change} />}
          {tab === 'performance' && <PerformanceTab props={props} options={options} onChange={change} />}
        </div>

        <footer className="creator-panel__footer">
          {error && <p className="creator-panel__error">{error}</p>}
          <p className="muted vehicle-custom__note">{t('Gardée pour toutes tes prochaines {vehicle}.', { vehicle: label })}</p>
          <div className="creator-panel__actions">
            <button className="btn cut-s" onClick={cancel} disabled={saving}>
              {t('Annuler')}
            </button>
            <button className="btn btn--primary cut-s creator-panel__confirm" onClick={save} disabled={saving}>
              {saving ? t('Enregistrement…') : t('Enregistrer')}
            </button>
          </div>
        </footer>
      </aside>

      <CustomStage hint={t('[GLISSER] TOURNER AUTOUR DU VÉHICULE')} onRotate={vehicleCustomApi.rotate} />
    </div>
  );
}

interface TabProps {
  props: VehicleCustomProps;
  onChange: (next: VehicleCustomProps) => void;
}

function ColorsTab({ props, colors, onChange }: TabProps & { colors: VehicleCustomColor[] }) {
  const t = useT();
  return (
    <>
      <Colors label={t('Couleur principale')} colors={colors} value={props.primary} onChange={(primary) => onChange({ ...props, primary })} />
      <Colors label={t('Couleur secondaire')} colors={colors} value={props.secondary} onChange={(secondary) => onChange({ ...props, secondary })} />
      <Colors label={t('Reflet nacré')} colors={colors} value={props.pearl} onChange={(pearl) => onChange({ ...props, pearl })} />
    </>
  );
}

function ModsTab({ tab, props, options, onChange, empty }: TabProps & { tab: VehicleCustomMod['tab']; options: VehicleCustomOptions; empty?: string }) {
  const mods = options.mods.filter((mod) => mod.tab === tab);
  if (mods.length === 0) return empty ? <p className="muted">{empty}</p> : null;
  return (
    <>
      {mods.map((mod) => (
        <ModStepper key={mod.id} mod={mod} props={props} onChange={onChange} />
      ))}
    </>
  );
}

function ModStepper({ mod, props, onChange }: TabProps & { mod: VehicleCustomMod }) {
  const t = useT();
  return (
    <Stepper
      label={t(mod.label)}
      // Choix 0 : la pièce d'origine, -1 pour GTA
      value={Math.min((props.mods[mod.id] ?? -1) + 1, mod.options.length - 1)}
      count={mod.options.length}
      format={(value) => mod.options[value]}
      onChange={(value) => onChange({ ...props, mods: { ...props.mods, [mod.id]: value - 1 } })}
    />
  );
}

function WheelsTab({ props, options, palettes, onChange }: TabProps & { options: VehicleCustomOptions; palettes: VehicleCustomPalettes }) {
  const t = useT();
  const changeType = (wheelType: number) => {
    const mods = { ...props.mods };
    for (const id of WHEEL_MODS) if (id in mods) mods[id] = -1;
    onChange({ ...props, wheelType, mods });
  };
  return (
    <>
      {options.isCar && <Choice label={t('Type de jantes')} choices={palettes.wheelTypes} value={props.wheelType} onChange={changeType} />}
      <ModsTab tab="wheels" props={props} options={options} onChange={onChange} />
      <Colors label={t('Couleur des jantes')} colors={palettes.colors} value={props.wheelColor} onChange={(wheelColor) => onChange({ ...props, wheelColor })} />
    </>
  );
}

function ExtrasTab({ props, options, palettes, onChange }: TabProps & { options: VehicleCustomOptions; palettes: VehicleCustomPalettes }) {
  const t = useT();
  return (
    <>
      <Choice label={t('Vitres teintées')} choices={palettes.tints} value={props.tint} onChange={(tint) => onChange({ ...props, tint })} />
      <Choice label={t('Plaque')} choices={palettes.plates} value={props.plate} onChange={(plate) => onChange({ ...props, plate })} />
      {options.liveries > 0 && (
        <Stepper
          label={t('Livrée')}
          value={Math.max(0, props.livery ?? 0)}
          count={options.liveries}
          onChange={(livery) => onChange({ ...props, livery })}
        />
      )}
      <div className="ctl-group">
        <Toggle label={t('Phares xénon')} value={props.xenon} onChange={(xenon) => onChange({ ...props, xenon })} />
        {props.xenon && (
          <Colors label={t('Couleur des phares')} colors={palettes.xenonColors} value={props.xenonColor} onChange={(xenonColor) => onChange({ ...props, xenonColor })} />
        )}
      </div>
      {options.isCar && (
        <div className="ctl-group">
          <Toggle label={t('Néons')} value={props.neon} onChange={(neon) => onChange({ ...props, neon })} />
          {props.neon && (
            <NeonColors label={t('Couleur des néons')} colors={palettes.neonColors} value={props.neonColor} onChange={(neonColor) => onChange({ ...props, neonColor })} />
          )}
        </div>
      )}
    </>
  );
}

function PerformanceTab({ props, options, onChange }: TabProps & { options: VehicleCustomOptions }) {
  const t = useT();
  return (
    <>
      <ModsTab tab="performance" props={props} options={options} onChange={onChange} />
      <Toggle label={t('Turbo')} value={props.turbo} onChange={(turbo) => onChange({ ...props, turbo })} />
    </>
  );
}

/** Choix dans une liste de la config (la valeur enregistrée peut ne pas y être : véhicule jamais customisé) */
function Choice({ label, choices, value, onChange }: { label: string; choices: VehicleCustomChoice[]; value: number; onChange: (id: number) => void }) {
  const t = useT();
  const index = Math.max(0, choices.findIndex((choice) => choice.id === value));
  return (
    <Stepper
      label={label}
      value={index}
      count={choices.length}
      format={(position) => t(choices[position].label)}
      onChange={(position) => onChange(choices[position].id)}
    />
  );
}

function Toggle({ label, value, onChange }: { label: string; value: boolean; onChange: (value: boolean) => void }) {
  const t = useT();
  return (
    <div className="ctl">
      <span className="ctl__label">{label}</span>
      <div className="segmented">
        <button className={value ? 'btn btn--small cut-s' : 'btn btn--small btn--active cut-s'} onClick={() => onChange(false)}>
          {t('Non')}
        </button>
        <button className={value ? 'btn btn--small btn--active cut-s' : 'btn btn--small cut-s'} onClick={() => onChange(true)}>
          {t('Oui')}
        </button>
      </div>
    </div>
  );
}

/** Nuancier, avec le nom de la couleur choisie (elle peut ne pas être dans la liste : couleur d'origine du modèle) */
function Colors({ label, colors, value, onChange }: { label: string; colors: VehicleCustomColor[]; value: number; onChange: (id: number) => void }) {
  const t = useT();
  const current = colors.find((color) => color.id === value);
  return (
    <div className="ctl">
      <span className="ctl__row">
        <span className="ctl__label">{label}</span>
        <span className="mono ctl__value">{current ? t(current.label) : t('D\'origine')}</span>
      </span>
      <div className="swatches vehicle-custom__swatches" role="radiogroup" aria-label={label}>
        {colors.map((color) => (
          <button
            key={color.id}
            role="radio"
            aria-checked={color.id === value}
            aria-label={t(color.label)}
            title={t(color.label)}
            className={color.id === value ? 'swatch swatch--active' : 'swatch'}
            style={{ background: color.hex }}
            onClick={() => onChange(color.id ?? 0)}
          />
        ))}
      </div>
    </div>
  );
}

function NeonColors({ label, colors, value, onChange }: { label: string; colors: VehicleCustomColor[]; value: string; onChange: (hex: string) => void }) {
  const t = useT();
  return (
    <div className="ctl">
      <span className="ctl__label">{label}</span>
      <div className="swatches vehicle-custom__swatches" role="radiogroup" aria-label={label}>
        {colors.map((color) => (
          <button
            key={color.hex}
            role="radio"
            aria-checked={color.hex === value}
            aria-label={t(color.label)}
            title={t(color.label)}
            className={color.hex === value ? 'swatch swatch--active' : 'swatch'}
            style={{ background: color.hex }}
            onClick={() => onChange(color.hex)}
          />
        ))}
      </div>
    </div>
  );
}
