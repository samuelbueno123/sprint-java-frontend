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

`AppConfig` é a única fonte de configuração. O app carrega `.env` na inicialização
e mantém suporte a `--dart-define`, que tem precedência. Em desenvolvimento, a
URL padrão é `http://localhost:8080`; no emulador Android, o padrão é
`http://10.0.2.2:8080`. Em um aparelho físico conectado por ADB, encaminhe a API
local com `adb reverse tcp:8080 tcp:8080`, ou defina `API_BASE_URL` com um host
acessível pelo aparelho. Staging e produção exigem uma URL HTTPS acessível.
Para Flutter Web, use a porta `3000`, permitida pela configuração CORS de
desenvolvimento do backend. O datasource do Google encapsula as diferenças entre
Web, iOS e plataformas nativas.

Ambientes aceitos: `development` (padrão), `staging` (também aceita `test`) e
`production`. Injete valores por ambiente no CI ou no comando Flutter:

As chaves aceitas no `.env` são `API_BASE_URL`, `GOOGLE_WEB_CLIENT_ID`,
`GOOGLE_IOS_CLIENT_ID`, `GOOGLE_SERVER_CLIENT_ID` e `GOOGLE_ANDROID_CLIENT_ID`.
Os IDs OAuth são identificadores públicos; não coloque segredos privados no
arquivo empacotado no app.

Para produção, injete os valores de `--dart-define` no pipeline de build ou use
um `.env` próprio com a URL HTTPS do backend.

### Configuração nativa do Google

No Android, cadastre no Google Cloud o cliente Android com o `applicationId` e
o SHA-1 da chave usada para assinar o app (debug e release têm fingerprints
distintos). O Android client ID é registrado no Google Cloud e não é passado como
`serverClientId` pelo plugin. `GOOGLE_SERVER_CLIENT_ID` deve ser o OAuth Client
Web, igual ao `GOOGLE_CLIENT_ID` usado pelo backend; é esse valor que permite ao
SDK emitir o ID token para o backend validar. No iOS, cadastre o cliente iOS do
bundle ID; no Web, autorize a origem `http://localhost:3000` no cliente OAuth Web.
O `applicationId` Android atual é `com.example.frontend`; altere-o para o valor
registrado no cliente Android antes de distribuir o app se esse não for o package
definitivo.
