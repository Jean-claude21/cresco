# Generates one batch of final media with Codex (ChatGPT image generation).
# Usage: pwsh run-media.ps1 <batch folder> [reference images...]
param([Parameter(Mandatory)][string]$Batch, [string[]]$Reference)
$codex = 'C:\Program Files\WindowsApps\OpenAI.Codex_26.1117.3838.0_x64__2p2nqsd0c76g0\app\resources\codex.exe'
$dir = Join-Path $PSScriptRoot $Batch
$prompt = @'
Lis BRIEF.md dans ce dossier et produis exactement les images demandées avec ton outil de génération d'images,
aux noms de fichiers indiqués, dans ce dossier uniquement. Les images jointes sont des références à respecter
(personnage, style). Quand le brief demande un fond transparent, produis un vrai PNG avec canal alpha.
Termine en écrivant NOTES.md : ce que tu as produit, et tout écart au brief.
'@
$codexArgs = @('exec', '--skip-git-repo-check', '--sandbox', 'workspace-write', '-C', $dir)
if ($Reference) { $codexArgs += @('-i') + $Reference }
# The prompt goes through stdin ("-"): -i takes several files and would swallow a positional prompt.
$prompt | & $codex @codexArgs - *> (Join-Path $dir 'codex.log')
Get-ChildItem $dir -Filter *.png | Select-Object Name, Length
