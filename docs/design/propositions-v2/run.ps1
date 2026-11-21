# Generates one design direction with Codex (ChatGPT image generation).
# Usage: pwsh run.ps1 <direction folder name> [reference image]
param([Parameter(Mandatory)][string]$Direction, [string[]]$Reference)
$codex = 'C:\Program Files\WindowsApps\OpenAI.Codex_26.1117.3838.0_x64__2p2nqsd0c76g0\app\resources\codex.exe'
$dir = Join-Path $PSScriptRoot $Direction
$prompt = @'
Lis ../BRIEF.md (brief commun) puis DIRECTION-DEMANDEE.md (la direction artistique à appliquer) dans ce dossier.
Génère ensuite les images PNG demandées (les 4 du brief, plus les écrans supplémentaires si DIRECTION-DEMANDEE.md en liste ; si DIRECTION-DEMANDEE.md donne sa propre liste d'écrans à la place, suis-la) avec ton outil de génération d'images, en respectant exactement les textes et chiffres,
puis écris DIRECTION.md. Les images jointes montrent des captures App Store d'autres apps (Welmi, Cal AI, Uber) : inspiration de principes seulement, ne copie rien.
Enregistre tout dans ce dossier, rien ailleurs.
'@
$codexArgs = @('exec', '--skip-git-repo-check', '--sandbox', 'workspace-write', '-C', $dir)
if ($Reference) { $codexArgs += @('-i') + $Reference }
# The prompt goes through stdin ("-"): -i takes several files and would swallow a positional prompt.
$prompt | & $codex @codexArgs - *> (Join-Path $dir 'codex.log')
Get-ChildItem $dir -Filter *.png | Select-Object Name, Length
