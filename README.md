# Duolinfo Flutter

## Arquitetura

O código é organizado por feature. `features/auth` usa camadas `data`, `domain` e
`presentation`; a tela depende do `LoginViewModel`, que chama use cases e um
repositório. A UI não conhece tokens, HTTP, URLs de API ou regras de autorização.
Após o Google Sign-In, somente o `idToken` e o papel escolhido são enviados ao
backend em `POST /api/auth/google`. O backend valida identidade, papel e devolve
a sessão; o cliente apenas trata estados de interface e a configuração necessária
para abrir o provedor OAuth.

## Ambientes e configuração

`AppConfig` é a única fonte de configuração. Não há URL de backend ou decisão de
plataforma em features. O datasource do Google encapsula as diferenças: Web usa o
client ID Web, iOS usa o client ID iOS, e Android/dispositivos nativos usam a
configuração nativa do Google. Não há fallback para `localhost`.

Ambientes aceitos: `development` (padrão), `staging` (também aceita `test`) e
`production`. Injete valores por ambiente no CI ou no comando Flutter:

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=https://api.dev.exemplo.com \
  --dart-define=GOOGLE_WEB_CLIENT_ID=... \
  --dart-define=GOOGLE_IOS_CLIENT_ID=... \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=...
```

Para produção, altere somente os valores de `--dart-define`; o código e as
features permanecem iguais.

### Configuração nativa do Google

Além dos `dart-define`, registre os identificadores e fingerprints exigidos pelo
Google Cloud em cada cliente nativo. Android (emulador e dispositivo físico) usa
o cliente Android correspondente ao applicationId/assinatura; iOS Simulator e
dispositivo usam o cliente iOS correspondente ao bundle ID; Flutter Web usa
`GOOGLE_WEB_CLIENT_ID`. A seleção ocorre somente no datasource de identidade,
sem condicional de plataforma nas telas.
