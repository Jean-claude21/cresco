-- Usual exercises at the pulleys and the Smith machine that the catalog did not have yet, so that
-- every station of "Ma salle" has its movements shown by the coach (docs/design/medias/coach-mouvements).
insert into exercice (id, nom, nom_en, muscles_primaires, muscles_secondaires, materiel, pas_kg, consignes) values
('curl-poulie', 'Curl à la poulie basse', 'Cable Biceps Curl', '{biceps}', '{avant_bras}', 'poulie', 2.5, 'Coudes collés au corps, monte la poignée vers les épaules, redescends lentement.'),
('elevations-laterales-poulie', 'Élévations latérales à la poulie', 'Cable Lateral Raise', '{epaules}', '{}', 'poulie', 1.25, 'Poulie basse côté opposé, coude légèrement fléchi, monte jusqu’à l’horizontale.'),
('tirage-bras-tendus-poulie', 'Tirage bras tendus à la poulie', 'Straight-Arm Pulldown', '{dos}', '{triceps}', 'poulie', 2.5, 'Buste légèrement penché, bras presque tendus, ramène la barre vers les cuisses.'),
('extension-triceps-nuque-poulie', 'Extension triceps nuque à la poulie', 'Overhead Cable Triceps Extension', '{triceps}', '{}', 'poulie', 2.5, 'Dos à la poulie, coudes près de la tête, tends les bras vers l’avant et le haut.'),
('kickback-fessier-poulie', 'Kickback fessier à la poulie', 'Cable Glute Kickback', '{fessiers}', '{ischios}', 'poulie', 1.25, 'Sangle à la cheville, buste penché, pousse la jambe en arrière sans cambrer.'),
('bucheron-poulie', 'Bûcheron à la poulie', 'Cable Woodchop', '{abdominaux}', '{epaules}', 'poulie', 2.5, 'Bras tendus, tourne le buste de la poulie haute vers la hanche opposée, hanches stables.'),
('oiseau-poulie', 'Oiseau à la poulie', 'Cable Rear Delt Fly', '{epaules}', '{dos}', 'poulie', 1.25, 'Câbles croisés, bras presque tendus, ouvre vers l’arrière à hauteur d’épaules.'),
('ecarte-poulie-basse', 'Écarté à la poulie basse', 'Low-to-High Cable Fly', '{pectoraux}', '{epaules}', 'vis-a-vis', 2.5, 'Poulies basses, monte les mains en arc jusqu’à les réunir devant le haut de la poitrine.'),
('developpe-militaire-smith', 'Développé militaire à la Smith machine', 'Smith Machine Shoulder Press', '{epaules}', '{triceps}', 'smith', 2.5, 'Assis sur un banc droit, barre devant le visage, pousse jusqu’au-dessus de la tête.'),
('fentes-smith', 'Fentes à la Smith machine', 'Smith Machine Split Squat', '{quadriceps,fessiers}', '{ischios}', 'smith', 2.5, 'Un pied devant, un derrière, descends le genou arrière près du sol, buste droit.'),
('hip-thrust-smith', 'Hip thrust à la Smith machine', 'Smith Machine Hip Thrust', '{fessiers}', '{ischios}', 'smith', 2.5, 'Haut du dos sur un banc, barre sur les hanches, monte le bassin jusqu’à l’alignement.'),
('mollets-smith', 'Mollets debout à la Smith machine', 'Smith Machine Calf Raise', '{mollets}', '{}', 'smith', 2.5, 'Avant des pieds sur une cale, barre sur les épaules, monte sur la pointe puis descends bas.'),
('rowing-smith', 'Rowing à la Smith machine', 'Smith Machine Bent-Over Row', '{dos}', '{biceps,lombaires}', 'smith', 2.5, 'Buste penché dos plat, tire la barre vers le nombril, coudes le long du corps.')
on conflict (id) do update set nom = excluded.nom, nom_en = excluded.nom_en, muscles_primaires = excluded.muscles_primaires,
  muscles_secondaires = excluded.muscles_secondaires, materiel = excluded.materiel, pas_kg = excluded.pas_kg, consignes = excluded.consignes;
