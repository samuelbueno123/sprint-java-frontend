import 'dart:math';

import '../../audio/system_sound_service.dart';

enum MascotVariant {
  white,
  fire,
}

enum MascotState {
  idle,
  celebrate,
  sad,
  intense,
  clickPoke,
  clickHeart,
  clickSpin,
  clickBleat,
  clickShake,
  holdGrab,
  dragStartRight,
  dragStartLeft,
  dragStartUp,
  dragStartDown,
  dragMoveRight,
  dragMoveLeft,
  dragMoveUp,
  dragMoveDown,
  wallHitRight,
  wallHitLeft,
  wallHitTop,
  wallHitBottom,
  fireLoop,
}

class MascotStateSpec {
  const MascotStateSpec({
    required this.state,
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.defaultQuote,
    required this.gifPath,
    required this.spriteSheetPath,
    required this.jsonPath,
    required this.frameCount,
    required this.columns,
    required this.rows,
    required this.frameWidth,
    required this.frameHeight,
    required this.fps,
    required this.loop,
    this.sfx,
    this.triggerHint = '',
  });

  final MascotState state;
  final String id;
  final String title;
  final String category;
  final String description;
  final String defaultQuote;
  final String gifPath;
  final String spriteSheetPath;
  final String jsonPath;
  final int frameCount;
  final int columns;
  final int rows;
  final int frameWidth;
  final int frameHeight;
  final int fps;
  final bool loop;
  final SystemSfxType? sfx;
  final String triggerHint;

  int get cols => columns;
  String get gifAssetPath => gifPath;
}

abstract final class MascotAssets {
  MascotAssets._();

  static const String baseDir = 'assets/duo_goat_spritesheet';
  static const String catalog24FpsJson =
      '$baseDir/spritesheets_24fps/catalog_24fps.json';
  static const String catalogInteractiveJson =
      '$baseDir/spritesheets_interactive/catalog_interactive.json';
  static const String masterGrid24Fps =
      '$baseDir/bode_branco_24fps_master_grid.png';
  static const String masterInteractiveGrid =
      '$baseDir/bode_branco_interactive_master.png';
  static const String masterSpritesheetJson = '$baseDir/bode_spritesheet.json';

  static String variantName(MascotVariant variant) => switch (variant) {
    MascotVariant.white => 'Bode Duo Branco',
    MascotVariant.fire => 'Bode Duo Modo Chama',
  };

  static String variantSubtitle(MascotVariant variant) => switch (variant) {
    MascotVariant.white =>
      'Sprite oficial da pasta duo_goat_spritesheet em 24 FPS fluidos',
    MascotVariant.fire =>
      'Aura incandescente inspirada no Modo Fogo (Ofensiva Ativa)',
  };

  static MascotStateSpec _coreSpec({
    required MascotState state,
    required String id,
    required String title,
    required String description,
    required String defaultQuote,
    required bool loop,
    SystemSfxType? sfx,
  }) {
    return MascotStateSpec(
      state: state,
      id: id,
      title: title,
      category: 'Base 24 FPS',
      description: description,
      defaultQuote: defaultQuote,
      gifPath: '$baseDir/bode_branco_24fps_$id.gif',
      spriteSheetPath: '$baseDir/spritesheets_24fps/bode_branco_24fps_${id}_grid.png',
      jsonPath: '$baseDir/spritesheets_24fps/bode_branco_24fps_$id.json',
      frameCount: 24,
      columns: 6,
      rows: 4,
      frameWidth: 256,
      frameHeight: 256,
      fps: 24,
      loop: loop,
      sfx: sfx,
      triggerHint: 'Estado emocional principal do Duolinfo',
    );
  }

  static MascotStateSpec _interactiveSpec({
    required MascotState state,
    required String id,
    required String title,
    required String category,
    required String description,
    required String defaultQuote,
    required bool loop,
    SystemSfxType? sfx,
    String triggerHint = '',
  }) {
    return MascotStateSpec(
      state: state,
      id: id,
      title: title,
      category: category,
      description: description,
      defaultQuote: defaultQuote,
      gifPath: '$baseDir/$id.gif',
      spriteSheetPath: '$baseDir/spritesheets_interactive/${id}_grid.png',
      jsonPath: '$baseDir/spritesheets_interactive/$id.json',
      frameCount: 12,
      columns: 6,
      rows: 2,
      frameWidth: 256,
      frameHeight: 256,
      fps: 24,
      loop: loop,
      sfx: sfx,
      triggerHint: triggerHint,
    );
  }

  static final Map<MascotState, MascotStateSpec> specs = Map.unmodifiable({
    MascotState.idle: _coreSpec(
      state: MascotState.idle,
      id: 'idle',
      title: 'Repouso & Respiração',
      description: 'Balanço suave e piscar atento acompanhando seu painel.',
      defaultQuote: 'Estou aqui torcendo por você! Vamos aprender hoje?',
      loop: true,
    ),
    MascotState.celebrate: _coreSpec(
      state: MascotState.celebrate,
      id: 'celebrate',
      title: 'Celebração & Vitória',
      description: 'Salto e chifres brilhando ao concluir metas e lições.',
      defaultQuote: 'Mandou bem demais! Mais XP direto na conta!',
      loop: false,
      sfx: SystemSfxType.success,
    ),
    MascotState.sad: _coreSpec(
      state: MascotState.sad,
      id: 'sad',
      title: 'Tristeza & Apoio',
      description: 'Orelhas caídas com incentivo gentil para tentar de novo.',
      defaultQuote: 'Não desanime! Todo erro nos aproxima da fluência.',
      loop: true,
      sfx: SystemSfxType.defeat,
    ),
    MascotState.intense: _coreSpec(
      state: MascotState.intense,
      id: 'intense',
      title: 'Foco & Intensidade',
      description: 'Olhar determinado pronto para desafios e pronúncia.',
      defaultQuote: 'Modo foco ativado! Você consegue dominar isso agora.',
      loop: true,
      sfx: SystemSfxType.transition,
    ),
    MascotState.clickPoke: _interactiveSpec(
      state: MascotState.clickPoke,
      id: 'click_poke',
      title: 'Cutucão Curioso',
      category: 'Cliques',
      description: 'Pulinho surpreso ao tocar no Bode Duo.',
      defaultQuote: 'Opa! Me cutucou! Pronto para a próxima lição?',
      loop: false,
      sfx: SystemSfxType.pop,
      triggerHint: 'Clique simples no mascote',
    ),
    MascotState.clickHeart: _interactiveSpec(
      state: MascotState.clickHeart,
      id: 'click_heart',
      title: 'Carinho & Corações',
      category: 'Cliques',
      description: 'Sopro de carinho agradecendo pela sua dedicação.',
      defaultQuote: 'Você é o melhor estudante do universo! ❤️',
      loop: false,
      sfx: SystemSfxType.pop,
      triggerHint: 'Clique / aprovação / avaliação alta',
    ),
    MascotState.clickSpin: _interactiveSpec(
      state: MascotState.clickSpin,
      id: 'click_spin',
      title: 'Giro Rápido 360°',
      category: 'Cliques',
      description: 'Pirueta energética processando insights de IA.',
      defaultQuote: 'Processando ideias em alta rotação!',
      loop: false,
      sfx: SystemSfxType.jump,
      triggerHint: 'Análise IA / clique consecutivo',
    ),
    MascotState.clickBleat: _interactiveSpec(
      state: MascotState.clickBleat,
      id: 'click_bleat',
      title: 'Balido "Bééé!"',
      category: 'Cliques',
      description: 'Conversando e incentivando na prática de diálogo.',
      defaultQuote: 'Bééé! Que tal praticar pronúncia ou conversação agora?',
      loop: false,
      sfx: SystemSfxType.bleat,
      triggerHint: 'Chat IA / avisos / clique',
    ),
    MascotState.clickShake: _interactiveSpec(
      state: MascotState.clickShake,
      id: 'click_shake',
      title: 'Sacudida de Alerta',
      category: 'Cliques',
      description: 'Balanço divertido para chamar atenção a detalhes.',
      defaultQuote: 'Psiu! Confira esse detalhe antes de enviar!',
      loop: false,
      sfx: SystemSfxType.pop,
      triggerHint: 'Validação pendente / clique',
    ),
    MascotState.holdGrab: _interactiveSpec(
      state: MascotState.holdGrab,
      id: 'hold_grab',
      title: 'Segurando o Bode',
      category: 'Interação Física',
      description: 'Patas balançando ao segurar o mascote por 250ms.',
      defaultQuote: 'Ei, me segura direito! Para onde vamos voar?',
      loop: true,
      sfx: SystemSfxType.pop,
      triggerHint: 'Pressionar e segurar',
    ),
    MascotState.dragStartRight: _interactiveSpec(
      state: MascotState.dragStartRight,
      id: 'drag_start_right',
      title: 'Impulso para Direita',
      category: 'Arrasto',
      description: 'Inclinação inicial ao puxar o bode para a direita.',
      defaultQuote: 'Avançando para a direita!',
      loop: false,
      sfx: SystemSfxType.jump,
    ),
    MascotState.dragStartLeft: _interactiveSpec(
      state: MascotState.dragStartLeft,
      id: 'drag_start_left',
      title: 'Impulso para Esquerda',
      category: 'Arrasto',
      description: 'Inclinação inicial ao puxar o bode para a esquerda.',
      defaultQuote: 'Voltando um passo para revisar!',
      loop: false,
      sfx: SystemSfxType.jump,
    ),
    MascotState.dragStartUp: _interactiveSpec(
      state: MascotState.dragStartUp,
      id: 'drag_start_up',
      title: 'Decolagem para Cima',
      category: 'Arrasto',
      description: 'Decolagem ao impulsionar o bode para o alto.',
      defaultQuote: 'Subindo de nível sem parar!',
      loop: false,
      sfx: SystemSfxType.jump,
    ),
    MascotState.dragStartDown: _interactiveSpec(
      state: MascotState.dragStartDown,
      id: 'drag_start_down',
      title: 'Mergulho para Baixo',
      category: 'Arrasto',
      description: 'Aterrissagem veloz descendo pela tela.',
      defaultQuote: 'Descendo para explorar os detalhes!',
      loop: false,
      sfx: SystemSfxType.jump,
    ),
    MascotState.dragMoveRight: _interactiveSpec(
      state: MascotState.dragMoveRight,
      id: 'drag_move_right',
      title: 'Voo Contínuo à Direita',
      category: 'Arrasto',
      description: 'Flutuando continuamente enquanto avança à direita.',
      defaultQuote: 'Próxima questão a caminho!',
      loop: true,
    ),
    MascotState.dragMoveLeft: _interactiveSpec(
      state: MascotState.dragMoveLeft,
      id: 'drag_move_left',
      title: 'Voo Contínuo à Esquerda',
      category: 'Arrasto',
      description: 'Flutuando continuamente retornando para a esquerda.',
      defaultQuote: 'Revisando conteúdo anterior!',
      loop: true,
    ),
    MascotState.dragMoveUp: _interactiveSpec(
      state: MascotState.dragMoveUp,
      id: 'drag_move_up',
      title: 'Ascensão na Trilha',
      category: 'Arrasto',
      description: 'Subindo firmemente pelos módulos da trilha.',
      defaultQuote: 'Cada módulo desbloqueado leva você ao topo!',
      loop: true,
    ),
    MascotState.dragMoveDown: _interactiveSpec(
      state: MascotState.dragMoveDown,
      id: 'drag_move_down',
      title: 'Queda Controlada',
      category: 'Arrasto',
      description: 'Descida estável deslizando pelo palco.',
      defaultQuote: 'Descendo suavemente pela área de estudos!',
      loop: true,
    ),
    MascotState.wallHitRight: _interactiveSpec(
      state: MascotState.wallHitRight,
      id: 'wall_hit_right',
      title: 'Impacto na Borda Direita',
      category: 'Colisões',
      description: 'Quique cômico ao atingir a parede direita.',
      defaultQuote: 'Pof! Borda direita alcançada!',
      loop: false,
      sfx: SystemSfxType.splat,
    ),
    MascotState.wallHitLeft: _interactiveSpec(
      state: MascotState.wallHitLeft,
      id: 'wall_hit_left',
      title: 'Impacto na Borda Esquerda',
      category: 'Colisões',
      description: 'Quique cômico ao atingir a parede esquerda.',
      defaultQuote: 'Tum! Borda esquerda!',
      loop: false,
      sfx: SystemSfxType.splat,
    ),
    MascotState.wallHitTop: _interactiveSpec(
      state: MascotState.wallHitTop,
      id: 'wall_hit_top',
      title: 'Batida no Teto',
      category: 'Colisões',
      description: 'Chifrada leve no topo do palco de física.',
      defaultQuote: 'Topo máximo atingido!',
      loop: false,
      sfx: SystemSfxType.splat,
    ),
    MascotState.wallHitBottom: _interactiveSpec(
      state: MascotState.wallHitBottom,
      id: 'wall_hit_bottom',
      title: 'Aterrissagem no Chão',
      category: 'Colisões',
      description: 'Quique amaciado ao tocar o piso do palco.',
      defaultQuote: 'Pés firmes de volta ao chão!',
      loop: false,
      sfx: SystemSfxType.splat,
    ),
    MascotState.fireLoop: _interactiveSpec(
      state: MascotState.fireLoop,
      id: 'fire_loop',
      title: 'Modo Chama da Ofensiva',
      category: 'Modo Chama',
      description: 'Energia máxima quando sua sequência de estudos está pegando fogo!',
      defaultQuote: 'Sua ofensiva está em chamas! Continue imparável!',
      loop: true,
      sfx: SystemSfxType.fire,
      triggerHint: 'Ofensiva ativa / Botão Fogo',
    ),
  });

  static MascotStateSpec specFor(MascotState state) => specs[state]!;

  static List<MascotState> get allStates => MascotState.values;

  static const List<MascotState> coreStates = [
    MascotState.idle,
    MascotState.celebrate,
    MascotState.sad,
    MascotState.intense,
  ];

  static const List<MascotState> clickReactions = [
    MascotState.clickPoke,
    MascotState.clickHeart,
    MascotState.clickSpin,
    MascotState.clickBleat,
    MascotState.clickShake,
  ];

  static const List<MascotState> dragStates = [
    MascotState.dragStartRight,
    MascotState.dragStartLeft,
    MascotState.dragStartUp,
    MascotState.dragStartDown,
    MascotState.dragMoveRight,
    MascotState.dragMoveLeft,
    MascotState.dragMoveUp,
    MascotState.dragMoveDown,
  ];

  static const List<MascotState> wallHitStates = [
    MascotState.wallHitRight,
    MascotState.wallHitLeft,
    MascotState.wallHitTop,
    MascotState.wallHitBottom,
  ];

  static String gifFor(
    MascotState state, {
    MascotVariant variant = MascotVariant.white,
  }) => specFor(state).gifPath;

  static String sheetFor(
    MascotState state, {
    MascotVariant variant = MascotVariant.white,
  }) => specFor(state).spriteSheetPath;

  static String jsonFor(MascotState state) => specFor(state).jsonPath;

  static List<String> get allDeclaredAssetPaths {
    final paths = <String>{
      catalog24FpsJson,
      catalogInteractiveJson,
      masterGrid24Fps,
      masterInteractiveGrid,
      masterSpritesheetJson,
    };
    for (final spec in specs.values) {
      paths.add(spec.gifPath);
      paths.add(spec.spriteSheetPath);
      paths.add(spec.jsonPath);
    }
    return List.unmodifiable(paths);
  }

  static const List<String> _idleQuotes = [
    'Cinco minutinhos por dia já mantêm sua ofensiva viva!',
    'Clique, segure ou arraste o Bode Duo para brincar entre as lições!',
    'Revisão espaçada + pronúncia = confiança real ao falar.',
    'Complete lições para ver seu anel de XP brilhar na página inicial!',
    'Ative o Modo Fogo quando estiver pronto para superar seus recordes!',
  ];

  static String randomIdleQuote([int? seed]) {
    final rng = seed == null ? Random() : Random(seed);
    return _idleQuotes[rng.nextInt(_idleQuotes.length)];
  }
}
