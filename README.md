# Duolinfo Frontend — Flutter & Dart

Aplicação cliente moderna, reativa e multiplataforma (Web, Android, iOS e Desktop) para a plataforma de aprendizagem de idiomas **Duolinfo**, construída com **Flutter 3.x**, adotando **Clean Architecture + Feature-First**, design system baseado em **`shadcn_ui`**, composições fluidas com **`velocity_x`**, microinterações com **`flutter_animate`**, resiliência de rede com **Dio + Correlation IDs** e sincronização em tempo real via **Server-Sent Events (SSE)**.

---

## Sumário

1. [Visão Geral da Arquitetura](#visão-geral-da-arquitetura)
2. [Estrutura de Diretórios](#estrutura-de-diretórios)
3. [Design System e Experiência do Usuário (UI/UX)](#design-system-e-experiência-do-usuário-uiux)
4. [Gerenciamento de Estado e Reatividade](#gerenciamento-de-estado-e-reatividade)
5. [Comunicação de Rede, Resiliência e Sessão](#comunicação-de-rede-resiliência-e-sessão)
6. [Módulos e Recursos por Feature](#módulos-e-recursos-por-feature)
7. [Dashboards Especializados por Perfil](#dashboards-especializados-por-perfil)
8. [Configuração de Ambientes e Variáveis](#configuração-de-ambientes-e-variáveis)
9. [Instruções de Execução e Desenvolvimento](#instruções-de-execução-e-desenvolvimento)
10. [Execução da Suíte de Testes](#execução-da-suíte-de-testes)
11. [Convenções de Código e Boas Práticas](#convenções-de-código-e-boas-práticas)

---

## Visão Geral da Arquitetura

O frontend adota o padrão **Clean Architecture** organizado por **Features**, promovendo total desacoplamento entre a interface de usuário (UI) e as regras de negócio e comunicação com a API REST.

```mermaid
flowchart TD
    subgraph PresentationLayer["Camada de Apresentação (UI)"]
        Pages["Pages / Screens (Views)"]
        Widgets["Componentes Shadcn / Widgets Customizados"]
        ViewModels["ViewModels (ChangeNotifier / State)"]
    end

    subgraph DomainLayer["Camada de Domínio (Regras Puras)"]
        UseCases["Use Cases (Casos de Uso Interactors)"]
        Entities["Entidades de Domínio Imutáveis"]
        RepoInterfaces["Interfaces de Repositório (Contratos)"]
    end

    subgraph DataLayer["Camada de Dados (Infraestrutura)"]
        RepoImpl["Implementação dos Repositórios"]
        DataSources["Data Sources (Remote HTTP / Google Auth / SSE)"]
        Models["Models (fromMap / toMap / Serialização)"]
    end

    subgraph CoreLayer["Core & Serviços Transversais"]
        ApiClient["ApiClient (Dio com Timeouts e Interceptors)"]
        SessionStore["SessionStore (Sessão Reativa & Notifier)"]
        Realtime["RealtimeSyncService (SSE)"]
    end

    Pages --> ViewModels
    ViewModels --> UseCases
    UseCases --> RepoInterfaces
    UseCases --> Entities
    RepoImpl ..|> RepoInterfaces
    RepoImpl --> DataSources
    DataSources --> ApiClient
    DataSources --> Realtime
    ApiClient --> SessionStore
    DataSources --> Models
    RepoImpl --> Models
```

### Princípios Arquiteturais
- **Independência de Framework**: As entidades de domínio (`domain/entities`) são objetos puros em Dart, sem dependência de bibliotecas de terceiros ou classes de infraestrutura.
- **Isolamento de Erros**: O `ApiClient` intercepta exceções do Dio e converte respostas HTTP em instâncias estruturadas de `ApiException`, expondo mensagens traduzidas, mapas de validação e Correlation IDs.
- **Inversão de Dependências**: As camadas superiores dependem apenas de contratos abstratos (`repositories/*.dart`), facilitando a substituição de datasources e viabilizando testes unitários sem chamadas de rede.

---

## Estrutura de Diretórios

```text
lib/
├── core/                                # Módulos globais transversais
│   ├── config/                          # AppConfig e AppEnvironment
│   ├── localization/                    # AppLocaleController (i18n)
│   ├── network/                         # ApiClient, ApiException, SessionStore, RealtimeSync
│   └── theme/                           # AppThemeController (Dark / Light / System)
├── features/
│   ├── access/                          # Seleção de acesso rápido e redirecionamento
│   │   └── presentation/pages/          # AccessSelectionPage
│   ├── auth/                            # Autenticação e Onboarding
│   │   ├── data/                        # Datasources, Models e Repositórios de Auth
│   │   ├── domain/                      # Entidades (AuthSession, UserRole) e UseCases
│   │   └── presentation/                # LoginPage, Signup, ViewModels e Formulários
│   └── dashboard/                       # Painéis e Funcionalidades Pedagógicas
│       ├── data/                        # DashboardRemoteDataSource e Models
│       ├── domain/                      # DashboardData, Perfil Estudante e Docente
│       └── presentation/
│           ├── pages/                   # DashboardPage principal
│           ├── viewmodels/              # DashboardViewModel e DashboardState
│           └── widgets/                 # Componentes de interface e Dashboards
│               └── advanced_learning/   # 10 Visualizações de Recursos Avançados
├── app.dart                             # Widget raiz com MaterialApp, Temas e Rotas
└── main.dart                            # Ponto de entrada e injeção de dependências
```

---

## Design System e Experiência do Usuário (UI/UX)

A interface foi reformulada para oferecer padrões visuais de alta fidelidade e ergonomia:

1. **`shadcn_ui`**:
   - Componentização refinada para cartões (`ShadCard`), botões com estados de carregamento (`ShadButton`), caixas de diálogo modais (`ShadDialog`), abas de navegação (`ShadTabs`) e badges indicativos (`ShadBadge`).
2. **`velocity_x`**:
   - Composição estrutural concisa, utilitários de espaçamento (`VxBox`, `.h(16)`, `.w(12)`), tipografia expressiva e alinhamentos fluidos.
3. **`flutter_animate`**:
   - Microinterações em cards, revelações graduais de elementos de lista (`.fade().slideY()`) e feedback tátil em ações de gamificação.
4. **Layout Adaptativo Desktop vs Mobile (`ResponsiveLayout`)**:
   - **Desktop (>= 900px)**: Barra lateral persistente de navegação (`DashboardSidebar`), multi-colunas de conteúdo com visualização simultânea de métricas, cards informativos e painéis laterais de suporte.
   - **Mobile (< 900px)**: Barra de topo simplificada (`DashboardTopBar`), gaveta de navegação deslizante (*Drawer*), cartões verticais empilhados e zonas de toque otimizadas para uso com uma mão.

---

## Gerenciamento de Estado e Reatividade

O gerenciamento de estado é fundamentado no padrão **MVVM (Model-View-ViewModel)** com primitivas reativas do Flutter:

- **`ChangeNotifier`**: Utilizado em viewmodels (`LoginViewModel`, `RegistrationViewModel`, `DashboardViewModel`) para encapsular o estado da tela, disparar eventos de carregamento (`isLoading`), armazenar dados e notificar a camada de apresentação através de `AnimatedBuilder` ou `ListenableBuilder`.
- **`ValueNotifier`**: Utilizado em fluxos de eventos específicos, como no `SessionStore.sessionExpiredNotifier`, permitindo que o cliente reaja globalmente à expiração de sessão sem acoplamento direto com a árvore de widgets.
- **Imutabilidade de Estado**: O `DashboardState` expõe propriedades imutáveis de visualização, prevenindo mutações concorrentes de estado durante o ciclo de renderização.

---

## Comunicação de Rede, Resiliência e Sessão

### `ApiClient` Resiliente
Encapsula o cliente HTTP **Dio** com garantias de tolerância a falhas:
- **Timeouts Configuráveis**:
  - `connectTimeout`: 15 segundos.
  - `receiveTimeout`: 20 segundos.
  - `sendTimeout`: 15 segundos.
- **Rastreabilidade com Correlation ID**:
  - Toda requisição HTTP injeta automaticamente um cabeçalho `X-Correlation-Id` no formato `req-<timestamp>-<hash>`.
  - Permite correlacionar erros apresentados na interface do usuário diretamente com os logs do servidor backend.
- **Tratamento Tipado via `ApiException`**:
  - Mapeia respostas de erro da API e extrai `message`, `statusCode`, `error`, `path`, `correlationId` e o mapa de validação `validationErrors`.
  - Diferencia automaticamente falhas de perda de conectividade (`isNetworkError`) de estouro de tempo de resposta (`isTimeout`).

### `SessionStore` e Recuperação de Sessão
- Armazena em memória os tokens emitidos pelo backend (`accessToken` e `refreshToken`).
- Ao receber uma resposta HTTP 401 terminal (que não pôde ser recuperada com renovação de token), o interceptor dispara `SessionStore.notifySessionExpired()`.
- A aplicação intercepta a notificação e guia o usuário suavemente de volta à tela de login, exibindo aviso de segurança e preservando dados em formulários quando apropriado.

### Sincronização em Tempo Real (`RealtimeSyncService`)
- Conecta-se ao endpoint Server-Sent Events `/api/realtime/stream?token=<accessToken>`.
- Atualiza dados em segundo plano quando novos comunicados de turmas, avaliações de exercícios ou notificações são transmitidos pelo servidor, sem necessidade de *polling* agressivo.

---

## Módulos e Recursos por Feature

### 1. Autenticação e Onboarding (`features/auth`)
- **Login Híbrido**: Entrada tradicional com e-mail/senha ou autenticação federada com Google OAuth2.
- **Cadastro Especializado**: Fluxos guiados para estudantes (com seleção de idiomas preferidos) e professores (com seleção de instituição e áreas de especialização).
- **Recuperação de Senha**: Solicitação de código de verificação por e-mail e redefinição de credenciais.

### 2. Recursos Educacionais Avançados (`features/dashboard/presentation/widgets/advanced_learning`)
A plataforma conta com **10 módulos pedagógicos especializados**:

1. **`PersonalizedLearningPathView`**: Visualização interativa da trilha de aprendizagem CEFR (A1 a C2), com progresso de módulos, marcos alcançados e teste diagnóstico inicial.
2. **`SrsReviewView`**: Sessões de estudo baseadas em repetição espaçada (algoritmo SM-2), permitindo classificar cartões de memória por facilidade (0 a 5) com cálculo de intervalos automáticos.
3. **`AiConversationView`**: Roleplay conversacional com inteligência artificial generativa em tempo real, fornecendo sugestões e correções gramaticais imediatas.
4. **`PronunciationPracticeView`**: Desafios fonéticos com pontuação de acurácia, reprodução de áudio nativo e sintetização vocal.
5. **`CommunityPeerReviewView`**: Feed colaborativo para envio de redações, avaliação por outros estudantes e moderação por denúncias.
6. **`StudentVocabularyView`**: Glossário pessoal com filtros por idioma, domínio e nível de maestria (1 a 5).
7. **`StudentMistakesView`**: Caderno inteligente de erros cometidos em exercícios, com botão para solicitar explicação didática gerada por IA.
8. **`ClassAnnouncementsView`**: Mural de comunicados prioritários da turma emitidos pelo professor.
9. **`TeacherClassAnalyticsView`**: Relatórios preditivos com identificação visual de estudantes em risco acadêmico e taxa de submissão de tarefas.
10. **`TeacherStudentNotesDialog`**: Registro de anotações pedagógicas privadas feitas por docentes sobre o progresso individual de cada aluno.

---

## Dashboards Especializados por Perfil

O `DashboardPage` adapta dinamicamente a área de trabalho com base no papel do usuário autenticado:

- **Dashboard do Estudante (`StudentDashboardView`)**:
  - Exibição de ofensiva atual (*streak*), meta diária de estudos e botão de compra de congelamento com pontos.
  - Cartões de idiomas ativos com nível e pontuação acumulada.
  - Atalhos rápidos para as atividades do dia (SRS, conversa com IA, pronúncia e caderno de erros).
- **Dashboard do Professor (`TeacherDashboardView`)**:
  - Visão geral de turmas ativas e disciplinas lecionadas.
  - Acesso ao Estúdio de Criação de Exercícios (`TeacherCreateExerciseScreen`), gerador assistido por IA e clonagem de atividades.
  - Acesso à analítica da turma e mural de comunicados.
- **Dashboard do Administrador Institucional (`AdminDashboardView`)**:
  - Monitoramento de solicitações de aprovação de professores pendentes.
  - Cadastro e vinculação de turmas às escolas da rede.
- **Dashboard do Administrador Global**:
  - Supervisão de entidades do sistema, catálogo global e auditoria.

---

## Configuração de Ambientes e Variáveis

A configuração do app é unificada na classe [`AppConfig`](file:///home/antigravity/samuelbueno123/sprint-java-frontend/lib/core/config/app_config.dart), que lê variáveis do arquivo `.env` ou injetadas via `--dart-define`:

| Variável | Descrição | Padrão (Desenvolvimento) |
| :--- | :--- | :--- |
| `API_BASE_URL` | URL base do backend Spring Boot | `http://localhost:8080` *(ou `http://10.0.2.2:8080` no emulador Android)* |
| `GOOGLE_WEB_CLIENT_ID` | OAuth Client ID para Flutter Web | Identificador cadastrado no Google Cloud Console |
| `GOOGLE_SERVER_CLIENT_ID` | OAuth Client ID do servidor Web | Identificador equivalente ao `GOOGLE_CLIENT_ID` do backend |
| `GOOGLE_ANDROID_CLIENT_ID`| Client ID para dispositivos Android | Registrado com SHA-1 do keystore |
| `GOOGLE_IOS_CLIENT_ID` | Client ID para dispositivos iOS | Registrado com o Bundle ID correspondente |

---

## Instruções de Execução e Desenvolvimento

### Pré-requisitos
- Flutter SDK 3.22+ instalado e configurado (`flutter doctor`).
- Google Chrome instalado (para desenvolvimento Web).
- Emulador Android ou dispositivo físico conectado (para desenvolvimento Mobile).

### 1. Obtenção de Dependências
```bash
flutter pub get
```

### 2. Execução em Ambiente Web (Desktop)
```bash
flutter run -d chrome --web-port=3000
```
> **Nota**: A porta `3000` está pré-autorizada nas configurações de CORS do backend Duolinfo.

### 3. Execução em Emulador Android
```bash
flutter run -d android
```
*(O `AppConfig` detecta o ambiente Android e roteia automaticamente as requisições para `http://10.0.2.2:8080`)*

### 4. Execução em Dispositivo Físico via USB
Ao utilizar um smartphone físico conectado por cabo:
```bash
adb reverse tcp:8080 tcp:8080
flutter run
```

---

## Execução da Suíte de Testes

O projeto conta com **104 testes automatizados** com **100% de taxa de aprovação**:

```bash
flutter test
```

### Categorias de Teste Cobertas
- **Testes de Rede e Resiliência** (`test/core/network/`): Validação de injeção de Correlation IDs, tratamento de timeouts e desserialização de `ApiException`.
- **Testes de Autenticação** (`test/features/auth/`): Validação de fluxos de login com senha, Google Sign-In, ViewModels e validações de formulário.
- **Testes de Dashboards** (`test/features/dashboard/`): Renderização de layouts responsivos, estados de carregamento, erro e ausência de dados.
- **Testes de Integração de UI** (`test/integration_libraries_test.dart`): Coexistência harmônica entre `shadcn_ui`, `velocity_x` e `flutter_animate`.

---

## Convenções de Código e Boas Práticas

1. **Separação Rígida de Camadas**: Widgets nunca invocam datasources HTTP diretamente; toda comunicação passa por um ViewModel ou UseCase.
2. **Tratamento de Nulos e Segurança de Tipos**: Utilização de tipos estritos e tratamento defensivo com fallbacks claros em dados de API.
3. **Internacionalização (i18n)**: Textos e mensagens utilizam `AppLocaleController` para permitir suporte a múltiplos idiomas.
4. **Respeito ao Tema do Sistema**: O aplicativo suporta tema Claro, Escuro e sincronização com o sistema operacional através do `AppThemeController`.
