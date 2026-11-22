-- Machines catalog (22/11/2026): English names next to the French ones (people know the machines
-- by both), the selectorized and plate-loaded machines found in gyms (Matrix Versa/Ultra/Aura and
-- Magnum ranges first, docs/design/medias/machines/LISTE.md), and the exercises of the cable and
-- free stations. Muscles use the slugs of C-PERF-5; pas_kg is the load step of the machine.
alter table exercice add column if not exists nom_en text;

update exercice set nom_en = v.en from (values
  ('developpe-couche-barre', 'Barbell Bench Press'),
  ('developpe-incline-halteres', 'Incline Dumbbell Press'),
  ('developpe-militaire', 'Overhead Press'),
  ('elevations-laterales', 'Dumbbell Lateral Raise'),
  ('tractions', 'Pull-up'),
  ('tirage-vertical', 'Lat Pulldown'),
  ('rowing-barre', 'Barbell Row'),
  ('rowing-assis-poulie', 'Seated Cable Row'),
  ('squat-barre', 'Barbell Back Squat'),
  ('presse-cuisses', '45-Degree Leg Press'),
  ('souleve-de-terre', 'Deadlift'),
  ('souleve-terre-roumain', 'Romanian Deadlift'),
  ('fentes-halteres', 'Dumbbell Lunge'),
  ('leg-curl', 'Lying Leg Curl'),
  ('leg-extension', 'Leg Extension'),
  ('hip-thrust', 'Barbell Hip Thrust'),
  ('mollets-debout', 'Standing Calf Raise'),
  ('curl-halteres', 'Dumbbell Curl'),
  ('extension-triceps-poulie', 'Cable Triceps Pushdown'),
  ('dips', 'Dips'),
  ('pompes', 'Push-up'),
  ('gainage', 'Plank'),
  ('crunch-poulie', 'Cable Crunch'),
  ('course-tapis', 'Treadmill Run'),
  ('velo', 'Stationary Bike'),
  ('rameur', 'Rowing Machine')
) as v(id, en) where exercice.id = v.id;

insert into exercice (id, nom, nom_en, muscles_primaires, muscles_secondaires, materiel, pas_kg, consignes) values
-- Selectorized machines (weight stack).
('developpe-convergent', 'Presse pectorale convergente', 'Converging Chest Press', '{pectoraux}', '{triceps,epaules}', 'machine', 5, 'Poignées à hauteur du milieu de la poitrine, omoplates serrées, pousse sans verrouiller les coudes.'),
('pec-deck', 'Pec deck (écarté à la machine)', 'Pectoral Fly', '{pectoraux}', '{epaules}', 'pec-deck', 5, 'Coudes légèrement fléchis et fixes, rapproche les bras devant toi, retour lent.'),
('oiseau-machine', 'Oiseau inversé à la machine', 'Rear Delt Fly', '{epaules}', '{dos}', 'pec-deck', 5, 'Face au dossier, bras tendus, ouvre vers l’arrière sans hausser les épaules.'),
('developpe-epaules-convergent', 'Presse épaules convergente', 'Converging Shoulder Press', '{epaules}', '{triceps}', 'machine', 5, 'Dos collé au dossier, poignées à hauteur des oreilles, pousse au-dessus de la tête.'),
('tirage-vertical-divergent', 'Tirage vertical divergent', 'Diverging Lat Pulldown', '{dos}', '{biceps}', 'machine', 5, 'Cuisses bloquées, tire les coudes vers les hanches, poitrine sortie.'),
('rowing-divergent', 'Rowing assis divergent', 'Diverging Seated Row', '{dos}', '{biceps,epaules}', 'machine', 5, 'Poitrine contre l’appui, tire les coudes vers l’arrière en serrant les omoplates.'),
('elevations-laterales-machine', 'Élévations latérales à la machine', 'Lateral Raise Machine', '{epaules}', '{}', 'machine', 2.5, 'Coudes contre les coussins, monte jusqu’à l’horizontale, sans hausser les épaules.'),
('traction-assistee', 'Traction assistée', 'Assisted Chin-up', '{dos}', '{biceps}', 'traction-dips-assistes', 5, 'Genoux sur la plateforme, monte le menton au-dessus des poignées ; plus de charge = plus d’aide.'),
('dips-assistes', 'Dips assistés', 'Assisted Dip', '{triceps}', '{pectoraux,epaules}', 'traction-dips-assistes', 5, 'Buste droit, descends jusqu’à 90° aux coudes ; plus de charge = plus d’aide.'),
('pull-over-machine', 'Pull-over à la machine', 'Pullover Machine', '{dos}', '{pectoraux,triceps}', 'machine', 5, 'Coudes sur les coussins, ramène le bras de l’arrière de la tête vers le ventre.'),
('curl-biceps-machine', 'Curl biceps à la machine', 'Biceps Curl Machine', '{biceps}', '{avant_bras}', 'machine', 2.5, 'Arrière des bras à plat sur le pupitre, monte sans décoller les coudes.'),
('extension-triceps-machine', 'Extension triceps à la machine', 'Triceps Extension Machine', '{triceps}', '{}', 'machine', 2.5, 'Arrière des bras sur le pupitre, étends les avant-bras sans bouger les épaules.'),
('abdominaux-machine', 'Crunch à la machine', 'Abdominal Crunch Machine', '{abdominaux}', '{}', 'machine', 5, 'Enroule le buste vers les cuisses, souffle en descendant, retour contrôlé.'),
('rotation-buste', 'Rotation du buste', 'Rotary Torso', '{abdominaux}', '{}', 'machine', 5, 'Bassin fixe, tourne le buste lentement, des deux côtés.'),
('extension-lombaire-machine', 'Extension lombaire à la machine', 'Back Extension Machine', '{lombaires}', '{fessiers,ischios}', 'machine', 5, 'Pousse le dossier vers l’arrière depuis les hanches, sans cambrer en fin de mouvement.'),
('presse-cuisses-assise', 'Presse à cuisses assise', 'Seated Leg Press', '{quadriceps}', '{fessiers,ischios}', 'machine', 5, 'Pieds largeur de hanches, descends à 90° aux genoux, ne verrouille pas.'),
('leg-curl-assis', 'Leg curl assis', 'Seated Leg Curl', '{ischios}', '{mollets}', 'machine', 5, 'Genoux alignés sur l’axe, boudin au-dessus des chevilles, ramène les talons sous le siège.'),
('adducteurs-machine', 'Adducteurs à la machine', 'Hip Adductor', '{fessiers}', '{}', 'adducteurs-abducteurs', 5, 'Serre les jambes lentement, sans rebond en fin de mouvement.'),
('abducteurs-machine', 'Abducteurs à la machine', 'Hip Abductor', '{fessiers}', '{}', 'adducteurs-abducteurs', 5, 'Écarte les jambes en gardant le dos au dossier, retour lent.'),
('fessiers-machine', 'Machine fessiers (kickback)', 'Glute Kickback Machine', '{fessiers}', '{ischios}', 'machine', 5, 'Buste en appui, pousse la jambe vers l’arrière sans cambrer le bas du dos.'),
('mollets-assis-guidee', 'Mollets à la machine guidée', 'Calf Extension Machine', '{mollets}', '{}', 'machine', 5, 'Avant des pieds sur la cale, descends les talons puis monte au maximum.'),
('presse-inclinee-machine', 'Presse inclinée poitrine', 'Incline Chest Press', '{pectoraux}', '{epaules,triceps}', 'machine', 5, 'Poignées à hauteur du haut de la poitrine, pousse vers le haut et l’avant.'),
-- Plate-loaded machines.
('hack-squat', 'Hack squat', 'Hack Squat', '{quadriceps}', '{fessiers}', 'machine', 2.5, 'Dos collé au dossier, pieds au milieu du plateau, descends sous la parallèle si tu le peux.'),
('pendulum-squat', 'Pendulum squat', 'Pendulum Squat', '{quadriceps}', '{fessiers}', 'machine', 2.5, 'Épaules sous les coussins, descends profond en gardant les talons au sol.'),
('belt-squat', 'Belt squat', 'Belt Squat', '{quadriceps}', '{fessiers,ischios}', 'machine', 2.5, 'Ceinture aux hanches, buste droit, squat sans charge sur le dos.'),
('leg-extension-inclinee', 'Leg extension inclinée', 'Reclining Leg Extension', '{quadriceps}', '{}', 'machine', 2.5, 'Dos incliné, étends les jambes complètement, retour lent.'),
('leg-curl-genoux', 'Leg curl à genoux', 'Kneeling Leg Curl', '{ischios}', '{}', 'machine', 2.5, 'Un genou sur le coussin, ramène le talon vers la fesse, une jambe après l’autre.'),
('hip-thrust-machine', 'Hip thrust à la machine', 'Standing Hip Thrust', '{fessiers}', '{ischios}', 'machine', 2.5, 'Coussin sur les hanches, pousse le bassin vers l’avant jusqu’à l’extension, serre les fessiers.'),
('mollets-assis-disques', 'Mollets assis à disques', 'Seated Calf Raise', '{mollets}', '{}', 'machine', 2.5, 'Coussins sur le bas des cuisses, amplitude complète des talons.'),
('rowing-bas-disques', 'Rowing bas à disques', 'Low Row', '{dos}', '{biceps}', 'machine', 2.5, 'Poitrine contre l’appui, tire les poignées vers le bas du ventre.'),
('rowing-haut-disques', 'Rowing haut à disques', 'High Row', '{dos}', '{biceps}', 'machine', 2.5, 'Tire d’en haut vers les épaules, coudes vers le bas et l’arrière.'),
('rowing-incline-levier', 'Rowing incliné à levier', 'Incline Lever Row', '{dos}', '{biceps,epaules}', 'machine', 2.5, 'Poitrine sur l’appui incliné, tire le levier vers le ventre.'),
('rowing-t-bar', 'Rowing T-bar', 'T-Bar Row', '{dos}', '{biceps,lombaires}', 'machine', 2.5, 'Poitrine contre l’appui, tire la barre vers la poitrine, dos neutre.'),
('curl-biceps-surleve', 'Curl biceps surélevé à disques', 'Elevated Biceps Curl', '{biceps}', '{avant_bras}', 'machine', 2.5, 'Bras sur le pupitre haut, monte sans balancer.'),
-- Cable and free stations, and machines shared by two exercises: their equipment is a material
-- of "Ma salle" (pec-deck, traction-dips-assistes, adducteurs-abducteurs, poulie, vis-a-vis, smith…).
('ecarte-vis-a-vis', 'Écarté à la poulie vis-à-vis', 'Cable Crossover Fly', '{pectoraux}', '{epaules}', 'vis-a-vis', 2.5, 'Un pas en avant, coudes légèrement fléchis, croise les mains devant toi.'),
('tirage-visage-poulie', 'Tirage visage à la poulie', 'Cable Face Pull', '{epaules}', '{dos}', 'poulie', 2.5, 'Corde à hauteur des yeux, tire vers le visage en ouvrant les coudes.'),
('squat-smith', 'Squat à la Smith machine', 'Smith Machine Squat', '{quadriceps}', '{fessiers}', 'smith', 2.5, 'Barre sur le haut du dos, pieds un peu en avant, descends à la parallèle.'),
('developpe-couche-smith', 'Développé couché à la Smith machine', 'Smith Machine Bench Press', '{pectoraux}', '{triceps,epaules}', 'smith', 2.5, 'Barre au-dessus du bas de la poitrine, crochets de sécurité réglés juste au-dessus.'),
('releve-jambes-chaise', 'Relevés de jambes à la chaise romaine', 'Captain’s Chair Leg Raise', '{abdominaux}', '{}', 'chaise-romaine', 0, 'Dos contre l’appui, monte les genoux vers la poitrine sans balancer.'),
('extension-lombaire-45', 'Extension lombaire au banc à 45°', '45-Degree Back Extension', '{lombaires}', '{fessiers,ischios}', 'banc-lombaires', 0, 'Bassin sur le coussin, descends dos neutre puis remonte jusqu’à l’alignement.')
on conflict (id) do update set nom = excluded.nom, nom_en = excluded.nom_en, muscles_primaires = excluded.muscles_primaires,
  muscles_secondaires = excluded.muscles_secondaires, materiel = excluded.materiel, pas_kg = excluded.pas_kg, consignes = excluded.consignes;
