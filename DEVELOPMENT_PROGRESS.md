# ECLIPSE — Progresso de desenvolvimento

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
