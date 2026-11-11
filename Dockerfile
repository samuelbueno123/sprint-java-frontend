# Multi-stage Dockerfile para Frontend Flutter Web em Produção

# Estágio 1: Build da aplicação Flutter Web
FROM ghcr.io/cirruslabs/flutter:3.24.5 AS build

WORKDIR /app

# Copia dependências e faz download prévio
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copia o código-fonte
COPY . .

# Argumentos de compilação para injeção de ambiente
ARG API_BASE_URL=http://localhost:8080
ARG GOOGLE_WEB_CLIENT_ID=367385027390-dmuj8neeqpgcbph3uk9qfb2cs5ubldhp.apps.googleusercontent.com
ARG GOOGLE_SERVER_CLIENT_ID=367385027390-dmuj8neeqpgcbph3uk9qfb2cs5ubldhp.apps.googleusercontent.com

# Compilação otimizada para release Web
RUN flutter build web --release \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=GOOGLE_WEB_CLIENT_ID=${GOOGLE_WEB_CLIENT_ID} \
    --dart-define=GOOGLE_SERVER_CLIENT_ID=${GOOGLE_SERVER_CLIENT_ID}

# Estágio 2: Servidor Web Nginx de Alta Performance
FROM nginx:1.27-alpine

# Remove configuração padrão do Nginx
RUN rm -rf /etc/nginx/conf.d/*

# Copia configuração customizada de SPA e segurança
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copia os arquivos compilados do estágio anterior
COPY --from=build /app/build/web /usr/share/nginx/html

# Instala curl para healthcheck do container
RUN apk add --no-cache curl

EXPOSE 80

# Healthcheck nativo
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -fsS http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
