import { Component, type ErrorInfo, type ReactNode } from 'react';
import { fetchNui } from '../../api/nui';

interface UiGuardProps {
  /** nom de la partie de l'interface (journal) */
  name: string;
  /** rend la main au jeu si cette partie avait le focus (ferme le menu côté Lua) */
  onCrash?: () => void;
  children: ReactNode;
}

interface UiGuardState {
  failed: boolean;
  attempts: number;
}

const RETRY_DELAY = 1500;
const MAX_ATTEMPTS = 3;

/**
 * Isole une partie de l'interface : si elle plante, elle seule disparaît (sans emporter tout
 * l'écran ni garder le curseur), l'erreur part dans les journaux du jeu et du serveur, puis elle
 * est remontée peu après (quelques essais).
 */
export class UiGuard extends Component<UiGuardProps, UiGuardState> {
  state: UiGuardState = { failed: false, attempts: 0 };
  private retryTimer?: number;

  static getDerivedStateFromError(): Partial<UiGuardState> {
    return { failed: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error(`[7PVP] interface « ${this.props.name} »`, error, info.componentStack);
    void fetchNui('uiError', {
      name: this.props.name,
      message: String(error?.message ?? error),
      stack: (info.componentStack ?? '').trim().split('\n').slice(0, 5).join('\n'),
    });
    this.props.onCrash?.();
    if (this.state.attempts < MAX_ATTEMPTS) {
      this.retryTimer = window.setTimeout(
        () => this.setState((current) => ({ failed: false, attempts: current.attempts + 1 })),
        RETRY_DELAY,
      );
    }
  }

  componentWillUnmount() {
    window.clearTimeout(this.retryTimer);
  }

  render() {
    return this.state.failed ? null : this.props.children;
  }
}
