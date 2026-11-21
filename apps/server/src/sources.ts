import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';

export interface Source {
  id: string;
  citation: string;
  statut: 'verifie' | 'partiel' | 'non_verifie';
}

/** Lit la bibliothèque de sources depuis docs/science/SOURCES.md (copiée dans l'image). */
export function chargerSources(racine: string): Source[] {
  const candidats = [process.env.SOURCES_PATH, path.join(racine, 'docs/science/SOURCES.md'), path.join(racine, '../../docs/science/SOURCES.md')];
  const fichier = candidats.find((f): f is string => Boolean(f && existsSync(f)));
  if (!fichier) return [];
  return readFileSync(fichier, 'utf8')
    .split(/\r?\n/u)
    .map((ligne) => ligne.match(/^- \*\*\[(S-\d+)\]\*\* (.+)$/u))
    .filter((m): m is RegExpMatchArray => Boolean(m))
    .map((m) => {
      const texte = m[2]!;
      const statut = /— \*\*Non vérifié\*\*/u.test(texte) ? 'non_verifie' : /— \*\*Partiel\*\*/u.test(texte) ? 'partiel' : 'verifie';
      return { id: m[1]!, citation: texte.replace(/\*\*/gu, '').replace(/\s—\s.*$/u, '').trim(), statut };
    });
}
