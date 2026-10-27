import { createContext, useCallback, useContext, useMemo, useRef, useState, type ReactNode } from 'react';
import { creatorApi } from '../api/creatorApi';
import { isEnvBrowser } from '../api/nui';
import { useNuiMessage } from '../hooks/useNuiMessage';
import type {
  Appearance,
  CameraPreset,
  CreatorLimits,
  CreatorMode,
  CreatorPalettes,
  CreatorSchema,
} from '../types/appearance';
import type { NuiMessage } from '../types/nui';

/** Délai minimum entre deux envois de l'apparence au jeu pendant qu'on bouge un curseur */
const APPLY_THROTTLE = 60;

export interface CreatorState {
  open: boolean;
  mode: CreatorMode;
  appearance: Appearance;
  limits: CreatorLimits;
  palettes: CreatorPalettes;
  schema: CreatorSchema;
  camera: CameraPreset;
  saving: boolean;
  error: string | null;
}

export interface CreatorActions {
  update: (change: (appearance: Appearance) => Appearance) => void;
  setCamera: (preset: CameraPreset) => void;
  rotate: (delta: number) => void;
  save: () => Promise<void>;
  cancel: () => void;
}

interface CreatorContextValue {
  state: CreatorState | null;
  actions: CreatorActions;
}

const CreatorContext = createContext<CreatorContextValue | null>(null);

export function useCreator(): CreatorContextValue {
  const context = useContext(CreatorContext);
  if (!context) throw new Error('useCreator doit être utilisé dans <CreatorProvider>');
  return context;
}

export function CreatorProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<CreatorState | null>(null);
  const pending = useRef<Appearance | null>(null);
  const timer = useRef<number | null>(null);

  /** Envoie la dernière apparence au jeu (au plus une fois toutes les APPLY_THROTTLE ms). */
  const flush = useCallback(async () => {
    timer.current = null;
    const appearance = pending.current;
    pending.current = null;
    if (!appearance) return;

    const result = await creatorApi.apply(appearance);
    if (!result) return;
    setState((current) =>
      current && {
        ...current,
        limits: result.limits ?? current.limits,
        appearance: result.appearance ?? current.appearance,
      },
    );
  }, []);

  const handleMessage = useCallback((message: NuiMessage) => {
    if (message.action !== 'creator') return;
    const data = message.data;
    if (!data.open || !data.appearance || !data.limits || !data.palettes || !data.schema) {
      setState(null);
      return;
    }
    setState({
      open: true,
      mode: data.mode ?? 'create',
      appearance: data.appearance,
      limits: data.limits,
      palettes: data.palettes,
      schema: data.schema,
      camera: 'body',
      saving: false,
      error: null,
    });
  }, []);

  useNuiMessage(handleMessage);

  const actions = useMemo<CreatorActions>(
    () => ({
      update: (change) => {
        setState((current) => {
          if (!current) return current;
          const appearance = change(current.appearance);
          pending.current = appearance;
          if (timer.current === null) timer.current = window.setTimeout(flush, APPLY_THROTTLE);
          return { ...current, appearance, error: null };
        });
      },
      setCamera: (preset) => {
        setState((current) => current && { ...current, camera: preset });
        creatorApi.camera(preset);
      },
      rotate: (delta) => {
        creatorApi.rotate(delta);
      },
      save: async () => {
        setState((current) => current && { ...current, saving: true, error: null });
        const result = await creatorApi.save();
        if (result?.ok) {
          if (isEnvBrowser()) setState(null);
          return;
        }
        setState((current) => current && { ...current, saving: false, error: result?.message ?? 'Erreur.' });
      },
      cancel: () => {
        creatorApi.cancel();
        if (isEnvBrowser()) setState(null);
      },
    }),
    [flush],
  );

  const value = useMemo(() => ({ state, actions }), [state, actions]);

  return <CreatorContext.Provider value={value}>{children}</CreatorContext.Provider>;
}
