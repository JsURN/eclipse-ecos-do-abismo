# Assets — Catacumbas do Eclipse

Os recursos **ativos** são recortes das novas folhas fornecidas pelo usuário. Consulte `INTEGRATION_REPORT.md`, `concept_manifest.json` e `INTEGRATED_FILES.txt` para os mapas de recorte, contagem real de frames, transparência e limitações. Originais estão preservados em `source_art/`; candidatos rejeitados ficam isolados nessa pasta e não são usados pelo jogo.

```text
characters/kael/
enemies/shadow_crawler/
enemies/spectral_archer/
enemies/stone_guardian/
tilesets/catacombs/
environments/props/
effects/
```

A integração não depende de rede nem de assets pagos. Preparadores são ferramentas offline opcionais; os PNGs e o TileSet prontos já estão no projeto.

## Assets legados preservados (histórico)

Os arquivos antigos na raiz de `assets/` foram mantidos para referência. A documentação abaixo descreve essa base anterior; ela não é o conjunto de sprites/tiles ativo após a integração das folhas conceituais.

## Atlas de tiles

`catacombs_tiles.png`: 128×128 px, 64 posições de 16×16 px, oito colunas (algumas posições ficam reservadas/transparentes).

| Índices | Conteúdo |
| --- | --- |
| 0–1 | Chão de pedra |
| 2–3 | Chão rachado |
| 4–5 | Chão com musgo |
| 6 | Piso lunar |
| 7 | Degraus (disponível no atlas) |
| 8–9 | Pilar inteiro / quebrado |
| 10 | Sarcófago |
| 11 | Ossadas |
| 12 | Tocha azul |
| 13 | Entulho |
| 14 | Runa lunar |
| 15 | Lápide (disponível no atlas) |
| 16–31 | Paredes e junções de canto por máscara N/E/S/O |
| 32–39 | Variações de lajes, rachaduras e piso do relicário |
| 40–47 | Raízes, cristal, velas, estandarte, pedra e inscrições |
| 48–50 | Variantes de chama azul disponíveis no atlas |
| 52–55 | Quatro quadrantes do selo lunar central |

`dungeon.gd` configura um `TileSetAtlasSource` com colisões e duas `TileMapLayer`: piso/paredes e decoração. A máscara de vizinhos escolhe faces e cantos internos/externos; paredes junto às diagonais fecham as junções. O mapa é construído localmente na inicialização, com layout fixo para esta slice.

## Personagens

`kael.png`, `crawler.png`, `archer.png`, `guardian.png`: 192×192 px cada. Seis frames de 32×32 px por linha. Linhas: idle, walk, attack, dash, hurt e death. `pixel_actor.gd` cria as animações `SpriteFrames`. Kael usa as seis; os inimigos usam idle/walk/hurt/death e o arqueiro também emite o efeito de ataque. O tamanho da arte aumentou; os hitboxes e os parâmetros de combate foram mantidos.

`environment.png`: seis ilustrações de 32×48 px (estátua funerária, coluna, sarcófago, cristais, raízes/ruínas e altar). São montadas na camada com Y-sort para que a posição dos pés determine a sobreposição. A colisão continua nos tiles de base já existentes.

`props.png`: quatro frames de 24×32 px para baú fechado, baú aberto, selo inativo e selo ativo. As grades têm desenho pixelado próprio e animação em `gate.gd`.

## Direção e limites atuais

Paleta: pedra azul/cinza, ameixa/roxo, sombras azul-escuras, ciano e dourado. Kael possui cabelo prateado, capa azul, armadura e lâmina clara. O rastejante é baixo e multípede; o arqueiro usa um capuz lilás e arco dourado; o guardião tem ombros largos e fissuras luminosas.

Estes são **assets originais provisórios**, não arte final: personagens espelham apenas esquerda/direita, os estados têm seis frames e o movimento não possui oito orientações ilustradas. O ciclo de passos, cabelo/capa, fases do golpe e silhueta de queda são simples. Os efeitos usam partículas quadradas, arcos pixelados e cópias do frame de Kael para o dash. Sombras de contato são pintadas/desenhadas; não há sombras dinâmicas complexas. A fonte é a padrão local da Godot. Corrupção é apenas uma indicação reservada e os slots exibem a arma/dash atuais, sem inventário ou sistema de troca.
