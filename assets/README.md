# Arte original — Catacumbas do Eclipse

Todos os PNGs desta pasta são assets locais originais, gerados deterministicamente por `tools/build_art.gd`. Não há dependências de imagens, fontes ou pacotes pagos externos.

## Atlas de tiles

`catacombs_tiles.png`: 128×64 px, 32 tiles de 16×16 px, oito colunas.

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

`dungeon.gd` configura um `TileSetAtlasSource` com colisões e duas `TileMapLayer`: piso/paredes e decoração. A máscara de vizinhos escolhe faces e cantos internos/externos; paredes junto às diagonais fecham as junções. O mapa é construído localmente na inicialização, com layout fixo para esta slice.

## Personagens

`kael.png`, `crawler.png`, `archer.png`, `guardian.png`: 96×144 px cada. Quatro frames de 24×24 px por linha. Linhas: idle, walk, attack, dash, hurt e death. `pixel_actor.gd` cria as animações `SpriteFrames`. Kael usa as seis; os inimigos usam idle/walk/hurt/death e o arqueiro também emite o efeito de ataque.

`props.png`: quatro frames de 24×32 px para baú fechado, baú aberto, selo inativo e selo ativo. As grades têm desenho pixelado próprio e animação em `gate.gd`.

## Direção e limites atuais

Paleta: pedra azul/cinza, ameixa/roxo, sombras azul-escuras, ciano e dourado. Kael possui manto, armadura, visor lunar e lâmina clara; cada inimigo tem silhueta própria.

Estes são **placeholders originais funcionais**, não arte final: personagens espelham apenas esquerda/direita, os estados têm quatro frames simples e o movimento não possui oito orientações ilustradas. Os efeitos são partículas quadradas desenhadas por código. A fonte é a padrão local da Godot; a HUD usa molduras e barras pixeladas. Corrupção é apenas uma indicação reservada e os slots exibem a arma/dash atuais, sem inventário ou sistema de troca.
