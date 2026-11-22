-- Stations of the full Matrix catalog that Cresco did not have yet (docs/design/medias/machines/CATALOGUE-MATRIX.md).
insert into exercice (id, nom, nom_en, muscles_primaires, muscles_secondaires, materiel, pas_kg, consignes) values
('developpe-disques', 'Développé couché à disques', 'Plate-Loaded Bench Press', '{pectoraux}', '{triceps,epaules}', 'machine', 2.5, 'Dos à plat, poignées au-dessus du bas de la poitrine, pousse sans verrouiller les coudes.'),
('developpe-decline-disques', 'Développé décliné à disques', 'Decline Bench Press', '{pectoraux}', '{triceps}', 'machine', 2.5, 'Pousse vers l’avant et le bas, omoplates serrées contre le dossier.'),
('ecarte-decline-disques', 'Écarté décliné à disques', 'Decline Pec Fly', '{pectoraux}', '{epaules}', 'machine', 2.5, 'Coudes légèrement fléchis, referme les bras au-dessus de la poitrine, retour lent.'),
('dips-assis-machine', 'Dips assis à la machine', 'Seated Dip (Triceps Press)', '{triceps}', '{pectoraux,epaules}', 'machine', 5, 'Buste droit, pousse les poignées vers le bas jusqu’à tendre les bras.'),
('extension-inversee', 'Extension lombaire inversée', 'Reverse Hyperextension', '{lombaires,fessiers}', '{ischios}', 'machine', 2.5, 'Ventre sur le plateau, monte les jambes tendues jusqu’à l’horizontale, sans élan.'),
('squat-fentes-disques', 'Squat et fentes à disques', 'Squat / Lunge Machine', '{quadriceps}', '{fessiers,ischios}', 'machine', 2.5, 'Épaules sous les coussins, descends en gardant le buste droit ; une jambe en avant pour les fentes.'),
('curl-pupitre', 'Curl au pupitre', 'Preacher Curl', '{biceps}', '{avant_bras}', 'pupitre', 2.5, 'Arrière des bras à plat sur le pupitre, descends presque bras tendus, monte sans décoller.'),
('crunch-banc', 'Crunch au banc décliné', 'Decline Bench Crunch', '{abdominaux}', '{}', 'banc-abdos', 0, 'Pieds bloqués, enroule le buste vers les genoux, redescends lentement.'),
('glute-ham-raise', 'Glute ham raise au GHD', 'Glute Ham Raise', '{ischios}', '{fessiers,lombaires}', 'ghd', 0, 'Chevilles bloquées, descends le buste en contrôle puis remonte en tirant avec les ischios.'),
('poussee-traineau', 'Poussée de traîneau', 'Sled Push', '{quadriceps}', '{fessiers,mollets}', 'traineau', 5, 'Bras tendus sur les montants, buste incliné, pousse par petits pas rapides.')
on conflict (id) do update set nom = excluded.nom, nom_en = excluded.nom_en, muscles_primaires = excluded.muscles_primaires,
  muscles_secondaires = excluded.muscles_secondaires, materiel = excluded.materiel, pas_kg = excluded.pas_kg, consignes = excluded.consignes;
