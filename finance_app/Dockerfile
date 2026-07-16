# Estágio 1 — build do Flutter Web
FROM ghcr.io/cirruslabs/flutter:3.35.4 AS build

WORKDIR /app

# Copia só o pubspec primeiro para aproveitar o cache de camadas do Docker:
# enquanto as dependências não mudarem, o pub get não roda de novo.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release --base-href /

# Estágio 2 — servidor estático
FROM nginx:1.27-alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 2006

CMD ["nginx", "-g", "daemon off;"]
