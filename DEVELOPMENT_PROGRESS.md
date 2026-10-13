# ECLIPSE — Progresso de desenvolvimento

## Polimento visual e experiência (13/10/2026)

Etapa aplicada à vertical slice existente, mantendo dano, velocidades, hitboxes, três ondas, navegação, XP, recompensa do baú e condições de vitória/derrota.

- Câmera suave, posição renderizada em pixels inteiros e limites verificados nas quatro extremidades do mapa. Visão interna 384×216, janela 1152×648 com escala inteira 3×. Indicadores direcionais alertam sobre arqueiros fora da área visível.
- Kael e inimigos ganharam sheets de 192×192 (frames 32×32, seis por estado). Kael tem cabelo prateado, capa azul com movimento, armadura em camadas e espada clara. Ataque reinicia a pose por golpe; cadências visuais ajustadas sem alterar o cooldown.
- Rastejante baixo com patas, arqueiro de capuz lilás e guardião com ombros largos/fissuras ciano. Efeitos distintos de impacto, flashes, morte e números flutuantes de dano.
- Atlas expandido para 64 posições: lajes variadas, juntas de baixo contraste, rachaduras, musgo e selo lunar central. Seleção por mistura determinística das coordenadas reduz padrões diagonais repetidos.
- Paredes com topo, face e sombra de contato; região não transitável mais escura. Pilares altos, sarcófagos e personagens compartilham a ordenação pelos pés. Estátuas, cristais, velas, raízes e altar aparecem nas bordas, preservando as rotas e colisões da slice.
- Tochas/ciano, cristais/roxo e runas com luz localizada, chama/brilho oscilantes e pequena luz acompanhando Kael. Textura de luz compartilhada, sombras simples e 32 partículas ambientais discretas.
- HUD compacta: barras de vida/XP, nível, corrupção reservada, sala, onda/inimigos, minimapa e slots. Barra de vida com perda atrasada e indicador de recarga do dash. Minimap pré-renderizado em textura para evitar redesenhar centenas de células por frame.
- Afterimages do dash, partículas de golpe, cruz de impacto, fragmentos de morte e coleta ascendente. Projéteis aliados têm rastro ciano/lâmina; os hostis são losangos quentes com borda roxa. Efeitos temporários limitados a 64 e liberados após sua duração.
- Grades com bordas de pedra, barras metálicas, lacre lunar e estado aberto mais legível; preservada a animação e a colisão anterior.

### Arquivos deste polimento

Criados: `pixel_camera.gd`, `atmosphere.gd`, `assets/environment.png` e seus metadados/UIDs.

Modificados: `main.gd`, `dungeon.gd`, `hud.gd`, `pixel_actor.gd`, `player.gd`, `enemy.gd`, `projectile.gd`, `experience_orb.gd`, `effects.gd`, `gate.gd`, `project.godot`, `tools/build_art.gd`, `tests/smoke_test.gd`, `tests/capture.gd`, `README.md`, `assets/README.md`, este documento e os PNGs originais de tiles/personagens/props. A cena principal e a configuração das ondas/recompensas foram preservadas.

### Limitações ainda presentes

Arte e animações continuam provisórias e geradas localmente; não possuem oito direções desenhadas nem variações de equipamentos. Fonte padrão da Godot. Corrupção/inventário permanecem reservados. Layout fixo, sem áudio, chefe ou save. As sombras são de contato, sem oclusão dinâmica complexa das luzes.

### Validação efetivamente realizada

Godot **4.7.2**, importação do editor headless sem erros de script, regressão de **36 verificações com zero falhas** (30 sistemas existentes + enquadramento/limites/seguimento da câmera, textura de luz compartilhada e limite/liberação de efeitos). Capturas reais com OpenGL Compatibility inspecionadas: vestíbulo, câmara, relicário e feedback de ataque/dash/projéteis. Essas capturas verificam aparência na engine; não equivalem a uma rodada manual completa nem a um benchmark de desempenho.

## Vertical slice — Catacumbas do Eclipse (13/10/2026)

Implementada sobre os sistemas da base inicial. A progressão agora ocorre por exploração contínua de quatro espaços e três ondas na câmara, sem teleportar Kael entre arenas.

- `TileMapLayer` de pedra/paredes e camada de decoração, atlas original local de 32 tiles.
- Vestíbulo, corredor, câmara de combate e relicário conectados por passagens transitáveis.
- Colisões em paredes, pilares e sarcófagos; projéteis usam raycast contra cenário.
- Grades fecham na entrada da câmara; três ondas de 4/5/6 inimigos; ambas as grades abrem após a última onda.
- Navegação `AStarGrid2D` com obstáculos e estados das portas.
- Kael com idle, walk, attack, dash, hurt e death; movimentação, disparos, XP e evolução preservados.
- Rastejante Sombrio, Arqueiro Espectral e Guardião de Pedra Corrompido com sprites e comportamentos distintos.
- Dash (Shift), recarga de 0,9s e invulnerabilidade breve.
- HUD com barras de vida/XP, nível, sala, onda, inimigos, minimapa, reserva de corrupção e slots de arma/habilidade.
- Tochas ciano com luz oscilante, runas, musgo, rachaduras, ossadas, ruínas e pilares.
- Efeitos de ataque, dash, dano, impacto, morte, coleta, baú e portas; animação de abertura das grades.
- Baú interativo (E), recompensa única de cura/XP/dano e selo de saída para vitória; derrota/reinício continuam disponíveis.
- Renderização interna 576×324 com filtro nearest e escala inteira, janela padrão 1152×648.

### Arquivos desta etapa

Criados: `dungeon.gd`, `gate.gd`, `hud.gd`, `pixel_actor.gd`, `effects.gd`, `tools/build_art.gd`, `tests/smoke_test.gd`, `tests/capture.gd`, `assets/README.md`, seis PNGs e respectivos metadados de importação/UID gerados pela Godot.

Modificados: `main.gd`, `player.gd`, `enemy.gd`, `projectile.gd`, `experience_orb.gd`, `project.godot`, `.gitignore`, `README.md` e este documento. `main.tscn` e os UIDs anteriores foram preservados.

### Placeholders e escopo

- Sprites e tiles são originais, simples e provisórios; personagens possuem espelhamento lateral, não animação ilustrada para oito direções.
- Layout fixo da dungeon; não há geração procedural nesta slice.
- Corrupção está reservada na HUD; slots não implementam inventário/troca de equipamentos.
- Sem áudio, chefe, save ou meta-progressão permanente. A progressão de nível é da partida.
- Compatibilidade mínima: Godot 4.3 (introdução de `TileMapLayer`); validação realizada com Godot 4.7.2.

### Validação desta etapa

- Importação/verificação do editor headless e execução da cena principal com Godot 4.7.2.
- Testes de integração na engine: **30 verificações, zero falhas**, cobrindo mapa, conexão dos espaços, colisões, dash, portas, navegação, projéteis, arqueiro, ondas, XP/níveis, baú, vitória, derrota e reinício real com R. Execução final com código de saída 0, sem diagnósticos de script.
- Capturas reais com renderizador OpenGL Compatibility, inspecionadas visualmente (vestíbulo, combate e relicário).
- Os testes não substituem uma rodada manual completa de balanceamento; usam posições/dano controlados em algumas verificações.

## Base inicial (histórico)

Primeira versão jogável implementada em 13/10/2026.

### Sistemas disponíveis

- Projeto Godot 4 configurado com cena principal.
- Arena top-down desenhada por código, com quatro salas progressivas.
- Movimentação em oito direções com WASD e setas.
- Ataque à distância com Espaço ou J, usando a direção do movimento ou o cursor.
- Inimigos `shade`, `stalker` e `brute`, cada um com velocidade, vida, dano e recompensa próprios.
- Vida do jogador, dano por contato e janela de invulnerabilidade.
- Orbes de experiência com atração pelo jogador.
- Evolução de nível, cura, aumento de vida máxima e dano.
- HUD com vida, nível, experiência, sala e quantidade de inimigos.
- Estados de sala limpa, derrota e vitória, com reinício usando R.

## Próximos marcos

1. Refinar arte final e animações direcionais; incorporar áudio.
2. Balancear ondas/recompensas em partidas manuais e adicionar escolha de melhorias.
3. Evoluir o layout fixo para salas procedurais e recursos de dados editáveis.
4. Implementar corrupção, equipamentos e habilidades adicionais.
5. Criar chefe e meta-progressão persistente.
