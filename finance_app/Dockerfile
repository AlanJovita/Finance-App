# Estágio 1 — build do Flutter Web
# A tag tem de acompanhar o Flutter que resolveu o `pubspec.lock` (o rodapé
# `sdks:` de lá diz o mínimo): o lock traz as versões exatas dos pacotes, e
# imagem mais velha que elas faz o `pub get` falhar por SDK — foi o que
# aconteceu quando o file_picker 13 passou a exigir Dart >= 3.10.
FROM ghcr.io/cirruslabs/flutter:3.38.2 AS build

WORKDIR /app

# Copia só o pubspec primeiro para aproveitar o cache de camadas do Docker:
# enquanto as dependências não mudarem, o pub get não roda de novo.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
# Sem service worker: ele servia os assets cache-first e sem revalidar, o que
# prendia o navegador na versão anterior a cada deploy (ver o comentário no
# `web/index.html`). O cache agora é só o do HTTP, com revalidação por ETag.
RUN flutter build web --release --base-href / --pwa-strategy=none

# Estágio 2 — servidor estático
FROM nginx:1.27-alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 2006

CMD ["nginx", "-g", "daemon off;"]
