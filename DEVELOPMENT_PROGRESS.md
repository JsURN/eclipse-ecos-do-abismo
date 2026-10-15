# ECLIPSE — Progresso de desenvolvimento

## Integração dos novos assets conceituais (13/10/2026)

Os três anexos estavam acessíveis. Foram inspecionados antes das alterações no jogo: Kael e inimigos 1448×1086; cenário 1672×941, todos RGBA com transparência real e muito alpha parcial. Os originais estão copiados sem alteração em `assets/source_art/`. O preto da visualização não foi removido por chroma key.

### Implementado e integrado

- 48 frames válidos mapeados por recorte/pivô individual, sem presumir grade uniforme ou regenerar as imagens: 20 de Kael, 11 do rastejante, 8 do arqueiro e 9 do guardião. `concept_manifest.json` registra exatamente as sequências carregadas.
- `AnimatedSprite2D`/`SpriteFrames` com pivô nos pés. Kael: pose idle frontal/costas, walk com dois frames por vista, ataque de três frames, dash de três, hurt de dois e death de seis. Os inimigos usam idle, walk, ataque, hurt e morte disponíveis; idle e alguns hurt são poses únicas, não ciclos inventados.
- Poses de ataque ligadas a liberação de projétil/contato da IA. Impactos ligados ao dano real. Cadências, vida, hitboxes, velocidades, XP, ondas e recompensas preservados.
- TileSet editável `assets/tilesets/catacombs/catacombs.tres`, atlas recortado de 256×256 e duas TileMapLayer por células. Piso, fissuras, musgo, faces/cantos adaptados, corredor e selo lunar. Colisões das paredes e bases mantidas.
- Portas abertas/fechadas da nova folha ligadas aos corpos físicos e à transição existente. Baú fechado/aberto, recompensa e saída lunar continuam funcionais.
- Pilares, estátuas, sarcófagos, tochas, runas, pedestal/cristal, ossos, raízes, entulho e corrupção usam os novos recortes. Y-sort pelos pés, sombras simples e iluminação localizada mais clara.
- Arco, brilho de impacto, corrupção e flecha espectral extraídos das folhas; partículas/afterimages/números existentes complementam os efeitos. Retrato de Kael na HUD também foi extraído.
- Resolução 768×432, zoom inteiro 2× e janela padrão 1536×864 em escala inteira 2×. Campo do mundo permanece 384×216. Arte/camadas em escala 0,5 combinada ao zoom 2× resulta em pixels nativos nítidos, sem mudar dimensões físicas nem distorcer proporções dos personagens.
- Foco na câmara de combate completa com três ondas, portas e obstáculos; os outros espaços existentes usam o atlas preparado e continuam conectados. Não foram adicionadas masmorras/sistemas novos.

### Arquivos criados

- `concept_art.gd`: carregamento/cache dos SpriteFrames definidos pelo manifest.
- `tools/prepare_concept_assets.gd`: mapa de recortes, normalização/pivôs e extração offline reproduzível.
- `tools/build_concept_tileset.gd`: salva o TileSet com colisões editáveis.
- `assets/source_art/`: três fontes preservadas, `.gdignore` e candidatos rejeitados recuperáveis em `rejected_crops/`.
- `assets/characters/kael/`, `assets/enemies/shadow_crawler/`, `assets/enemies/spectral_archer/`, `assets/enemies/stone_guardian/`: PNGs de frames e retrato.
- `assets/tilesets/catacombs/`: atlas e `catacombs.tres`.
- `assets/environments/props/`: 14 recortes individuais e atlases de detalhes, portas e recompensas.
- `assets/effects/`: arco, impacto, flecha espectral e corrupção.
- `assets/concept_manifest.json`, `assets/INTEGRATED_FILES.txt`, `assets/INTEGRATION_REPORT.md`; metadados de importação/UID da Godot.

O inventário contém todos os caminhos dos recursos preparados: 71 PNGs derivados ativos, três originais, manifest e TileSet. Os 11 candidatos não usados foram movidos para a pasta de revisão; nada do projeto anterior foi removido.

### Arquivos modificados

`pixel_actor.gd`, `player.gd`, `enemy.gd`, `dungeon.gd`, `gate.gd`, `effects.gd`, `projectile.gd`, `main.gd`, `hud.gd`, `atmosphere.gd`, `pixel_camera.gd`, `project.godot`, `tests/smoke_test.gd`, `tests/capture.gd`, `README.md`, `assets/README.md` e este documento. `main.tscn`, saves/estrutura de persistência e PNGs legados foram preservados.

### Limitações e retoques manuais

Idle é pose estática; walk tem poucos frames; direções faltantes usam vista oblíqua/espelhamento. Hurt do arqueiro/guardião tem uma pose com flash. Alguns golpes e corpos caídos ainda podem precisar de ajuste fino de pivôs/halos, pois a fonte possui efeitos encostados em vizinhos. Cantos de parede foram adaptados por recomposição/rotação de faces e precisam de revisão artística fina; portas leste/oeste são rotações das arquiteturas disponíveis e alternam estados com crossfade, sem inventar frames de abertura. Corrupção permanece visual/reserva de HUD. As limitações por asset estão em `assets/INTEGRATION_REPORT.md`.

### Testes efetivamente executados

Godot **4.7.2**: importação do editor headless, preparação dos recortes, gravação do TileSet e teste de integração da cena real. **47 verificações, zero falhas**, incluindo caminhos dos sprites novos, avanço real de walk/attack/dash/hurt/death, pivô e raio de colisão, morte animada de inimigos, TileSet por células, portas, navegação, projéteis/dano, três ondas, XP, baú, vitória, derrota e reinício com R. Capturas reais OpenGL Compatibility do vestíbulo, câmara, relicário e feedback foram inspecionadas; na captura da câmara, posições de QA controladas permitem ver os três tipos de inimigo.

Os testes usam algumas posições/dano controlados e não equivalem a uma partida manual completa, exportação ou benchmark. Nenhuma imagem conceitual é mostrada como fundo gigante para simular gameplay.

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
