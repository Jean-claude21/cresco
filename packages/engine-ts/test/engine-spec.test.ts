import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { FONCTIONS, type NomFonction } from '../src/index.ts';

interface Cas {
  regle: string;
  fonction: string;
  entree: unknown;
  sortie: Record<string, unknown>;
}
const spec = JSON.parse(readFileSync(new URL('../../../engine-spec/cases.json', import.meta.url), 'utf8')) as {
  tolerance: number;
  cas: Cas[];
};

function compare(attendu: unknown, obtenu: unknown, chemin: string) {
  if (typeof attendu === 'number') {
    expect(typeof obtenu, chemin).toBe('number');
    expect(Math.abs((obtenu as number) - attendu), `${chemin}: ${obtenu} ≠ ${attendu}`).toBeLessThanOrEqual(spec.tolerance);
  } else if (Array.isArray(attendu)) {
    expect(Array.isArray(obtenu), chemin).toBe(true);
    expect((obtenu as unknown[]).length, chemin).toBe(attendu.length);
    attendu.forEach((v, i) => compare(v, (obtenu as unknown[])[i], `${chemin}[${i}]`));
  } else if (attendu && typeof attendu === 'object') {
    for (const [k, v] of Object.entries(attendu)) compare(v, (obtenu as Record<string, unknown>)[k], `${chemin}.${k}`);
  } else {
    expect(obtenu, chemin).toEqual(attendu);
  }
}

describe('engine-spec', () => {
  for (const [i, cas] of spec.cas.entries()) {
    it(`${i} ${cas.regle} ${cas.fonction}`, () => {
      const f = FONCTIONS[cas.fonction as NomFonction] as (e: unknown) => unknown;
      expect(f, `fonction inconnue ${cas.fonction}`).toBeTypeOf('function');
      compare(cas.sortie, f(cas.entree), cas.fonction);
    });
  }
});
