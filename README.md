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

A visão interna é **384×216**, ampliada em **3×** na janela padrão de 1152×648, com filtro nearest e câmera que segue Kael em posições de pixel inteiro. Os limites da câmera ficam dentro da masmorra. O campo de visão continua utilizável para combate, com indicadores nas bordas para arqueiros fora da tela.

Kael agora usa cabelo prateado, capa azul, armadura com reflexos e espada clara. Os personagens possuem frames de 32×32 px e seis frames por estado. Pisos com juntas discretas, paredes com profundidade, estátuas, pilares altos, cristais e um selo lunar central reforçam a catacumba sem ocupar as rotas de combate com novas colisões.

A HUD ficou compacta; vida, XP, nível, corrupção reservada e recarga do dash continuam visíveis. Projéteis aliados usam rastro ciano, enquanto inimigos usam um losango quente com borda roxa. Impactos, números de dano, morte e afterimages do dash são somente feedback visual. Luzes compartilham textura; efeitos temporários possuem limite de 64 instâncias e as partículas ambientais são limitadas a 32.

Os PNGs originais em `assets/` já estão incluídos. O jogo não requer downloads nem execução do gerador de arte. Veja `assets/README.md` e `DEVELOPMENT_PROGRESS.md` para os placeholders e detalhes técnicos.

## Verificação e manutenção

Com a Godot disponível no PATH (ou substitua `godot` pelo caminho do executável):

```text
godot --headless --path . --editor --quit
godot --headless --path . --script tests/smoke_test.gd
```

Para regenerar a arte original e reimportá-la:

```text
godot --headless --path . --script tools/build_art.gd
godot --headless --path . --editor --quit
```

`tests/capture.gd` usa renderização gráfica e salva capturas em `artifacts/`, ignorado pelo Git. O teste de integração usa a engine, física e cena reais; algumas etapas forçam dano/posições para percorrer todos os estados sem depender da habilidade de um jogador.
