import 'package:flutter/material.dart';

/// Variantes disponíveis do mascote Duolinfo.
enum MascotVariant {
  /// Bode Branco (Mascote principal CEFET-NI / Duolinfo 24 FPS + Interativo).
  white('white', 'Bode Branco', 'Edição 24 FPS interativa'),

  /// Bode Verde (Mascote clássico Duolinfo).
  green('green', 'Bode Verde', 'Edição clássica retrô');

  const MascotVariant(this.id, this.label, this.description);

  final String id;
  final String label;
  final String description;

  static MascotVariant fromId(String? raw) {
    for (final v in MascotVariant.values) {
      if (v.id == raw) return v;
    }
    return MascotVariant.white;
  }
}

/// Estados e animações disponíveis para o mascote.
enum MascotState {
  // 4 estados principais (24 FPS branco + 4 FPS verde)
  idle,
  celebrate,
  sad,
  intense,

  // 19 animações interativas (12 quadros a 24 FPS)
  fireLoop,
  clickPoke,
  clickBleat,
  clickShake,
  clickSpin,
  clickHeart,
  dragStartRight,
  dragMoveRight,
  dragStartLeft,
  dragMoveLeft,
  dragStartUp,
  dragMoveUp,
  dragStartDown,
  dragMoveDown,
  holdGrab,
  wallHitRight,
  wallHitLeft,
  wallHitTop,
  wallHitBottom,
}

/// Metadados técnicos de uma animação do mascote.
class MascotAnimationSpec {
  const MascotAnimationSpec({
    required this.state,
    required this.id,
    required this.title,
    required this.fps,
    required this.frameCount,
    required this.cols,
    required this.rows,
    required this.loop,
    required this.gridAssetPath,
    required this.jsonAssetPath,
    required this.gifAssetPath,
    required this.masterRow,
    required this.masterCol,
    required this.defaultQuote,
    required this.category,
    this.fallbackIcon = Icons.pets_rounded,
  });

  final MascotState state;
  final String id;
  final String title;
  final int fps;
  final int frameCount;
  final int cols;
  final int rows;
  final bool loop;
  final String gridAssetPath;
  final String jsonAssetPath;
  final String gifAssetPath;

  /// Linha e coluna correspondentes na spritesheet master 4x4 (256x256 por célula).
  final int masterRow;
  final int masterCol;

  final String defaultQuote;
  final String category;
  final IconData fallbackIcon;

  Duration get frameDuration => Duration(
    microseconds: (1000000 / (fps <= 0 ? 24 : fps)).round(),
  );

  bool get isCoreState =>
      state == MascotState.idle ||
      state == MascotState.celebrate ||
      state == MascotState.sad ||
      state == MascotState.intense;
}

/// Registro centralizado de todos os spritesheets, GIFs e catálogos JSON do mascote.
/// Evita caminhos espalhados e duplicados pelo projeto.
abstract final class MascotAssets {
  MascotAssets._();

  static const double frameSize = 256.0;

  // Masters 4x4 (1024x1024) e atlas verde
  static const String whiteMasterSheet =
      'assets/mascot/sheets/bode_branco_spritesheet_master.png';
  static const String greenMasterSheet =
      'assets/mascot/sheets/bode_spritesheet_transparent.png';
  static const String greenAtlasJson =
      'assets/mascot/sheets/bode_spritesheet.json';

  // Master 24fps (3072x2048 -> 12x8 = 96 quadros) & catálogos JSON
  static const String white24FpsMasterGrid =
      'assets/mascot/sheets_24fps/bode_branco_24fps_master_grid.png';
  static const String white24FpsMasterJson =
      'assets/mascot/sheets_24fps/bode_branco_24fps_master.json';
  static const String catalog24FpsJson =
      'assets/mascot/sheets_24fps/catalog_24fps.json';
  static const String catalogInteractiveJson =
      'assets/mascot/sheets_interactive/catalog_interactive.json';

  // GIFs do Bode Verde
  static const String greenIdleGif = 'assets/mascot/gifs/green/bode_idle.gif';
  static const String greenCelebrateGif =
      'assets/mascot/gifs/green/bode_celebrate.gif';
  static const String greenSadGif = 'assets/mascot/gifs/green/bode_sad.gif';
  static const String greenIntenseGif =
      'assets/mascot/gifs/green/bode_intense.gif';

  // GIFs 24 FPS do Bode Branco
  static const String whiteIdleGif =
      'assets/mascot/gifs/white_24fps/bode_branco_24fps_idle.gif';
  static const String whiteCelebrateGif =
      'assets/mascot/gifs/white_24fps/bode_branco_24fps_celebrate.gif';
  static const String whiteSadGif =
      'assets/mascot/gifs/white_24fps/bode_branco_24fps_sad.gif';
  static const String whiteIntenseGif =
      'assets/mascot/gifs/white_24fps/bode_branco_24fps_intense.gif';

  /// Catálogo completo das 23 animações (4 principais 24 FPS + 19 interativas).
  static const Map<MascotState, MascotAnimationSpec> specs = {
    MascotState.idle: MascotAnimationSpec(
      state: MascotState.idle,
      id: 'idle',
      title: 'Repouso & Respiração',
      fps: 24,
      frameCount: 24,
      cols: 6,
      rows: 4,
      loop: true,
      gridAssetPath:
          'assets/mascot/sheets_24fps/bode_branco_24fps_idle_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_24fps/bode_branco_24fps_idle.json',
      gifAssetPath: whiteIdleGif,
      masterRow: 0,
      masterCol: 0,
      defaultQuote: 'Bora praticar mais um pouco hoje?',
      category: 'Principais',
      fallbackIcon: Icons.sentiment_satisfied_alt_rounded,
    ),
    MascotState.celebrate: MascotAnimationSpec(
      state: MascotState.celebrate,
      id: 'celebrate',
      title: 'Salto & Comemoração',
      fps: 24,
      frameCount: 24,
      cols: 6,
      rows: 4,
      loop: true,
      gridAssetPath:
          'assets/mascot/sheets_24fps/bode_branco_24fps_celebrate_grid.png',
      jsonAssetPath:
          'assets/mascot/sheets_24fps/bode_branco_24fps_celebrate.json',
      gifAssetPath: whiteCelebrateGif,
      masterRow: 1,
      masterCol: 1,
      defaultQuote: 'Mandou bem demais! Continue evoluindo!',
      category: 'Principais',
      fallbackIcon: Icons.celebration_rounded,
    ),
    MascotState.sad: MascotAnimationSpec(
      state: MascotState.sad,
      id: 'sad',
      title: 'Atenção & Empatia',
      fps: 24,
      frameCount: 24,
      cols: 6,
      rows: 4,
      loop: true,
      gridAssetPath:
          'assets/mascot/sheets_24fps/bode_branco_24fps_sad_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_24fps/bode_branco_24fps_sad.json',
      gifAssetPath: whiteSadGif,
      masterRow: 2,
      masterCol: 2,
      defaultQuote: 'Sem problemas! Errar faz parte do aprendizado.',
      category: 'Principais',
      fallbackIcon: Icons.sentiment_dissatisfied_rounded,
    ),
    MascotState.intense: MascotAnimationSpec(
      state: MascotState.intense,
      id: 'intense',
      title: 'Foco & Ofensiva',
      fps: 24,
      frameCount: 24,
      cols: 6,
      rows: 4,
      loop: true,
      gridAssetPath:
          'assets/mascot/sheets_24fps/bode_branco_24fps_intense_grid.png',
      jsonAssetPath:
          'assets/mascot/sheets_24fps/bode_branco_24fps_intense.json',
      gifAssetPath: whiteIntenseGif,
      masterRow: 3,
      masterCol: 3,
      defaultQuote: 'Foco total! Não deixe sua sequência apagar!',
      category: 'Principais',
      fallbackIcon: Icons.local_fire_department_rounded,
    ),
    MascotState.fireLoop: MascotAnimationSpec(
      state: MascotState.fireLoop,
      id: 'fire_loop',
      title: 'Chamas da Ofensiva',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: true,
      gridAssetPath: 'assets/mascot/sheets_interactive/fire_loop_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/fire_loop.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/fire_loop.gif',
      masterRow: 3,
      masterCol: 3,
      defaultQuote: 'Ofensiva em chamas! Ritmo imparável nos estudos!',
      category: 'Principais',
      fallbackIcon: Icons.local_fire_department_rounded,
    ),
    MascotState.clickPoke: MascotAnimationSpec(
      state: MascotState.clickPoke,
      id: 'click_poke',
      title: 'Pulinho de Atenção',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: false,
      gridAssetPath: 'assets/mascot/sheets_interactive/click_poke_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/click_poke.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/click_poke.gif',
      masterRow: 0,
      masterCol: 3,
      defaultQuote: 'Opa! Pronto para o próximo desafio?',
      category: 'Cliques',
      fallbackIcon: Icons.touch_app_rounded,
    ),
    MascotState.clickBleat: MascotAnimationSpec(
      state: MascotState.clickBleat,
      id: 'click_bleat',
      title: 'Berro Musical (Pronúncia)',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: false,
      gridAssetPath: 'assets/mascot/sheets_interactive/click_bleat_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/click_bleat.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/click_bleat.gif',
      masterRow: 0,
      masterCol: 2,
      defaultQuote: 'Bééé! Vamos praticar a pronúncia juntos!',
      category: 'Cliques',
      fallbackIcon: Icons.record_voice_over_rounded,
    ),
    MascotState.clickShake: MascotAnimationSpec(
      state: MascotState.clickShake,
      id: 'click_shake',
      title: 'Sacudida de Cabeça',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: false,
      gridAssetPath: 'assets/mascot/sheets_interactive/click_shake_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/click_shake.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/click_shake.gif',
      masterRow: 3,
      masterCol: 1,
      defaultQuote: 'Sacudindo a poeira e tentando de novo!',
      category: 'Cliques',
      fallbackIcon: Icons.vibration_rounded,
    ),
    MascotState.clickSpin: MascotAnimationSpec(
      state: MascotState.clickSpin,
      id: 'click_spin',
      title: 'Pirueta 360 com Estrelas',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: false,
      gridAssetPath: 'assets/mascot/sheets_interactive/click_spin_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/click_spin.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/click_spin.gif',
      masterRow: 1,
      masterCol: 2,
      defaultQuote: 'Giro de mestre! Mais uma conquista desbloqueada!',
      category: 'Cliques',
      fallbackIcon: Icons.auto_awesome_rounded,
    ),
    MascotState.clickHeart: MascotAnimationSpec(
      state: MascotState.clickHeart,
      id: 'click_heart',
      title: 'Carinho com Corações',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: false,
      gridAssetPath: 'assets/mascot/sheets_interactive/click_heart_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/click_heart.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/click_heart.gif',
      masterRow: 0,
      masterCol: 1,
      defaultQuote: 'Que ótimo te ver por aqui no Duolinfo!',
      category: 'Cliques',
      fallbackIcon: Icons.favorite_rounded,
    ),
    MascotState.dragStartRight: MascotAnimationSpec(
      state: MascotState.dragStartRight,
      id: 'drag_start_right',
      title: 'Arrastar: Início Direita',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: false,
      gridAssetPath:
          'assets/mascot/sheets_interactive/drag_start_right_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/drag_start_right.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/drag_start_right.gif',
      masterRow: 1,
      masterCol: 0,
      defaultQuote: 'Avançando para a próxima etapa!',
      category: 'Movimento',
      fallbackIcon: Icons.arrow_forward_rounded,
    ),
    MascotState.dragMoveRight: MascotAnimationSpec(
      state: MascotState.dragMoveRight,
      id: 'drag_move_right',
      title: 'Voando para a Direita',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: true,
      gridAssetPath:
          'assets/mascot/sheets_interactive/drag_move_right_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/drag_move_right.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/drag_move_right.gif',
      masterRow: 1,
      masterCol: 1,
      defaultQuote: 'Acelerando rumo à fluência!',
      category: 'Movimento',
      fallbackIcon: Icons.fast_forward_rounded,
    ),
    MascotState.dragStartLeft: MascotAnimationSpec(
      state: MascotState.dragStartLeft,
      id: 'drag_start_left',
      title: 'Arrastar: Início Esquerda',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: false,
      gridAssetPath:
          'assets/mascot/sheets_interactive/drag_start_left_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/drag_start_left.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/drag_start_left.gif',
      masterRow: 1,
      masterCol: 0,
      defaultQuote: 'Revisando passos anteriores!',
      category: 'Movimento',
      fallbackIcon: Icons.arrow_back_rounded,
    ),
    MascotState.dragMoveLeft: MascotAnimationSpec(
      state: MascotState.dragMoveLeft,
      id: 'drag_move_left',
      title: 'Voando para a Esquerda',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: true,
      gridAssetPath:
          'assets/mascot/sheets_interactive/drag_move_left_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/drag_move_left.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/drag_move_left.gif',
      masterRow: 1,
      masterCol: 1,
      defaultQuote: 'Deslizando pelo mapa de estudos!',
      category: 'Movimento',
      fallbackIcon: Icons.fast_rewind_rounded,
    ),
    MascotState.dragStartUp: MascotAnimationSpec(
      state: MascotState.dragStartUp,
      id: 'drag_start_up',
      title: 'Arrastar: Início Cima',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: false,
      gridAssetPath: 'assets/mascot/sheets_interactive/drag_start_up_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/drag_start_up.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/drag_start_up.gif',
      masterRow: 1,
      masterCol: 2,
      defaultQuote: 'Decolando no ranking!',
      category: 'Movimento',
      fallbackIcon: Icons.arrow_upward_rounded,
    ),
    MascotState.dragMoveUp: MascotAnimationSpec(
      state: MascotState.dragMoveUp,
      id: 'drag_move_up',
      title: 'Subindo no Ranking',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: true,
      gridAssetPath: 'assets/mascot/sheets_interactive/drag_move_up_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/drag_move_up.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/drag_move_up.gif',
      masterRow: 1,
      masterCol: 2,
      defaultQuote: 'Rumo ao topo da turma!',
      category: 'Movimento',
      fallbackIcon: Icons.trending_up_rounded,
    ),
    MascotState.dragStartDown: MascotAnimationSpec(
      state: MascotState.dragStartDown,
      id: 'drag_start_down',
      title: 'Arrastar: Início Baixo',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: false,
      gridAssetPath:
          'assets/mascot/sheets_interactive/drag_start_down_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/drag_start_down.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/drag_start_down.gif',
      masterRow: 1,
      masterCol: 3,
      defaultQuote: 'Preparando aterrissagem!',
      category: 'Movimento',
      fallbackIcon: Icons.arrow_downward_rounded,
    ),
    MascotState.dragMoveDown: MascotAnimationSpec(
      state: MascotState.dragMoveDown,
      id: 'drag_move_down',
      title: 'Pressionado Baixo',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: true,
      gridAssetPath:
          'assets/mascot/sheets_interactive/drag_move_down_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/drag_move_down.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/drag_move_down.gif',
      masterRow: 1,
      masterCol: 3,
      defaultQuote: 'Pouso firme! Mantendo a concentração!',
      category: 'Movimento',
      fallbackIcon: Icons.south_rounded,
    ),
    MascotState.holdGrab: MascotAnimationSpec(
      state: MascotState.holdGrab,
      id: 'hold_grab',
      title: 'Suspenso no Ar (Grab)',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: true,
      gridAssetPath: 'assets/mascot/sheets_interactive/hold_grab_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/hold_grab.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/hold_grab.gif',
      masterRow: 1,
      masterCol: 2,
      defaultQuote: 'Ouvindo com atenção! Pode falar!',
      category: 'Interação',
      fallbackIcon: Icons.pan_tool_rounded,
    ),
    MascotState.wallHitRight: MascotAnimationSpec(
      state: MascotState.wallHitRight,
      id: 'wall_hit_right',
      title: 'Impacto Parede Direita',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: false,
      gridAssetPath:
          'assets/mascot/sheets_interactive/wall_hit_right_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/wall_hit_right.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/wall_hit_right.gif',
      masterRow: 2,
      masterCol: 0,
      defaultQuote: 'POW! Cabeça dura para não desistir!',
      category: 'Colisões',
      fallbackIcon: Icons.flash_on_rounded,
    ),
    MascotState.wallHitLeft: MascotAnimationSpec(
      state: MascotState.wallHitLeft,
      id: 'wall_hit_left',
      title: 'Impacto Parede Esquerda',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: false,
      gridAssetPath:
          'assets/mascot/sheets_interactive/wall_hit_left_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/wall_hit_left.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/wall_hit_left.gif',
      masterRow: 2,
      masterCol: 0,
      defaultQuote: 'CLANG! Ricochete direto para os estudos!',
      category: 'Colisões',
      fallbackIcon: Icons.flash_on_rounded,
    ),
    MascotState.wallHitTop: MascotAnimationSpec(
      state: MascotState.wallHitTop,
      id: 'wall_hit_top',
      title: 'Impacto no Teto (Bonk)',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: false,
      gridAssetPath: 'assets/mascot/sheets_interactive/wall_hit_top_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/wall_hit_top.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/wall_hit_top.gif',
      masterRow: 2,
      masterCol: 1,
      defaultQuote: 'BONK! Quase saiu pela órbita!',
      category: 'Colisões',
      fallbackIcon: Icons.stars_rounded,
    ),
    MascotState.wallHitBottom: MascotAnimationSpec(
      state: MascotState.wallHitBottom,
      id: 'wall_hit_bottom',
      title: 'Impacto no Chão (Splat)',
      fps: 24,
      frameCount: 12,
      cols: 6,
      rows: 2,
      loop: false,
      gridAssetPath:
          'assets/mascot/sheets_interactive/wall_hit_bottom_grid.png',
      jsonAssetPath: 'assets/mascot/sheets_interactive/wall_hit_bottom.json',
      gifAssetPath: 'assets/mascot/gifs/interactive/wall_hit_bottom.gif',
      masterRow: 2,
      masterCol: 3,
      defaultQuote: 'SPLAT! Já levantando firme para tentar de novo!',
      category: 'Colisões',
      fallbackIcon: Icons.warning_amber_rounded,
    ),
  };

  static MascotAnimationSpec specFor(MascotState state) => specs[state]!;

  static List<MascotState> get clickReactions => const [
    MascotState.clickPoke,
    MascotState.clickBleat,
    MascotState.clickShake,
    MascotState.clickSpin,
    MascotState.clickHeart,
  ];

  static String masterSheetFor(MascotVariant variant) =>
      variant == MascotVariant.green ? greenMasterSheet : whiteMasterSheet;

  /// Retorna o GIF apropriado para a variante e estado solicitados.
  static String gifFor(MascotState state, {MascotVariant variant = MascotVariant.white}) {
    if (variant == MascotVariant.green) {
      switch (state) {
        case MascotState.idle:
        case MascotState.clickPoke:
        case MascotState.clickBleat:
        case MascotState.clickHeart:
        case MascotState.holdGrab:
          return greenIdleGif;
        case MascotState.celebrate:
        case MascotState.clickSpin:
        case MascotState.dragStartRight:
        case MascotState.dragMoveRight:
        case MascotState.dragStartUp:
        case MascotState.dragMoveUp:
          return greenCelebrateGif;
        case MascotState.sad:
        case MascotState.wallHitBottom:
        case MascotState.wallHitLeft:
        case MascotState.wallHitRight:
        case MascotState.wallHitTop:
        case MascotState.dragStartLeft:
        case MascotState.dragMoveLeft:
        case MascotState.dragStartDown:
        case MascotState.dragMoveDown:
          return greenSadGif;
        case MascotState.intense:
        case MascotState.fireLoop:
        case MascotState.clickShake:
          return greenIntenseGif;
      }
    }
    return specFor(state).gifAssetPath;
  }

  /// Lista completa de todos os 80 assets empacotados para validação em testes.
  static List<String> get allDeclaredAssetPaths => [
    whiteMasterSheet,
    greenMasterSheet,
    greenAtlasJson,
    white24FpsMasterGrid,
    white24FpsMasterJson,
    catalog24FpsJson,
    catalogInteractiveJson,
    greenIdleGif,
    greenCelebrateGif,
    greenSadGif,
    greenIntenseGif,
    for (final spec in specs.values) ...[
      spec.gridAssetPath,
      spec.jsonAssetPath,
      spec.gifAssetPath,
    ],
  ];
}
