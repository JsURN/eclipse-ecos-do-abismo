# ECLIPSE: Ecos do Abismo

Vertical slice jogável de um roguelite 2D top-down em pixel art dark fantasy: **Catacumbas do Eclipse**.

## Como executar

1. Importe `project.godot` na Godot **4.3 ou superior** (`TileMapLayer`); validado em **4.7.2**.
2. Aguarde a importação dos PNGs e pressione **F5**.
3. Explore o vestíbulo e siga o corredor a leste até a câmara de combate.

| Controle | Ação |
| --- | --- |
| WASD / setas | Mover Kael |
| Mouse | Mirar os ecos da lâmina |
| Espaço / J / botão esquerdo | Atacar |
| Shift | Dash com breve invulnerabilidade; recarga de 0,9s |
| E | Abrir o baú / atravessar o selo de saída |
| R | Reiniciar após vitória ou derrota |

## Loop atual

- Quatro espaços conectados: Vestíbulo dos Esquecidos, Passagem das Cinzas, Câmara do Eclipse e Relicário Lunar.
- Três ondas de 4, 5 e 6 inimigos, com portas fechadas até a última vitória.
- Rastejante Sombrio (perseguição), Arqueiro Espectral (disparos e recuo) e Guardião de Pedra Corrompido (tanque de contato).
- Paredes e pilares com colisão, projéteis bloqueados pelo cenário e navegação por grade.
- Experiência, níveis, cura ao evoluir e aumento de dano, preservados da base inicial.
- Baú de uso único: +6 de dano, +12 XP e até 35 de cura. O selo lunar encerra a partida após o baú.
- Sprites animados, iluminação ciano, HUD temática, minimapa e efeitos em pixel art.

## Polimento visual

A integração das folhas conceituais mantém um campo de **384×216 unidades do mundo**, agora com viewport de **768×432**, zoom inteiro 2× e janela padrão 1536×864 em escala inteira 2×. Isso preserva detalhe dos recortes sem mudar a física. Filtro nearest, pivô nos pés, limites da câmera e indicadores de arqueiros fora da tela continuam ativos.

Kael, criaturas, pisos, paredes, portas, objetos e efeitos usam os recortes dos três anexos, organizados nas subpastas de `assets/`. Cada estado usa somente os frames mapeados no manifest; idle é uma pose, e algumas sequências têm apenas dois quadros válidos. Detalhes e correções manuais estão em `assets/INTEGRATION_REPORT.md`.

A HUD ficou compacta; vida, XP, nível, corrupção reservada e recarga do dash continuam visíveis. Projéteis aliados usam rastro ciano; inimigos usam a flecha espectral roxa extraída da referência. Impactos, números de dano, morte e afterimages do dash são somente feedback visual. Luzes compartilham textura; efeitos temporários possuem limite de 64 instâncias e as partículas ambientais são limitadas a 32.

Os PNGs preparados e o TileSet editável já estão incluídos. O jogo não requer downloads nem execução dos preparadores. Os gráficos simplificados antigos foram preservados como legado.

## Verificação e manutenção

Com a Godot disponível no PATH (ou substitua `godot` pelo caminho do executável):

```text
godot --headless --path . --editor --quit
godot --headless --path . --script tests/smoke_test.gd
```

Para refazer os recortes das fontes preservadas e reimportá-los:

```text
godot --headless --path . --script tools/prepare_concept_assets.gd
godot --headless --path . --editor --quit
godot --headless --path . --script tools/build_concept_tileset.gd
```

`tests/capture.gd` usa renderização gráfica e salva capturas em `artifacts/`, ignorado pelo Git. O teste de integração usa a engine, física e cena reais; algumas etapas forçam dano/posições para percorrer todos os estados sem depender da habilidade de um jogador.
