import { ItemIcon } from '../components/inventory/ItemIcon';
import { Panel } from '../components/ui/Panel';
import { useGame } from '../store/GameContext';
import { entriesOf, itemLabel } from '../utils/inventory';
import './pages.css';

/** Fabrication : matériaux récupérés sur les zombies -> munitions, soins, accessoires. */
export function CraftingPage() {
  const { state, actions } = useGame();
  const { config, player, menu } = state;
  if (!player) return null;

  // Quantités portées (sac + conteneur protégé), comme côté serveur
  const owned = new Map<string, number>();
  for (const [name, count] of [...entriesOf(player.inventory.bag), ...entriesOf(player.inventory.protected)]) {
    owned.set(name, (owned.get(name) ?? 0) + count);
  }

  return (
    <>
      {!menu.inSafe && (
        <p className="hint cut-s">La fabrication se fait en zone safe. Rejoins un abri pour fabriquer.</p>
      )}
      <div className="crafting">
        {(config.recipes ?? []).map((recipe) => {
          const result = config.items[recipe.result.item];
          if (!result) return null;
          const locked = player.level < (recipe.level ?? 1);
          const ingredients = Object.entries(recipe.ingredients);
          const ready = ingredients.every(([name, count]) => (owned.get(name) ?? 0) >= count);
          return (
            <Panel key={recipe.id} className={locked ? 'recipe recipe--locked' : 'recipe'}>
              <div className="recipe__head">
                <span className="recipe__icon cut-s">
                  <ItemIcon name={recipe.result.item} type={result.type} />
                </span>
                <span className="recipe__title">
                  <span className="disp recipe__name">{result.label}</span>
                  <span className="mono muted recipe__count">x{recipe.result.count}</span>
                </span>
                {locked && <span className="chip chip--outline">Niv. {recipe.level}</span>}
              </div>
              <ul className="recipe__ingredients">
                {ingredients.map(([name, count]) => {
                  const have = owned.get(name) ?? 0;
                  return (
                    <li key={name} className={have >= count ? 'recipe__ingredient' : 'recipe__ingredient recipe__ingredient--missing'}>
                      <span>{itemLabel(config, name)}</span>
                      <span className="mono">{have}/{count}</span>
                    </li>
                  );
                })}
              </ul>
              <button
                className="btn btn--primary btn--small cut-s"
                disabled={locked || !ready || !menu.inSafe}
                onClick={() => actions.craft(recipe.id)}
              >
                Fabriquer
              </button>
            </Panel>
          );
        })}
      </div>
    </>
  );
}
