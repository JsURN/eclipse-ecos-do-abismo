# Protótipo isométrico contínuo — Catacumbas do Eclipse

Primeira versão **experimental** da migração de perspectiva. A vertical slice top-down (`main.tscn`) continua sendo a cena principal e não foi substituída.

## Como abrir e testar

1. Abra o projeto na Godot 4.3+ (validado em **4.7.2**).
2. No FileSystem, abra `res://isometric/isometric_prototype.tscn` e pressione **F6** (Executar cena atual).

| Controle | Ação |
| --- | --- |
| W / S | Subir / descer **na tela** |
| A / D | Esquerda / direita **na tela** |
| W+D, W+A, S+D, S+A | Andar **paralelo aos corredores e paredes** (eixos da grade) |
| Mouse + Espaço / J / clique | Atacar na direção do cursor |
| Shift | Dash (mesmos 0,16 s / 0,9 s de recarga / invulnerabilidade) |
| E | Abrir o baú / atravessar o selo de saída |
| R | Reiniciar após vitória ou derrota |

Roteiro do mapa: Vestíbulo dos Esquecidos → Passagem das Cinzas (corredor com curva) → **Câmara do Eclipse** (pilares, estrado elevado com altar; dispara 3 ondas e sela as 3 passagens) → Descida do Ossário → **Ossário Lunar** (sarcófagos, baú) → Fenda Colapsada (laço) → **Ruínas Submersas** (paredes desabadas, cristais, pedestais lunares e selo de saída sobre um estrado).

### Verificação automatizada

```text
godot --headless --path . --editor --quit
godot --headless --path . --script tests/smoke_test.gd       # slice original: 47 checks
godot --headless --path . --script tests/iso_smoke_test.gd   # protótipo: 67 checks
godot --path . --script tests/iso_capture.gd                 # capturas em artifacts/iso_*.png (precisa de GPU)
```

Para regenerar o kit de arte: `godot --headless --path . --script tools/build_iso_art.gd` seguido da importação (`--editor --quit`). Os placeholders antigos (`tools/build_iso_placeholders.gd`, `assets/isometric/placeholders/`) ficam só como referência e não são mais carregados.

## Decisões de coordenadas e movimentação

### Dois espaços, uma fonte de verdade

| Espaço | O que vive nele | Unidade |
| --- | --- | --- |
| **Lógico / mundo** (`LogicWorld`, oculto) | `CharacterBody2D` de Kael e inimigos, projéteis, colisões, `AStarGrid2D`, distâncias de combate | Plano cartesiano, **16 u por célula** (mesma escala do top-down) |
| **Visual / tela** (`CatacumbasIsometricas`) | Losangos do piso, paredes, props, proxies visuais, luzes, efeitos | Pixels, losango **32×16** (2:1) |

Projeção (linear, então serve para posições **e** direções), em [isometric/iso_math.gd](../isometric/iso_math.gd):

```text
tela  = (x − y, (x + y) / 2)
mundo = (ty + tx/2, ty − tx/2)
+x do mundo → baixo-direita na tela;  +y do mundo → baixo-esquerda
```

Por que separar: a física e a IA continuam isotrópicas (um inimigo a 14 u de distância está a 14 u em qualquer direção), o `AStarGrid2D` segue quadrado, e `player.gd`, `enemy.gd` e `projectile.gd` rodam **sem mudança de regra**. O `LogicWorld` tem `visible = false`; física e processamento continuam ativos.

O `TileMapLayer` em `DIAMOND_DOWN` centraliza a célula (0,0) em (16, 8); a projeção acima a coloca em (0, 8). As camadas são deslocadas por `IsoMath.TILEMAP_OFFSET = (−16, 0)`; um teste garante o alinhamento.

### Entrada

`IsoMath.input_to_world(input) = input.rotated(−45°)`:

- W/S/A/D movem nos eixos **da tela** (W = sobe na tela).
- Diagonais de teclado (W+D…) caem exatamente nos **eixos da grade**, então andar por um corredor ou rente a uma parede não "serrilha".
- A rotação preserva o módulo; `Input.get_vector` já normaliza, então as 8 direções têm **a mesma velocidade no mundo** (110 u/s; dash 340 u/s).
- Na tela, a mesma velocidade aparece em escorço 2:1 (31 px na horizontal contra 16 px na vertical por 12 quadros), que é o que faz o chão parecer um plano em perspectiva, e não um mapa inclinado.

A mira converte o cursor (tela) de volta para o mundo a partir do peito de Kael (`iso_player.gd`).

### Alturas

Estrado (+6 px) e escadas (+3 px) são **apenas visuais**: o `IsoActorView` aplica a altura a um nó filho (`Lift`), nunca ao ponto de ordenação. Elevações pequenas são "pisáveis"; elevações altas, com bloqueio de borda, ficam para uma próxima etapa.

## Profundidade e renderização

```text
CatacumbasIsometricas (Node2D)
├─ FloorDiamonds   TileMapLayer isométrico (piso temático por área + vazio de rocha)
├─ FloorDetail     decalques espelhados (rachaduras, musgo, poças, ossos, fuligem...)
├─ WallShade       oclusão ambiente onde o piso encontra uma parede
├─ RockMass        rocha elevada ao redor das salas (y_sort próprio, nunca cobre piso/paredes)
├─ RaisedFloor     TileMapLayer isométrico com y_sort próprio (estrado/escadas)
├─ FloorGlow       sombras, runas, selos, limiares, mosaico/anéis, fendas, margens da água
├─ Mist            névoa rasteira (iso_atmosphere.gd), abaixo de tudo que é alto
├─ DepthSorted     Node2D com y_sort_enabled
│   ├─ paredes, batentes, arcos, pilares, estátuas, sarcófagos, baú, pedestais, velas
│   ├─ Embers      fagulhas ancoradas na base da chama (mesma profundidade da tocha)
│   ├─ KaelView / EnemyView (IsoActorView)
│   ├─ ProjectileView
│   └─ SealPane (cortinas dos selos)
├─ Lights          PointLight2D (tochas, arandelas, velas, runas, altar, baú, saída, humor)
└─ Ambient         CanvasModulate
Atmosphere (irmão do mundo): partículas de altar/pedestais/baú/saída, poeira, vinheta (CanvasLayer 1; HUD na 2)
```

- Todo elemento alto fica em `DepthSorted` com `position` = **base / pés** projetados; o desenho sobe a partir dali (`offset`). O Y-sort da Godot passa a ser o algoritmo do pintor correto para blocos de uma célula.
- **Paredes de fundo** (com piso à frente na tela: +x, +y ou +x+y) têm altura cheia (40 px). **Paredes frontais** são rebaixadas (12 px), no estilo *cutaway*, para não esconder a sala.
- **Transparência contextual** (`iso_occlusion_fader.gd`): paredes de fundo, batentes, arcos, pilares, estátuas e tocos que estejam *à frente* de Kael (Y de base maior) e cubram de fato a silhueta dele vão para 50% de opacidade. Só as células vizinhas são checadas (custo desprezível). Blocos que ocultam são recortados às margens opacas (`region_rect`), então o retângulo de teste é justo.
- Fora do mapa o piso recebe ladrilhos de "rocha/vazio" até cobrir todo o alcance da câmera: não aparece borda flutuante de diorama.

## Câmera

`pixel_camera.gd` reaproveitado sem mudanças: segue o **proxy visual** de Kael, interpola suavemente, arredonda para pixel inteiro, zoom inteiro 2× e limites (`world_bounds`) calculados a partir do losango projetado do mapa, já incluindo a altura das paredes de fundo.

## Sistemas reaproveitados

| Sistema | Como |
| --- | --- |
| `player.gd` (vida, XP, níveis, ataque, dash, invulnerabilidade, animações) | Herdado por `iso_player.gd`; só entrada e mira são sobrescritas |
| `enemy.gd` (3 arquétipos, IA, tiro do arqueiro, contato, morte) | Sem alteração; anda na grade lógica |
| `projectile.gd` | Sem alteração; ganha `IsoProjectileView` |
| `effects.gd` (impacto, arco, dash, números) | Sem alteração; posições e direções projetadas pelo protótipo |
| `pixel_camera.gd`, `pixel_actor.gd`, SpriteFrames de Kael e inimigos | Reaproveitados com ganchos opcionais |
| `hud.gd` | Só na slice top-down; o protótipo usa `iso_hud.gd` |
| Regras de ondas, baú (+6 dano, +12 XP, cura 35), vitória/derrota, reinício | Mesmas regras de `main.gd` em `iso_prototype.gd` |

Mudanças nos arquivos compartilhados (comportamento padrão idêntico; a suíte original continua 47/47):

- `player.gd`: métodos `_movement_input()` e `_aim_direction()` extraídos.
- `pixel_actor.gd`: `facing_transform` (identidade por padrão) e `up_threshold`.
- `hud.gd`: `_minimap_point()` e `_canvas_point()` consultam a cena quando ela oferece projeção própria.
- `main.gd`: o mapa de entrada foi movido para `input_setup.gd` (compartilhado).

## Direção de arte e atmosfera (polimento visual)

Paleta: preto azulado e pedra azul-escura como base, roxo profundo nos tecidos e na corrupção, ciano luminoso para magia lunar (runas, chamas, selos) e dourado envelhecido só em acabamentos (capitéis, molduras, fechaduras, limiares). Nada saturado além das luzes.

**Kit procedural** (`tools/build_iso_art.gd` → `assets/isometric/catacombs/`): todas as peças são rasterizadas a partir de geometria isométrica real (caixas e cilindros em espaço local da célula), então topo, faces e decoração compartilham a mesma projeção e o mesmo sentido de luz (face +y mais clara, +x mais escura, topo escuro).

| Elemento | O que mudou |
| --- | --- |
| Piso | 6 partições de lajes irregulares com bisel, mais rachado, gasto, musgo, gravado e cinzas; tom por mancha de ruído (5 tonalidades alternativas) |
| Áreas | Tema por região: Vestíbulo limpo e gasto, Passagem das Cinzas com fuligem, Câmara com runas e corrupção, Ossário violeta com ossos e moedas, Fenda/Galeria/Ruínas com musgo, poças e rachaduras |
| Decalques | 10 decalques sobre o piso, espelhados em 4 variações para não repetir |
| Paredes | Topo contínuo (borda só onde a parede termina: 16 máscaras), fiadas escalonadas, rodapé e cornija; 13 variações de fundo (lisas, rachada, musgo, runa, estandarte, arandela, nicho com crânio) escolhidas pelo tema e espaçadas; paredes frontais com rachadura/musgo |
| Profundidade | Sombra na base das paredes (oclusão ambiente com pontilhado), sombras de contato sob pilares, batentes, sarcófagos, baú, estátuas e pedestais |
| Pilares | Fuste redondo com caneluras, base em degraus, anel e capitel dourados, crescente ciano; variante rachada com musgo |
| Passagens | Batentes com faixa rúnica ciano e remate dourado; lintéis formam arcos sobre todas as passagens com batentes (pedra-chave com crescente); limiar dourado com cravos ciano marca as passagens seláveis |
| Selos | Cortina vertical de energia: base dourada, linhas subindo, barras rúnicas cintilando e crescente na célula central |
| Props | Baú com lingueta lunar, aberto com brilho interno; sarcófago com efígie e molduras douradas; pedestais com orbe ladeando a escada da saída; velas votivas perto de sarcófagos e estátuas; paredes desabadas em dois formatos |
| Luz | Ambiente mais escuro; arandelas, braseiros e velas cintilam; luz de humor por área (violeta na Câmara/Ossário, verde-água nas Ruínas); baú pulsa dourado até ser aberto; selo de saída mais forte |
| Atmosfera | `iso_atmosphere.gd`: névoa rasteira nas áreas úmidas/criptas, fagulhas por chama, partículas subindo no altar/pedestais/baú/saída, poeira ciano/violeta ao redor da câmera, vinheta suave abaixo da HUD |

Legibilidade: a névoa fica sob tudo que é alto, as partículas são de 1 px e baixa opacidade, a vinheta só escurece as bordas e Kael mantém a luz própria de `player.gd`. A transparência contextual continua valendo para paredes, arcos, batentes, pilares e estátuas.

Custo: ~260 partículas de CPU no total, ~60 luzes 2D (a maioria pequenas), sprites estáticos; nada é redesenhado por quadro além de `FloorGlow` e dos selos visíveis.

## Refinamento do cenário (etapa 3)

| Problema | Solução |
| --- | --- |
| Paredes de uma célula com chão preto atrás ("buraco cru") | **Massa de rocha** (`RockMass`, atlas `rock_atlas.png`, 5 alturas × 4 variações): as salas parecem escavadas na rocha. A altura de cada célula é a maior que não cobre nenhum piso ou parede atrás dela na tela (`IsoWorld._rock_level`); atrás das salas sobe à altura das paredes, à frente fica cortada na altura das paredes frontais (continua o *cutaway*). |
| Bordas escuras e vazias | A rocha escurece com a distância ao piso (5 tons alternativos + ruído) e vira chão de rocha escura com rachaduras além de 7 células: penumbra orgânica em vez de preto liso. |
| Paredes longas e retas | Pilastras a cada 5 células (ritmo de vãos), cantos externos com pedras angulares e linha rúnica, trechos desabados (mais baixos, com entulho; os vizinhos mantêm a borda) nas áreas em ruína. |
| Áreas repetitivas | Pontos de interesse: mosaico lunar no Vestíbulo, anéis dourados em volta do estrado da Câmara e no Ossário, fendas com brilho corrompido (Cinzas, Câmara, Fenda), poças rasas nas Ruínas (Kael afunda 2 px), tocos de coluna, coluna caída, urnas, pilha de ossos. |
| Arcos isolados | Pedra-chave com crescente dourado em pé sobre o lintel. |
| Atmosfera | Feixes de luar (aditivos, sutis) sobre o mosaico, o estrado, o Ossário e o selo de saída, com poeira caindo. |

Tudo isso é visual: colisão nova só para os novos props bloqueantes (`G`, `F`, `U`, `H`), colocados em cantos e áreas abertas; um teste garante que todo o mapa continua conectado.

## HUD (`isometric/iso_hud.gd`)

O protótipo isométrico tem HUD própria; `hud.gd` (top-down) não foi alterado nesta etapa. Mesma escala da arte (canvas lógico 384×216 em 2×), sem caixas pesadas: painéis que se dissolvem, filetes de ouro velho e losangos lunares.

| Área | Conteúdo |
| --- | --- |
| Topo-esquerda | Retrato octogonal em moldura dourada, gema de nível, nome em serifa, vida em barra inclinada (lasca atrasada, marcas de quartos, clarão ao levar dano, pulso abaixo de 30%), ecos (XP) e cinco sigilos de corrupção (sistema ainda reservado) |
| Topo-centro | Nome da área em serifa com ornamentos; abaixo, **um** objetivo (`objective()`) ou, em combate, "Onda X de 3 · N inimigos" com losangos de progresso |
| Topo-direita | Minimapa isométrico em moldura chanfrada, revelado conforme Kael explora (raio 6), área atual realçada, poças e estrado em cores próprias; Kael pulsando, inimigos, baú e selo de saída |
| Base-esquerda | Encaixes em losango para atacar (J) e esquivar (Shift), com ícone e preenchimento de recarga |
| Base-centro | Prompt contextual só quando há algo a fazer (`action_prompt()`: tecla E + ação, ou o motivo de não poder); nos primeiros segundos, dicas de controle em teclas pequenas que somem sozinhas |
| Centro | Faixas para ondas/relíquia/selos (título em serifa + subtítulo, cor por tipo), cartão de título ao entrar numa área pela primeira vez (cede lugar às faixas e some ao sair da área), painel de vitória/derrota com tecla R |
| Bordas | Setas para arqueiros fora da tela; vermelho pulsante nas bordas com vida baixa |

Tipografia: títulos usam fonte serifada do sistema (`SystemFont`: Cinzel, Palatino Linotype, Book Antiqua, Georgia...) com retorno à fonte padrão, sem adicionar arquivos de fonte. O minimapa é desenhado na resolução nativa (meia escala) para ficar nítido.

Ganchos lidos pela HUD em `iso_prototype.gd`: `objective()`, `action_prompt()`, `wave_total()`, `canvas_point()`; a mensagem inicial foi trocada pelo cartão de título da área. `interaction_prompt()` e o mapeamento do minimapa antigo saíram do protótipo (continuam em `main.gd`/`hud.gd` para a slice top-down).

## Ainda não adaptado

- **Orbes de experiência**: no protótipo o XP é concedido no ponto de morte (com o efeito de coleta); `experience_orb.gd` ainda não tem proxy visual.
- **Facing de 8 direções**: Kael e inimigos só têm vista frontal e de costas com espelhamento; as diagonais isométricas usam a mais próxima.
- **Hitboxes de combate**: continuam circulares no mundo (corretas em perspectiva), mas o arco de espada ainda é o efeito top-down rotacionado.
- **Elevações bloqueantes**: estrado e escadas são pisáveis por qualquer lado; não há queda nem borda alta.
- **Oclusão para inimigos**: só Kael aciona a transparência.
- **TileSet editável**: o TileSet isométrico é montado em código (`IsoWorld.build_tileset()`); ainda não há `.tres` para pintar no editor.
- **Sombras projetadas por luz**: as luzes 2D não usam `LightOccluder2D`; paredes não bloqueiam luz.
- **HUD temporária em partes**: retrato reaproveitado do top-down; corrupção é só visual (sistema não implementado); ícones de habilidade desenhados por código; fonte serifada depende do sistema (cai na padrão se ausente).
- **Rocha à frente das salas**: cortada em altura baixa por legibilidade; não há "teto" ou transição de câmera para áreas cobertas.

## Assets: substituídos, temporários e definitivos a produzir

Substituições devem manter as dimensões e a base do losango nas **16 linhas inferiores** (atlas de piso: regiões 32×32; paredes: atlas de 16 colunas por máscara de topo).

| Placeholder antigo | Substituído por (`assets/isometric/catacombs/`) | Estado |
| --- | --- | --- |
| `placeholder_floor_atlas.png` | `floor_atlas.png` (19 colunas) + `floor_decals.png` + `floor_shade.png` | Arte procedural de 1ª passada |
| `placeholder_wall_full.png` | `wall_full.png` (atlas 16 máscaras × 13 variações, 32×56) | Arte procedural de 1ª passada |
| `placeholder_wall_low.png` | `wall_low.png` (16 × 4, 32×28) | Arte procedural de 1ª passada |
| `placeholder_wall_broken.png` | `wall_broken_a.png`, `wall_broken_b.png` | Arte procedural de 1ª passada |
| `placeholder_door_post.png` | `door_post.png` + `lintel_x/y(_key).png` | Arte procedural de 1ª passada |
| `placeholder_pillar.png` | `pillar_a.png`, `pillar_b.png` (32×72) | Arte procedural de 1ª passada |
| `placeholder_sarcophagus.png` | `sarcophagus.png` | Arte procedural de 1ª passada |
| `placeholder_chest_closed/open.png` | `chest_closed.png`, `chest_open.png` | Arte procedural de 1ª passada |
| — | `pedestal.png`, `candles.png` | Novos |
| — | `rock_atlas.png`, `pillar_stump.png`, `fallen_column.png`, `urns.png`, `bone_pile.png`; água (colunas 19-20 do piso); linhas `pier`, `quoin`, `broken` nos atlas de parede | Novos (etapa 3) |

Os placeholders antigos não são mais carregados (um teste garante); ficam em `assets/isometric/placeholders/` só como referência e podem ser apagados.

Ainda temporários (billboards frontais da slice top-down, aceitáveis mas não isométricos): `statue_sword`, `torch` (braseiro), `altar`, `crystal`, `rubble`, `bones`.

Precisam de arte definitiva (pixel art desenhada à mão, mesmo enquadramento): todo o kit acima (o procedural serve de guia de proporção e paleta), com prioridade para **piso e paredes** (o que mais aparece), **arco/porta** completo, **braseiro isométrico**, **altar** e **estátua** em 3/4; variações de canto de parede e transições piso↔estrado.

Incompatíveis com a nova perspectiva (mantidos para a slice top-down): `assets/tilesets/catacombs/*`, `doors.png`, `banner.png` (de parede), `atmosphere.gd`.

### Personagens (próxima etapa, não alterados aqui)

- Kael e os três inimigos precisam de **quatro diagonais** (SE, SW, NE, NW) para idle, walk, attack e dash; hurt/death podem ficar com 2 direções.
- Contra o novo cenário mais escuro, os inimigos dependem da própria luz/aura; vale um contorno escuro de 1 px ou leve rim light ciano/roxo nas folhas definitivas.
- O arco de ataque e os afterimages do dash ainda são os efeitos top-down projetados; redesenhar em 2:1 junto das diagonais.

## Próximos passos recomendados

1. Validar a sensação de controle (W+D ao longo da grade contra diagonal livre da tela) com jogadores; a escolha está isolada em `IsoMath.input_to_world`.
2. Encomendar o kit definitivo de piso, paredes e arcos seguindo a tabela acima; trocar os PNGs sem mexer em código (os nomes e as grades de atlas são o contrato).
3. Sprites em 4 diagonais e ajuste de `PixelActor` para escolhê-las pelo `facing_transform`.
4. Proxy visual para orbes de XP.
5. Salvar o TileSet como `.tres` e migrar o layout ASCII para pintura no editor (ou importação de `.tscn` por sala).
6. Elevações com bordas bloqueantes (colisão de aresta + custo no A*), se o level design pedir.
7. Quando o protótipo for aprovado, tornar `isometric_prototype.tscn` a cena principal e aposentar `dungeon.gd`/`main.gd`.
