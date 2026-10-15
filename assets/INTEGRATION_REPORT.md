# Integração das folhas conceituais — 13/10/2026

Os assets ativos desta etapa são **recortes das três imagens fornecidas pelo usuário**. Não foram regenerados por IA nem substituídos por desenhos geométricos. Os PNGs antigos foram preservados como legado e não são os personagens/tiles usados na cena.

## Fontes e transparência

| Fonte local preservada | Dimensões | Pixels alpha zero | Pixels alpha parcial | Pixels opacos |
| --- | --- | --- | --- | --- |
| `source_art/kael_concept.png` | 1448×1086 | 658691 | 913114 | 723 |
| `source_art/enemies_concept.png` | 1448×1086 | 595697 | 975410 | 1421 |
| `source_art/catacombs_concept.png` | 1672×941 | 349630 | 1222737 | 985 |

Todas possuem RGBA e transparência real. O preto na visualização não foi tratado como cor a remover: existe muito alpha parcial, especialmente nos brilhos. Originais foram copiados sem alteração, e o alpha dos recortes foi preservado. A pasta de fontes tem `.gdignore`: fica no repositório para edição, mas não é carregada pelo jogo.

## Preparação e origem

`tools/prepare_concept_assets.gd` contém cada retângulo selecionado e seu pivô. Não pressupõe uma grade uniforme nas fontes. `concept_manifest.json` registra os recortes, origem, fator de reamostragem e listas exatas dos frames usados. `INTEGRATED_FILES.txt` lista os arquivos preparados e as fontes.

48 frames de personagens são carregados: 20 de Kael, 11 do rastejante, 8 do arqueiro e 9 do guardião. Cada frame tem canvas transparente 160×160, com pivô comum nos pés `(80,140)`. Reamostragem uniforme com nearest; a margem varia, a escala do corpo não varia entre estados. Candidatos contaminados por rótulos/vizinhos foram movidos para `source_art/rejected_crops/`, excluídos do manifest e da importação. Um pequeno trecho de rótulo foi apagado fora do corpo no primeiro frame de morte do guardião.

## Estados realmente integrados

| Personagem | Idle | Walk | Attack | Dash | Hurt | Death |
| --- | --- | --- | --- | --- | --- | --- |
| Kael | 1 pose frontal + 1 de costas | 2 frontal + 2 de costas | 3 frames | 3 frames | 2 frames | 6 frames |
| Rastejante Sombrio | 1 pose | 2 frames | 3 frames | Não disponível | 2 frames | 3 frames |
| Arqueiro Espectral | 1 pose | 2 frames | 2 frames | Não disponível | 1 pose | 2 frames |
| Guardião de Pedra Corrompido | 1 pose | 2 frames | 2 frames | Não disponível | 1 pose | 3 frames |

Idle não foi apresentado como ciclo de respiração: é uma pose válida mantida. Hurt do arqueiro/guardião é uma pose com flash de dano. Direções não disponíveis usam a vista oblíqua e espelhamento horizontal; não há oito direções completas. As vistas de costas de Kael só são aplicadas a idle/walk.

O golpe de Kael inicia na pose de liberação, junto ao projétil real. O arco já está presente em um dos quadros e há um efeito separado recortado. Impactos só surgem quando há colisão/dano. As poses de ataque dos inimigos são acionadas pelo contato/disparo da IA; tempos de dano/cooldown anteriores não foram alterados. Os frames de morte continuam avançando antes de liberar os corpos ou enquanto a tela de derrota aparece.

## Cenário e objetos

- `tilesets/catacombs/atlas.png`: atlas preparado de 256×256, 64 posições de 32×32. Pisos, variações, fissuras, musgo, faces de parede, cantos adaptados e selo lunar em quatro quadrantes. Algumas posições continuam reservadas/transparentes.
- `tilesets/catacombs/catacombs.tres`: `TileSetAtlasSource` editável com colisões em paredes e bases sólidas. A folha conceitual não é usada como fundo gigante.
- `environments/props/`: estátuas, coluna, sarcófagos fechado/aberto, pedestal/cristal, raízes, altar lunar, tochas, estandarte, ossos, entulho e corrupção; PNGs individuais e atlas para os props da sala.
- Portas abertas/fechadas/seladas/lunares em `doors.png`. As portas de combate alternam aberto/fechado com a transição existente e mantêm seu corpo físico. Imagens de arquitetura foram rotacionadas para as passagens leste/oeste; não há ciclo de porta desenhado frame a frame.
- Baú fechado/aberto e selo de saída em `rewards_atlas.png`, conectados à interação/recompensa/vitória existentes.
- `effects/`: arco de espada, brilho de impacto, projétil espectral e corrupção recortados. Partículas pequenas, números, afterimages e luzes existentes continuam complementando esses recursos.

O foco visual foi a câmara de combate completa. O mesmo atlas mantém vestíbulo, corredor e relicário conectados. Não foram adicionadas novas salas, ondas ou mudanças de balanceamento.

## Resolução e física

Viewport 768×432, câmera com zoom inteiro 2× e janela padrão 1536×864 com escala inteira 2×. O campo do mundo permanece 384×216. Sprites/TileMapLayer usam 0,5 no mundo, que combinado com o zoom 2× dá **um texel preparado por pixel do viewport**, sem filtragem linear ou escalas irregulares perceptíveis. HUD usa escala 2×.

As células gráficas 32×32 ocupam 16×16 unidades do mundo. Polígonos do TileSet são 32×32 antes da escala, resultando nas mesmas colisões de 16×16. Raio do jogador 5, inimigos 6; velocidades, alcances, projéteis, navgrid e recompensas foram preservados. Os props são ordenados pelo pivô nos pés; a sombra simples permanece no chão.

## Correções manuais ainda recomendadas

1. Produzir ciclos de idle consistentes e mais frames de passos. A folha mistura poses/direções e não fornece ciclos completos confiáveis.
2. Retocar pequenos halos, faíscas vizinhas e pivôs em golpes/corpos caídos. Não há correção de anatomia por geração de novos quadros.
3. Criar ataques direcionais/de costas e poses hurt adicionais de arqueiro/guardião.
4. Refazer junções de paredes/cantos como tiles de produção. Nesta integração, faces foram recortadas e rotacionadas/recombinadas; alguns encontros podem precisar de pintura fina.
5. Criar portas específicas para leste/oeste e frames de abertura. A versão atual usa as imagens válidas abertas/fechadas rotacionadas e crossfade.
6. Corrupção é visual/reserva de HUD; não foi inventada uma mecânica nova. Também não há animação nova de baú além dos estados aberto/fechado.

## Verificação

Godot 4.7.2 disponível: importação do editor, teste da cena real e renderização OpenGL Compatibility. **47 verificações com zero falhas** incluem fontes corretas dos sprites, avanço real de walk/attack/dash/hurt/death, pivô/colisão, TileSet por células, portas, navegação, ataques, XP, três ondas, baú, vitória, derrota e reinício. Capturas de QA usam algumas posições/dano controlados para mostrar os tipos de inimigo e percorrer estados. Não equivalem a uma partida manual inteira, teste de exportação ou benchmark.

## Regeneração opcional

O jogo já usa os PNGs e o `.tres` incluídos; F5 não executa nenhum preparador.

```text
godot --headless --path . --script tools/prepare_concept_assets.gd
godot --headless --path . --editor --quit
godot --headless --path . --script tools/build_concept_tileset.gd
godot --headless --path . --script tests/smoke_test.gd
```

Use o executável console da Godot no Windows para capturar os diagnósticos. `tools/build_art.gd` é o gerador geométrico/pixel legado, não o caminho desta integração.
